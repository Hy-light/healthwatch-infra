# =============================================================================
#  HealthWatch Naija - production environment
#  This is the ONLY file that changes when an ICR is approved.
# =============================================================================

icr_id         = "ICR-0041"
change_summary = "Initial clinic network: Lagos pilot"

environment = "prod"
location    = "southafricanorth"

states = ["Lagos"]

owner_email        = "puc.chime@gmail.com"
cost_centre        = "CC-HEALTH-001"
monthly_budget_usd = 50

vendor_ssh_sources = []

