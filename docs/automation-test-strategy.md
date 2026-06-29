# Automation Test Strategy

> Issue [#48](https://github.com/larchanka-training/js-notebook/issues/48) — Create Automation test strategy

Дата: 2026-06-28

## Текущее состояние

### Что уже автоматизировано

| Слой | Инструмент | CI | Файлов тестов | Покрытие |
|------|-----------|-----|--------------|----------|
| API unit/integration | pytest | `ci-cd.yml` → `test` job | 7 файлов | auth, notebooks, analytics, ai (context, endpoint, validation), health |
| UI unit/component | vitest | `ci-cd.yml` → `test` job | 19 файлов | notebook model, executor, services, components, auth, analytics |
| Linting API | ruff | `ci-cd.yml` → `lint` job | — | — |
| Linting UI | eslint | `ci-cd.yml` → `lint` job | — | — |

### Что не автоматизировано (пробелы)

| Пробел | Влияние | Приоритет |
|--------|---------|-----------|
| Нет E2E тестов | Регрессии UI flow не детектируются автоматически | High |
| Нет coverage измерения | Неизвестно реальное покрытие, нет CI gate | Medium |
| Нет integration тестов API↔DB | Тесты используют моки БД, не проверяют реальные SQL-запросы | Medium |
| Нет contract тестов API↔UI | Изменение API может сломать UI без предупреждения | Medium |
| Нет visual regression | Изменения в UI компонентах не проверяются визуально | Low |
| Нет load/performance тестов | Деградация производительности не детектируется | Low |

---

## Стратегия

### Принципы

1. **Пирамида тестов** — больше unit, меньше E2E. E2E только для критических flow.
2. **Fast feedback** — unit тесты < 10 сек, E2E < 2 минут.
3. **Тесты в CI — не локально** — каждый PR автоматически прогоняет тесты.
4. **Coverage как ориентир, не как gate** — измеряем, показываем, не блокируем merge (до 80% покрытия).
5. **Изолированные тесты** — нет сетевых вызовов, нет реальных AWS-сервисов в CI.

### Уровни тестирования

```
        ┌───────────────────┐
        │     E2E (Playwright)     │  ← smoke: login, notebook CRUD, cell exec
        ├───────────────────┤
        │  Integration (testcontainers) │  ← API + реальная PostgreSQL
        ├───────────────────┤
        │   Component (vitest + jsdom)  │  ← UI компоненты с моками API
        ├───────────────────┤
        │     Unit (pytest / vitest)    │  ← бизнес-логика, чистые функции
        └───────────────────┘
```

---

## 1. Unit тесты (уже есть, расширять)

### API (pytest)

**Текущее покрытие:**

| Endpoint group | Файл | Статус |
|----------------|------|--------|
| Auth | `api/tests/test_auth.py` | ✅ register, login, logout, me, refresh |
| Notebooks | `api/tests/test_notebooks.py` | ✅ CRUD, ownership |
| Analytics | `api/tests/test_analytics.py` | ✅ create event, dashboard |
| AI context | `api/tests/test_ai_context.py` | ✅ context building |
| AI endpoint | `api/tests/test_ai_endpoint.py` | ✅ generate, rate limit |
| AI validation | `api/tests/test_ai_validation.py` | ✅ JS syntax check |
| Health | `api/tests/test_health.py` | ✅ health, health/db |

**Что добавить:**

| Тест | Причина | Приоритет |
|------|---------|-----------|
| `test_auth_cookie_security` — проверка `httponly`, `samesite`, `secure` флагов | Security review #S1 | High |
| `test_auth_expired_token` — refresh с истёкшим token | Редкий edge case | Medium |
| `test_notebooks_concurrent_edit` — два PUT одновременно | Race condition | Low |
| `test_analytics_event_types` — все типы событий | Полнота | Low |

### UI (vitest)

**Текущее покрытие:**

| Модуль | Файлы | Статус |
|--------|-------|--------|
| Notebook model | `notebookSlice.test.ts`, `notebookContext.test.ts`, `selectors.test.ts` | ✅ |
| Notebook executor | `useNotebookExecutor.test.tsx`, `fakeKernel.test.ts`, `jsExecutor.worker.test.js` | ✅ |
| Notebook UI | `ErrorOutputView.test.tsx`, `StreamOutputView.test.tsx`, `ExecutionIndicator.test.tsx`, `BrowserLLMStatus.test.tsx` | ✅ |
| Notebook API | `aiService.test.ts` | ✅ |
| Auth | `authContext.test.tsx` | ✅ |
| Analytics | `analyticsService.test.ts` | ✅ |
| Shared | `apiClient.test.ts`, `Button.test.tsx`, `uuid.test.ts`, `cn.test.ts` | ✅ |
| Auto-save | `useAutoSave.test.ts` | ✅ |
| WebLLM | `useWebLLM.test.tsx` | ✅ |

**Что добавить:**

| Тест | Причина | Приоритет |
|------|---------|-----------|
| `NotebookToolbar.test.tsx` — кнопки Run, Add cell, AI | UI компонент без теста | High |
| `NotebookSidebar.test.tsx` — навигация, ссылки | UI компонент без теста | Medium |
| `AnalyticsDashboard.test.tsx` — рендеринг данных | UI компонент без теста | Medium |
| `MarkdownCellView.test.tsx` — рендеринг markdown | XSS проверка, rendering | Medium |
| `CellOutputView.test.tsx` — все типы output | UI компонент без теста | Medium |

---

## 2. Integration тесты API↔DB (новые)

### Проблема

Текущие API тесты используют моки БД (`app.dependency_overrides`). Реальные SQL-запросы, миграции и connection pooling не проверяются.

### Решение: testcontainers

```python
# api/tests/conftest.py
from testcontainers.postgres import PostgresContainer

@pytest.fixture(scope="session")
def postgres():
    with PostgresContainer("postgres:16") as pg:
        yield pg
```

| Тест | Что проверяет | Приоритет |
|------|---------------|-----------|
| `test_db_migrations_apply` — Alembic upgrade head на чистой БД | Миграции не сломаны | High |
| `test_db_notebook_crud_real` — CRUD через реальную PostgreSQL | SQL-запросы корректны | High |
| `test_db_session_rotation` — refresh token rotation с реальной БД | Транзакционность | Medium |
| `test_db_analytics_aggregation` — dashboard с реальными данными | SQL aggregation | Medium |

### Альтернатива

Если testcontainers недоступен в CI (Docker-in-Docker), использовать SQLite in-memory как fallback. Менее реалистично, но проверяет SQLAlchemy-запросы.

---

## 3. E2E тесты (новые)

### Инструмент: Playwright

```bash
npm install -D @playwright/test
npx playwright install --with-deps chromium
```

### Структура

```
ui/
├── e2e/
│   ├── playwright.config.ts
│   ├── smoke.spec.ts         # критические flow
│   └── fixtures/
│       └── auth.ts           # login helper
```

### Smoke тесты (приоритет 1)

| ID | Сценарий | Шаги | Ожидаемый результат |
|----|----------|------|---------------------|
| E2E-01 | Регистрация и login | Открыть → Register → заполнить → submit → увидеть notebook | Пользователь залогинен, notebook page виден |
| E2E-02 | Создание notebook | Login → click "New notebook" → ввести код → Run | Output виден, executionCount = 1 |
| E2E-03 | Выполнение ячейки | Notebook → ввести `console.log("hello")` → Run | stdout "hello" виден |
| E2E-04 | Ошибка выполнения | Notebook → ввести `undefined.x` → Run | Error output виден с ename |
| E2E-05 | Сохранение notebook | Создать → изменить → перезагрузить страницу | Данные сохранены |
| E2E-06 | Logout | Login → click logout → проверить cookies очищены | Redirect на login |

### Расширенные E2E (приоритет 2)

| ID | Сценарий | Приоритет |
|----|----------|-----------|
| E2E-07 | AI генерация кода | Medium |
| E2E-08 | Analytics dashboard | Medium |
| E2E-09 | Markdown ячейка | Low |
| E2E-10 | Тёмная тема toggle | Low |

### CI интеграция

```yaml
# ui/.github/workflows/ci-cd.yml — добавить job
e2e:
  needs: changes
  if: needs.changes.outputs.src == 'true'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
    - run: npm ci
    - run: npx playwright install --with-deps chromium
    - run: npx playwright test
    - uses: actions/upload-artifact@v4
      if: failure()
      with:
        name: playwright-report
        path: playwright-report/
```

---

## 4. Coverage измерение (новое)

### API: pytest-cov

```bash
pip install pytest-cov
pytest --cov=app --cov-report=term-missing --cov-report=xml
```

### UI: vitest coverage

```bash
npx vitest run --coverage
```

### CI gate (постепенное внедрение)

| Этап | Порог | Блокирует merge? |
|------|-------|------------------|
| 1. Измерение | Нет порога | Нет — только отчёт |
| 2. Отображение | Покрытие в PR comment | Нет |
| 3. Gate | < 60% → warn | Нет |
| 4. Strict gate | < 80% → block | Да (когда покрытие достигнуто) |

---

## 5. Contract тесты API↔UI (опционально)

### Проблема

API меняет схему ответа → UI ломается без предупреждения. Нет единого контракта.

### Решение: OpenAPI schema validation

1. API генерирует `openapi.json` (уже есть через FastAPI).
2. CI job экспортирует схему и сравнивает с сохранённой версией.
3. При изменении схемы — UI тесты прогоняются автоматически.

| Проверка | Инструмент | Приоритет |
|----------|-----------|-----------|
| Schema diff в PR | `openapi-diff` | Medium |
| UI types совпадают со schema | `openapi-typescript` | Low |

---

## План внедрения

### Месяц 1: Foundation

| Неделя | Задача | Эффект |
|--------|--------|--------|
| 1 | Playwright setup + E2E-01..03 (login, notebook, cell exec) | Smoke baseline |
| 2 | E2E-04..06 (error, save, logout) | Полный smoke |
| 3 | pytest-cov + vitest coverage в CI | Видимость покрытия |
| 4 | Unit тесты для UI компонентов без покрытия (Toolbar, Sidebar, Dashboard) | Покрытие UI |

### Месяц 2: Integration

| Неделя | Задача | Эффект |
|--------|--------|--------|
| 1 | testcontainers setup для API | Реальная БД в тестах |
| 2 | Integration тесты: migrations, notebook CRUD, session rotation | SQL корректность |
| 3 | E2E-07..08 (AI, analytics) | Расширенный smoke |
| 4 | Coverage gate: warn при < 60% | Ориентир для команды |

### Месяц 3: Maturity

| Неделя | Задача | Эффект |
|--------|--------|--------|
| 1 | Contract тесты: openapi-diff в CI | Schema drift detection |
| 2 | E2E-09..10 (markdown, theme) | Полное E2E покрытие |
| 3 | Coverage gate: block при < 80% | Quality gate |
| 4 | Load тесты (k6 / locust) на API | Performance baseline |

---

## Связанные документы

- [QA Plan](qa/qa-plan.md) — общая QA стратегия
- [Execution QA Plan](qa/execution-qa-plan.md) — runtime тестирование notebook
- [Definition of Done](qa/definition-of-done.md) — критерии завершения
- [Production Readiness Audit](production-readiness.md) — аудит (раздел Testing)
- [GitHub Actions](dev-ops/github-actions.md) — CI/CD пайплайны
