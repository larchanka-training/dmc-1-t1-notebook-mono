locals {
  name_prefix = "${var.project}-${var.environment}"
}

# CloudWatch Log Groups

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project}-api-${var.environment}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "ui" {
  name              = "/ecs/${var.project}-ui-${var.environment}"
  retention_in_days = 7
}

# RDS Password in Secrets Manager

resource "random_password" "db" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${local.name_prefix}-db-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = "postgresql://postgres:${random_password.db.result}@${aws_db_instance.main.endpoint}/notebook"

  depends_on = [aws_db_instance.main]
}

# GHCR credentials (value added manually in AWS Console)

resource "aws_secretsmanager_secret" "ghcr" {
  name = "${local.name_prefix}-ghcr-credentials"
}

# RDS

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "main" {
  identifier             = "${local.name_prefix}-db"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = "notebook"
  username               = "postgres"
  password               = random_password.db.result
  multi_az               = false
  skip_final_snapshot    = var.environment != "prod"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]

  tags = { Name = "${local.name_prefix}-db" }
}

# IAM Role for ECS Task Execution

resource "aws_iam_role" "ecs_execution" {
  name = "${local.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "secrets_access" {
  name = "${local.name_prefix}-ecs-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        aws_secretsmanager_secret.db_password.arn,
        aws_secretsmanager_secret.ghcr.arn,
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secrets" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# ECS Cluster

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}"
}

# ECS Task Definitions

resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "api"
      image = "ghcr.io/larchanka-training/dmc-1-t1-notebook-api:latest"

      repositoryCredentials = {
        credentialsParameter = aws_secretsmanager_secret.ghcr.arn
      }

      secrets = [{
        name      = "DATABASE_URL"
        valueFrom = aws_secretsmanager_secret.db_password.arn
      }]

      environment = [
        { name = "OTEL_ENABLED", value = "true" },
        { name = "OTEL_ENDPOINT", value = "http://localhost:4317" },
        { name = "OTEL_SERVICE_NAME", value = "${local.name_prefix}-api" },
        { name = "OTEL_TRACES_SAMPLER", value = "parentbased_traceidratio" },
        { name = "OTEL_TRACES_SAMPLER_ARG", value = tostring(var.xray_sampling_rate) },
        { name = "OTEL_LOGS_ENABLED", value = "false" },
      ]

      portMappings = [{
        containerPort = 8000
        protocol      = "tcp"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name      = "adot-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      essential = false

      environment = [
        { name = "AWS_DEFAULT_REGION", value = var.region },
        { name = "AOT_CONFIG_CONTENT", value = <<-YAML
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
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.adot.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "ui" {
  family                   = "${local.name_prefix}-ui"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name  = "ui"
    image = "ghcr.io/larchanka-training/dmc-1-t1-notebook-ui:latest"

    repositoryCredentials = {
      credentialsParameter = aws_secretsmanager_secret.ghcr.arn
    }

    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ui.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# ECS Services

resource "aws_ecs_service" "api" {
  name            = "${local.name_prefix}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = "api"
    container_port   = 8000
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_execution_managed]
}

resource "aws_ecs_service" "ui" {
  name            = "${local.name_prefix}-ui"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ui.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.ui_target_group_arn
    container_name   = "ui"
    container_port   = 80
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_execution_managed]
}
