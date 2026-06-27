---
name: architecture-discipline
description: "Границы слоёв (UI→API→Proxy), submodule изоляция, без новой архитектуры без согласования; указатель на остальные скиллы."
---

# Skill: architecture-discipline

Базовые архитектурные правила монорепозитория. Загружай **первым** для широкой/неочевидной задачи, затем — профильный скилл.

## Когда использовать

- Задача широкая или неочевидная — начни отсюда.
- Добавляешь компонент, endpoint, feature или поток.
- Сомневаешься, не выходит ли решение за рамки принятой архитектуры.

## Алгоритм

1. **Слоистая изоляция.** Поток: UI (React) → API (FastAPI) → Proxy (Nginx). Слой ниже не знает про слой выше: API не знает про React, Proxy не знает про бизнес-логику.
2. **Submodule границы.** `api/` и `ui/` — независимые репозитории. Изменения внутри submodule коммитятся отдельно, затем обновляется pointer в mono.
3. **API структура.** Endpoints в `app/api/v1/endpoints/`, бизнес-логика в `app/`, модели в `app/db/models/`, схемы в `app/schemas/`. Endpoint — тонкий, делегирует в сервисы/модели.
4. **UI структура.** Feature-first: `src/features/<feature>/{api,model,lib,ui}`. Shared код в `src/shared/`. App-level в `src/app/`.
5. **Без новой архитектуры без согласования.** Новый слой/сервис/абстракция/паттерн/зависимость — сначала проговорить с пользователем. В рамках задачи — только локальные технические решения.
6. **Async-first (API).** Любый I/O — через `await` (asyncpg, httpx, Bedrock).
7. **State management (UI).** Redux Toolkit для глобального state, `useMemo`/`useState` для локального. Не вводить новый state manager без согласования.

## Куда дальше

- Тесты → `testing-discipline`. Ошибки → `error-handling-discipline`.
- Документация → `documentation-discipline`. Git и коммиты → `git-discipline`.
- Submodule workflow → `submodule-discipline`.

## Чего избегать

- Обращения UI к БД в обход API.
- Бизнес-логики в Proxy (Nginx).
- Новых зависимостей / слоёв / паттернов без согласования.
- Смешивания API и UI кода в одном репозитории.
