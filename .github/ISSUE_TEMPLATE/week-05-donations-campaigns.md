---
name: Week 5 — Donations & Campaigns
about: Implement campaigns lifecycle and donations with history
title: "Week 5: Donations & Campaigns"
labels: ["epic","week-5"]
assignees: []
---

Goals
- Allow users to create/manage campaigns and accept donations.

Tasks
- API
  - [ ] Models: Campaign, Donation; CampaignStatus lifecycle.
  - [ ] Endpoints: create campaign, my campaigns, donation history, campaign management, donate.
- Mobile
  - [ ] Wire CreateCampaign, MyCampaigns, DonationHistory, CampaignManagement.
- Admin
  - [ ] Campaign list; donations explorer; status/visibility controls; CSV export.

Deliverables
- Campaign CRUD and donation flows with history.

Acceptance criteria
- [ ] State transitions validated; donations immutable.
- [ ] Totals per campaign computed and consistent with donations.
