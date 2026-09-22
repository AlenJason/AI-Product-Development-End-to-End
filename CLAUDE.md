# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**SmartFit AI** is a VKU (Vietnam-Korea University of Information and Communication Technology) capstone project ("AI Product Development End-to-End"): an adaptive meal & workout planner for a Vietnamese audience. It plans a rolling 3-day cycle of Vietnamese home meals and bodyweight workouts, lets the user swap a meal/exercise for an AI-suggested equivalent, adapts the next day's plan from end-of-day feedback, and generates a grocery checklist.

Full product spec, target users, phased scope (MVP vs. advanced features), the planned NestJS↔Gemini JSON contract, and the weekly roadmap live in [BRD.md](BRD.md) — read it before making scope decisions or designing the backend API, since it is the source of truth for requirements.

## Repository layout and current state

This is a monorepo with three components:

- **`frontend_app/`** — Flutter app. UI-first: screens are built against hardcoded/mock data models, with no network layer wired up yet (`pubspec.yaml` still only declares stock `flutter`, `cupertino_icons`, `flutter_lints` — no `http`, `provider`, or `shared_preferences` despite these being named in the BRD's tech choices). Screen navigation is driven by a local enum (`AppScreen` in `lib/main.dart`), not a router package. **Not yet wired to `backend_api/`.**
- **`backend_api/`** — NestJS (TypeScript) service, scaffolded and working: `GET /health` and `POST /api/v1/generate-plan` (see Backend architecture below). Request/response DTOs validated with `class-validator`; Gemini call is wired but falls back to a bundled `sample-plan.json` when `GEMINI_API_KEY` is unset or the AI response fails the nutrition sanity check (BRD NFR-2, NFR-4).
- **`ai_workspace/`** — standalone Node/TypeScript project (own `package.json`, unrelated to `backend_api/`'s dependencies) for iterating on the Gemini prompt via `npm run experiment` before copying the finalized prompt into `backend_api/src/plan/gemini.service.ts`.

When asked to "connect the app to the backend," the backend now exists and runs locally — the remaining work is adding `http`/state management to `frontend_app/` and pointing it at `backend_api`'s endpoints.

## Commands

Frontend (`frontend_app/`):

```bash
flutter pub get                 # install dependencies
flutter run -d chrome           # run on Chrome (fastest loop for UI-only work, no device needed)
flutter run                     # run on a connected device/emulator
flutter analyze                 # static analysis (flutter_lints, default rule set)
flutter test                    # run all tests
flutter test test/widget_test.dart   # run a single test file
```

Backend (`backend_api/`):

```bash
npm install
cp .env.example .env            # fill in GEMINI_API_KEY (optional — falls back to sample data without it)
npm run start:dev               # http://localhost:3000, Swagger UI at /docs
npm run build                   # tsc via Nest compiler; verifies the project compiles
npm test                        # vitest unit tests
npm run test:e2e                # vitest e2e tests (test/app.e2e-spec.ts)
```

Note: `nest-cli.json` has `compilerOptions.assets` copying `plan/data/*.json` into `dist/` on build — if you add another non-`.ts` file under `src/` that needs to ship, add it there too, or it silently won't exist at runtime (this bit the initial `sample-plan.json` wiring).

AI workspace (`ai_workspace/`, independent Node project):

```bash
npm install
cp .env.example .env            # fill in GEMINI_API_KEY
npm run experiment              # runs generate-plan-experiment.ts
```

## Backend architecture (`backend_api/`)

- `src/app.controller.ts` / `app.service.ts` — `GET /health`.
- `src/plan/` — the `/api/v1/generate-plan` feature:
  - `dto/create-plan.dto.ts` + `dto/restrictions.dto.ts` — request shape, matches BRD.md §6.1 (`age`, `gender`, `height_cm`, `weight_kg`, `activity_level`, `goal`, `restrictions`).
  - `enums/` — `ActivityLevel` (+ `ACTIVITY_MULTIPLIER`), `Goal` (+ `GOAL_CALORIE_ADJUSTMENT`), `Gender`. These encode the Mifflin-St Jeor multipliers/adjustments, not just labels.
  - `plan.service.ts` — `computeDailyTarget()` does the BMR (Mifflin-St Jeor) → TDEE → goal-adjusted target-calorie math (BRD FR-1.5). `generatePlan()` orchestrates: calls `GeminiService`, retries once if `isNutritionWithinBounds()` fails, then falls back to `data/sample-plan.json` (with `daily_target` overwritten by the just-computed values, since the sample only has real day-1 data).
  - `gemini.service.ts` — wraps `@google/generative-ai`, builds the Vietnamese system prompt inline. `isConfigured` is false when `GEMINI_API_KEY` is unset; callers must check it rather than assuming Gemini is reachable.
  - `nutrition-sanity.util.ts` — per-meal-type calorie bounds from BRD NFR-4 (breakfast 250–600 kcal, lunch/dinner 400–800 kcal).
  - `interfaces/plan.interface.ts` — response types matching BRD.md §6.2, including `GroceryItem.source_meal_ids` (used to sync the grocery checklist when a meal is swapped per FR-4.1 — not yet implemented, just modeled).
- The project uses ESM (`"type": "module"` in `package.json`) — relative imports need explicit `.js` extensions even though the source is `.ts` (e.g. `import { AppService } from './app.service.js'`).
- Swagger is mounted at `/docs`, global `ValidationPipe({ whitelist: true, transform: true })` is set in `main.ts`.

## Frontend architecture

- `lib/main.dart` — app entry point and `MainShell`, a `StatefulWidget` that owns all top-level navigation state (`AppScreen` enum: onboarding → loading → dashboard → grocery) and the bottom nav bar. There is no named-route or router package; screen switching is a `setState` + `switch` in `_buildBody()`.
- `lib/screens/` — one file per screen (`onboarding_screen.dart`, `loading_screen.dart`, `dashboard_screen.dart`, `grocery_screen.dart`). Screens currently render mock data defined inline or in `lib/models/`, not data fetched from an API.
- `lib/models/meal_plan.dart` — plain Dart data classes (`MealItem`, `DayPlan`, `WorkoutExercise`, `GroceryItem`, `GroceryCategory`, `MacroNutrient`) used by the screens. These are UI view-models, not yet `fromJson`/`toJson` mappings of the backend's planned response shape (BRD.md section 6 documents that target JSON schema — the BRD suggests generating Dart classes for it via quicktype.io once the backend contract is real).
- `lib/widgets/` — shared UI pieces (`macro_ring.dart`, `feedback_bottom_sheet.dart`).

UI strings, labels, and comments are in Vietnamese throughout the existing code — match this when adding to the same screens/widgets.

## Working conventions

- Git commit subjects in this repo are written in Vietnamese; follow the existing style for consistency.
- BRD.md is versioned and marked "Approved" — treat feature scope changes as needing to reconcile with it, not silently diverge.
