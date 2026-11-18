terraform {
  backend "local" {
    path = "../../.git/forge/cloud/staging.tfstate"
  }
}

variable "orders_api_token" {
  type      = string
  sensitive = true
  default   = "s3cr3t-orders-api-token"
}

resource "terraform_data" "orders_settings" {
  input = { log_level = "info", api_token = var.orders_api_token }
}
