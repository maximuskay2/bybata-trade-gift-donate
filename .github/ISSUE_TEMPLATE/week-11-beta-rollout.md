---
name: Week 11 — Beta Rollout (Staging → Production)
about: Promote services, finalize data, pilot users, and triage
title: "Week 11: Beta Rollout"
labels: ["epic","week-11"]
assignees: []
---

Goals
- Promote to production; onboard pilot users; collect feedback.

Tasks
- Data/Infra
  - [ ] Final migrations; seed achievements, conversion rates, promotions.
  - [ ] Configure domains, TLS, CORS; lock Swagger to non-prod.
- Deploy
  - [ ] Promote API/Admin; environment variables verified.
- UX Polish
  - [ ] Empty states, loading, error messaging; app icons/splash.
- Analytics
  - [ ] Sentry releases and dashboards; basic event tracking (if enabled).

Deliverables
- Production services running; pilot users invited.

Acceptance criteria
- [ ] No critical errors in logs within 48h; SLOs met.
- [ ] Pilot user feedback collected; P0/P1 issues tracked.
