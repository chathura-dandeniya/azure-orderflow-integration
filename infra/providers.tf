terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-orderflow-tfstate"
    storage_account_name = "storderflowtf2026"
    container_name       = "tfstate"
    key                  = "orderflow.dev.tfstate"
    use_azuread_auth     = true
    use_cli              = true
  }
}

provider "azurerm" {
  features {}
}