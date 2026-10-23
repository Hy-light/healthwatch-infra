terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state lives in an Azure Storage account created by scripts/bootstrap-azure.sh.
  # The values are passed in by the pipeline with -backend-config (see .github/workflows).
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}
  # Providers are registered once by scripts/bootstrap-azure.sh, so Terraform
  # doesn't try to register ~50 of them on the first run.
  resource_provider_registrations = "none"
  # Authentication comes from ARM_CLIENT_ID / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID /
  # ARM_USE_OIDC environment variables set by GitHub Actions. No secrets stored anywhere.
}
