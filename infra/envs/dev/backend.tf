terraform {
  backend "s3" {
    bucket         = "dmc-1-t1-notebook-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "dmc-1-t1-notebook-terraform-lock"
    encrypt        = true
  }
}
