# IT security fault tree: Unauthorized customer data exfiltration (case study)
# - Top event: data exfiltration from production (observable binary outcome)
# - 4 gates total: 1 top OR + 1 OR (credentials) + 3 ANDs
# - Basic events are binary (0/1) from logs, control audits, or incident reports
# - Event names are valid R identifiers for tidyfault formulate() / quantify()

library(tidyverse)

# ---- Scenario ----
# Top event: Unauthorized customer data exfiltration from a production system
# Three pathways:
#   A. External attacker gets privileged access (credential-based)
#   B. External attacker exploits unpatched internet-facing service
#   C. Insider exfiltration (malicious or compromised insider)
#
# Boolean logic (1 = weakness present, 0 = not present):
#   Top = ExternalPrivAccess OR UnpatchedExploit OR InsiderExfil
#   ExternalPrivAccess = CredentialsCompromised AND MFA_NotEnforced AND PrivAccess_Misconfig
#   CredentialsCompromised = PhishingCreds OR LeakedOrReusedCreds
#   UnpatchedExploit = VulnerableService AND PatchOverdue AND WAF_MissingOrBypassed
#   InsiderExfil = InsiderMaliciousOrCompromised AND DLP_Absent AND ExcessivePrivileges

# ---- Event definitions (what each node means) ----
# Gates (intermediate):
#   DataExfiltration          - Top event: unauthorized customer data exfil from production
#   BreachPathways            - Any of the three attack pathways is active
#   ExternalPrivAccess        - Attacker gained privileged access via credentials
#   UnpatchedExploit          - Attacker exploited an internet-facing, unpatched service
#   InsiderExfil              - Malicious or compromised insider exfiltrated data
#   CredentialsCompromised    - At least one credential-compromise mechanism occurred
#
# Basic events (binary 0/1; observable from logs, audits, or IR):
#   PhishingCreds             - User entered credentials into a phishing site; captured
#   LeakedOrReusedCreds       - Creds in a dump, reused across systems, or flagged by SSO
#   MFA_NotEnforced           - Privileged roles exempt from MFA or legacy auth allowed
#   PrivAccess_Misconfig      - RBAC too broad, PAM not required, or stale admin accounts
#   VulnerableService         - Internet-facing service has a known vulnerability
#   PatchOverdue              - Patch for that service is past SLA / not applied
#   WAF_MissingOrBypassed     - WAF disabled, misconfigured, or bypass path confirmed
#   InsiderMaliciousOrCompromised - Insider threat case or compromised employee account
#   DLP_Absent                - No egress filtering, DLP rules, or CASB controls
#   ExcessivePrivileges       - Account can access sensitive data beyond job role

# ---- Nodes (tidyfault: id, event, type) ----
# event names are valid R identifiers for the boolean formula
it_security_nodes <- tibble(
  id = 1:16,
  event = c(
    "DataExfiltration",              # 1  TOP
    "BreachPathways",               # 2  OR
    "ExternalPrivAccess",          # 3  AND
    "UnpatchedExploit",             # 4  AND
    "InsiderExfil",                 # 5  AND
    "CredentialsCompromised",       # 6  OR
    "PhishingCreds",               # 7  not
    "LeakedOrReusedCreds",         # 8  not
    "MFA_NotEnforced",             # 9  not
    "PrivAccess_Misconfig",        # 10 not
    "VulnerableService",           # 11 not
    "PatchOverdue",                # 12 not
    "WAF_MissingOrBypassed",       # 13 not
    "InsiderMaliciousOrCompromised", # 14 not
    "DLP_Absent",                 # 15 not
    "ExcessivePrivileges"          # 16 not
  ),
  type = factor(
    c("top", "or", "and", "and", "and", "or",
      "not", "not", "not", "not", "not", "not", "not", "not", "not", "not"),
    levels = c("top", "and", "or", "not")
  )
)

# ---- Edges (from = parent, to = child) ----
it_security_edges <- tibble(
  from = c(
    1L,       # TOP -> BreachPathways
    2L, 2L, 2L,   # BreachPathways (OR) -> three pathways
    3L, 3L, 3L,   # ExternalPrivAccess (AND) -> CredentialsCompromised, MFA_NotEnforced, PrivAccess_Misconfig
    6L, 6L,       # CredentialsCompromised (OR) -> PhishingCreds, LeakedOrReusedCreds
    4L, 4L, 4L,   # UnpatchedExploit (AND) -> VulnerableService, PatchOverdue, WAF_MissingOrBypassed
    5L, 5L, 5L    # InsiderExfil (AND) -> InsiderMaliciousOrCompromised, DLP_Absent, ExcessivePrivileges
  ),
  to = c(
    2L,
    3L, 4L, 5L,
    6L, 9L, 10L,
    7L, 8L,
    11L, 12L, 13L,
    14L, 15L, 16L
  )
)

# ---- Binary outcomes dataset (12 system-month snapshots / assessments) ----
# Column names match node event names so this works with formulate() / calculate() / quantify()
# 1 = weakness/condition present, 0 = not present (see event definitions above)
it_security_data <- tibble(
  obs = 1:12,

  # Pathway A (credential-based)
  PhishingCreds             = c(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0),  # creds captured via phishing
  LeakedOrReusedCreds       = c(0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0),  # dump/reuse/SSO flag
  MFA_NotEnforced           = c(1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0),  # privileged MFA gap
  PrivAccess_Misconfig      = c(1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0),  # RBAC/PAM misconfig

  # Pathway B (unpatched exploit)
  VulnerableService         = c(0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0),  # vuln on internet-facing svc
  PatchOverdue              = c(0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0),  # patch past SLA
  WAF_MissingOrBypassed     = c(0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0),  # WAF off or bypassed

  # Pathway C (insider)
  InsiderMaliciousOrCompromised = c(0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1),  # insider threat / comp'd account
  DLP_Absent                = c(0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1),  # no DLP/egress controls
  ExcessivePrivileges       = c(0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1)   # access beyond role
) %>%
  mutate(
    # Derived gate outputs (for reference / validation)
    CredentialsCompromised = (PhishingCreds == 1) | (LeakedOrReusedCreds == 1),
    ExternalPrivAccess = CredentialsCompromised & (MFA_NotEnforced == 1) & (PrivAccess_Misconfig == 1),
    UnpatchedExploit = (VulnerableService == 1) & (PatchOverdue == 1) & (WAF_MissingOrBypassed == 1),
    InsiderExfil = (InsiderMaliciousOrCompromised == 1) & (DLP_Absent == 1) & (ExcessivePrivileges == 1),
    top_breach = ExternalPrivAccess | UnpatchedExploit | InsiderExfil
  )

# ---- Optional: save as package data (run from tidyfault root) ----
# dir.create("data", showWarnings = FALSE)
# usethis::use_data(it_security_nodes, it_security_edges, it_security_data, overwrite = TRUE)

# ---- Use with tidyfault (quantify from binary data) ----
# library(tidyfault)
# f <- curate(nodes = it_security_nodes, edges = it_security_edges) %>%
#   equate() %>%
#   formulate()
# res <- f %>% quantify(it_security_data)  # adds outcome column; matches top_breach
