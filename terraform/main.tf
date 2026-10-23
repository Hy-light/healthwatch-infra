locals {
  prefix = "hwn-${var.environment}"

  # Tags are how finance, security and on-call find out who owns what.
  tags = {
    application = "healthwatch-naija"
    environment = var.environment
    owner       = var.owner_email
    cost_centre = var.cost_centre
    change_ref  = var.icr_id
    managed_by  = "terraform"
    repository  = "healthwatch-infra"
  }

  # "Cross River" -> "cross-river" (storage container names must be lowercase, no spaces)
  state_slugs = { for s in var.states : s => lower(replace(trimspace(s), " ", "-")) }

  # HTML for the status page (built here so the template stays simple).
  state_cards = join("\n", [
    for s in var.states :
    "<li class=\"card\"><span class=\"dot\"></span><div><strong>${s}</strong><small>reports-${lower(replace(trimspace(s), " ", "-"))} &middot; private</small></div></li>"
  ])
  ssh_status = length(var.vendor_ssh_sources) == 0 ? "Closed" : "Vendor only (${length(var.vendor_ssh_sources)} range)"

  # Network rules. HTTPS is open to the internet; SSH only for vendor ranges the ICR approves.
  nsg_rules = concat(
    [
      {
        name   = "Allow-HTTPS-Inbound"
        prio   = 100
        port   = "443"
        source = "Internet"
      }
    ],
    [
      for i, cidr in var.vendor_ssh_sources : {
        name   = "Allow-Vendor-SSH-${i + 1}"
        prio   = 200 + i
        port   = "22"
        source = cidr
      }
    ]
  )
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

# ---------------------------------------------------------------- Resource group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.prefix}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------- Observability
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# ---------------------------------------------------------------- Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "clinics" {
  name                 = "snet-clinics"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 1)]
}

# Rules are defined INSIDE the NSG on purpose: if someone adds a rule by hand in
# the portal ("ClickOps"), the drift-detection pipeline will see it and flag it.
resource "azurerm_network_security_group" "clinics" {
  name                = "nsg-${local.prefix}-clinics"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  dynamic "security_rule" {
    for_each = local.nsg_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.prio
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = security_rule.value.source
      destination_address_prefix = "VirtualNetwork"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "clinics" {
  subnet_id                 = azurerm_subnet.clinics.id
  network_security_group_id = azurerm_network_security_group.clinics.id
}

# ---------------------------------------------------------------- Storage
resource "azurerm_storage_account" "main" {
  name                            = "sthwn${var.environment}${random_string.suffix.result}"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}

# One PRIVATE container per state for clinic reports.
resource "azurerm_storage_container" "reports" {
  for_each              = local.state_slugs
  name                  = "reports-${each.value}"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Public status page (the only public thing in this environment).
resource "azurerm_storage_account_static_website" "status" {
  storage_account_id = azurerm_storage_account.main.id
  index_document     = "index.html"
  error_404_document = "index.html"
}

resource "azurerm_storage_blob" "status_page" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.main.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"

  source_content = templatefile("${path.module}/templates/status.html.tftpl", {
    icr_id         = var.icr_id
    change_summary = var.change_summary
    environment    = upper(var.environment)
    location       = var.location
    state_count    = length(var.states)
    state_cards    = local.state_cards
    ssh_status     = local.ssh_status
    owner          = var.owner_email
  })

  depends_on = [azurerm_storage_account_static_website.status]
}

# ---------------------------------------------------------------- Cost guardrail
resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "budget-${local.prefix}"
  resource_group_id = azurerm_resource_group.main.id
  amount            = var.monthly_budget_usd
  time_grain        = "Monthly"

  time_period {
    # Budgets must start on the 1st of the current month.
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"
    contact_emails = [var.owner_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_emails = [var.owner_email]
  }

  lifecycle {
    # Do not recreate the budget every time the month changes.
    ignore_changes = [time_period]
  }
}
