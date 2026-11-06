# ByBata.com — Deep links & share URLs

Deploy these files on **[https://bybata.com](https://bybata.com)** so shared links, email CTAs, and invite links open the Flutter app (or show a useful web fallback).

## Why links show “page does not exist”

Live checks (May 2026): `https://bybata.com/invite/...` and `/trade/...` return **404** because:

1. **`app-link-fallback.html` is not on the server** (also 404).
2. **No rewrite rules** — Hostinger needs `.htaccess` (or Netlify `_redirects`).

The app URLs are already correct (`https://bybata.com/...`). Deploy server files — see **`HOSTINGER_DEPLOY.md`**.

The mobile app now uses **`https://bybata.com`** for all shares (see `lib/core/config/web_links_config.dart`).

---

## Required files on bybata.com

```
bybata.com/
├── .well-known/
│   ├── apple-app-site-association    ← iOS Universal Links (NO extension)
│   └── assetlinks.json               ← Android App Links verification
├── open-app/
│   └── index.html                    ← from open-app.html (email “Open app” fallback)
├── app-link-fallback.html            ← **REQUIRED** fallback for /trade, /gift, /invite, …
├── .htaccess                         ← **REQUIRED** on Hostinger (rewrites share paths → fallback)
├── _redirects                        ← Netlify / Cloudflare Pages equivalent
├── open-app/index.html               ← email ?path= router (upgrade optional)
├── HOSTINGER_DEPLOY.md               ← step-by-step fix for 404 share links
├── terms.html                        ← full Terms (Plus Jakarta Sans, glass card, matches site)
├── privacy.html                      ← full Privacy Policy (same layout as terms)
├── _legal-shared.css                 ← optional external stylesheet (styles are inlined in HTML)
└── (optional) nginx-deep-links.conf.example
```

---

## 1. `.well-known/apple-app-site-association` (iOS)

1. Copy from this folder.
2. Replace **`TEAM_ID`** with your 10-character Apple Team ID.
3. Confirm bundle ID: **`com.bybata.bybata`** (must match Xcode).
4. Serve at: `https://bybata.com/.well-known/apple-app-site-association`
5. **Content-Type:** `application/json` (no `.json` extension on the file).

**Paths claimed by the app:**

| Path | Example |
|------|---------|
| `/open-app`, `/open-app/*` | Email links |
| `/trade/*` | Shared trade |
| `/gift/*` | Shared gift |
| `/campaign/*`, `/donation/*` | Campaigns |
| `/profile/*` | Profiles |
| `/invite/*` | Referrals |
| `/request/*` | Trade requests |

Verify:

```bash
curl -sI https://bybata.com/.well-known/apple-app-site-association
```

---

## 2. `.well-known/assetlinks.json` (Android)

1. Get **SHA-256** release fingerprint:

```bash
keytool -list -v -keystore YOUR_RELEASE.keystore -alias YOUR_ALIAS
```

2. Replace `REPLACE_WITH_RELEASE_SHA256` in `assetlinks.json`.
3. Package names in repo:
   - **`com.example.bybata`** — `android/app/build.gradle.kts` (current)
   - **`com.bybata.bybata`** — iOS bundle (include if you ship a different Android id later)

4. Serve at: `https://bybata.com/.well-known/assetlinks.json`

Verify:

```bash
curl -s https://bybata.com/.well-known/assetlinks.json | jq .
```

Android verification (device):

```bash
adb shell pm get-app-links com.example.bybata
```

---

## 3. `/open-app/` (email links)

Emails use URLs like:

`https://bybata.com/open-app?path=/trade/550e8400-e29b-41d4-a716-446655440000`

- **App installed:** iOS/Android opens the app → `main.dart` routes to trade details.
- **App not installed:** Browser loads `open-app/index.html` → tries `bybata://`, then redirects to [Google Play](https://play.google.com/store/apps/details?id=com.bybata.bybata) or [App Store](https://apps.apple.com/ng/app/bybata/id6779921314) on mobile.

---

## 4. Share link fallback (`app-link-fallback.html`)

Shared URLs look like:

`https://bybata.com/trade/550e8400-e29b-41d4-a716-446655440000`

**App installed:** OS opens app directly (after AASA + assetlinks are valid).

**App not installed:** Server must **not** return an empty SPA shell. Options:

**A. Nginx** (see `nginx-deep-links.conf.example`):

```nginx
location ~ ^/(trade|gift|campaign|donation|profile|invite|request)(/|$) {
    try_files $uri /app-link-fallback.html;
}
```

**B. Netlify** `_redirects`:

```
/trade/*  /app-link-fallback.html  200
/gift/*   /app-link-fallback.html  200
/campaign/* /app-link-fallback.html  200
/donation/* /app-link-fallback.html  200
/profile/*  /app-link-fallback.html  200
/invite/*   /app-link-fallback.html  200
/request/*  /app-link-fallback.html  200
```

**C. Vercel** `vercel.json` rewrites — same idea.

The fallback page redirects to `/open-app?path=...` so one code path handles “try open app”.

---

## 5. Legal URLs

App settings open:

- `https://bybata.com/terms.html`
- `https://bybata.com/privacy.html`

These match the live pages on [bybata.com](https://bybata.com).

---

## 6. API environment (Railway / production)

```env
APP_PUBLIC_URL=https://bybata.com
APP_DEEP_LINK_BASE_URL=https://bybata.com
REFERRAL_WEB_BASE_URL=https://bybata.com
MOBILE_APP_SCHEME=bybata
```

---

## 7. Optional: redirect old `bybata.app` links

If `bybata.app` still receives traffic, add **301 redirects**:

```
https://bybata.app/trade/ID  →  https://bybata.com/trade/ID
https://bybata.app/gift/ID   →  https://bybata.com/gift/ID
…
```

---

## Test checklist

| Test | Expected |
|------|----------|
| Share trade from app | Link is `https://bybata.com/trade/...` |
| Tap link on phone **with** app | App opens trade detail |
| Tap link **without** app | Fallback page + store buttons (not blank) |
| Email “View trade” button | `bybata.com/open-app?path=...` opens app or `/open-app` page |
| iOS Universal Links | Settings → Developer → diagnose associated domains |
| Android App Links | `adb shell pm verify-app-links --re-verify com.example.bybata` |

---

## Files in this folder

| File | Deploy to |
|------|-----------|
| `.well-known/apple-app-site-association` | `/.well-known/` |
| `.well-known/assetlinks.json` | `/.well-known/` |
| `open-app.html` | `/open-app/index.html` |
| `app-link-fallback.html` | `/app-link-fallback.html` |
| `nginx-deep-links.conf.example` | Reference only |
