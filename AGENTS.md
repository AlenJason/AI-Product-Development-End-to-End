# AGENTS.md — SmartFit AI

> Project instruction file for AI coding agents (OpenAI Codex, ChatGPT, Copilot, Cursor, Windsurf, Jules, Antigravity) based on the [`AGENTS.md` open standard](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
> 
> **Single source of truth for execution roadmap:** [`docs/PLAN.md`](docs/PLAN.md). Read its actual statuses, acceptance criteria, and decisions D1–D6 before implementing features.
> **Requirements & API contracts:** [`BRD.md`](BRD.md) (v2.6.0).

---

## 1. Project Overview & Architecture

**SmartFit AI** is an adaptive meal and bodyweight workout planner for a Vietnamese audience (VKU Capstone project). It generates a rolling 3-day cycle of Vietnamese home meals and bodyweight workouts, allows swapping meals/exercises with AI-suggested equivalents, adapts subsequent days from end-of-day feedback, and creates organized grocery checklists.

### Monorepo Structure

- **`backend_api/`**: NestJS 12 (TypeScript, Node.js ESM).
  - **Database:** TypeORM with MySQL (`smartfit_db`) for production/dev persistence; in-memory SQLite (`better-sqlite3`) for automated unit & e2e testing.
  - **AI Engine:** Groq API (`PLAN_AI_PROVIDER=groq`, model `openai/gpt-oss-120b` via `GroqPlanService`) with graceful fallback to bundled `src/plan/data/sample-plan.json` when `GROQ_API_KEY` is absent or network fails.
  - **Auth:** Email + Password with `scrypt` hashing, 7-day JWT, plus Guest Mode (`AUTH_MODE=mock`).
  - **Documentation:** Swagger UI at `http://localhost:3000/docs` (`/docs-json`).
- **`frontend_app/`**: Flutter 3.x cross-platform app (Android, iOS, macOS, Web).
  - **State Management:** `Provider` / `ChangeNotifier` (`PlanProvider`, `AuthProvider`, `GroceryProvider`).
  - **Persistence:** Local storage with `shared_preferences`.
  - **UI & Strings:** Vietnamese language UI strings, Material 3 with brand green theme.
- **`ai_workspace/`**: Standalone Node/TypeScript project for prompt iteration and experiment runs (`npm run experiment`) before migrating prompts to `backend_api`.
- **`docs/`**: `PLAN.md` (execution tracker), `BRD.md` (business requirements), architectural decision records (`D1`–`D6`), and credential setup instructions (`docs/SETUP_CREDENTIALS.md`).

---

## 2. Dev Environment Tips

### Setup & Package Management

- **Backend (`backend_api/`):**
  ```bash
  cd backend_api
  npm install
  cp .env.example .env     # Optional: GROQ_API_KEY, AUTH_MODE, MySQL config
  npm run start:dev        # Starts NestJS watch mode on http://localhost:3000
  ```
- **Frontend (`frontend_app/`):**
  ```bash
  cd frontend_app
  flutter pub get
  flutter run -d chrome    # Web debug (defaults to backend at http://localhost:3000)
  # For Android emulator:
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  # For physical device (replace with machine LAN IP):
  flutter run --dart-define=API_BASE_URL=http://192.168.1.x:3000
  ```
- **Prompt Experiments (`ai_workspace/`):**
  ```bash
  cd ai_workspace
  npm install
  npm run experiment
  ```

### Environment Flags & Mock Mode

- The backend runs in **mock/fallback mode by default** without external API keys:
  - No `GROQ_API_KEY` or `GEMINI_API_KEY` → safely falls back to `sample-plan.json` (`source: "sample"`).
  - `AUTH_MODE=mock` → accepts `id_token` as `mock:<email>`, enabling guest/mock testing without Google OAuth credentials.
  - Production safety: Backend will refuse to boot with `NODE_ENV=production` and `AUTH_MODE=mock` unless `ALLOW_MOCK_AUTH=true`.

---

## 3. Testing & Verification Instructions

### Verification Contract (Definition of Done)

1. **Never mark a task DONE without running the test suite.**
2. **Never delete, bypass, or comment out an existing failing test** to force tests to pass. Always fix the underlying implementation.
3. Every contract change between Backend and Frontend requires updating fixtures and verifying both sides.

### Backend Verification (`backend_api/`)

Run these commands before finishing changes in `backend_api/`:

```bash
# 1. Typecheck (checks both src/ and test/ files)
npm run typecheck

# 2. Linter (oxlint with type-aware rules)
npm run lint

# 3. Unit tests (Vitest: 39+ files, 500+ tests)
npm test

# 4. Run a single test file during development:
npx vitest run src/plan/plan.service.spec.ts
npx vitest run -t "should calculate BMR correctly"

# 5. E2E tests (in-memory SQLite, isolated mock app)
npm run test:e2e

# 6. Production build check & smoke test
npm run build
npm run test:smoke

# 7. Update contract fixtures (when BRD §6 API contracts change):
npm run fixtures:update
```

### Frontend Verification (`frontend_app/`)

Run these commands before finishing changes in `frontend_app/`:

```bash
# 1. Static analysis (flutter_lints, zero issues required)
flutter analyze

# 2. Run all unit & widget tests (190+ tests, no backend required)
flutter test

# 3. Run a single test file:
flutter test test/services/api_client_test.dart
flutter test test/models/contract_test.dart

# 4. Code formatting (120 line length standard for newer files)
dart format --line-length 120 lib/ test/
```

---

## 4. Architectural & Coding Conventions

### Backend Guidelines (`backend_api/`)

1. **ESM Imports (`"type": "module"`):**
   - Relative TypeScript imports **MUST** include the explicit `.js` extension, e.g.:
     ```typescript
     import { PlanService } from './plan.service.js';
     import { User } from '../database/entities/user.entity.js';
     ```
2. **TypeORM Relations:**
   - Always wrap entity relations with `Relation<T>`, e.g., `user: Relation<User>;`. Without this, ESM circular dependencies crash on boot with `Cannot access 'User' before initialization`.
   - Never use `synchronize: true` in production or shared database configs. Schema changes must go through TypeORM migrations (`migrationsRun: true`).
3. **DTOs and Validation:**
   - All incoming payloads must be strictly typed and validated using `class-validator` and `class-transformer`.
   - Global validation pipe strips unwhitelisted properties (`whitelist: true, transform: true`).
4. **Pure Calculation Separation:**
   - Keep health formulas (BMR via Mifflin-St Jeor, TDEE, macro ratios 25/45/30) in pure, side-effect-free functions (e.g., `daily-target.ts`).

### Frontend Guidelines (`frontend_app/`)

1. **Provider Architecture:**
   - Widgets must **NEVER** call `ApiClient` or `http` directly.
   - All server communication and state changes go through `PlanProvider`, `AuthProvider`, or `GroceryProvider`.
2. **API Contract Serialization:**
   - Hand-written JSON models (`lib/models/api/`) must guarantee `fromJson(json).toJson() == json`.
   - Missing fields, invalid types, or unknown enum values must throw descriptive `FormatException`s.
   - Use `num` for all numeric fields to prevent integer/double serialization mismatches.
3. **Error Handling & Localization:**
   - All API failures must map to a user-friendly `ApiException` with localized Vietnamese error messages.
   - Wrap `ListTile` widgets in a `Material` widget (not a colored `Container`) to satisfy Flutter framework assertions.

### Git & Commit Conventions

- Commit subjects follow the existing style (either conventional commits or clear descriptive Vietnamese):
  - `feat(app): ...` / `feat(plan): ...`
  - `chore(backend): ...` / `fix(auth): ...`
  - Or clear Vietnamese commit summaries matching repo history.

---

## 5. Security, Safety & Privacy Guardrails (Strict)

> [!CAUTION]
> These rules protect user safety and privacy and must NEVER be violated.

1. **Sensitive Health Data Privacy (Design Decisions D4 & D5):**
   - User allergies, injuries, and medical conditions (`allergies`, `injuries`, `health_conditions`) must **NEVER** be persisted in the database (`users` or `plan_records`) or written to server logs.
   - They are sent per-request from client local storage, processed in ephemeral memory, and discarded.
2. **Clinical Safety Constraints (Design Decision D6):**
   - **BMI < 18.5:** Selecting "Giảm mỡ" (Cut/Weight Loss) must be rejected with HTTP 400 at the backend and blocked in the UI form. Only "Duy trì" or "Tăng cơ" allowed.
   - **Minimum Age:** Strictly 18 years old (18–100).
   - **Pregnancy / Breastfeeding:** Caloric deficit is strictly forbidden; workouts are locked to Level 1.
   - **Danger Signs (D2):** When a user reports danger symptoms (chóng mặt, khó thở, đau ngực) in end-of-day feedback:
     - **DO NOT** trigger AI plan rebalancing.
     - Advise stopping exercise and consulting a doctor; automatically assign rest or light walking for the next day.
3. **Secrets & Credentials:**
   - Never commit `.env`, API keys (`GROQ_API_KEY`, `GEMINI_API_KEY`, `JWT_SECRET`), or service account JSON files to git.

---

## 6. Directory-Specific Routing for Agents

When implementing tasks, navigate directly to these core modules:

| Feature / Domain | Primary Locations |
|---|---|
| **Plan Generation & Calculation** | `backend_api/src/plan/daily-target.ts`<br>`backend_api/src/plan/plan.service.ts`<br>`backend_api/src/plan/plan-validation.ts` |
| **LLM Prompts & Fallback Data** | `backend_api/src/plan/gemini.service.ts` / `groq-plan.service.ts`<br>`backend_api/src/plan/data/sample-plan.json`<br>`backend_api/src/plan/data/restriction-keywords.json` |
| **Swap & Feedback Handlers** | `backend_api/src/plan/adjust/`<br>`backend_api/src/plan/swap-pools.ts` |
| **Auth & User Accounts** | `backend_api/src/auth/`<br>`backend_api/src/database/entities/user.entity.ts` |
| **Database Migrations** | `backend_api/src/database/migrations/`<br>`backend_api/src/database/data-source.ts` |
| **Flutter Screens & Navigation** | `frontend_app/lib/screens/`<br>`frontend_app/lib/main.dart` (`AppScreen` enum & `MainShell`) |
| **Flutter State Providers** | `frontend_app/lib/providers/plan_provider.dart`<br>`frontend_app/lib/providers/auth_provider.dart`<br>`frontend_app/lib/providers/grocery_provider.dart` |
| **API Client & Contracts** | `frontend_app/lib/services/api_client.dart`<br>`frontend_app/lib/models/api/` |
| **Project Roadmap & Status** | `docs/PLAN.md` |

---

## 7. Agent Continuous Feedback Loop

- If an AI agent encounters a recurring bug, tooling mismatch, or non-obvious environment quirk during development, **update this `AGENTS.md` file** with the resolution so future agent sessions inherit the fix.
- Keep instructions concise, factual, and actionable. Do not add speculative guidance.
