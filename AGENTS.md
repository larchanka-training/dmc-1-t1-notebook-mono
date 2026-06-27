# AGENTS.md — dmc-1-t1-notebook-mono

JavaScript Notebook платформа (аналог Jupyter) для написания заметок и выполнения JS/Markdown ячеек. Разрабатывается в рамках учебного курса.

**Поведенческие гайдлайны:** см. раздел «Поведенческие правила» ниже. Технические скиллы — в `.agents/skills/`.

## Структура репозитория

```
dmc-1-t1-notebook-mono/
├── api/          # FastAPI backend (git submodule → dmc-1-t1-notebook-api)
├── ui/           # React frontend (git submodule → dmc-1-t1-notebook-ui)
├── proxy/        # Nginx reverse proxy
├── docs/         # Архитектура, гайды, QA документация
└── docker-compose.yaml
```

## Tech Stack

| Слой     | Технологии                                          |
|----------|-----------------------------------------------------|
| Backend  | Python 3.11, FastAPI, Uvicorn, Pydantic, PostgreSQL |
| Frontend | React 18, TypeScript 5.6, Vite 7, Redux Toolkit     |
| UI libs  | CodeMirror, React Markdown, Tailwind CSS 4          |
| Infra    | Docker Compose, Nginx, OpenTelemetry (Aspire)       |

## Локальная разработка

```bash
docker compose up --build
```

| Сервис           | URL                          |
|------------------|------------------------------|
| UI               | http://localhost:3000        |
| API              | http://localhost:8000        |
| API docs         | http://localhost:8000/docs   |
| Aspire Dashboard | http://localhost:18888       |
| PgAdmin          | http://localhost:5050        |

## Submodule Workflow

При редактировании `api/` или `ui/` внутри mono:

```bash
# 1. Внести изменения внутри папки submodule (api/ или ui/)
# 2. Создать commit внутри submodule
cd api && git add . && git commit -m "описание изменения"
# 3. Вернуться в корень mono и обновить pointer на submodule
cd .. && git add api && git commit -m "chore: обновить api submodule"
```

GitHub Action `.github/workflows/update-submodules.yml` автоматически синхронизирует submodules при push.

## Документация

- Архитектура: `docs/architecture.md`, `docs/architecture/`
- Локальная настройка: `docs/guides/local-setup.md`
- Docker Compose: `docs/guides/docker-compose.md`
- Observability: `docs/guides/observability.md`
- QA: `docs/qa/` (qa-plan, definition-of-done, acceptance-criteria)
- CI/CD: `docs/ci-cd.md`

## Graphify — Code Graph

Проект использует [Graphify](https://github.com/nicholasgasior/graphify) + Graphweave для построения графа зависимостей кода. Конфиг `graphweave.yaml` в корне mono описывает репозитории (submodules) и связи между ними.

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

### Структура

| Файл                  | Назначение                                      |
|-----------------------|-------------------------------------------------|
| `graphweave.yaml`     | Конфиг Graphweave: репозитории и связи          |
| `.graphifyignore`     | Исключения из графа (аналог .gitignore)         |
| `.graphweave/`        | Выходные данные Graphweave (gitignored)         |
| `graphify-out/`       | Выходные данные Graphify (gitignored)           |

### Связи между репозиториями

```
ui ──consumes-api──▶ api
api ──routed-through──▶ proxy
```

### Что исключено из графа

- Документация (`.md`, `.txt`, `.rst`, `.html`)
- Конфиги (`.yaml`, `.yml`) — кроме `graphweave.yaml`
- Медиа (`.png`, `.jpg`, `.svg`, `.ico`)
- Сборки (`dist/`, `node_modules/`, `__pycache__/`, `.venv/`)
- Логи, секреты, egg-info

## Навигация для агента

`AGENTS.md` — **единая точка входа и источник истины** для всех AI-агентов проекта. Файлы `CLAUDE.md`, `GEMINI.md`, `QWEN.md`, `.github/copilot-instructions.md` — относительные symlink'и на этот файл. Меняй правила **здесь** — изменения подхватят все агенты. Подробно — `.agents/README.md`.

## Skills

Скиллы-дисциплины для разработки живут в `.agents/skills/<name>/SKILL.md`. Если тема задачи совпадает со скиллом — прочитай его **до** правок.

- `.agents/skills/architecture-discipline/SKILL.md` — границы слоёв (UI→API→Proxy), submodule изоляция; загружай первым для широкой задачи.
- `.agents/skills/code-review-discipline/SKILL.md` — чек-лист ревью: хирургичность, тесты, стиль, безопасность.
- `.agents/skills/documentation-discipline/SKILL.md` — относительные пути, синхронизация ссылок, doc-before-code.
- `.agents/skills/error-handling-discipline/SKILL.md` — FastAPI HTTPException, React error boundaries, человеческие сообщения.
- `.agents/skills/git-discipline/SKILL.md` — ветки, Conventional Commits, формат коммита, секреты не коммитим.
- `.agents/skills/submodule-discipline/SKILL.md` — submodule workflow: commit внутри → pointer в mono.
- `.agents/skills/testing-discipline/SKILL.md` — pytest (API) + Vitest (UI), моки внешних систем, без сети.

## Рекомендуемый порядок загрузки

- Широкая или неочевидная задача: `architecture-discipline` → профильный скилл.
- Код в `api/`: `architecture-discipline` → `testing-discipline` → `error-handling-discipline`.
- Код в `ui/`: `architecture-discipline` → `testing-discipline` → `error-handling-discipline`.
- Задача про документацию: `documentation-discipline`. Про коммит/ветку: `git-discipline`. Про submodule: `submodule-discipline`.
- Ревью PR: `code-review-discipline`.

## Поведенческие правила

### 1. Сначала думай, потом кодь

**Не додумывай. Не прячь сомнения. Озвучивай развилки.**

- Явно сформулируй свои допущения. Если не уверен — спроси.
- Если возможно несколько интерпретаций задачи — назови их, не выбирай молча.
- Если есть более простой способ — скажи об этом.
- Если что-то непонятно — остановись и задай вопрос.

### 2. Минимализм

**Минимум кода, решающего задачу. Никаких спекуляций.**

- Никаких фич, которых не просили.
- Никаких абстракций ради одного использования.
- Если получилось 200 строк, а хватило бы 50 — перепиши.

### 3. Хирургические правки

**Трогай только то, что необходимо. Прибирай только за собой.**

- Не «улучшай» соседний код, комментарии или форматирование.
- Не рефактори то, что не сломано.
- Сохраняй существующий стиль кода.
- Заметил мёртвый код, не относящийся к задаче — упомяни, **не удаляй**.

### 4. Выполнение от цели

**Определяй критерий успеха. Итеративно проверяй, пока не достигнешь его.**

- «Почини баг» → «Напиши тест, воспроизводящий баг, потом сделай его зелёным».
- «Добавь фичу» → «Напиши тесты, потом сделай их зелёными».

## Agent Workflow

### 1. Перед выполнением задачи
- Изучи задачу, подготовь план, предоставь пользователю на ревью
- Получи явное одобрение перед началом любых изменений в коде

### 2. Git (после одобрения плана)
```bash
git checkout main
git pull origin main
git checkout -b <тип>/<краткое-описание>   # feat/, fix/, chore/
```
При изменениях в `api/` или `ui/` — создавать commit внутри submodule, затем обновить pointer в mono.

### 3. Тестирование
- API (`api/`): pytest, покрыть новый код тестами
- UI (`ui/`): Vitest unit-тесты; Playwright E2E если затронут UI-флоу

### 4. Перед коммитом
- Запроси одобрение у пользователя с кратким summary изменений
- После одобрения запусти тесты в затронутых репозиториях — все должны пройти

### 5. Формат коммита
```
<Тема: максимум 50 символов>

# Краткое описание
* Что реализовано

# Почему
* Причины выбора подхода

# План тестирования
✅ pytest: X/X пройдены (включая N новых)
✅ vitest: X/X пройдены
```

### 6. Pull Request
```bash
gh pr create --title "<заголовок до 70 символов>" --body "..."
```
Тело PR: краткий Summary + Test plan.
