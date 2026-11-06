---
name: Week 9 — Real-time (Chat + Live Notifications)
about: WebSockets for chat and live notification counters
title: "Week 9: Real-time"
labels: ["epic","week-9"]
assignees: []
---

Goals
- Real-time chat and live notification updates.

Tasks
- API
  - [ ] WS gateway for chat; join rooms per conversation; send/receive; typing/seen (optional).
  - [ ] Push live notifications to connected clients.
  - [ ] Optional Redis for scaling/rooms.
- Mobile
  - [ ] Replace mock chat with real conversations/messages; WS subscription and reconnect.
  - [ ] Live updates for unread notifications (and wallet if desired).
- Admin
  - [ ] Chat moderation console; view conversations/messages; flag/ban tools.

Deliverables
- Stable WS-backed chat; live unread counts.

Acceptance criteria
- [ ] Messages delivered in <2s on average; ordered consistently; reconnects gracefully.
- [ ] Unread counts update without manual refresh.
