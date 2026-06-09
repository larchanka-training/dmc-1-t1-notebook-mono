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

variable "alb_security_group_id" {
  description = "ALB security group ID"
  default     = ""
}

variable "ecs_security_group_id" {
  description = "ECS tasks security group ID"
  default     = ""
}

variable "rds_security_group_id" {
  description = "RDS security group ID"
  default     = ""
}

variable "alb_dns_name" {
  description = "ALB DNS name"
  default     = ""
}

variable "xray_sampling_rate" {
  description = "X-Ray trace sampling rate (0.0 to 1.0). Dev: 1.0, Prod: 0.3"
  type        = number
  default     = 0.1
}

variable "bedrock_model_id" {
  description = "AWS Bedrock foundation model ID for AI code generation"
  type        = string
}

variable "ai_rate_limit_rpm" {
  description = "AI endpoint: max requests per minute per user"
  type        = number
  default     = 10
}

variable "ai_rate_limit_rpd" {
  description = "AI endpoint: max requests per day per user"
  type        = number
  default     = 100
}

variable "ai_max_prompt_chars" {
  description = "AI endpoint: max prompt size in characters (~8K tokens at 32000)"
  type        = number
  default     = 32000
}
