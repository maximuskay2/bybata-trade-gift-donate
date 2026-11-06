---
name: Week 3 — Trade Module (Trades, Offers, Negotiation)
about: Implement trading flows: listing, offering, acceptance, negotiation threads
title: "Week 3: Trade Module"
labels: ["epic","week-3"]
assignees: []
---

Goals
- Allow users to create trades, receive offers, accept/reject, and negotiate.

Tasks
- API
  - [ ] Models: Trade, TradeOffer, Negotiation, Message (negotiation messages).
  - [ ] CRUD /v1/trades; offers (create/list); actions: accept/reject/withdraw.
  - [ ] Negotiation: POST messages; GET history.
  - [ ] Rules: accepting an offer closes trade; only owner cancels; permissions enforced.
- Mobile
  - [ ] Wire CreateTrade, MyTrades, TradeDetails, TradeOffers, Negotiation; media via storage.
- Admin
  - [ ] Trade moderation: list, filter, force close/cancel; CSV export.

Deliverables
- Complete trade lifecycle with offers and negotiation.

Acceptance criteria
- [ ] Creating trade returns id and appears in list/search.
- [ ] Accepting offer sets trade=CLOSED and offer=ACCEPTED; others remain PENDING/REJECTED.
- [ ] Negotiation messages persist and list correctly in order.
