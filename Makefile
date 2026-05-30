.PHONY: up fresh down wipe logs ps migrate

# ─────────────────────────────────────────────
# Магия: тянет последние изменения всех репо,
# пересобирает образы где нужно, запускает стек,
# применяет миграции БД.
# ─────────────────────────────────────────────
up:
	@echo "→ Pulling latest changes..."
	git pull origin main
	git submodule update --remote --merge
	@echo "→ Building and starting services (waiting for health checks)..."
	docker compose up -d --build --wait
	@echo "→ Applying DB migrations..."
	@docker compose exec api sh -c "command -v alembic >/dev/null 2>&1 && alembic upgrade head || echo '  ℹ  alembic not configured yet — skipping (see .agents/add-model.md)'"
	@echo "✓ Stack is up. See: https://notebook.com"

# ─────────────────────────────────────────────
# Полная пересборка с нуля.
# Удаляет все volumes (БД и node_modules).
# Используй когда up не помогает.
# ─────────────────────────────────────────────
fresh:
	@echo "⚠ Removing all volumes (DB data will be lost)..."
	docker compose down -v
	@echo "→ Pulling latest changes..."
	git pull origin main
	git submodule update --remote --merge
	@echo "→ Building images without cache..."
	docker compose build --no-cache
	@echo "→ Starting services..."
	docker compose up -d --wait
	@echo "→ Applying DB migrations..."
	@docker compose exec api sh -c "command -v alembic >/dev/null 2>&1 && alembic upgrade head || echo '  ℹ  alembic not configured yet — skipping (see .agents/add-model.md)'"
	@echo "✓ Fresh stack is up."

# ─────────────────────────────────────────────
# Остановить сервисы (данные сохраняются)
# ─────────────────────────────────────────────
down:
	docker compose down

# ─────────────────────────────────────────────
# Остановить и удалить все данные (volumes)
# ─────────────────────────────────────────────
wipe:
	docker compose down -v

# ─────────────────────────────────────────────
# Применить миграции БД вручную
# ─────────────────────────────────────────────
migrate:
	docker compose exec api alembic upgrade head

# ─────────────────────────────────────────────
# Утилиты
# ─────────────────────────────────────────────
logs:
	docker compose logs -f

ps:
	docker compose ps
