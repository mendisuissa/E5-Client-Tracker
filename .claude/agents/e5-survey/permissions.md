# E5 survey: read-only access the customer must grant

Principle: the consultant account is a normal user of the customer tenant (guest or member), signs in by hand, and holds **read-only** roles only.
No app registration, no consent, no API, no PowerShell connection to the tenant.

| # | Where it is granted | Role (read-only) | What it unlocks | Checks |
|---|---|---|---|---|
| 1 | Entra roles | **Global Reader** | Entra (users, CA, PIM, governance, agents), Intune read, Exchange / SharePoint / Teams admin centers read, Microsoft 365 admin center (licenses, Copilot, Agents), part of Defender and Purview | p1, p2, p8, most of p4 and p6, part of p9 |
| 2 | Entra roles | **Security Reader** | Defender XDR: Endpoints settings, Email and collaboration policies, Cloud apps, Identities, Exposure management, Secure Score | p3, p4, p5 |
| 3 | Defender XDR unified RBAC / MDE device groups | Read on **all device groups** | Device inventory. If it is scoped to some groups, the device list can look empty | p3 (onboarding, ASR, tamper, isolation) |
| 4 | Purview role groups | **Information Protection Reader**, **View-Only DLP Compliance Management**, **View-Only Audit Logs**, **View-Only Retention Management**, **Insider Risk Management Auditors** | Labels, DLP, audit retention, retention, Insider Risk read | p6 |
| 5 | Azure RBAC on the Sentinel subscription / workspace | **Reader** + **Microsoft Sentinel Reader** (+ **Log Analytics Reader** if workbooks and tables are needed) | Sentinel workspace, connectors, rules, automation. Without it the Defender portal shows "0 workspaces" | p7 (22 checks) |
| 6 | Azure RBAC (optional) | **Security Reader** on the subscription | Defender for Cloud | none of the 194 directly |
| 7 | Security Copilot | Reader on the Security Copilot capacity resource | Capacity and usage | p9-copilot |

## Cannot be verified read-only (the agent marks these "not assessed" with the reason)

- **eDiscovery cases**: the case list is shown only to case members. "0 cases" can mean "no access". Ask the customer.
- **Power Platform / Copilot Studio governance** (environments, DLP policies, maker permissions): needs Power Platform admin. Partly covered by the Microsoft 365 admin center agent registry and Entra Agents.
- **Process controls** (pentest, tabletop, SOC maturity, MSSP, monthly review, agent lifecycle): questions for the customer, not portal reads.
- **DNS**: SPF, DKIM, DMARC are public records; no role needed.

## To confirm in the first pilot

The role names above are the least privilege I expect to work. The first run on a new tenant starts with the agent's permission probe, which reports for each workstream whether it can see data. Anything that fails the probe is listed as "access needed" and is never reported as "not implemented".
