variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to create"
  default     = "slz-demo-rg"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "eastus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
  default     = "slz"
}

variable "backend_storage_account_prefix" {
  type        = string
  description = "Prefix used when creating a globally unique storage account for terraform state migration"
  default     = "slzstate"
}

variable "backend_container_name" {
  type        = string
  description = "Blob container name for terraform state"
  default     = "tfstate"
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription id where resources will be created"
  default     = ""
}
