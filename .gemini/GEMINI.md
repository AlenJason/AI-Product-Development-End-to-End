# ECC Guidelines & Rules for Gemini

This file provides Gemini AI agents with the baseline ECC workflow, review standards, API design rules, and security checks adapted for this project.

## 1. Core Workflow

1. **Plan before editing**: Outline approach, impact on API contracts, and models before making changes.
2. **Contract-first & Test-first**:
   - Backend APIs must conform strictly to [[plan-data-contract]] and REST API design patterns.
   - Run existing unit/e2e tests (`npm test` in `backend_api`, `flutter test` in `frontend_app`) before and after changes.
3. **Review for Security & Secrets**: Never hardcode API keys or credentials; use `.env` / environment variables.
4. **Resilience & Fallbacks**: All AI/Gemini endpoints must handle timeouts, malformed responses, and quota exhaustion gracefully.

## 2. API Design Standards (ECC `api-design` Skill)

- **URL Structure**: Nouns, plural, kebab-case (e.g., `/api/v1/plans`, `/api/v1/auth/login`, `/api/v1/meals/swap`).
- **HTTP Methods**: GET (Safe/Idempotent), POST (Create/Action), PUT (Full Replace), PATCH (Partial), DELETE.
- **Status Codes**: 
  - `200 OK`, `201 Created`, `204 No Content`
  - `400 Bad Request` (Format/Validation), `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `409 Conflict`, `422 Unprocessable Entity`, `429 Too Many Requests`
  - `500 Internal Server Error`, `504 Gateway Timeout`
- **Error Format**:
  ```json
  {
    "error": {
      "code": "validation_error",
      "message": "Human readable message",
      "details": []
    }
  }
  ```

## 3. Gemini SDK & Service Rules

- **SDK**: Use `@google/genai` (Node.js SDK) exclusively in `backend_api/src/plan/gemini.service.ts`.
- **Response Format**: Use `generationConfig.responseMimeType: 'application/json'`.
- **Timeout Management**:
  - `GEMINI_TIMEOUT_MS` (default 20,000 ms per call).
  - `GEMINI_TOTAL_TIMEOUT_MS` (default 40,000 ms across retries).
  - Handle `504 DEADLINE_EXCEEDED` & `AbortError` as `GeminiTimeoutError`.
- **Retry Policy**: Maximum 1 retry (`generateWithRetry`). If failed/timed out, fall back to sample curated plans.
- **Prompt Safety**: Enforce `ingredientAvoidRule()`, `exerciseAvoidRule()`, and strict macro distributions.
