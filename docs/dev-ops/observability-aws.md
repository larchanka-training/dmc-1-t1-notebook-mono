# Observability в AWS: мониторинг, логи и трейсы

Руководство по наблюдению за приложением в dev и prod окружениях.
Локальная разработка использует Aspire Dashboard — см. [guides/observability.md](../guides/observability.md).

---

## Архитектура

```
API контейнер  ──OTLP gRPC──▶  ADOT Collector  ──▶  AWS X-Ray (трейсы)
     │
     └── stdout (JSON) ──▶  CloudWatch Logs (логи)
```

- **Трейсы** — AWS X-Ray через ADOT Collector sidecar
- **Логи** — CloudWatch Logs, формат JSON с полями `trace_id`, `user_id`, `level`
- **Инфраструктурные метрики** — CloudWatch Container Insights (CPU, память ECS)

Sampling: dev — 100%, prod — 30% (настраивается через `xray_sampling_rate` в Terraform).

---

## Инфраструктурные метрики

### CPU и память ECS контейнеров

| Окружение | Ссылка |
|-----------|--------|
| Dev — сервисы кластера | [ECS Cluster dev](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-dev/services?region=eu-north-1) |
| Prod — сервисы кластера | [ECS Cluster prod](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-prod/services?region=eu-north-1) |

**Как смотреть:** ECS → кластер → сервис `api` → вкладка **Metrics** → графики CPU и Memory utilization.

### RDS

| Окружение | Ссылка |
|-----------|--------|
| Dev | [RDS dev](https://eu-north-1.console.aws.amazon.com/rds/home?region=eu-north-1#database:id=dmc-1-t1-notebook-dev-db;is-cluster=false) |
| Prod | [RDS prod](https://eu-north-1.console.aws.amazon.com/rds/home?region=eu-north-1#database:id=dmc-1-t1-notebook-prod-db;is-cluster=false) |

**Как смотреть:** RDS → база данных → вкладка **Monitoring** → графики CPU, connections, free storage.

---

## Логи в CloudWatch

### Log Groups

| Log Group | Содержимое |
|-----------|-----------|
| `/ecs/dmc-1-t1-notebook-api-dev` | Логи API (dev) |
| `/ecs/dmc-1-t1-notebook-api-prod` | Логи API (prod) |
| `/ecs/dmc-1-t1-notebook-adot-dev` | Логи ADOT Collector (dev) |
| `/ecs/dmc-1-t1-notebook-ui-dev` | Логи UI Nginx (dev) |

Retention: 7 дней. Health check запросы (`/api/v1/health`) отфильтрованы.

### Logs Insights — готовые запросы

Открой [CloudWatch Logs Insights](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:logs-insights), выбери нужный log group и вставь запрос.

**Все ошибки за последний час:**
```
fields @timestamp, level, message, trace_id, user_id
| filter level = "ERROR"
| sort @timestamp desc
| limit 50
```

**Найти все логи по trace_id** (вставить ID из X-Ray без дефисов):
```
fields @timestamp, level, message, name
| filter trace_id = "вставить_32_char_hex"
| sort @timestamp asc
```

**Все логи конкретного пользователя:**
```
fields @timestamp, level, message, trace_id
| filter user_id = "вставить_user_id"
| sort @timestamp desc
| limit 50
```

**Ошибки за последние 24 часа с группировкой по типу:**
```
fields message
| filter level = "ERROR"
| stats count(*) as cnt by name
| sort cnt desc
```

### Как найти trace_id для поиска в логах

Trace ID из X-Ray имеет формат `1-{8hex}-{24hex}`. Для поиска в логах — убрать `1-` и дефис:

```
X-Ray:  1-7614ebc4-230db625f5e4fd8b4f8ee6dc
Логи:   7614ebc4230db625f5e4fd8b4f8ee6dc
```

---

## Трейсы в X-Ray

### Открыть список трейсов

[CloudWatch → Application Signals → Traces](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#xray:traces/query)

> Если страница недоступна из-за прав — используй [прямую ссылку X-Ray](https://eu-north-1.console.aws.amazon.com/xray/home?region=eu-north-1#/traces).

По умолчанию показывает трейсы за последние 5 минут. Для поиска по истории — смени диапазон на **1h** или **3h**.

### Найти медленные запросы

В списке трейсов кликни на заголовок колонки **Duration** — сортировка по времени выполнения. Самые медленные запросы окажутся вверху.

### Найти ошибки

Фильтр по статусу: в поле поиска введи `http.status = 500` или `http.status >= 400`.

### Перейти от трейса к логам

1. Открой трейс → скопируй **Trace ID** из заголовка
2. Убери `1-` и дефис → получи 32-char hex
3. Вставь в запрос Logs Insights:
```
fields @timestamp, level, message, name
| filter trace_id = "полученный_hex"
| sort @timestamp asc
```

---

## ADOT Collector

ADOT Collector — sidecar контейнер в ECS task, передаёт трейсы из API в X-Ray.

**Проверить что работает:** открой log stream в `/ecs/dmc-1-t1-notebook-adot-dev` — должна быть строка:
```
Everything is ready. Begin running and processing data.
```

**Если ADOT не стартует:** смотри логи на ошибки IAM (`AccessDeniedException`) или проблемы с конфигом (`AOT_CONFIG_CONTENT`).

ADOT имеет `essential=false` — если он упадёт, API продолжит работу, но трейсы перестанут поступать в X-Ray.

---

## Быстрая диагностика

| Симптом | Где смотреть | Что искать |
|---------|-------------|-----------|
| API не отвечает | ECS → сервис → Tasks | Статус `RUNNING`, health check |
| Ошибки в приложении | CloudWatch Logs Insights | `filter level = "ERROR"` |
| Трейсы не появляются в X-Ray | `/ecs/dmc-1-t1-notebook-adot-dev` | `Everything is ready` |
| Высокий CPU контейнера | ECS → сервис → Metrics | График CPU utilization |
| БД недоступна | `/api/v1/health/db` + RDS Monitoring | HTTP 503, connections |
