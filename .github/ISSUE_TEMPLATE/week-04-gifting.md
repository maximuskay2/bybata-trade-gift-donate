---
name: Week 4 — Gifting
about: Implement gift creation, details, claims, history
title: "Week 4: Gifting"
labels: ["epic","week-4"]
assignees: []
---

Goals
- Users can create gifts (with media), share/claim via code, and view history.

Tasks
- API
  - [ ] Models: Gift, GiftClaim; statuses ACTIVE/CLAIMED/EXPIRED/CANCELLED.
  - [ ] POST /v1/gifts; GET /v1/gifts/:id; POST /v1/gifts/:id/claim; lists: mine, history.
  - [ ] Validate creator != claimer; expiry enforcement; unique code.
- Mobile
  - [ ] Wire CreateGift, GiftDetails, ClaimGift, MyGifts, GiftHistory.
- Admin
  - [ ] Gifts overview, filters by status, claim statistics.

Deliverables
- Gift creation, secure claiming, and tracking.

Acceptance criteria
- [ ] Gift claim prevents duplicates; status transitions valid.
- [ ] Gift media stored privately; keys persisted; downloads via signed URL.
