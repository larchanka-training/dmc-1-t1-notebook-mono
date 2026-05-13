# PR Manual Check Process

## Purpose

This document describes how we manually verify pull requests before merge. It complements code review by confirming that the change actually behaves as expected from the user's or API consumer's point of view. The process is intentionally lightweight and focused on catching the issues code review cannot easily see.

## Goals

Code review catches structural and logical issues in the code. Manual verification catches:

- Behavior that compiles but does not match the acceptance criteria.
- UI regressions, broken states, and visual issues.
- Integration problems between layers (frontend ↔ backend ↔ data).
- Configuration or environment issues that only appear at runtime.
- Unexpected side effects on adjacent flows.

Both are needed. Manual verification is the last cheap chance to catch a defect before it reaches `main`.

## Verification Checklist

The reviewer (or the author, when self-verifying) runs through the relevant items below. Not every item applies to every PR — skip what is clearly not relevant and note why in the PR.

- [ ] **Acceptance criteria coverage** — every AC from the linked requirement has been exercised and passes.
- [ ] **Happy path** — the main intended flow works end-to-end with realistic input.
- [ ] **Negative scenarios** — invalid input, missing data, unauthorized access, and error states behave as expected (proper messages, correct status codes, no crashes).
- [ ] **Obvious regressions** — directly adjacent flows still work (e.g. if changing the cart, also open the orders list and checkout once).
- [ ] **UI issues** — layout holds on common viewport sizes, no overlapping elements, no console errors, loading and empty states are reasonable.
- [ ] **API contract changes** — request/response shape, status codes, and error formats match the AC and existing conventions; backward compatibility is preserved unless a breaking change is intentional and documented.
- [ ] **Logs and errors** — no new unexpected errors, warnings, or stack traces in browser console, server logs, or network tab during the verified flows.
- [ ] **Configuration changes** — new env vars, feature flags, or migrations are documented in the PR, applied in dev/staging where needed, and reversible.

The author should leave a short verification note in the PR: what was checked, on which environment, and any screenshots or recordings for UI changes.

## Verification Result Rules

Every manual check ends with one of three outcomes:

- **Approved** — all relevant checklist items pass. The PR can be merged once code review is also approved.
- **Approved with comments** — the change works, but there are non-blocking observations (minor UI polish, small refactor suggestions, follow-up ideas). Merge is allowed; comments are addressed either in the same PR or tracked as separate tickets.
- **Rejected** — at least one critical or major defect is found, an acceptance criterion is not met, or the change breaks an adjacent flow. The PR is not merged until the issues are fixed and re-verified.

Reasons for the outcome are written in the PR conversation so the author has a clear next step.

## When Verification Is Required

Manual verification is **always** required for:

- **New features** — anything that introduces user-visible behavior.
- **Critical fixes** — bug fixes in production-affecting areas, hotfixes.
- **Payment, auth, and security logic** — including session handling, permissions, billing, and data access rules.
- **UI changes** — any change that alters what users see or interact with.
- **API changes** — new endpoints, changed contracts, new error codes, changed authentication or rate-limiting behavior.

Manual verification is **optional but encouraged** for:

- Internal refactors with no behavior change (still smoke-check at least one related flow).
- Documentation-only changes.
- Build, tooling, or dependency updates (verify the app still starts and core flows still work).

## Notes

- The process must stay lightweight. If a checklist item never catches anything for a given type of change, skip it for that type and revisit the list later.
- Avoid blocking development unnecessarily — a check that takes longer than the change itself is a signal that scope, automation, or environment quality needs attention.
- Prioritize critical business flows over exhaustive coverage. It is better to verify the top three flows well than ten flows superficially.
- Verification is a team behavior, not a role. Anyone with enough context (author, peer engineer, analyst) can perform it; the important part is that it actually happens before merge.
