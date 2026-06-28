# Аутентификация

## Обзор

API использует **JWT-аутентификацию через HttpOnly cookies**. Заголовок `Authorization: Bearer` не используется — все токены хранятся в cookies, что делает их недоступными для JavaScript и устойчивыми к XSS.

При каждом входе или регистрации выдаются два токена:

| Cookie | TTL | Назначение |
|---|---|---|
| `access_token` | 15 мин | Аутентификация API-запросов (`GET /me`, и т.д.) |
| `refresh_token` | 7 дней | Получение нового `access_token` без повторного входа |

---

## Конфигурация cookies

Все auth-cookies устанавливаются с:

```
HttpOnly: true     — недоступен для JS
Secure:   <env>    — см. SECURE_COOKIES ниже
SameSite: Lax      — отправляется на same-site + top-level cross-site GET
Domain:   <env>    — см. COOKIE_DOMAIN ниже
```

---

## Endpoints

### `POST /api/v1/auth/register`

Создание нового аккаунта. Устанавливает оба cookie при успехе.

**Тело запроса**
```json
{
  "email": "user@example.com",
  "password": "atleast8chars",
  "display_name": "Alice"
}
```

Правила валидации:
- `password` — минимум 8 символов
- `display_name` — опционально; по умолчанию используется email

**Ответ `201`**
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "display_name": "Alice",
  "created_at": "2026-06-01T00:00:00Z"
}
```

Ошибки: `409 Conflict` если email уже зарегистрирован.

---

### `POST /api/v1/auth/login`

Аутентификация по email + пароль. Устанавливает оба cookie при успехе.

**Тело запроса**
```json
{ "email": "user@example.com", "password": "atleast8chars" }
```

**Ответ `200`** — та же структура, что при регистрации.

Ошибки: `401 Unauthorized` при неверных учётных данных (общее сообщение, без раскрытия существования пользователя).

---

### `POST /api/v1/auth/logout`

Удаляет серверную запись сессии для текущего refresh token и очищает оба cookie.

- Тело не требуется.
- Идемпотентный: безопасно вызывать даже без активной сессии.
- **Ответ `204 No Content`**

---

### `GET /api/v1/auth/me`

Возвращает текущего аутентифицированного пользователя. Читает cookie `access_token`.

**Ответ `200`** — та же структура `UserResponse`.

Ошибки: `401 Unauthorized` если cookie отсутствует, невалиден или истёк.

---

### `POST /api/v1/auth/refresh`

Выдаёт новый `access_token` (и ротирует `refresh_token`) используя cookie `refresh_token`.

- Старый refresh token удаляется из БД (ротация предотвращает повторное использование).
- Оба cookie обновляются в ответе.
- **Ответ `200`** — та же структура `UserResponse`.

Ошибки: `401 Unauthorized` если refresh token отсутствует, истёк или уже использован.

---

## Поток токенов

```
Браузер                          API
  │                               │
  │── POST /auth/login ──────────►│
  │                               │  проверка пароля
  │                               │  создание access_token  (JWT, 15мин)
  │                               │  создание refresh_token (opaque, 7д)
  │                               │  сохранение SHA-256(refresh_token) в sessions
  │◄─ Set-Cookie: access_token ───│
  │◄─ Set-Cookie: refresh_token ──│
  │                               │
  │── GET /auth/me ──────────────►│  читает cookie access_token
  │◄─ 200 UserResponse ───────────│
  │                               │
  │  [через 15 мин access истекает]
  │                               │
  │── POST /auth/refresh ────────►│  читает cookie refresh_token
  │                               │  проверка SHA-256(token) по sessions
  │                               │  удаление старой записи (ротация)
  │                               │  создание новой записи
  │◄─ Set-Cookie: access_token ───│  новый access на 15 мин
  │◄─ Set-Cookie: refresh_token ──│  новый refresh на 7 дней
  │                               │
  │── POST /auth/logout ─────────►│  читает cookie refresh_token
  │                               │  удаляет запись сессии
  │◄─ 204 + очищенные cookies ────│
```

---

## Хранение refresh token

Refresh tokens — **непрозрачные случайные строки** (48 байт, URL-safe base64). Сырое значение отправляется в cookie; API хранит только `SHA-256(сырое)` в таблице `sessions`. Это означает, что утечка БД не раскрывает пригодные к использованию токены.

| Колонка | Описание |
|---|---|
| `id` | UUID PK |
| `user_id` | FK → users.id (CASCADE DELETE) |
| `token_hash` | SHA-256 hex, 64 символа, unique index |
| `expires_at` | UTC timestamp |
| `created_at` | авто |

---

## Модель пользователя

| Колонка | Тип | Описание |
|---|---|---|
| `id` | UUID | PK, default uuid4 |
| `email` | varchar(255) | unique, indexed |
| `password_hash` | varchar(255) | bcrypt |
| `display_name` | varchar(255) | nullable; fallback на email в ответах |
| `created_at` | timestamptz | server default now() |

Пароли хешируются с помощью **bcrypt** (пакет `bcrypt` напрямую — passlib не используется из-за несовместимости passlib 1.7 и bcrypt 4.x). Открытый пароль никогда не сохраняется и не логируется.

---

## Конфигурация

| Переменная | По умолчанию | Описание |
|---|---|---|
| `JWT_SECRET` | *(слабый dev-default)* | **Должен быть переопределён в production.** Используется для подписи access tokens. |
| `JWT_ALGORITHM` | `HS256` | Алгоритм подписи JWT |
| `ACCESS_TOKEN_TTL_SECONDS` | `900` | 15 минут |
| `SESSION_TTL_SECONDS` | `604800` | 7 дней (срок жизни refresh token) |
| `COOKIE_DOMAIN` | `""` (пусто) | Атрибут `Domain` cookie. Пустая строка = cookie привязан к текущему хосту. |
| `SECURE_COOKIES` | `false` | `true` когда приложение обслуживается по HTTPS. |

### COOKIE_DOMAIN для локальной разработки

- **Docker Compose (через proxy):** `COOKIE_DOMAIN=.notebook.com` — cookie доступны на всех поддоменах `notebook.com`.
- **Без Docker (uvicorn + vite dev напрямую):** `COOKIE_DOMAIN=` (пустая строка) — cookie привязан к `localhost`. Если установить `.notebook.com`, браузер **не примет** cookie, т.к. домен запроса не совпадает.

---

## Интеграция аутентификации на фронтенде

Состояние аутентификации управляется `AuthProvider` (`ui/src/features/auth/model/authContext.tsx`), который оборачивает всё приложение. Он предоставляет хук `useAuth()`:

```ts
{
  status: "loading" | "authenticated" | "unauthenticated";
  user: User | null;
  login(email, password): Promise<void>;
  register(email, password, displayName?): Promise<void>;
  logout(): Promise<void>;
}
```

**Восстановление сессии при загрузке** — при монтировании `AuthProvider` вызывает `GET /auth/me`. Если cookie валиден, пользователь тихо восстанавливается; если нет — `status` становится `unauthenticated`. Используется `AbortController`, чтобы двойной монтирование в React 18 StrictMode не приводило к дублированию запросов.

**UI-состояния в зависимости от `status`:**

| `status` | Что видит пользователь |
|---|---|
| `"loading"` | Полноэкранный спиннер во время проверки `/me` |
| `"unauthenticated"` | Sidebar без блокнотов + центрированный placeholder с кнопкой "Sign in / Sign up" |
| `"authenticated"` | Полноценный notebook-интерфейс; блокноты загружаются, навигация к последнему |

**Автоматическое обновление токена** — `apiClient` перехватывает каждый ответ `401` и пытается тихо обновить токен перед тем, как показать ошибку вызывающему:

1. Запрос получает `401`.
2. `apiClient` вызывает `POST /auth/refresh` (максимум один за раз — параллельные 401 разделяют один in-flight refresh через module-level promise).
3. Если refresh успешен, исходный запрос повторяется прозрачно.
4. Если refresh не удался (refresh token истёк или отозван), диспатчится DOM-событие `auth:session-expired` и `AuthProvider` переходит в `unauthenticated`.

Endpoints, которые никогда не запускают retry refresh: `/auth/login`, `/auth/register`, `/auth/logout` — `401` от них означает неверные учётные данные, а не истёкший токен.

---

## Миграции базы данных

Запуск миграций через Alembic из директории `api/`:

```bash
# Применить все ожидающие миграции
alembic upgrade head

# Откатить одну миграцию
alembic downgrade -1

# Авто-генерация новой миграции после изменения моделей
alembic revision --autogenerate -m "описание изменения"
```

Первая миграция (`0001`) создаёт таблицы `users` и `sessions`. Миграция `0003` добавляет `analytics_events`.
