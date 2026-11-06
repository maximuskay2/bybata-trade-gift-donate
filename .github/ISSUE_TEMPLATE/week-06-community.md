---
name: Week 6 — Community (Communities, Posts, Events, Members)
about: Community creation, membership, posting, and events
title: "Week 6: Community"
labels: ["epic","week-6"]
assignees: []
---

Goals
- Build community spaces with roles, posts, and events.

Tasks
- API
  - [ ] Models: Community, CommunityMember, Post, Event.
  - [ ] Endpoints: create/list communities; details; members; posts (create/list); events (create/list).
  - [ ] Roles: OWNER/ADMIN/MEMBER; private/public access rules.
- Mobile
  - [ ] Wire CreateCommunity, CommunityDetails, CommunityPosts, CreatePost (type param), Events, Members.
- Admin
  - [ ] Moderation: remove posts, manage members/roles, ban, event edits.

Deliverables
- Functional communities with content and membership.

Acceptance criteria
- [ ] Private community content inaccessible to non-members.
- [ ] Members can post; role permissions enforced (owner/admin actions).
