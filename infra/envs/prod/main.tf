variable "region"             { default = "eu-north-1" }
variable "project"            { default = "dmc-1-t1-notebook" }
variable "environment"        { default = "prod" }
variable "xray_sampling_rate" { default = 0.3 }

module "shared" {
  source      = "../../shared"
  region      = var.region
  project     = var.project
  environment = var.environment
}

module "environment" {
  source                = "../../modules/environment"
  environment           = var.environment
  project               = var.project
  region                = var.region
  vpc_id                = module.shared.vpc_id
  private_subnet_ids    = module.shared.private_subnet_ids
  public_subnet_ids     = module.shared.public_subnet_ids
  api_target_group_arn  = module.shared.api_target_group_arn
  ui_target_group_arn   = module.shared.ui_target_group_arn
  alb_security_group_id = module.shared.alb_security_group_id
  ecs_security_group_id = module.shared.ecs_security_group_id
  rds_security_group_id = module.shared.rds_security_group_id
  alb_dns_name          = module.shared.alb_dns_name
  xray_sampling_rate    = var.xray_sampling_rate
}
