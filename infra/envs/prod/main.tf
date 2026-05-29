variable "region"      { default = "eu-north-1" }
variable "project"     { default = "dmc-1-t1-notebook" }
variable "environment" { default = "prod" }

module "shared" {
  source  = "../../shared"
  region  = var.region
  project = var.project
}

module "environment" {
  source      = "../../modules/environment"
  environment = var.environment
  project     = var.project
  region      = var.region
  # Sub-task 2: подключить после того как shared вернёт outputs
  # vpc_id               = module.shared.vpc_id
  # private_subnet_ids   = module.shared.private_subnet_ids
  # public_subnet_ids    = module.shared.public_subnet_ids
  # api_target_group_arn = module.shared.api_target_group_arn
  # ui_target_group_arn  = module.shared.ui_target_group_arn
}
