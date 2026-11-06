# byBata

byBata is a trade-by-barter marketplace by **Maximusinfotech Services**. It brings together trading, gifting, donations, communities, messaging and a BYC wallet.

This is a sanitized source snapshot prepared for a prospective PayPal hackathon repository. It is not a production backup or a claim that the existing product was developed during the event. Existing PayPal payment and AI search code must be distinguished from any new hackathon work. No new hackathon feature is implemented by this cleanup.

## Structure

- `lib/`, `android/`, `ios/`, `web/` and desktop folders: Flutter application.
- `apps/api/`: NestJS API, Prisma and PostgreSQL.
- `apps/admin/`: Next.js administration interface.
- `docker-compose.yml`: local PostgreSQL, Redis and MinIO services.

## Requirements

Use Flutter with Dart compatible with `^3.9.0`, Node.js 22 LTS with npm, and Docker Compose v2. Android and iOS builds also need their platform SDKs. Dependency installation and full application builds have not been verified for this snapshot.

## Safe local setup

Never connect this copy, its tests, seed scripts or administrative tools to production services. Some inherited source and documentation still reference the production application. Always explicitly configure local endpoints. Do not run production deployment, purge, backup, scenario or seed scripts without reviewing them first.

### 1. Local services

```sh
cp .env.example .env
```

Replace all three placeholders in `.env` with unique local passwords, then:

```sh
docker compose up -d
```

PostgreSQL listens on port 5432, Redis on 6379 and MinIO on 9000 with its console on 9001. MinIO creates a local `bybata` bucket. These containers are for local use only.

### 2. API

```sh
cd apps/api
cp .env.example .env
```

Set `DATABASE_URL` and `REDIS_URL` to the local passwords above, and `STORAGE_SECRET_ACCESS_KEY` to the local MinIO password. URL-encode passwords used in URLs. Generate separate random JWT secrets, for example with `openssl rand -hex 32`. For encrypted administrative configuration, provide a new `CONFIG_ENCRYPTION_KEY` compatible with the encryption helper in the API. Optional third-party features require your own isolated development credentials.

```sh
npm ci
npx prisma generate
npx prisma db push
npm run start:dev
```

SQL files, including migration SQL, were deliberately excluded. `prisma db push` is only for a fresh disposable local database; do not use it on production. Existing migration folders are not a deployable migration history in this snapshot.

### 3. Admin

In another terminal:

```sh
cd apps/admin
cp .env.example .env.local
npm ci
npm run dev
```

The admin runs at `http://localhost:3001`. Use a newly created local test account and grant it an administrative role only in the disposable local database.

### 4. Flutter

```sh
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://localhost:3000
```

For an Android emulator, use `http://10.0.2.2:3000`. For an iOS simulator, use `http://localhost:3000`. A physical device needs the development machine's reachable LAN address. Always pass `API_BASE_URL`, including release/profile builds, so inherited production defaults are not used.

Firebase sign-in, messaging and Google Maps need a separate development project. Platform Firebase files and signing keys are intentionally absent. Create your own `google-services.json` and `GoogleService-Info.plist` locally, never commit them. Web Firebase settings are supplied using `--dart-define` entries for `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID` and optionally `FIREBASE_MEASUREMENT_ID`. Android Maps reads the `GOOGLE_MAPS_API_KEY` environment variable at build time. Public client configuration is not a substitute for proper API restrictions and Firebase security rules.

## PayPal and AI

The API contains existing PayPal payment code and optional OpenAI-backed search. Use sandbox credentials only: `PAYPAL_ENV=sandbox`, `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET` and, where the existing provider discovery expects it, the same value in `PAYPAL_SECRET`. Webhook verification also needs your sandbox `PAYPAL_WEBHOOK_ID` and a development webhook endpoint. Keep secrets on the server, never in Flutter compile-time defines or `NEXT_PUBLIC_*` variables. Enable `AI_INTENT_ENABLED` only when an isolated `OPENAI_API_KEY` is configured. Review event rules before describing any component as new work.

## Security and publication

The snapshot excludes original Git history, environment files other than new placeholder examples, signing material, database dumps, SQL, archives, dependency caches, build outputs and selected credential-bearing internal reports. Remaining hardcoded mobile API keys were replaced with build-time configuration. A clean automated secrets scan is not proof that every sensitive datum or licensing issue has been found. Rotate previously committed credentials and review the copy before publication. The original private production repository is not changed by this snapshot.

## License

MIT. Copyright (c) 2026 Maximusinfotech Services. Third-party dependencies and assets retain their respective licenses; verify redistribution rights before publication.
