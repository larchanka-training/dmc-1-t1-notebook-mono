---
name: git-discipline
description: "Git-дисциплина: ветки feat/fix/chore, Conventional Commits на русском, формат коммита проекта, секреты не коммитим, submodule workflow."
---

# Skill: git-discipline

Правила работы с git в монорепозитории и submodules.

## Когда использовать

- Начинаешь или закрываешь задачу.
- Готовишь любой коммит.
- Работаешь с submodule'ами (api, ui).

## Алгоритм

1. **Ветки.** Основная — `main`, рабочие — `feat/<краткое-описание>`, `fix/<краткое-описание>`, `chore/<краткое-описание>`.
2. **Коммиты — атомарные**, по Conventional Commits. Текст — на русском, идентификаторы — латиницей.
   - `feat(analytics): добавить endpoints аналитики`
   - `fix(executor): обработать ошибку Web Worker`
   - `docs(readme): актуализировать структуру проекта`
   - `chore: add graphify config`
3. **Формат коммита проекта:**
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
4. **Submodule workflow.** При правках в `api/` или `ui/`:
   - Commit внутри submodule → вернуться в mono → `git add api` (или `ui`) → commit обновления pointer'а.
   - Никогда не коммитить submodule pointer без commit'а внутри submodule.
5. **Перед каждым кодовым коммитом** — тесты зелёные:
   - API: `ruff check . && pytest`
   - UI: `npm run lint && npm run test && npm run build`
6. **`.gitignore`** обязан содержать: `.env`, `.venv/`, `__pycache__/`, `node_modules/`, `dist/`, `*.egg-info/`, `graphify-out/`, `.graphweave/`.

## Чего избегать

- Коммита `.env`, токенов, логов, `*.db`.
- Push / merge в `main` — это делает **только пользователь** по явному запросу.
- Неатомарных коммитов (несколько несвязанных правок в одном).
- Коммита при красных тестах.
- Прямых правок в submodule без commit'а внутри него.

## Что делать при утечке секрета

Если токен случайно попал в историю — ротировать токен, удалить из истории (`git filter-repo`).
