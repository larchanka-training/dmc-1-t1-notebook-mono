# Authentication

## Overview

The API uses **JWT-based authentication delivered via HttpOnly cookies**. There is no `Authorization: Bearer` header — all tokens live in cookies, making them inaccessible to JavaScript and resistant to XSS.

Two tokens are issued on every login or register:

| Cookie | TTL | Purpose |
|---|---|---|
| `access_token` | 15 min | Authenticate API requests via `GET /me`, etc. |
| `refresh_token` | 7 days | Obtain a new `access_token` without re-logging in |

---

## Cookie configuration

All auth cookies are set with:

```
HttpOnly: true        — not readable by JS
Secure:   true        — HTTPS only (always enabled; local dev uses HTTPS via the proxy)
SameSite: Lax         — sent on same-site + top-level cross-site GETs
Domain:   .notebook.com
```

`COOKIE_DOMAIN` can be overridden via environment variable.

---

## Endpoints

### `POST /api/v1/auth/register`

Create a new account. Sets both cookies on success.

**Request body**
```json
{
  "email": "user@example.com",
  "password": "atleast8chars",
  "display_name": "Alice"
}
```

Validation rules:
- `password` — minimum 8 characters
- `display_name` — optional; defaults to the email address if omitted

**Response `201`**
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "display_name": "Alice",
  "created_at": "2026-06-01T00:00:00Z"
}
```

Errors: `409 Conflict` if email is already registered.

---

### `POST /api/v1/auth/login`

Authenticate with email + password. Sets both cookies on success.

**Request body**
```json
{ "email": "user@example.com", "password": "atleast8chars" }
```

**Response `200`** — same shape as register.

Errors: `401 Unauthorized` for invalid credentials (generic message, no user enumeration).

---

### `POST /api/v1/auth/logout`

Deletes the server-side session row for the current refresh token and clears both cookies.

- No body required.
- Idempotent: safe to call even if no session exists.
- **Response `204 No Content`**

---

### `GET /api/v1/auth/me`

Returns the currently authenticated user. Reads the `access_token` cookie.

**Response `200`** — same `UserResponse` shape.

Errors: `401 Unauthorized` if cookie is missing, invalid, or expired.

---

### `POST /api/v1/auth/refresh`

Issues a new `access_token` (and rotates the `refresh_token`) using the `refresh_token` cookie.

- The old refresh token is deleted from the database (rotation prevents replay).
- Both cookies are updated in the response.
- **Response `200`** — same `UserResponse` shape.

Errors: `401 Unauthorized` if the refresh token is missing, expired, or already used.

---

## Token flow

```
Browser                          API
  │                               │
  │── POST /auth/login ──────────►│
  │                               │  verify password
  │                               │  create access_token  (JWT, 15min)
  │                               │  create refresh_token (opaque, 7d)
  │                               │  store SHA-256(refresh_token) in sessions table
  │◄─ Set-Cookie: access_token ───│
  │◄─ Set-Cookie: refresh_token ──│
  │                               │
  │── GET /auth/me ──────────────►│  reads access_token cookie
  │◄─ 200 UserResponse ───────────│
  │                               │
  │  [15 min later, access expires]
  │                               │
  │── POST /auth/refresh ────────►│  reads refresh_token cookie
  │                               │  validates SHA-256(token) against sessions row
  │                               │  deletes old session row (rotation)
  │                               │  creates new session row
  │◄─ Set-Cookie: access_token ───│  new 15-min access token
  │◄─ Set-Cookie: refresh_token ──│  new 7-day refresh token
  │                               │
  │── POST /auth/logout ─────────►│  reads refresh_token cookie
  │                               │  deletes session row
  │◄─ 204 + cleared cookies ──────│
```

---

## Refresh token storage

Refresh tokens are **opaque random strings** (48-byte URL-safe base64). The raw value is sent in the cookie; the API stores only `SHA-256(raw)` in the `sessions` table. This means a database breach does not expose usable tokens.

| Column | Notes |
|---|---|
| `id` | UUID PK |
| `user_id` | FK → users.id (CASCADE DELETE) |
| `token_hash` | SHA-256 hex, 64 chars, unique index |
| `expires_at` | UTC timestamp |
| `created_at` | auto |

---

## User model

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK, default uuid4 |
| `email` | varchar(255) | unique, indexed |
| `password_hash` | varchar(255) | bcrypt |
| `display_name` | varchar(255) | nullable; falls back to email in responses |
| `created_at` | timestamptz | server default now() |

Passwords are hashed with **bcrypt** (the `bcrypt` package directly — passlib is not used due to a compatibility issue between passlib 1.7 and bcrypt 4.x). The plain-text password is never stored or logged.

---

## Configuration

| Variable | Default | Description |
|---|---|---|
| `JWT_SECRET` | *(weak dev default)* | **Must be overridden in production.** Used to sign access tokens. |
| `JWT_ALGORITHM` | `HS256` | JWT signing algorithm |
| `ACCESS_TOKEN_TTL_SECONDS` | `900` | 15 minutes |
| `SESSION_TTL_SECONDS` | `604800` | 7 days (refresh token lifetime) |
| `COOKIE_DOMAIN` | `.notebook.com` | Override for non-standard domain setups |

---

## Frontend auth integration

Auth state is managed by `AuthProvider` (`ui/src/features/auth/model/authContext.tsx`), which wraps the entire app. It exposes a `useAuth()` hook returning:

```ts
{
  status: "loading" | "authenticated" | "unauthenticated";
  user: User | null;
  login(email, password): Promise<void>;
  register(email, password, displayName?): Promise<void>;
  logout(): Promise<void>;
}
```

**Session restore on load** — on mount, `AuthProvider` calls `GET /auth/me`. If the cookie is still valid the user is silently restored; if not, `status` becomes `unauthenticated`. An `AbortController` is used so that React 18 StrictMode's double-mount only results in one completed request.

**UI states driven by `status`:**

| `status` | What the user sees |
|---|---|
| `"loading"` | Full-screen spinner while the `/me` check is in flight |
| `"unauthenticated"` | Sidebar with no notebooks + centred placeholder with "Sign in / Sign up" button |
| `"authenticated"` | Full notebook experience; notebooks load and navigate to the most recent one |

**Automatic token refresh** — `apiClient` intercepts every `401` response and attempts a silent refresh before surfacing the error to the caller:

1. The failing request gets a `401`.
2. `apiClient` calls `POST /auth/refresh` (at most once at a time — concurrent 401s share a single in-flight refresh via a module-level promise).
3. If refresh succeeds the original request is retried transparently.
4. If refresh fails (refresh token expired or revoked), a `auth:session-expired` DOM event is dispatched and `AuthProvider` transitions to `unauthenticated`, returning the user to the sign-in screen.

Endpoints that never trigger a refresh retry: `/auth/login`, `/auth/register`, `/auth/logout` — a `401` from those means wrong credentials, not an expired token.

---

## Database migrations

Run migrations with Alembic from the `api/` directory:

```bash
# Apply all pending migrations
alembic upgrade head

# Roll back one step
alembic downgrade -1

# Auto-generate a new migration after model changes
alembic revision --autogenerate -m "describe the change"
```

The first migration (`0001`) creates the `users` and `sessions` tables.
