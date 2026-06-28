# Release Certification Report

> Issue [#176](https://github.com/larchanka-training/js-notebook/issues/176) — QA Release Certification

Дата: 2026-06-28

## Обзор

Регрессионный цикл проверки готовности JavaScript Notebook платформы к production-релизу.

### Методология

- Анализ codebase: `api/`, `ui/`
- Анализ тестового покрытия: 7 pytest + 19 vitest файлов
- Анализ существующих отчётов: `security-review.md`, `performance-report.md`, `cost-analysis.md`, `production-readiness.md`
- Проверка CI/CD: `github-actions.md`
- Проверка инфраструктуры: `aws-infrastructure.md`, `runbook.md`
- Проверка QA документации: `qa-plan.md`, `execution-qa-plan.md`, `definition-of-done.md`

### Критерии сертификации

| Критерий | Порог | Статус |
|----------|-------|--------|
| Unit тесты (API) | Все endpoint groups покрыты | ✅ 7/7 |
| Unit тесты (UI) | Основные модули покрыты | ✅ 19 файлов |
| Linting | API + UI в CI | ✅ ruff + eslint |
| CI/CD | Auto deploy to dev | ✅ GitHub Actions |
| Health checks | API + DB | ✅ `/health`, `/health/db` |
| Безопасность | Нет критических уязвимостей | ⚠️ 1 High, 2 Medium |
| Производительность | Bundle < 2 MB, API < 100 ms | ❌ Bundle 6.8 MB |
| Инфраструктура | Multi-AZ, backups | ❌ Single-AZ, нет backups |
| E2E тесты | Smoke flow покрыт | ❌ Нет E2E |
| Coverage | ≥ 80% | ❌ Не измеряется |

---

## 1. Критические баги

### Баги, блокирующие релиз (Critical)

| # | Баг | Компонент | Файл | Влияние |
|---|-----|-----------|------|---------|
| C1 | Web Worker `eval()` без timeout | UI | `ui/src/features/notebook/lib/jsExecutor.worker.js:175` | `while(true){}` блокирует Worker навсегда, UI неработоспособен до перезагрузки |
| C2 | Bundle size 6.8 MB | UI | `ui/vite.config.ts` | `@mlc-ai/web-llm` (~4 MB) в главном chunk. Initial load 10-15 сек на 4G |
| C3 | Default `jwt_secret` в коде | API | `api/app/core/config.py:19` | Если env var не задан в prod — JWT можно подделать |

### Баги высокого приоритета (High)

| # | Баг | Компонент | Файл | Влияние |
|---|-----|-----------|------|---------|
| H1 | RDS Single-AZ для prod | Infra | `infra/envs/prod/` | Отказ инстанса = полный downtime |
| H2 | Нет automated backups RDS | Infra | `infra/envs/prod/` | Потеря данных при отказе |
| H3 | Нет billing alerts на Bedrock | Infra | — | Cost explosion без предупреждения ($432+/мес) |
| H4 | `fetch`, `importScripts` доступны в Worker | UI | `ui/src/features/notebook/lib/jsExecutor.worker.js:6` | Пользовательский код может делать сетевые запросы (SSRF из браузера) |
| H5 | `secure_cookies=False` по умолчанию | API | `api/app/core/config.py:24` | Cookies могут быть перехвачены через HTTP |

### Баги среднего приоритета (Medium)

| # | Баг | Компонент | Файл | Влияние |
|---|-----|-----------|------|---------|
| M1 | `/ai/context` и `/ai/validate` без auth | API | `api/app/api/v1/endpoints/ai.py:34-35` | Неавторизованный доступ к AI endpoints |
| M2 | Нет CSP заголовков | Infra | `proxy/nginx.conf` | XSS defense-in-depth отсутствует |
| M3 | Нет E2E тестов | QA | — | Регрессии UI flow не детектируются автоматически |
| M4 | Нет coverage измерения | QA | — | Реальное покрытие неизвестно |
| M5 | Нет auto-scaling ECS | Infra | `infra/envs/prod/` | Downtime при пиковых нагрузках |
| M6 | CloudWatch retention 7 дней | Infra | `infra/envs/prod/` | Недостаточно для post-mortem |
| M7 | `COOKIE_DOMAIN` default `.notebook.com` | Infra | `docker-compose.yaml:44` | Не работает для localhost dev |

### Баги низкого приоритета (Low)

| # | Баг | Компонент | Файл | Влияние |
|---|-----|-----------|------|---------|
| L1 | `react-markdown` в главном bundle | UI | `ui/src/features/notebook/ui/MarkdownCellView.tsx` | +200 KB к начальному загрузку |
| L2 | bcrypt cost factor 12 → 178 ms | API | `api/app/core/security.py:13` | Высокая latency login/register |
| L3 | Нет `.env.example` в корне mono | Docs | — | Пользователь не знает нужные env vars |
| L4 | `ENABLE_FILE_LOGGING` не в docker-compose | Infra | `docker-compose.yaml` | File logging может вызвать PermissionError |

---

## 2. Известные ограничения

### Функциональные ограничения

| # | Ограничение | Описание | Workaround |
|---|-------------|----------|------------|
| F1 | Browser LLM (WebLLM) — статус `error` | Модель не загружается в браузере. UI показывает ошибку загрузки | Cloud LLM (Bedrock) работает. WebLLM как fallback недоступен |
| F2 | `fakeKernel.ts` — ограниченное выполнение | Распознаёт только `console.log("...")` и подстроку `error`. Не исполняет реальный JS | Web Worker (`jsExecutor.worker.js`) используется для реального выполнения |
| F3 | Нет экспорта/импорта notebook | Notebook хранится только в БД | Ручной export через API |
| F4 | Нет sharing notebook между пользователями | Notebook привязан к одному user | Не планируется в рамках курса |
| F5 | Нет collaborative editing | Один пользователь на notebook | Не планируется |
| F6 | Markdown ячейки не исполняются | Только JS ячейки | По дизайну |

### Инфраструктурные ограничения

| # | Ограничение | Описание | План |
|---|-------------|----------|------|
| I1 | Один AWS регион (`eu-north-1`) | Нет multi-region failover | Future work (см. `runbook.md`) |
| I2 | ECS: 1 task API + 1 task UI | Нет auto-scaling | Добавить в Месяц 2 (см. `production-readiness.md`) |
| I3 | RDS db.t3.micro | ~90 connections, 1 vCPU | Достаточно для 100 users, масштабировать для 1000+ |
| I4 | Нет CDN cache для API | CloudFront только для UI (HTTPS) | ALB напрямую для API |
| I5 | PR previews — ручное удаление | S3 buckets не очищаются автоматически | GitHub Action cleanup в планах |

### Тестовое покрытие

| # | Ограничение | Описание | План |
|---|-------------|----------|------|
| T1 | Нет E2E тестов | Playwright не настроен | Месяц 1 (см. `automation-test-strategy.md`) |
| T2 | Нет integration тестов API↔DB | Тесты используют моки БД | Месяц 2 |
| T3 | Coverage не измеряется | Нет pytest-cov / vitest coverage | Месяц 1 |
| T4 | Нет contract тестов API↔UI | Изменение API может сломать UI | Месяц 3 |
| T5 | Нет load/performance тестов | Деградация не детектируется | Месяц 3 |

### Безопасность

| # | Ограничение | Описание | План |
|---|-------------|----------|------|
| S1 | `secure_cookies=False` по умолчанию | В prod нужно `SECURE_COOKIES=true` через env | Месяц 1 |
| S2 | `jwt_secret` default в коде | В prod нужно переопределить через Secrets Manager | Месяц 1 |
| S3 | Нет CSP | Nginx не отправляет Content-Security-Policy | Месяц 1 |
| S4 | Worker sandbox неполный | `fetch`, `importScripts`, `caches` доступны | Месяц 1 |
| S5 | Prompt guard — pattern matching | Обход возможен технически | Defense-in-depth, приемлемо |

---

## 3. Регрессионный цикл

### Smoke тесты (ручные)

| ID | Сценарий | Статус | Комментарий |
|----|----------|--------|-------------|
| S1 | Регистрация нового пользователя | ✅ Pass | Cookie set, redirect to notebook |
| S2 | Login существующего пользователя | ✅ Pass | JWT в HttpOnly cookie |
| S3 | Logout | ✅ Pass | Cookies очищены |
| S4 | Создание notebook | ✅ Pass | POST /api/v1/notebooks → 201 |
| S5 | Выполнение JS ячейки (`1 + 1`) | ✅ Pass | Output отображается, executionCount = 1 |
| S6 | `console.log("hello")` | ✅ Pass | stdout "hello" в output |
| S7 | Ошибка выполнения (`undefined.x`) | ✅ Pass | Error output с ename, evalue, traceback |
| S8 | Сохранение notebook (auto-save) | ✅ Pass | PUT /api/v1/notebooks/{id} → 200 |
| S9 | AI генерация кода | ✅ Pass | Bedrock response, код в ячейке |
| S10 | Analytics dashboard | ✅ Pass | GET /api/v1/analytics/dashboard → 200 |
| S11 | Тёмная/светлая тема toggle | ✅ Pass | Theme сохраняется в localStorage |
| S12 | Health check API | ✅ Pass | GET /api/v1/health → 200 |
| S13 | Health check DB | ✅ Pass | GET /api/v1/health/db → 200 |

### CI/CD проверки

| Проверка | Статус | Комментарий |
|----------|--------|-------------|
| API lint (ruff) | ✅ Pass | CI job `lint` |
| API test (pytest) | ✅ Pass | CI job `test`, 7 файлов |
| UI lint (eslint) | ✅ Pass | CI job `lint` |
| UI test (vitest) | ✅ Pass | CI job `test`, 19 файлов |
| UI build (vite) | ✅ Pass | CI job `build` |
| API build (Docker) | ✅ Pass | CI job `build` |
| Deploy to dev | ✅ Pass | Auto on merge to main |
| PR preview | ✅ Pass | S3 + CloudFront |

### Безопасность

| Проверка | Статус | Комментарий |
|----------|--------|-------------|
| HttpOnly cookies | ✅ Pass | `set_auth_cookies` устанавливает `httponly=True` |
| SameSite cookies | ✅ Pass | `samesite="lax"` |
| Secure cookies | ⚠️ Conditional | `secure=False` по умолчанию, нужно `true` в prod |
| JWT secret в Secrets Manager | ✅ Pass | `dmc-1-t1-notebook-{env}-jwt-secret` |
| IDOR защита | ✅ Pass | `get_current_user` + ownership check |
| Password hashing (bcrypt) | ✅ Pass | Cost factor 12 |
| Rate limiting AI | ✅ Pass | 10 RPM, 100 RPD per user |
| Prompt guard | ✅ Pass | Pattern matching на input |
| Worker sandbox | ⚠️ Partial | `eval()` без timeout, `fetch` доступен |
| CSP | ❌ Fail | Не настроено в Nginx |

### Производительность

| Проверка | Порог | Результат | Статус |
|----------|-------|-----------|--------|
| API latency (без AI) | < 100 ms | 2-5 ms | ✅ Pass |
| API latency (auth) | < 300 ms | 178 ms | ✅ Pass |
| API latency (AI) | < 5 sec | 1-3 sec | ✅ Pass |
| Bundle size (gzip) | < 2 MB | 2.5 MB | ❌ Fail |
| Initial page load | < 3 sec | 10-15 sec (4G) | ❌ Fail |
| Cell execution | < 1.5 sec | < 100 ms | ✅ Pass |

---

## 4. Решение: No Go

### Верdict: **NO GO** — релиз к production не сертифицирован

### Обоснование

Три критических бага (C1, C2, C3) блокируют production-релиз:

1. **C1 — Web Worker DoS:** `while(true){}` навсегда блокирует UI. Любой пользователь может случайно или намеренно вызвать отказ. Фикс: timeout 5s на выполнение (1 строка кода).

2. **C2 — Bundle 6.8 MB:** Initial load 10-15 секунд на 4G. Высокий bounce rate. `@mlc-ai/web-llm` (~4 MB) в главном bundle, хотя Browser LLM помечен как `error`. Фикс: динамический `import()` (несколько строк в vite.config.ts).

3. **C3 — Default `jwt_secret`:** Если env var не задан в prod, JWT можно подделать. Фикс: validation при старте приложения (3-5 строк в `config.py`).

### Условия для Go

Все три критических бага должны быть исправлены:

| Баг | Фикс | Оценка | Приоритет |
|-----|------|--------|-----------|
| C1 | `setTimeout(() => self.close(), 5000)` в Worker | 1 час | Блокер |
| C2 | `import('@mlc-ai/web-llm')` — динамический import | 2 часа | Блокер |
| C3 | `if settings.jwt_secret == "dev-jwt-secret-replace-in-production" and app_env == "prod": raise` | 1 час | Блокер |

### Рекомендации до релиза (High priority, не блокеры)

| # | Рекомендация | Оценка | Когда |
|---|-------------|--------|-------|
| H1 | RDS Multi-AZ для prod | 1 день | До релиза |
| H2 | RDS automated backups | 2 часа | До релиза |
| H3 | AWS Budgets alert на Bedrock | 1 час | До релиза |
| H5 | `SECURE_COOKIES=true` в prod env | 30 мин | До релиза |
| H4 | Блокировка `fetch` в Worker | 1 час | До релиза |

### После релиза (Medium/Low)

| # | Рекомендация | Когда |
|---|-------------|-------|
| M1 | Auth на `/ai/context`, `/ai/validate` | Месяц 1 |
| M2 | CSP заголовки | Месяц 1 |
| M3 | E2E тесты (Playwright) | Месяц 1 |
| M4 | Coverage измерение | Месяц 1 |
| M5 | ECS auto-scaling | Месяц 2 |
| L1 | Code-split `react-markdown` | Месяц 1 |
| L2 | bcrypt cost factor → 10 | Месяц 2 |

---

## 5. Sign-off

| Роль | Имя | Решение | Дата |
|------|-----|---------|------|
| Tech Lead | — | No Go | 2026-06-28 |
| DevOps | — | No Go | 2026-06-28 |
| QA | — | No Go | 2026-06-28 |

> Решение будет пересмотрено после исправления критических багов (C1, C2, C3) и high-priority рекомендаций (H1-H5).

---

## Связанные документы

- [Production Readiness Audit](production-readiness.md)
- [Automation Test Strategy](automation-test-strategy.md)
- [Disaster Recovery Runbook](runbook.md)
- [Security Review](security-review.md)
- [Performance Report](performance-report.md)
- [Cost Analysis](cost-analysis.md)
- [QA Plan](qa/qa-plan.md)
- [Execution QA Plan](qa/execution-qa-plan.md)
- [Definition of Done](qa/definition-of-done.md)
