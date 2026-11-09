<#
  Test-BreakGlassCA.ps1  (READ-ONLY)
  Checks that every Conditional Access policy either does not target the break-glass account(s)
  or excludes them (directly, through a group, or through a role). Nothing is changed in the tenant.

  Usage:
    .\Test-BreakGlassCA.ps1 -UserPrincipalName bg1@contoso.com,bg2@contoso.com
    .\Test-BreakGlassCA.ps1 -UserPrincipalName bg1@contoso.com -CsvPath "$env:USERPROFILE\bg-ca.csv"

  Needs the module Microsoft.Graph.Authentication and a read-only sign-in (device code).
  Scopes requested (all read): Policy.Read.All, Directory.Read.All, RoleManagement.Read.Directory
#>
param(
  [Parameter(Mandatory)][string[]]$UserPrincipalName,
  [string]$CsvPath,
  [switch]$SkipConnect   # for testing only
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-All($uri) {
  $out = @()
  while ($uri) { $r = Invoke-MgGraphRequest -Method GET -Uri $uri; $out += @($r.value); $uri = $r.'@odata.nextLink' }
  $out
}

if (-not $SkipConnect) {
  if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Host 'Install first: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser' -ForegroundColor Red; return
  }
  Import-Module Microsoft.Graph.Authentication
  Connect-MgGraph -Scopes 'Policy.Read.All', 'Directory.Read.All', 'RoleManagement.Read.Directory' -UseDeviceCode -NoWelcome
}

$policies = @(Get-All 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies')
Write-Host ("Conditional Access policies found: {0}" -f $policies.Count)

$all = @()
foreach ($upn in $UserPrincipalName) {
  $u = Invoke-MgGraphRequest -Method GET -Uri ('https://graph.microsoft.com/v1.0/users/' + [uri]::EscapeDataString($upn) + '?$select=id,userPrincipalName,displayName,accountEnabled')
  Write-Host ("`n=== {0} ({1}) enabled={2} ===" -f $u.userPrincipalName, $u.id, $u.accountEnabled) -ForegroundColor Cyan

  # groups (transitive) and directly assigned directory roles
  $mem = @(Get-All ('https://graph.microsoft.com/v1.0/users/' + $u.id + '/transitiveMemberOf?$select=id,displayName,isAssignableToRole,roleTemplateId&$top=999'))
  $groups = @($mem | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' })
  $groupName = @{}; $groups | ForEach-Object { $groupName[$_.id] = $_.displayName }
  $roleIds = @{}
  $mem | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.directoryRole' -and $_.roleTemplateId } | ForEach-Object { $roleIds[$_.roleTemplateId] = $true }
  # roles reached through role-assignable groups, and any direct assignment not listed above
  $principals = @($u.id) + @($groups | Where-Object { $_.isAssignableToRole } | ForEach-Object { $_.id })
  foreach ($principalId in $principals) {
    Get-All ('https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?$filter=principalId eq ''' + $principalId + '''') |
      ForEach-Object { if ($_.roleDefinitionId) { $roleIds[$_.roleDefinitionId] = $true } }
  }
  Write-Host ("Member of {0} groups, holds {1} directory roles (eligible PIM roles are not included)" -f $groups.Count, $roleIds.Count)

  foreach ($p in $policies) {
    $c = $p.conditions; $us = $null
    if ($c) { $us = $c.users }
    $row = [ordered]@{ User = $u.userPrincipalName; Policy = $p.displayName; State = $p.state; Targeted = ''; Result = ''; How = '' }
    if (-not $us) { $row.Targeted = 'n/a'; $row.Result = 'N/A (no user conditions)'; $all += [pscustomobject]$row; continue }

    $incUsers = @($us.includeUsers | Where-Object { $_ }); $incGroups = @($us.includeGroups | Where-Object { $_ }); $incRoles = @($us.includeRoles | Where-Object { $_ })
    $excUsers = @($us.excludeUsers | Where-Object { $_ }); $excGroups = @($us.excludeGroups | Where-Object { $_ }); $excRoles = @($us.excludeRoles | Where-Object { $_ })

    $targeted = ($incUsers -contains 'All') -or ($incUsers -contains $u.id) `
      -or (@($incGroups | Where-Object { $groupName.ContainsKey($_) }).Count -gt 0) `
      -or (@($incRoles | Where-Object { $roleIds.ContainsKey($_) }).Count -gt 0)

    $how = @()
    if ($excUsers -contains $u.id) { $how += 'user' }
    $excG = @($excGroups | Where-Object { $groupName.ContainsKey($_) }); if ($excG.Count) { $how += ('group: ' + (($excG | ForEach-Object { $groupName[$_] }) -join ', ')) }
    $excR = @($excRoles | Where-Object { $roleIds.ContainsKey($_) }); if ($excR.Count) { $how += ('role: ' + ($excR -join ', ')) }

    if (-not $targeted) { $row.Targeted = 'no'; $row.Result = 'NOT TARGETED' }
    elseif ($how.Count) { $row.Targeted = 'yes'; $row.Result = 'EXCLUDED'; $row.How = ($how -join '; ') }
    else { $row.Targeted = 'yes'; $row.Result = 'MISSING' }
    $all += [pscustomobject]$row
  }
}

$order = @{ 'MISSING' = 0; 'EXCLUDED' = 1; 'NOT TARGETED' = 2 }
$all | Sort-Object User, @{ Expression = { if ($order.ContainsKey($_.Result)) { $order[$_.Result] } else { 3 } } }, Policy |
  Format-Table User, Policy, State, Targeted, Result, How -AutoSize -Wrap

Write-Host '--- Summary ---'
foreach ($upn in $UserPrincipalName) {
  $mine = @($all | Where-Object { $_.User -eq $upn -or $_.User -like "$upn*" })
  $miss = @($mine | Where-Object { $_.Result -eq 'MISSING' })
  $missLive = @($miss | Where-Object { $_.State -ne 'disabled' })
  $line = "{0}: {1} policies, excluded in {2}, not targeted in {3}, MISSING in {4} ({5} enabled or report-only)" -f $upn, $mine.Count,
    @($mine | Where-Object { $_.Result -eq 'EXCLUDED' }).Count, @($mine | Where-Object { $_.Result -eq 'NOT TARGETED' }).Count, $miss.Count, $missLive.Count
  if ($missLive.Count) { Write-Host $line -ForegroundColor Red; $missLive | ForEach-Object { Write-Host ('   add exclusion: ' + $_.Policy + '  [' + $_.State + ']') -ForegroundColor Red } }
  else { Write-Host $line -ForegroundColor Green }
}
if ($CsvPath) { $all | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8; Write-Host "CSV: $CsvPath" }
