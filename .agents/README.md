# `.agents/` — скиллы и гайды для AI-агентов

Каталог содержит **переиспользуемые скиллы и пошаговые гайды** для AI-ассистентов, работающих над проектом.

## Структура

```
.agents/
├── README.md                 # этот файл
└── skills/                   # скиллы-дисциплины (<name>/SKILL.md)
    ├── architecture-discipline/
    ├── code-review-discipline/
    ├── documentation-discipline/
    ├── error-handling-discipline/
    ├── git-discipline/
    ├── submodule-discipline/
    └── testing-discipline/
```

## Скиллы (`skills/`)

Скилл — устойчивая **дисциплина/правило**, которое полезно держать перед глазами. Формат: каталог `<name>/SKILL.md` с YAML frontmatter (`name`, `description`) и телом «Когда использовать → Алгоритм → Чего избегать».

| Скилл | Назначение |
|-------|------------|
| `architecture-discipline` | Границы слоёв (UI→API→Proxy), submodule изоляция; загружай первым для широкой задачи. |
| `code-review-discipline` | Чек-лист ревью: хирургичность, тесты, стиль, безопасность. |
| `documentation-discipline` | Относительные пути, синхронизация ссылок, doc-before-code. |
| `error-handling-discipline` | FastAPI HTTPException, React error boundaries, человеческие сообщения. |
| `git-discipline` | Ветки, Conventional Commits, формат коммита, секреты не коммитим. |
| `submodule-discipline` | Submodule workflow: commit внутри → pointer в mono. |
| `testing-discipline` | pytest (API) + Vitest (UI), моки внешних систем, без сети. |

## Как пользоваться

- **Скилл.** Прочитай `SKILL.md` перед задачей соответствующего класса — он задаёт правила, по которым проверяется результат.
- Windsurf (Cascade) читает `.agents/skills/` нативно через `skill` tool.

## Рекомендуемый порядок загрузки

- Широкая или неочевидная задача: `architecture-discipline` → профильный скилл.
- Код в `api/`: `architecture-discipline` → `testing-discipline` → `error-handling-discipline`.
- Код в `ui/`: `architecture-discipline` → `testing-discipline` → `error-handling-discipline`.
- Задача про документацию: `documentation-discipline`. Про коммит/ветку: `git-discipline`. Про submodule: `submodule-discipline`.
- Ревью PR: `code-review-discipline`.

## Зеркалирование для других агентов

Чтобы одни и те же правила видели все AI-инструменты, держим **единственный источник истины** — `AGENTS.md` в корне. Зеркала-symlink'и на него:

- `CLAUDE.md → AGENTS.md` (Claude Code)
- `GEMINI.md → AGENTS.md` (Gemini CLI)
- `QWEN.md → AGENTS.md` (Qwen Code)
- `.github/copilot-instructions.md → ../AGENTS.md` (GitHub Copilot)

**Правило:** правим только `AGENTS.md` и `.agents/skills/`; зеркала-symlink'и подхватывают изменения сами. Новый агент добавляется одним symlink'ом его дефолтного контекст-файла на `AGENTS.md`.

## Как добавить новый скилл

1. Создать `skills/<name>/SKILL.md` (frontmatter `name` + `description` ≤ 200 символов, тело с разделами «Когда использовать», «Алгоритм», «Чего избегать»).
2. Добавить строку в таблицу выше.
3. Добавить строку в `AGENTS.md` (раздел «Skills»).
