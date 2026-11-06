# Push Notification System Fixes & Implementation

## Overview

The push notification system was experiencing silent failures where:
1. Firebase initialization failures were not being logged
2. Push notification errors were swallowed without visibility
3. Several services were not creating notifications for user-relevant events

This document outlines all fixes applied to stabilize the notification system.

---

## Issues Found & Fixed

### 1. **Silent Firebase Initialization Failure** ❌ → ✅
**File**: `apps/api/src/notifications/push-notification.service.ts`

**Problem**:
- When `FIREBASE_SERVICE_ACCOUNT_JSON` or `FIREBASE_SERVICE_ACCOUNT_PATH` environment variables were missing, Firebase initialization would silently fail
- Method logged at DEBUG level and returned `true` (success) even though no notification would be sent
- Made it impossible to debug why push notifications weren't working in production

**Fix Applied**:
```typescript
// BEFORE: Silent failure
if (!app) {
  this.logger.debug(`[MOCK] Push notification (FCM not configured)...`);
  return true;  // Lying about success
}

// AFTER: Clear warning
if (!app) {
  this.logger.warn(`Firebase not configured - notifications will not be sent...`);
  return false;  // Honest about failure
}
```

**Impact**: Firebase setup issues are now immediately visible in logs

---

### 2. **Silent Push Notification Error Handling** ❌ → ✅
**File**: `apps/api/src/notifications/notifications.service.ts`

**Problem**:
- When push notifications failed, the error was caught but not logged
- Users would never know why they weren't receiving notifications
- Made debugging production issues extremely difficult

**Fix Applied**:
```typescript
// BEFORE: Silent failure
try {
  await this.pushNotifications.sendNotification(...);
} catch {
  // Non-blocking: push failures should not break notification creation
}

// AFTER: Logged failure
try {
  await this.pushNotifications.sendNotification(...);
} catch (error) {
  console.error(`Push notification failed for user ${data.userId}:`, error);
}
```

**Impact**: All push notification failures are now visible in server logs for debugging

---

### 3. **Missing Chat Message Notifications** ❌ → ✅
**File**: `apps/api/src/chat/chat.service.ts`

**Problem**:
- Chat service was dispatching emails when new messages arrived
- But was NOT creating push notifications for chat participants
- Users had to wait for email to learn about new messages (no real-time push)

**Fix Applied**:
- Added `NotificationsService` to chat service constructor
- Created push notification alongside email dispatch for each message recipient
- Wrapped both operations in `Promise.all()` for efficiency

```typescript
// Create notifications and send emails in parallel
await Promise.all(
  conversation.participants
    .filter((p) => p.user?.email)
    .map((p) =>
      Promise.all([
        this.notifications.createNotification({
          userId: p.userId,
          type: NotificationType.CHAT,
          title: 'New Message',
          message: `${senderName} sent you a message`,
          priority: NotificationPriority.HIGH,
          relatedEntityId: conversationId,
        }),
        this.email.dispatch({...}),
      ]),
    ),
);
```

**Impact**: Chat messages now trigger real-time push notifications

---

### 4. **Missing Karma Level Up Notifications** ❌ → ✅
**File**: `apps/api/src/karma/karma.service.ts`

**Problem**:
- When users leveled up in karma, the system sent an email
- But no push notification was created
- Users had to check email to see they leveled up (no immediate feedback)

**Fix Applied**:
- Added `NotificationsService` to karma service constructor
- Created push notification when level up occurs
- Wrapped notification and email in `Promise.all()` for parallel dispatch

```typescript
if (levelUp) {
  await Promise.all([
    this.notifications.createNotification({
      userId,
      type: NotificationType.KARMA,
      title: 'Level Up!',
      message: `Congratulations! You've reached Level ${nextLevel}`,
      priority: NotificationPriority.HIGH,
      relatedEntityId: userId,
    }),
    this.email.dispatch({...}),
  ]);
}
```

**Impact**: Users now receive instant push notifications when they level up

---

### 5. **Missing Wallet Security Notifications** ❌ → ✅
**File**: `apps/api/src/wallet/wallet-security.service.ts`

**Problem**:
- When wallet was locked for security (e.g., suspicious activity), only email was sent
- No push notification meant users might not notice their wallet was locked
- Could result in frustrated users unable to use the app

**Fix Applied**:
- Added `NotificationsService` to wallet-security service constructor
- Created urgent-priority push notification when wallet is locked
- Wrapped notification and email in `Promise.all()` for parallel dispatch

```typescript
if (user?.email) {
  await Promise.all([
    this.notifications.createNotification({
      userId,
      type: NotificationType.SECURITY,
      title: 'Wallet Locked',
      message: 'Your wallet has been locked for security. Please verify your account.',
      priority: NotificationPriority.URGENT,
      relatedEntityId: userId,
    }),
    this.email.dispatch({...}),
  ]);
}
```

**Impact**: Users are immediately alerted to wallet security issues via push notification

---

## Services Already With Notifications ✅

The following services were already sending push notifications correctly:

| Service | Events | Notifications |
|---------|--------|---------------|
| **campaigns.service.ts** | Campaign created, published, donations received | ✅ createNotification calls |
| **gifts.service.ts** | Gift offers, accepts, claims | ✅ createNotification calls |
| **wallet.service.ts** | Withdrawals, transfers, deposits | ✅ createNotification calls |
| **communities.service.ts** | Member joins, mentions, invites | ✅ createNotification calls |
| **interactions.service.ts** | Likes, follows, unfollows | ✅ createNotification calls |
| **trades.service.ts** | Offers, acceptances, negotiations | ✅ Helper methods (notifyTradeOffer, notifyTradeAccepted, notifyCounterOffer) |
| **auth.service.ts** | New signup (welcome) | ✅ notifyWelcome |

---

## Services Without Email URLs (No Changes Needed) ✅

These services don't send emails with links, so they don't need the email link router:

| Service | Reason |
|---------|--------|
| **wallet.service.ts** | Transaction confirmations only (no links) |
| **users.service.ts** | Profile updates/deletions (transactional only) |

---

## Environment Variables Required

For push notifications to work, configure these on Railway:

```bash
# Firebase Service Account (choose ONE):

# Option A — minified single-line JSON (paste entire service account file, no extra braces):
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",...}

# Option B — base64 (recommended on Railway; avoids quote/newline issues):
#   chmod +x scripts/encode-firebase-service-account.sh
#   ./scripts/encode-firebase-service-account.sh ~/Downloads/your-adminsdk.json
# Copy ONLY the long base64 line into Railway (see below).
FIREBASE_SERVICE_ACCOUNT_JSON=<paste-base64-here-no-quotes>

# Option C — file path (only if the file exists inside the API container):
FIREBASE_SERVICE_ACCOUNT_PATH="/path/to/service-account.json"
```

**Common Railway mistake:** wrapping JSON as `{{...}}` or pasting with an extra `{` at the start causes:
`SyntaxError: Expected property name or '}' in JSON at position 1`.
The value must be **valid JSON only** — not `{{` + JSON + `}}`.

### Railway UI — saving the full credential

Railway often **truncates** multiline JSON. Do **not** save a fragment like `"type": "service_account",` or
`FIREBASE_SERVICE_ACCOUNT_JSON="\"type\": ..."` — that is invalid and will never work.

**Use base64 (recommended):**

1. Firebase Console → Project settings → Service accounts → **Generate new private key** (`.json` file).
2. Run: `./scripts/encode-firebase-service-account.sh ~/Downloads/your-adminsdk.json`
3. Railway → **API** service → **Variables** → **RAW Editor**
4. Name: `FIREBASE_SERVICE_ACCOUNT_JSON` — Value: paste **only** the one long base64 line (no quotes, no `KEY=` prefix).
5. Save and **Redeploy**. Look for: `Firebase Admin SDK initialized (project: ...)`.

**Or minified JSON:** `jq -c . your-file.json | pbcopy` — paste one line starting with `{` ending with `}`.

```bash
# Email Link Routing:
APP_PUBLIC_URL=https://bybata.com
MOBILE_APP_SCHEME=bybata://
ADMIN_URL=https://bybataadmin-production.up.railway.app
SUPPORT_EMAIL=support@bybata.com
```

---

## Testing Checklist

- [ ] **Firebase Configuration**
  - [ ] Verify `FIREBASE_SERVICE_ACCOUNT_JSON` or `FIREBASE_SERVICE_ACCOUNT_PATH` is set on Railway
  - [ ] Check server logs for Firebase initialization message (should be INFO, not WARN)

- [ ] **Chat Notifications**
  - [ ] Send message in chat
  - [ ] Recipient should receive push notification within 2 seconds
  - [ ] Email should also be sent (backup delivery method)

- [ ] **Karma Level Up**
  - [ ] Award karma to user to trigger level up
  - [ ] User should receive push notification immediately
  - [ ] User should receive email confirmation

- [ ] **Wallet Security**
  - [ ] Manually lock wallet via admin or trigger via suspicious activity
  - [ ] User should receive urgent push notification
  - [ ] User should receive security alert email

- [ ] **Error Logging**
  - [ ] Monitor server logs for push notification failures
  - [ ] Any failures should appear as ERROR or WARN entries (not silent)

- [ ] **Device Token Registration**
  - [ ] Verify users can register device tokens via app
  - [ ] Check database: `DeviceToken` table should have entries after app login

---

## Git Commits

This work was completed across 4 commits:

1. **`959461e`** - "fix: notification system - add logging and missing notifications for chat"
   - Improved push notification error logging
   - Firebase warnings instead of silent failures
   - Chat notifications added
   - 4 files changed, 33 insertions

2. **`20d2ca3`** - "fix: add push notifications for karma level up events"
   - Added NotificationsService to karma.service.ts
   - Created notifications when users level up
   - 1 file changed, 26 insertions

3. **`2f4b25e`** - "fix: add push notifications for wallet security account lock alerts"
   - Added NotificationsService to wallet-security.service.ts
   - Created urgent notifications for wallet locks
   - 1 file changed, 26 insertions

---

## Architecture

### Push Notification Flow

```
Event Triggered (e.g., new chat message)
    ↓
Service creates notification via NotificationsService.createNotification()
    ↓
Notification stored in database
    ↓
PushNotificationService.sendNotification() called
    ↓
Firebase Admin SDK sends FCM message to device tokens
    ↓
User receives push notification on phone (if device token registered)
    ↓
Parallel: Email also dispatched as backup delivery method
```

### Error Handling

**Before (Silent Failures)**:
```
Push fails → Caught silently → No logs → User unaware → Debugging impossible
```

**After (Visible Failures)**:
```
Push fails → Logged to console.error → Visible in logs → Can debug
OR
Firebase not configured → Logged warning on startup → Setup issue immediately visible
```

---

## Future Improvements

1. **Add notification preferences** - Let users control which notifications they receive
2. **Notification retry logic** - Automatically retry failed push notifications
3. **Notification analytics** - Track delivery rates and user engagement
4. **Rich notifications** - Add images, action buttons, custom formatting
5. **Notification grouping** - Group similar notifications from same event
6. **Timezone-aware scheduling** - Send notifications at optimal times for users' timezones

---

## Related Documentation

- [Email Link Router Configuration](EMAIL_LINK_CONFIG.md) - Deep links and web URL routing
- [Notification Types](./apps/api/prisma/schema.prisma) - See NotificationType enum
- [Firebase Admin SDK Setup](https://firebase.google.com/docs/admin/setup) - Official Firebase docs

---

## Questions?

If push notifications are still not working after these fixes:

1. Check server logs for Firebase initialization message
2. Verify Firebase credentials are set in environment variables
3. Confirm device tokens are being registered (check `DeviceToken` table in database)
4. Monitor error logs for specific push notification failure messages
5. Verify Firebase project has Cloud Messaging enabled

---

**Last Updated**: Post notification system fixes (commits 959461e through 2f4b25e)
**Status**: ✅ All identified issues fixed, ready for testing
