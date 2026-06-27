# Git Submodules в Mono репо

## Структура

Mono репо (`dmc-1-t1-notebook-mono`) содержит два submodule:

```
dmc-1-t1-notebook-mono/
  api/  →  github.com/larchanka-training/dmc-1-t1-notebook-api  (ветка main)
  ui/   →  github.com/larchanka-training/dmc-1-t1-notebook-ui   (ветка main)
```

Каждый submodule — это указатель на конкретный коммит в другом репозитории. Mono репо не хранит код api и ui, только SHA коммита.

---

## Автоматическое обновление

При каждом merge в `main` в api или ui репо запускается цепочка:

```
Push в main (api или ui репо)
    │
    ▼
CI/CD: job notify-mono
    │  peter-evans/repository-dispatch
    │  event-type: submodule-update
    ▼
Mono репо: workflow update-submodules
    │  git submodule update --remote --force
    │  Создаёт ветку chore/update-submodules-<timestamp>
    ▼
PR в mono репо (chore: update submodules to latest)
    │  Автоматически закрывает предыдущий открытый PR обновления
    ▼
После merge PR — mono репо указывает на последние коммиты api и ui
```

---

## Ручные команды

**Обновить все submodules до последних коммитов из main:**
```bash
git submodule update --remote --merge
```

**Вернуть submodules к состоянию записанному в mono репо:**
```bash
git submodule update
```

**Обновить только один submodule:**
```bash
git submodule update --remote --merge api
git submodule update --remote --merge ui
```

**Зафиксировать обновление submodules в mono репо:**
```bash
git add api ui
git commit -m "chore: обновить submodules до latest main"
git push
```

---

## Когда делать ручное обновление

- Нужно проверить свежую версию api или ui локально через `docker compose up` до того как автоматический PR смержен
- Автоматический PR ещё не создан или завис
- Нужно обновить только один submodule, не дожидаясь CI/CD

---

## Локальная работа с submodules

При первом клонировании mono репо submodules не подтягиваются автоматически:

```bash
git clone --recurse-submodules <url>
# или после обычного clone:
git submodule update --init --recursive
```

---

## Graphify / Graphweave

Монорепо использует [Graphify](https://github.com/nicholasgasior/graphify) + Graphweave
для построения графа зависимостей кода.

### Конфигурация

| Файл | Назначение |
|---|---|
| `graphweave.yaml` | Конфиг Graphweave: репозитории и связи |
| `.graphifyignore` | Исключения из графа (в mono, api, ui) |
| `.graphweave/` | Выходные данные Graphweave (gitignored) |
| `graphify-out/` | Выходные данные Graphify (gitignored) |

### Связи между репозиториями

```
ui ──consumes-api──▶ api
api ──routed-through──▶ proxy
```

### Команды из корня mono

```bash
graphweave up --no-register    # Построить графы для всех репозиториев
graphweave watch               # Следить за изменениями
```

### Команды внутри submodule

```bash
graphify update                # Перестроить граф для текущего репо
graphify hook install          # Установить pre-commit хук
```

Подробнее — в `AGENTS.md` монорепозитория.
