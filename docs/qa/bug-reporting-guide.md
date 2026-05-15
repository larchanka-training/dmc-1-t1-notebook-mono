# Bug Reporting Guide

## Purpose

A bug report is a request for repair. Its job is to give the person fixing the issue enough information to **reproduce, understand, and verify** the problem without coming back with questions. A good report saves hours of debugging and keeps the team focused on solving, not clarifying.

## Bug Report Templates

Use the appropriate GitHub Issue template when filing a bug:

- **API bugs** — [bug_api.md](../../.github/ISSUE_TEMPLATE/bug_api.md) — for backend, endpoint, and service issues.
- **UI bugs** — [bug_ui.md](../../.github/ISSUE_TEMPLATE/bug_ui.md) — for frontend, visual, and interaction issues.

## Severity Guide

- **Critical** — production is down or unsafe. Core flows are blocked for all or most users, data is lost or corrupted, security or payments are affected. Triggers immediate response and may block the release. *Example: checkout fails with 500 for every user.*
- **Major** — important functionality is broken or significantly degraded, but the system still runs and a workaround exists or only a subset of users is affected. Must be fixed before the next planned release. *Example: search returns wrong results for one product category.*
- **Minor** — cosmetic issues, small UX problems, edge cases with negligible business impact. Fixed when it fits into the schedule. *Example: tooltip text overflows by 2 pixels on Safari.*

When in doubt, raise severity rather than lower it — re-classification is cheap.

## Good Bug Report Example: API

```
Summary:
POST /api/v1/cart/apply-promo applies the discount twice, doubling the amount deducted.

Environment:
- App / module: web-checkout
- Version / build / commit: staging build 2026-05-12, commit 4f7a2b1
- Environment: staging
- Date and time observed: 2026-05-13 10:42 UTC

API Details:
- Endpoint: /api/v1/cart/apply-promo
- HTTP method: POST
- Request body: { "code": "SPRING10" }

Preconditions:
- User is logged in as qa-user-07@example.com (standard customer).
- Cart contains 2 items totaling $100.00.
- Promo code SPRING10 (10% off, single-use, active) has not been used by this account.

Steps to Reproduce:
1. Create a cart with 2 items totaling $100.00.
2. POST /api/v1/cart/apply-promo with body { "code": "SPRING10" }.
3. Observe the response and the order total via GET /api/v1/cart.

Expected Result:
Discount is $10.00, order total is $90.00, per AC3 of CHK-142.

Actual Result:
First POST returns 200 with { "discount": 10.00 }.
A second identical POST is fired 80 ms later by the frontend.
GET /api/v1/cart shows discount $20.00, total $80.00.
The API does not reject the duplicate apply request.

Severity:
Major (financial impact, workaround: remove and reapply once, but inconsistent)

Attachments:
- har-export-2026-05-13.har

Additional Notes:
- Reproduces 5/5 times on staging.
- Does not reproduce on dev (same commit — possibly env config).
- Started after PR #318 (promo code refactor) merged on 2026-05-12.
```

## Good Bug Report Example: UI

```
Summary:
On the checkout page, the promo code discount line shows double the expected amount after applying a code once.

Environment:
- App / module: web-checkout
- Version / build / commit: staging build 2026-05-12, commit 4f7a2b1
- Environment: staging
- Browser / version: Chrome 124
- OS / device: macOS 14.4
- Viewport / resolution: 1440x900
- User account / role: qa-user-07@example.com (standard customer)
- Date and time observed: 2026-05-13 10:42 UTC

Preconditions:
- User is logged in.
- Cart contains 2 items totaling $100.00.
- Promo code SPRING10 (10% off, single-use, active) has not been used by this account.

Steps to Reproduce:
1. Open /cart with the cart described above.
2. Click "Checkout".
3. In the "Promo code" field, enter SPRING10 and click "Apply".
4. Observe the order summary.

Expected Result:
Discount line shows "-$10.00" and order total is $90.00, per AC3 of CHK-142.

Actual Result:
Discount line shows "-$20.00" and order total is $80.00.
Browser console shows no errors.
Network tab: two identical POST /api/v1/cart/apply-promo requests fired 80 ms apart; the UI sums both responses.

Severity:
Major (financial impact, workaround: remove and reapply once, but inconsistent)

Attachments:
- screenshot-checkout-discount.png
- har-export-2026-05-13.har

Additional Notes:
- Reproduces 5/5 times in Chrome and Firefox on staging.
- Safari not tested.
- Started after PR #318 (promo code refactor) merged on 2026-05-12.
```

## Bad Bug Report Example

```
Summary:
Promo codes are broken.

Steps:
Tried to use a promo code and it didn't work.

Expected:
Should work.

Actual:
Doesn't work.
```

**Why it's bad:**
- No environment, no build version — impossible to know where to look.
- No specific promo code, no cart content, no user — cannot reproduce.
- "Doesn't work" gives no error, no status code, no UI state.
- No severity, no attachments, no timestamp.
- The fix path starts with a 20-minute conversation that should have been one paragraph in the report.
