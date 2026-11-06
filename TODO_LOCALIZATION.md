# BYBATA Multi-Language Localization TODO

**To:** Lead Mobile Developer / Core UI Engineer  
**From:** Product Architecture  
**Context:** Global Internationalization (`i18n`) & Dynamic Localization Strategy

Production-ready implementation blueprint for client-side asset compilation, dynamic backend headers (`Accept-Language`), bidirectional RTL mirroring safeguards, and tiered market rollout.

**Admin surfaces stay English-only** — see [§ Admin English-Only Policy](#admin-english-only-policy).

---

## Current State (Baseline)

- Mobile app strings are mostly hardcoded English in UI widgets.
- Settings already has a language picker (`settings_language`) and persistence, but **`MaterialApp` is not wired to locale** — changing language does not translate the UI.
- `intl` is in `pubspec.yaml`; `flutter_localizations` and gen-l10n are **not** configured yet.
- `ApiClient` (`lib/core/api/api_client.dart`) has interceptors but does **not** yet send `Accept-Language`.
- Admin panel (`apps/admin`) is Next.js, already `html lang="en"` — **no localization work planned there**.

---

## Admin English-Only Policy

> **Rule:** All admin-facing content MUST remain English (`en`). Only the end-user mobile app is multi-locale.

| Surface | Scope | Action |
| --- | --- | --- |
| `apps/admin` (Next.js) | Dashboard, moderation, settings, reports | **Do not add i18n.** Keep `html lang="en"`. No locale switcher. |
| Admin API responses | `/v1/admin/*`, `/admin/*` controllers | Return English labels/messages only. Ignore client `Accept-Language` for admin JWT sessions. |
| Admin email / alerts | Disputes, appeals, verification queues, system alerts to staff | Force `locale: 'en'` in email template resolution. |
| Admin push (if any) | Internal operator notifications | English copy only. |
| Admin audit logs | `adminActionAudit`, moderation notes | Store and display in English. |
| Mobile app | Consumer UX | Full tier rollout below. |

**API implementation note:** When resolving locale from `Accept-Language`, branch on role:

```ts
// Pseudocode — admin sessions always English
const locale = user.isAdmin
  ? 'en'
  : resolveLocale(req.headers['accept-language'], user.profile.language);
```

---

## Language Tiers (Rollout Order)

| Tier | Locale codes | Target regions | BYBATA rationale |
| --- | --- | --- | --- |
| **Tier 1: Global Core** | `en`, `es`, `pt-BR` | Global default, NA, UK, LATAM, Spain, Brazil | Western Hemisphere e-commerce scale; barter & donation rails. |
| **Tier 2: High-Velocity Commerce** | `zh-Hans`, `de`, `fr` | China, Singapore, Germany, Western Europe, Francophone Africa | European trading economies + Francophone Africa mobile growth. |
| **Tier 3: RTL & Proximity Hubs** | `ar`, `hi`, `ja` | MENA, India, Japan | MENA spend; India digital expansion; Japan proximity hub. |

**Final `supportedLocales` target (all tiers shipped):**

```dart
const supportedLocales = [
  Locale('en'),       // English baseline proxy
  Locale('es'),       // Spanish transaction channel
  Locale('pt', 'BR'), // Brazilian Portuguese localization
  Locale('zh'),       // zh-Hans — Simplified Chinese
  Locale('de'),
  Locale('fr'),
  Locale('ar'),       // Arabic layout match (RTL verification channel)
  Locale('hi'),
  Locale('ja'),
];
```

**Phase-gated activation:** Only expose locales in Settings / `supportedLocales` once their `.arb` file exists and QA passes for that tier.

---

## § 1. Setup Front-End Local Generation Pipelines

### 1.1 `pubspec.yaml`

Ensure the client dynamically maps text bundles at runtime without hardcoded string allocations in the UI thread.

- [ ] Add localization dependency suite to package manifest:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0  # Core calendar, date format, and number localization tracker

flutter:
  uses-material-design: true
  generate: true   # Instructs compiler to parse internal text asset dictionaries
```

- [ ] Confirm `intl` version is compatible with current Flutter SDK (use SDK-pinned version if `^0.19.0` conflicts).
- [ ] Run `flutter pub get`.

### 1.2 `l10n.yaml` (project root)

- [ ] Create root `l10n.yaml` to govern automatic class compilation parameters:

```yaml
arb-dir: lib/l10n                  # Dictionary directory path
template-arb-file: app_en.arb      # Source blueprint
output-class-file: app_localizations.dart
synthetic-package: true            # Compiles dynamic string lookups natively in memory
```

- [ ] Run `flutter gen-l10n` (or `flutter run`) and verify generation of:
  - `flutter_gen/gen_l10n/app_localizations.dart`
- [ ] Add `l10n.yaml` and gen-l10n step to CI build documentation.

---

## § 2. Populate Resource Dictionaries (`lib/l10n/`)

Create key-value Application Resource Bundle (`.arb`) files. **Every key across all dictionaries must mirror each other exactly** to avoid build failures.

### 2.1 Baseline English — `lib/l10n/app_en.arb`

- [ ] Create as single source of truth for all keys.
- [ ] Document naming convention: `camelCase`, optional feature prefix.

```json
{
  "@@locale": "en",
  "appTitle": "BYBATA",
  "tradeCenterTitle": "Trade Center",
  "supportHubTitle": "Support Hub",
  "donateButtonLabel": "Donate Base",
  "apiNetworkError": "Network sync failed. Please try again.",
  "tryAgain": "Try again",
  "cancel": "Cancel",
  "save": "Save",
  "noInternet": "No internet connection. Check your network and try again."
}
```

### 2.2 Spanish — `lib/l10n/app_es.arb`

- [ ] Create with identical keys to `app_en.arb`.

```json
{
  "@@locale": "es",
  "appTitle": "BYBATA",
  "tradeCenterTitle": "Centro de Intercambio",
  "supportHubTitle": "Centro de Apoyo",
  "donateButtonLabel": "Donar Base",
  "apiNetworkError": "Error de sincronización de red. Intente de nuevo.",
  "tryAgain": "Intente de nuevo",
  "cancel": "Cancelar",
  "save": "Guardar",
  "noInternet": "Sin conexión a Internet. Compruebe su red e inténtelo de nuevo."
}
```

### 2.3 Additional tier dictionaries

- [ ] `app_pt.arb` / `app_pt_BR.arb` — Brazilian Portuguese (Tier 1)
- [ ] `app_zh.arb` — Simplified Chinese (Tier 2)
- [ ] `app_de.arb`, `app_fr.arb` (Tier 2)
- [ ] `app_ar.arb`, `app_hi.arb`, `app_ja.arb` (Tier 3)
- [ ] CI check: fail build if any non-`en` ARB is missing keys present in `app_en.arb`.

---

## § 3. Inject Context Delegates to Application Core (`main.dart`)

Wrap the root container inside system localization delegates. This enables immediate front-end rendering shifts when the active locale changes (device OS or in-app Settings).

### 3.1 `LocaleProvider` (wire existing Settings picker)

- [ ] Create `lib/core/providers/locale_provider.dart` that:
  - [ ] Reads `settings_language` from SharedPreferences on startup.
  - [ ] Falls back to device locale if supported, else `en`.
  - [ ] Exposes `Locale get locale` and `Future<void> setLocale(String languageCode)`.
- [ ] Map stored codes to full locales where needed (`pt` → `Locale('pt', 'BR')`, `zh` → `Locale('zh')`).
- [ ] Connect existing `LanguageSelector` / `SimpleLanguageSelector` to call `setLocale()` and persist.
- [ ] Restrict picker options to **locales with completed ARB files** for the active tier.
- [ ] Sync `settings_language` → API `profile.language` on change.

### 3.2 `MaterialApp` binding

- [ ] Import delegates and generated localizations.
- [ ] Wrap app with `LocaleProvider` above `MaterialApp`.
- [ ] Bind delegates in `lib/main.dart`:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Auto-generated on run

// Inside MaterialApp:
MaterialApp(
  title: 'BYBATA',
  theme: themeProvider.lightTheme,
  darkTheme: themeProvider.darkTheme,
  themeMode: themeProvider.themeMode,

  locale: localeProvider.locale,

  // Explicitly define verified multi-lingual targets (expand per tier rollout)
  supportedLocales: const [
    Locale('en'),       // English baseline proxy
    Locale('es'),       // Spanish transaction channel
    Locale('pt', 'BR'), // Brazilian Portuguese localization
    Locale('ar'),       // Arabic layout match (RTL verification channel)
    // Tier 2+: Locale('zh'), Locale('de'), Locale('fr'),
    // Tier 3+: Locale('hi'), Locale('ja'),
  ],

  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],

  // ...
)
```

- [ ] Verify hot restart / Settings language switch updates UI without reinstall.

### 3.3 Compliant runtime lookup in widgets

Replace hardcoded layout labels with direct context definitions.

- [ ] Add developer extension:

```dart
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
```

- [ ] Enforce in PR review — **no new hardcoded user-facing strings** in `lib/features/**`:

```dart
// BLOCKED — breaks multi-language support
Text('Trade Center')

// COMPLIANT — dynamically updates based on active locale
Text(AppLocalizations.of(context)!.tradeCenterTitle)
// or
Text(context.l10n.tradeCenterTitle)
```

- [ ] Migrate `NetworkErrorMessage` callers to use `context.l10n.apiNetworkError` (or equivalent ARB key) where UI-bound.

---

## § 4. Implement Automated `Accept-Language` API Headers

Backend servers must match incoming mobile locale state to properly localize push tokens, receipt parameters, and error strings before dispatching server payloads.

### 4.1 Mobile — `ApiLocalizationInterceptor`

- [ ] Create `lib/core/api/api_localization_interceptor.dart`.
- [ ] Register on `ApiClient` Dio instance in `lib/core/api/api_client.dart` (alongside existing auth interceptor).

**Preferred:** Read active locale from `LocaleProvider` (respects in-app Settings override).

**Fallback:** OS locale via `Platform.localeName`.

```dart
import 'package:dio/dio.dart';

class ApiLocalizationInterceptor extends Interceptor {
  ApiLocalizationInterceptor({required String Function() localeCodeProvider})
      : _localeCodeProvider = localeCodeProvider;

  final String Function() _localeCodeProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Industry-standard localization header on every endpoint call
    final locale = _localeCodeProvider(); // e.g. "en", "es", "pt-BR" → send "pt" or full tag per API contract
    options.headers['Accept-Language'] = locale;

    super.onRequest(options, handler);
  }
}
```

**Reference implementation (OS-only fallback — replace with LocaleProvider in production):**

```dart
import 'dart:io';
import 'package:dio/dio.dart';

class ApiLocalizationInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String systemLocale = Platform.localeName.split('_').first;
    options.headers['Accept-Language'] = systemLocale;
    super.onRequest(options, handler);
  }
}
```

- [ ] Document header format agreed with API (`en` vs `en-US` vs `pt-BR`).
- [ ] Do **not** send user locale on admin-authenticated requests from admin tooling (N/A for mobile consumer app).

### 4.2 API — locale resolution (`apps/api`)

- [ ] Parse `Accept-Language` header on user-facing routes.
- [ ] Resolve order: explicit user preference (`profile.language`) → `Accept-Language` → `en`.
- [ ] **Admin routes (`/v1/admin/*`, `/admin/*`):** force `locale = 'en'` regardless of header.
- [ ] Email service (`apps/api/src/email`): user templates use resolved locale; admin/staff templates hardcoded `en`.
- [ ] Push notification copy: user notifications localized; admin/operator alerts English only.

---

## § 5. Layout Alignment Enforcement Rules (RTL Safety Guard)

When enabling **Arabic (`ar`)** or other RTL locales, the entire layout direction flips. Audit styling habits **before** Tier 3 ship.

### 5.1 Directional variables (mandatory)

- [ ] **Padding & margins:** Never `EdgeInsets.only(left: 16)`. Use `EdgeInsetsDirectional.only(start: 16)`.
- [ ] **Alignment:** Never `Alignment.centerLeft`. Use `AlignmentDirectional.centerStart`.
- [ ] **Positioning:** `Positioned(left:/right:)` → `PositionedDirectional(start:/end:)`.
- [ ] **Border radius:** `BorderRadius.only(topLeft:...)` → `BorderRadiusDirectional` where mirrored.
- [ ] **Row/Column cross-axis:** Prefer `start` / `end` alignment enums over `left` / `right`.

### 5.2 Directional icon assets

For contextual directional graphics (back buttons, scroll arrows, chevrons), mirror when layout flow pivots:

```dart
Transform.flip(
  flipX: Directionality.of(context) == TextDirection.rtl,
  child: const Icon(Icons.chevron_left),
)
```

- [ ] Prefer `Icons.arrow_back` (auto-mirrors in Material) where possible over custom chevrons.
- [ ] Set `matchTextDirection: true` on directional icons when supported.

### 5.3 RTL regression targets

- [ ] Custom Bento / glass grids — test flip on `Locale('ar')`.
- [ ] Trade, Chat, Wallet, Settings hubs — full regression on Android + iOS.
- [ ] Notch, gesture nav bar, and keyboard inset behavior in RTL.

---

## Phase 0 — Infrastructure Checklist (Do First)

- [ ] Complete **§ 1** (`pubspec.yaml`, `l10n.yaml`, gen-l10n).
- [ ] Complete **§ 2.1–2.2** (`app_en.arb`, `app_es.arb` minimum).
- [ ] Complete **§ 3** (`LocaleProvider`, `main.dart` delegates).
- [ ] Complete **§ 4.1** (`ApiLocalizationInterceptor` on `ApiClient`).
- [ ] Smoke test: switch `en` ↔ `es` in Settings; confirm UI + API header change.

---

## Phase 1 — Tier 1 Locales (`en`, `es`, `pt-BR`)

### ARB & codegen

- [ ] `app_pt.arb` / `app_pt_BR.arb` with 100% key parity to `app_en.arb`.
- [ ] Add `Locale('pt', 'BR')` to `supportedLocales`.
- [ ] Run gen-l10n; fix missing-key errors.

### String migration — high-impact screens (~150 keys)

- [ ] Bottom navigation / hub labels (`MainNavigation`, home v2)
- [ ] Auth: login, register, forgot password, verification
- [ ] Settings: language/region section
- [ ] Search / Items screen
- [ ] Trade browse (`trade_screen.dart`)
- [ ] Gifting browse (`gifting_screen.dart`)
- [ ] Donations browse (`donations_screen.dart`)
- [ ] Profile shell
- [ ] Empty states & pull-to-refresh copy in `SocialFeedList`

### QA

- [ ] Manual pass Android + iOS for `en`, `es`, `pt-BR`.
- [ ] Dates/numbers use `intl` with active locale.
- [ ] Store listing screenshots per market (if required).

---

## Phase 2 — Tier 2 Locales (`zh-Hans`, `de`, `fr`)

### ARB files

- [ ] `app_zh.arb`, `app_de.arb`, `app_fr.arb` — full key parity.
- [ ] Professional translation review for `fr` (Francophone Africa tone).

### String migration — feature depth

- [ ] Wallet & BYC flows
- [ ] Chat & in-app notifications (user-facing only)
- [ ] Karma / trust screens
- [ ] Create/edit listing flows (trade, gift, campaign)
- [ ] Detail screens & action sheets
- [ ] Onboarding overlay text

### API alignment

- [ ] Complete **§ 4.2** (API locale resolution + admin English lock).
- [ ] Verify user error payloads respect `Accept-Language`.

### QA

- [ ] `fr` native speaker review.
- [ ] `zh-Hans` line-length on narrow devices.
- [ ] `de` compound-word button overflow.

---

## Phase 3 — Tier 3 Locales (`ar`, `hi`, `ja`) + RTL

### ARB files

- [ ] `app_ar.arb`, `app_hi.arb`, `app_ja.arb` — full key parity.

### RTL audit

- [ ] Complete **§ 5** codebase sweep across `lib/`.
- [ ] Enable `Locale('ar')` in Settings only after RTL QA sign-off.

### QA

- [ ] Arabic RTL on Android + iOS.
- [ ] Hindi Devanagari rendering and line height.
- [ ] Japanese compact-mode vertical spacing.

---

## Phase 4 — Admin & Backend Alignment

- [ ] Confirm `<html lang="en">` in `apps/admin/app/layout.tsx`.
- [ ] **Do not** add `next-intl`, i18n routing, or locale middleware to admin.
- [ ] Admin notification / Slack / webhook copy: English only.
- [ ] Legal URLs / terms: English unless separate localized web pages exist.
- [ ] Developer diagnostic screens (`kDebugMode`): English acceptable.
- [ ] Raw API error codes in logs; user sees localized wrapper in app.

---

## Phase 5 — Release & Store

- [ ] Play Console localized store listings per tier market.
- [ ] App Store Connect localization metadata per tier.
- [ ] Play App Bundle `resourceConfigurations` if stripping unused languages later.
- [ ] Optional remote config flags to gate Tier 2/3 locales post-RTL QA.

---

## File Checklist

| File | Action |
| --- | --- |
| `pubspec.yaml` | Add `flutter_localizations`, `generate: true`, confirm `intl` |
| `l10n.yaml` | Create with `synthetic-package: true` |
| `lib/l10n/app_en.arb` | Create (template) |
| `lib/l10n/app_*.arb` | Create per tier rollout |
| `lib/core/providers/locale_provider.dart` | Create |
| `lib/core/api/api_localization_interceptor.dart` | Create |
| `lib/core/api/api_client.dart` | Register interceptor |
| `lib/main.dart` | Wire delegates + `locale` |
| `lib/core/utils/l10n_extension.dart` | Optional `L10nX` extension |
| `lib/features/settings/**` | Connect picker → `LocaleProvider` |
| `apps/api/src/email/**` | User locale vs admin `en` |
| `apps/api/src/**/admin*.ts` | Force English for admin sessions |
| `apps/admin/**` | **No i18n changes** |

---

## Definition of Done (per tier)

- [ ] All Tier N ARB files have **100% key parity** with `app_en.arb`.
- [ ] Phase migration checklist for that tier is complete.
- [ ] No hardcoded user-facing strings in migrated screens.
- [ ] Settings language switch updates UI without app reinstall.
- [ ] `Accept-Language` header reflects active user locale on all mobile API calls.
- [ ] Admin panel and admin API notifications verified **English-only**.
- [ ] RTL audit complete before `ar` is user-selectable (Tier 3).
- [ ] QA sign-off on listed devices for each new locale.

---

## Out of Scope

- Localizing the admin dashboard UI (`apps/admin`).
- Machine-translating user-generated content (trade titles, chat messages, campaign descriptions).
- Localizing third-party payment gateway webviews (Stripe/Paystack host their own UI).

---

*Last updated: Scalable Multi-Locale Engine Implementation — tiered global rollout, admin English-only, RTL safety guard.*
