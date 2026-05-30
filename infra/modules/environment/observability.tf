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

resource "aws_iam_policy" "xray" {
  name = "${local.name_prefix}-ecs-xray-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
      ]
      Resource = ["*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_xray" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.xray.arn
}

# CloudWatch Log Group for ADOT Collector sidecar

resource "aws_cloudwatch_log_group" "adot" {
  name              = "/ecs/${var.project}-adot-${var.environment}"
  retention_in_days = 7
}
