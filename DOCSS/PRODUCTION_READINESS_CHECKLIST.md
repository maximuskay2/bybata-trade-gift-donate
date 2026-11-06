# BYBATA Production Readiness Checklist

**Generated:** December 2024  
**Status:** Pre-Production  
**Overall Completion:** ~70% Production Ready

---

## 🚨 CRITICAL - Must Fix Before Production

### 1. Testing & QA
- [ ] **End-to-End Testing** - Execute all 11 test scenarios from `docs/E2E_TESTING_GUIDE.md`
- [ ] **Performance Testing** - Load testing for feed endpoint (<2s target, <500ms P95 API)
- [ ] **Unit Test Coverage** - Currently minimal test files exist (only 4 spec files found)
  - [ ] Backend: Add unit tests for all services (interactions, feed, wallet, etc.)
  - [ ] Frontend: Add widget tests for critical components
- [ ] **Integration Tests** - Test payment gateway integrations (Paystack, Stripe, PayPal) for BYC funding
- [ ] **BYC Transaction Tests** - Test all BYC coin transactions (donations, transfers, promotions)
- [ ] **Conversion Rate Tests** - Test fiat-to-BYC conversion accuracy
- [ ] **Security Testing** - Penetration testing, SQL injection tests, XSS tests
- [ ] **User Acceptance Testing (UAT)** - Real user testing with feedback

### 2. Wallet System Implementation (BYC Coin Architecture)

**Architecture Overview:**
- **BYC Coin** is the internal currency used for ALL transactions in the app
- Users fund their wallet through payment gateways (Stripe, PayPal, Paystack)
- Fiat currency (USD/NGN) is converted to BYC coin using admin-controlled conversion rates
- Payment gateways are ONLY used for wallet funding/top-up, NOT for transactions
- All in-app transactions (donations, trades, transfers, promotions) use BYC coin

**Critical Implementation Items:**
- [ ] **Payment Gateway Integration (Funding Only)** - Top-up functionality incomplete
  - [ ] **Paystack Integration (NGN)** 
    - [ ] Initialize transaction and get authorization URL
    - [ ] Handle callback and webhook verification
    - [ ] Convert NGN amount to BYC using admin rate (BYC = NGN / bycToNgn)
    - [ ] Credit BYC to user wallet after verified payment
    - [ ] Idempotency handling to prevent double-credit
  - [ ] **Stripe Integration (USD)**
    - [ ] Create PaymentIntent with client-side card handling
    - [ ] Webhook verification for `payment_intent.succeeded`
    - [ ] Convert USD amount to BYC using admin rate (BYC = USD / bycToUsd)
    - [ ] Credit BYC to user wallet after verified payment
    - [ ] Handle payment failures and refunds
  - [ ] **PayPal Integration (USD)**
    - [ ] Create Order and get approval link
    - [ ] Handle order capture and webhook verification
    - [ ] Convert USD amount to BYC using admin rate
    - [ ] Credit BYC to user wallet after verified payment
    - [ ] Handle order cancellations
  - [ ] **Webhook Security** - Signature verification for all payment webhooks
  - [ ] **Idempotency** - Prevent duplicate credits from webhook retries

- [ ] **BYC Coin Transaction System** - Only 20% complete (wallet structure exists, no coin debit/ledger)
  - [ ] **Donations with BYC**
    - [ ] Implement wallet debit for donations (deduct BYC from donor)
    - [ ] Credit BYC to campaign wallet/escrow
    - [ ] Create immutable ledger entries (debit donor, credit campaign)
    - [ ] Handle insufficient balance scenarios (show top-up CTA)
    - [ ] Update campaign progress immediately after donation
  - [ ] **Trade Promotions with BYC**
    - [ ] Debit BYC for trade promotion purchases
    - [ ] Create promotion records linked to trades
    - [ ] Apply promotion boosts/badges to trades
  - [ ] **Ad Purchases with BYC**
    - [ ] Debit BYC for advertisement placements
    - [ ] Create advert records with scheduling
    - [ ] Track ad performance and billing
  - [ ] **P2P BYC Transfers**
    - [ ] Complete implementation with atomic debit/credit transactions
    - [ ] Create two `WalletTransaction` rows (debit sender, credit recipient)
    - [ ] Create `Transfer` record linking both transactions
    - [ ] PIN/biometric confirmation for transfers
    - [ ] Handle insufficient balance errors
    - [ ] Send notifications to both parties

- [ ] **Conversion Rate Management**
  - [ ] Admin-controlled conversion rates (BYC ↔ NGN, BYC ↔ USD)
  - [ ] CRUD operations for conversion rates via admin dashboard
  - [ ] Rate validity windows (validFrom, validTo)
  - [ ] Automatic deactivation of old rates when new active rate is set
  - [ ] Rate history and audit trail
  - [ ] Frontend displays real-time BYC estimates based on latest rates

- [ ] **Wallet Security**
  - [ ] PIN/biometric confirmation for all BYC debits (transfers, donations, purchases)
  - [ ] Wallet lock/unlock functionality
  - [ ] Session timeout for wallet operations
  - [ ] Transaction limits (daily/monthly) per user
  - [ ] Suspicious activity detection

- [ ] **Fraud Detection & Prevention**
  - [ ] Velocity checks (transactions per time window)
  - [ ] Large-amount thresholds with admin alerts
  - [ ] Recipient blacklists/whitelists
  - [ ] Unusual pattern detection
  - [ ] Webhook replay attack prevention

- [ ] **Transaction Ledger & Audit**
  - [ ] Immutable transaction records with type (FUND, SEND, RECEIVE, DONATION, PROMOTION, ADVERT, REFUND)
  - [ ] Reference linking (referenceType, referenceId) to domain entities
  - [ ] Idempotency keys for all transactions
  - [ ] Transaction status tracking (PENDING, SUCCESS, FAILED)
  - [ ] Complete audit trail for admin review

### 3. Error Handling & Monitoring
- [ ] **Error Tracking** - Sentry integration (DSN configured but not fully integrated)
- [ ] **Structured Logging** - Winston logger with correlation IDs (partially implemented)
- [ ] **Error Boundaries** - Frontend error boundary implementation
- [ ] **Health Check Endpoints** - `/health` endpoint for load balancers
- [ ] **Monitoring Dashboards** - Transaction volumes, gateway failures, latency
- [ ] **Alerting System** - Email/Slack alerts for critical errors
- [ ] **Log Aggregation** - Centralized logging solution

### 4. Security Hardening
- [ ] **Rate Limiting** - Throttler enabled but needs production tuning
- [ ] **Input Sanitization** - XSS prevention, SQL injection protection
- [ ] **CORS Configuration** - Production CORS_ORIGINS properly configured
- [ ] **Environment Variables** - All secrets properly secured (no hardcoded values)
- [ ] **API Key Rotation** - Strategy for rotating JWT secrets
- [ ] **HTTPS Enforcement** - SSL/TLS certificates configured
- [ ] **Database Security** - Connection encryption, backup encryption
- [ ] **Webhook Signature Verification** - All payment webhooks verified
- [ ] **2FA Implementation** - Two-factor authentication (marked as TODO in settings)

### 5. Database & Data
- [ ] **Database Migrations** - Automated migration strategy for production
- [ ] **Database Backups** - Automated backup schedule and recovery testing
- [ ] **Data Retention Policy** - GDPR compliance, data deletion workflows
- [ ] **Index Optimization** - Performance tuning for production queries
- [ ] **Connection Pooling** - Database connection pool configuration

---

## ⚠️ HIGH PRIORITY - Should Fix Soon

### 6. Offer/Ask Flow Completion System (Module-Isolated Chat Architecture)

**Architecture Overview:**
The Offer/Ask Flow Completion system is a reusable chat component that integrates into four distinct modules (Trade, Gift, Donation, Community) while maintaining complete isolation between modules. Each module has its own dedicated chat environment, and conversations initiated from one module remain confined to that module's chat system.

**Core Principles:**
- **Reusability**: Shared chat infrastructure (backend services, WebSocket gateway, UI components)
- **Isolation**: Complete separation of chat contexts per module
- **Context Preservation**: Module-specific metadata and UI elements
- **No Cross-Module Interference**: Conversations from one module never appear in another module's chat

#### 6.1 Backend Architecture (Module Isolation)

- [ ] **Conversation Type Enum** - Extend `ConversationType` to include:
  - [ ] `TRADE` - Trade negotiations and offers
  - [ ] `GIFT` - Gift requests and claims
  - [ ] `DONATION` - Campaign support and donor communications
  - [ ] `COMMUNITY` - Community post discussions and requests
  - [ ] `DIRECT` - General direct messages (fallback)

- [ ] **Conversation Metadata Schema** - Store module-specific context:
  ```typescript
  {
    sourceModule: 'TRADE' | 'GIFT' | 'DONATION' | 'COMMUNITY',
    itemId: string,           // Trade ID, Gift ID, Campaign ID, or Post ID
    itemType: string,         // 'trade', 'gift', 'campaign', 'request'
    itemTitle: string,         // Display title for chat header
    itemStatus: string,        // Current status of the item
    moduleSpecificData?: {    // Module-specific fields
      // Trade: price, condition, negotiationStatus
      // Gift: giftType, claimStatus
      // Donation: campaignGoal, donationAmount
      // Community: postType, communityId
    }
  }
  ```

- [ ] **Module-Specific Conversation Queries** - Backend endpoints:
  - [ ] `GET /v1/chat/conversations?module=TRADE` - Returns only Trade conversations
  - [ ] `GET /v1/chat/conversations?module=GIFT` - Returns only Gift conversations
  - [ ] `GET /v1/chat/conversations?module=DONATION` - Returns only Donation conversations
  - [ ] `GET /v1/chat/conversations?module=COMMUNITY` - Returns only Community conversations
  - [ ] Filter conversations by `ConversationType` and metadata `sourceModule`

- [ ] **Conversation Creation with Module Context**:
  - [ ] When "I'm Interested" is clicked, create conversation with:
    - [ ] `type` set to appropriate `ConversationType`
    - [ ] `metadata.sourceModule` set to originating module
    - [ ] `metadata.itemId` linking to the specific item
    - [ ] `metadata.itemTitle` for display
  - [ ] Prevent duplicate conversations for same item between same users
  - [ ] Validate user has access to the item before creating conversation

- [ ] **WebSocket Namespace Isolation** (Optional Enhancement):
  - [ ] Consider module-specific namespaces: `/chat/trade`, `/chat/gift`, `/chat/donation`, `/chat/community`
  - [ ] Or use single namespace with module filtering in message handlers
  - [ ] Ensure messages are routed only to conversations of matching module type

#### 6.2 Frontend Architecture (Module-Isolated Chat UI)

- [ ] **Reusable Chat Component** - Core chat widget that accepts module context:
  ```dart
  class ModuleChatScreen extends StatelessWidget {
    final ChatModule module;  // TRADE, GIFT, DONATION, COMMUNITY
    final String itemId;
    final String itemTitle;
    final Map<String, dynamic>? moduleSpecificData;
  }
  ```

- [ ] **Chat List Screen with Module Tabs**:
  - [ ] Tab bar with 4 tabs: Trade, Gift, Donation, Community
  - [ ] Each tab shows only conversations for that module
  - [ ] Tab switching filters conversations by `sourceModule`
  - [ ] Active tab indicator and unread message badges per module
  - [ ] Default tab based on navigation context (e.g., from Trade screen → Trade tab)

- [ ] **Module-Specific Chat Headers**:
  - [ ] **Trade Chat Header**:
    - [ ] Show trade title: "Re: [Trade Title]"
    - [ ] Display trade status badge (Open, Negotiating, Closed)
    - [ ] Quick link to trade details screen
    - [ ] Price/condition info if applicable
  - [ ] **Gift Chat Header**:
    - [ ] Show gift title: "Re: [Gift Title]"
    - [ ] Display gift status (Available, Claimed)
    - [ ] Quick link to gift details screen
    - [ ] Gift type icon/badge
  - [ ] **Donation Chat Header**:
    - [ ] Show campaign title: "Re: [Campaign Title]"
    - [ ] Display campaign progress (amount raised / goal)
    - [ ] Quick link to campaign details screen
    - [ ] Campaign status badge
  - [ ] **Community Chat Header**:
    - [ ] Show post/request title: "Re: [Post Title]"
    - [ ] Display community name
    - [ ] Quick link to post/community screen
    - [ ] Post type indicator (Request, Discussion, etc.)

- [ ] **Module-Specific Chat Features**:
  - [ ] **Trade Module**:
    - [ ] Proposal/counter-proposal message types
    - [ ] Price negotiation UI elements
    - [ ] Trade status updates within chat
    - [ ] "Accept Offer" button in chat (if applicable)
  - [ ] **Gift Module**:
    - [ ] Gift claim request messages
    - [ ] Gift status updates (claimed, expired)
    - [ ] Thank you message templates
  - [ ] **Donation Module**:
    - [ ] Donation amount display in messages
    - [ ] Campaign update notifications
    - [ ] Thank you messages from campaign creator
  - [ ] **Community Module**:
    - [ ] Post context preservation
    - [ ] Community-specific message formatting
    - [ ] Link to original post/request

- [ ] **State Management for Module Isolation**:
  - [ ] `ChatProvider` with module filtering:
    ```dart
    List<ChatConversation> getConversationsForModule(ChatModule module) {
      return conversations.where((c) => c.sourceModule == module).toList();
    }
    ```
  - [ ] Separate state per module tab (prevents cross-module data mixing)
  - [ ] Module-specific message handlers
  - [ ] Module-specific notification routing

#### 6.3 Integration Points (Module Entry)

- [ ] **Trade Module Integration**:
  - [ ] "I'm Interested" button on `TradeDetailsScreen`
  - [ ] Creates conversation with `sourceModule: 'TRADE'`
  - [ ] Navigates to Chat List with Trade tab active
  - [ ] Conversation appears only in Trade tab
  - [ ] Trade-specific actions available in chat

- [ ] **Gift Module Integration**:
  - [ ] "I'm Interested" / "Request Gift" button on `GiftDetailsScreen`
  - [ ] Creates conversation with `sourceModule: 'GIFT'`
  - [ ] Navigates to Chat List with Gift tab active
  - [ ] Conversation appears only in Gift tab
  - [ ] Gift-specific actions available in chat

- [ ] **Donation Module Integration**:
  - [ ] "I Want to Help" / "Support Campaign" button on `CampaignDetailsScreen`
  - [ ] Creates conversation with `sourceModule: 'DONATION'`
  - [ ] Navigates to Chat List with Donation tab active
  - [ ] Conversation appears only in Donation tab
  - [ ] Donation-specific actions available in chat

- [ ] **Community Module Integration**:
  - [ ] "I'm Interested" / "Respond" button on `RequestDetailsScreen` or `CommunityPostCard`
  - [ ] Creates conversation with `sourceModule: 'COMMUNITY'`
  - [ ] Navigates to Chat List with Community tab active
  - [ ] Conversation appears only in Community tab
  - [ ] Community-specific actions available in chat

#### 6.4 Completion Flow Integration

- [ ] **Completion Actions Per Module**:
  - [ ] **Trade**: "Mark Trade as Completed" in chat menu or detail screen
  - [ ] **Gift**: "Mark Gift as Claimed" in chat menu or detail screen
  - [ ] **Donation**: "Mark Campaign as Completed" (campaign owner only)
  - [ ] **Community**: "Mark Request as Fulfilled" (request creator only)

- [ ] **Completion Dialog Integration**:
  - [ ] Reusable `CompletionDialog` widget
  - [ ] Module-specific completion messages
  - [ ] Rating and thank-you functionality
  - [ ] Karma point updates per module type

- [ ] **Status Updates in Chat**:
  - [ ] Show completion status in chat header
  - [ ] Display completion date and rating (if applicable)
  - [ ] Disable further actions after completion
  - [ ] Show "Completed" badge in conversation list

#### 6.5 Isolation Enforcement

- [ ] **Backend Validation**:
  - [ ] Verify `sourceModule` matches conversation type on message send
  - [ ] Prevent cross-module conversation access
  - [ ] Validate item belongs to correct module before conversation creation
  - [ ] Module-specific permission checks

- [ ] **Frontend Validation**:
  - [ ] Filter conversations by module in all queries
  - [ ] Prevent navigation to wrong module's chat from another module
  - [ ] Module-specific route guards
  - [ ] Clear visual distinction between module tabs

- [ ] **Data Isolation**:
  - [ ] Conversations stored with module metadata
  - [ ] Messages tagged with module context
  - [ ] No shared state between modules
  - [ ] Module-specific caching strategies

#### 6.6 Testing Requirements

- [ ] **Isolation Testing**:
  - [ ] Verify Trade conversations don't appear in Gift tab
  - [ ] Verify Gift conversations don't appear in Donation tab
  - [ ] Verify Donation conversations don't appear in Community tab
  - [ ] Verify Community conversations don't appear in Trade tab
  - [ ] Test conversation creation from each module
  - [ ] Test message routing to correct module tab

- [ ] **Integration Testing**:
  - [ ] Test "I'm Interested" flow for each module
  - [ ] Test completion flow for each module
  - [ ] Test navigation between modules and chat
  - [ ] Test module-specific features in chat

- [ ] **Performance Testing**:
  - [ ] Test chat list loading with multiple modules
  - [ ] Test tab switching performance
  - [ ] Test real-time message updates per module

#### 6.7 Additional Features

- [ ] **Chat Header Context** - Update chat screen to show item title (args passed, UI pending)
- [ ] **Completion Status Badges** - Show "Completed" badge on completed items in chat list
- [ ] **Feature Flags** - Dynamic feature flag configuration (currently hardcoded defaults)
- [ ] **Analytics Events** - Track user interactions, completion rates, adoption metrics per module
- [ ] **Performance Optimization** - Feed aggregation optimization for large datasets
- [ ] **Unread Message Counts** - Per-module unread message badges
- [ ] **Module-Specific Notifications** - Push notifications tagged with module type
- [ ] **Quick Actions** - Module-specific quick actions in chat (e.g., "View Trade", "Claim Gift")

### 7. Donations Feature (BYC Coin Based)
- [ ] **BYC Donation Flow** - Users donate using BYC coin balance (not external gateways)
  - [ ] Wallet balance check before donation
  - [ ] BYC debit from donor wallet
  - [ ] BYC credit to campaign wallet/escrow
  - [ ] Insufficient balance handling (redirect to top-up flow)
- [ ] **Chat Integration** - Donation chat tab (0% complete, can leverage existing system)
- [ ] **Campaign Updates** - System for campaign owners to post updates
- [ ] **Reward Tiers** - Backend for crowdfunding perks (30% complete)
- [ ] **Real-Time Notifications** - Live donation notifications (10% complete)
- [ ] **Analytics Dashboard** - For campaign creators (deferred, needs approval)

### 8. User Features
- [ ] **Timezone Selector** - Settings screen (marked as TODO)
- [ ] **Theme Selector** - Settings screen (marked as TODO)
- [ ] **Active Sessions Management** - Settings screen (marked as TODO)
- [ ] **Blocked Users Management** - Settings screen (marked as TODO)
- [ ] **Data Download** - GDPR data export functionality
- [ ] **Profile Verification** - KYC workflow completion

### 9. Wallet Features (BYC Coin)
- [ ] **QR Code Scanner** - For receiving BYC transfers (marked as TODO)
- [ ] **Wallet Notifications** - BYC transaction notifications (marked as TODO)
- [ ] **Wallet Settings** - Configuration screen (marked as TODO)
- [ ] **Transaction History Filtering** - Advanced filters and search for BYC transactions
- [ ] **Export Transactions** - CSV/PDF export functionality
- [ ] **BYC Balance Display** - Show balance with fiat equivalents (NGN/USD)
- [ ] **Funding Flow UI** - Seamless top-up experience with real-time BYC conversion preview
- [ ] **Transaction Details** - Show conversion rates used, gateway fees, net BYC received

### 10. Trade-by-Barter System (Comprehensive Item-for-Item Trading)

**Architecture Overview:**
A complete barter system where users can trade items for other users' items. The system supports item uploads, offer creation, negotiation with counter-offers, and acceptance/rejection workflows. All negotiations are integrated with the chat system for seamless communication.

**Current Status:** ~60% Complete
- Basic trade creation exists
- Negotiation screen exists but needs enhancement
- Offers tab exists but needs item-for-item support
- Backend schema needs extension for item-for-item offers

#### 10.1 Backend Schema & Data Model Updates

- [ ] **Extend TradeOffer Model** - Add support for item-for-item trading:
  ```prisma
  model TradeOffer {
    // ... existing fields ...
    offeredTradeId String?  // NEW: ID of the trade item being offered
    offeredTrade   Trade?   @relation("TradeOffer_OfferedTrade", fields: [offeredTradeId], references: [id])
    // Keep amount field for cash offers (hybrid support)
  }
  ```

- [ ] **Create Prisma Migration**:
  - [ ] Add `offeredTradeId` field to `TradeOffer` table
  - [ ] Add foreign key constraint to `Trade` table
  - [ ] Add index on `offeredTradeId` for performance
  - [ ] Make field nullable to support both cash and item offers

- [ ] **Update TradeOffer DTOs**:
  - [ ] `CreateOfferDto` - Add optional `offeredTradeId` field
  - [ ] `OfferResponseDto` - Include `offeredTrade` details in response
  - [ ] Validation: Ensure either `amount` OR `offeredTradeId` is provided (not both required, but at least one)

- [ ] **Update TradeOffer Service Methods**:
  - [ ] `createOffer()` - Accept `offeredTradeId` parameter
  - [ ] `listOffers()` - Include `offeredTrade` relation in query
  - [ ] `acceptOffer()` - Handle item-for-item acceptance logic
  - [ ] Validate offered trade belongs to bidder and is OPEN status

#### 10.2 Backend API Endpoints

- [ ] **Create Offer Endpoint** - `POST /v1/trades/:tradeId/offers`:
  - [ ] Accept `offeredTradeId` in request body (optional, for item offers)
  - [ ] Accept `amount` in request body (optional, for cash offers)
  - [ ] Validation: At least one of `offeredTradeId` or `amount` must be provided
  - [ ] Validate offered trade exists and belongs to bidder (if `offeredTradeId` provided)
  - [ ] Validate offered trade is OPEN status
  - [ ] Prevent self-offers (user can't offer their own trade for their own trade)
  - [ ] Prevent offering a trade that's already closed or in another accepted offer
  - [ ] Create offer with item reference or cash amount
  - [ ] Return full offer with offered trade details (if item offer)
  - [ ] Create notification for trade owner

- [ ] **List Offers Endpoint** - `GET /v1/trades/:tradeId/offers`:
  - [ ] Include `offeredTrade` relation in response (for item offers)
  - [ ] Include `offeredTrade.owner` and `offeredTrade.mediaKeys` for full details
  - [ ] Return offered trade details (title, images, description, condition, category)
  - [ ] Filter offers by type (item offers vs cash offers) - optional query param
  - [ ] Sort by creation date (newest first)
  - [ ] Pagination support (page, size)

- [ ] **Get Offer Details** - `GET /v1/offers/:id`:
  - [ ] Return full offer details including offered trade
  - [ ] Include negotiation history if exists
  - [ ] Include offer status and metadata

- [ ] **Accept Offer Endpoint** - `POST /v1/offers/:id/accept`:
  - [ ] Handle item-for-item acceptance:
    - [ ] Validate offer has `offeredTradeId`
    - [ ] Mark both trades as CLOSED
    - [ ] Set `acceptedOfferId` on target trade
    - [ ] Set `acceptedOfferId` on offered trade (new field or metadata)
    - [ ] Create acceptance records for both trades
    - [ ] Link trades to each other via metadata or new relation
    - [ ] Reject all other pending offers for both trades
  - [ ] Handle cash offer acceptance (existing logic)
  - [ ] Create karma events for both parties (TRADE_COMPLETED)
  - [ ] Send notifications to both users
  - [ ] Return updated trade statuses

- [ ] **Reject Offer Endpoint** - `POST /v1/offers/:id/reject`:
  - [ ] Update offer status to REJECTED
  - [ ] Send notification to bidder
  - [ ] Optionally allow rejection with message/feedback

- [ ] **Counter-Offer Endpoint** - `POST /v1/offers/:id/counter-offer`:
  - [ ] Accept new `offeredTradeId` in request body
  - [ ] Accept optional `message` for counter-offer context
  - [ ] Validate new offered trade belongs to counter-offerer
  - [ ] Validate new offered trade is OPEN status
  - [ ] Create new `TradeOffer` with:
    - [ ] Same `tradeId` (target trade)
    - [ ] New `offeredTradeId` (counter-offer item)
    - [ ] Link to original offer via metadata or parentOfferId
  - [ ] Create negotiation message with type `COUNTER_OFFER`
  - [ ] Update original offer status (optional: mark as COUNTERED)
  - [ ] Return new offer with negotiation context

- [ ] **Withdraw Offer Endpoint** - `POST /v1/offers/:id/withdraw`:
  - [ ] Validate offer belongs to current user
  - [ ] Update offer status to WITHDRAWN
  - [ ] Send notification to trade owner (optional)
  - [ ] Clean up any associated negotiations

#### 10.3 Frontend: Trade Details Screen Updates

- [ ] **"Make Offer" Button Enhancement**:
  - [ ] Show button on `TradeDetailsScreen` for non-owners
  - [ ] Button label: "Make Offer" or "Trade for This"
  - [ ] On tap: Navigate to negotiation screen with:
    - [ ] Target trade (the one being viewed)
    - [ ] User's available trades (for selection)
    - [ ] Pre-populated context

- [ ] **Navigation to Negotiation**:
  - [ ] Update `_onInterestedPressed()` or create `_onMakeOfferPressed()`
  - [ ] Fetch user's active trades before navigation
  - [ ] Pass trades list to `NegotiationScreen`
  - [ ] Handle case where user has no available trades (show message)

- [ ] **Item Selection UI** (if needed on details screen):
  - [ ] Quick preview of user's trades
  - [ ] "Select Item to Trade" button
  - [ ] Navigate to trade selection screen

#### 10.4 Frontend: Negotiation Screen Enhancements

- [ ] **Item Selection Interface**:
  - [ ] Display user's available trades in selectable list/grid
  - [ ] Show trade cards with:
    - [ ] First image thumbnail
    - [ ] Title and category
    - [ ] Condition badge
    - [ ] Status indicator (Available, In Offer, etc.)
  - [ ] Allow selection of trade to offer
  - [ ] Show selected trade prominently at top
  - [ ] "Change Item" option to reselect
  - [ ] Filter: Show only OPEN trades available for offering
  - [ ] Empty state: "No items available" with "Create Trade" CTA

- [ ] **Proposal Creation**:
  - [ ] "Propose Trade" button when item selected
  - [ ] Disable button if no item selected
  - [ ] Show proposal preview modal/sheet:
    - [ ] Side-by-side: "Your Item" ↔ "Their Item"
    - [ ] Images, titles, conditions
    - [ ] Optional message field
  - [ ] Create offer with selected `offeredTradeId` via API
  - [ ] Show loading state during submission
  - [ ] On success: Add proposal message to chat
  - [ ] On error: Show error message and allow retry

- [ ] **Counter-Offer Mechanism**:
  - [ ] "Make Counter-Offer" button in negotiation (for offer owner)
  - [ ] Button shows when:
    - [ ] User is offer owner (bidder)
    - [ ] Offer is pending or countered
    - [ ] User has available trades
  - [ ] On tap: Open item selection interface
  - [ ] Allow user to select different item for counter-offer
  - [ ] Validate: Can't use same item as original offer (or show warning)
  - [ ] Show counter-offer history/chain:
    - [ ] Visual timeline: Original → Counter 1 → Counter 2
    - [ ] Display version numbers (v1, v2, v3)
    - [ ] Show who made each proposal
  - [ ] Visual distinction:
    - [ ] Different colors for original vs counter-offers
    - [ ] Icons or badges for proposal types
    - [ ] Highlight latest proposal

- [ ] **Proposal Display in Chat**:
  - [ ] Show offered item details in proposal messages
  - [ ] Display item cards for proposals (compact view)
  - [ ] Show "Item A ↔ Item B" format in message
  - [ ] Expandable item cards (tap to see full details)
  - [ ] Allow tapping on proposed items to navigate to details
  - [ ] Highlight latest proposal in conversation
  - [ ] Show proposal version in message header
  - [ ] Display proposal timestamp

- [ ] **Negotiation Status Indicators**:
  - [ ] Status banner at top showing:
    - [ ] Current proposal status (pending, countered, accepted, declined)
    - [ ] Who made the last proposal
    - [ ] Proposal version number
  - [ ] Visual timeline of proposal history:
    - [ ] Chronological list of all proposals
    - [ ] Show item changes between proposals
    - [ ] Highlight current active proposal
  - [ ] Status badges:
    - [ ] "Pending Response" - waiting for other party
    - [ ] "Counter-Offer Received" - new counter available
    - [ ] "Accepted" - trade finalized
    - [ ] "Declined" - offer rejected

- [ ] **Accept/Reject in Negotiation**:
  - [ ] "Accept Offer" button (for trade owner)
  - [ ] Confirmation dialog showing both items
  - [ ] "Reject Offer" button with optional feedback
  - [ ] Handle acceptance: Close both trades, show success
  - [ ] Navigate to trade completion screen after acceptance

#### 10.5 Frontend: Trade Offers Screen Updates

- [ ] **Offers Tab Enhancement**:
  - [ ] Display item offers with offered trade details
  - [ ] Show item cards for offers (not just cash amounts)
  - [ ] Distinguish between item offers and cash offers
  - [ ] Filter options: "Item Offers", "Cash Offers", "All"

- [ ] **Offer Cards**:
  - [ ] Display offered item image, title, condition
  - [ ] Show target item (the trade being offered on)
  - [ ] Display offer status badge
  - [ ] Show offer date and bidder info
  - [ ] "View Details" button to see full offer

- [ ] **Accept/Reject Actions**:
  - [ ] "Accept Offer" button for item offers
  - [ ] Confirmation dialog showing both items
  - [ ] "Reject Offer" button
  - [ ] "Make Counter-Offer" button (navigate to negotiation)
  - [ ] Handle acceptance of item-for-item trades:
    - [ ] Close both trades
    - [ ] Update both trade statuses
    - [ ] Show success message

- [ ] **Offer Details View**:
  - [ ] Full screen or modal showing:
    - [ ] Offered item details
    - [ ] Target item details
    - [ ] Offer message
    - [ ] Negotiation history
    - [ ] Action buttons

#### 10.6 Chat System Integration

- [ ] **Negotiation Chat Integration**:
  - [ ] Ensure negotiation messages appear in Trade chat tab
  - [ ] Link negotiation to Trade module chat system
  - [ ] Show proposal messages as special message types
  - [ ] Display item cards in chat for proposals

- [ ] **Proposal Message Types**:
  - [ ] `PROPOSAL` - Initial offer with item
  - [ ] `COUNTER_OFFER` - Counter-proposal with different item
  - [ ] `ACCEPTANCE` - Offer accepted
  - [ ] `DECLINE` - Offer declined
  - [ ] Render each type with appropriate UI

- [ ] **Chat Context**:
  - [ ] Show both items in chat header
  - [ ] Quick link to view item details from chat
  - [ ] "Make Counter-Offer" button in chat
  - [ ] Proposal history visible in chat

#### 10.7 User Trade Management

- [ ] **My Trades Screen**:
  - [ ] Show user's active trades available for offering
  - [ ] Filter: "Available for Trade", "In Negotiation", "Closed"
  - [ ] Quick actions: "Use in Offer", "Edit", "Delete"
  - [ ] Status indicators for trades used in offers

- [ ] **Trade Status Updates**:
  - [ ] When trade is used in offer, mark as "In Offer"
  - [ ] When offer is accepted, mark trade as "Traded"
  - [ ] When offer is rejected/withdrawn, mark trade as "Available"
  - [ ] Prevent using closed trades in new offers

- [ ] **Trade Validation**:
  - [ ] Only OPEN trades can be offered
  - [ ] User cannot offer trade that's already in an accepted offer
  - [ ] User cannot offer same trade in multiple pending offers (or allow with warning)

#### 10.8 Counter-Offer Flow Implementation

- [ ] **Backend Counter-Offer Logic**:
  - [ ] Create new `TradeOffer` with new `offeredTradeId`
  - [ ] Link counter-offer to original offer:
    - [ ] Option A: Add `parentOfferId` field to `TradeOffer` model
    - [ ] Option B: Use metadata to track offer chain
  - [ ] Track offer chain/version in negotiation messages
  - [ ] Update negotiation status to `COUNTER_OFFERED`
  - [ ] Keep original offer in PENDING or mark as COUNTERED
  - [ ] Return new offer with chain information

- [ ] **Frontend Counter-Offer UI**:
  - [ ] "Make Counter-Offer" button in negotiation screen
  - [ ] Button visibility logic:
    - [ ] Show for trade owner when offer is pending
    - [ ] Show for bidder when counter-offer received
    - [ ] Hide when offer accepted/rejected
  - [ ] Item selection interface for counter-offer:
    - [ ] Show user's available trades
    - [ ] Pre-select current offered item (for easy change)
    - [ ] Allow selecting different item
  - [ ] Show counter-offer history/chain:
    - [ ] List view of all proposals in order
    - [ ] Visual comparison: Original Offer → Counter-Offer 1 → Counter-Offer 2
    - [ ] Show item changes (what changed between versions)
    - [ ] Highlight active/latest proposal
  - [ ] Counter-offer submission:
    - [ ] Create new offer via API
    - [ ] Add counter-offer message to chat
    - [ ] Update UI to show new proposal
    - [ ] Notify other party

- [ ] **Counter-Offer Notifications**:
  - [ ] Backend: Notify original offerer of counter-offer
  - [ ] Frontend: Show counter-offer in offers tab with badge
  - [ ] Highlight new counter-offers in offers list
  - [ ] Push notification: "New counter-offer received"
  - [ ] In-app notification badge on offers tab
  - [ ] Show counter-offer indicator in negotiation screen

#### 10.9 Trade Completion Flow

- [ ] **Item-for-Item Acceptance**:
  - [ ] When offer accepted, close both trades
  - [ ] Mark both trades as "Traded"
  - [ ] Create completion records for both parties
  - [ ] Award karma points to both users
  - [ ] Send notifications to both parties

- [ ] **Trade History**:
  - [ ] Show completed trades in user's trade history
  - [ ] Display both items in completed trade view
  - [ ] Show trade partner information
  - [ ] Allow rating/review of completed trade

- [ ] **Post-Trade Actions**:
  - [ ] "Mark as Received" for both parties
  - [ ] "Rate Trade Partner" functionality
  - [ ] Dispute resolution (if needed)
  - [ ] Trade completion confirmation

#### 10.10 UI/UX Enhancements

- [ ] **Item Comparison View**:
  - [ ] Side-by-side comparison of offered vs requested items
  - [ ] Show images, titles, conditions, descriptions
  - [ ] Value estimation display (if available)
  - [ ] "Fair Trade" indicator (optional)

- [ ] **Visual Indicators**:
  - [ ] Badge for item offers vs cash offers
  - [ ] Status badges: "Pending", "Countered", "Accepted", "Rejected"
  - [ ] Proposal version numbers
  - [ ] "New Counter-Offer" indicators

- [ ] **Empty States**:
  - [ ] "No items to offer" message with "Create Trade" CTA
  - [ ] "No offers yet" message on offers tab
  - [ ] "No counter-offers" message

- [ ] **Loading States**:
  - [ ] Loading indicators when creating offers
  - [ ] Skeleton loaders for offers list
  - [ ] Progress indicators for multi-step flows

#### 10.11 Testing Requirements

- [ ] **Unit Tests**:
  - [ ] Test offer creation with `offeredTradeId`
  - [ ] Test validation (user can't offer own trade, closed trade, etc.)
  - [ ] Test counter-offer creation
  - [ ] Test offer acceptance for item-for-item trades

- [ ] **Integration Tests**:
  - [ ] End-to-end: Create trade → Make offer → Accept offer
  - [ ] Counter-offer flow: Offer → Counter → Accept
  - [ ] Multiple offers scenario
  - [ ] Chat integration with negotiations

- [ ] **Edge Cases**:
  - [ ] User offers trade that gets closed before acceptance
  - [ ] Multiple counter-offers chain
  - [ ] User tries to offer same item in multiple offers
  - [ ] Network failures during offer creation

#### 10.12 Documentation

- [ ] **API Documentation**:
  - [ ] Document new `offeredTradeId` field
  - [ ] Update offer creation endpoint docs
  - [ ] Document counter-offer endpoint
  - [ ] Example requests/responses

- [ ] **User Guide**:
  - [ ] How to make an item-for-item offer
  - [ ] How to make a counter-offer
  - [ ] How to accept/reject offers
  - [ ] Understanding offer statuses

#### 10.13 Migration & Rollout

- [ ] **Database Migration**:
  - [ ] Create migration for `offeredTradeId` field
  - [ ] Test migration on staging
  - [ ] Backup production database before migration
  - [ ] Rollback plan if migration fails

- [ ] **Feature Flag**:
  - [ ] Add feature flag: `ENABLE_ITEM_FOR_ITEM_TRADING`
  - [ ] Default to `true` in dev, `false` in production
  - [ ] Gradual rollout plan

- [ ] **Backward Compatibility**:
  - [ ] Ensure existing cash offers continue to work
  - [ ] Support both item and cash offers simultaneously
  - [ ] Handle offers without `offeredTradeId` (cash offers)
  - [ ] Migration script to handle existing offers (all will be cash offers)

#### 10.14 Implementation Priority & Phases

**Phase 1: Foundation (Week 1-2)**
- Database schema migration (`offeredTradeId` field)
- Backend API updates for item offers
- Basic offer creation with items
- Frontend: "Make Offer" button navigation

**Phase 2: Core Functionality (Week 2-3)**
- Item selection in negotiation screen
- Proposal creation and display
- Offers tab updates for item offers
- Accept/reject item offers

**Phase 3: Counter-Offers (Week 3-4)**
- Backend counter-offer endpoint
- Frontend counter-offer UI
- Offer chain tracking
- Counter-offer notifications

**Phase 4: Polish & Integration (Week 4-5)**
- Chat system integration
- Visual enhancements
- Testing and bug fixes
- Documentation

**Estimated Total Time:** 4-5 weeks for complete implementation

#### 10.15 Key Design Decisions

- [ ] **Hybrid Support**: Support both item-for-item AND cash offers
  - [ ] Users can make cash offers (existing functionality)
  - [ ] Users can make item offers (new functionality)
  - [ ] Trade owners can receive both types of offers
  - [ ] UI clearly distinguishes between offer types

- [ ] **Offer Chain Strategy**: 
  - [ ] Option A: Create new `TradeOffer` for each counter-offer (recommended)
  - [ ] Option B: Update existing offer with new `offeredTradeId`
  - [ ] Decision: Use Option A for clear history tracking

- [ ] **Trade Status Management**:
  - [ ] When trade used in offer: Mark as "IN_OFFER" (optional status)
  - [ ] When offer accepted: Mark as "TRADED" or "CLOSED"
  - [ ] When offer rejected/withdrawn: Return to "OPEN"
  - [ ] Prevent using "IN_OFFER" trades in new offers (or allow with warning)

- [ ] **Negotiation vs Offer Relationship**:
  - [ ] One `Negotiation` per `TradeOffer`
  - [ ] Multiple `TradeOffer` records for counter-offers (each creates new negotiation or links to parent)
  - [ ] All offers for same trade share negotiation context

### 11. Community Features
- [ ] **Geo-fencing Validation** - 20km rule enforcement testing
- [ ] **Community Moderation** - Content moderation tools
- [ ] **Event Management** - Community events CRUD operations
- [ ] **Community Analytics** - Engagement metrics

---

## 📋 MEDIUM PRIORITY - Nice to Have

### 11. Documentation
- [ ] **API Documentation** - OpenAPI/Swagger documentation
- [ ] **Admin Guide** - Complete admin dashboard documentation
- [ ] **User Guide** - In-app help or external documentation
- [ ] **Developer Documentation** - Setup guides, architecture docs
- [ ] **Deployment Guide** - Production deployment procedures
- [ ] **Troubleshooting Guide** - Common issues and solutions

### 12. Performance & Scalability
- [ ] **Caching Strategy** - Redis caching for frequently accessed data
- [ ] **CDN Configuration** - Static asset delivery optimization
- [ ] **Image Optimization** - Compression, lazy loading, responsive images
- [ ] **Database Query Optimization** - Slow query identification and fixing
- [ ] **Load Balancing** - Multi-instance deployment strategy
- [ ] **Auto-scaling** - Horizontal scaling configuration

### 13. CI/CD Pipeline
- [ ] **Automated Testing** - GitHub Actions for test execution
- [ ] **Automated Deployment** - Railway/cloud deployment automation
- [ ] **Environment Management** - Dev, staging, production environments
- [ ] **Rollback Strategy** - Quick rollback procedures
- [ ] **Migration Automation** - Automated Prisma migrations on deploy

### 14. User Experience
- [ ] **Onboarding Flow** - First-time user experience
- [ ] **Tutorial/Help System** - In-app guidance
- [ ] **Accessibility** - Screen reader support, keyboard navigation
- [ ] **Internationalization** - Multi-language support (if needed)
- [ ] **Offline Support** - Basic offline functionality

### 15. Admin Dashboard
- [ ] **User Management** - Advanced user search and filtering
- [ ] **Content Moderation** - Bulk actions, automated moderation
- [ ] **Analytics Dashboard** - Usage statistics, revenue metrics
- [ ] **Audit Logs** - Comprehensive audit trail viewing
- [ ] **System Health** - Real-time system status monitoring

---

## 🔧 TECHNICAL DEBT

### 16. Code Quality
- [ ] **TODO Items** - 580+ TODO/FIXME comments found across codebase
- [ ] **Code Review** - Comprehensive code review for all modules
- [ ] **Refactoring** - Clean up deprecated code, optimize structure
- [ ] **Type Safety** - Ensure strict TypeScript/Dart typing
- [ ] **Linting** - Fix all linting warnings and errors

### 17. Dependencies
- [ ] **Dependency Audit** - Security audit of all npm/pub dependencies
- [ ] **Version Updates** - Update outdated dependencies
- [ ] **Vulnerability Scanning** - Regular security scans

### 18. Configuration
- [ ] **Environment Files** - Create `.env.example` files for all services
- [ ] **Configuration Validation** - Startup validation of required env vars
- [ ] **Secrets Management** - Proper secrets management (not in code)

---

## 📊 PRODUCTION DEPLOYMENT CHECKLIST

### Pre-Deployment
- [ ] All critical items above completed
- [ ] Database migrations tested and ready
- [ ] Environment variables configured
- [ ] SSL certificates installed
- [ ] Domain names configured
- [ ] DNS records set up
- [ ] Backup strategy implemented
- [ ] Monitoring tools configured
- [ ] Error tracking enabled
- [ ] Load testing completed

### Deployment
- [ ] Deploy to staging environment
- [ ] Run smoke tests
- [ ] Deploy to production
- [ ] Monitor error rates
- [ ] Monitor performance metrics
- [ ] Verify all services running
- [ ] Test critical user flows

### Post-Deployment
- [ ] Monitor for 24-48 hours
- [ ] Collect user feedback
- [ ] Track error rates
- [ ] Monitor performance
- [ ] Review logs for issues
- [ ] Plan hotfixes if needed

---

## 📈 METRICS TO TRACK

### Technical Metrics
- API response times (P50, P95, P99)
- Error rates (<5% target)
- Database query performance
- Memory and CPU usage
- Network latency
- Uptime percentage

### Business Metrics
- User registration rate
- Active users (DAU/MAU)
- Transaction volume
- Completion rates
- User retention
- Feature adoption rates

---

## 🎯 ESTIMATED TIME TO PRODUCTION

### Critical Path Items: 3-4 weeks
- Testing & QA: 1 week
- Wallet system completion: 1-2 weeks
- Security hardening: 3-5 days
- Error handling & monitoring: 2-3 days
- Database setup: 1-2 days

### High Priority Items: 2-3 weeks
- Offer/Ask flow polish: 3-5 days
- Donations features: 1 week
- User features: 3-5 days
- Wallet features: 3-5 days

### Total Estimated Time: 5-7 weeks to full production readiness

---

## 🚀 QUICK WINS (Can be done in 1-2 days)

1. Add `/health` endpoint
2. Create `.env.example` files
3. Update chat header with item context
4. Add completion status badges
5. Implement basic analytics events
6. Add error boundaries
7. Create deployment documentation
8. Set up basic monitoring

---

## 📝 NOTES

### Wallet System Architecture
- **BYC Coin** is the sole internal currency for all app transactions
- **Payment Gateways** (Stripe, PayPal, Paystack) are ONLY used for wallet funding
- **Conversion Rates** are admin-controlled (BYC ↔ NGN, BYC ↔ USD)
- **All Transactions** use BYC: donations, trades, transfers, promotions, ads
- **No External Gateways** during transactions - all handled internally with BYC

### Offer/Ask Flow Completion System Architecture
- **Module-Isolated Chat System** - Reusable chat component with complete isolation between modules
- **Four Module Types**: Trade, Gift, Donation, Community - each with dedicated chat environment
- **Isolation Enforcement**: Conversations from one module never appear in another module's chat
- **Context Preservation**: Module-specific metadata, UI elements, and features per module
- **Shared Infrastructure**: Backend services and core UI components are reusable across modules
- **Module-Specific Features**: Each module has tailored chat features (proposals for Trade, claims for Gift, etc.)

### Current Status
- Core features implemented (~85%), but production infrastructure needs work
- Biggest Gaps: Testing coverage, wallet system completion, monitoring/alerting
- Risk Level: Medium - Core functionality works, but needs hardening for scale
- Recommended Approach: Phased rollout starting with beta users

### Wallet System Priority
- Payment gateway integration is critical for user onboarding
- BYC transaction system must be fully functional before launch
- Conversion rate management needed for admin control
- Fraud detection essential for financial operations

---

**Last Updated:** December 2024  
**Next Review:** After critical items completion

