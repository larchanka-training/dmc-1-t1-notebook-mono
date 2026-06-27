---
name: submodule-discipline
description: "Submodule workflow: commit внутри submodule → pointer в mono, синхронизация, GitHub Action update-submodules."
---

# Skill: submodule-discipline

Правила работы с git submodules в монорепозитории.

## Когда использовать

- Любые изменения в `api/` или `ui/` внутри mono.
- Синхронизация submodule'ов после pull.
- Обновление pointer'ов в mono.

## Алгоритм

1. **Изменения внутри submodule:**
   ```bash
   # Внести изменения в api/ или ui/
   cd api && git add . && git commit -m "описание изменения"
   ```
2. **Обновить pointer в mono:**
   ```bash
   cd ..
   git add api    # или ui
   git commit -m "chore: обновить api submodule"
   ```
3. **Синхронизация после pull:**
   ```bash
   git pull origin main
   git submodule update --remote --merge
   ```
   Или через Makefile: `make up` (подтягивает изменения автоматически).
4. **GitHub Action** `.github/workflows/update-submodules.yml` автоматически синхронизирует submodules при push в mono.

## Чего избегать

- Коммита pointer'а submodule без commit'а внутри submodule.
- Прямых правок в mono, которые должны быть в submodule.
- `git add -A` в mono — можно случайно закоммитить изменения внутри submodule как part of mono.
- Удаления `.gitmodules` или ручного редактирования submodule URL'ов.
