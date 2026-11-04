# Portal playbook (learned on a real run, November 2026)

General
- Each page needs 10 to 20 seconds. `computer wait` accepts at most 10 seconds; call it twice.
- `get_page_text` reads Defender, Purview and Microsoft 365 admin center pages well. Entra and Intune blades render inside iframes: use screenshots (scale 0.5, then `zoom` on the table region) and click the left menu instead of guessing blade URLs.
- Flyouts (policy details) are outside `<main>`: read them with `javascript_tool`: `[...document.querySelectorAll('[role=dialog],.ms-Panel')].map(e=>e.innerText).join(' || ').replace(/\n+/g,' | ').replace(/https?:\/\/\S+/g,'<url>').replace(/[?&=]/g,' ')`. If the tool answers `[BLOCKED: Cookie/query string data]`, strip URLs and `?&=` as above.
- Click a policy name with `javascript_tool`: find the element whose `innerText.trim()` equals the name and call `.click()`.
- Pagination: use `find` for the "Next" button and click by `ref`.
- A page that redirects to the Defender home page usually means the feature is not provisioned or the role cannot see it.

Defender (security.microsoft.com)
- Devices: `/machines`. Empty list plus "You need access to all device groups" on the Endpoints advanced-features page means the device list may be scoped. Compare with Intune.
- Endpoints advanced features (tamper protection, EDR block mode, device discovery, live response, MDCA integration): `/securitysettings/endpoints/integration`.
- Indicators: `/securitysettings/endpoints/custom_ti_indicators`. Custom detections: `/custom_detection`.
- Safe Links `/safelinksv2`, Safe Attachments `/safeattachmentv2`, Anti-phishing `/antiphishing`, Anti-spam `/antispam` (open the custom policy; ZAP is "Enable for spam / phishing messages"), user-reported settings `/securitysettings/userSubmission`, submissions `/reportsubmission?viewid=email`, attack simulation `/attacksimulator?viewid=simulations`.
- Home page cards give quick facts: Sentinel data connectors count, SaaS app connectors health, Action center pending actions, Identity Security Deployment Status, discovered devices.
- Exposure management: `/exposure-overview` (loads partly). Sentinel workspaces: `/sentinel/workspaces` (0 can mean no Azure RBAC).
- Defender for Cloud Apps: policies `/cloudapps/policies/management` (31 rows over 2 pages; many legacy anomaly policies show Disabled because of the dynamic detection migration; that is not a failure), app governance `/cloudapps/app-governance` ("turn on" banner means it is off). Cloud Discovery dashboard redirects home when not set up.
- Identities sensors page may redirect home when there are no sensors.

Entra (entra.microsoft.com)
- Conditional Access list: `#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies` (scroll inside the blade, read names and state; "38 out of 38 policies found").
- Authentication strengths: `#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/AuthStrengths`.
- Entitlement management: `#view/Microsoft_AAD_ERM/DashboardBlade/~/elmEntitlement`; Lifecycle workflows is in the left menu of that blade (scroll the menu); Access reviews are in the same menu.
- Agents: click "Agents" in the left navigation (blade URLs for agent identities fail). Overview shows the agent identity count and blueprints.

Purview (purview.microsoft.com)
- DLP policies `/datalossprevention/policies` (mode: Off, Test, Enforce), Information Protection overview `/informationprotection/policies` (label coverage and protection coverage), retention `/datalifecyclemanagement/policies` (overview shows retention labels in use), eDiscovery `/ediscovery/cases` (only case members see cases), DSPM `/dspm/overview`.
- The sensitivity labels list page can hang on "Loading"; use the overview pages instead.

Microsoft 365 admin center (admin.cloud.microsoft)
- Copilot: `#/copilot/overview` (licensed and active users, adoption score); Agents registry `#/agents/all` (total agents, agents without owners, connected platforms).

Other
- Security Copilot: `securitycopilot.microsoft.com`; landing on `/tour/welcome` means no established use for the account.
- Power Platform admin center shows only Home, Deployment and Licensing for a Global Reader: governance there is "not assessed".
- DNS (SPF, DKIM, DMARC): public records; use the commands in the catalog `check`.
