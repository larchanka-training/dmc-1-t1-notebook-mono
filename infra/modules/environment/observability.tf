# ECS Task Role (used by running containers to call AWS APIs)
# Distinct from the execution role which is used by the ECS agent.

resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "xray_and_ssm" {
  name = "${local.name_prefix}-ecs-xray-ssm-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
        ]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = [aws_ssm_parameter.adot_config.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_xray_ssm" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.xray_and_ssm.arn
}

# CloudWatch Log Group for ADOT Collector sidecar

resource "aws_cloudwatch_log_group" "adot" {
  name              = "/ecs/${var.project}-adot-${var.environment}"
  retention_in_days = 7
}

# SSM Parameter: ADOT Collector config (traces only → X-Ray)

resource "aws_ssm_parameter" "adot_config" {
  name = "/${local.name_prefix}/adot-config"
  type = "String"

  value = <<-YAML
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
    processors:
      batch:
    exporters:
      awsxray:
        region: ${var.region}
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [awsxray]
  YAML
}

# X-Ray Sampling Rule

resource "aws_xray_sampling_rule" "api" {
  rule_name      = "${local.name_prefix}-api"
  priority       = 1000
  version        = 1
  reservoir_size = 1
  fixed_rate     = var.xray_sampling_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "${local.name_prefix}-api"
  resource_arn   = "*"
}
