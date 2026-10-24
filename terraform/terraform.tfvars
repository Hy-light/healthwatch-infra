# =============================================================================
#  HealthWatch Naija - production environment
#  This is the ONLY file that changes when an ICR is approved.
# =============================================================================

icr_id         = "ICR-0042"
change_summary = "Expanded to Kano, Enugu and Rivers; vendor SSH access"

environment = "prod"
location    = "southafricanorth"

states = ["Lagos", "Kano", "Enugu", "Rivers"]

owner_email        = "platform-team@example.com"
cost_centre        = "CC-HEALTH-001"
monthly_budget_usd = 100

vendor_ssh_sources = ["203.0.113.10/32"]

