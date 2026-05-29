variable "environment" {
  description = "Environment name: dev or prod"
}

variable "project" {
  description = "Project name prefix for all resources"
}

variable "region" {
  description = "AWS region"
}

# Заполняются из shared outputs после Sub-task 2
variable "vpc_id" {
  description = "VPC ID from shared module"
  default     = ""
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks and RDS"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
  default     = []
}

variable "api_target_group_arn" {
  description = "ALB target group ARN for API"
  default     = ""
}

variable "ui_target_group_arn" {
  description = "ALB target group ARN for UI"
  default     = ""
}
