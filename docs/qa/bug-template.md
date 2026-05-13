# Bug Report Template

## Purpose

A bug report is a request for repair. Its job is to give the person fixing the issue enough information to **reproduce, understand, and verify** the problem without coming back with questions. A good report saves hours of debugging and keeps the team focused on solving, not clarifying.

This template defines the minimum structure every bug report should follow.

## Bug Template

```
Summary:
<One sentence describing the problem. What is broken, where, and the impact.>

Environment:
- App / module:
- Version / build / commit:
- Environment: dev | staging | prod
- Browser / OS / device (if relevant):
- User account / role (if relevant):
- Date and time observed:

Preconditions:
<State the system must be in before reproduction. E.g. "logged in as a paid user with at least one active subscription".>

Steps to Reproduce:
1.
2.
3.
...

Expected Result:
<What should have happened, ideally referencing the acceptance criterion or documented behavior.>

Actual Result:
<What actually happened. Include exact error messages, HTTP status codes, or visible UI state.>

Severity:
Critical | Major | Minor

Attachments:
- Screenshot / video
- Logs / network trace
- Request and response payloads (with secrets removed)

Additional Notes:
<Frequency (always / intermittent), suspected cause, recent related changes, workarounds, related tickets.>
```

## Severity Guide

- **Critical** — production is down or unsafe. Core flows are blocked for all or most users, data is lost or corrupted, security or payments are affected. Triggers immediate response and may block the release. *Example: checkout fails with 500 for every user.*
- **Major** — important functionality is broken or significantly degraded, but the system still runs and a workaround exists or only a subset of users is affected. Must be fixed before the next planned release. *Example: search returns wrong results for one product category.*
- **Minor** — cosmetic issues, small UX problems, edge cases with negligible business impact. Fixed when it fits into the schedule. *Example: tooltip text overflows by 2 pixels on Safari.*

When in doubt, raise severity rather than lower it — re-classification is cheap.

## Good Bug Report Example

```
Summary:
On staging, applying a promo code at checkout doubles the order discount instead of applying it once.

Environment:
- App / module: web-checkout
- Version / build / commit: staging build 2026-05-12, commit 4f7a2b1
- Environment: staging
- Browser / OS: Chrome 124, macOS 14.4
- User account: qa-user-07@example.com (standard customer)
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
Network tab: POST /api/v1/cart/apply-promo returns 200 with { "discount": 10.00 },
but a second identical POST is fired 80 ms later and the UI sums both responses.

Severity:
Major (financial impact, workaround: remove and reapply once, but inconsistent)

Attachments:
- screenshot-checkout-discount.png
- har-export-2026-05-13.har

Additional Notes:
- Reproduces 5/5 times in Chrome and Firefox on staging.
- Does not reproduce on dev (commit 4f7a2b1 deployed there too — possibly env config).
- Started after PR #318 (promo code refactor) was merged on 2026-05-12.
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
