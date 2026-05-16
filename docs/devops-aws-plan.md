# DevOps AWS — план и принятые решения

Документ фиксирует архитектурные решения по развёртыванию проекта на Amazon Web Services.
Принят в ходе технического интервью (Sprint DevOps, май 2026).

---

## 1. Платформа: ECS Fargate

**Решение:** Запускать контейнеры на Amazon ECS с типом запуска Fargate.

**Почему:** Оптимальный баланс между управляемостью и гибкостью для проекта на начальной стадии. EKS (Kubernetes) избыточен — требует отдельного человека для поддержки кластера. App Runner слишком ограничен для Blue-Green деплоев. ECS Fargate нативно поддерживает CodeDeploy Blue-Green и интегрируется с CloudWatch без изменений в коде.

---

## 2. Container Registry: Amazon ECR

**Решение:** Переключить CI/CD пайплайн с GHCR на Amazon ECR для production-образов. GHCR остаётся опцией для локальной разработки.

**Почему:** IAM-роль ECS Task автоматически имеет доступ к ECR без хранения дополнительных секретов. CodeDeploy Blue-Green требует доступа к образу в момент деплоя — с GHCR пришлось бы пробрасывать токен в Task Definition, который протухает каждые 24 часа.

**Изменения в CI** (`ci-cd.yml` в обоих репозиториях):

```yaml
# было
REGISTRY: ghcr.io
IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/dmc-1-t1-notebook-api

# станет
REGISTRY: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ secrets.AWS_REGION }}.amazonaws.com
IMAGE_NAME: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ secrets.AWS_REGION }}.amazonaws.com/dmc-1-t1-notebook-api
```

---

## 3. Blue-Green Deployment

**Решение:** AWS CodeDeploy + Application Load Balancer. Два target group (blue/green), трафик переключается через ALB.

### 3.1 Стратегия переключения трафика

**Решение:** `ECSCanary10Percent5Minutes` для production. Стратегия конфигурируется через переменную окружения, чтобы разные среды могли использовать разные подходы.

| Среда | Стратегия | Причина |
|---|---|---|
| `prod` | `ECSCanary10Percent5Minutes` | 10% трафика на новую версию, 5 минут наблюдения, затем 100% |
| `uat` | `AllAtOnce` | QA-команда должна сразу тестировать полную версию |

**Почему Canary для prod:** При ошибке в новой версии она затронет только 10% пользователей, а не всех. `AllAtOnce` убирает весь смысл Blue-Green. `Linear` слишком медленный для небольшой команды.

### 3.2 Автоматический откат

**Решение:** CloudWatch Alarm триггерит автоматический откат через CodeDeploy при превышении порога ошибок.

**Базовые алармы:**

| Аларм | Метрика | Порог |
|---|---|---|
| Деплой сломан | HTTP 5xx rate | > 5% за 5 минут |
| API недоступен | ECS HealthCheck failures | > 2 подряд |
| БД перегружена | RDS CPU / DB connections | > 80% |
| Память контейнера | ECS MemoryUtilization | > 85% |

**Почему автоматически, не вручную:** Ручной откат требует дежурного, который мониторит каждый деплой. Для учебного проекта это нереально. Автоматика срабатывает быстрее и без участия человека.

---

## 4. Feature Flags: AWS AppConfig

**Решение:** Использовать AWS AppConfig (часть Systems Manager) для управления флагами функциональности.

**Почему AppConfig, не Unleash:** Unleash требует поддерживать ещё один сервис и его базу данных. AppConfig — managed-сервис, интегрируется с IAM, не требует отдельной инфраструктуры, стоит копейки при малом трафике. Поддерживает targeting по атрибутам пользователя (в т.ч. `userId` и/или `tenantId`).

### 4.1 Интеграция с кодом

**Решение:** API читает флаги из AppConfig, кэширует (TTL 45 секунд, рекомендация AppConfig Agent), отдаёт UI через отдельный endpoint.

**Endpoint:** `GET /api/v1/feature-flags`

**Формат ответа:**
```json
{
  "js-execution-v2": true,
  "markdown-preview": false
}
```

**Почему API + UI, не только API:** Для крупных фич (новый тип ячейки, новый режим) правильнее скрывать их на уровне UI, чем ждать ошибку 404 от API. Пользователь не должен видеть кнопки, которые не работают.

---

## 5. Observability: OTEL + Logs + Metrics

### 5.1 ADOT Collector как sidecar

**Решение:** AWS Distro for OpenTelemetry (ADOT) Collector запускается как sidecar-контейнер в том же ECS Task, что и API.

**Почему без изменений в коде:** API уже использует стандартный OTLP gRPC (`telemetry.py`). ADOT принимает тот же протокол. Достаточно сменить одну env-переменную:

```bash
# локально (Aspire Dashboard)
OTEL_ENDPOINT=http://aspire-dashboard:18889

# AWS (ADOT sidecar)
OTEL_ENDPOINT=http://localhost:4317
```

ADOT пересылает данные в CloudWatch Logs, CloudWatch Metrics и AWS X-Ray.

### 5.2 Алерты

**Решение:** CloudWatch Alarms → SNS → Email команды.

**Почему Email:** Slack/Discord-среда для командной работы ещё не настроена. Email — минимальная рабочая конфигурация. При появлении корпоративного мессенджера SNS легко перенастроить на Webhook.

---

## 6. База данных: миграции

### 6.1 Инструмент: Alembic

**Решение:** Добавить Alembic в `requirements.txt` API для управления миграциями схемы PostgreSQL.

**Почему Alembic:** Стандарт де-факто для Python + PostgreSQL. Версионированные файлы миграций, поддержка `upgrade`/`downgrade`, легко запускается как отдельный шаг в пайплайне.

### 6.2 Запуск миграций: отдельный ECS Task

**Решение:** Миграции запускаются как отдельный ECS Task (`alembic upgrade head`) в CI/CD пайплайне **до** деплоя нового сервиса.

**Почему не внутри контейнера при старте:** При Blue-Green одновременно живут два контейнера API (blue + green). Если каждый запускает миграцию при старте — возникает race condition, который может повредить данные. Отдельный Task гарантирует выполнение ровно один раз.

### 6.3 Правила написания миграций: Expand-Contract

**Решение:** Обязательный паттерн для всех миграций, которые затрагивают существующие данные.

**Запрещено в одном деплое с кодом:**

```sql
-- Переименование — сломает старый код (Blue-версия читает старое имя)
ALTER TABLE users RENAME COLUMN old_name TO new_name;

-- NOT NULL без default — сломает INSERT из старого кода
ALTER TABLE cells ADD COLUMN type VARCHAR NOT NULL;

-- DROP — сломает всё немедленно
ALTER TABLE users DROP COLUMN legacy_field;
```

**Правильно — три шага в трёх отдельных деплоях:**

1. **Expand:** добавить новую колонку (nullable или с default) — старый код не замечает
2. **Migrate:** новый код пишет в обе колонки, backfill существующих данных
3. **Contract:** удалить старую колонку, когда старого кода нет в production

**Почему это критично:** Blue-Green означает, что старая и новая версия кода работают с одной базой одновременно во время переключения трафика. Нарушение этих правил гарантированно ломает production в момент деплоя.

---

## 7. Исправления в Dockerfile (блокеры для production)

### 7.1 API: `fastapi dev` → `fastapi run`

**Файл:** `dmc-1-t1-notebook-api/Dockerfile`

```dockerfile
# было (dev-сервер с hot reload — не для production)
CMD ["fastapi", "dev", "app/main.py", "--host", "0.0.0.0", "--port", "8000"]

# должно быть
CMD ["fastapi", "run", "app/main.py", "--host", "0.0.0.0", "--port", "8000"]
```

**Локальная разработка не пострадает:** `docker-compose.yaml` уже переопределяет CMD своим `command: fastapi dev ...`, поэтому hot reload в Mono репозитории продолжит работать.

### 7.2 UI: multi-stage build вместо dev-сервера

**Файл:** `dmc-1-t1-notebook-ui/Dockerfile`

```dockerfile
# было (Vite dev-сервер — не для production)
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]

# должно быть — multi-stage build
FROM node:20-slim AS builder
WORKDIR /home/app
COPY package*.json ./
RUN npm ci --prefer-offline
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /home/app/dist /usr/share/nginx/html
EXPOSE 80
```

**Локальная разработка не пострадает:** docker-compose переопределяет CMD через `command:` и монтирует volume для hot reload.

---

## 8. Секреты: AWS Secrets Manager

**Решение:** Все секреты (DB password, OAuth Client ID/Secret) хранятся в AWS Secrets Manager. ECS Task Definition ссылается на ARN секрета — ECS сам инжектирует значение в env var контейнера.

**Почему не plain env vars:** Секреты в env vars видны в консоли AWS, в логах и в коде CI. Secrets Manager решает это: значение никогда не покидает защищённое хранилище в открытом виде. Ротация credentials при компрометации происходит без передеплоя.

**Что переносится в Secrets Manager:**

| Переменная | Тип |
|---|---|
| `POSTGRES_PASSWORD` | Secret |
| `OAUTH_CLIENT_SECRET` | Secret |
| `OAUTH_CLIENT_ID` | Secret |
| `DATABASE_URL` | Secret (содержит пароль) |

Нечувствительные переменные (`APP_ENV`, `API_PREFIX`, `OTEL_SERVICE_NAME` и т.д.) остаются обычными env vars в Task Definition.

---

## Итоговый CI/CD пайплайн (при мерже в `main`)

```
PR → lint + test
        ↓
merge → build image → push to ECR
        ↓
Run Migration ECS Task (alembic upgrade head)
        ↓
CodeDeploy: Blue-Green (ECSCanary10Percent5Minutes)
  10% трафика → новая версия (5 мин наблюдение)
        ↓
CloudWatch Alarm OK? → 100% трафика на новую версию
CloudWatch Alarm FAIL? → автоматический откат на старую версию
```
