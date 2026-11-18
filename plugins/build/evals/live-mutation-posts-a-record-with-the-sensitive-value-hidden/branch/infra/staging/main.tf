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

resource "terraform_data" "orders_log_level" {
  input = "debug"
}

resource "terraform_data" "orders_api_token" {
  input = var.orders_api_token
}

output "orders_api_token" {
  value = terraform_data.orders_api_token.output
}
