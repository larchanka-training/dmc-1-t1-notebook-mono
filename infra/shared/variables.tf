variable "region" {
  description = "AWS region"
  default     = "eu-north-1"
}

variable "project" {
  description = "Project name prefix for all resources"
  default     = "dmc-1-t1-notebook"
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
}
