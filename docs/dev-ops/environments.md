# Окружения

## Dev

### Приложение

| Сервис | URL |
|--------|-----|
| UI (Notebook) | http://dmc-1-t1-notebook-dev-alb-1605418557.eu-north-1.elb.amazonaws.com |
| API Swagger UI | http://dmc-1-t1-notebook-dev-alb-1605418557.eu-north-1.elb.amazonaws.com/docs |
| API ReDoc | http://dmc-1-t1-notebook-dev-alb-1605418557.eu-north-1.elb.amazonaws.com/redoc |
| API Health Check | http://dmc-1-t1-notebook-dev-alb-1605418557.eu-north-1.elb.amazonaws.com/api/v1/health |
| API Health Check (БД) | http://dmc-1-t1-notebook-dev-alb-1605418557.eu-north-1.elb.amazonaws.com/api/v1/health/db |

### AWS Console

**ECS**

| Страница | Ссылка |
|----------|--------|
| Сервисы кластера | https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-dev/services?region=eu-north-1 |
| Логи API | https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-api-dev |
| Логи UI | https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-ui-dev |

**База данных**

| Страница | Ссылка |
|----------|--------|
| RDS instance | https://eu-north-1.console.aws.amazon.com/rds/home?region=eu-north-1#database:id=dmc-1-t1-notebook-dev-db;is-cluster=false |

**Сеть и балансировка**

| Страница | Ссылка |
|----------|--------|
| ALB | https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#LoadBalancers:search=dmc-1-t1-notebook-dev-alb |
| Target Groups | https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#TargetGroups:search=dmc-1-t1-notebook-dev |
| VPC | https://eu-north-1.console.aws.amazon.com/vpc/home?region=eu-north-1#vpcs:search=dmc-1-t1-notebook-dev |

**Безопасность**

| Страница | Ссылка |
|----------|--------|
| Secrets Manager | https://eu-north-1.console.aws.amazon.com/secretsmanager/listsecrets?region=eu-north-1 |

---

## Prod

### Приложение

| Сервис | URL |
|--------|-----|
| UI (Notebook) | http://dmc-1-t1-notebook-prod-alb-179181558.eu-north-1.elb.amazonaws.com |
| API Swagger UI | http://dmc-1-t1-notebook-prod-alb-179181558.eu-north-1.elb.amazonaws.com/docs |
| API ReDoc | http://dmc-1-t1-notebook-prod-alb-179181558.eu-north-1.elb.amazonaws.com/redoc |
| API Health Check | http://dmc-1-t1-notebook-prod-alb-179181558.eu-north-1.elb.amazonaws.com/api/v1/health |
| API Health Check (БД) | http://dmc-1-t1-notebook-prod-alb-179181558.eu-north-1.elb.amazonaws.com/api/v1/health/db |

### AWS Console

**ECS**

| Страница | Ссылка |
|----------|--------|
| Сервисы кластера | https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-prod/services?region=eu-north-1 |
| Логи API | https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-api-prod |
| Логи UI | https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-ui-prod |

**База данных**

| Страница | Ссылка |
|----------|--------|
| RDS instance | https://eu-north-1.console.aws.amazon.com/rds/home?region=eu-north-1#database:id=dmc-1-t1-notebook-prod-db;is-cluster=false |

**Сеть и балансировка**

| Страница | Ссылка |
|----------|--------|
| ALB | https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#LoadBalancers:search=dmc-1-t1-notebook-prod-alb |
| Target Groups | https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#TargetGroups:search=dmc-1-t1-notebook-prod |
| VPC | https://eu-north-1.console.aws.amazon.com/vpc/home?region=eu-north-1#vpcs:search=dmc-1-t1-notebook-prod |

**Безопасность**

| Страница | Ссылка |
|----------|--------|
| Secrets Manager | https://eu-north-1.console.aws.amazon.com/secretsmanager/listsecrets?region=eu-north-1 |
