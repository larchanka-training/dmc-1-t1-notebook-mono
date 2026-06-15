# Окружения

## Dev

### Приложение

> **HTTPS (CloudFront)** — основная точка входа. Прямые ALB URL (HTTP) работают, но не поддерживают WebLLM из-за ограничений браузера на Cache Storage API в insecure context.

| Сервис | URL |
|--------|-----|
| UI (Notebook) | https://d1fa8v8wb6f2t9.cloudfront.net |
| API Swagger UI | https://d1fa8v8wb6f2t9.cloudfront.net/docs |
| API Health Check | https://d1fa8v8wb6f2t9.cloudfront.net/api/v1/health |

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
| Сервисы кластера | [dmc-1-t1-notebook-dev](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-dev/services?region=eu-north-1) |
| Логи API | [/ecs/dmc-1-t1-notebook-api-dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-api-dev) |
| Логи UI | [/ecs/dmc-1-t1-notebook-ui-dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-ui-dev) |
| Логи ADOT | [/ecs/dmc-1-t1-notebook-adot-dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-adot-dev) |
| Logs Insights | [API dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:logs-insights$3FqueryDetail$3D~(end~0~start~-3600~timeType~'RELATIVE~unit~'seconds~editorString~'fields*20*40timestamp*2c*20level*2c*20message*2c*20trace_id*0a*7c*20sort*20*40timestamp*20desc*0a*7c*20limit*2020~isLiveTail~false~queryId~''~source~(~'*2fecs*2fdmc-1-t1-notebook-api-dev))) |
| Трейсы X-Ray | [Traces](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#xray:traces/query) |

**База данных**

| Страница | Ссылка |
|----------|--------|
| RDS instance | [dmc-1-t1-notebook-dev-db](https://eu-north-1.console.aws.amazon.com/rds/home?region=eu-north-1#database:id=dmc-1-t1-notebook-dev-db;is-cluster=false) |

**Сеть и балансировка**

| Страница | Ссылка |
|----------|--------|
| ALB | [dmc-1-t1-notebook-dev-alb](https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#LoadBalancers:search=dmc-1-t1-notebook-dev-alb) |
| Target Groups | [dmc-1-t1-notebook-dev](https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#TargetGroups:search=dmc-1-t1-notebook-dev) |
| VPC | [dmc-1-t1-notebook-dev](https://eu-north-1.console.aws.amazon.com/vpc/home?region=eu-north-1#vpcs:search=dmc-1-t1-notebook-dev) |

**Безопасность**

| Страница | Ссылка |
|----------|--------|
| Secrets Manager | [Secrets Manager](https://eu-north-1.console.aws.amazon.com/secretsmanager/listsecrets?region=eu-north-1) |

---

## Prod

### Приложение

> **HTTPS (CloudFront)** — основная точка входа.
>
> HTTPS URL: `cd infra/envs/prod && terraform output cloudfront_domain_name`

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
| Сервисы кластера | [dmc-1-t1-notebook-prod](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-prod/services?region=eu-north-1) |
| Логи API | [/ecs/dmc-1-t1-notebook-api-prod](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-api-prod) |
| Логи UI | [/ecs/dmc-1-t1-notebook-ui-prod](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-ui-prod) |
| Логи ADOT | [/ecs/dmc-1-t1-notebook-adot-prod](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-adot-prod) |
| Logs Insights | [API prod](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:logs-insights$3FqueryDetail$3D~(end~0~start~-3600~timeType~'RELATIVE~unit~'seconds~editorString~'fields*20*40timestamp*2c*20level*2c*20message*2c*20trace_id*0a*7c*20sort*20*40timestamp*20desc*0a*7c*20limit*2020~isLiveTail~false~queryId~''~source~(~'*2fecs*2fdmc-1-t1-notebook-api-prod))) |
| Трейсы X-Ray | [Traces](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#xray:traces/query) |

**База данных**

| Страница | Ссылка |
|----------|--------|
| RDS instance | [dmc-1-t1-notebook-prod-db](https://eu-north-1.console.aws.amazon.com/rds/home?region=eu-north-1#database:id=dmc-1-t1-notebook-prod-db;is-cluster=false) |

**Сеть и балансировка**

| Страница | Ссылка |
|----------|--------|
| ALB | [dmc-1-t1-notebook-prod-alb](https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#LoadBalancers:search=dmc-1-t1-notebook-prod-alb) |
| Target Groups | [dmc-1-t1-notebook-prod](https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#TargetGroups:search=dmc-1-t1-notebook-prod) |
| VPC | [dmc-1-t1-notebook-prod](https://eu-north-1.console.aws.amazon.com/vpc/home?region=eu-north-1#vpcs:search=dmc-1-t1-notebook-prod) |

**Безопасность**

| Страница | Ссылка |
|----------|--------|
| Secrets Manager | [Secrets Manager](https://eu-north-1.console.aws.amazon.com/secretsmanager/listsecrets?region=eu-north-1) |

---

## PR Previews

UI-превью для каждого открытого PR в `dmc-1-t1-notebook-ui`.
API-запросы проксируются через CloudFront на dev ALB (общая база данных с dev).

### Ссылки

| Страница | Ссылка |
|----------|--------|
| CloudFront Distributions | [Distributions](https://us-east-1.console.aws.amazon.com/cloudfront/v4/home#/distributions) |
| S3 Bucket (файлы превью) | [dmc-1-t1-notebook-previews](https://s3.console.aws.amazon.com/s3/buckets/dmc-1-t1-notebook-previews?region=eu-north-1) |

### Как найти превью конкретного PR

URL превью всегда есть в комментарии к PR — обновляется автоматически при каждом коммите.

Формат: `https://{CF_DOMAIN}/pr-{N}/`

Актуальный `CF_DOMAIN` хранится в [GHA Variables](./github-actions.md#preview-previewyml) репо `dmc-1-t1-notebook-ui`.
