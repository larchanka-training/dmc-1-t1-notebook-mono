# Acceptance Criteria Template

## Purpose

Acceptance Criteria (AC) describe **what must be true for a feature to be considered correctly implemented**. They turn a customer request into something the team can build, verify, and agree on. Good AC reduce ambiguity, prevent rework, and act as the source of truth for both development and manual verification.

AC are written **before** development starts and reviewed by the engineer who will implement the work.

## Rules

Every acceptance criterion must be:

- **Clear** — written in plain language, no hidden assumptions.
- **Testable** — it can be verified by a human or automated check with a yes/no answer.
- **Measurable** — concrete values, states, or outcomes instead of subjective words ("fast", "nice", "good").
- **Unambiguous** — only one reasonable interpretation.
- **Focused on observable behavior** — describes *what* the system does, not *how* it is implemented.
- **Scoped** — covers one feature or change; large stories are split.

## Template

```
Feature: <short name>
Context: <why this is needed, 1–2 sentences>

Acceptance Criteria:

AC1. Given <precondition>, when <action>, then <expected observable result>.
AC2. Given <precondition>, when <action>, then <expected observable result>.
AC3. ...

Out of scope:
- <what this feature explicitly does NOT cover>

Non-functional notes (optional):
- Performance, security, accessibility, logging expectations if relevant.
```

The Given/When/Then format is recommended but not mandatory — bullet lists are fine if they remain testable.

## Good Examples

### 1. API endpoint

**Feature:** `GET /api/v1/orders/{id}`

- AC1. Given a valid order ID owned by the authenticated user, when the endpoint is called, then the response is `200 OK` with the order payload (id, status, items, total, createdAt).
- AC2. Given an order ID that does not exist, then the response is `404 Not Found` with body `{ "error": "order_not_found" }`.
- AC3. Given an order ID owned by another user, then the response is `403 Forbidden`.
- AC4. Given a missing or invalid auth token, then the response is `401 Unauthorized`.
- AC5. Response time under normal load is below 500 ms (p95).

### 2. UI form (sign-up)

**Feature:** Sign-up form

- AC1. The form contains fields: email, password, confirm password, and a "Create account" button.
- AC2. The "Create account" button is disabled until all fields are filled and password matches confirmation.
- AC3. On submit with valid data, the user is redirected to `/onboarding` and a session cookie is set.
- AC4. On submit with an already-registered email, an inline error "Email is already in use" is displayed and no request is repeated.
- AC5. Password field shows validation: minimum 8 characters, at least one number; errors are shown on blur.

### 3. Authentication

**Feature:** Login with email + password

- AC1. Given correct credentials, the user is logged in and redirected to the last visited page or `/dashboard` by default.
- AC2. Given incorrect credentials, the user sees "Invalid email or password" without revealing which field is wrong.
- AC3. After 5 failed attempts within 10 minutes from the same IP, further attempts return `429 Too Many Requests` for 15 minutes.
- AC4. Session token expires after 24 hours of inactivity.
- AC5. Logging in from a new device triggers a notification email to the account owner.

### 4. Validation

**Feature:** Phone number input

- AC1. The field accepts only digits, spaces, `+`, `-`, and parentheses.
- AC2. On blur, the value is normalized to E.164 format (e.g. `+14155552671`).
- AC3. If normalization fails, the field shows "Enter a valid phone number" and the form cannot be submitted.
- AC4. The field is required; submitting without a value shows "Phone number is required".
- AC5. The maximum stored length is 16 characters; longer input is rejected client- and server-side.

### 5. Async processing

**Feature:** CSV import of contacts

- AC1. When the user uploads a CSV up to 10 MB, the request returns `202 Accepted` with a `jobId` within 1 second.
- AC2. The UI shows an "Import in progress" status and polls job status every 5 seconds.
- AC3. On success, the user sees a summary: total rows, imported, skipped, failed (with reasons).
- AC4. Failed rows are downloadable as a CSV with the original data plus an `error` column.
- AC5. If the job fails entirely (e.g. malformed file), the status becomes `failed` and an error message is shown; no partial data is persisted.

## Bad Examples

1. **"The login page should work correctly."**
   *Why it's bad:* "Work correctly" is undefined. No way to test pass/fail.

2. **"The API should be fast."**
   *Why it's bad:* "Fast" is subjective. No measurable threshold (e.g. p95 < 500 ms).

3. **"Use Redis to cache the user profile for 10 minutes."**
   *Why it's bad:* Describes implementation, not behavior. AC should say *what* the user observes (e.g. "profile updates appear within 10 minutes"), not which technology is used.

4. **"Handle all edge cases."**
   *Why it's bad:* Unbounded scope. No one can confirm completion. Edge cases must be enumerated.

5. **"The form should look nice and be user-friendly."**
   *Why it's bad:* Subjective, untestable. Replace with specific, observable rules (field order, validation messages, disabled states).
