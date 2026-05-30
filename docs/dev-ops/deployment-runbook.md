# Операционный справочник

Инструкции для частых задач при работе с dev окружением.

---

## Посмотреть логи контейнера

**Через AWS Console:**

1. Открыть [сервисы ECS](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-dev/services?region=eu-north-1)
2. Кликнуть на сервис (`api` или `ui`)
3. Вкладка **Tasks** → кликнуть на задачу
4. Вкладка **Logs**

**Прямые ссылки на CloudWatch:**
- API: [/ecs/dmc-1-t1-notebook-api-dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-api-dev)
- UI: [/ecs/dmc-1-t1-notebook-ui-dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-ui-dev)

---

## Форсировать новый деплой

Используется когда нужно перезапустить контейнер без нового коммита (например, после обновления секрета).

**Через AWS Console:**
1. ECS → кластер `dmc-1-t1-notebook-dev` → сервис (`api` или `ui`)
2. **Update service** → поставить галочку **Force new deployment** → **Update**

---

## Откатиться на предыдущую версию (rollback)

ECS хранит историю всех ревизий task definition. Каждый деплой создаёт новую ревизию.

**Через AWS Console:**
1. ECS → **Task Definitions** → `dmc-1-t1-notebook-dev-api`
2. Выбрать нужную ревизию (каждая содержит sha-тег образа)
3. **Deploy** → **Update Service** → выбрать кластер и сервис

**Определить нужную ревизию:** в поле `image` каждой ревизии указан `sha-<commit>` — сравни с git log в API/UI репо.

---

## Проверить здоровье приложения

**Базовый health check (API):**
```
http://dmc-1-t1-notebook-dev-alb-1605418557.eu-north-1.elb.amazonaws.com/api/v1/health
```
Ответ: `{"status": "healthy", ...}`

**Проверка подключения к БД:**
```
http://dmc-1-t1-notebook-dev-alb-1605418557.eu-north-1.elb.amazonaws.com/api/v1/health/db
```
Ответ при успехе: `{"status": "healthy", "detail": "database connection successful"}`
Ответ при проблеме: HTTP 503 с описанием ошибки

---

## Обновить GHCR credentials

Нужно при истечении или компрометации PAT.

1. Создать новый Classic PAT на GitHub с правом `read:packages`
2. Создать временный workflow в mono репо (или использовать шаблон из истории):

```yaml
- name: Put GHCR credentials into Secrets Manager
  run: |
    aws secretsmanager put-secret-value \
      --secret-id dmc-1-t1-notebook-dev-ghcr-credentials \
      --secret-string '{"username":"CroixANI","password":"<новый PAT>"}'
```

3. После успешного выполнения — форсировать деплой обоих сервисов (см. выше)
4. Удалить временный workflow

Подробнее: [secrets-management.md](./secrets-management.md)

---

## Перезапустить terraform apply вручную

Если нужно применить изменения инфраструктуры без коммита:

GitHub → mono репо → **Actions** → **Terraform** → **Run workflow** → выбрать `main`

---

## Проверить статус Task Targets в ALB

Если сервис показывает `0/1 Running` или контейнеры не получают трафик:

1. [Target Groups](https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#TargetGroups:search=dmc-1-t1-notebook-dev) → выбрать `api-tg` или `ui-tg`
2. Вкладка **Targets** — статус `healthy` или `unhealthy` с описанием причины
