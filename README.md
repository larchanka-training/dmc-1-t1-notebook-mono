# Notebook Platform — Монорепозиторий

JavaScript Notebook платформа (аналог Jupyter) для написания заметок и выполнения JS/Markdown ячеек. Разрабатывается в рамках учебного курса.

## Структура репозитория

```
dmc-1-t1-notebook-mono/
├── api/          # FastAPI backend (git submodule → dmc-1-t1-notebook-api)
├── ui/           # React frontend (git submodule → dmc-1-t1-notebook-ui)
├── proxy/        # Nginx reverse proxy
├── infra/        # Инфраструктура (AWS, ECS, CI/CD конфиги)
├── docs/         # Архитектура, гайды, QA, DevOps
├── Makefile      # Команды для управления Docker-стеком
└── docker-compose.yaml
```

## Tech Stack

| Слой     | Технологии                                          |
|----------|-----------------------------------------------------|
| Backend  | Python 3.11, FastAPI, Uvicorn, Pydantic, PostgreSQL |
| Frontend | React 18, TypeScript 5.6, Vite 7, Redux Toolkit     |
| UI libs  | CodeMirror, React Markdown, Tailwind CSS 4          |
| Infra    | Docker Compose, Nginx, OpenTelemetry (Aspire)       |
| AI       | AWS Bedrock (Claude), Browser LLM (WebLLM)          |

## Быстрый старт

**Требование:** [Docker](https://docs.docker.com/get-docker/) (или Docker Desktop).

```bash
make up
```

Эта команда подтягивает последние изменения из всех submodule'ов, собирает образы, запускает сервисы и применяет миграции БД.

| Сервис           | URL                          |
|------------------|------------------------------|
| UI               | https://notebook.com         |
| API              | https://notebook.com/api     |
| API docs         | https://notebook.com/api/docs |
| Aspire Dashboard | http://localhost:18888       |
| PgAdmin          | http://localhost:5050        |

> Для работы локальных доменов добавьте записи в `/etc/hosts` — см. [docs/guides/local-setup.md](docs/guides/local-setup.md).

## Команды Makefile

| Команда      | Описание                                                    |
|--------------|-------------------------------------------------------------|
| `make up`    | Подтянуть изменения, собрать и запустить стек, мигрировать  |
| `make fresh` | Полная пересборка с нуля (удаляет volumes, без кэша)        |
| `make down`  | Остановить сервисы (данные сохраняются)                     |
| `make wipe`  | Остановить и удалить все данные (volumes)                   |
| `make migrate` | Применить миграции БД вручную                             |
| `make logs`  | Логи всех сервисов в реальном времени                       |
| `make ps`    | Статус запущенных сервисов                                  |

## Документация

### Архитектура

- [Обзор архитектуры](docs/architecture.md)
- [Модель Notebook](docs/architecture/notebook-model.md)
- [Архитектура выполнения](docs/architecture/execution-architecture.md)
- [Web Worker execution engine](docs/architecture/web-worker-execution-engine.md)
- [AI генерация кода](docs/architecture/ai-generation.md)
- [AI контекст notebook](docs/architecture/ai-notebook-context.md)
- [AI валидация вывода](docs/architecture/ai-output-validation.md)
- [Browser LLM](docs/architecture/browser-llm.md)

### Гайды

- [Локальная настройка](docs/guides/local-setup.md)
- [Docker Compose](docs/guides/docker-compose.md)
- [Observability](docs/guides/observability.md)
- [Авторизация](docs/guides/auth.md)

### DevOps

- [AWS инфраструктура](docs/dev-ops/aws-infrastructure.md)
- [Окружения](docs/dev-ops/environments.md)
- [GitHub Actions](docs/dev-ops/github-actions.md)
- [Deployment runbook](docs/dev-ops/deployment-runbook.md)
- [Управление секретами](docs/dev-ops/secrets-management.md)
- [PR previews](docs/dev-ops/pr-previews.md)
- [Submodules](docs/dev-ops/submodules.md)
- [Observability в AWS](docs/dev-ops/observability-aws.md)

### QA

- [QA Plan](docs/qa/qa-plan.md)
- [Execution QA Plan](docs/qa/execution-qa-plan.md)
- [Definition of Done](docs/qa/definition-of-done.md)
- [PR Manual Check Process](docs/qa/pr-manual-check-process.md)
- [Acceptance Criteria Template](docs/qa/acceptance-criteria-template.md)
- [Bug Reporting Guide](docs/qa/bug-reporting-guide.md)

---

## Code Graph (Graphify + Graphweave)

Проект использует [Graphify](https://github.com/nicholasgasior/graphify) и [Graphweave](https://www.npmjs.com/package/graphweave) для построения графа зависимостей кода. Конфиг — [`graphweave.yaml`](graphweave.yaml) в корне mono.

### Установка

```bash
uv tool install graphify              # CLI-инструмент для построения графов
sudo npm install -g graphweave        # Оркестратор графов для монорепо
graphify hook install                 # Хуки для авто-обновления (в каждом репо отдельно)
```

### Команды из корня mono

```bash
graphweave up --no-register          # Построить графы для всех репозиториев
graphweave watch                      # Следить за изменениями и обновлять графы автоматически
```

### Команды внутри submodule (api/ или ui/)

```bash
graphify update                       # Перестроить граф для текущего репозитория
graphify hook install                 # Установить pre-commit хук для авто-обновления
```

### Связи между репозиториями

```
ui ──consumes-api──▶ api ──routed-through──▶ proxy
```

| Файл                  | Назначение                                      |
|-----------------------|-------------------------------------------------|
| `graphweave.yaml`     | Конфиг Graphweave: репозитории и связи          |
| `.graphifyignore`     | Исключения из графа (аналог .gitignore)         |
| `.graphweave/`        | Выходные данные Graphweave (gitignored)         |
| `graphify-out/`       | Выходные данные Graphify (gitignored)           |

Подробнее — в [`AGENTS.md`](AGENTS.md).
