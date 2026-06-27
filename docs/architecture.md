# Обзор архитектуры

## Информация о проекте

- **Название:** JavaScript Notebook
- **Фронтенд:** React 18 + TypeScript 5.6 (Vite 7)
- **Бэкенд:** Python 3.11, FastAPI
- **База данных:** PostgreSQL
- **Инфраструктура:** Docker Compose, Nginx, OpenTelemetry (Aspire)
- **Облако:** AWS

---

# Архитектура верхнего уровня

```text
        ┌─────────────────────┐
        │        Proxy        │
        │        Nginx        │
        └─────────┬───────────┘
                  | HTTPS
         ┌────────┴────────┐
         ▼                 ▼
┌─────────────────────┐ ┌─────────────────────┐
│    Python Backend   │ │     Frontend        │
│ FastAPI Application │ │       React         │
└─────┬───────────┬───┘ └─────────────────────┘
     │            │
     ▼            ▼
┌────────────┐ ┌────────────┐
│ PostgreSQL │ │  AI Tools  │
│  Database  │ │            │
└────────────┘ └────────────┘
```

## Архитектура фронтенда
### Технологический стек
| Компонент | Технология |
| --- | --- |
| Фреймворк | React 18 |
| Управление состоянием | Redux Toolkit |
| Маршрутизация | React Router DOM 7 |
| Язык | TypeScript 5.6 |
| UI библиотека | Tailwind CSS 4 |
| API клиент | Fetch (с credentials: include) |
| Сборка | Vite 7 |
| Редактор кода | CodeMirror 6 |
| Markdown | react-markdown + remark-gfm |
| Тестирование | Vitest 3 |

### Структура фронтенда
```text
ui/
├── src/
│   ├── app/              # Корневой компонент, роутер, Redux store
│   ├── features/         # Feature-модули (notebook, auth, analytics)
│   │   ├── notebook/
│   │   │   ├── api/      # notebookService
│   │   │   ├── lib/      # Web Worker, fakeKernel, fakeAiCodegen
│   │   │   ├── model/    # Redux slice, thunks, selectors, types
│   │   │   └── ui/       # React компоненты
│   │   ├── auth/         # Auth context, authService
│   │   └── analytics/    # Analytics service, useAnalytics, dashboard
│   └── shared/           # apiClient, утилиты, переиспользуемые UI
├── public/
├── tests/
└── package.json
```

### Принципы фронтенда
* Feature-based архитектура (модули по доменам)
* Переиспользуемые UI компоненты в `shared/`
* Разделение бизнес-логики и представления
* Централизованный API слой (`apiClient.ts`)
* Типобезопасные интерфейсы (TypeScript)
* Web Worker для изолированного выполнения JS

## Архитектура бэкенда
### Технологический стек
| Компонент | Технология |
| --- | --- |
| Фреймворк | FastAPI |
| ORM | SQLAlchemy (async) |
| Аутентификация | JWT + HttpOnly cookies |
| Миграции | Alembic |
| Валидация | Pydantic |
| Логирование | Structured JSON logging |
| Телеметрия | OpenTelemetry |

### Структура бэкенда
```text
api/
├── app/
│   ├── api/v1/endpoints/  # FastAPI endpoints (auth, notebooks, analytics, ai)
│   ├── ai/                # AI generation (bedrock, rate_limit, prompt_guard)
│   ├── db/models/         # SQLAlchemy модели
│   ├── schemas/           # Pydantic схемы
│   ├── core/              # config, security, deps
│   └── main.py            # Точка входа
├── alembic/               # Миграции БД
├── tests/                 # pytest
└── requirements.txt
```

### Слои бэкенда
#### API слой (endpoints)
* HTTP endpoints
* Валидация запросов (Pydantic)
* Сериализация ответов
* Аутентификация (cookie-based JWT)
#### Сервисный слой
* Бизнес-логика
* Транзакции
* Доменные правила
#### Слой данных (models + SQLAlchemy)
* Доступ к БД через async SQLAlchemy
* ORM-модели: User, Session, Notebook, AnalyticsEvent

## Архитектура базы данных
### PostgreSQL (основные принципы)
* UUID primary keys
* Нормализованная схема
* Foreign key constraints
* Индексы на часто запрашиваемые поля
* JSONB для event metadata (analytics)

### Модели
| Модель | Описание |
| --- | --- |
| `User` | Пользователи (email, password_hash, display_name) |
| `Session` | Refresh tokens (token_hash, expires_at) |
| `Notebook` | Блокноты (user_id, title, cells JSONB) |
| `AnalyticsEvent` | События аналитики (user_id, event_type, event_metadata JSONB) |

### Стратегия миграций
* Alembic миграции
* Одна миграция на фичу
* Обратная совместимость
* Поддержка rollback

---

## Дополнительные материалы

- [Архитектура исполнения кода](architecture/execution-architecture.md)
- [Web Worker Execution Engine](architecture/web-worker-execution-engine.md)
- [Модель блокнота](architecture/notebook-model.md)
- [AI генерация кода](architecture/ai-generation.md)
- [Контекст Notebook для LLM](architecture/ai-notebook-context.md)
- [Валидация ответов ИИ](architecture/ai-output-validation.md)
- [Browser LLM](architecture/browser-llm.md)
- [Аналитика](architecture/analytics.md)
- [Аутентификация](guides/auth.md)
- [Локальная настройка](guides/local-setup.md)
- [Reverse Proxy](Local-Proxy.md)
