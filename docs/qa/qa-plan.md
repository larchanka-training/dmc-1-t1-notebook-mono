# QA Plan

## Purpose

This QA Plan defines a lightweight, practical quality approach for our team during early-stage development. It sets shared expectations for how we plan, build, verify, and release software so that we ship predictably without slowing down. The goal is to prevent the most common defects, reduce ambiguity in requirements, and make quality a natural part of daily work — not an extra phase added at the end.

## Principles

- **Quality is a shared responsibility.** Engineers, analysts, designers, and managers all own quality, not a single QA role.
- **Prevent defects early.** Issues found during requirements or PR review are cheaper than issues found in production.
- **Requirements must be testable.** If a requirement cannot be verified, it is not ready for development.
- **Focus on critical flows first.** Cover the paths that generate revenue, hold user data, or block other features before edge cases.
- **Automate gradually.** Start with manual verification; add automation where regressions actually hurt.
- **Lightweight by default.** Every process step must earn its place. If a checklist item never catches anything, remove it.

## Environments

| Environment | Purpose | Who uses it | Data |
|---|---|---|---|
| **dev** | Local development. Used for active coding, integration of WIP features, and quick experiments. May be unstable. | Engineers | Synthetic / disposable |
| **prod** | Live environment serving real users. Only verified, approved builds are deployed here. | End users | Real |

Rules:
- No manual data changes in `prod` outside of approved procedures.
- A feature is not "done" until it has been observed working on `staging`.

## Development Workflow

1. **Requirement preparation** — the analyst captures the customer request as a short, written description with goals and constraints.
2. **Acceptance criteria definition** — clear, testable criteria are added before development starts (see `acceptance-criteria-template.md`).
3. **Development** — engineer implements the change on a feature branch.
4. **Pull request** — engineer opens a PR with a description, linked requirement, and verification notes.
5. **Manual verification** — the PR is reviewed and manually checked against acceptance criteria (see `pr-manual-check-process.md`).
6. **Merge** — PR is merged into the main branch once review and verification pass.
7. **Deploy to staging** — the change is deployed to staging automatically or on demand.
8. **Smoke verification** — critical flows are checked on staging.
9. **Production release** — the build is promoted to prod with a known rollback path.

## Quality Gates

Minimum gates the team commits to:

**Before merge**
- Acceptance criteria are documented in the PR or linked ticket.
- Code review approved by at least one other engineer.
- Manual verification against acceptance criteria completed.
- No known critical or major defects in the changed area.

**Before release to prod**
- Build deployed and observed on staging.
- Smoke checks of critical flows pass.
- Rollback approach is known (revert PR, redeploy previous build, feature flag off).

## Test Types

- **Smoke testing** — a small set of checks that confirm the system is alive and core flows work after a deploy.
- **Manual functional testing** — verifying a feature behaves according to its acceptance criteria.
- **API testing** — checking request/response contracts, status codes, and error handling for backend endpoints.
- **Regression testing** — re-checking previously working flows that could be affected by a change.
- **Exploratory testing** — unscripted investigation around new or risky areas to surface unexpected issues.
- **Negative testing** — verifying the system handles invalid input, errors, and edge conditions gracefully.

## Bug Severity Levels

- **Critical** — system is down, data is lost or corrupted, security breach, payment failure, full block of a core user flow. *Example: users cannot log in; checkout fails for all users.* Must be fixed immediately, may block release.
- **Major** — important functionality is broken or significantly degraded, but a workaround exists or only part of users is affected. *Example: search returns wrong results in some categories; export works but is slow.* Should be fixed before the next release.
- **Minor** — cosmetic or low-impact issue, edge case, small UX inconsistency. *Example: misaligned button, typo, tooltip flicker.* Fixed when convenient.

## Risks

- **Missing or vague requirements** — features get built without clarity, causing rework.
- **Regressions** — changes silently break previously working areas due to limited test coverage.
- **No test automation yet** — every release depends on manual checks; risk grows with scope.
- **Unstable environments** — broken staging blocks verification and slows delivery.
- **Incomplete edge-case coverage** — negative paths and uncommon inputs are easy to miss.
- **Single points of knowledge** — only one person understands a critical area.

We accept these risks consciously and mitigate them incrementally rather than building heavy processes up front.

## Future Improvements

As the team and product grow, we plan to add (in roughly this order):

1. **Automation foundation** — unit tests for core logic and a basic test runner in CI.
2. **CI validation** — lint, build, and test on every PR; block merges on failure.
3. **API test suites** — automated checks for critical endpoints and contracts.
4. **E2E testing** — a small set of automated end-to-end checks for the most important user flows.
5. **Release checklists** — formalized pre-release verification per area as the product surface grows.
6. **Bug tracking metrics** — basic visibility into defect trends and time-to-fix.

Each step should be introduced only when its absence becomes painful — not preemptively.
