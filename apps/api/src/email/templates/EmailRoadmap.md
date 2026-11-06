Account & Security
Welcome / Verify email (initial signup)
Email verified confirmation
Password reset request
Password changed confirmation
New device or login alert
Account locked / suspicious activity
Account deletion request + confirmation
Terms/Privacy updates
Trade
Trade request received
Trade request accepted / rejected
Counter‑offer received
Trade completed (both parties)
Trade canceled / expired
Trade reminder (pending too long)
Gifting
Gift offer received
Gift accepted
Gift claimed / completed
Gift expired
Thank‑you / appreciation prompt
Donations / Campaigns
Campaign created (owner)
Campaign approved / published
Donation received (owner)
Donation receipt (donor)
Goal milestone reached
Campaign paused / ended
Campaign expiring soon
Refund / failed payment
Wallet / Payments / BYC
Wallet funded
Wallet funding failed
BYC sent / received
Withdrawal request / completed
Conversion rate update (if applicable)
Promo / boost purchase receipt
Community
Community invite received
Invite accepted / declined
Join request approved / rejected
New post in community (digest or realtime)
Mention or reply in community
Chat & Messages
New message (if offline)
Message request / new conversation
Chat reaction / mention (optional)
Profile & Verification
Profile updated confirmation
Verification submitted
Verification approved / rejected
Trust level / Karma level up
Ads / Promotions (if enabled)
Ad submitted
Ad approved / rejected
Ad started / ended
Ad budget low / depleted
Promotion performance summary (daily/weekly)
System / Service
Scheduled maintenance
Feature announcements (optional)
Policy / compliance notifications
Weekly activity summary (digest)
If you want, I can translate this into an “email events matrix” with exact event names, recipients, and required template variables so engineering can implement quickly.
translate this into an “email events matrix” with exact event names, recipients, and required template variables so engineering can implement quickly and create to do onhow to implement this now 

Below is a compact Email Events Matrix with exact event names, recipients, and required template variables, followed by a implementation todo checklist the team can execute.
Email Events Matrix
Legend
Event Name: Suggested event key for backend
Recipient: actor, target, both, admins
Vars: Required template variables
1) Account & Security
auth.signup.welcome → recipient: actor
vars: firstName, displayName, appName, supportEmail, loginUrl
auth.email.verify → actor
vars: displayName, verificationLink, expiresAt, appName
auth.email.verified → actor
vars: displayName, appName, loginUrl
auth.password.reset.request → actor
vars: displayName, resetLink, expiresAt, appName
auth.password.changed → actor
vars: displayName, changedAt, supportEmail
auth.login.new_device → actor
vars: displayName, deviceName, ip, city, loginAt, supportEmail
auth.account.locked → actor
vars: displayName, unlockSteps, supportEmail
auth.account.deleted.confirm → actor
vars: displayName, deletedAt, supportEmail
2) Trade
trade.request.received → target
vars: targetName, actorName, tradeTitle, tradeId, tradeUrl
trade.request.accepted → actor
vars: actorName, targetName, tradeTitle, tradeId, tradeUrl
trade.request.rejected → actor
vars: actorName, targetName, tradeTitle, tradeId, tradeUrl
trade.counter_offer.received → target
vars: targetName, actorName, tradeTitle, counterOfferSummary, tradeUrl
trade.completed → both
vars: actorName, targetName, tradeTitle, tradeId, completedAt, tradeUrl
trade.canceled → both
vars: actorName, targetName, tradeTitle, canceledBy, tradeUrl
trade.reminder.pending → actor
vars: actorName, tradeTitle, daysPending, tradeUrl
3) Gifting
gift.offer.received → target
vars: targetName, actorName, giftTitle, giftUrl
gift.accepted → actor
vars: actorName, targetName, giftTitle, giftUrl
gift.claimed → both
vars: actorName, targetName, giftTitle, claimedAt, giftUrl
gift.expired → actor
vars: actorName, giftTitle, expiredAt
gift.thank_you.prompt → target
vars: targetName, actorName, giftTitle, giftUrl
4) Donations / Campaigns
campaign.created → actor
vars: actorName, campaignTitle, campaignUrl
campaign.published → actor
vars: actorName, campaignTitle, campaignUrl
campaign.approved → actor
vars: actorName, campaignTitle, campaignUrl
campaign.rejected → actor
vars: actorName, campaignTitle, reason, supportEmail
donation.received → target (campaign owner)
vars: targetName, donorName, amount, currency, campaignTitle, campaignUrl
donation.receipt → actor (donor)
vars: actorName, amount, currency, campaignTitle, receiptId, campaignUrl
campaign.milestone.reached → target
vars: targetName, campaignTitle, milestone, campaignUrl
campaign.expiring → target
vars: targetName, campaignTitle, daysLeft, campaignUrl
campaign.ended → target
vars: targetName, campaignTitle, totalRaised, campaignUrl
donation.failed → actor
vars: actorName, amount, currency, campaignTitle, reason, supportEmail
5) Wallet / Payments / BYC
wallet.funded → actor
vars: actorName, amount, currency, balance, fundedAt
wallet.funding.failed → actor
vars: actorName, amount, currency, reason, supportEmail
wallet.byc.sent → actor
vars: actorName, amount, recipientName, balance, txId
wallet.byc.received → target
vars: targetName, amount, senderName, balance, txId
wallet.withdrawal.requested → actor
vars: actorName, amount, currency, withdrawalId, createdAt
wallet.withdrawal.completed → actor
vars: actorName, amount, currency, withdrawalId, completedAt
wallet.rate.updated → actor
vars: actorName, oldRate, newRate, effectiveAt
6) Community
community.invite.received → target
vars: targetName, communityName, inviterName, inviteUrl
community.invite.accepted → actor (inviter)
vars: actorName, targetName, communityName
community.invite.declined → actor
vars: actorName, targetName, communityName
community.join.request.approved → target
vars: targetName, communityName, communityUrl
community.join.request.rejected → target
vars: targetName, communityName, reason
community.new_post.digest → target
vars: targetName, communityName, postCount, digestUrl
community.mention → target
vars: targetName, actorName, communityName, postUrl
7) Chat
chat.new_message → target
vars: targetName, actorName, snippet, chatUrl
chat.new_conversation → target
vars: targetName, actorName, contextTitle, chatUrl
8) Profile / Verification / Karma
profile.updated → actor
vars: actorName, updatedAt
verification.submitted → actor
vars: actorName, submittedAt
verification.approved → actor
vars: actorName, approvedAt, trustLevel
verification.rejected → actor
vars: actorName, reason, supportEmail
karma.level.up → actor
vars: actorName, newLevel, points
9) Ads / Promotions (if enabled)
ad.submitted → actor
vars: actorName, adTitle, adId
ad.approved → actor
vars: actorName, adTitle, startDate, adUrl
ad.rejected → actor
vars: actorName, adTitle, reason
ad.budget.low → actor
vars: actorName, adTitle, remainingBudget, adUrl
ad.ended → actor
vars: actorName, adTitle, spent, adUrl
10) System / Service
system.maintenance.scheduled → all
vars: windowStart, windowEnd, statusUrl
system.policy.updated → all
vars: effectiveAt, policyUrl
system.weekly.summary → actor
vars: actorName, summaryItems, summaryUrl
Implementation TODO (Engineering Checklist)
Phase 1 — Core Infrastructure
Define EmailEventName enum constants using the names above.
Create a single EmailDispatcher service that accepts:
eventName, recipientUserId, templateVars, locale.
Implement EmailTemplateRegistry mapping eventName → templateId + requiredVars.
Add runtime validation: error if any required template var is missing.
Implement provider adapter (e.g., SendGrid/Mailgun/SES).
Phase 2 — Data Contracts
Create a EmailPayload type with:
to, subject, templateId, vars, category, eventId.
Store EmailLog table: eventName, recipientId, sentAt, status, providerMessageId, error.
Phase 3 — Event Emission
For each feature module, emit email events:
Auth, Trade, Gift, Donation, Wallet, Community, Chat, Verification, Ads.
Use background job/queue for delivery (Bull, SQS, etc.).
Phase 4 — Templates
Create templates for each event (MJML or provider templates).
Include common footer: unsubscribe, support, social links.
Phase 5 — Preferences
Add email_preferences per category:
transactional (always on)
marketing/digest (opt‑out)
Respect preferences when dispatching.
Phase 6 — QA
Add integration tests for:
correct template variables
correct recipient(s)
preference opt‑out
Add seed scripts for demo users and events.



