# Аналитика использования (Usage Analytics)

## Обзор

Система сбора и отображения событий аналитики — отслеживает ключевые действия пользователей
в notebook-платформе: создание блокнотов, выполнение ячеек, AI-запросы, ошибки выполнения.

## Архитектура

```
UI (React)                              API (FastAPI)                    PostgreSQL
  │                                        │                               │
  │── trackEvent(type, metadata) ─────────►│  POST /analytics/events       │
  │                                        │  → INSERT INTO analytics_events│
  │                                        │                               │
  │── getDashboard() ─────────────────────►│  GET /analytics/dashboard     │
  │◄─ { totalEvents, byType, recent } ─────│  → SELECT агрегации            │
```

---

## Backend

### Модель `AnalyticsEvent`

| Колонка | Тип | Описание |
|---|---|---|
| `id` | UUID | PK, default uuid4 |
| `user_id` | UUID | FK → users.id, NOT NULL |
| `event_type` | varchar(100) | Тип события (см. ниже) |
| `event_metadata` | JSONB | Дополнительные данные события |
| `created_at` | timestamptz | server default now() |

Файл: `api/app/db/models/analytics_event.py`

### Endpoints

| Endpoint | Метод | Описание |
|---|---|---|
| `/api/v1/analytics/events` | POST | Создание события аналитики |
| `/api/v1/analytics/dashboard` | GET | Агрегированные данные для дашборда |

Файл: `api/app/api/v1/endpoints/analytics.py`

### Pydantic схемы

- `AnalyticsEventCreate` — входная схема для создания события
- `AnalyticsEventResponse` — ответ с полным событием
- `DashboardResponse` — агрегированные данные (totalEvents, byType, recent)
- `EventCountItem` — элемент агрегации (eventType, count)

Файл: `api/app/schemas/analytics.py`

### Миграция

`0003_create_analytics_events` — создаёт таблицу `analytics_events` с индексами на `user_id` и `created_at`.

---

## Frontend

### Analytics Service

`ui/src/features/analytics/api/analyticsService.ts`:
- `trackEvent(eventType, metadata?)` — POST запрос для записи события
- `getDashboard()` — GET запрос для получения данных дашборда

### useAnalytics Hook

`ui/src/features/analytics/model/useAnalytics.ts`:
- Хук, вызывающий `getDashboard()` при монтировании
- Тихая обработка ошибок (аналитика не должна ломать UI)

### AnalyticsDashboard

`ui/src/features/analytics/ui/AnalyticsDashboard.tsx`:
- Карточки со сводной статистикой (total events, по типам)
- Диаграмма распределения событий
- Таблица недавних событий
- Маршрут `/analytics`, ссылка в sidebar

---

## Типы событий

| event_type | Когда срабатывает | metadata |
|---|---|---|
| `notebook_created` | Создание нового блокнота | `{ notebook_id }` |
| `cell_executed` | Выполнение code-ячейки | `{ cell_id, execution_count, duration_ms }` |
| `ai_request` | Запрос AI-генерации кода | `{ prompt_length, success }` |
| `execution_error` | Ошибка при выполнении ячейки | `{ cell_id, error_type, error_message }` |

---

## Тестирование

### Backend (pytest)
- Тесты endpoints: создание события, получение дашборда
- Тесты валидации Pydantic схем

### Frontend (Vitest)
- Unit-тесты `analyticsService` (мок fetch)
- Тесты `useAnalytics` хука (мок service)
