# GitHub Actions

## dmc-1-t1-notebook-api

### CI/CD (`ci-cd.yml`)

**Триггер:** push в `main`/`develop`, теги `v*`, PR в `main`/`develop`

| Job | Условие | Описание |
|-----|---------|----------|
| `changes` | всегда | Определяет есть ли изменения в коде (paths-filter) |
| `lint` | изменения в коде | Проверка стиля через ruff |
| `test` | изменения в коде | Запуск pytest |
| `build` | изменения в коде | Сборка Docker-образа и push в GHCR (только при push в main/тег) |
| `deploy-dev` | push в main | Деплой на dev ECS: новая ревизия task definition с `sha-<commit>` тегом |
| `notify-mono` | push в main | Отправка `repository-dispatch` в mono репо для обновления submodule |

**Теги образов:**
- `latest` — при push в main
- `sha-<commit>` — при каждом push (используется для деплоя и rollback)
- `v1.2.3` — при push тега

---

## dmc-1-t1-notebook-ui

### CI/CD (`ci-cd.yml`)

**Триггер:** push в `main`/`develop`, теги `v*`, PR в `main`/`develop`

| Job | Условие | Описание |
|-----|---------|----------|
| `changes` | всегда | Определяет есть ли изменения в коде (paths-filter) |
| `lint` | изменения в коде | Проверка через ESLint |
| `test` | изменения в коде | Запуск vitest |
| `build` | изменения в коде | Сборка Docker-образа и push в GHCR (только при push в main/тег) |
| `deploy-dev` | push в main | Деплой на dev ECS: новая ревизия task definition с `sha-<commit>` тегом |
| `notify-mono` | push в main | Отправка `repository-dispatch` в mono репо для обновления submodule |

---

## dmc-1-t1-notebook-mono

### Terraform (`terraform.yml`)

**Триггер:** push/PR в `main` (изменения в `infra/`), `workflow_dispatch`

| Job | Условие | Описание |
|-----|---------|----------|
| `terraform-dev` (Plan) | PR или `workflow_dispatch` | `terraform init` + `validate` + `plan` |
| `terraform-dev` (Apply) | push в main | `terraform init` + `validate` + `apply` — автоматический деплой инфраструктуры dev |

**State:** хранится в S3 `dmc-1-t1-notebook-terraform-state`, ключ `dev/terraform.tfstate`. Лок через DynamoDB.

### Update Submodules (`update-submodules.yml`)

**Триггер:** `repository_dispatch` с типом `submodule-update` (отправляется из api/ui репо)

| Job | Описание |
|-----|----------|
| `update-submodules` | Обновляет submodules до latest main, создаёт PR с изменениями. Закрывает предыдущие открытые PR обновления submodules. |

---

## Общие секреты (org-level)

Доступны во всех репозиториях организации `larchanka-training` автоматически:

| Секрет | Используется в |
|--------|---------------|
| `AWS_ACCESS_KEY_ID` | terraform.yml, ci-cd.yml (deploy-dev job) |
| `AWS_SECRET_ACCESS_KEY` | terraform.yml, ci-cd.yml (deploy-dev job) |
| `MONO_REPO_PAT` | update-submodules.yml (push и создание PR), notify-mono job в api/ui |
