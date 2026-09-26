# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**SmartFit AI** is a VKU (Vietnam-Korea University of Information and Communication Technology) capstone project ("AI Product Development End-to-End"): an adaptive meal & workout planner for a Vietnamese audience. It plans a rolling 3-day cycle of Vietnamese home meals and bodyweight workouts, lets the user swap a meal/exercise for an AI-suggested equivalent, adapts the next day's plan from end-of-day feedback, and generates a grocery checklist.

Full product spec, target users, phased scope (MVP vs. advanced features), the planned NestJS↔Gemini JSON contract, and the weekly roadmap live in [BRD.md](BRD.md) — read it before making scope decisions or designing the backend API, since it is the source of truth for requirements.

## How work is planned

[docs/PLAN.md](docs/PLAN.md) is the execution roadmap: phases 0–9 with checkboxes, plus decisions D1–D4 that resolved mismatches between the Flutter UI and the backend/BRD (calorie adjustment −300/+250, 3-question feedback with a danger-sign rule, grocery `name`/`quantity` split, free-text health inputs kept on-device only). Work the phases in order and tick the checkbox when a step is done.

Every phase from 1 onward goes through `/feature-explore` → `/feature-plan` before coding; artifacts land in `docs/superpowers/brainstorms/` and `docs/superpowers/plans/<slug>/`. `/feature-build` as installed assumes a Next.js layout and does not recognize `backend_api/src/` or Flutter — implement from the specs directly unless a repo-local adapted copy exists in `.claude/skills/`.

Both external services run in a mock mode by default so everything works without credentials: no `GEMINI_API_KEY` → bundled sample data; `AUTH_MODE=mock` (default) → `id_token` of the form `mock:<email>` accepted, everything after that (user row, JWT, history) is real; the backend refuses to boot with `NODE_ENV=production` + mock unless `ALLOW_MOCK_AUTH=true`. How to switch to real credentials: [docs/SETUP_CREDENTIALS.md](docs/SETUP_CREDENTIALS.md).

## Repository layout and current state

This is a monorepo with three components:

- **`frontend_app/`** — Flutter app. Since phase 5 it has the API layer (`http`, `provider`, `shared_preferences`; models in `lib/models/api/`, `ApiClient` in `lib/services/`, `PlanProvider`/`AuthProvider` in `lib/providers/`), but the **screens still render hardcoded mock data** through the old view-models in `lib/models/meal_plan.dart` — wiring them to the providers is phase 6. Screen navigation is driven by a local enum (`AppScreen` in `lib/main.dart`), not a router package.
- **`backend_api/`** — NestJS (TypeScript) service, scaffolded and working: `GET /health` and `POST /api/v1/generate-plan` (see Backend architecture below). Request/response DTOs validated with `class-validator`; Gemini call is wired but falls back to the bundled 3-day `sample-plan.json` when `GEMINI_API_KEY` is unset, Gemini times out, or its output fails contract validation (BRD NFR-2, NFR-4) — the response's `source` field (`gemini` / `sample`) says which one was used. Accounts (Google Sign-In, mock mode by default), `DELETE /api/v1/me`, and plan history on SQLite/TypeORM are built (BRD FR-6, FR-7; PLAN.md phase 3). Meal/exercise swap and end-of-day feedback (BRD §6.4) are built too (PLAN.md phase 4): stateless endpoints that take `{ profile, plan, … }` and return the whole new plan.
- **`ai_workspace/`** — standalone Node/TypeScript project (own `package.json`, unrelated to `backend_api/`'s dependencies) for iterating on the Gemini prompt via `npm run experiment` before copying the finalized prompt into `backend_api/src/plan/gemini.service.ts`.

When asked to "connect the app to the backend," the plumbing exists (phase 5): screens should read and write through `PlanProvider`/`AuthProvider` (never call `ApiClient` or `http` directly) and show `ApiException.message` on failure. The web build needs the backend's CORS (`CORS_ORIGINS`, see Backend architecture).

## Commands

Frontend (`frontend_app/`):

```bash
flutter pub get                 # install dependencies
flutter run -d chrome           # run on Chrome; backend defaults to http://localhost:3000 (Android emulator: 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000   # real phone: LAN IP of the machine running backend_api
flutter run                     # run on a connected device/emulator
flutter analyze                 # static analysis (flutter_lints, default rule set)
flutter test                    # run all tests (no backend needed; fixtures in test/fixtures/)
flutter test test/services/api_client_test.dart   # run a single test file
flutter test integration_test -d emulator-5554   # manual only: real backend_api from the device (mock mode, no GEMINI_API_KEY); wipes the app's saved data there; not in CI
```

Backend (`backend_api/`):

```bash
npm install
cp .env.example .env            # all optional: no GEMINI_API_KEY → sample data; AUTH_MODE=mock → fake logins
npm run start:dev               # http://localhost:3000, Swagger UI at /docs
npm run build                   # tsc via Nest compiler; verifies the project compiles
npm run typecheck               # tsc --noEmit over src/ and test/ incl. specs (build and vitest both skip type-checking tests)
npm run lint                    # oxlint (type-aware); typescript/no-misused-spread is off on purpose — DTOs are data-only
npm test                        # vitest unit tests (src/**/*.spec.ts)
npx vitest run src/plan/plan.service.spec.ts   # a single test file
npm run test:e2e                # vitest e2e tests (test/*.e2e-spec.ts)
npm run fixtures:update         # rewrite frontend_app/test/fixtures/ after changing the BRD §6 contract, then fix the Dart models
npm run test:smoke              # after npm run build: boots dist/main.js and calls /health, login, generate-plan, history, meal/exercise swap, feedback
npm run measure:gemini          # after npm run build: calls the REAL Gemini API with the backend's prompts/checks — costs quota, never in tests/CI
```

Note: `nest-cli.json` has `compilerOptions.assets` copying `plan/data/*.json` into `dist/` on build — if you add another non-`.ts` file under `src/` that needs to ship, add it there too, or it silently won't exist at runtime (this bit the initial `sample-plan.json` wiring).

Tests never call the real Gemini or Google APIs and never touch a real database file. `test/fake-gemini-server.ts` is a local HTTP server that speaks Gemini's `generateContent` format; the real `@google/genai` SDK is pointed at it through `GEMINI_BASE_URL` (leave that empty in real runs). Every e2e file builds the app through `createTestApp()` (`test/test-app.ts`), which pins `DATABASE_PATH=:memory:`, `AUTH_MODE=mock`, the JWT/Google vars, and `GEMINI_*` *before* dynamically importing `AppModule` (a developer's `.env` may hold real values) and restores them on close; `loginMock()` logs in with `mock:<email>`. Unit tests that need a database use `createMemoryDataSource()` (`test/memory-data-source.ts`), which runs the real migration on an in-memory SQLite. Google ID token verification is tested offline by signing tokens with a throwaway RSA key and stubbing `getFederatedSignonCertsAsync()`. Vitest runs `.ts` sources directly, so it cannot catch failures that only exist in the compiled build (missing assets, ESM circular imports between entities) — `npm run test:smoke` covers those. `test/contract-fixtures.e2e-spec.ts` compares real responses with the JSON fixtures committed in `frontend_app/test/fixtures/` (UUIDs, token and timestamps normalised; `RandomSource` fixed) — the Flutter tests use the same files, so a contract change fails on both sides until `npm run fixtures:update` is run and the Dart models are fixed. GitHub Actions: `.github/workflows/backend.yml` runs build + typecheck + unit + e2e + smoke on Node 24 and 26 on every push touching `backend_api/`, `ai_workspace/` or the fixtures; `.github/workflows/frontend.yml` runs `flutter analyze` + `flutter test` on Flutter 3.47.5 for `frontend_app/`. No secrets.

AI workspace (`ai_workspace/`, independent Node project):

```bash
npm install
cp .env.example .env            # fill in GEMINI_API_KEY
npm run experiment              # runs generate-plan-experiment.ts
```

## Backend architecture (`backend_api/`)

- `src/app.controller.ts` / `app.service.ts` — `GET /health`, which also reports whether Gemini is configured (`gemini: "configured" | "fallback"`) and the login mode (`auth_mode: "mock" | "google"`) — the quickest way to confirm a key was picked up. `.env` is read once at boot; `start:dev` watch mode does not restart on `.env` edits.
- `src/plan/` — `POST /api/v1/generate-plan`. The contract is BRD.md §6 (v2.5.0); the wiki article `docs/knowledge/wiki/plan-data-contract.md` maps it to code. Flow:
  1. `dto/create-plan.dto.ts` validates the request. `dto/restrictions.dto.ts` holds three free-text fields (`allergies`, `injuries`, `health_conditions`, ≤300 chars, default `''`) — sensitive health data: never persist or log them (BRD NFR-7).
  2. `daily-target.ts` — pure `computeDailyTarget()`: BMI, BMR (Mifflin-St Jeor), TDEE, target = `max(TDEE + goal adjustment, BMR)` (cut −300, bulk +250), macros 25/45/30. Returns `flooredToBmr` so the service can add a warning.
  3. `gemini.service.ts` — `@google/genai` (`client.models.generateContent()`, result via the `response.text` property; the old `@google/generative-ai` SDK is deprecated — don't reintroduce it). `buildPlanPrompt()` puts user text inside a `<du_lieu_nguoi_dung>` block after `sanitizeUserText()`, spells out what the backend will reject (`ingredientAvoidRule()` / `exerciseAvoidRule()` from the keyword matcher — without it Gemini read "seafood" more narrowly than the checker and served freshwater fish), and reads the allowed codes and calorie bounds from the enums/`mealCalorieBounds()`. Defaults come from measuring the real API (`npm run measure:gemini`, 2026-09-24): model `gemini-3.5-flash` (3.8 kept returning 503), `GEMINI_THINKING=off` (plans take 8–13 s instead of 37–42 s with the model's own thinking), `GEMINI_TIMEOUT_MS=20000` per call and `GEMINI_TOTAL_TIMEOUT_MS=40000` across the retry — `generateWithRetry()` only retries with ≥ 5 s left and gives the retry only the remaining time. The free tier allows 20 requests/day per model. Never pass `retryOptions` to the SDK (it would retry up to 5× with up to 60 s backoff).
  4. `plan-validation.ts` — `parsePlanContent(raw, target)`: class-validator against `dto/plan-content.dto.ts`, then `findPlanViolations(plan, target)`: meal calories as a share of the daily target (`MEAL_CALORIE_SHARE`: breakfast 15–35 %, lunch/dinner 25–45 %), each day's total within [max(85 % target, BMR); 110 % target], calories within 15 % of 4P+4C+9F, no repeated dish. The old fixed bounds (250–600 / 400–800) capped a day at 2200 kcal, below many users' targets, and the day total was never checked. Unknown enum values must fail, never skip a check.
  5. `plan.service.ts` — orchestration: Gemini through `generateWithRetry()` (`gemini-retry.ts`: retry once, never after a timeout), output also rejected if it contains a recognised allergen → otherwise `data/sample-plan.json`, filtered by `filterPlanByRestrictions()` and scaled per day to the target by `meal-scaling.ts` (the file is written for ~1550 kcal/day), then validated by the same function. Warning texts live in `plan-warnings.ts` and never quote user text.
  6. `plan-assembly.ts` — `assemblePlan()` assigns `plan_id` (UUID) and `m{day}_{n}` / `e{day}_{n}` ids, orders meals, and `buildGroceryList()` recomputes the grocery list from structured ingredients. Grocery lists are never taken from Gemini or the client.
  - `dto/meal-plan-response.dto.ts` holds the response classes Swagger shows; `MealDto` / `ExerciseDto` extend the content DTOs with ids. `enums/` holds the fixed codes (meal type, ingredient category/unit, muscle group, exercise tags, plan source).
- `src/plan/restriction-matcher.ts` + `data/restriction-keywords.json` — keyword matcher for allergies/injuries (mock mode, D4) and for re-checking every Gemini result. Ingredient names are always compared with Vietnamese accents ("cá" fish ≠ "cà" tomato, "bò" ≠ "bơ"); user text is compared accent-insensitively only when typed without accents (NFD does not split "đ" — replaced by hand). It returns keywords/tags and a `hasUnrecognized` flag, never the user's text. `swap-pools.ts` loads and validates `data/swap-meals.json` (21 dishes) and `data/swap-exercises.json` (39 exercises with `level` 1–3) at boot; every exercise in `sample-plan.json` must be in the pool so its level is known.
- `src/plan/adjust/` — `POST /api/v1/meals/swap`, `/exercises/swap`, `/feedback` (BRD §6.4) behind `OptionalJwtAuthGuard`. `readClientPlan()` recomputes the target from `profile` (mismatch with the plan's `daily_target` → 409) and checks ids/positions + `findPlanViolations()` (→ 400); `rebuildPlan()` keeps `plan_id`/`source` and recomputes ids, grocery list and warnings. Meal swap: Gemini first (±10 % calories, same meal type, no repeat, no allergen), then the pool scaled to the old meal's calories, else 422. Exercise swap: Gemini first, accepted only if same muscle group, sets ≤ old, tags ⊆ old tags, no injury tag; then a lower-`level` pool exercise, else 422. Feedback: fixed rules in `workout-rules.ts` (danger sign → rest day and `safety_warning`, skipping everything else), meals re-planned by Gemini on over/under-eating (never below BMR; no key → unchanged + warning), day 3 → a new plan via `PlanService.generatePlan(profile, { feedbackNote })`. Logged in: swap/feedback update the saved plan (`HistoryService.update()`), day-3 plans are saved as new. `test/plan-fixtures.ts` holds the shared fixtures (`samplePlan()`, `geminiAnswering()`, `firstPick`).
- `src/database/` — TypeORM 1.x on SQLite via `better-sqlite3@12` (TypeORM 1.1 only accepts `^12`; there is no `sqlite3` or `node:sqlite` driver). Entities `User` (`google_sub` unique; mock mode uses `mock:<email>`) and `PlanRecord` (`id` = the plan's `plan_id`, `user_id` FK with `ON DELETE CASCADE`, `plan_json` = the exact response, `created_at` set in code with millisecond precision because SQLite's `datetime('now')` default only has seconds). Schema changes go through migrations only (`migrationsRun: true`, never `synchronize`); `migrations.spec.ts` fails with the missing SQL if an entity drifts from the migrations. Relations between the two entities are typed `Relation<...>` — without it the compiled ESM build crashes at boot with `Cannot access 'User' before initialization` while every vitest test still passes.
- `src/auth/` — `resolveAuthConfig()` validates env at boot and throws (so the app does not start) on a bad config: unknown `AUTH_MODE`, google mode without `GOOGLE_CLIENT_ID` or with a `JWT_SECRET` under 32 chars, mock mode with `NODE_ENV=production` unless `ALLOW_MOCK_AUTH=true`. `IdTokenVerifier` is an abstract-class DI token resolved to `MockIdTokenVerifier` or `GoogleIdTokenVerifier` (`google-auth-library`; always passes `audience` — without it tokens issued to other apps are accepted — and never logs the library's error text, which embeds the token and email). `AuthService` find-or-creates users (handles the unique-constraint race), signs HS256 JWTs whose payload is only `sub`, and re-loads the user on every request so a deleted account gets 401. `JwtAuthGuard` (required) / `OptionalJwtAuthGuard` (no header → guest, bad header → 401) and `@CurrentUser()` live in `jwt-auth.guard.ts`. Routes: `POST /api/v1/auth/google`, `DELETE /api/v1/me`.
- `src/history/` — `GET /api/v1/plans/history` (50 newest) and `/:id` (another user's plan → 404, non-UUID → 400). `HistoryService.save()` returns `false` instead of throwing, so `generate-plan` still returns the plan (with a `historyNotSaved` warning) when saving fails.
- The project uses ESM (`"type": "module"` in `package.json`) — relative imports need explicit `.js` extensions even though the source is `.ts` (e.g. `import { AppService } from './app.service.js'`).
- `src/app.setup.ts` — `configureApp()` applies the global `ValidationPipe({ whitelist: true, transform: true })`, CORS from `resolveCorsOptions()` (`src/cors-options.ts`: `CORS_ORIGINS` comma list; empty in dev → any port on `http://localhost`/`http://127.0.0.1` for `flutter run -d chrome`; empty with `NODE_ENV=production` → CORS off, mobile only; malformed → boot fails), and mounts Swagger at `/docs` (JSON at `/docs-json`), with bearer auth so Swagger shows an Authorize button. Both `main.ts` and the e2e tests call it; put new global app config there, not in `main.ts`.

## Frontend architecture

- `lib/main.dart` — `main()` awaits `SharedPreferences.getInstance()` before `runApp`, builds one `ApiClient(baseUrl: resolveApiBaseUrl())` and both providers; `SmartFitApp(auth:, plans:)` wraps `MaterialApp` in a `MultiProvider` (tests inject providers backed by `test/fake_backend.dart`). `MainShell` owns navigation (`AppScreen` enum: onboarding → loading → dashboard → grocery; `setState` + `switch` in `_buildBody()`, no router); it opens on the dashboard if `PlanProvider.hasPlan`, else onboarding. The existing files are not `dart format`-ed — don't reformat whole files (it reflows unrelated widgets); CI doesn't check format.
- `lib/config/api_config.dart` — `resolveApiBaseUrl()`: `--dart-define=API_BASE_URL`, else `http://10.0.2.2:3000` on Android, `http://localhost:3000` elsewhere.
- `lib/models/api/` — hand-written models for BRD §6 (`MealPlan`, `Profile`, `AuthResult`, `FeedbackResult`…; enums in `codes.dart`). `fromJson(json).toJson()` must equal `json` exactly — swap/feedback send the whole plan back and the server checks every id and number, so numbers are read as `num`; missing fields, wrong types and unknown codes throw `FormatException` naming the field (`json_read.dart`). `test/models/contract_test.dart` round-trips the backend's fixtures.
- `lib/models/meal_plan.dart` — old UI view-models (`MealItem`, `DayPlan`, `GroceryCategory`…) the screens still use with hardcoded data; removed in phase 6.
- `lib/services/api_client.dart` — `ApiClient` for all 9 endpoints: 60 s timeout for calls that may hit Gemini (the backend gives up at 40 s), 15 s otherwise; bodies decoded as UTF-8 from `bodyBytes`; every failure becomes a sealed `ApiException` (`api_exception.dart`) whose `message` is Vietnamese UI text (400 details stay in `ValidationException.details`); a 401 on a request that carried a token calls `onUnauthorized`. Never log request/response bodies — they carry health data.
- `lib/providers/` — `PlanProvider` (profile + plan in `shared_preferences` keys `smartfit.profile.v1` / `smartfit.plan.v1`; `busy` flag, calls while busy are ignored; corrupt data dropped) and `AuthProvider` (`smartfit.access_token`, `smartfit.user.v1`; signs out on 401).
- `lib/screens/` — one file per screen; `lib/widgets/` — `macro_ring.dart`, `feedback_bottom_sheet.dart`.
- Network config per platform: `INTERNET` in the main Android manifest, cleartext HTTP only in the debug manifest, iOS `NSAllowsLocalNetworking`, macOS `network.client` in both entitlements (Dart's HTTP isn't subject to Android's cleartext policy — checked on Android 16 — the debug flag is only for platform-stack networking). Android `compileSdk = 36` (`shared_preferences_android` requires it; `targetSdk` stays 34). CI doesn't build an APK, so after adding a package with a native plugin run `flutter build apk --debug` locally.

UI strings, labels, and comments are in Vietnamese throughout the existing code — match this when adding to the same screens/widgets.

## Working conventions

- Git commit subjects in this repo are written in Vietnamese; follow the existing style for consistency.
- BRD.md is versioned and marked "Approved" — treat feature scope changes as needing to reconcile with it, not silently diverge.
