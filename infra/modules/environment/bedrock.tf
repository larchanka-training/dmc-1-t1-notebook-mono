data "aws_caller_identity" "current" {}

# VPC Interface Endpoint — Bedrock traffic stays inside AWS, never touches NAT/internet

resource "aws_security_group" "bedrock_endpoint" {
  name        = "${local.name_prefix}-bedrock-endpoint-sg"
  description = "Bedrock VPC endpoint: HTTPS from ECS only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  tags = { Name = "${local.name_prefix}-bedrock-endpoint-sg" }
}

resource "aws_vpc_endpoint" "bedrock_runtime" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.bedrock_endpoint.id]
  private_dns_enabled = true

  tags = { Name = "${local.name_prefix}-bedrock-runtime-endpoint" }
}

# IAM: allow ECS task containers to call Bedrock models

resource "aws_iam_policy" "bedrock" {
  name = "${local.name_prefix}-ecs-bedrock-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:Converse",
        "bedrock:ConverseStream",
      ]
      Resource = "arn:aws:bedrock:${var.region}::foundation-model/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_bedrock" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.bedrock.arn
}

# Bedrock model invocation logging → CloudWatch
# Account-scoped resource: created in prod only to avoid conflicts when
# dev and prod share the same AWS account + region.

resource "aws_cloudwatch_log_group" "bedrock" {
  count             = var.environment == "prod" ? 1 : 0
  name              = "/aws/bedrock/${var.project}-${var.environment}"
  retention_in_days = 7

  tags = { Name = "${local.name_prefix}-bedrock-logs" }
}

resource "aws_iam_role" "bedrock_logging" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${local.name_prefix}-bedrock-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_logging" {
  count = var.environment == "prod" ? 1 : 0
  name  = "cloudwatch-logs"
  role  = aws_iam_role.bedrock_logging[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.bedrock[0].arn}:*"
    }]
  })
}

resource "aws_bedrock_model_invocation_logging_configuration" "main" {
  count = var.environment == "prod" ? 1 : 0

  logging_config {
    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.bedrock[0].name
      role_arn       = aws_iam_role.bedrock_logging[0].arn
    }
    embedding_data_delivery_enabled = false
    image_data_delivery_enabled     = false
    text_data_delivery_enabled      = true
  }
}
