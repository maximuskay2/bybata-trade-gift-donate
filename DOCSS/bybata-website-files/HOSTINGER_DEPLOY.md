# Fix “page does not exist” for share links (bybata.com)

## What we tested (live)

| URL | Status today | After deploy |
|-----|----------------|--------------|
| `https://bybata.com/` | 200 | 200 |
| `https://bybata.com/terms.html` | 200 | 200 |
| `https://bybata.com/open-app/` | 200 | 200 |
| `https://bybata.com/.well-known/apple-app-site-association` | 200 | 200 |
| `https://bybata.com/invite/maximuskay2` | **404** | **200** (fallback page) |
| `https://bybata.com/trade/UUID` | **404** | **200** (fallback page) |
| `https://bybata.com/app-link-fallback.html` | **404** | **200** |

The Flutter app already generates correct URLs (`https://bybata.com/trade/...`, `/invite/...`).  
The site is on **Hostinger (LiteSpeed)** — you need two files on the server plus rewrite rules.

---

## Upload these 4 items to `public_html/`

1. **`app/index.html`** — **marketing link** `https://bybata.com/app` (routes to App Store or Play Store)
2. **`app-link-fallback.html`** (from this folder)
3. **`.htaccess`** (from this folder — enables `/trade/*`, `/invite/*`, `/get`, `/download`, etc.)
4. **`open-app/index.html`** (email “Open app” fallback)

Do **not** overwrite your marketing homepage unless you intend to.

---

## Hostinger steps (hPanel)

1. **Files → File Manager → public_html**
2. Upload `app-link-fallback.html` to the root (same level as `index.html`, `terms.html`)
3. Upload `.htaccess` to the root  
   - If `.htaccess` already exists, **merge** the `RewriteRule` block from our file into yours (do not delete SSL or WordPress rules).
4. Open **open-app** folder → upload `open-app/index.html` from this repo
5. Create **app** folder → upload `app/index.html` from this repo (marketing store link)
6. Confirm `.well-known/` still has `apple-app-site-association` and `assetlinks.json`

---

## Verify (run in this order)

```bash
# Step 1 — MUST be 200 first (file missing = invite will stay 404)
curl -sI https://bybata.com/app-link-fallback.html | grep HTTP

# Step 2 — only works after step 1 is 200
curl -sI https://bybata.com/invite/maximuskay2 | grep HTTP
curl -sI https://bybata.com/trade/test-uuid-123 | grep HTTP
```

Expected: **`HTTP/2 200`** (or `HTTP/1.1 200`) for all three.

### Your curl shows 404 — what it means

| Test | Result | Meaning |
|------|--------|---------|
| `app-link-fallback.html` | **404** | File **not uploaded** to `public_html/`, or wrong folder |
| `invite/...` | **404** | Fallback file missing **or** `.htaccess` rewrite not active |
| `.htaccess` (direct URL) | **403** | Normal — server blocks reading that file; does **not** prove rewrites work |

**Fix order:** Upload `app-link-fallback.html` → confirm step 1 is **200** → then fix `.htaccess` if step 2 is still 404.

Optional: upload `DEPLOY_VERIFY.txt` and open `https://bybata.com/DEPLOY_VERIFY.txt` — if that 404s, you are uploading to the wrong directory (use `public_html`, same level as `terms.html`).

In a browser (no app installed): open `https://bybata.com/invite/maximuskay2` — you should see **“You’re invited to ByBata”**, not Hostinger’s 404 page.

With the app installed: tapping the same link should open the app (Universal Links / App Links).

---

## If `.htaccess` does not work

On some Hostinger plans, enable **Apache mod_rewrite** or add rules in hPanel → **Advanced → Rewrite Rules**:

```
RewriteRule ^(trade|gift|campaign|donation|profile|invite|request)(/.*)?$ /app-link-fallback.html [L]
```

Alternative: Netlify-style `_redirects` file (included) if you move DNS to Netlify/Cloudflare Pages.

---

## App store links (live)

**One marketing link (use everywhere on social media):**

### https://bybata.com/app

Aliases (same page): `https://bybata.com/get` · `https://bybata.com/download`

| Platform | Store URL |
|----------|-----------|
| Google Play | `https://play.google.com/store/apps/details?id=com.bybata.bybata` |
| App Store | `https://apps.apple.com/ng/app/bybata/id6779921314` |

- **`app/index.html`** — auto-detects iPhone/Android and opens the correct store; desktop shows both buttons.
- **`app-link-fallback.html`** / **`open-app/index.html`** — used for share links and email deep links when the app may already be installed.
