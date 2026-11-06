---
name: Week 1 — Auth, Profile, Storage (Signed URLs)
about: Implement authentication, profiles, and S3-compatible storage via Railway Buckets
title: "Week 1: Auth, Profile, Storage"
labels: ["epic","week-1"]
assignees: []
---

Goals
- Secure auth (JWT access+refresh with rotation), basic profile CRUD.
- Private file storage with signed PUT/GET URLs.

Tasks
- API
  - [ ] POST /v1/auth/register, /login, /refresh (rotate), /logout.
  - [ ] Email verify + forgot/reset (stubs if email later).
  - [ ] GET/PATCH /v1/users/me.
  - [ ] StorageService with Railway Buckets; POST /v1/storage/upload-url, GET /v1/storage/download-url.
  - [ ] Audit logs for login/register.
- Mobile
  - [ ] Wire onboarding/login/register/forgot/email verify to API.
  - [ ] StorageRepository: request upload-url, PUT to bucket; set avatarKey in profile.
- Admin
  - [ ] Admin login; Users list/detail; edit role/KYC; avatar upload via signed URL.
- Infra/CI
  - [ ] JWT secrets set; STORAGE_* envs set in Railway; CORS configured.

Deliverables
- Full login/logout/refresh; profile edit; avatar upload.

Acceptance criteria
- [ ] Access token expires; refresh rotates; revoked refresh is rejected.
- [ ] Profile GET/PATCH returns/updates displayName, avatarKey.
- [ ] Upload URL returns key + pre-signed PUT; direct PUT succeeds; object not publicly listable.
- [ ] Admin can view users and update role/KYC.

Dependencies
- Week 0 scaffolding complete.

Risks/Mitigations
- Token theft → httpOnly cookies for admin; secure storage on mobile; rotate refresh on use.
- Storage CORS → Use forcePathStyle and allow PUT/GET; fallback to server proxy if needed.
