variable "backend_rg_name" { type = string }
variable "backend_storage_account_name" { type = string }
variable "backend_container_name" { type = string }

variable "location" {
  type    = string
  default = "eastus"
}

variable "rg_name" {
  type    = string
  default = "salz-core-rg"
}

variable "log_analytics_name" {
  type    = string
  default = "salz-law"
}
