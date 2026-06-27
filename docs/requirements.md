# Требования к проекту

## Обзор проекта

### Название
JavaScript Notebook

### Цель
Веб-приложение для написания заметок и выполнения JavaScript-кода в ячейках блокнота (аналог Jupyter Notebook для JS). Поддержка Markdown-ячеек, AI-генерации кода, сбора аналитики.

### Технологический стек
- **Фронтенд:** React 18, TypeScript 5.6, Vite 7, Redux Toolkit, Tailwind CSS 4
- **Бэкенд:** Python 3.11, FastAPI, SQLAlchemy (async), Alembic
- **База данных:** PostgreSQL
- **AI:** AWS Bedrock (Claude), prompt guard, rate limiting
- **Инфраструктура:** Docker Compose, Nginx, OpenTelemetry (Aspire)

---

# Функциональные требования

## Аутентификация и авторизация

### Аутентификация пользователей
- Регистрация пользователя
- Вход по email + пароль
- JWT-аутентификация через HttpOnly cookies
- Refresh tokens с ротацией
- Выход (logout) с очисткой cookies

### Роли
- User

### Контроль доступа
- API authorization middleware (cookie-based)

---

# Требования к фронтенду

## Технологии
- React 18
- TypeScript 5.6
- Tailwind CSS 4
- Redux Toolkit
- React Router DOM 7
- CodeMirror 6 (редактор кода)
- Vitest 3 (тестирование)

## Возможности

### UI
- Адаптивный layout
- Sidebar с навигацией
- Переключение тёмной/светлой темы
- Аналитический дашборд

### Страницы
- Login
- Registration
- Notebook (основная страница)
- Analytics (`/analytics`)

### Валидация
- Client-side валидация форм
- Обработка ошибок форм

---

# Требования к бэкенду

## Технологии
- Python 3.11
- FastAPI
- SQLAlchemy (async)
- Alembic
- Pydantic

## API требования

### REST API
- JSON-ответы
- OpenAPI документация (`/docs`)
- Версионирование API (`/api/v1`)

### Auth API
- `POST /api/v1/auth/register` — регистрация
- `POST /api/v1/auth/login` — вход
- `POST /api/v1/auth/logout` — выход
- `GET /api/v1/auth/me` — текущий пользователь
- `POST /api/v1/auth/refresh` — обновление токена

### Notebooks API
- `GET /api/v1/notebooks` — список блокнотов пользователя
- `POST /api/v1/notebooks` — создание блокнота
- `GET /api/v1/notebooks/{id}` — получение блокнота
- `PUT /api/v1/notebooks/{id}` — обновление блокнота
- `DELETE /api/v1/notebooks/{id}` — удаление блокнота

### Analytics API
- `POST /api/v1/analytics/events` — создание события аналитики
- `GET /api/v1/analytics/dashboard` — агрегированные данные дашборда

### AI API
- `POST /api/v1/ai/generate` — генерация кода через LLM
- `POST /api/v1/ai/context` — сборка контекста notebook (см. `docs/architecture/ai-notebook-context.md`)
- `POST /api/v1/ai/validate` — валидация ответа ИИ (см. `docs/architecture/ai-output-validation.md`)

---

# Требования к базе данных

## PostgreSQL

### Основные таблицы
- `users` — пользователи
- `sessions` — refresh tokens
- `notebooks` — блокноты (cells в JSONB)
- `analytics_events` — события аналитики

### Требования
- UUID primary keys
- Timestamps (`created_at`, `updated_at`)
- Foreign key constraints
- Индексы на часто запрашиваемые поля
- JSONB для cells и event_metadata

### Производительность
- Оптимизация запросов
- Connection pooling (asyncpg)
- Пулы соединений SQLAlchemy

---

# AI требования

## AI провайдеры
- AWS Bedrock (Claude) — основной
- Локальные LLM (опционально)

## Возможности
- Генерация кода по описанию
- Сборка контекста notebook для LLM
- Валидация и «починка» ответов ИИ
- Prompt guard (защита от injection)
- Rate limiting

## AI безопасность
- Rate limiting на пользователя
- Prompt injection protection
- Логирование запросов
- Учёт попыток генерации

---

# Нефункциональные требования

## Производительность
- Время ответа API < 300ms для стандартных запросов
- Streaming AI-ответов
- Поддержка 10k+ одновременных пользователей

## Безопасность
- HTTPS only (в production)
- Secure headers
- HttpOnly cookies для токенов
- SQL injection prevention (параметризованные запросы)
- Управление секретами (см. `docs/dev-ops/secrets-management.md`)

## Масштабируемость
- Горизонтальное масштабирование
- Stateless backend
- Поддержка очередей

## Надёжность
- Health checks
- Structured JSON logging
- OpenTelemetry tracing
- Error monitoring

---

# DevOps требования

## Контейнеризация
- Docker support
- docker-compose для локальной разработки

## CI/CD
- GitHub Actions
- Автоматические тесты
- Linting
- Deployment pipeline (AWS ECS)

## Окружения
- local (Docker Compose)
- production (AWS ECS)

---

# Требования к тестированию

## Фронтенд
- Unit тесты (Vitest)
- Component тесты (Vitest + jsdom)
- E2E тесты (Playwright, опционально)

## Бэкенд
- Unit тесты (pytest)
- Integration тесты (pytest + async)
- API тесты (pytest + httpx)

## Покрытие
- Минимум 80% coverage

---

# Мониторинг и наблюдаемость

## Логирование
- Structured JSON logs
- Request tracing (OpenTelemetry)

## Мониторинг
- Aspire Dashboard (локально)
- CloudWatch (production)

## Отслеживание ошибок
- Sentry (опционально)

---

# Структура проекта

## Фронтенд
```text
ui/
├── src/
│   ├── app/          # Корневой компонент, роутер, Redux store
│   ├── features/     # Feature-модули (notebook, auth, analytics)
│   └── shared/       # apiClient, утилиты
├── tests/
└── package.json
```

## Бэкенд
```text
api/
├── app/
│   ├── api/v1/endpoints/  # FastAPI endpoints
│   ├── ai/                # AI generation
│   ├── db/models/         # SQLAlchemy модели
│   ├── schemas/           # Pydantic схемы
│   └── core/              # config, security
├── alembic/               # Миграции
├── tests/                 # pytest
└── requirements.txt
```

## Переменные окружения
### Бэкенд (`api/.env`)
    DATABASE_URL=postgresql+asyncpg://...
    JWT_SECRET=
    JWT_ALGORITHM=HS256
    ACCESS_TOKEN_TTL_SECONDS=900
    SESSION_TTL_SECONDS=604800
    COOKIE_DOMAIN=
    SECURE_COOKIES=false
    AI_ENABLED=true
    AWS_REGION=
    AWS_ACCESS_KEY_ID=
    AWS_SECRET_ACCESS_KEY=
    BEDROCK_MODEL_ID=

### Фронтенд (`ui/.env`)
    VITE_API_PROXY_TARGET=http://localhost:8000
