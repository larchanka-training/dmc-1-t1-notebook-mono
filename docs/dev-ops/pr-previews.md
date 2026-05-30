# PR Preview

## Обзор

PR Preview — автоматическое развёртывание UI для каждого pull request в репозитории `dmc-1-t1-notebook-ui`. Как только разработчик открывает PR, GitHub Actions собирает приложение и публикует его по уникальному URL. Рецензент может открыть живое приложение прямо из комментария к PR, без локального запуска.

**Формат URL:** `https://{CF_DOMAIN}/pr-{N}/`

Пример: `https://d2dbju5cjbhc1q.cloudfront.net/pr-23/`

---

## Архитектура

```
GitHub Actions
     │
     ├─ npm run build --base=/pr-N/
     │
     └─ aws s3 sync → S3 bucket (dmc-1-t1-notebook-previews)
                              │
                        CloudFront Distribution
                         ┌────────────────────┐
                         │  /api/v1/*  → dev ALB (HTTP)  │
                         │  /*         → S3 (статика)     │
                         └────────────────────┘
                                   │
                              браузер
```

Запросы `/api/v1/*` проксируются через CloudFront на существующий dev ALB — превью работает с живым API и общей dev-базой данных.

### AWS-ресурсы

| Ресурс | Имя | Назначение |
|--------|-----|-----------|
| S3 Bucket | `dmc-1-t1-notebook-previews` | Хранит собранные файлы всех превью по путям `pr-{N}/` |
| CloudFront OAC | `dmc-1-t1-notebook-preview-oac` | Origin Access Control: S3 приватный, доступ только через CloudFront |
| CloudFront Function | `dmc-1-t1-notebook-preview-spa-rewrite` | Rewrite `/pr-N/path` → `/pr-N/index.html` для SPA-навигации |
| CloudFront Distribution | `E30N8I6Q63AJ0V` | Раздаёт статику + проксирует API |

Инфраструктура описана в Terraform: `infra/envs/dev/main.tf` (блок «PR Preview»).

---

## Lifecycle превью

| Событие PR | Что происходит |
|------------|---------------|
| Открыт / обновлён (push в ветку) | GHA собирает UI, синхронизирует файлы в S3, инвалидирует CloudFront кэш, создаёт или обновляет комментарий с URL |
| Закрыт или смержен | GHA удаляет папку `pr-{N}/` из S3, инвалидирует кэш |
| Файлы остались после сбоя cleanup | S3 Lifecycle policy удаляет их автоматически через 7 дней |

---

## GitHub Actions workflow (`preview.yml`)

**Файл:** `dmc-1-t1-notebook-ui/.github/workflows/preview.yml`

**Триггер:** `pull_request` с типами `opened`, `synchronize`, `reopened`, `closed` на ветки `main`/`develop`

| Job | Условие | Описание |
|-----|---------|----------|
| `changes` | PR открыт/обновлён | Определяет есть ли изменения в коде (paths-filter) |
| `deploy-preview` | изменения есть, PR не закрыт | Сборка → S3 sync → CF инвалидация → комментарий в PR |
| `cleanup-preview` | PR закрыт | `aws s3 rm pr-{N}/` → CF инвалидация |

### GHA Variables

Должны быть прописаны вручную в репо `dmc-1-t1-notebook-ui` после первого `terraform apply`:
**Settings → Secrets and variables → Actions → Variables**

| Variable | Значение | Откуда взять |
|----------|----------|-------------|
| `S3_PREVIEW_BUCKET` | `dmc-1-t1-notebook-previews` | `terraform output preview_s3_bucket` |
| `CF_DISTRIBUTION_ID` | `E30N8I6Q63AJ0V` | `terraform output preview_cf_distribution_id` |
| `CF_DOMAIN` | `d2dbju5cjbhc1q.cloudfront.net` | `terraform output preview_cf_domain` |

---

## Terraform-инфраструктура

**Файл:** `infra/envs/dev/main.tf` (блок «PR Preview: S3 + CloudFront»)

**Outputs:** `infra/envs/dev/outputs.tf`

Ресурсы создаются один раз в dev-окружении и не зависят от отдельных PR. При изменении инфраструктуры — `terraform apply` запускается автоматически через `terraform.yml` при push в `main`.

---

## SPA routing

React Router использует `BrowserRouter` с history API. При обслуживании приложения с path-prefix `/pr-23/` возникают две проблемы:

**Проблема 1 — пути ассетов.** Vite по умолчанию генерирует абсолютные пути `/assets/...`. При сборке с флагом `--base=/pr-23/` они становятся `/pr-23/assets/...` — правильно для S3.

**Проблема 2 — навигация React Router.** Без `basename` роутер не знает о prefix и при переходе между ноутбуками ломает URL. Решение:

```tsx
// src/app/router/AppRouter.tsx
<BrowserRouter basename={import.meta.env.BASE_URL}>
```

`import.meta.env.BASE_URL` содержит значение флага `--base` на момент сборки.

**Проблема 3 — refresh по вложенному URL.** CloudFront не находит файл `pr-23/some-id` в S3 и возвращает 404. CloudFront Function перехватывает запрос на viewer-request и делает rewrite:

```js
// /pr-N/path-without-extension → /pr-N/index.html
var match = uri.match(/^(\/pr-\d+)(\/[^.]*)?$/);
if (match) request.uri = match[1] + '/index.html';
```

---

## Ограничения

- Превью использует **dev API и dev базу данных** — данные общие для всех открытых PR и dev-окружения
- CloudFront инвалидация асинхронна: после деплоя обновление может занять до 1–2 минут
- При сбое `cleanup-preview` job файлы автоматически исчезнут через **7 дней** (S3 Lifecycle policy) — ручная очистка описана в [deployment-runbook.md](./deployment-runbook.md#управление-pr-preview)

---

## Связанные документы

- [github-actions.md](./github-actions.md) — описание workflow `preview.yml`
- [aws-infrastructure.md](./aws-infrastructure.md) — таблица AWS-ресурсов
- [environments.md](./environments.md) — URL превью и ссылки на AWS Console
- [deployment-runbook.md](./deployment-runbook.md) — операционные инструкции
