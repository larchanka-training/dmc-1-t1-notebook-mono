# Launch Presentation — JavaScript Notebook

> Issue [#180](https://github.com/larchanka-training/js-notebook/issues/180) — Demo Day

**Длительность:** 15–20 минут
**Дата:** 2026-06-28

---

## Слайд 1: О проекте (1 мин)

**JavaScript Notebook** — веб-платформа для написания заметок и выполнения JavaScript-кода в ячейках блокнота. Аналог Jupyter Notebook для JS.

**Команда:** Engineer #1–5

**Что умеет:**
- Markdown-ячейки с GFM
- JavaScript-ячейки с выполнением в браузере (Web Worker)
- AI-генерация кода через AWS Bedrock
- Аналитика использования
- JWT-аутентификация, тёмная/светлая тема

---

## Слайд 2: Архитектура (2 мин)

```text
         ┌──────────────────────────┐
         │      CloudFront          │
         │   (HTTPS, CDN, cache)    │
         └────────────┬─────────────┘
                      │
         ┌────────────▼─────────────┐
         │         ALB              │
         │   (HTTP:80, routing)     │
         └────────┬────────┬────────┘
                  │        │
     ┌────────────▼──┐  ┌──▼──────────────┐
     │  ECS Fargate  │  │  ECS Fargate    │
     │  API (FastAPI)│  │  UI (React)     │
     │  + ADOT side  │  │  (nginx static) │
     └──────┬────────┘  └─────────────────┘
            │
     ┌──────▼──────┐  ┌───────────────┐
     │  PostgreSQL │  │  AWS Bedrock  │
     │   (RDS)     │  │  (Nova Pro)   │
     └─────────────┘  └───────────────┘
```

**Tech Stack:**

| Слой | Технологии |
|------|-----------|
| Frontend | React 18, TypeScript 5.6, Vite 7, Redux Toolkit, Tailwind CSS 4, CodeMirror 6 |
| Backend | Python 3.11, FastAPI, SQLAlchemy (async), Pydantic, Alembic |
| Database | PostgreSQL 16 (RDS, db.t3.micro) |
| AI | AWS Bedrock (Nova Pro v1:0), prompt guard, rate limiting |
| Infra | AWS ECS Fargate, ALB, CloudFront, VPC, NAT Gateway, VPC Endpoint |
| Observability | OpenTelemetry → ADOT → X-Ray, CloudWatch Logs |
| CI/CD | GitHub Actions, GHCR, Terraform |

**Монорепозиторий:** `api/` и `ui/` — git submodules, `proxy/`, `docs/`, `infra/`.

---

## Слайд 3: Ключевые решения (2 мин)

### 1. Web Worker sandbox для выполнения JS

**Проблема:** Выполнение пользовательского JS-кода в браузере — риск для UI.

**Решение:** Web Worker с indirect eval `(0, eval)(code)`, перехват `console`, `setTimeout`, `setInterval`, `fetch`. Snapshot/restore глобального состояния между запусками.

**Результат:** Изоляция выполнения, cell execution = 106 ms.

### 2. AI-генерация с валидацией и retry

**Проблема:** LLM может сгенерировать невалидный JS-код.

**Решение:** Pipeline: prompt guard → Bedrock → валидация (AST + runtime) → retry до 3 попыток. System prompt строго ограничивает output формат.

**Результат:** Большинство запросов проходит с 1-й попытки, avg 1.5 попыток.

### 3. JWT в HttpOnly cookies

**Проблема:** XSS может украсть токен из localStorage.

**Решение:** Access token (15 мин) + refresh token (7 дней) в HttpOnly cookies. Refresh token rotation с хэшированием в БД.

**Результат:** Токены недоступны через JavaScript, автоматическое продление сессии.

### 4. Terraform IaC с module-based структурой

**Проблема:** Воспроизводимая инфраструктура для dev/prod.

**Решение:** `infra/shared/` (VPC, ALB, CloudFront) + `infra/modules/environment/` (ECS, RDS, Bedrock, observability) + `infra/envs/{dev,prod}/`.

**Результат:** Полностью описанная инфраструктура, идемпотентное развёртывание.

---

## Слайд 4: Проблемы и решения (2 мин)

### Bundle size: 6.8 MB (2.5 MB gzip)

**Проблема:** `@mlc-ai/web-llm` (~4 MB) в главном chunk. Vite предупреждает о превышении 500 KB.

**Решение (предложено):** Code-split через динамический `import()` → bundle 6.8 MB → 2.8 MB.

### Auth latency: 178 ms

**Проблема:** bcrypt с высоким cost factor — login/register в 35× медленнее остальных endpoints.

**Решение (предложено):** Снизить cost factor с 12 до 10 → 178 ms → ~50 ms.

### Bedrock стоимость: 79–96% затрат

**Проблема:** Nova Pro $0.80/$3.20 per 1M tokens — дорого при масштабировании.

**Решение (предложено):** Переключить prod на Nova Lite $0.06/$0.24 — 93% экономия.

### Secure cookies по умолчанию выключены

**Проблема:** `secure_cookies=False` в config — токены могут перехватываться по HTTP.

**Решение (предложено):** Установить `SECURE_COOKIES=true` в prod env vars.

---

## Слайд 5: Метрики (2 мин)

### Производительность

| Метрика | Значение | Оценка |
|---------|----------|--------|
| API CRUD (notebooks, analytics) | 2–5 ms | Отлично |
| Notebook open (UI) | 31 ms | Отлично |
| Cell execution (Run → output) | 106 ms | Отлично |
| Page load (DOM Content Loaded) | 50 ms | Отлично |
| Auth (login/register) | 178 ms | Средне (bcrypt) |
| JS Heap Used | 35 MB | Норма |
| Bundle size (gzip) | 2.5 MB | Критично |

### Безопасность

| Проверка | Результат |
|----------|-----------|
| XSS (React, markdown, cell output) | OK — auto-escaping, нет `dangerouslySetInnerHTML` |
| JWT (HttpOnly, expiry, rotation) | OK — кроме `secure_cookies` default |
| IDOR (notebook CRUD) | OK — `_get_owned()` на всех endpoints |
| Prompt injection | OK — regex guard + system prompt |
| Sandbox isolation | Medium — нет timeout, `fetch` доступен |

### Стоимость (AWS eu-north-1)

| Масштаб | Месяц | На пользователя |
|---------|-------|-----------------|
| 100 users | $546 | $5.46 |
| 1,000 users | $5,006 | $5.01 |
| 10,000 users | $44,743 | $4.47 |

С оптимизациями (Nova Lite + Fargate Spot + logs): до **93% экономии**.

---

## Слайд 6: Что получилось лучше всего (2 мин)

### 1. Web Worker execution engine
Изолированное выполнение JS в браузере с snapshot/restore, перехватом async и console. Cell execution = 106 ms. Уникальная фича для JS notebook.

### 2. AI pipeline с валидацией
Prompt guard → Bedrock → AST validation → runtime validation → retry. Defence-in-depth для AI-генерации.

### 3. Terraform infrastructure
Полностью описанная AWS-инфраструктура: VPC, ECS Fargate, RDS, CloudFront, Bedrock VPC endpoint, observability. Module-based, идемпотентное.

### 4. Feature-based frontend архитектура
Чёткое разделение `features/notebook/`, `features/auth/`, `features/analytics/`. Каждый модуль: `api/`, `model/`, `ui/`, `lib/`.

### 5. Observability out of the box
OpenTelemetry → ADOT collector sidecar → X-Ray. Sampling rate configurable (dev: 1.0, prod: 0.3).

---

## Слайд 7: Что бы переделали (2 мин)

### 1. Code-splitting с самого начала
`@mlc-ai/web-llm` (~4 MB) попал в главный bundle. Нужно было сразу использовать динамический `import()` для опциональных фич.

### 2. Nova Lite вместо Nova Pro для prod
Nova Pro избыточен для генерации JS-кода. Nova Lite в 13× дешевле и достаточен по качеству. Переключение сэкономило бы до 93% AI-затрат.

### 3. Secure cookies по умолчанию
`secure_cookies=False` — неудачный default для security. Должно быть `True` с возможностью отключения для local dev.

### 4. Timeout для Web Worker eval
`eval()` без timeout — `while(true)` заблокирует выполнение ячеек. Нужно добавить Web Worker timeout с `terminate()`.

### 5. CORS middleware
Отсутствует явная CORS конфигурация в FastAPI. В prod это работает через CloudFront + ALB, но для API consumers вне домена — проблема.

### 6. Ручное тестирование вместо E2E
Playwright E2E тесты не написаны. Performance замеры сделаны вручную через Playwright scripts, но не интегрированы в CI.

---

## Слайд 8: CI/CD и DevOps (1 мин)

```text
GitHub Push → GitHub Actions →
  ├─ Lint + Unit tests (pytest, vitest)
  ├─ Build Docker images → GHCR
  ├─ Terraform plan (prod)
  └─ Submodule sync (update-submodules.yml)
```

- **Docker Compose** для локальной разработки (5 сервисов)
- **Terraform** для AWS (shared + environment modules)
- **GitHub Actions** для CI/CD
- **GHCR** для container registry
- **OpenTelemetry** для distributed tracing

---

## Слайд 9: Демо (3 мин)

**Сценарий:**
1. Регистрация / вход
2. Создание notebook
3. Markdown-ячейка — редактирование, рендеринг
4. JS-ячейка — выполнение кода, вывод в консоль
5. AI-генерация — текстовое описание → JS-код
6. Аналитика — dashboard с метриками
7. Тёмная/светлая тема

---

## Слайд 10: Итоги (1 мин)

**Создали:**
- Веб-платформу для JS-блокнотов с AI-генерацией
- Full-stack приложение: React + FastAPI + PostgreSQL + AWS Bedrock
- Production-ready инфраструктуру на AWS (Terraform)
- Observability: OpenTelemetry → X-Ray + CloudWatch

**Метрики:**
- API latency: 2–5 ms (CRUD), 178 ms (auth)
- Cell execution: 106 ms
- Bundle: 2.5 MB gzip (оптимизация до 1 MB)
- Стоимость: $5.01/пользователя/мес (с оптимизациями $0.12)

**Документы:**
- [Architecture](architecture.md)
- [Performance Report](performance-report.md)
- [Security Review](security-review.md)
- [Cost Analysis](cost-analysis.md)

---

## Q&A (2 мин)
