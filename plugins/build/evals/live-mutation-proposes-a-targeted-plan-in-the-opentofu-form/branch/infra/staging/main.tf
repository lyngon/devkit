terraform {
  backend "local" {
    path = "../../.git/forge/cloud/staging.tfstate"
  }
}

resource "terraform_data" "orders_log_level" {
  input = "debug"
}

resource "terraform_data" "orders_replicas" {
  input = "3"
}
