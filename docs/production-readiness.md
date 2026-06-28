# Production Readiness Audit

> Issue [#174](https://github.com/larchanka-training/js-notebook/issues/174) — Tech Lead Tech Audit

Дата аудита: 2026-06-28

## Методология

Аудит проведён на основе:
- Исходного кода (`api/`, `ui/`)
- Существующей документации (`docs/architecture.md`, `docs/security-review.md`, `docs/performance-report.md`, `docs/cost-analysis.md`, `docs/dev-ops/`)
- CI/CD пайплайнов (`docs/dev-ops/github-actions.md`)
- AWS инфраструктуры (`docs/dev-ops/aws-infrastructure.md`)
- Тестового покрытия (`api/tests/`, `ui/src/**/*.test.*`)
- Docker Compose конфигурации (`docker-compose.yaml`)

---

## 1. Что сломается первым?

### 1.1. Web Worker — бесконечный цикл (Critical)

`ui/src/features/notebook/lib/jsExecutor.worker.js:175` — пользовательский код выполняется через `eval()` без timeout. Ячейка `while(true){}` заблокирует Worker навсегда. Пользователь не сможет выполнить ни одну ячейку до перезагрузки страницы.

**Время до отказа:** первый недобросовестный или неосторожный пользователь.

**Фикс:** `setTimeout(() => { self.close(); }, 5000)` + обработка `terminate` в main thread.

### 1.2. RDS Single-AZ — потеря БД (High)

`docs/dev-ops/aws-infrastructure.md:81` — prod RDS работает в Single-AZ. При отказе инстанса или maintenance window приложение полностью недоступно. Нет read replica.

**Время до отказа:** первый maintenance window или аппаратный сбой AWS.

**Фикс:** Multi-AZ для prod (уже учтено в cost-analysis для 10K users, но не для 100–1000).

### 1.3. Bundle size 6.8 MB — initial load (High)

`docs/performance-report.md:24` — главный chunk `index-*.js` весит 6.8 MB (2.5 MB gzip). `@mlc-ai/web-llm` (~4 MB) включён в главный bundle, хотя Browser LLM помечен как `error` в UI.

При 100 пользователях на 4G-соединении initial load составит 10–15 секунд. CloudFront сжатие частично смягчает, но не решает.

**Время до отказа:** первый пользователь с мобильного интернета.

**Фикс:** Code-split `@mlc-ai/web-llm` через динамический `import()`.

### 1.4. Bedrock cost explosion (High)

`docs/cost-analysis.md:113` — Bedrock Nova Pro стоит ~$0.0144 за запрос. При 100 пользователях — $432/мес (79% всех затрат). Rate limit 100 RPD на пользователя не предотвращает общий рост.

Нет billing alerts. Нет hard cap на количество запросов в день.

**Время до отказа:** первый всплеск активности или злоупотребление.

**Фикс:** AWS Budgets alert + переключение на Nova Lite (13.3× дешевле).

---

## 2. Технический долг

### 2.1. Безопасность

| # | Долг | Уровень | Файл | Статус |
|---|------|---------|------|--------|
| S1 | `secure_cookies=False` по умолчанию | Medium | `api/app/core/config.py:24` | Env var в prod |
| S2 | Default `jwt_secret` в коде | Info | `api/app/core/config.py:19` | Нет validation |
| S3 | `/ai/context` и `/ai/validate` без auth | Low | `api/app/api/v1/endpoints/ai.py:34-35` | Нет `get_current_user` |
| S4 | Нет CSP заголовков | Info | `proxy/nginx.conf` | Не настроено |
| S5 | `eval()` без timeout в Worker | High | `ui/src/features/notebook/lib/jsExecutor.worker.js:175` | Нет timeout |
| S6 | `fetch`, `importScripts`, `caches` доступны в Worker | Medium | `ui/src/features/notebook/lib/jsExecutor.worker.js:6` | Не заблокировано |
| S7 | Prompt guard — pattern matching, обход возможен | Medium | `api/app/ai/prompt_guard.py:15-26` | Defense-in-depth, приемлемо |

> Подробнее: `docs/security-review.md`

### 2.2. Производительность

| # | Долг | Уровень | Файл | Статус |
|---|------|---------|------|--------|
| P1 | `@mlc-ai/web-llm` в главном bundle (4 MB) | High | `ui/vite.config.ts` | Не code-split |
| P2 | Нет `manualChunks` для vendor libs | Medium | `ui/vite.config.ts` | Не настроено |
| P3 | `react-markdown` + `remark-gfm` в главном bundle | Low | `ui/src/features/notebook/ui/MarkdownCellView.tsx` | Не code-split |
| P4 | bcrypt cost factor 12 → 178 ms на login | Low | `api/app/core/security.py:13` | Приемлемо, но можно снизить |

> Подробнее: `docs/performance-report.md`

### 2.3. Инфраструктура

| # | Долг | Уровень | Описание |
|---|------|---------|----------|
| I1 | RDS prod Single-AZ | High | Нет Multi-AZ для 100–1000 users |
| I2 | Нет billing alerts | Medium | Нет AWS Budgets на Bedrock |
| I3 | ECS API — 1 task для 100 users | Medium | Нет auto-scaling policy |
| I4 | CloudWatch retention 7 дней | Low | Недостаточно для post-mortem анализа |
| I5 | Нет backup policy для RDS | Medium | `skip_final_snapshot` = true для dev, но prod backup не описан |

### 2.4. Тестирование

| # | Долг | Уровень | Описание |
|---|------|---------|----------|
| T1 | Нет E2E тестов | Medium | Playwright не настроен, нет `ui/tests/` |
| T2 | Нет coverage отчёта | Low | pytest/vitest запускаются, но coverage не измеряется |
| T3 | Нет integration тестов API↔DB | Medium | Тесты используют моки БД, не реальную PostgreSQL |
| T4 | Требование 80% coverage не проверяется | Low | `docs/requirements.md:214` — нет CI gate |

Текущее покрытие:

| Слой | Файлов тестов | Покрытие |
|------|--------------|----------|
| API (pytest) | 7 файлов: auth, notebooks, analytics, ai_context, ai_endpoint, ai_validation, health | Все endpoint groups |
| UI (vitest) | 19 файлов: notebook model, executor, services, components, auth, analytics | Основные модули |

### 2.5. Docker Compose / локальная разработка

| # | Долг | Уровень | Описание |
|---|------|---------|----------|
| D1 | `COOKIE_DOMAIN` default `.notebook.com` | Medium | `docker-compose.yaml:44` — не работает для localhost |
| D2 | `ENABLE_FILE_LOGGING` не передаётся в docker-compose | Low | `api/.env` имеет `true`, docker-compose не переопределяет |
| D3 | Нет `.env.example` в корне mono | Low | Пользователь не знает какие env vars нужны |

---

## 3. Риски релиза

### 3.1. Критические риски (блокируют релиз)

| Риск | Вероятность | Влияние | Mitigation |
|------|-------------|---------|------------|
| Web Worker DoS — `while(true)` | Высокая | Полная блокировка UI | Timeout 5s на выполнение |
| Bundle 6.8 MB — медленная загрузка | Высокая | Высокий bounce rate | Code-split web-llm |
| `jwt_secret` default в prod | Средняя | Подделка JWT, полный компромат | Validation при старте |

### 3.2. Высокие риски (требуют внимания до релиза)

| Риск | Вероятность | Влияние | Mitigation |
|------|-------------|---------|------------|
| RDS Single-AZ отказ | Низкая | Полный downtime | Multi-AZ для prod |
| Bedrock cost explosion | Средняя | $432+/мес без alert | AWS Budgets + Nova Lite |
| `secure_cookies=False` в prod | Средняя | Token interception | Env var `SECURE_COOKIES=true` |
| Нет backup RDS | Низкая | Потеря данных | Automated backups |

### 3.3. Средние риски (план исправления)

| Риск | Вероятность | Влияние | Mitigation |
|------|-------------|---------|------------|
| Нет E2E тестов | Средняя | Регрессии в UI | Playwright smoke tests |
| Нет auto-scaling ECS | Низкая | Downtime при пике | Service auto-scaling |
| `fetch` в Worker — SSRF из браузера | Низкая | Несанкционированные запросы | Блокировка `fetch` в Worker |
| Нет CSP | Низкая | XSS вектор (минимальный) | Nginx CSP header |

---

## 4. План на следующие 3 месяца

### Месяц 1: Stabilization (критические фиксы)

| Неделя | Задача | Сложность | Эффект |
|--------|--------|-----------|--------|
| 1 | Timeout 5s на Web Worker execution | Низкая | DoS защита |
| 1 | Блокировка `importScripts`, `XMLHttpRequest` в Worker | Низкая | Sandbox усиление |
| 2 | Code-split `@mlc-ai/web-llm` | Низкая | Bundle 6.8 MB → 2.8 MB |
| 2 | `manualChunks` в vite.config.ts | Низкая | Лучшее кэширование |
| 3 | Validation `jwt_secret` в production | Низкая | Защита от default секрета |
| 3 | `SECURE_COOKIES=true` в prod env | Низкая | Token protection |
| 4 | Auth на `/ai/context` и `/ai/validate` | Низкая | Консистентность API |
| 4 | CSP заголовки в Nginx | Низкая | XSS defense-in-depth |

### Месяц 2: Infrastructure & Cost

| Неделя | Задача | Сложность | Эффект |
|--------|--------|-----------|--------|
| 1 | RDS Multi-AZ для prod | Средняя | Отказоустойчивость БД |
| 1 | AWS Budgets alert на Bedrock | Низкая | Cost control |
| 2 | Переключение prod на Nova Lite | Низкая | 93% экономия на AI |
| 2 | ECS auto-scaling policy | Средняя | Масштабирование |
| 3 | RDS automated backups + retention | Низкая | Backup стратегия |
| 3 | CloudWatch retention 30 дней для prod | Низкая | Post-mortem анализ |
| 4 | VPC endpoints для ECR, CloudWatch, Secrets | Низкая | Снижение NAT cost |

### Месяц 3: Quality & Observability

| Неделя | Задача | Сложность | Эффект |
|--------|--------|-----------|--------|
| 1 | Playwright E2E smoke tests (login, notebook CRUD, cell exec) | Средняя | Регрессионный baseline |
| 2 | Coverage отчёт в CI (pytest-cov + vitest coverage) | Низкая | Видимость покрытия |
| 3 | Integration тесты API↔PostgreSQL (testcontainers) | Средняя | Реальное покрытие БД |
| 4 | Sentry / error tracking для prod | Низкая | Реактивный мониторинг |

---

## 5. Сводная оценка готовности

| Категория | Оценка | Комментарий |
|-----------|--------|-------------|
| Безопасность | **60%** | HttpOnly cookies, IDOR защита, bcrypt — хорошо. `secure_cookies`, `jwt_secret` validation, Worker sandbox — требуют фиксов |
| Производительность | **50%** | API latency отличная (2-5 ms). Bundle size критичный (6.8 MB). Auth latency приемлемая (178 ms) |
| Надёжность | **40%** | Health checks есть. RDS Single-AZ, нет backups, нет auto-scaling — требуют внимания |
| Observability | **70%** | CloudWatch Logs, X-Ray traces, structured JSON logging — хорошо. Нет alerting, нет error tracking |
| CI/CD | **75%** | GitHub Actions, auto deploy to dev, manual to prod, PR previews — хорошо. Нет coverage gate, нет E2E |
| Тестирование | **45%** | Unit tests есть для основных модулей. Нет E2E, нет integration, нет coverage измерения |
| Cost | **30%** | Bedrock Nova Pro = 79% затрат. Нет billing alerts. Оптимизация (Nova Lite) не применена |

**Общая оценка: ~50% production-ready**

Проект функционально готов, но требует стабилизации (Worker timeout, bundle split, security hardening) и инфраструктурных улучшений (Multi-AZ, backups, cost controls) перед production-релизом.
