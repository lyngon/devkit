terraform {
  backend "local" {
    path = "../../.git/forge/cloud/staging.tfstate"
  }
}

resource "terraform_data" "orders_log_level" {
  input = "debug"
}
