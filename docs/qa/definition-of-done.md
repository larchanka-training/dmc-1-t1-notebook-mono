# Definition of Done

## Purpose

The Definition of Done (DoD) is a shared checklist that tells the team when a piece of work can be considered complete. It prevents half-finished features from leaking into the main branch or to production, makes handoffs predictable, and gives everyone the same finish line.

DoD is intentionally short. It is the **minimum bar**, not a wish list.

## Minimum Requirements Before Merge

A pull request can be merged when all of the following are true:

- [ ] **Code completed** — the change implements the agreed scope; no commented-out blocks, no leftover debug code.
- [ ] **Acceptance criteria implemented** — every AC from the linked requirement is covered by the change.
- [ ] **PR created** with a clear title, description, link to the requirement/ticket, and verification notes (what was checked, how, screenshots if UI).
- [ ] **Code reviewed** — at least one other engineer has reviewed and approved the PR.
- [ ] **No critical defects** known in the changed area.
- [ ] **Manual verification completed** against acceptance criteria on `dev` or a PR preview (see `pr-manual-check-process.md`).
- [ ] **No obvious regressions** — directly adjacent flows still work; logs/console show no new errors.
- [ ] **Configuration and migrations** included in the PR where needed, and reversible where possible.

## Minimum Requirements Before Release

A change can be released to production when all of the following are true:

- [ ] **Deployed to staging** with the same configuration shape as production.
- [ ] **Smoke testing completed** on staging — core flows (login, main navigation, key feature paths) work.
- [ ] **Critical flows verified** — the specific business flows touched or adjacent to the change have been exercised end-to-end.
- [ ] **Rollback approach available** — the team knows how to revert: revert the PR, redeploy a prior build, toggle a feature flag, or run a documented rollback step.
- [ ] **Stakeholder sign-off** when the change is customer-facing or contractually scoped.

## Notes

- **DoD may evolve.** As the product and team grow, items will be added (e.g. automated tests, CI green, performance budgets). Changes to DoD are agreed by the whole team.
- **Quality ownership is shared.** "It compiled" is not done. "Someone else will test it" is not done. The engineer who opens the PR owns it until it is verified and merged.
- **Speed should not compromise critical quality.** Skipping DoD items to ship faster is allowed only as a conscious, written decision (e.g. hotfix), with a follow-up to close the gap immediately after.
