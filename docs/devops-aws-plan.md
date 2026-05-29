# DevOps AWS — план и принятые решения

Документ фиксирует архитектурные решения по развёртыванию проекта на Amazon Web Services.
Обновлён в Sprint 2 (Tech Lead, май 2026) в рамках issue #76.

---

## Статус реализации

| Компонент | Статус |
|---|---|
| Terraform state: S3 bucket | ✅ Создан (`dmc-1-t1-notebook-terraform-state`, eu-north-1, versioning включён) |
| Terraform state: DynamoDB lock | ✅ Создан (`dmc-1-t1-notebook-terraform-lock`) |
| AWS credentials (GitHub Actions) | ✅ Org-level secrets настроены организаторами (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) |
| Terraform код (`mono/infra/`) | ✅ Bootstrap структура создана |
| ECS кластеры dev + prod | ⏳ Terraform Sub-task 2+3 |
| RDS PostgreSQL dev + prod | ⏳ Terraform Sub-task 3 |
| GitHub Actions deploy | ⏳ Sub-tasks 4-6 |
| Preview per PR (UI-only, S3+CloudFront) | 🔜 Последняя очередь |

---

## 1. Платформа: ECS Fargate

**Решение:** Контейнеры запускаются на Amazon ECS с типом запуска Fargate.

**Стратегия деплоя:** Rolling Update (не Blue-Green — явно ограничено в рамках курса).

- `deployment_minimum_healthy_percent = 50`
- `deployment_maximum_percent = 200`

**Почему Fargate:** Serverless-контейнеры — не нужно управлять EC2 инстансами. Платим только за время работы контейнера.

---

## 2. Container Registry: GHCR

**Решение:** Образы остаются в GitHub Container Registry (GHCR). Переезд на Amazon ECR — отдельная задача будущего спринта.

**Текущие image names:**
- API: `ghcr.io/larchanka-training/dmc-1-t1-notebook-api:latest`
- UI: `ghcr.io/larchanka-training/dmc-1-t1-notebook-ui:latest`

**Важно для ECS:** Task Definition должен содержать `repositoryCredentials` — ARN секрета в Secrets Manager с GitHub PAT (`read:packages`) в формате `{"username":"...", "password":"..."}`.

---

## 3. Окружения

Два окружения, каждое со своим ECS Cluster, ECS Services и RDS инстансом:

| Окружение | Триггер деплоя | Назначение |
|---|---|---|
| `dev` | Push в `main` (автоматически) | Проверка что деплой работает |
| `prod` | `workflow_dispatch` или тег `v*` (вручную) | Production |

---

## 4. Инфраструктура как код: Terraform

**Расположение:** `dmc-1-t1-notebook-mono/infra/`

**Структура:**
```
infra/
  modules/
    environment/      # переиспользуемый модуль (ECS, RDS, Secrets Manager)
  envs/
    dev/              # вызывает modules/environment
    prod/
  shared/             # VPC, subnets, ALB (общие для dev и prod)
```

**Backend (S3 + DynamoDB):**
```hcl
terraform {
  backend "s3" {
    bucket         = "dmc-1-t1-notebook-terraform-state"
    key            = "dev/terraform.tfstate"   # или prod/
    region         = "eu-north-1"
    dynamodb_table = "dmc-1-t1-notebook-terraform-lock"
    encrypt        = true
  }
}
```

---

## 5. Сетевая инфраструктура (`infra/shared/`)

- `aws_vpc` — CIDR `10.0.0.0/16`
- 2 public subnets (eu-north-1a, eu-north-1b) — для ALB
- 2 private subnets — для ECS Tasks и RDS
- Internet Gateway + Route Tables
- Security Groups: ALB (80 inbound), ECS (от ALB), RDS (от ECS)
- Application Load Balancer (internet-facing, port 80)
- Path-based routing: `/api/v1/*` → API Target Group, `/*` → UI Target Group

**Доступ:** ALB DNS имя (`xxx.eu-north-1.elb.amazonaws.com`) — без домена и Route53.

---

## 6. Модуль окружения (`infra/modules/environment/`)

Параметризован через `var.environment` (`dev` / `prod`).

**ECS:**
- `aws_ecs_cluster`
- `aws_ecs_task_definition` для API (CPU 256, Memory 512) и UI (CPU 256, Memory 256)
- `aws_ecs_service` для API и UI с Rolling Update
- `aws_iam_role` для ECS Task Execution

**База данных:**
- `aws_db_instance` — PostgreSQL 15, `db.t3.micro`, Single-AZ, 20GB gp2, `skip_final_snapshot = true`
- `aws_db_subnet_group` — private subnets

**Секреты:**
- `aws_secretsmanager_secret` — DB password (генерируется через `random_password`)
- `aws_secretsmanager_secret` — GitHub PAT для pull из GHCR

**Логи:**
- `aws_cloudwatch_log_group` для API и UI

---

## 7. GitHub Actions — CI/CD Pipeline

### Аутентификация в AWS: Organization Secrets

**Решение:** Использовать org-level Access Keys, которые организаторы курса уже настроили для всей организации `larchanka-training`. Секреты автоматически доступны во всех репозиториях — дополнительной настройки не требуется.

**Org-level secrets (уже настроены организаторами):**
- `AWS_ACCESS_KEY_ID` — доступен во всех репо организации
- `AWS_SECRET_ACCESS_KEY` — доступен во всех репо организации

**Конфигурация в workflow:**
```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: eu-north-1
```

Регион хардкодится в workflow — он единственный и не меняется.

**Что покрывают эти credentials:**
- `aws ecs update-service` — деплой на ECS
- `terraform apply` — создание инфраструктуры
- `aws s3 sync` — будущие preview деплои

Docker образы пушатся в GHCR через `GITHUB_TOKEN` — AWS credentials для этого не нужны.

### Деплой на dev (автоматический)

Job `deploy-dev` добавляется в существующий `ci-cd.yml` API и UI репозиториев:

```yaml
deploy-dev:
  needs: [build]
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
        aws-region: ${{ secrets.AWS_REGION }}
    - run: |
        aws ecs update-service \
          --cluster dmc-1-t1-notebook-dev \
          --service dmc-1-t1-notebook-api-dev \
          --force-new-deployment
```

### Деплой на prod (ручной)

Отдельный workflow `deploy-prod.yml` в mono репо. Триггер: `workflow_dispatch` (приоритет) или тег `v*`.

### Оптимизация кэша сборок

В `docker/build-push-action@v7` обоих репозиториев:
```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

Ускоряет повторные сборки на 60–80%, бесплатно через GitHub Actions cache.

---

## 8. Полный CI/CD pipeline (push в `main`)

```
push → lint + test
           ↓
       build image → push to GHCR
           ↓
       OIDC: assume role/github-actions (временные credentials)
           ↓
       deploy-dev: aws ecs update-service --force-new-deployment
           ↓
       ECS Rolling Update (старый контейнер жив пока новый не healthy)
```

---

## 9. Preview per PR (отложено)

Реализовать в последнюю очередь после стабилизации dev/prod деплоя.

**Подход:** UI-only preview через S3 + CloudFront.

- Workflow на `pull_request` (opened, synchronize)
- `npm run build` → `aws s3 sync dist/ s3://dmc-1-t1-notebook-previews/pr-<number>/`
- GitHub Actions оставляет комментарий в PR с URL
- При закрытии PR: `aws s3 rm` папки

---

## 10. Dockerfile (уже исправлено)

Оба Dockerfile уже production-ready:

- **API:** использует `fastapi run` (не `fastapi dev`)
- **UI:** multi-stage build (builder → nginx:alpine)

`docker-compose.yaml` в mono репо переопределяет CMD для локальной разработки — hot reload не пострадал.

---

## Что НЕ в скоупе текущего спринта

- ~~Blue-Green Deployment~~ — явно ограничено организаторами курса
- ADOT sidecar + AWS X-Ray — отдельная задача
- AppConfig Feature Flags — отдельная задача
- Alembic миграции — после стабилизации деплоя
- ECR вместо GHCR — отдельный PR
- CloudWatch Alarms + SNS — после стабилизации деплоя
- Route53 + домен — не нужно, достаточно ALB DNS
