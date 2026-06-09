# Инфраструктура AWS

Все ресурсы описаны на примере `dev` окружения. `prod` окружение создаётся по той же схеме с суффиксом `-prod`.

Регион: `eu-north-1`. Управляется через Terraform в `infra/`.

Схема сети: [aws-network-diagram.md](./aws-network-diagram.md)

---

## Именование ресурсов

Паттерн: `dmc-1-t1-notebook-{env}-{тип}`

Примеры: `dmc-1-t1-notebook-dev-alb`, `dmc-1-t1-notebook-dev-api`, `dmc-1-t1-notebook-dev-db`

---

## Сеть

| Ресурс | Имя | Параметры |
|--------|-----|-----------|
| VPC | `dmc-1-t1-notebook-dev-vpc` | CIDR 10.0.0.0/16, DNS hostnames включён |
| Публичная подсеть A | `dmc-1-t1-notebook-dev-public-a` | 10.0.1.0/24, eu-north-1a |
| Публичная подсеть B | `dmc-1-t1-notebook-dev-public-b` | 10.0.2.0/24, eu-north-1b |
| Приватная подсеть A | `dmc-1-t1-notebook-dev-private-a` | 10.0.10.0/24, eu-north-1a |
| Приватная подсеть B | `dmc-1-t1-notebook-dev-private-b` | 10.0.11.0/24, eu-north-1b |
| Internet Gateway | `dmc-1-t1-notebook-dev-igw` | — |
| NAT Gateway | `dmc-1-t1-notebook-dev-nat` | В public-a, один на окружение |
| Route Table (public) | `dmc-1-t1-notebook-dev-rt-public` | 0.0.0.0/0 → IGW |
| Route Table (private) | `dmc-1-t1-notebook-dev-rt-private` | 0.0.0.0/0 → NAT GW |

---

## Балансировщик (ALB)

| Ресурс | Имя | Параметры |
|--------|-----|-----------|
| ALB | `dmc-1-t1-notebook-dev-alb` | internet-facing, HTTP:80, public subnets |
| Target Group API | `dmc-1-t1-notebook-dev-api-tg` | port 8000, target type ip, healthcheck /api/v1/health, deregistration_delay 30s |
| Target Group UI | `dmc-1-t1-notebook-dev-ui-tg` | port 80, target type ip, healthcheck /, deregistration_delay 30s |
| Listener | — | port 80, default action → ui-tg |
| Listener Rule (API) | — | /api/v1/* → api-tg, priority 10 |
| Listener Rule (Docs) | — | /docs, /docs/*, /redoc, /openapi.json → api-tg, priority 20 |

---

## Security Groups

| Ресурс | Inbound | Назначение |
|--------|---------|------------|
| `alb-sg` | TCP 80 от 0.0.0.0/0 | Трафик из интернета на ALB |
| `ecs-sg` | TCP 8000 от alb-sg, TCP 80 от alb-sg | Трафик с ALB на контейнеры |
| `rds-sg` | TCP 5432 от ecs-sg | Трафик с ECS на PostgreSQL |
| `bedrock-endpoint-sg` | TCP 443 от ecs-sg | Трафик с ECS на VPC endpoint Bedrock |

---

## ECS (вычисления)

| Ресурс | Имя | Параметры |
|--------|-----|-----------|
| Кластер | `dmc-1-t1-notebook-dev` | Fargate |
| Task Definition API | `dmc-1-t1-notebook-dev-api` | 256 CPU / 512 MB, образ из GHCR |
| Task Definition UI | `dmc-1-t1-notebook-dev-ui` | 256 CPU / 512 MB, образ из GHCR |
| Сервис API | `dmc-1-t1-notebook-dev-api` | desired 1, min healthy 100%, max 200%, private subnets |
| Сервис UI | `dmc-1-t1-notebook-dev-ui` | desired 1, min healthy 100%, max 200%, private subnets |

Образы хранятся в GHCR (`ghcr.io/larchanka-training/...`). При деплое CI/CD регистрирует новую ревизию task definition с `sha-<commit>` тегом.

---

## База данных (RDS)

| Параметр | Значение |
|----------|----------|
| Имя | `dmc-1-t1-notebook-dev-db` |
| Engine | PostgreSQL 15 |
| Instance class | db.t3.micro |
| Storage | 20 GB, gp3 |
| Multi-AZ | нет (Single-AZ) |
| Подсети | приватные |
| Пароль | генерируется Terraform (`random_password`), хранится в Secrets Manager |
| skip_final_snapshot | true (для dev), false (для prod) |

---

## Secrets Manager

| Секрет | Содержимое | Кто записывает |
|--------|-----------|----------------|
| `dmc-1-t1-notebook-dev-db-password` | Полный `DATABASE_URL` для подключения к RDS | Terraform при apply |
| `dmc-1-t1-notebook-dev-ghcr-credentials` | JSON `{"username":"...","password":"..."}` — PAT для pull образов из GHCR | Вручную через workflow |

Подробнее: [secrets-management.md](./secrets-management.md)

---

## IAM

| Ресурс | Назначение |
|--------|-----------|
| `dmc-1-t1-notebook-dev-ecs-execution-role` | Роль для ECS task execution (pull образов, запись логов, чтение секретов) |
| `AmazonECSTaskExecutionRolePolicy` | Managed policy: базовые права ECS execution |
| `dmc-1-t1-notebook-dev-ecs-secrets-policy` | Inline policy: `secretsmanager:GetSecretValue` на оба секрета |
| `dmc-1-t1-notebook-dev-ecs-task-role` | Роль для работающих контейнеров (X-Ray, Bedrock) |
| `dmc-1-t1-notebook-dev-ecs-xray-policy` | Inline policy: запись трейсов в X-Ray |
| `dmc-1-t1-notebook-dev-ecs-bedrock-policy` | Inline policy: `bedrock:InvokeModel`, `bedrock:Converse` и stream-варианты |
| `dmc-1-t1-notebook-prod-bedrock-logging-role` | Роль для Bedrock → CloudWatch (только prod, account-scoped) |

---

## CloudWatch

| Log Group | Содержимое | Окружение |
|-----------|-----------|-----------|
| `/ecs/dmc-1-t1-notebook-api-dev` | Логи API контейнера (FastAPI) | dev + prod |
| `/ecs/dmc-1-t1-notebook-ui-dev` | Логи UI контейнера (Nginx) | dev + prod |
| `/ecs/dmc-1-t1-notebook-adot-dev` | Логи ADOT Collector sidecar | dev + prod |
| `/aws/bedrock/dmc-1-t1-notebook-prod` | Все вызовы Bedrock моделей (invocation logging) | prod only |

Retention: 7 дней для всех групп.

---

## Bedrock / AI

Трафик к AWS Bedrock идёт через VPC Interface Endpoint — не через NAT/интернет.

| Ресурс | Имя | Параметры |
|--------|-----|-----------|
| VPC Endpoint | `dmc-1-t1-notebook-dev-bedrock-runtime-endpoint` | Interface, `bedrock-runtime`, private DNS enabled |
| Security Group | `dmc-1-t1-notebook-dev-bedrock-endpoint-sg` | TCP 443 только от ecs-sg |

**Credentials:** ECS task role. Контейнеры получают доступ к Bedrock автоматически через IAM, без явных ключей.

**Модели (конфигурируются через `BEDROCK_MODEL_ID`):**

| Окружение | Модель | Причина |
|-----------|--------|---------|
| dev | `amazon.nova-lite-v1:0` | Быстрее и дешевле |
| prod | `amazon.nova-pro-v1:0` | Выше качество генерации |

Amazon Nova модели не требуют ручной активации — включаются автоматически при первом вызове.

**Invocation logging (prod only):** все вызовы моделей пишутся в CloudWatch (`/aws/bedrock/dmc-1-t1-notebook-prod`). Конфигурация — account-scoped ресурс, создаётся только в prod, чтобы не конфликтовать при shared account.

---

## PR Preview (dev-only)

Ресурсы не привязаны к конкретному окружению. Создаются один раз из `infra/envs/dev/main.tf`.
Preview работает с живым dev ALB: запросы `/api/v1/*` проксируются через CloudFront на dev ALB.

| Ресурс | Имя | Параметры |
|--------|-----|-----------|
| S3 Bucket | `dmc-1-t1-notebook-previews` | Приватный, Lifecycle 7 дней |
| CloudFront OAC | `dmc-1-t1-notebook-preview-oac` | sigv4, для S3 origin |
| CloudFront Function | `dmc-1-t1-notebook-preview-spa-rewrite` | viewer-request, rewrite `/pr-N/path` → `/pr-N/index.html` |
| CloudFront Distribution | см. `terraform output preview_cf_domain` | HTTPS, два origin: S3 (статика) + dev ALB (`/api/v1/*`) |

**Routing в CloudFront:**
- `/api/v1/*` → dev ALB (HTTP, без кэша)
- `/*` → S3 (статика, SPA rewrite function)

---

## Terraform State

| Ресурс | Параметры |
|--------|-----------|
| S3 Bucket | `dmc-1-t1-notebook-terraform-state`, versioning включён |
| DynamoDB Table | `dmc-1-t1-notebook-terraform-lock` (state locking) |
| State файл dev | `dev/terraform.tfstate` |
| State файл prod | `prod/terraform.tfstate` |
