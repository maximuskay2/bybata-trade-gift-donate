---
name: Week 8 — Notifications + Search
about: User notifications (list/mark-read) and search across domains
title: "Week 8: Notifications + Search"
labels: ["epic","week-8"]
assignees: []
---

Goals
- Notify users of activity; provide basic search.

Tasks
- API
  - [ ] Notification model + GET /v1/notifications, POST /v1/notifications/:id/read.
  - [ ] Search endpoints per domain (e.g., /v1/trades?query=, /v1/communities?query=) or unified /v1/search.
- Mobile
  - [ ] NotificationsProvider wired; unread badge; Notifications screen; mark-read.
  - [ ] Search and Results wired to backend.
- Admin
  - [ ] Broadcast notifications (admin-only) with template; delivery logs.

Deliverables
- Working notifications and search.

Acceptance criteria
- [ ] Unread count matches server; opening marks as read.
- [ ] Search returns relevant results with pagination and sane filters.
