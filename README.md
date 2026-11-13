# FinPlan

Personal finance app: a Flutter client backed by a NestJS + PostgreSQL REST API. Built as a portfolio project.

## Features

- **Authentication** – register, login, logout, JWT access tokens with refresh-token rotation, automatic token renewal and global handling of expired sessions in the app. Rate limiting on auth routes.
- **Bank accounts** – create, list, edit and delete accounts.
- **Transactions** – income/expense records with categories and pending/completed status, linked to an account.
- **Payable bills** – create, edit, pay (with early-payment discount support), cancel and delete bills; paying a bill is guarded against concurrent updates.
- **Data isolation** – every query is scoped to the authenticated user.

## Tech stack

| Layer | Technology |
|---|---|
| Client | Flutter / Dart |
| API | NestJS 12, TypeScript, Passport JWT, argon2, helmet, throttler |
| Database | PostgreSQL, Prisma 7 (`@prisma/adapter-pg`) |
| Tests | Vitest + Supertest (backend), `flutter_test` (client) |

## Structure

```
lib/            Flutter app (app/, core/, features/<feature>/{application,presentation,...})
test/           Flutter tests
backend/
  src/          NestJS modules: auth, accounts, transactions, payable-bills, prisma
  prisma/       schema.prisma and migrations
  test/         E2E tests (run against a dedicated *_test database)
```

## Running the backend

Requirements: Node.js 22+, PostgreSQL.

```powershell
cd backend
npm install
Copy-Item .env.example .env        # then edit values
npx prisma generate
npx prisma migrate deploy
npm run start:dev
```

Environment variables (see `backend/.env.example`):

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Signing secret, **at least 32 bytes** |
| `CORS_ORIGINS` | Comma-separated allowed origins (required in production) |
| `PORT` | Optional, default `3000` |

Generate a secret: `node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"`

## Running the app

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` is the Android emulator's alias for the host machine; use `http://localhost:3000` for desktop/web.

## Tests

```powershell
# Backend
cd backend
npm run build
npm test            # unit tests
npm run lint
npm run test:e2e    # needs backend/.env.test pointing at a database named *_test

# Flutter
flutter analyze
flutter test
```

E2E setup: create an empty database (e.g. `finplan_test`), copy `.env.example` to `.env.test`, point `DATABASE_URL` at it and run `npx prisma migrate deploy` with that URL. The test runner refuses to start if the database name does not end in `_test`.

## Screenshots

_To add:_ `docs/screenshots/login.png`, `accounts.png`, `transactions.png`, `payable-bills.png`.

## Known limitations

- Dashboard, planning, and diagnostics screens are not fully verified against the backend; investments and news are not implemented.
- No Docker setup; PostgreSQL must be installed locally.
- No deployment configuration.
- Flutter widget/UI coverage is limited to stores and a login smoke test.

## License

MIT (see [LICENSE](LICENSE)).
