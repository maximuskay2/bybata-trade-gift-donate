---
name: Week 0 — Kickoff, Infra, Scaffolding
about: Planning, infra setup, CI/CD, and scaffolding for API/Admin/Mobile
title: "Week 0: Kickoff, Infra, Scaffolding"
labels: ["epic","week-0"]
assignees: []
---

Goals
- Align scope, success metrics, and architecture.
- Stand up Railway services (Postgres, API service, Buckets, optional Redis).
- Scaffold repos (api/admin; mobile exists) and CI pipelines.

Scope
- Infra/CI, API skeleton (auth/users/storage modules), Admin skeleton, Mobile API client baseline.

Tasks
- Infra/CI
  - [ ] Railway: Create project, Postgres, Buckets, (Redis optional), domains.
  - [ ] Secrets/envs draft: DATABASE_URL, JWT_* secrets, STORAGE_*, CORS_ORIGINS, SENTRY_DSN.
  - [ ] GitHub Actions templates for api/admin (lint/test/build/migrate/deploy).
  - [ ] Sentry org/projects for mobile/web/api.
- API
  - [ ] NestJS scaffold with modules: auth, users, storage.
  - [ ] Prisma init; base schema with User/Profile/Session.
  - [ ] /health endpoint; pino logging.
- Admin
  - [ ] Next.js App Router scaffold + Tailwind; health/status page calling API /health.
- Mobile
  - [ ] Add dio + flutter_secure_storage; base API URL config; request /health.

Deliverables
- API boots locally and on Railway; /health OK.
- Admin dev server renders status pulling from API.
- Mobile can hit /health and display connectivity.

Acceptance criteria
- [ ] Railway shows API service healthy with Postgres connected.
- [ ] CI runs on PR with lint/test; main deploy triggers (no pager output in logs).
- [ ] .env templates exist with documented required vars.

Dependencies
- GitHub repo access, Railway account.

Risks/Mitigations
- Secrets sprawl → Use .env.example, GitHub secrets, and Railway variables; document owners.
- CORS confusion → Define allowed origins now (admin domain, localhost dev ports).

Links
- Architecture doc, OpenAPI plan (to be added in Week 1/2).