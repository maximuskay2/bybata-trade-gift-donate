# BYBATA — Product & Marketing Handoff

**Document purpose:** Full repository overview for marketing, brand, growth, and launch teams.  
**Version:** 1.0 · **App version:** 1.0.0+1 · **Last updated:** June 2026  
**Website:** [https://bybata.com](https://bybata.com) · **Support:** info@bybata.com · **Phone:** 08036954577

---

## Executive Summary

**BYBATA** (also styled *bYbata* / *BYBATA*) is a **community-powered sharing economy mobile platform** where people **trade without cash**, **give gifts freely**, and **crowdfund personal and business needs** — all while building **KARMA** (trust reputation) and using **BYC** (bYbata Coin) for in-app value.

Unlike a traditional buy/sell marketplace, BYBATA is built around **local barter, kindness, and mutual support**. The product positions itself as: *local, trust-based, kindness-forward* — with the emotional hook **“You Are Not Alone.”**

### Primary taglines (approved in-app copy)

| Context | Copy |
|--------|------|
| **Splash / hero** | **Trade. Gift. Donate and Grow Together.** |
| **App tagline** | Trade, Gift, Donate — Making the World Better! |
| **Mission** | Building communities for a better world through sharing |
| **Conversational home (guest)** | Trade, Donate or Gift |
| **Conversational home (member)** | Will you Trade, Donate or Gift, {firstName}? |

### Elevator pitch (draft for campaigns)

> **BYBATA** is where neighbors trade without cash, gift freely, and fund each other’s dreams — while earning **KARMA** you can trust. Browse locally, chat to negotiate, and grow together.

---

## The Three Pillars

BYBATA is not one feature — it is **three interconnected community actions** in a single app:

```
┌─────────────────────────────────────────────────────────────┐
│                        BYBATA                               │
├──────────────┬──────────────────┬───────────────────────────┤
│    TRADE     │       GIFT       │         DONATE            │
│  Swap items  │  Give for free   │  Crowdfund campaigns      │
│  No cash     │  Earn KARMA      │  Reward tiers             │
│  Negotiate   │  Gift chains     │  Community support        │
└──────────────┴──────────────────┴───────────────────────────┘
         │              │                    │
         └──────────────┴────────────────────┘
                    KARMA + BYC
              (Trust + In-app currency)
```

---

## Target Audience & Positioning

### Who it’s for

- **Neighbors and local communities** who want to exchange value without always using cash
- **Generous givers** who want to pass items on and be recognized (KARMA)
- **People raising funds** for personal, creative, or small-business needs
- **Trust-conscious users** who care about reputation, verification, and safe exchanges
- **Africa-first + global** users (Paystack, Flutterwave alongside Stripe/PayPal for wallet funding)

### Positioning vs typical apps

| Typical marketplace | BYBATA |
|--------------------|--------|
| Buy/sell with money | **Barter / swap** as the core trade model |
| Single purpose (eBay, OfferUp) | **Trade + Gift + Donate** in one ecosystem |
| Star ratings only | **KARMA tiers** (Newcomer → Legend) + verification |
| Generic chat | **Context-native chat** tied to trade/gift/campaign |
| Account required to browse | **Guest browse** — sign in only when acting |
| Ads as interruption | **BYC-funded promotions** inside the wallet ecosystem |

---

## Onboarding Story (Marketing-Ready Slides)

The app ships a **4-slide onboarding** sequence. Use this narrative in ads, landing pages, and social:

1. **Trade Without Cash** — Swap items securely and locally  
2. **Spread Kindness** — Give to neighbors, earn KARMA  
3. **Power Your Dreams** — Community-funded campaigns  
4. **You Are Not Alone** — Request help, chat, grow together  

After onboarding, guests land on the **conversational browse home**; members land in the full **authenticated hub**.

---

## Core Product Modules

### 1. Trade (Barter Hub)

**What it is:** A local barter marketplace — list items, browse offers, negotiate swaps.

**User benefits:**
- Create and manage trade listings with photos, condition, location, estimated value
- Browse active trades by category and proximity
- **Make offers** and **negotiate** in dedicated threads
- Trade-context **chat** with the listing owner
- **Boost visibility** with BYC promotions
- Earn **+50 KARMA** on completed trades

**Marketing angles:** “Swap what you have for what you need.” “No cash, no problem.” “Meet locally, trade safely.”

---

### 2. Gift (Kindness Hub)

**What it is:** Free giving — pass items, skills, or experiences to others.

**Gift types:** Random · Targeted · Skill · Experience · Digital

**User benefits:**
- Browse available gifts near you
- Request / claim gifts with approval flow
- Gift history and “pay it forward” chains
- Filters: expiring soon, chain gifts, surprise gifts
- Earn **+30 KARMA** for giving

**Marketing angles:** “Pass it on.” “Kindness counts.” “Your clutter could change someone’s week.”

---

### 3. Donate / Campaigns (Support Hub)

**What it is:** Crowdfunding for personal and business needs with optional **reward tiers**.

**User benefits:**
- Browse active campaigns with progress, story, and deadline
- Donate via wallet (BYC)
- Create and manage your own campaigns
- Donation history
- Reward tiers (minimum donation, limited quantity perks)
- Earn **+40 KARMA** per donation

**Marketing angles:** “Fund dreams together.” “Small gifts, big impact.” “Transparent progress, real stories.”

---

### 4. Wallet & BYC (bYbata Coin)

**What it is:** In-app currency for funding, transfers, promotions, and withdrawals.

**User benefits:**
- View balance and transaction history
- **Fund wallet** via Paystack, Stripe, PayPal, Flutterwave
- **Funding packages** with bonus % on larger packs (admin-configurable)
- Send/receive BYC (including QR)
- Withdrawal requests
- PIN + biometric wallet security
- **Promotion Center** — boost listings with BYC

**Marketing angles:** “Power your promotions.” “One wallet for trade, gift, and give.”

---

### 5. KARMA (Trust & Reputation)

**What it is:** Community reputation system — not just points, but **trust tiers** that unlock credibility.

**Trust tiers:** Newcomer → Bronze → Silver → Gold → Platinum → Diamond → **Legend**

**User benefits:**
- KARMA dashboard with points and history
- Achievements and leaderboard
- Trust level visualization
- **Earn KARMA guide** (live, API-driven ways to earn)
- Statistics and activity history
- **+100 KARMA** welcome bonus · **+100** verification bonus

**Default earn values (in-app constants):**

| Action | KARMA |
|--------|-------|
| Complete trade | +50 |
| Give a gift | +30 |
| Make a donation | +40 |
| Community post | +10 |
| Help community member | +20 |
| Account verification | +100 |
| New user starting balance | 100 |

**Marketing angles:** “Trust you can see.” “Reputation that rewards kindness.” “Level up your community standing.”

---

### 6. Chat & Messaging

**What it is:** Real-time messaging tied to listings and direct conversations.

**Features:**
- Trade, Gift, Donation, and Direct chat types
- Module-colored UI (blue trade, purple gift, green donation)
- Text, images, documents, **voice notes**
- Reactions, quoted replies, typing indicators
- Socket.io real-time delivery

**Marketing angles:** “Negotiate in context.” “Coordinate pickup without leaving the app.”

---

### 7. Search & Discovery

**What it is:** Full-text search across trades, gifts, campaigns, communities, and users.

**Features:**
- Category filters, recent searches, trending, suggestions
- Modern filter UI (bottom sheet)
- Geo/nearby discovery on supported flows
- Entry via side drawer, conversational home (“discover”, “search”, “find”)

---

### 8. Profile & Identity

**User benefits:**
- Public profile with `@username` deep links
- Edit profile, bio, avatar, **location**
- Verification badge (after admin review)
- Followers / following
- Activity stats (trades, gifts, donations, BYC, KARMA)
- Share profile · referral card
- User reports and appeals (trust & safety)

---

### 9. Referrals

**Share card:** “Invite Friends & Earn” — code, link, QR, copy/share

**Default reward structure (configurable via backend/env):**

| Event | Referrer reward (typical) |
|-------|---------------------------|
| Friend signs up | 1 KARMA + 0.1 BYC |
| Friend’s first trade | 1 KARMA + 0.1 BYC |
| Friend’s first donation | 1 KARMA + 0.1 BYC |
| Friend’s first gift | 1 KARMA + 0.1 BYC |

**Invite URL format:** `https://bybata.com/invite/{code}`

**Marketing angles:** “Grow the circle.” “Invite kindness.” “Earn when friends join the movement.”

---

### 10. Notifications

- **Push:** Firebase Cloud Messaging + local notifications
- **In-app:** Filtered notification center (trades, campaigns, achievements, etc.)
- **Per-type preferences** in settings
- **Admin broadcast** with delivery logs
- Deep links from notification tap → relevant screen

---

### 11. Help & Support (Members)

Four-tab support hub (sign-in required):
1. **FAQ** — searchable, API-driven  
2. **Contact** — email, phone, contact cards  
3. **Chat** — live support chat  
4. **Tickets** — create and track support tickets  

---

## The New Home Experience (Home V2)

BYBATA’s default home is **conversational and intent-driven** — inspired by modern AI command interfaces, but routing to real app actions.

### Guest home (`BrowseHomeScreenV2`)
- Purple gradient ambient background
- Centered greeting: **“Trade, Donate or Gift”**
- **Command input pill** at bottom — type natural language
- **Intent suggestions** appear as you type (trade, gift, wallet, karma, settings, etc.)
- Top bar: menu · Bybata chip · **Sign In**
- **No account required** to browse listings

### Member home (`HomeScreenV2`)
- Same conversational body inside main navigation
- Personalized greeting with first name
- Full bottom nav: Home · Wallet · **Create (+)** · Chat · Profile

### Conversational intent examples (live in app)

| User types | Suggested destination |
|-----------|-------------------------|
| trade, swap, barter | Trade Center / Create Trade |
| gift, free, give | Gift Center / Give a Gift |
| donate, campaign | Donations / Create Campaign |
| wallet, balance, BYC | Wallet / Fund Wallet |
| karma, leaderboard | KARMA Hub / Earn KARMA |
| settings, privacy | Settings |
| ads, boost, promotion | Promotion Center |
| search, discover | Search Bybata |
| help, support | Help & Support (sign-in required) |

**Marketing angle:** “Tell BYBATA what you want to do.” “One search bar for your whole community life.”

---

## Guest vs Member Experience

| Capability | Guest (browse) | Member (signed in) |
|-----------|----------------|---------------------|
| Browse trades, gifts, campaigns | ✅ | ✅ |
| View listing details (limited) | ✅ | ✅ |
| Create listings / donate / trade / claim | ❌ → Sign-in modal | ✅ |
| View member profiles | ❌ | ✅ |
| Message / comment / follow / like | ❌ | ✅ |
| Wallet, chat, notifications | ❌ | ✅ |
| Help & Support (FAQ/tickets) | ❌ | ✅ |

**Sign-in modal (redesigned):** Branded frosted card with gradient header, **Sign In**, **Create free account**, and **Continue browsing**.

**Auth methods:** Email/password · Google · Apple · Forgot/reset password · Email verification

---

## Monetization & Growth Levers

| Mechanism | Description | Admin control |
|-----------|-------------|---------------|
| **Feed ads** | Sponsored placements in feeds | Ad placements, ads review |
| **Listing boosts** | Pay BYC to promote trade/gift/campaign | Boost types, boost config |
| **Funding packages** | Buy BYC bundles with bonus % | Funding packages CRUD |
| **Wallet promotions** | BYC-priced visibility campaigns | Promotions page |
| **Referral loop** | KARMA + BYC on signup and first actions | Referrals dashboard |

**Payment rails:** Paystack (Africa) · Stripe · PayPal · Flutterwave

---

## Trust & Safety (Marketing Trust Signals)

| Feature | User-facing benefit |
|---------|---------------------|
| **Identity verification** | Verified badge on profile and listings |
| **KARMA tiers** | See who is established in the community |
| **User reports** | Flag bad actors |
| **Appeals** | Fair process if action taken |
| **Chat moderation** | Platform oversight |
| **Wallet PIN / biometrics** | Secure funds |
| **Guest-safe browsing** | Explore before committing data |

**FAQ covers:** Safe meetups, disputes, reporting, verification steps.

---

## Brand & Design System

### Colors

| Token | Hex | Usage |
|-------|-----|--------|
| **Primary purple** | `#7E57C2` | Brand, buttons, accents |
| **Launch purple** | `#5E35B1` | Splash, home chrome, native handoff |
| **Trade** | `#2563EB` | Trade module, chat bubbles |
| **Gift** | `#9333EA` | Gift module |
| **Donation** | `#059669` | Campaign module |
| **KARMA** | `#F59E0B` | Reputation, rewards |
| **Light background** | `#FAFAFA` | Default light mode |
| **Dark background** | `#0D0B12` / `#121212` | Dark mode |

### UI patterns

- **Glass surfaces** — frosted blur on cards and chrome (user-toggleable glass mode)
- **3D listing cards** — portrait ratio, shadow depth, module color accents
- **BYBATA loading indicator** — animated letter-wave spinner (app-wide)
- **Sign-in modal** — gradient header, purple CTA, modern card
- **Conversational home** — Gemini-style gradient + command pill
- **Module-colored chat** — instant context (trade vs gift vs donation)

### Typography

- Mobile: Material system fonts
- Web/legal: Plus Jakarta Sans (`terms.html`, `privacy.html`)

### Brand iconography

- Sparkle / auto-awesome motif on conversational greeting
- Lock-open icon on sign-in prompt
- Module-specific icons per hub (swap, gift, volunteer activism, wallet, karma star)

---

## Platform & Technical Stack (For Marketing Ops)

| Layer | Technology |
|-------|------------|
| **Mobile app** | Flutter (iOS + Android), v1.0.0+1 |
| **iOS bundle** | `com.bybata.bybata` |
| **Backend API** | NestJS + Prisma (PostgreSQL) |
| **Admin dashboard** | Next.js 16 (Turbopack) |
| **Real-time** | Socket.io |
| **Push** | Firebase Cloud Messaging |
| **Crash reporting** | Firebase Crashlytics |
| **Deep links** | `bybata://` + `https://bybata.com/...` |
| **Production API** | `https://bybataapi-production.up.railway.app` |

### Share & deep link paths (bybata.com)

| Path | Opens |
|------|--------|
| `/trade/{id}` | Trade detail |
| `/gift/{id}` | Gift detail |
| `/campaign/{id}` | Campaign detail |
| `/profile/{id}` | User profile |
| `/invite/{code}` | Referral signup |
| `/open-app` | Email / web fallback |

Deploy guide: `DOCSS/bybata-website-files/HOSTINGER_DEPLOY.md`

---

## Admin Dashboard (Operator Capabilities)

Marketing and ops teams should know the platform is **fully operable** from the admin panel:

| Area | Capabilities |
|------|--------------|
| **Dashboard** | Users, trades, transactions, system health |
| **Platform** | Users, referrals, verification queue, trades, negotiations, gifts, donations, communities, reports, appeals, support tickets |
| **Finance** | Wallet oversight, withdrawals, exchange rates, funding packages |
| **Marketing** | Ads, boost config, boost types, ad placements, ads review |
| **Features** | KARMA system config, chat moderation |
| **System** | Status page, push broadcasts, email settings, maps, gateways |

---

## User Journey Map (Simplified)

```
Install → Animated splash ("Trade. Gift. Donate and Grow Together")
    → Onboarding (4 slides)
    → Guest browse home OR Sign in
         → Browse trades / gifts / campaigns
         → Tap action → Branded sign-in modal
    → Register / Login (Google, Apple, email)
    → Email verification
    → Main navigation home
         → Create (+): Post Trade | Give Gift | Start Campaign
         → Wallet: fund, send, promote
         → KARMA: earn, leaderboard, achievements
         → Chat: negotiate & coordinate
         → Profile: verify, refer, share
```

---

## Campaign Ideas (Ready to Execute)

### Launch themes
1. **“Trade Without Cash”** — barter-first, local swap stories  
2. **“Pass It On”** — gift chains, free giving, KARMA rewards  
3. **“Fund Together”** — campaign spotlights, reward tiers  
4. **“Trust You Can See”** — KARMA tiers + verification  
5. **“You Are Not Alone”** — emotional community support angle  

### Channel-specific hooks

| Channel | Hook |
|---------|------|
| **Instagram/TikTok** | Before/after swap stories; gift reveal; campaign progress |
| **Twitter/X** | “What would you trade?” polls; KARMA leaderboard highlights |
| **Email** | Referral invite; welcome +100 KARMA; first trade prompt |
| **Influencer** | Local barter challenges; 7-day kindness gift chain |
| **PR** | “Anti-loneliness economy” / sharing economy for Gen Z & millennials |

### Sample ad copy

- **Headline:** Trade. Gift. Donate. Grow together.  
- **Body:** BYBATA is the app where your community swaps, gives, and funds dreams — no cash required for trades. Earn KARMA. Build trust.  
- **CTA:** Download free · Browse before you join  

---

## Honest Roadmap / Caveats (Do Not Over-Promise)

| Feature | Status | Marketing guidance |
|---------|--------|-------------------|
| **Communities (mobile UI)** | Coming Soon | Backend + admin exist; mobile shows placeholder |
| **Ask for Help / Create Request** | Coming Soon | Listed in create sheet but not live |
| **Earn BYC opportunities screen** | Placeholder | Wallet earn tab TBD |
| **Android package ID** | `com.example.bybata` | Update before Play Store launch |
| **Share links on bybata.com** | Requires deploy | See `DOCSS/bybata-website-files/` |

Always verify feature status with product before external campaigns.

---

## Key Assets & File Locations

| Asset / copy source | Location |
|--------------------|----------|
| App name, tagline, KARMA values | `lib/core/constants/app_constants.dart` |
| Splash animation & tagline | `lib/screens/splash/animated_splash_screen.dart` |
| Onboarding slides | `lib/features/onboarding/onboarding_screen.dart` |
| Conversational home | `lib/features/home_v2/conversational/` |
| Sign-in modal | `lib/core/widgets/sign_in_required_dialog.dart` |
| BYBATA loader | `lib/core/widgets/bybata_loading_indicator.dart` |
| Web terms & privacy | `DOCSS/bybata-website-files/terms.html`, `privacy.html` |
| Deep link deploy | `DOCSS/bybata-website-files/README.md` |
| Admin nav (feature list) | `apps/admin/app/components/sidebar.tsx` |
| FAQ seed content | `apps/api/src/support/support.service.ts` |

---

## Contacts & Links

| Item | Value |
|------|--------|
| **Website** | https://bybata.com |
| **Support email** | info@bybata.com |
| **Support phone** | 08036954577 |
| **App deep link** | bybata:// |
| **Invite link** | https://bybata.com/invite/{code} |

---

## Appendix: Repository Structure (High Level)

```
bybataRailway/
├── lib/                    # Flutter mobile app (primary product)
│   ├── features/
│   │   ├── home_v2/        # Conversational home, discover
│   │   ├── trade/          # Barter hub
│   │   ├── gifting/        # Gift hub
│   │   ├── donations/      # Campaign hub
│   │   ├── wallet/         # BYC, promotions, funding
│   │   ├── karma/          # Reputation system
│   │   ├── chat/           # Messaging
│   │   ├── profile/        # Identity, verification
│   │   ├── settings/       # Help & support, preferences
│   │   └── ...
│   └── core/               # Theme, navigation, widgets
├── apps/api/               # NestJS backend
├── apps/admin/             # Next.js admin dashboard
├── DOCSS/                  # Website files, legal, this document
└── assets/                 # Images, icons, animations
```

---

*This document reflects the codebase as of June 2026. For feature-status confirmation before launch campaigns, sync with engineering on the items listed in **Honest Roadmap / Caveats**.*
