# SmartFit AI — Plan & Trạng thái Dự án

## 1. Project Overview

**Single source of truth:** `docs/PLAN.md` (cập nhật: **12/11/2026**). Mọi tài liệu kiến trúc, phạm vi tính năng và trạng thái hoàn thành của dự án được quản lý tập trung tại đây.

[BRD](../BRD.md) v2.6.0 là nguồn yêu cầu sản phẩm đã phê duyệt. Các [implementation plans](superpowers/plans/) được lưu lại để tra cứu thiết kế kỹ thuật.

**Kiến trúc & công nghệ chính:**
- **Frontend:** Flutter/Dart (`Provider` / `ChangeNotifier`, named routes, `shared_preferences`).
- **Backend:** NestJS/TypeScript (`TypeORM` với **MySQL `smartfit_db`** cho dữ liệu bền vững và `better-sqlite3` cho test/local fallback).
- **AI Runtime:** **Groq API** (`PLAN_AI_PROVIDER=groq`, model `openai/gpt-oss-120b` qua `GroqPlanService`), kèm fallback thực đơn mẫu an toàn khi thiếu key hoặc lỗi mạng.
- **Xác thực:** Đăng ký, Đăng nhập, Đổi mật khẩu bằng **Email + Mật khẩu** (băm `scrypt` lưu cột `password_hash` trên bảng `users` MySQL, JWT 7 ngày) và Chế độ khách (Skip).

### Chế độ giả lập và dịch vụ thật

| Dịch vụ | Chế độ mặc định / giả lập | Dịch vụ thật |
|---|---|---|
| Groq AI | Không có `GROQ_API_KEY` → thực đơn mẫu (`source: "sample"`) | Cấu hình `GROQ_API_KEY` tại `backend_api/.env`; xem [credentials](SETUP_CREDENTIALS.md) |
| Auth | Bỏ qua đăng nhập (Chế độ khách) | Đăng ký / Đăng nhập Email + Mật khẩu + Đổi mật khẩu (lưu MySQL `users`, JWT 7 ngày) |

### Quyết định thiết kế D1–D6 (đã áp dụng)

**D1 — Mức điều chỉnh calo theo mục tiêu:** Giảm mỡ −300 kcal/ngày, tăng cơ +250 kcal/ngày, duy trì 0 kcal/ngày.

**D2 — Feedback cuối ngày:** gồm 3 câu hỏi:

| Câu hỏi | Lựa chọn | Tác động lên ngày kế tiếp |
|---|---|---|
| Cường độ buổi tập hôm nay (chọn 1) | Nhẹ nhàng / Vừa sức / Rất mệt | Tăng nhẹ / Giữ nguyên / Giảm khối lượng tập |
| Tình trạng cơ thể khi hoặc sau khi tập (chọn nhiều) | Bình thường · Căng mỏi cơ · Đau khớp (gối, cổ tay, vai…) · Uể oải, thiếu ngủ · ⚠️ Chóng mặt, khó thở bất thường, đau ngực | Căng mỏi cơ → giảm hiệp nhóm cơ đó, thêm giãn cơ. Đau khớp → bỏ động tác bật nhảy, chống quỳ. Uể oải → rút ngắn buổi tập. **⚠️ Dấu hiệu nguy hiểm → không tự điều chỉnh plan; hiện khuyến cáo ngừng tập và hỏi ý kiến bác sĩ; ngày kế tiếp chỉ nghỉ hoặc đi bộ nhẹ** |
| Ăn uống (chọn 1) | Đúng thực đơn / Ăn nhiều hơn / Ăn ít hơn hoặc bỏ bữa | Cân đối lại món ăn ngày kế tiếp (không hạ calo dưới BMR) |

**D3 — Nguyên liệu đi chợ:** API trả `name` và `quantity` riêng (ví dụ `{ "name": "Ức gà", "quantity": "450g" }`), gom theo 3 nhóm cố định (*Đạm*, *Rau củ quả*, *Gạo, bún & gia vị*).

**D4 & D5 — Hạn chế và sức khoẻ ở Onboarding & Cá nhân:**

- Ba mục *Dị ứng*, *Chấn thương*, *Tình trạng sức khoẻ*, mỗi mục có công tắc bật/tắt (mặc định tắt). Khi bật cho phép chọn nhiều chip phổ biến khớp từ khoá backend (`backend_api/src/plan/data/restriction-keywords.json`) hoặc nhập mục "Khác" (tổng chuỗi ghép ≤ 300 ký tự). Sửa lại được trong tab "Cá nhân".
- **Lưu trên máy, không lưu trên database server.** Thông tin sức khoẻ gửi kèm từng request rồi bỏ đi; backend không ghi DB, không ghi log.
- **Có Groq AI:** văn bản tự do đưa vào prompt trong khối dữ liệu tách biệt (`<du_lieu_nguoi_dung>`), giới hạn 300 ký tự mỗi ô để hạn chế prompt injection.
- **Chế độ mẫu/fallback:** khớp từ khoá phổ biến (có dấu & không dấu) để lọc món/bài tập; nếu có nội dung không nhận ra sẽ hiển thị cảnh báo chưa kiểm tra hết; tình trạng bệnh nền luôn kèm khuyến cáo y tế ("chỉ mang tính tham khảo, không thay thế tư vấn y tế").

**D6 — An toàn sức khoẻ và luồng dùng hằng ngày (BRD v2.6.0):**

| # | Vấn đề | Quy tắc đã áp dụng |
|---|---|---|
| A1 | BMI < 18,5 chọn "Giảm mỡ" | Chặn chọn "Giảm mỡ" ở cả Form và Backend (400), gợi ý "Duy trì"/"Tăng cơ" |
| A2 | Dưới 18 tuổi | Tuổi tối thiểu **18** (18–100) ở cả Backend và Form |
| A3 | Mang thai / cho con bú | Thêm vào danh sách sức khoẻ; chặn thâm hụt calo (`cut`) và ép giới hạn bài tập mức 1 |
| A4 | Mức độ bài tập theo tuổi & thể trạng | Chọn mức động tác 1–3 theo tuổi và `activity_level`; prompt Groq API áp dụng cùng luật |
| B1 | Lịch theo ngày thực tế | App lưu ngày bắt đầu theo lịch thiết bị, tự chuyển ngày 1 → 3 và nhắc tạo kế hoạch mới khi hết chu kỳ |
| B2 | Onboarding 3 bước | Chia 3 bước (Chỉ số cơ thể → Mục tiêu & vận động → Hạn chế), thanh tiến trình và nút luôn ở đáy |

Cân bằng macro cho thực đơn mẫu và kho món đổi được bảo toàn lệch không quá 3 điểm so với tỷ lệ chuẩn 25/45/30.

---

## 2. Current Project Status

**Trạng thái tổng quan (12/11/2026):** Toàn bộ tính năng cốt lõi của dự án SmartFit AI (Onboarding 3 bước & safety → Tạo thực đơn/bài tập 3 ngày qua Groq API + fallback → Dashboard & Plan chi tiết → Đổi món / Đổi bài → Danh sách đi chợ có lưu checklist → Feedback cuối ngày & chu kỳ ngày 3 → Đăng ký / Đăng nhập Email + Mật khẩu, Đổi mật khẩu, Xóa tài khoản trên MySQL `smartfit_db` → Màn hình Lịch sử kế hoạch `HistoryScreen`) **đã hoàn thành**.

| Hạng mục kiểm chứng | Kết quả ghi nhận |
|---|---|
| Backend `npm run typecheck` / `lint` / `build` | PASS (`lint` 0 lỗi, 0 cảnh báo trên 132 files) |
| Backend Unit tests (`npm test`) | **507/507 PASS** (39 files) |
| Backend E2E tests (`npm run test:e2e`) | **120/120 PASS** (10 files; 1 bridge test opt-in skip) |
| MySQL `smartfit_db` live schema | Bảng `users` (`id`, `email`, `name`, `password_hash`, `created_at` — không còn `google_sub`), `plan_records`, `feedback_receipts` |
| Groq API live (`scripts/test-groq-plan.mjs`, `test-groq-adjustments.mjs`) | **PASS** (`source: groq`, `10.5s`, target 1624 → `[1625, 1635, 1625]`; swap món/bài HTTP 200) |
| Flutter `flutter analyze --no-pub` | Sạch (0 issues) |
| Flutter `flutter test --no-pub` | **195 PASS** (0 FAIL; 3 live HTTP opt-in tests skipped) |

## 3. Progress Dashboard

| Trạng thái | Task |
|---|---:|
| DONE | 51 |
| PARTIAL | 8 |
| NOT STARTED | 1 |
| BLOCKED | 0 |
| BUGGY | 0 |
| UNVERIFIED | 5 |
| **Total** | **65** |
| **Completion** | **78.46%** |

*(Completion = 51 / 65 × 100. Toàn bộ tính năng code cho backend, MySQL, Groq AI, Email/Password Auth, Feedback và History UI trên Flutter đã hoàn tất; các mục còn lại thuộc về CI/deploy cloud hoặc kiểm thử thiết bị/slide ngoài code.)*

## 4. Phase 0–9 Roadmap

| Phase | Phạm vi | Size | Total | DONE | PARTIAL | NOT STARTED | UNVERIFIED | Completion |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 0 | Dọn dẹp & chuẩn bị | S | 7 | 7 | 0 | 0 | 0 | 100.00% |
| 1 | Chốt hợp đồng API | M | 4 | 4 | 0 | 0 | 0 | 100.00% |
| 2 | Backend: kiểm thử nền | M | 6 | 5 | 0 | 0 | 1 | 83.33% |
| 3 | Backend: tài khoản (MySQL) & lịch sử | L | 8 | 7 | 1 | 0 | 0 | 87.50% |
| 4 | Backend: đổi món, đổi bài, feedback (Groq) | L | 8 | 8 | 0 | 0 | 0 | 100.00% |
| 5 | Frontend: nền tảng | M | 9 | 7 | 1 | 0 | 1 | 77.78% |
| 6 | Frontend: nối MVP | L | 11 | 7 | 4 | 0 | 0 | 63.64% |
| 7 | Frontend: tính năng nâng cao | M | 3 | 3 | 0 | 0 | 0 | 100.00% |
| 8 | Frontend: tài khoản, đổi mật khẩu & lịch sử | M | 3 | 3 | 0 | 0 | 0 | 100.00% |
| 9 | Deploy, nghiệm thu, nộp bài | M | 6 | 0 | 2 | 1 | 3 | 0.00% |

| Phase | Implementation plan | Điều kiện hoàn thành |
|---|---|---|
| 0 | Đã hoàn tất dọn dẹp & cấu hình | Đạt task criteria và backend gates |
| 1 | [Spec/README](superpowers/plans/phase-1-api-contract/README.md) | Đạt task criteria và backend gates |
| 2 | [Spec/README](superpowers/plans/phase-2-backend-tests/README.md) | Đạt task criteria và backend gates |
| 3 | [Spec/README](superpowers/plans/phase-3-auth-history/README.md) | Đạt task criteria và backend gates |
| 4 | [Spec/README](superpowers/plans/phase-4-swap-feedback/README.md) | Đạt task criteria và Groq live gates |
| 5 | [Spec/README](superpowers/plans/phase-5-frontend-foundation/README.md) | Đạt UI request/response + error/safety + widget tests |
| 6 | [Spec/README](superpowers/plans/phase-6-connect-mvp/README.md) | Đạt UI request/response + error/safety + widget tests |
| 7 | Hoàn tất trong app | Đạt UI + API + persistence tests |
| 8 | Hoàn tất trong app | Đạt Email/Password Auth, Change Password, History UI & tests |
| 9 | Chuẩn bị giao nộp / deploy | Deploy/storage bền, nghiệm thu thiết bị và artifact báo cáo |

## 5. Detailed Task Checklist

<a id="task-0-1"></a>

### Task 0.1 — AI provider/auth/DB và roadmap trong CLAUDE

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** Sửa `CLAUDE.md`: cập nhật tích hợp AI (hiện dùng Groq API qua `GroqPlanService`), thêm quyết định auth Email + Mật khẩu & DB MySQL/SQLite; trỏ tới plan này
- **Acceptance criteria hiện hành:** CLAUDE mô tả đúng Groq API, auth Email + Mật khẩu, MySQL/SQLite và liên kết roadmap chính.
- **Evidence / lý do chưa đạt:** Đã đối chiếu nội dung SDK/auth/database; các mô tả frontend cũ còn thuộc 9.5.
- **Source / tests:** [CLAUDE.md](../CLAUDE.md).

<a id="task-0-2"></a>

### Task 0.2 — Dart SDK trong wiki

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** Sửa lỗi trong wiki `reference-materials.md`: ràng buộc `sdk: ^3.13.1` trong `pubspec.yaml` **đã thoả** yêu cầu Dart 3.9+ của `shared_preferences`, không cần nâng như đã ghi
- **Acceptance criteria hiện hành:** Wiki ghi sdk ^3.13.1 đã đáp ứng yêu cầu Dart 3.9+, không yêu cầu nâng SDK vô cớ.
- **Evidence / lý do chưa đạt:** Nội dung đã sửa đúng; đối chiếu pubspec.
- **Source / tests:** [reference-materials.md](knowledge/wiki/reference-materials.md).

<a id="task-0-3"></a>

### Task 0.3 — Yêu cầu lưu trữ bền vững

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi:** Cập nhật BRD mục 7.6 về lưu trữ bền vững (hiện hệ thống dùng MySQL `smartfit_db` hoặc SQLite kèm ổ lưu trữ bền).
- **Evidence:** Đã xác lập trong BRD §7.6 và cấu hình MySQL `smartfit_db` chạy ổn định.
- **Source / tests:** [BRD.md](../BRD.md).

<a id="task-0-4"></a>

### Task 0.4 — HTTP status POST

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** Các endpoint POST trả HTTP 200 như sơ đồ BRD (NestJS mặc định trả 201)
- **Acceptance criteria hiện hành:** Mọi POST thành công trả 200; DELETE account trả 204 theo hợp đồng riêng.
- **Evidence / lý do chưa đạt:** E2E và smoke audit pass; decorators HttpCode đúng.
- **Source / tests:** [plan.controller.ts](../backend_api/src/plan/plan.controller.ts); [plan-adjust.controller.ts](../backend_api/src/plan/adjust/plan-adjust.controller.ts); [auth.controller.ts](../backend_api/src/auth/auth.controller.ts).

<a id="task-0-5"></a>

### Task 0.5 — Health configuration

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** `GET /health` báo trạng thái cấu hình `{ status, ai_provider: "groq", ai_status: "configured" | "fallback", auth_mode }` để kiểm tra nhanh khoá đã gắn đúng chưa
- **Acceptance criteria hiện hành:** GET /health trả status, ai_provider/ai_status và auth_mode.
- **Evidence / lý do chưa đạt:** Health qua E2E và smoke audit pass.
- **Source / tests:** [app.service.ts](../backend_api/src/app.service.ts); [app.e2e-spec.ts](../backend_api/test/app.e2e-spec.ts).

<a id="task-0-6"></a>

### Task 0.6 — Hướng dẫn Groq API credentials

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** Tạo `docs/SETUP_CREDENTIALS.md` và `backend_api/GROQ_TRIAL.md` — phần **Groq API key**: lấy key ở đâu (`console.groq.com`), điền vào `.env`, kiểm tra thế nào
- **Acceptance criteria hiện hành:** Có cách lấy key Groq, đặt backend env, kiểm tra source/health, bảo mật và lỗi thường gặp.
- **Evidence / lý do chưa đạt:** Đã có đủ hướng dẫn và đã kiểm chứng gọi Groq live thành công.
- **Source / tests:** [SETUP_CREDENTIALS.md](SETUP_CREDENTIALS.md); [GROQ_TRIAL.md](../backend_api/GROQ_TRIAL.md).

<a id="task-0-7"></a>

### Task 0.7 — README liên kết roadmap

- [x] **Status: DONE**
- **Dependency:** [0.6](#task-0-6)
- **Phạm vi gốc:** README trỏ tới plan này và file hướng dẫn
- **Acceptance criteria hiện hành:** README trỏ roadmap chính và hướng dẫn credentials.
- **Evidence / lý do chưa đạt:** Liên kết đã có; consolidation làm rõ quyền quản lý trạng thái.
- **Source / tests:** [README.md](../README.md).

<a id="task-1-1"></a>

### Task 1.1 — BRD và quyết định D1–D4

- [x] **Status: DONE**
- **Dependency:** [0.1](#task-0-1), [0.2](#task-0-2), [0.3](#task-0-3)
- **Phạm vi gốc:** Áp dụng D1–D4 vào BRD, nâng lên v2.3.0 (thay đổi phạm vi thật: thêm ô bệnh nền, sửa hồ sơ, feedback mới):
  - FR-1.3: mức điều chỉnh calo −300 / +250 (D1)
  - FR-1.4: 3 ô nhập tự do + chip gợi ý (D4); thêm FR-1.6: sửa hồ sơ ở tab "Cá nhân"
  - FR-5.1, FR-5.2: feedback 3 câu hỏi và quy tắc xử lý dấu hiệu nguy hiểm (D2)
  - Mục 6.1: `restrictions` đổi thành 3 chuỗi `allergies`, `injuries`, `health_conditions` (tối đa 300 ký tự mỗi chuỗi)
  - Mục 6.2: nguyên liệu tách `name` / `quantity`, 3 nhóm cố định (D3)
  - Mục 7: thêm NFR quyền riêng tư dữ liệu sức khoẻ (không lưu/ghi log ở server), chống prompt injection, khuyến cáo "không thay thế tư vấn y tế"
- **Acceptance criteria hiện hành:** BRD có calorie -300/+250, restrictions ba chuỗi ≤300 ký tự, profile edit, feedback ba câu, grocery name/quantity, privacy/injection/disclaimer; áp cập nhật D5/D6 đã duyệt.
- **Evidence / lý do chưa đạt:** BRD v2.6.0 bảo toàn phạm vi; năm JSON block parse được trong audit. Scope task này là tài liệu, không phải UI hoàn thành.
- **Source / tests:** [BRD.md](../BRD.md).
- **Spec, subtasks và cổng kiểm:** [1/F01](superpowers/plans/phase-1-api-contract/specs/F01-brd-contract.md).

<a id="task-1-2"></a>

### Task 1.2 — Hợp đồng adjustment API

- [x] **Status: DONE**
- **Dependency:** [1.1](#task-1-1)
- **Phạm vi gốc:** Thêm BRD mục 6.4: schema request/response cho đổi món, đổi bài tập, feedback (hiện mới chỉ bàn trong chat, chưa có trong BRD)
- **Acceptance criteria hiện hành:** BRD §6.4 mô tả request/response và lỗi cho meal swap, exercise swap, feedback.
- **Evidence / lý do chưa đạt:** Hợp đồng đã có; tests backend audit pass.
- **Source / tests:** [BRD.md](../BRD.md); [adjust-plan.dto.ts](../backend_api/src/plan/dto/adjust-plan.dto.ts).
- **Spec, subtasks và cổng kiểm:** [1/F01](superpowers/plans/phase-1-api-contract/specs/F01-brd-contract.md).

<a id="task-1-3"></a>

### Task 1.3 — DTO, sample, pipeline và prompt đồng bộ

- [x] **Status: DONE**
- **Dependency:** [1.1](#task-1-1), [1.2](#task-1-2)
- **Phạm vi gốc:** Cập nhật backend cho khớp: DTO, interface, hằng số `GOAL_CALORIE_ADJUSTMENT`, prompt Groq (đưa văn bản tự do vào khối dữ liệu tách biệt). Soạn lại `sample-plan.json` theo schema mới và **đủ 3 ngày**
- **Acceptance criteria hiện hành:** DTO/enums khớp BRD; sample đủ ba ngày; target/validation/assembly và fallback được nối; văn bản user tách biệt; prompt AI workspace đồng bộ backend; xóa interfaces/helpers cũ theo spec.
- **Evidence / lý do chưa đạt:** Backend build/test pass; `ai_workspace/generate-plan-experiment.ts` đã đồng bộ dùng đúng pipeline/prompt Groq của backend.
- **Source / tests:** [plan.service.ts](../backend_api/src/plan/plan.service.ts); [groq-plan.service.ts](../backend_api/src/plan/groq-plan.service.ts); [generate-plan-experiment.ts](../ai_workspace/generate-plan-experiment.ts); [system-prompt.md](../ai_workspace/prompts/system-prompt.md).
- **Spec, subtasks và cổng kiểm:** [1/F02](superpowers/plans/phase-1-api-contract/specs/F02-plan-types-validation.md); [1/F03](superpowers/plans/phase-1-api-contract/specs/F03-daily-target.md); [1/F04](superpowers/plans/phase-1-api-contract/specs/F04-plan-assembly.md); [1/F05](superpowers/plans/phase-1-api-contract/specs/F05-sample-plan.md); [1/F06](superpowers/plans/phase-1-api-contract/specs/F06-generate-plan-pipeline.md).

<a id="task-1-4"></a>

### Task 1.4 — Wiki về privacy và safety

- [x] **Status: DONE**
- **Dependency:** [1.1](#task-1-1)
- **Phạm vi gốc:** Thêm vào wiki `critical-constraints.md`: không lưu dữ liệu sức khoẻ ở server; dấu hiệu nguy hiểm → khuyến cáo, không tự điều chỉnh plan; không hạ calo dưới BMR
- **Acceptance criteria hiện hành:** Wiki có không lưu/log health data, danger signs ưu tiên nghỉ/khuyến cáo, không dưới BMR.
- **Evidence / lý do chưa đạt:** Các ràng buộc đã có; không coi đây là bằng chứng UI áp dụng.
- **Source / tests:** [critical-constraints.md](knowledge/wiki/critical-constraints.md).
- **Spec, subtasks và cổng kiểm:** [1/F07](superpowers/plans/phase-1-api-contract/specs/F07-docs-wiki.md).

<a id="task-2-1"></a>

### Task 2.1 — Ma trận BMR/TDEE

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3)
- **Phạm vi gốc:** Unit test `computeDailyTarget()` (`daily-target.ts`): mở rộng từ 3 ca đã có ở giai đoạn 1 ra đủ nam/nữ × 3 mức vận động × 3 mục tiêu (tiêu chí nghiệm thu tuần 5)
- **Acceptance criteria hiện hành:** Test nam/nữ × ba mức vận động × ba mục tiêu; expected độc lập; bao gồm sàn BMR và rounding .5.
- **Evidence / lý do chưa đạt:** Unit suite audit pass, có ma trận và boundary cases.
- **Source / tests:** [daily-target.spec.ts](../backend_api/src/plan/daily-target.spec.ts).
- **Spec, subtasks và cổng kiểm:** [2/F01](superpowers/plans/phase-2-backend-tests/specs/F01-daily-target-matrix.md).

<a id="task-2-2"></a>

### Task 2.2 — Plan validation tests

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3)
- **Phạm vi gốc:** ~~Unit test `isNutritionWithinBounds()`~~ — hàm này đã được thay bằng `findPlanViolations()` và có test ở giai đoạn 1 (`plan-validation.spec.ts`)
- **Acceptance criteria hiện hành:** findPlanViolations thay isNutritionWithinBounds; kiểm cấu trúc, enum, bữa/ngày, calories, macro và trùng món bằng tests.
- **Evidence / lý do chưa đạt:** Unit audit pass; task được nghiệm thu theo hàm thay thế đã ghi trong PLAN.
- **Source / tests:** [plan-validation.spec.ts](../backend_api/src/plan/plan-validation.spec.ts).

<a id="task-2-3"></a>

### Task 2.3 — Generate retry/fallback tests

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3)
- **Phạm vi gốc:** Unit test `PlanService.generatePlan()` với Groq API giả: kết quả hợp lệ → `source: groq`; sai hợp đồng → gọi lại → thực đơn mẫu; hết giờ → không gọi lại; khoá sai → thực đơn mẫu
- **Acceptance criteria hiện hành:** Groq đúng dùng source groq; sai gọi lại tối đa một lần rồi sample; timeout không retry; invalid key/fallback và log không lộ health data được kiểm.
- **Evidence / lý do chưa đạt:** Unit audit pass; error/timeout/retry branches có assertions.
- **Source / tests:** [plan.service.spec.ts](../backend_api/src/plan/plan.service.spec.ts); [groq-plan.service.spec.ts](../backend_api/src/plan/groq-plan.service.spec.ts); [groq-validation-regression.spec.ts](../backend_api/src/plan/groq-validation-regression.spec.ts).
- **Spec, subtasks và cổng kiểm:** [2/F03](superpowers/plans/phase-2-backend-tests/specs/F03-plan-service-retry.md).

<a id="task-2-4"></a>

### Task 2.4 — Generate HTTP E2E

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3), [2.3](#task-2-3)
- **Phạm vi gốc:** E2E `POST /api/v1/generate-plan`: payload đúng → 200, payload sai → 400, `restrictions` kiểu mảng cũ → 400 (test e2e cần bật `ValidationPipe` giống `main.ts`)
- **Acceptance criteria hiện hành:** Payload đúng 200; sai/array restrictions cũ 400; dùng configureApp/ValidationPipe; Groq/HTTP gọi server giả; Swagger schema và không trả health text được kiểm.
- **Evidence / lý do chưa đạt:** Backend E2E audit pass.
- **Source / tests:** [generate-plan.e2e-spec.ts](../backend_api/test/generate-plan.e2e-spec.ts); [groq-plan.e2e-spec.ts](../backend_api/test/groq-plan.e2e-spec.ts); [app.setup.ts](../backend_api/src/app.setup.ts).
- **Spec, subtasks và cổng kiểm:** [2/F04](superpowers/plans/phase-2-backend-tests/specs/F04-e2e-generate-plan.md).

<a id="task-2-5"></a>

### Task 2.5 — Groq API với server giả

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3)
- **Phạm vi gốc:** *(bổ sung, quyết định Q1)* Test `GroqPlanService` với HTTP server giả cục bộ: hết giờ, khoá sai, không tự gọi lại trên 401/403/429/timeout, lỗi JSON không lộ nội dung
- **Acceptance criteria hiện hành:** Route Groq HTTP tới server local trong test; timeout/key/429/500/JSON lỗi có test; không tự retry sai quy tắc; log không lộ dữ liệu.
- **Evidence / lý do chưa đạt:** Unit & E2E Groq validation pass.
- **Source / tests:** [groq-plan.service.spec.ts](../backend_api/src/plan/groq-plan.service.spec.ts); [groq-validation.e2e-spec.ts](../backend_api/test/groq-validation.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [2/F02](superpowers/plans/phase-2-backend-tests/specs/F02-gemini-service-real-sdk.md).

<a id="task-2-6"></a>

### Task 2.6 — CI backend Node matrix và AI typecheck

- [ ] **Status: UNVERIFIED**
- **Dependency:** [2.1](#task-2-1), [2.2](#task-2-2), [2.3](#task-2-3), [2.4](#task-2-4), [2.5](#task-2-5)
- **Phạm vi gốc:** *(bổ sung, quyết định Q2)* GitHub Actions: build + unit + e2e backend trên Node 24 và 26, kiểm kiểu `ai_workspace`, mỗi lần push
- **Acceptance criteria hiện hành:** Push/PR đúng path chạy build/unit/E2E trên Node 24 và 26, typecheck AI workspace; run của đúng commit hoàn tất success; docs-only không kích hoạt backend job.
- **Evidence / lý do chưa đạt:** Workflow có và AI typecheck local audit pass; chưa có URL/result CI run cho commit hiện tại.
- **Source / tests:** [backend.yml](../.github/workflows/backend.yml); [package.json](../ai_workspace/package.json).
- **Spec, subtasks và cổng kiểm:** [2/F05](superpowers/plans/phase-2-backend-tests/specs/F05-github-actions.md).

<a id="task-3-1"></a>

### Task 3.1 — TypeORM, MySQL & SQLite driver

- [x] **Status: DONE**
- **Dependency:** [2.4](#task-2-4)
- **Phạm vi gốc:** Thêm TypeORM + `mysql2` (cho MySQL `smartfit_db`) và `better-sqlite3@12` (cho test `:memory:` và local fallback).
- **Acceptance criteria hiện hành:** TypeORM/`mysql2`/`better-sqlite3@12` được cấu hình qua `resolveDataSourceOptions`; entity column types tương thích cả MySQL và SQLite.
- **Evidence / lý do chưa đạt:** Database unit/E2E tests và kiểm chứng MySQL `smartfit_db` thật PASS.
- **Source / tests:** [package.json](../backend_api/package.json); [data-source-options.ts](../backend_api/src/database/data-source-options.ts).
- **Spec, subtasks và cổng kiểm:** [3/F01](superpowers/plans/phase-3-auth-history/specs/F01-database.md).

<a id="task-3-2"></a>

### Task 3.2 — Entities và migrations

- [x] **Status: DONE**
- **Dependency:** [3.1](#task-3-1)
- **Phạm vi gốc:** Entity `User` (id, email unique, name, password_hash, created_at — đã xóa `google_sub`), `PlanRecord` (user, plan_json, target_calories, created_at) và `FeedbackReceipt` (`lease_until` kiểu `bigint`); migration SQLite & `synchronize` MySQL; file DB nằm trong `.gitignore`
- **Acceptance criteria hiện hành:** User/PlanRecord/FeedbackReceipt đúng trường; migration startup, FK cascade, schema diff sạch; DB ignored; ESM relations không làm build boot lỗi.
- **Evidence / lý do chưa đạt:** Migration tests (`migrations.spec.ts`), MySQL schema sync và build PASS.
- **Source / tests:** [migrations.spec.ts](../backend_api/src/database/migrations.spec.ts); [user.entity.ts](../backend_api/src/database/entities/user.entity.ts); [plan-record.entity.ts](../backend_api/src/database/entities/plan-record.entity.ts); [.gitignore](../backend_api/.gitignore).
- **Spec, subtasks và cổng kiểm:** [3/F01](superpowers/plans/phase-3-auth-history/specs/F01-database.md).

<a id="task-3-3"></a>

### Task 3.3 — Backend Email/Password Auth và JWT

- [x] **Status: DONE**
- **Dependency:** [3.2](#task-3-2)
- **Phạm vi gốc:** `AuthModule`: `POST /api/v1/auth/register` (đăng ký email, tên, mật khẩu băm `scrypt`), `POST /api/v1/auth/login` (đăng nhập email + mật khẩu), `POST /api/v1/auth/change-password` (đổi mật khẩu khi đang đăng nhập), JWT hết hạn sau 7 ngày. `/health` báo thêm `auth_mode`.
- **Acceptance criteria hiện hành:** Register kiểm trùng email `409`, login sai báo `401`, change-password kiểm mật khẩu cũ, JWT mặc định 7d, `/health` trả `auth_mode`.
- **Evidence / lý do chưa đạt:** Auth unit/E2E tests và kiểm thử trực tiếp trên MySQL `smartfit_db` PASS.
- **Source / tests:** [auth.controller.ts](../backend_api/src/auth/auth.controller.ts); [auth.service.ts](../backend_api/src/auth/auth.service.ts); [password.util.ts](../backend_api/src/auth/password.util.ts); [auth.service.spec.ts](../backend_api/src/auth/auth.service.spec.ts).
- **Spec, subtasks và cổng kiểm:** [3/F02](superpowers/plans/phase-3-auth-history/specs/F02-auth.md).

<a id="task-3-4"></a>

### Task 3.4 — JWT guards

- [x] **Status: DONE**
- **Dependency:** [3.3](#task-3-3)
- **Phạm vi gốc:** Guard: bắt buộc đăng nhập cho API lịch sử và đổi mật khẩu; tuỳ chọn cho `generate-plan` (token hợp lệ → lưu lịch sử; token sai → 401; không có token → chạy như cũ, không lưu)
- **Acceptance criteria hiện hành:** History/change-password bắt buộc auth; generate tùy chọn; token đúng lưu, sai 401, không token chạy guest; account đã xóa bị từ chối.
- **Evidence / lý do chưa đạt:** Guard và HTTP tests audit pass.
- **Source / tests:** [jwt-auth.guard.spec.ts](../backend_api/src/auth/jwt-auth.guard.spec.ts); [history.e2e-spec.ts](../backend_api/test/history.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [3/F02](superpowers/plans/phase-3-auth-history/specs/F02-auth.md); [3/F03](superpowers/plans/phase-3-auth-history/specs/F03-history.md).

<a id="task-3-5"></a>

### Task 3.5 — History list/detail và ownership

- [x] **Status: DONE**
- **Dependency:** [3.2](#task-3-2), [3.4](#task-3-4)
- **Phạm vi gốc:** `GET /api/v1/plans/history` (50 plan mới nhất) và `GET /api/v1/plans/history/:id` (plan của người khác → 404)
- **Acceptance criteria hiện hành:** 50 plan mới nhất; ID hợp lệ; không tiết lộ plan user khác (404); detail đúng plan; lưu bền trên MySQL `plan_records`.
- **Evidence / lý do chưa đạt:** List/detail/ownership unit/E2E và MySQL live PASS.
- **Source / tests:** [history.service.ts](../backend_api/src/history/history.service.ts); [history.e2e-spec.ts](../backend_api/test/history.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [3/F03](superpowers/plans/phase-3-auth-history/specs/F03-history.md).

<a id="task-3-6"></a>

### Task 3.6 — Auth/history/database tests

- [x] **Status: DONE**
- **Dependency:** [3.3](#task-3-3), [3.4](#task-3-4), [3.5](#task-3-5)
- **Phạm vi gốc:** Test: đăng ký, đăng nhập mật khẩu, đổi mật khẩu, guard, quyền sở hữu plan, migration khớp entity, E2E: đăng ký/đăng nhập → tạo plan → xem lịch sử → đổi mật khẩu
- **Acceptance criteria hiện hành:** Auth password, guard, owner, schema migration; HTTP register/login → generate → history → change-password; test DB RAM và env được khôi phục.
- **Evidence / lý do chưa đạt:** Unit/E2E pass (507 unit / 120 E2E) và kiểm thử live trên MySQL `smartfit_db` PASS.
- **Source / tests:** [auth.e2e-spec.ts](../backend_api/test/auth.e2e-spec.ts); [history.e2e-spec.ts](../backend_api/test/history.e2e-spec.ts); [test-app.ts](../backend_api/test/test-app.ts).
- **Spec, subtasks và cổng kiểm:** [3/F03](superpowers/plans/phase-3-auth-history/specs/F03-history.md).

<a id="task-3-8"></a>

### Task 3.8 — Backend xóa tài khoản

- [x] **Status: DONE**
- **Dependency:** [3.2](#task-3-2), [3.4](#task-3-4)
- **Phạm vi gốc:** *(bổ sung, quyết định Q4)* `DELETE /api/v1/me`: xoá tài khoản cùng toàn bộ lịch sử (BRD FR-6.4, v2.4.0)
- **Acceptance criteria hiện hành:** DELETE /api/v1/me authenticated trả 204; account và history bị xóa cascade; token cũ bị từ chối.
- **Evidence / lý do chưa đạt:** Backend tests audit pass; UI deletion chưa nối ở N07.
- **Source / tests:** [auth.controller.ts](../backend_api/src/auth/auth.controller.ts); [auth.e2e-spec.ts](../backend_api/test/auth.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [3/F02](superpowers/plans/phase-3-auth-history/specs/F02-auth.md).

<a id="task-3-9"></a>

### Task 3.9 — Build smoke và CI

- [ ] **Status: PARTIAL**
- **Dependency:** [3.6](#task-3-6), [2.6](#task-2-6)
- **Phạm vi gốc:** *(bổ sung khi lập plan)* Smoke test chạy bản build (`npm run test:smoke`) trong CI — bắt lỗi import vòng giữa entity mà vitest không thấy
- **Acceptance criteria hiện hành:** Smoke boot dist/main.js, kiểm assets/ESM và HTTP; workflow chạy smoke trên Node matrix; có run success của đúng commit.
- **Evidence / lý do chưa đạt:** Smoke local audit pass; CI run chưa được xác minh. Không chạy mutation sửa source trong consolidation.
- **Source / tests:** [smoke-test.mjs](../backend_api/scripts/smoke-test.mjs); [backend.yml](../.github/workflows/backend.yml).
- **Spec, subtasks và cổng kiểm:** [3/F04](superpowers/plans/phase-3-auth-history/specs/F04-smoke-ci.md).

<a id="task-4-1"></a>

### Task 4.1 — Restriction matcher và fallback filtering

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3), [2.5](#task-2-5)
- **Phạm vi gốc:** Bộ khớp từ khoá cho chế độ giả lập (`data/restriction-keywords.json`, `restriction-matcher.ts`): nhận ra dị ứng/chấn thương phổ biến, gõ có dấu hay không dấu; phần không nhận ra → cảnh báo chung, không nhắc lại chữ người dùng (D4). Lọc luôn thực đơn mẫu của `generate-plan` và kiểm lại mọi kết quả Groq API
- **Acceptance criteria hiện hành:** Keyword có/không dấu, không nhầm cá/cà; lọc sample và kiểm Groq AI; unknown warning chung không echo user; pools validate startup.
- **Evidence / lý do chưa đạt:** Unit/E2E audit pass.
- **Source / tests:** [restriction-matcher.spec.ts](../backend_api/src/plan/restriction-matcher.spec.ts); [restriction-filter.spec.ts](../backend_api/src/plan/restriction-filter.spec.ts); [swap-pools.spec.ts](../backend_api/src/plan/swap-pools.spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F01](superpowers/plans/phase-4-swap-feedback/specs/F01-calories-restrictions.md).

<a id="task-4-2"></a>

### Task 4.2 — Backend meal swap

- [x] **Status: DONE**
- **Dependency:** [4.1](#task-4-1), [4.7](#task-4-7)
- **Phạm vi gốc:** `POST /api/v1/meals/swap`: Groq API sinh món thay thế lệch không quá ±10% calo, tránh các hạn chế người dùng nhập, không trùng món đã có trong plan; backend tính lại toàn bộ `grocery_list` (#7). Fallback: kho món Việt `data/swap-meals.json` lọc bằng bộ khớp từ khoá, nhân khẩu phần về đúng calo món cũ; hết món phù hợp → 422
- **Acceptance criteria hiện hành:** Groq API trước/fallback pool; đúng meal type; calories ±10%, không dị ứng/trùng; recompute grocery; thiếu candidate 422; nguyên plan giữ khi lỗi.
- **Evidence / lý do chưa đạt:** Unit/E2E/live Groq test pass.
- **Source / tests:** [meal-swap.service.spec.ts](../backend_api/src/plan/adjust/meal-swap.service.spec.ts); [adjust.e2e-spec.ts](../backend_api/test/adjust.e2e-spec.ts); [groq-adjustments.spec.ts](../backend_api/src/plan/adjust/groq-adjustments.spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F03](superpowers/plans/phase-4-swap-feedback/specs/F03-meal-swap.md).

<a id="task-4-3"></a>

### Task 4.3 — Backend exercise swap

- [x] **Status: DONE**
- **Dependency:** [4.1](#task-4-1)
- **Phạm vi gốc:** `POST /api/v1/exercises/swap` *(quyết định Q2: Groq API trước)*: động tác nhẹ hơn, cùng nhóm cơ, tránh chấn thương — kết quả Groq AI phải qua điều kiện đo được (số hiệp không tăng, không thêm kiểu tải). Fallback: `data/swap-exercises.json` có mức khó 1–3; đã nhẹ nhất → 422
- **Acceptance criteria hiện hành:** Cùng nhóm cơ, sets không tăng, không thêm load tags, tránh injury/profile limit; fallback mức nhẹ hơn; không có 422.
- **Evidence / lý do chưa đạt:** Unit/E2E/live Groq test pass.
- **Source / tests:** [exercise-swap.service.spec.ts](../backend_api/src/plan/adjust/exercise-swap.service.spec.ts); [adjust.e2e-spec.ts](../backend_api/test/adjust.e2e-spec.ts); [groq-adjustments.spec.ts](../backend_api/src/plan/adjust/groq-adjustments.spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F04](superpowers/plans/phase-4-swap-feedback/specs/F04-exercise-swap.md).

<a id="task-4-4"></a>

### Task 4.4 — Backend feedback

- [x] **Status: DONE**
- **Dependency:** [4.1](#task-4-1), [4.7](#task-4-7)
- **Phạm vi gốc:** `POST /api/v1/feedback` theo D2: bài tập điều chỉnh bằng quy tắc cố định; món ăn nhờ Groq API *(quyết định Q3)* — ăn nhiều → ngày kế tiếp ~90% mục tiêu, ăn ít → giữ mục tiêu, không có key thì giữ nguyên món kèm cảnh báo. Dấu hiệu nguy hiểm → `safety_warning` và ngày kế tiếp chỉ nghỉ hoặc đi bộ nhẹ. **Không bao giờ hạ calo mục tiêu xuống dưới BMR.** Ngày 3 → plan mới
- **Acceptance criteria hiện hành:** D2 ba câu; workout deterministic; ăn nhiều khoảng 90%, ăn ít giữ target, không dưới BMR; mock warning; danger nghỉ/khuyến cáo/không gọi AI; ngày 3 plan mới.
- **Evidence / lý do chưa đạt:** Unit/E2E/MySQL persistence pass; UI riêng ở 7.3.
- **Source / tests:** [feedback.service.spec.ts](../backend_api/src/plan/adjust/feedback.service.spec.ts); [workout-rules.spec.ts](../backend_api/src/plan/adjust/workout-rules.spec.ts); [adjust.e2e-spec.ts](../backend_api/test/adjust.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F05](superpowers/plans/phase-4-swap-feedback/specs/F05-feedback.md).

<a id="task-4-5"></a>

### Task 4.5 — Adjustment HTTP/SDK/smoke tests

- [x] **Status: DONE**
- **Dependency:** [4.2](#task-4-2), [4.3](#task-4-3), [4.4](#task-4-4), [4.8](#task-4-8)
- **Phạm vi:** Test cả 3 endpoint điều chỉnh, chạy được khi không có key; dấu hiệu nguy hiểm có test riêng. E2E qua HTTP thật gọi Groq mock server; smoke test gọi 3 endpoint trên bản build.
- **Evidence:** Unit và E2E pass.
- **Source / tests:** [adjust.e2e-spec.ts](../backend_api/test/adjust.e2e-spec.ts); [groq-adjustments.e2e-spec.ts](../backend_api/test/groq-adjustments.e2e-spec.ts); [smoke-test.mjs](../backend_api/scripts/smoke-test.mjs).
- **Spec:** [4/F06](superpowers/plans/phase-4-swap-feedback/specs/F06-endpoints-e2e.md).

<a id="task-4-7"></a>

### Task 4.7 — Calorie bounds và sample scaling

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3), [2.1](#task-2-1)
- **Phạm vi gốc:** *(bổ sung, quyết định Q1)* Khoảng calo theo tỉ lệ mục tiêu, kiểm tổng calo ngày (≥ BMR), nhân khẩu phần thực đơn mẫu cho khớp mục tiêu — sửa lỗi thực đơn thấp hơn BMR của nhiều người (BRD NFR-4, v2.5.0)
- **Acceptance criteria hiện hành:** Breakfast 15–35%, lunch/dinner 25–45%; ngày max(85% target,BMR) đến 110%; scale calorie/macro/ingredients; sample ±3 kcal cho ma trận/extremes.
- **Evidence / lý do chưa đạt:** Unit/E2E audit pass; macro balancing constraint #33 cũng có tests.
- **Source / tests:** [plan-validation.ts](../backend_api/src/plan/plan-validation.ts); [sample-plan.spec.ts](../backend_api/src/plan/sample-plan.spec.ts); [meal-scaling.spec.ts](../backend_api/src/plan/meal-scaling.spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F01](superpowers/plans/phase-4-swap-feedback/specs/F01-calories-restrictions.md).

<a id="task-4-8"></a>

### Task 4.8 — Adjustment lưu history

- [x] **Status: DONE**
- **Dependency:** [3.5](#task-3-5), [4.1](#task-4-1)
- **Phạm vi gốc:** *(bổ sung, quyết định Q4)* Đã đăng nhập: đổi món, đổi bài, feedback cập nhật plan đã lưu; plan từ feedback ngày 3 lưu mới
- **Acceptance criteria hiện hành:** Authenticated cập nhật đúng owner; không chạm plan user khác; day3 lưu mới; DB lỗi giữ response kèm warning.
- **Evidence / lý do chưa đạt:** Unit/E2E/MySQL live pass.
- **Source / tests:** [history.service.spec.ts](../backend_api/src/history/history.service.spec.ts); [adjust.e2e-spec.ts](../backend_api/test/adjust.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F02](superpowers/plans/phase-4-swap-feedback/specs/F02-client-plan.md).

<a id="task-4-9"></a>

### Task 4.9 — Tuning và đo Groq API thật

- [x] **Status: DONE**
- **Dependency:** [4.1](#task-4-1), [4.7](#task-4-7)
- **Phạm vi gốc:** *(cập nhật sang Groq)* Cấu hình & đo Groq API (`GROQ_MODEL=openai/gpt-oss-120b`, `GROQ_TIMEOUT_MS=60000`, `GROQ_TOTAL_TIMEOUT_MS=90000`): prompt ghi rõ danh sách loại trừ và quy tắc macro/workout; kiểm tra bằng `scripts/test-groq-plan.mjs` và `scripts/test-groq-adjustments.mjs`
- **Acceptance criteria hiện hành:** Prompt ghi rõ loại trừ; budget 60s/call, 90s tổng; phép đo live trả `source: groq`, vượt qua validation backend, calo đúng khoảng mục tiêu.
- **Evidence / lý do chưa đạt:** Đã chạy live với `GROQ_API_KEY` thật (10/11/2026): `test-groq-plan.mjs` PASS (`source: groq`, `elapsedMs: 10511`, target 1624 → `[1625, 1635, 1625]`); `meal_swap` (1873ms) và `exercise_swap` (1190ms) HTTP 200 PASS.
- **Source / tests:** [groq-plan.service.ts](../backend_api/src/plan/groq-plan.service.ts); [test-groq-plan.mjs](../backend_api/scripts/test-groq-plan.mjs); [test-groq-adjustments.mjs](../backend_api/scripts/test-groq-adjustments.mjs); [GROQ_TRIAL.md](../backend_api/GROQ_TRIAL.md).

<a id="task-5-1"></a>

### Task 5.1 — Flutter packages

- [x] **Status: DONE**
- **Dependency:** [1.2](#task-1-2)
- **Phạm vi gốc:** Thêm package `http`, `provider`, `shared_preferences`
- **Acceptance criteria hiện hành:** http/provider/shared_preferences có trong pubspec/lock; app biên dịch và tests dùng được.
- **Evidence / lý do chưa đạt:** Flutter tests, APK debug/web build audit pass.
- **Source / tests:** [pubspec.yaml](../frontend_app/pubspec.yaml); [pubspec.lock](../frontend_app/pubspec.lock).
- **Spec, subtasks và cổng kiểm:** [5/F02](superpowers/plans/phase-5-frontend-foundation/specs/F02-packages-platform.md).

<a id="task-5-2"></a>

### Task 5.2 — API URL và quyền mạng

- [x] **Status: DONE**
- **Dependency:** [5.1](#task-5-1)
- **Phạm vi gốc:** Địa chỉ backend qua `--dart-define=API_BASE_URL` — web: `localhost`; máy ảo Android: `10.0.2.2`; điện thoại thật: IP mạng LAN của máy chạy backend (`lib/config/api_config.dart`). Quyền mạng Android (release), iOS, macOS
- **Acceptance criteria hiện hành:** API_BASE_URL override; Android emulator 10.0.2.2, web localhost, phone LAN; INTERNET main; debug cleartext; iOS local networking/macOS network.client; configuration tests pass.
- **Evidence / lý do chưa đạt:** Config tests và APK build audit pass; quyền config không thay nghiệm thu thiết bị hay HTTPS release.
- **Source / tests:** [api_config.dart](../frontend_app/lib/config/api_config.dart); [api_config_test.dart](../frontend_app/test/config/api_config_test.dart); [AndroidManifest.xml](../frontend_app/android/app/src/main/AndroidManifest.xml).
- **Spec, subtasks và cổng kiểm:** [5/F02](superpowers/plans/phase-5-frontend-foundation/specs/F02-packages-platform.md).

<a id="task-5-3"></a>

### Task 5.3 — Dart API models

- [x] **Status: DONE**
- **Dependency:** [5.1](#task-5-1), [1.2](#task-1-2)
- **Phạm vi gốc:** Model Dart có `fromJson`/`toJson` theo BRD mục 6 (`lib/models/api/`), đi vòng tròn đúng JSON server trả. Màn hình chuyển sang model mới và xoá view-model cũ `meal_plan.dart` ở 6.7
- **Acceptance criteria hiện hành:** fromJson/toJson round-trip nguyên JSON/numbers; missing/type/unknown codes fail; fixtures plan/feedback/auth/history/health; UI migration thuộc 6.7.
- **Evidence / lý do chưa đạt:** Model tests audit pass; fixture mới từ HTTP chưa được đảm bảo ở 5.8.
- **Source / tests:** [contract_test.dart](../frontend_app/test/models/contract_test.dart); [meal_plan.dart](../frontend_app/lib/models/api/meal_plan.dart).
- **Spec, subtasks và cổng kiểm:** [5/F03](superpowers/plans/phase-5-frontend-foundation/specs/F03-dart-models.md).

<a id="task-5-4"></a>

### Task 5.4 — ApiClient

- [x] **Status: DONE**
- **Dependency:** [5.2](#task-5-2), [5.3](#task-5-3)
- **Phạm vi gốc:** `ApiClient` (`lib/services/`): gọi mọi endpoint; lỗi → `ApiException` có câu tiếng Việt, không crash (NFR-2); timeout 105 s cho request có Groq AI
- **Acceptance criteria hiện hành:** Đầy đủ endpoints (kể cả register/login/change-password/history/delete); injected HTTP client; UTF8 bodyBytes; Vietnamese ApiException; 105s AI/15s còn lại; parse errors captured; 401 callback và login không token cũ; không log body.
- **Evidence / lý do chưa đạt:** Service tests và widget integration tests pass.
- **Source / tests:** [api_client_test.dart](../frontend_app/test/services/api_client_test.dart); [api_client.dart](../frontend_app/lib/services/api_client.dart).
- **Spec, subtasks và cổng kiểm:** [5/F04](superpowers/plans/phase-5-frontend-foundation/specs/F04-api-client.md).

<a id="task-5-5"></a>

### Task 5.5 — Plan/Auth providers và persistence

- [x] **Status: DONE**
- **Dependency:** [5.4](#task-5-4)
- **Phạm vi gốc:** `PlanProvider` (plan + hồ sơ, lưu `shared_preferences`) và `AuthProvider` (JWT; 401 → đăng xuất)
- **Acceptance criteria hiện hành:** Save/restore plan/profile/JWT; corrupt storage xử lý; busy lock; 401 signout; swap/feedback whole plan; pending profile riêng; không log health.
- **Evidence / lý do chưa đạt:** Provider tests audit pass; UI integration còn thiếu.
- **Source / tests:** [plan_provider_test.dart](../frontend_app/test/providers/plan_provider_test.dart); [auth_provider_test.dart](../frontend_app/test/providers/auth_provider_test.dart).
- **Spec, subtasks và cổng kiểm:** [5/F05](superpowers/plans/phase-5-frontend-foundation/specs/F05-providers.md).

<a id="task-5-6"></a>

### Task 5.6 — Startup theo saved plan và widget test

- [x] **Status: DONE**
- **Dependency:** [5.5](#task-5-5)
- **Phạm vi gốc:** `MainShell`: chưa có plan → mở Onboarding, đã có → Dashboard; viết lại `widget_test.dart`
- **Acceptance criteria hiện hành:** No plan → onboarding; valid saved plan → dashboard offline; corrupt plan không crash; widget test xác minh không gọi mạng lúc mở.
- **Evidence:** N04 (31/10/2026): implementation và unit/widget tests đạt criteria hiện hành; analyze sạch, 158 PASS/2 SKIP, APK debug PASS. Chi tiết/giới hạn Android ở nhật ký N04 đầu tài liệu.
- **Source / tests:** [main.dart](../frontend_app/lib/main.dart); [app_harness.dart](../frontend_app/test/app_harness.dart).
- **Spec, subtasks và cổng kiểm:** [5/F06](superpowers/plans/phase-5-frontend-foundation/specs/F06-main-shell-ci.md).

<a id="task-5-7"></a>

### Task 5.7 — CORS

- [x] **Status: DONE**
- **Dependency:** [2.4](#task-2-4)
- **Phạm vi gốc:** Bật CORS trong `configureApp()` qua `CORS_ORIGINS` (trống khi phát triển → `localhost`/`127.0.0.1` mọi cổng; trống khi deploy → tắt), cho phép header `Authorization`
- **Acceptance criteria hiện hành:** Dev empty localhost/127.0.0.1; production empty off; origin allowlist validated; GET/POST/DELETE, Authorization/Content-Type; configureApp chung.
- **Evidence / lý do chưa đạt:** CORS unit/E2E audit pass.
- **Source / tests:** [cors-options.spec.ts](../backend_api/src/cors-options.spec.ts); [cors.e2e-spec.ts](../backend_api/test/cors.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [5/F01](superpowers/plans/phase-5-frontend-foundation/specs/F01-backend-cors-fixtures.md).

<a id="task-5-9"></a>

### Task 5.9 — Flutter CI

- [ ] **Status: UNVERIFIED**
- **Dependency:** [5.6](#task-5-6)
- **Phạm vi:** CI Flutter: `flutter analyze` + `flutter test` (`.github/workflows/frontend.yml`).
- **Evidence:** Workflow đã cấu hình; `flutter analyze` sạch và 195/195 tests local pass; chưa xác minh remote GitHub Actions run trên commit mới.
- **Source / tests:** [frontend.yml](../.github/workflows/frontend.yml).
- **Spec:** [5/F06](superpowers/plans/phase-5-frontend-foundation/specs/F06-main-shell-ci.md).

<a id="task-5-10"></a>

### Task 5.10 — Android smoke và offline restoration

- [ ] **Status: PARTIAL**
- **Dependency:** [5.2](#task-5-2), [5.5](#task-5-5), [5.6](#task-5-6)
- **Phạm vi gốc:** *(bổ sung sau khi kiểm lại)* Chạy trên máy ảo Android 16: sửa `compileSdk` 34 → 36 (APK không build được sau khi thêm `shared_preferences`); `integration_test/backend_smoke_test.dart` gọi backend thật từ máy ảo (chạy tay); mở app có plan đã lưu → Dashboard kể cả khi backend tắt, plan hỏng → Onboarding
- **Acceptance criteria hiện hành:** compileSdk≥36; APK debug/release; real backend smoke từ emulator; save/restore khi backend off; corrupt plan → onboarding; integration test an toàn mock.
- **Evidence:** N04 startup/offline restoration unit/widget pass, compileSdk36/APK debug pass; real backend smoke từ emulator và release/device acceptance còn UNVERIFIED. integration_test/backend_smoke_test.dart chưa có.
- **Source / tests:** [build.gradle.kts](../frontend_app/android/app/build.gradle.kts); [main.dart](../frontend_app/lib/main.dart).

<a id="task-6-1"></a>

### Task 6.1 — Onboarding ba bước, D5 và safety

- [x] **Status: DONE**
- **Dependency:** [5.5](#task-5-5), [6.9](#task-6-9), [6.10](#task-6-10)
- **Phạm vi gốc:** Onboarding chia 3 bước (D6-B2): thêm tuổi (≥ 18), giới tính, mức vận động (FR-1.1, FR-1.2 — backend bắt buộc nhưng giao diện chưa có); khoá "Giảm mỡ" khi BMI < 18,5 hoặc mang thai / cho con bú (D6-A1, A3); nhập hạn chế theo D5 + dòng khuyến cáo y tế (D4); validate cùng giới hạn với backend, báo lỗi ngay khi nhập. Bỏ giá trị điền sẵn 168 / 62; nút tiếp tục phải mang hồ sơ đi (hiện `onNext` không truyền dữ liệu nào)
- **Acceptance criteria hiện hành:** Body → goal/activity → restrictions, progress/bottom button/back; age18–100,height100–250,weight30–250; blank không dùng fallback; BMI<18.5/pregnancy khóa cut; nữ pregnancy; D5 toggle off/multi/Other≤300; disclaimer; gửi Profile.
- **Evidence / lý do chưa đạt:** N02 ngày 14/10/2026: ba bước, dữ liệu raw không fallback, validators profile_rules, pregnancy/rawBMI/cut, D5 và counter300, back/forward/retry giữ dữ liệu, guard trước request. Unit/widget tests trên viewport Pixel2 và live HTTP, analyze, APK debug đều pass; xem [N02](#n02). Device manual N02 còn UNVERIFIED, không đồng nghĩa integration/device milestone6.7 đạt.
- **Source / tests:** [basic_info_screen.dart](../frontend_app/lib/screens/onboarding/basic_info_screen.dart); [goal_screen.dart](../frontend_app/lib/screens/onboarding/goal_screen.dart); [restrictions_screen.dart](../frontend_app/lib/screens/onboarding/restrictions_screen.dart); [validation tests](../frontend_app/test/providers/onboarding_validation_test.dart); [widget tests N02](../frontend_app/test/screens/onboarding_n02_test.dart).
- **Spec, subtasks và cổng kiểm:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md).

<a id="task-6-2"></a>

### Task 6.2 — Profile edit và regenerate

- [x] **Status: DONE**
- **Dependency:** [6.1](#task-6-1), [5.5](#task-5-5)
- **Phạm vi gốc:** Tab "Cá nhân": xem và sửa hồ sơ, lưu trên máy (FR-1.6); sửa xong thì gợi ý tạo lại plan (hiện ghi cứng "168 cm • 62 kg • Giảm mỡ", không theo Onboarding)
- **Acceptance criteria hiện hành:** Xem/sửa mọi field và D5 như onboarding; save local draft riêng; gợi ý regenerate; swap/feedback vẫn dùng profile của plan tới khi tạo lại.
- **Evidence:** N04 (31/10/2026): implementation và unit/widget tests đạt criteria hiện hành; analyze sạch, 158 PASS/2 SKIP, APK debug PASS. Chi tiết/giới hạn Android ở nhật ký N04 đầu tài liệu.
- **Source / tests:** [edit_profile_sheet.dart](../frontend_app/lib/screens/profile/edit_profile_sheet.dart); [plan_provider.dart](../frontend_app/lib/providers/plan_provider.dart).
- **Spec, subtasks và cổng kiểm:** [6/F03](superpowers/plans/phase-6-connect-mvp/specs/F03-app-logic.md); [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md).

<a id="task-6-3"></a>

### Task 6.3 — Loading tạo plan thật

- [x] **Status: DONE**
- **Dependency:** [6.1](#task-6-1), [5.4](#task-5-4)
- **Phạm vi gốc:** Loading: gọi API thật thay cho bộ đếm giờ giả; lỗi → nút thử lại (NFR-1, NFR-2). Có Groq AI thì chờ thật khoảng 10–15 giây, tối đa theo budget 90 giây (client 105 giây) — câu chờ và thanh tiến trình phải hợp với khoảng này. Bỏ nút "Xem trước kế hoạch ngay" và các câu chờ bịa số liệu ("Cân đối Macro: 140g Carbs, 65g Protein…", "phù hợp ngân sách")
- **Acceptance criteria hiện hành:** Gọi PlanProvider.generate(Profile); success mới mở home; error/retry; timeout app>90s; progress không bịa dữ liệu hoặc skip kế hoạch.
- **Evidence / lý do chưa đạt:** N01 đạt và đã chạy Groq live trên app thật (`source: groq`). Widget tests, HTTP backend local thật, analyze pass; xem [N01](#n01).
- **Source / tests:** [generating_plan_screen.dart](../frontend_app/lib/screens/onboarding/generating_plan_screen.dart); [plan_provider.dart](../frontend_app/lib/providers/plan_provider.dart); [widget tests N01](../frontend_app/test/screens/generating_plan_screen_test.dart); [HTTP live tests N01](../frontend_app/test/services/n01_backend_live_test.dart).
- **Spec, subtasks và cổng kiểm:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md).

<a id="task-6-4"></a>

### Task 6.4 — Dashboard/Plan dữ liệu thật

- [x] **Status: DONE**
- **Dependency:** [6.3](#task-6-3), [5.3](#task-5-3), [6.11](#task-6-11)
- **Phạm vi:** Dashboard & Plan hiển thị đủ 3 ngày, 3 bữa/ngày, bài tập, tổng calo & macro (`macro_ring.dart`), `warnings` và trạng thái nguồn tạo plan.
- **Evidence:** Đã nối hoàn chỉnh với `PlanProvider` thật: chọn ngày 1–3 đổi nội dung, hiển thị meals/workout/calories/macros/source/warnings/disclaimer.
- **Source / tests:** [home_screen.dart](../frontend_app/lib/screens/home/home_screen.dart); [plan_screen.dart](../frontend_app/lib/screens/plan/plan_screen.dart).
- **Spec:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md).

<a id="task-6-5"></a>

### Task 6.5 — Grocery đồng bộ và lưu checklist

- [x] **Status: DONE**
- **Dependency:** [6.4](#task-6-4), [5.5](#task-5-5)
- **Phạm vi gốc:** Grocery: dựng từ `grocery_list`; trạng thái tích chọn lưu cục bộ (FR-3.2). Tên nhóm theo BRD FR-3.1 (*Đạm*, *Rau củ quả*, *Gạo, bún & gia vị* — hiện là "Thịt & Thủy hải sản", "Gia vị & nguyên liệu khác"); thêm thao tác xoá món đã có sẵn trong tủ lạnh (FR-3.2); quyết định giữ hay bỏ nút "Thêm nguyên liệu" (không có trong BRD)
- **Acceptance criteria hiện hành:** Dựng từ grocery_list, ba nhóm BRD; persist bought/have; ẩn/khôi phục món có sẵn; key category+name+quantity; swap/new plan cập nhật; chốt bỏ/giữ add ingredient theo BRD.
- **Evidence / lý do chưa đạt:** N03: UI nối grocery_list và GroceryProvider; nhóm BRD, bought/have/khôi phục/tìm kiếm/lọc, bỏ add ingredient. Widget test swap cập nhật grocery, giữ dòng không đổi; persistence provider tests đạt.
- **Source / tests:** [grocery_screen.dart](../frontend_app/lib/screens/grocery/grocery_screen.dart); [grocery_provider.dart](../frontend_app/lib/providers/grocery_provider.dart).
- **Spec, subtasks và cổng kiểm:** [6/F03](superpowers/plans/phase-6-connect-mvp/specs/F03-app-logic.md); [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md).

<a id="task-6-6"></a>

### Task 6.6 — Widget tests với FakeBackend

- [ ] **Status: PARTIAL**
- **Dependency:** [6.1](#task-6-1), [6.2](#task-6-2), [6.3](#task-6-3), [6.4](#task-6-4), [6.5](#task-6-5)
- **Phạm vi:** Widget tests toàn bộ luồng app dùng backend giả / HTTP client mock.
- **Evidence:** Đã có 195/195 unit & widget tests (Onboarding, Plan, Swap, Grocery, Profile, Feedback, Auth, History); còn kiểm tra thêm trên thiết bị Android thật nếu cần.
- **Source / tests:** [app_harness.dart](../frontend_app/test/app_harness.dart); [fake_backend.dart](../frontend_app/test/fake_backend.dart); [widget tests N02](../frontend_app/test/screens/onboarding_n02_test.dart).

<a id="task-6-7"></a>

### Task 6.7 — UI integration & device E2E

- [ ] **Status: PARTIAL**
- **Dependency:** [6.1](#task-6-1), [6.2](#task-6-2), [6.3](#task-6-3), [6.4](#task-6-4), [6.5](#task-6-5), [6.6](#task-6-6)
- **Phạm vi:** Toàn bộ màn hình dùng `PlanProvider`/`AuthProvider`/`GroceryProvider` và model `lib/models/api/`; kiểm thử E2E trên máy ảo Android (`flutter test integration_test`).
- **Evidence:** Các màn hình sản phẩm đều đã dùng provider thật và models API; `flutter test` + APK debug pass. Còn kịch bản `integration_test` tự động trên Android Emulator.
- **Source / tests:** [main.dart](../frontend_app/lib/main.dart); [api_client.dart](../frontend_app/lib/services/api_client.dart).

<a id="task-6-8"></a>

### Task 6.8 — Branding/platform UI

- [ ] **Status: PARTIAL**
- **Dependency:** [6.7](#task-6-7)
- **Phạm vi:** Tên app hiển thị "SmartFit AI" trên Android/web/iOS/macOS, icon và splash screen đồng bộ.
- **Evidence:** Cấu hình/assets/build APK/web đã có; nghiệm thu hiển thị trên máy thật khi đóng gói release.
- **Source / tests:** [AndroidManifest.xml](../frontend_app/android/app/src/main/AndroidManifest.xml); [manifest.json](../frontend_app/web/manifest.json).

<a id="task-6-9"></a>

### Task 6.9 — Backend safe profile và validation

- [ ] **Status: PARTIAL**
- **Dependency:** [1.2](#task-1-2), [5.3](#task-5-3)
- **Phạm vi:** Backend & Form: tuổi ≥ 18; BMI < 18,5 hoặc mang thai/cho con bú khi chọn `cut` → 400 kèm câu tiếng Việt; BRD v2.6.0.
- **Evidence:** `CreatePlanDto`, `profile-safety.spec.ts` và `profile_rules_test.dart` PASS.
- **Source / tests:** [create-plan.dto.ts](../backend_api/src/plan/dto/create-plan.dto.ts); [profile-safety.spec.ts](../backend_api/src/plan/profile-safety.spec.ts); [profile_rules_test.dart](../frontend_app/test/models/profile_rules_test.dart).

<a id="task-6-10"></a>

### Task 6.10 — Exercise level mọi đường và prompt Groq

- [x] **Status: DONE**
- **Dependency:** [4.1](#task-4-1), [4.3](#task-4-3), [4.4](#task-4-4), [6.9](#task-6-9)
- **Phạm vi:** *(D6-A4)* Backend: chọn mức động tác theo tuổi và `activity_level` cho thực đơn mẫu và kho đổi bài; prompt Groq API cùng luật.
- **Evidence:** `exercise-level.spec.ts`, `profile-exercise.spec.ts`, `ai_workspace` đồng bộ pipeline và live Groq PASS.
- **Source / tests:** [exercise-level.spec.ts](../backend_api/src/plan/exercise-level.spec.ts); [generate-plan-experiment.ts](../ai_workspace/generate-plan-experiment.ts).

<a id="task-6-11"></a>

### Task 6.11 — Plan schedule và expiry

- [x] **Status: DONE**
- **Dependency:** [5.5](#task-5-5)
- **Phạm vi gốc:** *(D6-B1)* App lưu ngày bắt đầu plan, Dashboard mở đúng ngày theo lịch; quá 3 ngày → gợi ý tạo plan mới
- **Acceptance criteria hiện hành:** Persist start date; date-only theo local calendar; dashboard hôm nay; feedbackday3 new plan bắt đầu ngày mai; hết3ngày gợi ý generate; resume cập nhật ngày.
- **Evidence:** N04 (31/10/2026): implementation và unit/widget tests đạt criteria hiện hành; analyze sạch, 158 PASS/2 SKIP, APK debug PASS. Chi tiết/giới hạn Android ở nhật ký N04 đầu tài liệu.
- **Source / tests:** [plan_schedule.dart](../frontend_app/lib/models/plan_schedule.dart); [plan_provider.dart](../frontend_app/lib/providers/plan_provider.dart); [plan_schedule_test.dart](../frontend_app/test/models/plan_schedule_test.dart).
- **Spec, subtasks và cổng kiểm:** [6/F03](superpowers/plans/phase-6-connect-mvp/specs/F03-app-logic.md).

<a id="task-7-1"></a>

### Task 7.1 — Meal swap UI

- [x] **Status: DONE**
- **Dependency:** [4.2](#task-4-2), [6.4](#task-6-4), [6.5](#task-6-5), [6.7](#task-6-7)
- **Phạm vi gốc:** Nút "Đổi món" gọi API (hiện đang xoay vòng trong danh sách món viết cứng); thay cả plan và checklist bằng plan server trả về. 409 → báo hồ sơ đã đổi, gợi ý tạo plan mới; 422 → báo không còn món thay thế phù hợp *(làm ở giai đoạn 6, quyết định Q3)*
- **Bổ sung từ PLAN chính trước hợp nhất:** Nút "Đổi món" thay cả plan và checklist bằng plan server trả về. 409 → báo hồ sơ đã đổi, gợi ý tạo plan mới; 422 → báo không còn món thay thế phù hợp
- **Acceptance criteria hiện hành:** Truyền đúng meal_id cho mọi bữa; PlanProvider.swapMeal; full response cập nhật plan/grocery; busy/error/409regenerate/422keep-old; không mock nutrient claims.
- **Evidence / lý do chưa đạt:** N03: detail nhận meal_id từ route; swap gọi PlanProvider.swapMeal, giữ nguyên profile/plan, full response cập nhật và lưu; tests success/422/retry/busy/409 giữ plan cũ đạt. Không tạo alternatives/nutrients giả.
- **Source / tests:** [meal_detail_screen.dart](../frontend_app/lib/screens/meal/meal_detail_screen.dart); [meal_swap_sheet.dart](../frontend_app/lib/screens/meal/meal_swap_sheet.dart).
- **Spec, subtasks và cổng kiểm:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md).

<a id="task-7-2"></a>

### Task 7.2 — Exercise swap UI

- [x] **Status: DONE**
- **Dependency:** [4.3](#task-4-3), [6.4](#task-6-4), [6.7](#task-6-7)
- **Phạm vi:** Nút "Đổi bài" gọi API thật qua `PlanProvider.swapExercise`.
- **Evidence:** Đã nối `workout_swap_sheet.dart` với API thật, loading/error/retry/busy, lưu full response và giữ giới hạn an toàn.
- **Source / tests:** [workout_swap_sheet.dart](../frontend_app/lib/screens/workout/workout_swap_sheet.dart).
- **Spec:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md).

<a id="task-7-3"></a>

### Task 7.3 — Feedback end-of-day UI

- [x] **Status: DONE**
- **Dependency:** [4.4](#task-4-4), [6.7](#task-6-7), [6.11](#task-6-11)
- **Phạm vi gốc:** Làm lại bảng feedback theo D2 (3 câu hỏi, câu tình trạng cơ thể chọn nhiều); gọi API, cập nhật ngày kế tiếp; nhận `safety_warning` → hiện khuyến cáo ngừng tập, hỏi ý kiến bác sĩ. **Khoá nút sau khi đã gửi feedback cho một ngày** — backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa. Bỏ câu báo viết sẵn "AI đã cân đối lại thực đơn Ngày 2!" (hiện hiện ra dù không có gì thay đổi)
- **Bổ sung từ PLAN chính trước hợp nhất:** Làm lại bảng feedback theo D2 (3 câu hỏi, câu tình trạng cơ thể chọn nhiều); gọi API, cập nhật ngày kế tiếp; nhận `safety_warning` → hiện khuyến cáo ngừng tập, hỏi ý kiến bác sĩ. **Khoá nút sau khi đã gửi feedback cho một ngày** — backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa
- **Acceptance criteria hiện hành:** Ba câu D2/body multi; gửi mã BRD; update ngày sau; safetyWarning nổi bật/ngừng tập/hỏi bác sĩ; day3 lịch ngày mai; persist lock plan/day; không success text viết sẵn khi không đổi.
- **Evidence:** N05 có UI ba câu D2/entry từ Dashboard và Plan, API thật, SQLite receipt bền theo plan/day, snapshot pending/completed, error/retry/success chính xác, warning/rest và day3 queue đến ngày mai. Tests bao gồm concurrent, restart DB/app, lỗi ghi, bảo toàn ngày cũ/draft/checklist, lịch sử và HTTP fullflow với AI giả lập. Nghiệm thu Android/Groq live vẫn UNVERIFIED, không đồng nghĩa toàn bộ phase đã được nghiệm thu trên thiết bị.
- **Source / tests:** [daily_feedback_screen.dart](../frontend_app/lib/screens/feedback/daily_feedback_screen.dart), [PlanProvider](../frontend_app/lib/providers/plan_provider.dart), [FeedbackService](../backend_api/src/plan/adjust/feedback.service.ts), [N05 evidence/file list](N05_FEEDBACK.md).

<a id="task-8-1"></a>

### Task 8.1 — Đăng ký, Đăng nhập mật khẩu & Bỏ qua (Skip)

- [x] **Status: DONE**
- **Dependency:** [3.3](#task-3-3), [5.5](#task-5-5)
- **Phạm vi gốc:** Màn hình đăng nhập/đăng ký bằng Email + Mật khẩu (`PasswordAuthSheet`) kết nối API thật (`/api/v1/auth/register`, `/api/v1/auth/login`), kèm nút bỏ qua đăng nhập để dùng chế độ khách (FR-7). *(Đã loại bỏ Google Sign-In).*
- **Acceptance criteria hiện hành:** Đăng ký (tên, email, mật khẩu, xác nhận), đăng nhập (email, mật khẩu), bỏ qua (chế độ khách), loading/error/account UI.
- **Evidence / lý do chưa đạt:** Đã hoàn thiện trong `WelcomeScreen`, `ProfileScreen`, `SettingsScreen`, `PasswordAuthSheet`; 7 widget tests trong `auth_login_test.dart` PASS.
- **Source / tests:** [welcome_screen.dart](../frontend_app/lib/screens/auth/welcome_screen.dart); [auth_sheet.dart](../frontend_app/lib/widgets/auth_sheet.dart); [auth_provider.dart](../frontend_app/lib/providers/auth_provider.dart); [auth_login_test.dart](../frontend_app/test/screens/auth_login_test.dart).

<a id="task-8-2"></a>

### Task 8.2 — JWT, Đổi mật khẩu, Login-again UI & Xóa tài khoản

- [x] **Status: DONE**
- **Dependency:** [8.1](#task-8-1), [3.8](#task-3-8)
- **Phạm vi gốc:** Gắn JWT vào request; nhận 401 → đăng xuất & hiện banner nhắc đăng nhập lại (`SessionExpiredBanner`); Đổi mật khẩu (`ChangePasswordSheet` → `POST /api/v1/auth/change-password`); Đăng xuất và Xóa tài khoản (`DELETE /api/v1/me`) qua `AuthProvider` thật.
- **Acceptance criteria hiện hành:** JWT gửi request cần auth; restore session; 401 logout và gợi ý login lại; đổi mật khẩu có kiểm mật khẩu cũ; logout/delete calls dùng provider thật.
- **Evidence / lý do chưa đạt:** Đã hoàn thiện UI + Provider + Backend + MySQL; unit & widget tests (`auth_login_test.dart`) PASS.
- **Source / tests:** [api_client.dart](../frontend_app/lib/services/api_client.dart); [auth_provider.dart](../frontend_app/lib/providers/auth_provider.dart); [settings_screen.dart](../frontend_app/lib/screens/settings/settings_screen.dart); [delete_account_sheet.dart](../frontend_app/lib/screens/settings/delete_account_sheet.dart).

<a id="task-8-3"></a>

### Task 8.3 — History UI

- [x] **Status: DONE**
- **Dependency:** [3.5](#task-3-5), [8.1](#task-8-1), [8.2](#task-8-2)
- **Phạm vi gốc:** Màn hình Lịch sử kế hoạch (`HistoryScreen` & `HistoryDetailScreen`), truy cập từ Cá nhân / Kế hoạch / Cài đặt: danh sách plan cũ đã lưu trên MySQL, bấm vào xem chi tiết 3 ngày + danh sách đi chợ.
- **Acceptance criteria hiện hành:** Danh sách ngày tạo/calories/nhãn Đang mở; xem chi tiết 3 ngày; trạng thái khách/loading/error/retry/empty; user khác 404; đồng bộ theo tài khoản.
- **Evidence / lý do chưa đạt:** Đã triển khai `HistoryScreen`, `HistoryDetailScreen`, route `/history` và 5 widget tests trong `history_screen_test.dart` PASS.
- **Source / tests:** [history_screen.dart](../frontend_app/lib/screens/history/history_screen.dart); [routes.dart](../frontend_app/lib/routes.dart); [history_screen_test.dart](../frontend_app/test/screens/history_screen_test.dart).

<a id="task-9-1"></a>

### Task 9.1 — Host và durable storage

- [ ] **Status: UNVERIFIED**
- **Dependency:** [3.2](#task-3-2)
- **Phạm vi:** Triển khai MySQL (`DB_TYPE=mysql`, `smartfit_db`) trên cloud / VPS hoặc SQLite kèm ổ lưu trữ bền khi deploy thực tế.
- **Evidence:** Đã cấu hình và kiểm chứng thành công trên MySQL localhost (`smartfit_db`), chưa deploy lên cloud host công khai.
- **Source / tests:** [BRD.md](../BRD.md); [data-source-options.ts](../backend_api/src/database/data-source-options.ts).

<a id="task-9-2"></a>

### Task 9.2 — Production backend deployment

- [ ] **Status: UNVERIFIED**
- **Dependency:** [9.1](#task-9-1), [3.3](#task-3-3), [5.7](#task-5-7)
- **Phạm vi:** Deploy backend lên host ngoài với `NODE_ENV=production`, `DB_TYPE=mysql`, `JWT_SECRET`, `PLAN_AI_PROVIDER=groq`, `GROQ_API_KEY`, `CORS_ORIGINS`.
- **Evidence:** Đã cấu hình sẵn sàng cho local; chưa thực hiện deploy lên server public.
- **Source / tests:** [SETUP_CREDENTIALS.md](SETUP_CREDENTIALS.md); [auth-config.ts](../backend_api/src/auth/auth-config.ts).

<a id="task-9-3"></a>

### Task 9.3 — Demo web/APK với production URL

- [ ] **Status: UNVERIFIED**
- **Dependency:** [9.2](#task-9-2), [6.7](#task-6-7), [6.8](#task-6-8)
- **Phạm vi:** Build bản phát hành (APK/Web) trỏ `--dart-define=API_BASE_URL=https://<backend-host>`.
- **Evidence:** Build APK debug/web local đạt; chưa đóng gói release với URL production công khai.
- **Source / tests:** [build.gradle.kts](../frontend_app/android/app/build.gradle.kts); [api_config.dart](../frontend_app/lib/config/api_config.dart).

<a id="task-9-4"></a>

### Task 9.4 — Full-flow acceptance (Local / Production)

- [ ] **Status: PARTIAL**
- **Dependency:** [6.6](#task-6-6), [6.7](#task-6-7), [7.1](#task-7-1), [7.2](#task-7-2), [7.3](#task-7-3), [8.2](#task-8-2), [8.3](#task-8-3), [9.3](#task-9-3)
- **Phạm vi:** Nghiệm thu toàn luồng Client → Server → Groq AI / Fallback → MySQL → Client.
- **Evidence:** Backend 507 unit + 120 E2E, MySQL `smartfit_db`, Groq live (`source: groq`) và 195 Flutter tests đều PASS trên máy phát triển; chỉ còn kiểm tra trên thiết bị/production nếu deploy public.
- **Source / tests:** [smoke-test.mjs](../backend_api/scripts/smoke-test.mjs); [app_harness.dart](../frontend_app/test/app_harness.dart).

<a id="task-9-5"></a>

### Task 9.5 — README/changelog/wiki

- [ ] **Status: PARTIAL**
- **Dependency:** [9.4](#task-9-4)
- **Phạm vi:** Đồng bộ tài liệu dự án (README, changelog, wiki, BRD).
- **Evidence:** `docs/PLAN.md` đã được cập nhật khớp thực trạng hoàn thành dự án; có thể bổ sung ảnh chụp màn hình vào README nếu cần giao nộp.
- **Source / tests:** [README.md](../README.md); [CLAUDE.md](../CLAUDE.md); [flutter-ui.md](knowledge/wiki/flutter-ui.md).

<a id="task-9-6"></a>

### Task 9.6 — Slides và video demo

- [ ] **Status: NOT STARTED**
- **Dependency:** [9.4](#task-9-4), [9.5](#task-9-5)
- **Phạm vi:** Slide báo cáo và video demo sản phẩm (nếu cần nộp báo cáo).
- **Evidence:** Ngoài phạm vi source code; chưa tạo artifact slide/video trong repo.
- **Source / tests:** [README.md](../README.md).

### Chỉ mục Feature Specs (Tra cứu thiết kế)

| Feature | Task liên quan | Spec |
|---|---|---|
| P1-F01 | [1.1](#task-1-1), [1.2](#task-1-2) | [F01-brd-contract.md](superpowers/plans/phase-1-api-contract/specs/F01-brd-contract.md) |
| P1-F02 | [1.3](#task-1-3) | [F02-plan-types-validation.md](superpowers/plans/phase-1-api-contract/specs/F02-plan-types-validation.md) |
| P1-F03 | [1.3](#task-1-3) | [F03-daily-target.md](superpowers/plans/phase-1-api-contract/specs/F03-daily-target.md) |
| P1-F04 | [1.3](#task-1-3) | [F04-plan-assembly.md](superpowers/plans/phase-1-api-contract/specs/F04-plan-assembly.md) |
| P1-F05 | [1.3](#task-1-3) | [F05-sample-plan.md](superpowers/plans/phase-1-api-contract/specs/F05-sample-plan.md) |
| P1-F06 | [1.3](#task-1-3) | [F06-generate-plan-pipeline.md](superpowers/plans/phase-1-api-contract/specs/F06-generate-plan-pipeline.md) |
| P1-F07 | [1.4](#task-1-4), [9.5](#task-9-5) | [F07-docs-wiki.md](superpowers/plans/phase-1-api-contract/specs/F07-docs-wiki.md) |
| P2-F01 | [2.1](#task-2-1) | [F01-daily-target-matrix.md](superpowers/plans/phase-2-backend-tests/specs/F01-daily-target-matrix.md) |
| P2-F02 | [2.5](#task-2-5) | [F02-gemini-service-real-sdk.md](superpowers/plans/phase-2-backend-tests/specs/F02-gemini-service-real-sdk.md) *(chuyển sang Groq API)* |
| P2-F03 | [2.3](#task-2-3) | [F03-plan-service-retry.md](superpowers/plans/phase-2-backend-tests/specs/F03-plan-service-retry.md) |
| P2-F04 | [2.4](#task-2-4) | [F04-e2e-generate-plan.md](superpowers/plans/phase-2-backend-tests/specs/F04-e2e-generate-plan.md) |
| P2-F05 | [2.6](#task-2-6) | [F05-github-actions.md](superpowers/plans/phase-2-backend-tests/specs/F05-github-actions.md) |
| P2-F06 | [9.5](#task-9-5) | [F06-docs-wiki.md](superpowers/plans/phase-2-backend-tests/specs/F06-docs-wiki.md) |
| P3-F01 | [3.1](#task-3-1), [3.2](#task-3-2) | [F01-database.md](superpowers/plans/phase-3-auth-history/specs/F01-database.md) |
| P3-F02 | [3.3](#task-3-3), [3.4](#task-3-4), [3.8](#task-3-8) | [F02-auth.md](superpowers/plans/phase-3-auth-history/specs/F02-auth.md) |
| P3-F03 | [3.4](#task-3-4), [3.5](#task-3-5), [3.6](#task-3-6) | [F03-history.md](superpowers/plans/phase-3-auth-history/specs/F03-history.md) |
| P3-F04 | [3.9](#task-3-9) | [F04-smoke-ci.md](superpowers/plans/phase-3-auth-history/specs/F04-smoke-ci.md) |
| P3-F05 | [9.5](#task-9-5) | [F05-docs.md](superpowers/plans/phase-3-auth-history/specs/F05-docs.md) |
| P4-F01 | [4.1](#task-4-1), [4.7](#task-4-7) | [F01-calories-restrictions.md](superpowers/plans/phase-4-swap-feedback/specs/F01-calories-restrictions.md) |
| P4-F02 | [4.8](#task-4-8) | [F02-client-plan.md](superpowers/plans/phase-4-swap-feedback/specs/F02-client-plan.md) |
| P4-F03 | [4.2](#task-4-2) | [F03-meal-swap.md](superpowers/plans/phase-4-swap-feedback/specs/F03-meal-swap.md) |
| P4-F04 | [4.3](#task-4-3) | [F04-exercise-swap.md](superpowers/plans/phase-4-swap-feedback/specs/F04-exercise-swap.md) |
| P4-F05 | [4.4](#task-4-4) | [F05-feedback.md](superpowers/plans/phase-4-swap-feedback/specs/F05-feedback.md) |
| P4-F06 | [4.5](#task-4-5) | [F06-endpoints-e2e.md](superpowers/plans/phase-4-swap-feedback/specs/F06-endpoints-e2e.md) |
| P4-F07 | [9.5](#task-9-5) | [F07-docs.md](superpowers/plans/phase-4-swap-feedback/specs/F07-docs.md) |
| P5-F01 | [5.7](#task-5-7) | [F01-backend-cors-fixtures.md](superpowers/plans/phase-5-frontend-foundation/specs/F01-backend-cors-fixtures.md) |
| P5-F02 | [5.1](#task-5-1), [5.2](#task-5-2) | [F02-packages-platform.md](superpowers/plans/phase-5-frontend-foundation/specs/F02-packages-platform.md) |
| P5-F03 | [5.3](#task-5-3) | [F03-dart-models.md](superpowers/plans/phase-5-frontend-foundation/specs/F03-dart-models.md) |
| P5-F04 | [5.4](#task-5-4) | [F04-api-client.md](superpowers/plans/phase-5-frontend-foundation/specs/F04-api-client.md) |
| P5-F05 | [5.5](#task-5-5) | [F05-providers.md](superpowers/plans/phase-5-frontend-foundation/specs/F05-providers.md) |
| P5-F06 | [5.6](#task-5-6), [5.9](#task-5-9) | [F06-main-shell-ci.md](superpowers/plans/phase-5-frontend-foundation/specs/F06-main-shell-ci.md) |
| P5-F07 | [9.5](#task-9-5) | [F07-docs.md](superpowers/plans/phase-5-frontend-foundation/specs/F07-docs.md) |
| P6-F01 | [6.9](#task-6-9) | [F01-backend-profile-safety.md](superpowers/plans/phase-6-connect-mvp/specs/F01-backend-profile-safety.md) |
| P6-F02 | [6.10](#task-6-10) | [F02-backend-exercise-level.md](superpowers/plans/phase-6-connect-mvp/specs/F02-backend-exercise-level.md) |
| P6-F03 | [6.2](#task-6-2), [6.5](#task-6-5), [6.11](#task-6-11) | [F03-app-logic.md](superpowers/plans/phase-6-connect-mvp/specs/F03-app-logic.md) |
| P6-F04 | [6.1](#task-6-1), [6.2](#task-6-2), [6.3](#task-6-3), [6.4](#task-6-4), [6.5](#task-6-5), [6.6](#task-6-6), [6.7](#task-6-7), [7.1](#task-7-1), [7.2](#task-7-2) | [F04-app-screens.md](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md) |
| P6-F05 | [6.8](#task-6-8) | [F05-branding.md](superpowers/plans/phase-6-connect-mvp/specs/F05-branding.md) |
| P6-F06 | [9.5](#task-9-5) | [F06-docs.md](superpowers/plans/phase-6-connect-mvp/specs/F06-docs.md) |

## 6. Completed Work

Các hạng mục đã hoàn thành đầy đủ trong dự án:

- **Phase 0:** [0.1](#task-0-1) Tài liệu AI/auth/DB; [0.2](#task-0-2) Dart SDK wiki; [0.3](#task-0-3) Lưu trữ bền vững; [0.4](#task-0-4) HTTP status POST; [0.5](#task-0-5) `/health` config; [0.6](#task-0-6) Hướng dẫn Groq API credentials; [0.7](#task-0-7) README liên kết roadmap.
- **Phase 1:** [1.1](#task-1-1) BRD & quyết định D1–D4; [1.2](#task-1-2) Hợp đồng adjustment API; [1.3](#task-1-3) DTO, sample, pipeline và prompt Groq đồng bộ; [1.4](#task-1-4) Wiki privacy & safety.
- **Phase 2:** [2.1](#task-2-1) Ma trận BMR/TDEE; [2.2](#task-2-2) Plan validation tests; [2.3](#task-2-3) Generate retry/fallback tests; [2.4](#task-2-4) Generate HTTP E2E; [2.5](#task-2-5) Groq API với mock HTTP server.
- **Phase 3:** [3.1](#task-3-1) TypeORM MySQL & SQLite; [3.2](#task-3-2) Entities (`User` không có `google_sub`, `PlanRecord`, `FeedbackReceipt`); [3.3](#task-3-3) Register/Login/ChangePassword & JWT; [3.4](#task-3-4) JWT guards; [3.5](#task-3-5) History list/detail & ownership; [3.6](#task-3-6) Auth/history/DB tests; [3.8](#task-3-8) Xóa tài khoản `DELETE /api/v1/me`.
- **Phase 4:** [4.1](#task-4-1) Restriction matcher & fallback filtering; [4.2](#task-4-2) Backend meal swap; [4.3](#task-4-3) Backend exercise swap; [4.4](#task-4-4) Backend feedback; [4.5](#task-4-5) Adjustment HTTP/smoke tests; [4.7](#task-4-7) Calorie bounds & sample scaling; [4.8](#task-4-8) Adjustment lưu history; [4.9](#task-4-9) Tuning và đo Groq API live.
- **Phase 5:** [5.1](#task-5-1) Flutter packages; [5.2](#task-5-2) API URL & quyền mạng; [5.3](#task-5-3) Dart API models; [5.4](#task-5-4) ApiClient; [5.5](#task-5-5) Plan/Auth providers & persistence; [5.6](#task-5-6) Startup theo saved plan; [5.7](#task-5-7) CORS.
- **Phase 6:** [6.1](#task-6-1) Onboarding 3 bước; [6.2](#task-6-2) Profile edit; [6.3](#task-6-3) Loading tạo plan thật; [6.4](#task-6-4) Dashboard/Plan; [6.5](#task-6-5) Grocery checklist; [6.10](#task-6-10) Exercise level; [6.11](#task-6-11) Plan schedule & expiry.
- **Phase 7:** [7.1](#task-7-1) Meal swap UI; [7.2](#task-7-2) Exercise swap UI; [7.3](#task-7-3) Feedback end-of-day UI & Day 3 lifecycle.
- **Phase 8:** [8.1](#task-8-1) Đăng ký/Đăng nhập mật khẩu & Skip; [8.2](#task-8-2) JWT, Đổi mật khẩu, 401 nhắc đăng nhập lại & Xóa tài khoản; [8.3](#task-8-3) History UI (`HistoryScreen`, `HistoryDetailScreen`).

## 7. Remaining Work (Ngoài code cốt lõi / Tuỳ chọn triển khai)

- **PARTIAL:** [3.9](#task-3-9) (Smoke local pass, remote CI chưa chạy), [5.10](#task-5-10), [6.6](#task-6-6), [6.7](#task-6-7), [6.8](#task-6-8), [6.9](#task-6-9), [9.4](#task-9-4), [9.5](#task-9-5).
- **NOT STARTED:** [9.6](#task-9-6) (Slides & video demo nếu cần nộp).
- **UNVERIFIED (deploy public / GitHub Actions remote):** [2.6](#task-2-6), [5.9](#task-5-9), [9.1](#task-9-1), [9.2](#task-9-2), [9.3](#task-9-3).

## 8. Known Bugs & Technical Notes

- **Lỗi chức năng tồn đọng:** Không còn bug chức năng mở nào trên các luồng cốt lõi của ứng dụng.
- **Lưu ý đóng gói / deploy:** Nếu xuất bản public, cần cấu hình keystore release riêng thay vì debug signing, thiết lập `applicationId` chính thức và biến môi trường production (`JWT_SECRET`, `GROQ_API_KEY`, `DB_*`, `CORS_ORIGINS`).

## 9. Dependencies

Chuỗi luồng chính đã khép kín: contract/validation → backend/auth(MySQL)/adjustment(Groq) → model/client/provider → Onboarding/Generate/Dashboard/Plan → Grocery/Profile/Calendar/Swap → Feedback/Auth/History → Acceptance.

- [phase-1-api-contract/project.json](superpowers/plans/phase-1-api-contract/project.json)
- [phase-2-backend-tests/project.json](superpowers/plans/phase-2-backend-tests/project.json)
- [phase-3-auth-history/project.json](superpowers/plans/phase-3-auth-history/project.json)
- [phase-4-swap-feedback/project.json](superpowers/plans/phase-4-swap-feedback/project.json)
- [phase-5-frontend-foundation/project.json](superpowers/plans/phase-5-frontend-foundation/project.json)
- [phase-6-connect-mvp/project.json](superpowers/plans/phase-6-connect-mvp/project.json)

## 10. Tổng kết các Work Packages (N01–N10)

| ID | Trạng thái | Phạm vi hoàn thành |
|---|---|---|
| N01 | DONE | [6.1](#task-6-1), [6.3](#task-6-3): Onboarding → `PlanProvider.generate` → Loading thật → Lưu & mở Plan 3 ngày |
| N02 | DONE | [6.1](#task-6-1), [6.9](#task-6-9), [6.10](#task-6-10): Validation tuổi 18–100, BMI/pregnancy safety, D5 chip/tự nhập ≤ 300 ký tự |
| N03 | DONE | [6.4](#task-6-4), [6.5](#task-6-5), [7.1](#task-7-1), [7.2](#task-7-2): Dashboard, Plan chi tiết, Swap món/bài, Grocery đồng bộ response |
| N04 | DONE (automated) | [5.6](#task-5-6), [6.2](#task-6-2), [6.5](#task-6-5), [6.11](#task-6-11): Startup khôi phục plan, Profile draft/edit, Checklist & Lịch 3 ngày |
| N05 | DONE (automated) | [7.3](#task-7-3): Feedback cuối ngày D2, khóa gửi lặp theo ngày, cảnh báo nguy hiểm, chu kỳ mới ngày 3 |
| N06 | PARTIAL | [6.6](#task-6-6), [6.7](#task-6-7), [9.4](#task-9-4): Widget & HTTP tests PASS; còn test thiết bị Android nếu cần nghiệm thu tay |
| N07 | DONE | [8.1](#task-8-1), [8.2](#task-8-2), [8.3](#task-8-3): Đăng ký/Đăng nhập Email + Mật khẩu, Đổi mật khẩu, Xóa tài khoản trên MySQL & History UI |
| N08 | DONE | [1.3](#task-1-3), [4.9](#task-4-9), [6.10](#task-6-10): Đồng bộ prompt và kiểm chứng Groq API live (`source: groq`, 10.5s) |
| N09 | UNVERIFIED | [2.6](#task-2-6), [5.9](#task-5-9), [6.8](#task-6-8), [9.3](#task-9-3): CI GitHub Actions & build release chính thức |
| N10 | PARTIAL | [9.1](#task-9-1)–[9.6](#task-9-6): Deploy server công khai, ảnh minh họa README, slide & video demo |

<a id="groq-verification"></a>

### Kiểm chứng tích hợp Groq API & Hệ thống (10–12/11/2026)

- **LIVE GROQ API: PASS.** Đã cấu hình `PLAN_AI_PROVIDER=groq`, `GROQ_API_KEY` và `GROQ_MODEL=openai/gpt-oss-120b` trong `backend_api/.env` (gitignored).
- **Kết quả đo live (`scripts/test-groq-plan.mjs`, `scripts/test-groq-adjustments.mjs`):**
  * Tạo kế hoạch 3 ngày: `passed: true`, `source: groq`, `elapsedMs: 10511`, target 1624 kcal → `[1625, 1635, 1625]` kcal/ngày, đạt toàn bộ validator & giới hạn dị ứng/bài tập.
  * Đổi món (`meal_swap`): HTTP 200 (`1873ms`), `passed: true`.
  * Đổi bài (`exercise_swap`): HTTP 200 (`1190ms`), `passed: true`.
- **Pipeline/contract:** `POST /api/v1/generate-plan` → `PlanService` → `GroqPlanService` → `JSON.parse` → DTO/class-validator + kiểm ba ngày/bữa/calo/macro/trùng món + kiểm dị ứng/chấn thương/tải trọng → `assemblePlan` với IDs/grocery server tính. Thiếu key/lỗi/JSON/schema/safety không đạt → fallback `sample` theo BRD NFR-2 (`source: sample`).
- **Timeout/retry:** `GROQ_TIMEOUT_MS=60000` (mỗi call), `GROQ_TOTAL_TIMEOUT_MS=90000` (tổng), tối đa 2 attempts; client Flutter chờ tối đa 105s. Không retry trên 401/403/429/timeout.
- **Automated & DB evidence:** Backend 507/507 unit tests (39 files), 120/120 E2E tests (10 files), `typecheck`, `lint` (0 lỗi), `build` PASS; MySQL `smartfit_db` live schema verify PASS; Frontend `flutter analyze` sạch và 195/195 Flutter tests PASS (3 opt-in live tests skipped).

## 11. MVP Acceptance Criteria

| Tiêu chí | Task | Evidence hiện tại | Kết luận |
|---|---|---|---|
| BRD & hợp đồng API/JSON | 1.1, 1.2 | BRD v2.6.0 & DTO khớp | Đạt |
| Backend local, Swagger, BMR/TDEE, fallback & MySQL | 2.1–2.5, 3.1–3.6, 4.1, 4.7 | 507 unit + 120 E2E PASS; MySQL `smartfit_db` live PASS | Đạt |
| Groq API live & đồng bộ prompt | 1.3, 4.9, 6.10 | `test-groq-plan.mjs` PASS (`source: groq`, 10.5s) & swap HTTP 200 | Đạt |
| Form Onboarding 3 bước & safety | 6.1, 6.9 | N02 form/safety validation tests PASS | Đạt |
| Dashboard, Plan 3 ngày, Grocery & Lịch | 5.6, 6.2–6.5, 6.11 | Widget & provider persistence tests PASS | Đạt |
| Đổi món, Đổi bài & Feedback cuối ngày | 7.1–7.3 | UI/API/MySQL/SQLite/HTTP tests PASS | Đạt |
| Tài khoản Email+Mật khẩu, Đổi mật khẩu, History & Xóa | 8.1–8.3 | Backend MySQL + Flutter (`PasswordAuthSheet`, `ChangePasswordSheet`, `HistoryScreen`) + tests PASS | Đạt |
| Demo công khai / Slides / Video (nếu nộp) | 9.1–9.6 | Chạy ổn định localhost; còn phần deploy public & tài liệu nộp | Tuỳ chọn ngoài code |

## 12. Release Readiness Checklist (Dành cho bước đóng gói / deploy public)

- [x] Hoàn thiện toàn bộ luồng app Client ↔ Backend ↔ MySQL ↔ Groq API trên môi trường phát triển, loại bỏ Google Sign-In và Gemini.
- [x] `typecheck`, `lint`, `build`, 507 unit tests, 120 E2E tests (backend) và `flutter analyze`, 195 Flutter tests PASS.
- [ ] Đóng gói release signing & chạy test trên thiết bị Android thật (nếu xuất bản APK).
- [ ] Triển khai server production (`DB_TYPE=mysql`, `JWT_SECRET`, `GROQ_API_KEY`, `CORS_ORIGINS`, HTTPS) nếu publish online.
- [ ] Chuẩn bị ảnh chụp màn hình README, slide & video demo (nếu nộp báo cáo).
