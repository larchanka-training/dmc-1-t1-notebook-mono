# Disaster Recovery Runbook

> Issue [#175](https://github.com/larchanka-training/js-notebook/issues/175) — DevOps Disaster Recovery Plan

Дата: 2026-06-28

## Обзор

Документ описывает сценарии восстановления для JavaScript Notebook платформы, развёрнутой в AWS (регион `eu-north-1`).

### Архитектура (кратко)

```
CloudFront (HTTPS) → ALB (HTTP) → ECS Fargate (API + UI)
                                    │
                         ┌──────────┴──────────┐
                         ▼                     ▼
                    RDS PostgreSQL        AWS Bedrock
                  (private subnets)     (VPC endpoint)
```

### Ключевые ресурсы

| Ресурс | Имя (dev/prod) | Тип |
|--------|----------------|-----|
| RDS | `dmc-1-t1-notebook-{env}-db` | PostgreSQL 16, db.t3.micro |
| ECS API | `dmc-1-t1-notebook-{env}-api` | Fargate, 0.25 vCPU, 1 GB |
| ECS UI | `dmc-1-t1-notebook-{env}-ui` | Fargate, 0.25 vCPU, 0.5 GB |
| ALB | `dmc-1-t1-notebook-{env}-alb` | Application Load Balancer |
| CloudFront | `*.cloudfront.net` | HTTPS termination |
| Secrets Manager | `dmc-1-t1-notebook-{env}-*` | JWT secret, DB password, GHCR |
| S3 (terraform state) | `dmc-1-t1-notebook-terraform-state` | Infra state |
| S3 (previews) | `dmc-1-t1-notebook-previews` | PR preview static files |

### RTO / RPO цели

| Сценарий | RTO (цель) | RPO (цель) |
|----------|-----------|-----------|
| Падение API | 5 мин | 0 (stateless) |
| Потеря БД | 30 мин | 24 ч (backup) |
| Падение региона | 2 ч | 24 ч |
| Утечка ключей | 15 мин | 0 |
| Bedrock budget | 1 ч | 0 |

> RTO — Recovery Time Objective (время восстановления).
> RPO — Recovery Point Objective (максимальная потеря данных).

---

## 1. Потеря базы данных (RDS)

### Симптомы

- Health check `/api/v1/health/db` возвращает HTTP 503
- API логи: `OperationalError`, `ConnectionRefusedError`, `database connection failed`
- ECS API task перезапускается (health check fail → kill → restart)
- UI: запросы к API возвращают 500

### Причины

- Аппаратный сбой RDS инстанса
- Corruption данных
- Случайное удаление (DROP TABLE, DELETE без WHERE)
- Maintenance window с отказом

### Восстановление

#### 1.1. Single-AZ отказ (текущая конфигурация)

```bash
# 1. Проверить статус RDS
aws rds describe-db-instances \
  --db-instance-identifier dmc-1-t1-notebook-prod-db \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Class:DBInstanceClass,AZ:AvailabilityZone}'

# 2. Если статус "available" но БД повреждена — восстановить из snapshot
# Найти последний snapshot:
aws rds describe-db-snapshots \
  --db-instance-identifier dmc-1-t1-notebook-prod-db \
  --query 'DBSnapshots[-1].{ID:DBSnapshotIdentifier,Created:SnapshotCreateTime}'

# 3. Восстановить из snapshot (создаёт новый инстанс)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier dmc-1-t1-notebook-prod-db-restored \
  --db-snapshot-identifier <snapshot-id> \
  --db-instance-class db.t3.micro \
  --no-multi-az

# 4. Обновить DATABASE_URL в Secrets Manager на новый endpoint
aws secretsmanager put-secret-value \
  --secret-id dmc-1-t1-notebook-prod-db-password \
  --secret-string 'postgresql://postgres:<пароль>@<новый-endpoint>/notebook'

# 5. Форсировать деплой API для подхвата нового секрета
# Через AWS Console: ECS → сервис api → Force new deployment

# 6. Удалить старый инстанс
aws rds delete-db-instance \
  --db-instance-identifier dmc-1-t1-notebook-prod-db \
  --skip-final-snapshot
```

#### 1.2. Предотвращение (рекомендации)

| Действие | Приоритет | Эффект |
|----------|-----------|--------|
| Включить Multi-AZ для prod | High | Автоматический failover < 60 сек |
| Включить automated backups (retention 7 дней) | High | Point-in-time recovery |
| Включить `skip_final_snapshot = false` для prod | Medium | Snapshot при удалении |
| Добавить read replica | Low | Отказоустойчивость + read scaling |

---

## 2. Падение API (ECS)

### Симптомы

- Health check `/api/v1/health` не отвечает или возвращает 5xx
- ALB Target Group: `unhealthy`
- ECS: task status `STOPPED` или циклический restart
- CloudWatch Logs: ошибки запуска, OOM, crash

### Причины

- OOM (out of memory) — 1 GB RAM может быть недостаточно
- Падение при старте (невалидный env var, отсутствующий секрет)
- Баг в коде (unhandled exception в startup)
- Закончились ECR credentials (GHCR PAT истёк)

### Восстановление

#### 2.1. Быстрое восстановление (rollback)

```bash
# 1. Проверить статус сервиса
aws ecs describe-services \
  --cluster dmc-1-t1-notebook-prod \
  --services dmc-1-t1-notebook-prod-api \
  --query 'services[0].{Desired:desiredCount,Running:runningCount,Deployments:deployments[*].{Status:status,Rollback:rollback,targetCount:taskCount}}'

# 2. Откатиться на предыдущую ревизию task definition
# Найти последние ревизии:
aws ecs list-task-definitions \
  --family-prefix dmc-1-t1-notebook-prod-api \
  --sort DESC --max-items 5

# 3. Обновить сервис на предыдущую ревизию
aws ecs update-service \
  --cluster dmc-1-t1-notebook-prod \
  --service dmc-1-t1-notebook-prod-api \
  --task-definition dmc-1-t1-notebook-prod-api:<предыдущая-ревизия>

# 4. Дождаться стабилизации
aws ecs wait services-stable \
  --cluster dmc-1-t1-notebook-prod \
  --services dmc-1-t1-notebook-prod-api
```

#### 2.2. OOM — увеличить ресурсы

```bash
# Обновить task definition с большим memory
# Через Terraform: изменить variables в infra/envs/prod/terraform.tfvars
# api_cpu = 512    # 0.5 vCPU
# api_memory = 2048  # 2 GB
# Затем: terraform apply
```

#### 2.3. Истёкший GHCR PAT

```bash
# 1. Создать новый Classic PAT на GitHub с read:packages
# 2. Обновить секрет
aws secretsmanager put-secret-value \
  --secret-id dmc-1-t1-notebook-prod-ghcr-credentials \
  --secret-string '{"username":"CroixANI","password":"<новый PAT>"}'

# 3. Форсировать деплой
aws ecs update-service \
  --cluster dmc-1-t1-notebook-prod \
  --service dmc-1-t1-notebook-prod-api \
  --force-new-deployment
```

### Предотвращение

| Действие | Приоритет | Эффект |
|----------|-----------|--------|
| CloudWatch alarm на `unhealthy` hosts | High | Proactive alerting |
| Auto-scaling policy (CPU > 70%) | Medium | Автоматическое масштабирование |
| Memory limit alert (memory > 80%) | Medium | Предупреждение OOM |
| Health check grace period 60s | Low | Избежать false negative при старте |

---

## 3. Падение AWS региона

### Симптомы

- Все сервисы недоступны (CloudFront → ALB → ECS — всё в `eu-north-1`)
- AWS Health Dashboard сообщает о региональном инциденте

### Восстановление

#### 3.1. Текущая стратегия: ожидание

Проект развёрнут в одном регионе (`eu-north-1`). Multi-region не реализован.

**Действия:**
1. Проверить [AWS Health Dashboard](https://health.aws.amazon.com/health/status)
2. Если инцидент подтверждён — ждать восстановления AWS
3. После восстановления — проверить health checks:
   ```
   https://d3kjnujjg7beoo.cloudfront.net/api/v1/health
   https://d3kjnujjg7beoo.cloudfront.net/api/v1/health/db
   ```
4. При необходимости — форсировать деплой обоих сервисов

#### 3.2. Стратегия multi-region (будущее)

| Шаг | Описание | Сложность |
|-----|----------|-----------|
| 1 | Дублировать Terraform в `eu-central-1` | Средняя |
| 2 | RDS cross-region read replica | Средняя |
| 3 | Route 53 health checks + failover routing | Высокая |
| 4 | CloudFront с multi-origin | Средняя |
| 5 | S3 cross-region replication для previews | Низкая |

> Multi-region не реализован в рамках учебного курса. Документирован как future work.

---

## 4. Утечка ключей / секретов

### Симптомы

- JWT secret скомпрометирован (утечка в логи, коммит в git, доступ третьих лиц)
- GHCR PAT скомпрометирован
- AWS access key скомпрометирован

### Восстановление

#### 4.1. JWT secret

```bash
# 1. Сгенерировать новый секрет
openssl rand -hex 32

# 2. Обновить в Secrets Manager
aws secretsmanager put-secret-value \
  --secret-id dmc-1-t1-notebook-prod-jwt-secret \
  --secret-string '<новый-секрет>'

# 3. Форсировать деплой API
aws ecs update-service \
  --cluster dmc-1-t1-notebook-prod \
  --service dmc-1-t1-notebook-prod-api \
  --force-new-deployment

# 4. Результат: все существующие JWT токены становятся невалидными.
#    Пользователи должны заново login. Refresh tokens тоже невалидны
#    (сессии в БД подписаны старым секретом — проверка не пройдёт).
```

#### 4.2. GHCR PAT

```bash
# 1. Отозвать старый PAT на GitHub (Settings → Developer settings → Personal access tokens)
# 2. Создать новый Classic PAT с read:packages
# 3. Обновить секрет
aws secretsmanager put-secret-value \
  --secret-id dmc-1-t1-notebook-prod-ghcr-credentials \
  --secret-string '{"username":"CroixANI","password":"<новый PAT>"}'

# 4. Форсировать деплой обоих сервисов
```

#### 4.3. AWS Access Key

```bash
# 1. В AWS IAM — deactivate старый key
aws iam update-access-key --access-key-id <OLD_KEY> --status Inactive

# 2. Создать новый key
aws iam create-access-key --user-name <iam-user>

# 3. Обновить GitHub Secrets:
#    AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (org-level)
#    Settings → Secrets and variables → Actions

# 4. Отозвать старый key
aws iam delete-access-key --access-key-id <OLD_KEY> --user-name <iam-user>

# 5. Проверить CloudTrail на несанкционированные API вызовы
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=<OLD_KEY> \
  --max-results 50
```

### Предотвращение

| Действие | Приоритет | Эффект |
|----------|-----------|--------|
| Rotation JWT secret раз в 90 дней | Medium | Снижение риска |
| GitHub PAT срок 90 дней (уже) | Low | Уже реализовано |
| AWS CloudTrail enabled | Medium | Audit trail |
| Нет секретов в коде (уже) | Low | Уже реализовано |
| Pre-commit hook для secrets scanning | Medium | Предотвращение коммита |

---

## 5. Превышение бюджета Bedrock

### Симптомы

- AWS Billing alert срабатывает
- Bedrock cost превышает месячный бюджет
- API логи: `ThrottlingException` (rate limit превышен)

### Текущие лимиты

| Параметр | Значение | Где настроено |
|----------|----------|---------------|
| Rate limit per user | 10 RPM | `api/app/ai/rate_limit.py` |
| Daily limit per user | 100 RPD | `api/app/ai/rate_limit.py` |
| Max prompt length | 32,000 chars | `api/app/api/v1/endpoints/ai.py:67` |
| Max output tokens | 4,096 | `api/app/ai/bedrock.py` |
| Max retry attempts | 3 | `api/app/ai/bedrock.py` |

### Стоимость (из cost-analysis.md)

| Масштаб | Nova Pro/мес | Nova Lite/мес |
|---------|-------------|--------------|
| 100 users | $432 | $32 |
| 1,000 users | $4,320 | $324 |
| 10,000 users | $43,200 | $3,240 |

### Восстановление

#### 5.1. Экстренная остановка AI

```bash
# Вариант 1: Отключить AI endpoint через env var (если реализовано)
# Установить AI_ENABLED=false и форсировать деплой

# Вариант 2: Заблокировать через Security Group
# Закрыть доступ к VPC endpoint Bedrock
aws ec2 modify-security-group-rules \
  --group-id <bedrock-endpoint-sg-id> \
  --security-group-parameters "IpProtocol=tcp,FromPort=443,ToPort=443,SourceSecurityGroupId=<deny>"
```

#### 5.2. Переключение на Nova Lite

```bash
# 1. Обновить env var
aws ecs update-service \
  --cluster dmc-1-t1-notebook-prod \
  --service dmc-1-t1-notebook-prod-api \
  --task-definition <новая-ревизия-с-BEDROCK_MODEL_ID=amazon.nova-lite-v1:0>

# 2. Или через Terraform:
# В infra/envs/prod/terraform.tfvars:
# bedrock_model_id = "amazon.nova-lite-v1:0"
# terraform apply
```

#### 5.3. Снижение лимитов

```bash
# Уменьшить rate limits через env vars
# AI_RATE_LIMIT_RPM=5 (вместо 10)
# AI_RATE_LIMIT_RPD=50 (вместо 100)
# Форсировать деплой
```

### Предотвращение

| Действие | Приоритет | Эффект |
|----------|-----------|--------|
| AWS Budgets alert (daily + monthly) | High | Early warning |
| Переключение на Nova Lite | High | 93% экономия |
| Hard cap на daily requests (global, не per-user) | Medium | Абсолютный лимит |
| Bedrock invocation logging (уже в prod) | Low | Audit |
| Dashboard: daily Bedrock cost | Medium | Видимость |

---

## 6. Подсчёт лимитов

### Ресурсные лимиты AWS

| Ресурс | Текущий лимит | Утилизация (100 users) | Запас |
|--------|--------------|----------------------|-------|
| ECS Fargate tasks | — | 2 (1 API + 1 UI) | Достаточно |
| RDS connections | db.t3.micro: ~90 | ~10 (asyncpg pool) | 9× |
| ALB connections/sec | — | < 10/sec | Достаточно |
| CloudFront requests | — | < 100/sec | Достаточно |
| Secrets Manager API calls | 10K/sec | < 1/sec (только при старте task) | Достаточно |
| VPC endpoints | — | 1 (Bedrock) | Достаточно |

### Лимиты GitHub

| Ресурс | Лимит | Утилизация | Запас |
|--------|-------|-----------|-------|
| Actions minutes (private repo) | 2,000/мес | ~500/мес | 4× |
| GHCR storage | 0.5 GB | ~200 MB | 2.5× |
| PAT срок действия | 90 дней | — | Обновлять до истечения |

### Лимиты приложения

| Ресурс | Лимит | На кого | Настраивается в |
|--------|-------|---------|-----------------|
| AI requests/min | 10 | per user | `rate_limit.py` |
| AI requests/day | 100 | per user | `rate_limit.py` |
| Prompt length | 32,000 chars | per request | `ai.py:67` |
| Output tokens | 4,096 | per request | `bedrock.py` |
| Retry attempts | 3 | per request | `bedrock.py` |
| Access token TTL | 900 сек (15 мин) | per session | `config.py` |
| Refresh token TTL | 604,800 сек (7 дней) | per session | `config.py` |

### Расчёт пропускной способности

| Масштаб | API RPS (пик) | API tasks | RDS connections | Fargate vCPU |
|---------|-------------|-----------|-----------------|-------------|
| 100 users | ~10 RPS | 1 | ~10 | 0.25 |
| 1,000 users | ~100 RPS | 2 | ~20 | 0.5 |
| 10,000 users | ~1,000 RPS | 5 | ~50 | 1.25 |

> API latency 2-5 ms (без AI), 178 ms (auth). Один Fargate task (0.25 vCPU) выдерживает ~50 RPS. Для 10K users нужно 5 tasks + auto-scaling.

---

## Контакты и эскалация

| Роль | Ответственность | Канал |
|------|----------------|-------|
| DevOps | Инфраструктура, деплой | GitHub issue |
| Tech Lead | Архитектура, код | GitHub issue |
| QA | Верификация после восстановления | GitHub issue |

### Порядок эскалации

1. **Обнаружение** — CloudWatch alarm / пользовательский отчёт
2. **Оценка** — определить сценарий (раздел 1–5)
3. **Действие** — выполнить шаги восстановления
4. **Верификация** — health checks проходят, UI работает
5. **Post-mortem** — создать issue с описанием инцидента и превентивными мерами

---

## Связанные документы

- [AWS инфраструктура](dev-ops/aws-infrastructure.md)
- [Deployment runbook](dev-ops/deployment-runbook.md)
- [Управление секретами](dev-ops/secrets-management.md)
- [Окружения](dev-ops/environments.md)
- [Observability в AWS](dev-ops/observability-aws.md)
- [Cost Analysis](cost-analysis.md)
- [Production Readiness Audit](production-readiness.md)
