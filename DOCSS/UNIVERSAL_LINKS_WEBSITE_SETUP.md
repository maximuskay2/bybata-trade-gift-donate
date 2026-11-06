# Universal Links Website Setup for bybata.com

This guide explains how to configure bybata.com so that email links (e.g. "Login to Dashboard") open the ByBata app when installed, or fall back to the website.

**Ready-to-use files:** See `DOCSS/bybata-website-files/` for HTML pages and JSON configs you can copy directly to your bybata.com site.

---

## 1. Create `/open-app` Route (HTML)

Since bybata.com is a static HTML site, use the ready-made HTML files in **`DOCSS/bybata-website-files/`**:

### Option A: Redirect to Homepage

Copy `open-app-redirect.html` to `open-app/index.html` on your server. It immediately redirects to `/`.

### Option B: "Open in App" Landing Page

Copy `open-app.html` to `open-app/index.html`. It shows:
- ByBata branding
- Google Play and App Store buttons
- Auto-redirect to `/` after 3 seconds

**Before deploying:** Update the App Store URL (replace `idXXXXXXXXX` with your real Apple App ID) and the Google Play URL if your package differs from `com.example.bybata`.

### File structure on your server

```
bybata.com/
├── open-app/
│   └── index.html    ← Use open-app.html or open-app-redirect.html
├── .well-known/
│   ├── assetlinks.json
│   └── apple-app-site-association
```

---

## 2. Android: `assetlinks.json`

Android uses this file to verify your app can handle links from your domain.

### Step 1: Get your app's SHA-256 fingerprint

```bash
# For release keystore (production)
keytool -list -v -keystore your-release.keystore -alias your-alias

# For debug (testing only)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey
```

Copy the **SHA-256** value (e.g. `AA:BB:CC:DD:...`).

### Step 2: Create the file

Create `public/.well-known/assetlinks.json` (or `public/assetlinks.json` and configure your server):

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.bybata",
      "sha256_cert_fingerprints": [
        "YOUR_SHA256_FINGERPRINT_HERE"
      ]
    }
  }
]
```

**Replace:**
- `com.example.bybata` → Your Android `applicationId` (from `android/app/build.gradle.kts`)
- `YOUR_SHA256_FINGERPRINT_HERE` → The SHA-256 from step 1 (colons allowed, or use lowercase without colons)

### Step 3: Serve at the correct URL

The file **must** be accessible at:
```
https://bybata.com/.well-known/assetlinks.json
```

- **Content-Type**: `application/json`
- **Next.js**: Place in `public/.well-known/assetlinks.json` (served automatically)
- **Vercel/Netlify**: Add to `public/` folder
- **Apache**: Ensure `.well-known` is not blocked

### Verify

```bash
curl -I https://bybata.com/.well-known/assetlinks.json
# Should return 200 OK
```

---

## 3. iOS: `apple-app-site-association`

iOS uses this file (no file extension) for Universal Links.

### Step 1: Create the file

Create `public/.well-known/apple-app-site-association` or `public/apple-app-site-association`:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.bybata.bybata",
        "paths": ["/open-app", "/open-app/*"]
      }
    ]
  }
}
```

**Replace:**
- `TEAM_ID` → Your Apple Developer Team ID (10-character alphanumeric, from [developer.apple.com](https://developer.apple.com/account))
- `com.bybata.bybata` → Your iOS bundle ID (from Xcode project)

### Step 2: Serve at the correct URL

The file **must** be accessible at:
```
https://bybata.com/.well-known/apple-app-site-association
```
or
```
https://bybata.com/apple-app-site-association
```

- **Content-Type**: `application/json` (Apple accepts this)
- **HTTPS required**: No redirects for the initial request
- **No file extension** in the filename

### Step 3: Associated Domains in iOS App

The ByBata Flutter app already has `applinks:bybata.com` in `ios/Runner/Runner.entitlements`. If you add a new domain, ensure it's in Xcode **Signing & Capabilities** → **Associated Domains**.

### Verify

```bash
curl -I https://bybata.com/.well-known/apple-app-site-association
# Should return 200 OK
```

---

## 4. Quick Reference

| Item | Value |
|------|-------|
| Android package | `com.example.bybata` |
| iOS bundle ID | `com.bybata.bybata` |
| Domain | `bybata.com` |
| Paths to handle | `/open-app`, `/open-app/*` |

---

## 5. Testing

1. **Deploy** all files to bybata.com
2. **Verify** both JSON files are served correctly (see curl commands above)
3. **Install** the app on a device
4. **Send** a test email with a "Login to Dashboard" link
5. **Tap** the link – the app should open (not the browser)

### Troubleshooting

- **Android**: App Links may take a few minutes to verify. Use [Statement List Generator](https://developers.google.com/digital-asset-links/tools/generator) to validate.
- **iOS**: Associated Domains must be enabled in Xcode. Rebuild and reinstall the app after adding the capability.
- **Caching**: CDNs and browsers cache these files. Use incognito or a different device if changes don't appear.

---

## 6. If bybata.com is in a Different Repo

If bybata.com is a separate project:

1. Copy the `assetlinks.json` and `apple-app-site-association` content above
2. Add the `/open-app` route (redirect or landing page)
3. Place the files in the appropriate `public/` or static folder
4. Deploy

Ensure the domain is exactly `bybata.com` (or add `www.bybata.com` as another entry if needed).
