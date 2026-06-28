# Описание проекта

## JavaScript Notebook

Веб-платформа для написания заметок и выполнения JavaScript-кода в ячейках блокнота (аналог Jupyter Notebook для JS).

## Возможности

- **Markdown-ячейки** — форматированный текст с поддержкой GFM
- **JavaScript-ячейки** — выполнение кода в изолированном Web Worker
- **AI-генерация кода** — генерация JS-кода по текстовому описанию через AWS Bedrock (Claude)
- **Аналитика** — отслеживание событий использования (создание блокнотов, выполнение ячеек, AI-запросы)
- **Аутентификация** — JWT через HttpOnly cookies, refresh token rotation
- **Тёмная/светлая тема** — переключение с сохранением в localStorage

## Структура монорепозитория

```
dmc-1-t1-notebook-mono/
├── api/          # FastAPI backend (git submodule)
├── ui/           # React frontend (git submodule)
├── proxy/        # Nginx reverse proxy
├── docs/         # Архитектура, гайды, QA документация
└── docker-compose.yaml
```

## Технологический стек

| Слой | Технологии |
|---|---|
| Backend | Python 3.11, FastAPI, SQLAlchemy, PostgreSQL, Alembic |
| Frontend | React 18, TypeScript 5.6, Vite 7, Redux Toolkit, Tailwind CSS 4 |
| UI libs | CodeMirror 6, React Markdown, Vitest |
| Infra | Docker Compose, Nginx, OpenTelemetry (Aspire) |

## Документация

- [Обзор архитектуры](architecture.md)
- [Требования к проекту](requirements.md)
- [Локальная настройка](guides/local-setup.md)
- [Аутентификация](guides/auth.md)
- [Reverse Proxy](Local-Proxy.md)
- [Docker Compose](guides/docker-compose.md)
- [Observability](guides/observability.md)
- [Архитектура исполнения кода](architecture/execution-architecture.md)
- [Web Worker Execution Engine](architecture/web-worker-execution-engine.md)
- [Модель блокнота](architecture/notebook-model.md)
- [AI генерация кода](architecture/ai-generation.md)
- [Аналитика](architecture/analytics.md)
- [QA Plan](qa/qa-plan.md)
- [Definition of Done](qa/definition-of-done.md)

## Ссылки

- **Mono репо:** [github.com/larchanka-training/dmc-1-t1-notebook-mono](https://github.com/larchanka-training/dmc-1-t1-notebook-mono)
- **API репо:** [github.com/larchanka-training/dmc-1-t1-notebook-api](https://github.com/larchanka-training/dmc-1-t1-notebook-api)
- **UI репо:** [github.com/larchanka-training/dmc-1-t1-notebook-ui](https://github.com/larchanka-training/dmc-1-t1-notebook-ui)
