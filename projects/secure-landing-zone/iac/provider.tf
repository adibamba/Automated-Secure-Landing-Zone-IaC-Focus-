terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Optional: configure remote backend by uncommenting and configuring below
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "<state-rg>"
#     storage_account_name = "<statestorage>"
#     container_name       = "tfstate"
#     key                  = "secure-landing-zone.tfstate"
#   }
# }
