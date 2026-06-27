# Руководство по локальной настройке

## Зачем всё это?

### Docker — единая среда для всей команды

Все сервисы работают в контейнерах, что гарантирует одинаковую конфигурацию для всех разработчиков и устраняет проблему "у меня работает".

### Локальные домены (notebook.com и поддомены)

Используются для:
- корректной работы cookie (особенно **SameSite**, secure cookies),
- правильной работы OAuth / redirect URL,
- настройки reverse-proxy через virtual hosts,
- эмуляции production-инфраструктуры.

### HTTPS даже локально

Self-signed сертификат обеспечивает:
- secure cookies,
- service workers,
- API, требующие https,
- корректную работу процесса аутентификации.

Браузер предупредит, что сертификат недоверенный — это нормально для dev. Просто нажмите **Дополнительно → Перейти на сайт**.

---

## Настройка локальных доменов

Чтобы открывать `notebook.com`, `api.notebook.com` и `pgadmin.notebook.com` локально, добавьте записи в hosts-файл:

```
127.0.0.1 notebook.com
127.0.0.1 api.notebook.com
127.0.0.1 pgadmin.notebook.com
```

### Как редактировать `hosts`

**macOS / Linux:**

```
sudo nano /etc/hosts
```

**Windows:**

Открыть Notepad от имени администратора → открыть файл:
`C:\Windows\System32\drivers\etc\hosts`

После изменений сбросьте DNS-кеш (например, `ipconfig /flushdns` на Windows).

---

## Запуск проекта локально

### Шаг 0. Подготовить .env

```bash
cp .env.example .env
```

Открыть `.env` и заполнить все значения, помеченные `[REQUIRED]`.

Для локальной разработки достаточно значений по умолчанию из `.env.example`. Обратите внимание на переменную `JWT_SECRET` — в `.env.example` она содержит небезопасное значение-заглушку. Для локальной работы это нормально; в production она **должна** быть заменена на случайный секрет (см. [secrets-management.md](../dev-ops/secrets-management.md)).

### Шаг 1. Запустить стек

**macOS / Linux:**
```bash
make up
```

**Windows (PowerShell):**
```powershell
.\start.ps1
```

Обе команды делают одно и то же: тянут последние изменения всех репозиториев,
пересобирают образы если изменились зависимости, запускают все сервисы
и применяют миграции БД.

### Остановка сервисов

```bash
make down
# или напрямую:
docker compose down
```

---

## Как `docker compose up` делает всё сам

Устанавливать зависимости и запускать dev-серверы вручную не нужно — всё прописано в Docker-конфигурации.

**API** (`api/Dockerfile`):
- Зависимости устанавливаются при сборке образа: `pip install -r requirements.txt`
- `docker-compose.yaml` переопределяет стандартную команду на запуск FastAPI в dev-режиме с hot-reload:
  ```
  fastapi dev app/main.py --host 0.0.0.0 --port 8000
  ```
- Исходный код монтируется как volume (`./api:/app`), поэтому локальные изменения применяются сразу без пересборки образа.

**Frontend** (`docker-compose.yaml`, `command:`):
- Compose-файл использует stage `builder` из `ui/Dockerfile` и задаёт команду запуска:
  ```
  npm ci --prefer-offline && npm run dev -- --host
  ```
- Node modules хранятся в named Docker volume (`ui-node-modules`) и сохраняются между перезапусками.
- Исходный код монтируется как volume (`./ui:/home/app`), что обеспечивает hot-reload через Vite.

---

## Адреса после запуска

| Сервис | URL |
|--------|-----|
| Frontend | [https://notebook.com](https://notebook.com/) |
| API | [https://api.notebook.com](https://api.notebook.com/) |
| pgAdmin | [https://pgadmin.notebook.com](https://pgadmin.notebook.com/) |

При первом открытии браузер может показать предупреждение о сертификате — это ожидаемо.

---

## Предупреждение о self-signed сертификате

Браузер покажет сообщение о ненадёжном соединении. Нажмите **Дополнительно → Перейти на сайт**.

Это типично для локальной разработки. Чтобы убрать предупреждения, используйте `mkcert` для генерации доверенного локального сертификата.

---

## Полезные команды

| Команда | Платформа | Описание |
|---------|-----------|----------|
| `make up` | macOS / Linux | Запустить всё свежее (pull + build + migrate) |
| `.\start.ps1` | Windows | То же самое для PowerShell |
| `make fresh` | macOS / Linux | Полная пересборка с нуля (⚠️ удаляет данные БД) |
| `make migrate` | macOS / Linux | Применить миграции БД вручную (без перезапуска стека) |
| `make down` | macOS / Linux | Остановить сервисы |
| `make logs` | macOS / Linux | Логи всех сервисов в реальном времени |
| `docker ps` | все | Показать запущенные контейнеры |
| `docker compose logs -f` | все | Стримить логи сервисов |

Полный список команд: [docker-compose.md](./docker-compose.md)

---

## Устранение проблем

### Сайт не открывается

Проверьте:
- hosts-файл,
- что контейнеры запущены (`docker ps`),
- логи (`docker compose logs`).

### Порт уже занят

Найдите, что его использует:
- macOS/Linux: `lsof -i :80` / `lsof -i :443`
- Windows: `netstat -a -b`

### Предупреждение о сертификате

Это нормально. Нажмите **Продолжить**. Чтобы убрать предупреждения, используйте `mkcert`.

### Frontend или backend не запустились

Проверьте:
- что контейнер найден (имя совпадает с ожидаемым),
- что зависимости установились корректно.

---

## Разработка без Docker (uvicorn + vite dev напрямую)

Иногда удобно запустить backend и frontend напрямую, без Docker — для отладки или быстрой разработки.

### Backend (FastAPI)

```bash
cd api
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
fastapi dev app/main.py --host 0.0.0.0 --port 8000
```

### Frontend (Vite)

```bash
cd ui
npm ci
npm run dev
```

Vite запустится на `http://localhost:5173`, API — на `http://localhost:8000`.
Vite proxy автоматически перенаправляет `/api` запросы на backend.

### COOKIE_DOMAIN для non-Docker

При запуске без Docker (через `localhost:5173` + `localhost:8000`):
- Установите `COOKIE_DOMAIN=` (пустая строка) в `api/.env`
- Браузер привяжет cookie к `localhost`
- Если оставить `COOKIE_DOMAIN=.notebook.com`, браузер **не примет** cookie — домен не совпадает с хостом

### Адреса (non-Docker)

| Сервис | URL |
|--------|-----|
| Frontend | http://localhost:5173 |
| API | http://localhost:8000 |
| API docs | http://localhost:8000/docs |
