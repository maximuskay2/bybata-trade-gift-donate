# Email Link Router Configuration

## Overview

The application uses a centralized **EmailLinkRouterService** to generate appropriate URLs for email links. This enables:

- **Mobile users**: Receive deep links (`bybata://`) or Universal Links (`https://bybata.com/open-app`) that open the Flutter app directly
- **Fallback**: When app isn't installed, links open https://bybata.com (or /open-app) in the browser
- **Production safety**: When APP_PUBLIC_URL is localhost, all email links use https://bybata.com so users never get localhost in production emails

### Universal Links (bybata.com/open-app)

Email links like "Login to Dashboard" use `https://bybata.com/open-app`. When tapped:
- **App installed**: Opens the app (requires assetlinks.json on bybata.com for Android, apple-app-site-association for iOS)
- **App not installed**: Browser loads https://bybata.com/open-app (website should redirect to / or show app store links)

## How It Works

### Deep Link Support

The Flutter app has been configured with the `app_links` package to handle deep links:

```
bybata://campaign/{id}
bybata://trade/{id}
bybata://gift/{id}
bybata://community/{id}
bybata://chat/{id}
bybata://profile/{username}
bybata://wallet
bybata://invite?code={code}
```

### Android Configuration
- **Location**: `android/app/src/main/AndroidManifest.xml`
- **Setup**: ✅ Deep link intent-filter configured for `bybata://` scheme

### iOS Configuration
- **Location**: `ios/Runner/Info.plist`
- **Setup**: ✅ URL scheme `bybata` registered in CFBundleURLSchemes

### Flutter App Integration
- **Location**: `lib/main.dart` (_DeepLinkHandlerState)
- **Setup**: ✅ Deep link handler implemented with routing for all supported types

## Environment Variables Required

Add these variables to your Railway environment:

### 1. **APP_PUBLIC_URL** (Required)
Your web app URL. Used as fallback for all users and primary URL for web users.

```
APP_PUBLIC_URL=https://bybata.app
```

### 2. **APP_DEEP_LINK_BASE_URL** (Optional, default: https://bybata.com)
Base URL for "Open App" / "Login to Dashboard" links in emails. Uses /open-app path.
When APP_PUBLIC_URL is localhost, all email links use this as fallback.

```
APP_DEEP_LINK_BASE_URL=https://bybata.com
```

### 3. **MOBILE_APP_SCHEME** (Required for Deep Links)
Mobile app deep link scheme. When set, mobile users will receive deep links instead of web URLs.

```
MOBILE_APP_SCHEME=bybata://
```

### 4. **ADMIN_URL** (Optional)
Admin dashboard URL. ONLY used for admin-specific links (not sent to regular users in emails).

```
ADMIN_URL=https://bybataadmin-production.up.railway.app
```

## Email Link Generation

### By Service

| Service | Link Type | Method | Example URL |
|---------|-----------|--------|------------|
| campaigns | Campaign details | `getCampaignLink(id)` | `bybata://campaign/{id}` |
| gifts | Gift details | `getGiftLink(id)` | `bybata://gift/{id}` |
| trades | Trade/offer details | `getTradeLink(id)` | `bybata://trade/{id}` |
| communities | Community details | `getCommunityLink(id)` | `bybata://community/{id}` |
| chat | Conversation | `getChatLink(id)` | `bybata://chat/{id}` |
| profiles | User profile | `getProfileLink(username)` | `bybata://profile/{username}` |
| invites | Community invites | `getCommunityInviteLink(code)` | `bybata://invite?code={code}` |
| other | Generic web link | `getWebLink(path)` | `https://bybata.app{path}` |

### Services Updated

1. **campaigns.service.ts** - CampaignCreated, CampaignPublished, DonationReceived, etc.
2. **gifts.service.ts** - GiftOfferReceived, GiftAccepted, GiftClaimed
3. **ad-scheduling.service.ts** - AdStarted, AdEnded
4. **communities.service.ts** - CommunityJoinRequestApproved, CommunityMention, community invites
5. **chat.service.ts** - ChatNewConversation, ChatNewMessage, ChatMention
6. **auth.service.ts** - AuthSignupWelcome, AuthEmailVerified

## Implementation Details

### EmailLinkRouterService
**Location**: `apps/api/src/shared/services/email-link-router.service.ts`

The service provides these methods:
- `getCampaignLink(id, preferMobile=true)` → Deep link or web URL
- `getTradeLink(id, preferMobile=true)` → Deep link or web URL
- `getGiftLink(id, preferMobile=true)` → Deep link or web URL
- `getCommunityLink(id, preferMobile=true)` → Deep link or web URL
- `getChatLink(id, preferMobile=true)` → Deep link or web URL
- `getProfileLink(username, preferMobile=true)` → Deep link or web URL
- `getCommunityInviteLink(code, preferMobile=true)` → Deep link or web URL
- `getWebLink(path)` → Web URL (no deep link support)
- `getAdminDashboardLink()` → Admin dashboard URL

## Configuration Steps

### 1. Update Railway Environment

Go to your Railway project dashboard and add these variables to your production environment:

```bash
APP_PUBLIC_URL=https://bybata.app
MOBILE_APP_SCHEME=bybata://
ADMIN_URL=https://bybataadmin-production.up.railway.app
```

### 2. Redeploy Backend
Push this commit to trigger a new deployment:

```bash
git push origin main
```

The backend will automatically pick up the new environment variables.

### 3. Test Email Links

1. **Test Mobile Deep Link**
   - Create a campaign and trigger the CampaignCreated email
   - Click the campaign link in the email from a mobile device
   - App should open with campaign details

2. **Test Web Link**
   - Create a campaign and trigger the CampaignCreated email  
   - Click the campaign link from a desktop browser
   - Web app should open with campaign details

3. **Test Fallback**
   - If MOBILE_APP_SCHEME is not set, all links should use web URL
   - Verify this works on both mobile and web

## Troubleshooting

### Deep links not working on mobile
1. Check that `MOBILE_APP_SCHEME=bybata://` is set in environment variables
2. Ensure mobile app has been rebuilt and deployed with latest code
3. Check Android manifest and iOS plist configuration are correct

### Web links not working
1. Verify `APP_PUBLIC_URL` is set correctly
2. Check that the web app is deployed at that URL
3. Ensure route handlers exist for the paths being generated

### Admin dashboard appearing in user emails
1. Confirm this code has been deployed (commit `6b22a28`)
2. Check that `APP_PUBLIC_URL` is set to web app URL, not admin dashboard
3. Verify backend has restarted with new environment variables

## Rollback

If issues occur, you can revert to direct environment variable usage:

1. Revert commit `6b22a28`
2. Remove the new environment variables from Railway
3. Keep old `APP_PUBLIC_URL` pointing to web app

However, deep links will not work until the router is re-enabled.

## Migration from Old System

**Before** (all emails used admin dashboard):
```
campaignUrl = "https://bybataadmin-production.up.railway.app/campaigns/{id}"
```

**After** (mobile users get deep links, web users get web URL):
```
campaignUrl = "bybata://campaign/{id}"        (mobile)
campaignUrl = "https://bybata.app/campaigns/{id}"  (web fallback)
```

## Future Enhancements

1. Add platform detection to email templates (send different links for mobile vs web)
2. Track email link clicks to analytics
3. Add QR code generation for email links
4. Support for other platforms (Android-specific schemes, iOS-specific schemes)



the draggable floating menu in /Users/maximusinfotech/StudioProjects/BYBATAPHP/bybataRailway/lib/screens/home/home_screen.dart (home screen) should upgraded so when user tapped the menu items wont show or float outside the screen of the user
