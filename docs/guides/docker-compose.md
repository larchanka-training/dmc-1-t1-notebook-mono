# Локальный запуск через Docker Compose

Весь стек поднимается одной командой из корня Mono репозитория. Ниже описаны типичные сценарии и команды.

---

## Быстрый старт — одна команда на всё

Не хочешь думать что там намержили другие разработчики? Одна команда сделает всё:

```bash
make up
```

Что происходит под капотом:
1. `git pull origin main` + `git submodule update --remote --merge` — тянет последние изменения API и UI
2. `docker compose build` — пересобирает образы если изменились зависимости (использует кэш, быстро)
3. `docker compose up -d --wait` — поднимает все сервисы, ждёт health checks
4. `docker compose exec api alembic upgrade head` — применяет новые миграции БД

### Остальные Makefile-команды

| Команда | Когда использовать |
|---------|-------------------|
| `make up` | Стандартный запуск — тянет всё свежее и запускает |
| `make fresh` | Что-то сломалось — полная пересборка без кэша, удаляет volumes (⚠️ БД очищается) |
| `make down` | Остановить стек (данные сохраняются) |
| `make wipe` | Остановить и удалить все данные |
| `make migrate` | Применить только миграции (стек уже запущен) |
| `make logs` | Стримить логи всех сервисов |
| `make ps` | Статус контейнеров |

> Команды `make` запускаются из корня mono репозитория (рядом с `docker-compose.yml`).

---

---

## Сервисы

```mermaid
graph LR
    browser[Браузер] --> proxy[nginx proxy :80/:443]
    proxy -->|notebook.com| ui[UI :5173]
    proxy -->|api.notebook.com| api[API :8000]
    proxy -->|pgadmin.notebook.com| pgadmin[pgAdmin :80]
    proxy -->|aspire.notebook.com| aspire[Aspire Dashboard :18888]
    api --> postgres[(PostgreSQL :5432)]
    api -->|OTLP gRPC| aspire
```

| Сервис | Образ | localhost | notebook.com |
|--------|-------|-----------|-------------|
| UI (фронтенд) | собирается локально | `http://localhost:3000` | `https://notebook.com` |
| API (бэкенд) | собирается локально | `http://localhost:8000` | `https://api.notebook.com` |
| PostgreSQL | `postgres:16` | `localhost:5432` | — |
| pgAdmin | `dpage/pgadmin4` | `http://localhost:5050` | `https://pgadmin.notebook.com` |
| Aspire Dashboard | `mcr.microsoft.com/dotnet/aspire-dashboard` | `http://localhost:18888` | `https://aspire.notebook.com` |
| nginx proxy | собирается локально | `:80` / `:443` | обслуживает все домены выше |

---

## Первый запуск

```bash
# 1. Скопировать и заполнить переменные окружения
cp .env.example .env

# 2. Поднять весь стек
docker compose up --build
```

Флаг `--build` пересобирает образы при первом запуске или после изменений в коде.

---

## Стандартные сценарии

### Запустить всё в фоне

```bash
docker compose up -d
```

### Запустить и смотреть логи в реальном времени

```bash
docker compose up
```

### Пересобрать после изменений в коде

```bash
docker compose up --build
```

### Пересобрать только один сервис

```bash
docker compose up --build api
docker compose up --build frontend
```

### Остановить все сервисы (без удаления данных)

```bash
docker compose down
```

### Остановить и удалить все данные (volumes)

> ⚠️ Удаляет данные PostgreSQL и node_modules volume

```bash
docker compose down -v
```

Используй когда:
- node_modules в контейнере устарел (ошибка версии esbuild или других пакетов)
- нужно начать с чистой базы данных

### Посмотреть логи конкретного сервиса

```bash
docker compose logs api
docker compose logs frontend
docker compose logs -f api      # в реальном времени
```

### Зайти в контейнер

```bash
docker compose exec api bash
docker compose exec frontend sh
```

### Проверить статус контейнеров

```bash
docker compose ps
```

### Перезапустить один сервис без пересборки

```bash
docker compose restart api
```

### Применить новые миграции БД

После того как кто-то добавил новую модель — применить миграцию к локальной БД:

```bash
docker compose exec api alembic upgrade head
# или короче:
make migrate
```

> Только локально. В dev/prod на AWS миграции применяются автоматически
> при старте ECS-контейнера — делать ничего не нужно.

---

## OpenTelemetry и Aspire Dashboard

По умолчанию OTel выключен (`OTEL_ENABLED=false`). Чтобы включить сбор трейсов и логов:

1. В `.env` выставить:
   ```
   OTEL_ENABLED=true
   ```
2. Перезапустить стек:
   ```bash
   docker compose up -d
   ```
3. Открыть Aspire Dashboard: [http://localhost:18888](http://localhost:18888)

Подробнее о логировании и трейсах — в [observability.md](./observability.md).

---

## Troubleshooting

### Порт уже занят

```bash
# macOS / Linux
lsof -i :8000
lsof -i :80

# Windows
netstat -a -b
```

### node_modules устарел (ошибка версии esbuild)

```bash
docker compose down -v
docker compose up --build
```

### API не видит базу данных

Убедиться, что в `.env` значение `DATABASE_URL` использует имя сервиса `postgres`, а не `localhost`:
```
DATABASE_URL=postgresql://admin:changeme@postgres:5432/wiki
```

### Изменения в коде не применяются

Для API и UI используется hot reload — изменения должны применяться автоматически. Если нет — пересобрать образ:
```bash
docker compose up --build <service>
```
