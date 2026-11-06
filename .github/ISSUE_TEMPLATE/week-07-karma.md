---
name: Week 7 — Karma (Points, Achievements, History, Leaderboard)
about: Event-sourced karma with achievements
title: "Week 7: Karma"
labels: ["epic","week-7"]
assignees: []
---

Goals
- Provide gamification via points and achievements.

Tasks
- API
  - [ ] Models: KarmaAccount, KarmaEvent, Achievement, UserAchievement.
  - [ ] GET /v1/karma/me, /history, /leaderboard, /achievements; POST claim.
  - [ ] Hook minimal events (first login, first trade, first donation) to increment points.
- Mobile
  - [ ] Wire Karma dashboard, Leaderboard, Achievements, History, TrustLevel, Earn guide.
- Admin
  - [ ] Achievements CRUD; leaderboard view; manual adjustments (admin-only).

Deliverables
- Karma surfacing across app and admin.

Acceptance criteria
- [ ] Leaderboard order stable and indexed; totals match event sums.
- [ ] Achievements unlock and persist; duplicates prevented.
