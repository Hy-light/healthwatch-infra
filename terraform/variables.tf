# -----------------------------------------------------------------------------
# Every value an Infrastructure Change Request (ICR) can change lives here.
# The actual values are in terraform.tfvars, which is the ONLY file you edit
# when an ICR comes in.
# -----------------------------------------------------------------------------

variable "icr_id" {
  description = "The Infrastructure Change Request that authorised the current state, e.g. ICR-0042."
  type        = string

  validation {
    condition     = can(regex("^ICR-[0-9]{4}$", var.icr_id))
    error_message = "icr_id must look like ICR-0042. No ticket, no change."
  }
}

variable "change_summary" {
  description = "One line describing the change, shown on the status page."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "location" {
  description = "Azure region. South Africa North is the closest Azure region to Nigeria."
  type        = string
  default     = "southafricanorth"
}

variable "states" {
  description = "Nigerian states served by the clinic network. Each gets its own private reports container."
  type        = list(string)

  validation {
    condition     = length(var.states) > 0 && length(var.states) <= 37
    error_message = "Provide between 1 and 37 states."
  }
}

variable "owner_email" {
  description = "Team mailbox that owns this environment. Receives budget alerts."
  type        = string
}

variable "cost_centre" {
  description = "Cost centre the Azure bill is charged to."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget for the resource group, in USD. Alerts at 80% (forecast) and 100% (actual)."
  type        = number
}

variable "vendor_ssh_sources" {
  description = "Source IP ranges allowed to SSH into the clinic subnet (vendor support). Empty list = no SSH."
  type        = list(string)
  default     = []
}

variable "address_space" {
  description = "VNet address space."
  type        = string
  default     = "10.20.0.0/16"
}
