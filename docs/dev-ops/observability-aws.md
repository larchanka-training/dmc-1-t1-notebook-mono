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

- **Трейсы** — AWS X-Ray через ADOT Collector sidecar (`essential=false`)
- **Логи** — CloudWatch Logs, формат JSON с полями `trace_id`, `user_id`, `level`
- **Инфраструктурные метрики** — CloudWatch ECS метрики (CPU, память)

Sampling: dev — 100%, prod — 30% (переменная `xray_sampling_rate` в Terraform).

---

## Инфраструктурные метрики

### ECS — CPU и память контейнеров

**Dev**

| Страница | Ссылка |
|----------|--------|
| Сервисы кластера | [dmc-1-t1-notebook-dev](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-dev/services?region=eu-north-1) |
| Метрики API | [dmc-1-t1-notebook-dev-api → Metrics](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-dev/services/dmc-1-t1-notebook-dev-api/metrics?region=eu-north-1) |
| Метрики UI | [dmc-1-t1-notebook-dev-ui → Metrics](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-dev/services/dmc-1-t1-notebook-dev-ui/metrics?region=eu-north-1) |

**Prod**

| Страница | Ссылка |
|----------|--------|
| Сервисы кластера | [dmc-1-t1-notebook-prod](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-prod/services?region=eu-north-1) |
| Метрики API | [dmc-1-t1-notebook-prod-api → Metrics](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-prod/services/dmc-1-t1-notebook-prod-api/metrics?region=eu-north-1) |
| Метрики UI | [dmc-1-t1-notebook-prod-ui → Metrics](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-prod/services/dmc-1-t1-notebook-prod-ui/metrics?region=eu-north-1) |

Открой сервис → вкладка **Metrics** → графики CPU utilization и Memory utilization.

### RDS — база данных

| Страница | Ссылка |
|----------|--------|
| RDS dev | [dmc-1-t1-notebook-dev-db](https://eu-north-1.console.aws.amazon.com/rds/home?region=eu-north-1#database:id=dmc-1-t1-notebook-dev-db;is-cluster=false) |
| RDS prod | [dmc-1-t1-notebook-prod-db](https://eu-north-1.console.aws.amazon.com/rds/home?region=eu-north-1#database:id=dmc-1-t1-notebook-prod-db;is-cluster=false) |

Открой базу данных → вкладка **Monitoring** → CPU, connections, free storage.

---

## Логи в CloudWatch

### Log Groups

**Dev**

| Log Group | Ссылка |
|-----------|--------|
| API | [/ecs/dmc-1-t1-notebook-api-dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-api-dev) |
| ADOT Collector | [/ecs/dmc-1-t1-notebook-adot-dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-adot-dev) |
| UI (Nginx) | [/ecs/dmc-1-t1-notebook-ui-dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-ui-dev) |

**Prod**

| Log Group | Ссылка |
|-----------|--------|
| API | [/ecs/dmc-1-t1-notebook-api-prod](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-api-prod) |
| ADOT Collector | [/ecs/dmc-1-t1-notebook-adot-prod](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-adot-prod) |
| UI (Nginx) | [/ecs/dmc-1-t1-notebook-ui-prod](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-ui-prod) |

Retention: 7 дней. Запросы к `/api/v1/health` отфильтрованы и в логи не попадают.

### Logs Insights — поиск по логам

| Страница | Ссылка |
|----------|--------|
| Logs Insights dev | [API dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:logs-insights$3FqueryDetail$3D~(end~0~start~-3600~timeType~'RELATIVE~unit~'seconds~editorString~'fields*20*40timestamp*2c*20level*2c*20message*2c*20trace_id*0a*7c*20sort*20*40timestamp*20desc*0a*7c*20limit*2020~isLiveTail~false~queryId~''~source~(~'*2fecs*2fdmc-1-t1-notebook-api-dev))) |
| Logs Insights prod | [API prod](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:logs-insights$3FqueryDetail$3D~(end~0~start~-3600~timeType~'RELATIVE~unit~'seconds~editorString~'fields*20*40timestamp*2c*20level*2c*20message*2c*20trace_id*0a*7c*20sort*20*40timestamp*20desc*0a*7c*20limit*2020~isLiveTail~false~queryId~''~source~(~'*2fecs*2fdmc-1-t1-notebook-api-prod))) |

### Готовые запросы

**Все ошибки:**
```
fields @timestamp, level, message, trace_id, user_id
| filter level = "ERROR"
| sort @timestamp desc
| limit 50
```

**Найти все логи по trace_id** (ID берётся из X-Ray, см. ниже как конвертировать):
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

**Ошибки с группировкой по типу:**
```
fields message
| filter level = "ERROR"
| stats count(*) as cnt by name
| sort cnt desc
```

---

## Трейсы в X-Ray

### Ссылки

| Страница | Ссылка |
|----------|--------|
| Traces | [Traces (dev + prod)](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#xray:traces/query) |
| Trace Map | [Trace Map](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#xray:service-map) |

> Примечание: курсовой IAM аккаунт не имеет права `xray:GetServiceGraph` — Trace Map недоступна. Traces работает.

По умолчанию показывает трейсы за последние **5 минут**. Для поиска по истории смени диапазон кнопками **1h** или **3h** вверху справа.

### Найти медленные запросы

В списке трейсов кликни на заголовок колонки **Duration** — сортировка по убыванию. Самые медленные запросы окажутся вверху.

### Найти ошибки

В поле фильтра введи:
```
http.status >= 400
```

### Перейти от трейса к логам

1. В списке трейсов кликни на нужный трейс
2. Скопируй **Trace ID** из заголовка (формат: `1-{8hex}-{24hex}`)
3. Убери `1-` и средний дефис → получи 32-char hex:
   ```
   X-Ray:  1-7614ebc4-230db625f5e4fd8b4f8ee6dc
   Логи:     7614ebc4230db625f5e4fd8b4f8ee6dc
   ```
4. Открой [Logs Insights](#logs-insights--поиск-по-логам) и выполни запрос:
   ```
   fields @timestamp, level, message, name
   | filter trace_id = "7614ebc4230db625f5e4fd8b4f8ee6dc"
   | sort @timestamp asc
   ```

---

## ADOT Collector

ADOT Collector — sidecar контейнер в ECS task, передаёт трейсы из API в X-Ray.
Настроен с `essential=false` — если упадёт, API продолжит работу, но трейсы перестанут поступать в X-Ray.

**Проверить что работает** — открой log group ADOT и найди строку:
```
Everything is ready. Begin running and processing data.
```

| Окружение | Ссылка |
|-----------|--------|
| Логи ADOT dev | [/ecs/dmc-1-t1-notebook-adot-dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-adot-dev) |
| Логи ADOT prod | [/ecs/dmc-1-t1-notebook-adot-prod](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-adot-prod) |

---

## Быстрая диагностика

| Симптом | Где смотреть | Что искать |
|---------|-------------|-----------|
| API не отвечает | [ECS dev](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-dev/services?region=eu-north-1) | Статус `RUNNING`, health check `healthy` |
| Ошибки в приложении | [Logs Insights dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:logs-insights) | `filter level = "ERROR"` |
| Трейсы не появляются в X-Ray | [Логи ADOT dev](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$252Fecs$252Fdmc-1-t1-notebook-adot-dev) | `Everything is ready` |
| Высокий CPU / OOM | [ECS API Metrics dev](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-dev/services/dmc-1-t1-notebook-dev-api/metrics?region=eu-north-1) | CPU utilization, Memory utilization |
| БД недоступна | [RDS dev](https://eu-north-1.console.aws.amazon.com/rds/home?region=eu-north-1#database:id=dmc-1-t1-notebook-dev-db;is-cluster=false) | Free storage, connections |
| Новый деплой завис | [ECS dev](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/dmc-1-t1-notebook-dev/services?region=eu-north-1) | Статус deployment, failed tasks |
