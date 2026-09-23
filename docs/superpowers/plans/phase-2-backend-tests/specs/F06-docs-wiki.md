# F06 — Wiki, CLAUDE.md, hướng dẫn, Changelog, tiến độ

## Feature

Ghi lại những gì giai đoạn 2 học được để các giai đoạn sau (và AI agent khác) không phải tìm lại:

- Bài wiki mới `gemini-integration.md`: hành vi thật của SDK `@google/genai` đã kiểm bằng server giả (brainstorm F1–F4), cách `GeminiService` dùng SDK, cách test không cần khoá. Đây là bài trigger thiếu từ giai đoạn 1.
- Ràng buộc mới: test không bao giờ gọi Gemini thật; cấu hình app chỉ nằm ở `configureApp()`.
- `CLAUDE.md`: lệnh chạy một file test, cấu trúc test, CI.
- `SETUP_CREDENTIALS.md`: `GEMINI_BASE_URL` phải để trống khi chạy thật.
- README: Changelog và chỗ xem kết quả CI.
- `PLAN.md`: đánh dấu xong giai đoạn 2, thêm bước 2.5, 2.6 (quyết định Q1, Q2).

## Scope

Docs:

- `docs/knowledge/wiki/gemini-integration.md` (mới)
- `docs/knowledge/wiki/critical-constraints.md`, `INDEX.md`, `wiki-triggers.md`, `log.md`
- `CLAUDE.md`, `docs/SETUP_CREDENTIALS.md`, `README.md`, `docs/PLAN.md`

## Implementation

### API Routes

Không sửa code.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

Feature này thêm ràng buộc #17, #18 và cập nhật lý do của #15 (đã có test khoá hành vi).

## Definition of Done

- [ ] `gemini-integration.md` tồn tại, có trong `INDEX.md`
- [ ] `critical-constraints.md` có #1–#18
- [ ] PLAN.md: giai đoạn 2 ghi `· M`, 2.1–2.6 đều `[x]`
- [ ] README có dòng Changelog giai đoạn 2 và link tab Actions
- [x] All API routes complete within deployment timeout — không áp dụng
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: `grep -c 'gemini-integration' docs/knowledge/wiki/INDEX.md` → `1`; `grep -c '^- \[x\] \*\*2\.' docs/PLAN.md` → `6`
2. **@auth**: không áp dụng
3. **@timeout**: không áp dụng
4. **@partial-fail**: mọi `[[link]]` trong wiki trỏ tới file có thật
5. **@token**: không áp dụng
6. **@db**: không áp dụng

## Tasks

### Task 1 — Bài wiki `docs/knowledge/wiki/gemini-integration.md`

```markdown
---
last_updated: 2026-09-24
tags: [gemini, sdk, kiem-thu]
---

# Tích hợp Gemini

Backend gọi Gemini qua SDK `@google/genai` ở đúng một chỗ: `GeminiService` (`backend_api/src/plan/gemini.service.ts`). Bài này ghi hành vi thật của SDK — đã kiểm ngày 2026-09-24 bằng SDK 2.24 chạy với server Gemini giả cục bộ, không cần khoá — và cách test phần này mà không bao giờ gọi Google. Ràng buộc liên quan: [[critical-constraints]] #8, #9, #12, #15, #17. Hợp đồng dữ liệu: [[plan-data-contract]].

## Hành vi SDK đã kiểm chứng

| Tình huống | SDK làm gì | `GeminiService` xử lý |
|---|---|---|
| Thành công | `POST {baseUrl}/v1beta/models/{model}:generateContent`, body có prompt và `generationConfig.responseMimeType`; đọc `candidates[0].content.parts[].text` thành `response.text` | `JSON.parse` → trả JSON thô cho `PlanService` kiểm hợp đồng |
| Hết `httpOptions.timeout` | Ném `DOMException` tên `AbortError` (là `instanceof Error`), đúng lúc hết giờ | Đổi thành `GeminiTimeoutError` → `PlanService` không gọi lại |
| HTTP 4xx/5xx (ví dụ khoá sai: 400) | Ném `ApiError`, có `status`; `message` là nguyên văn JSON lỗi của Google | Ném tiếp → `PlanService` log thông báo, gọi lại 1 lần, rồi dùng thực đơn mẫu |
| HTTP 500 khi **không** truyền `retryOptions` | Gửi đúng **1** request, không tự gọi lại | — |
| HTTP 500 khi **có** `retryOptions` | Tự gọi lại tới 5 lần, chờ tới 60 giây giữa các lần | Cấm dùng (#15) |
| `response.text` không phải JSON | — | Ném lỗi chung "không phải JSON hợp lệ", không đính kèm lỗi gốc của `JSON.parse` vì nó trích nội dung (#12) |

## Cấu hình

`GEMINI_API_KEY` (bắt buộc để dùng AI thật), `GEMINI_MODEL` (mặc định `gemini-3.8-flash`), `GEMINI_TIMEOUT_MS` (mặc định 15 000), `GEMINI_BASE_URL` (chỉ dùng khi test — để trống là gọi Google thật). Khoá tạo trên AI Studio trước 28/05/2026 là loại Standard và bị từ chối từ tháng 9/2026 — xem [[reference-materials]] mục 1.4.

## Test không cần khoá

`backend_api/test/fake-gemini-server.ts` dựng server HTTP cục bộ trả phản hồi đúng định dạng Gemini, đếm và lưu request, có chế độ trả JSON / văn bản / lỗi HTTP / không trả lời. SDK thật được trỏ vào đó qua `GEMINI_BASE_URL`:

- `src/plan/gemini.service.spec.ts` — hành vi bảng trên, gồm cả đếm request khi lỗi 500.
- `test/generate-plan.e2e-spec.ts` — trọn đường HTTP → `PlanService` → `GeminiService` → SDK → server giả. Ghim biến môi trường **trước** khi nạp `AppModule` vì máy dev có thể có khoá thật trong `.env`.

Tầng `PlanService` (`src/plan/plan.service.spec.ts`) dùng object `GeminiService` giả bằng `vi.fn()` để test logic gọi lại cho nhanh.

## Thử prompt với Gemini thật

`ai_workspace/` (`npm run experiment`) chép y nguyên prompt của `buildPlanPrompt()` và in thời gian phản hồi. Khi sửa prompt ở backend, sửa cả bản trong `ai_workspace/generate-plan-experiment.ts`.
```

### Task 2 — `critical-constraints.md`

Thay lý do của hàng #15 (cột thứ ba) bằng:

```
BRD NFR-1. SDK có cơ chế tự gọi lại (mặc định 5 lần, chờ tới 60 giây) nhưng chỉ bật khi có `retryOptions`; bật lên sẽ chồng lên lần gọi lại của `PlanService` và kéo request lên vài phút. Đã kiểm bằng SDK thật: lỗi 500 → đúng 1 request; `gemini.service.spec.ts` khoá hành vi này để lần nâng phiên bản SDK sau không làm đổi âm thầm.
```

Thêm sau hàng #16:

```
| 17 | Test **không bao giờ** gọi Gemini thật. Test cần Gemini dùng server giả `backend_api/test/fake-gemini-server.ts` qua `GEMINI_BASE_URL`; e2e ghim `GEMINI_API_KEY`, `GEMINI_BASE_URL`, `GEMINI_TIMEOUT_MS` **trước** khi nạp `AppModule`. `GEMINI_BASE_URL` luôn để trống khi chạy thật và khi deploy. | Máy dev có thể có khoá thật trong `.env`: test gọi thật sẽ chậm, tốn hạn mức, kết quả không cố định, và gửi dữ liệu test ra ngoài. CI không có khoá nào nên cũng không chạy được test gọi thật. |
| 18 | Cấu hình app (`ValidationPipe`, Swagger) chỉ nằm ở `configureApp()` (`backend_api/src/app.setup.ts`); `main.ts` và e2e cùng gọi hàm này. Thêm cấu hình toàn cục mới thì thêm vào đó, không thêm thẳng vào `main.ts`. | Nếu cấu hình nằm riêng ở `main.ts`, e2e chạy thiếu `ValidationPipe` và không bắt được lỗi 400 — đúng tình trạng trước giai đoạn 2. |
```

### Task 3 — `wiki-triggers.md`, `INDEX.md`, `log.md`

`wiki-triggers.md` — thay hàng trigger của `gemini-integration.md` và thêm `app.setup.ts` vào hàng `api-routes.md`:

```
| `backend_api/src/app.controller.ts`, `backend_api/src/app.service.ts`, `backend_api/src/app.setup.ts`, `backend_api/src/plan/plan.controller.ts`, `backend_api/src/plan/plan.module.ts`, `backend_api/src/main.ts` | `api-routes.md` |
| `backend_api/src/plan/gemini.service.ts`, `backend_api/test/fake-gemini-server.ts`, `ai_workspace/**` | `gemini-integration.md` |
```

`INDEX.md` — thêm sau hàng `[[plan-data-contract]]`:

```
| [[gemini-integration]]      | Hành vi thật của SDK Gemini (hết giờ, lỗi, không tự gọi lại), cách test không cần khoá |
```

`log.md` — thêm dòng cuối:

```
2026-09-24 — Giai đoạn 2 (PLAN.md): thêm bài [[gemini-integration]] (hành vi SDK kiểm bằng server Gemini giả); thêm ràng buộc #17 (test không gọi Gemini thật), #18 (cấu hình app ở `configureApp()`); cập nhật lý do #15 — đã có test khoá hành vi không tự gọi lại
```

### Task 4 — `CLAUDE.md`

Trong khối lệnh Backend, thay dòng `npm test                        # vitest unit tests` bằng:

```
npm test                        # vitest unit tests (src/**/*.spec.ts)
npx vitest run src/plan/plan.service.spec.ts   # a single test file
```

Thêm ngay sau đoạn "Note: `nest-cli.json` has `compilerOptions.assets`…":

```
Tests never call the real Gemini API. `test/fake-gemini-server.ts` is a local HTTP server that speaks Gemini's `generateContent` format; the real `@google/genai` SDK is pointed at it through `GEMINI_BASE_URL` (leave that empty in real runs). The e2e suite pins `GEMINI_*` env vars *before* dynamically importing `AppModule`, because a developer's `.env` may hold a real key. GitHub Actions (`.github/workflows/backend.yml`) runs build + unit + e2e on Node 24 and 26 on every push touching `backend_api/` or `ai_workspace/`, with no secrets.
```

Trong mục "Backend architecture", thay dòng Swagger cuối cùng:

```
- Swagger is mounted at `/docs`, global `ValidationPipe({ whitelist: true, transform: true })` is set in `main.ts`.
```

bằng:

```
- `src/app.setup.ts` — `configureApp()` applies the global `ValidationPipe({ whitelist: true, transform: true })` and mounts Swagger at `/docs` (JSON at `/docs-json`). Both `main.ts` and the e2e tests call it; put new global app config there, not in `main.ts`.
```

### Task 5 — `docs/SETUP_CREDENTIALS.md`

Trong mục 1.2, sau dòng "Tuỳ chọn: `GEMINI_TIMEOUT_MS=15000` …", thêm:

```
`GEMINI_BASE_URL` trong `.env.example` chỉ dùng khi chạy test với server Gemini giả — **để trống** khi dùng thật, nếu không backend sẽ gửi request (kèm khoá) tới địa chỉ đó thay vì Google.
```

### Task 6 — `README.md`

Trong mục `### BRD v2.3.0 — 2026-09-24`, thêm dòng cuối:

```
- Giai đoạn 2 — kiểm thử backend: ma trận 18 trường hợp BMR/TDEE (tính độc lập để đối chiếu), test phần gọi Gemini bằng SDK thật với server Gemini giả (hết giờ, khoá sai, không tự gọi lại), e2e toàn luồng `generate-plan`; GitHub Actions chạy build + test mỗi lần push (Node 24 và 26), không cần khoá
```

Trong mục `## Trạng thái dự án`, thêm dòng cuối:

```
Kết quả build và test tự động của từng commit: tab [Actions](https://github.com/AlenJason/AI-Product-Development-End-to-End/actions) trên GitHub.
```

### Task 7 — `docs/PLAN.md`

- Đổi `## Giai đoạn 2 — Backend: kiểm thử nền · S` thành `## Giai đoạn 2 — Backend: kiểm thử nền · M`.
- Đổi `- [ ] **2.1**`, `**2.3**`, `**2.4**` thành `- [x]`.
- Thêm sau bước 2.4:

```
- [x] **2.5** *(bổ sung, quyết định Q1)* Test `GeminiService` với SDK `@google/genai` thật trỏ vào server Gemini giả cục bộ (`GEMINI_BASE_URL`): hết giờ, khoá sai, không tự gọi lại, lỗi JSON không lộ nội dung
- [x] **2.6** *(bổ sung, quyết định Q2)* GitHub Actions: build + unit + e2e backend trên Node 24 và 26, kiểm kiểu `ai_workspace`, mỗi lần push

Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-2-backend-tests.md`, plan `docs/superpowers/plans/phase-2-backend-tests/`.
```

### Task 8 — Kiểm tra

```bash
grep -c 'gemini-integration' docs/knowledge/wiki/INDEX.md
grep -c '^- \[x\] \*\*2\.' docs/PLAN.md
cd docs/knowledge && grep -rhoE '\[\[[a-z-]+\]\]' wiki/*.md | sort -u | while read -r l; do n=$(echo "$l" | tr -d '[]'); [ -f "wiki/$n.md" ] || echo "MISSING $l"; done; echo "links checked"
```

Mong đợi: `1`; `6`; chỉ in `links checked`.
