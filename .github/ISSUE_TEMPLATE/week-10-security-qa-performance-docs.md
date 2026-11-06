---
name: Week 10 — Security, QA, Performance, Docs
about: Hardening pass across auth, RBAC, validation, testing, load, and documentation
title: "Week 10: Security, QA, Performance, Docs"
labels: ["epic","week-10"]
assignees: []
---

Goals
- Harden security and quality; prepare documentation for launch.

Tasks
- Security
  - [ ] RBAC review; admin-only endpoints locked; audit logs.
  - [ ] Rate limiting and validation pipes; security headers.
  - [ ] CORS tightened to prod origins.
- QA
  - [ ] API e2e tests for critical flows (auth, wallet send, trade create).
  - [ ] Mobile widget/integration tests for key screens.
  - [ ] Admin route guard tests and forms validation.
- Performance
  - [ ] DB indexes on FKs and frequent filters; load test with k6/artillery.
- Docs
  - [ ] Runbook, deployment steps, API docs (OpenAPI), Admin guide, Mobile integration guide.

Deliverables
- Signed-off test results and docs bundle.

Acceptance criteria
- [ ] No unauth/unauthorized access in test suite.
- [ ] p95 latency targets met on critical endpoints.
- [ ] Docs cover install, config, deploy, troubleshoot.
