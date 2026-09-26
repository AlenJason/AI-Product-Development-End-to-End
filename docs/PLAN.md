# Kế hoạch triển khai SmartFit AI

Plan này chia [BRD.md](../BRD.md) (v2.5.1) thành các bước làm được theo thứ tự. BRD vẫn là nguồn yêu cầu; plan chỉ trả lời "làm gì trước, làm gì sau, xong khi nào".

**Thứ tự tổng thể:** hoàn thiện backend trước (kiểm thử toàn bộ qua Swagger), sau đó mới làm frontend bám theo hợp đồng API đã chốt.

**Một bước được coi là xong khi:** build và test đều pass, kiểm tra được trên Swagger (backend) hoặc trên app (frontend), và đã commit.

Kích thước ước lượng tương đối: **S** (nhỏ) · **M** (vừa) · **L** (lớn).

**Cách làm từng giai đoạn:**

- **Giai đoạn 0** (dọn dẹp): làm trực tiếp.
- **Giai đoạn 1–8:** trước khi code, chạy `/feature-explore` (đầu vào: BRD + mục giai đoạn đó trong plan này) rồi `/feature-plan`. Kết quả lưu ở `docs/superpowers/brainstorms/` và `docs/superpowers/plans/<slug>/`, gồm spec từng feature, tiêu chí hoàn thành và checklist test, với các ràng buộc trong wiki được nạp tự động. Sau đó code theo spec.
- `/feature-build` bản hiện tại được viết cho dự án Next.js nên không nhận ra NestJS/Flutter. Nếu muốn dùng, cần tạo bản riêng cho repo này trong `.claude/skills/`.

---

## Chạy giả lập trước, gắn khoá thật sau

Cả hai dịch vụ bên ngoài đều có chế độ giả lập, nên toàn bộ dự án chạy và demo được khi chưa có khoá nào. Cách gắn khoá thật viết trong [SETUP_CREDENTIALS.md](SETUP_CREDENTIALS.md) (phần Gemini viết ở giai đoạn 0, phần Google Sign-In ở giai đoạn 3 và 8).

| Dịch vụ | Chế độ giả lập (mặc định) | Bật chế độ thật |
|---|---|---|
| Gemini API | Không có `GEMINI_API_KEY` → trả dữ liệu mẫu soạn sẵn (plan 3 ngày, kho món/bài tập để đổi) | Điền `GEMINI_API_KEY` vào `.env` |
| Google Sign-In | `AUTH_MODE=mock` → backend chấp nhận token dạng `mock:<email>`, bỏ qua bước xác minh với Google. Phần còn lại (tạo user trong DB, phát JWT, lưu lịch sử) chạy thật. Bị chặn khi `NODE_ENV=production`, trừ khi `ALLOW_MOCK_AUTH=true` | `AUTH_MODE=google` + `GOOGLE_CLIENT_ID` + `JWT_SECRET` |

---

## Hiện trạng (đã xong)

- [x] BRD v2.5.1 (MVP, tính năng nâng cao, tài khoản & lịch sử, hợp đồng API đầy đủ)
- [x] Backend: `GET /health`, `POST /api/v1/generate-plan` (tính BMR/TDEE, gọi Gemini, kiểm tra khoảng calo, fallback), đổi món, đổi bài tập, feedback, đăng nhập Google (giả lập mặc định), lịch sử kế hoạch (SQLite), validate DTO, Swagger UI, CORS cho bản web
- [x] `ai_workspace/`: script thử prompt Gemini
- [x] Frontend: giao diện Onboarding, Loading, Dashboard, Grocery, bảng Feedback (dữ liệu mẫu); tầng kết nối API — model theo hợp đồng, `ApiClient`, provider, lưu trên máy (giai đoạn 5). Màn hình **chưa nối API** (giai đoạn 6)
- [x] Wiki nội bộ `docs/knowledge/`, `CLAUDE.md`

---

## Quyết định đã chốt (2026-09-24)

Giao diện Flutter (thiết kế từ Figma) và backend/BRD từng lệch nhau ở 4 điểm dưới. Các quyết định này được áp dụng ở giai đoạn 1.

**D1 — Mức điều chỉnh calo theo mục tiêu:** theo giao diện. Giảm mỡ −300 kcal/ngày, tăng cơ +250 kcal/ngày (backend đang để −500 / +300, sẽ sửa).

**D2 — Feedback cuối ngày:** gồm 3 câu hỏi.

| Câu hỏi | Lựa chọn | Tác động lên ngày kế tiếp |
|---|---|---|
| Cường độ buổi tập hôm nay (chọn 1) | Nhẹ nhàng / Vừa sức / Rất mệt | Tăng nhẹ / Giữ nguyên / Giảm khối lượng tập |
| Tình trạng cơ thể khi hoặc sau khi tập (chọn nhiều) | Bình thường · Căng mỏi cơ · Đau khớp (gối, cổ tay, vai…) · Uể oải, thiếu ngủ · ⚠️ Chóng mặt, khó thở bất thường, đau ngực | Căng mỏi cơ → giảm hiệp nhóm cơ đó, thêm giãn cơ. Đau khớp → bỏ động tác bật nhảy, chống quỳ. Uể oải → rút ngắn buổi tập. **⚠️ Dấu hiệu nguy hiểm → không tự điều chỉnh plan; hiện khuyến cáo ngừng tập và hỏi ý kiến bác sĩ; ngày kế tiếp chỉ nghỉ hoặc đi bộ nhẹ** |
| Ăn uống (chọn 1) | Đúng thực đơn / Ăn nhiều hơn / Ăn ít hơn hoặc bỏ bữa | Cân đối lại món ăn ngày kế tiếp (không hạ calo dưới BMR) |

**D3 — Nguyên liệu đi chợ:** API trả `name` và `quantity` riêng (ví dụ `{ "name": "Ức gà", "quantity": "450g" }`), nhóm nguyên liệu là danh sách cố định 3 nhóm để giao diện gắn icon.

**D4 — Hạn chế và sức khoẻ ở Onboarding:** người dùng tự nhập, sửa được về sau.

- 3 ô nhập tự do: *Dị ứng / thực phẩm cần tránh*, *Chấn thương / vùng cơ thể cần tránh*, *Tình trạng sức khoẻ / bệnh nền* (mới — ví dụ tiểu đường, cao huyết áp, gout).
- Có chip gợi ý bấm nhanh (hải sản, trứng, sữa, đậu phộng, đau gối, đau lưng…); bấm vào chỉ điền sẵn chữ vào ô, không thay cho ô nhập.
- Sửa bất cứ lúc nào ở tab "Cá nhân" (hiện đang là placeholder).
- **Lưu trên máy, không lưu ở server.** Thông tin sức khoẻ gửi kèm từng request rồi bỏ đi; backend không ghi vào DB, không ghi log. Đây là dữ liệu cá nhân nhạy cảm theo Nghị định 13/2023/NĐ-CP.
- **Có Gemini:** văn bản tự do đưa vào prompt, đặt trong khối dữ liệu tách biệt, giới hạn 300 ký tự mỗi ô để hạn chế prompt injection.
- **Chế độ giả lập:** code khớp từ khoá phổ biến (tôm, cua, sữa, gối…). Nếu có nội dung không nhận ra, app cảnh báo rằng chưa kiểm tra được toàn bộ hạn chế.
- App ghi rõ: gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế; người có bệnh nền nên hỏi ý kiến bác sĩ.

---

## Giai đoạn 0 — Dọn dẹp & chuẩn bị · S

- [x] **0.1** Sửa `CLAUDE.md`: `gemini.service.ts` đã dùng `@google/genai` (đang ghi SDK cũ); thêm quyết định auth/DB; trỏ tới plan này
- [x] **0.2** Sửa lỗi trong wiki `reference-materials.md`: ràng buộc `sdk: ^3.13.1` trong `pubspec.yaml` **đã thoả** yêu cầu Dart 3.9+ của `shared_preferences`, không cần nâng như đã ghi
- [x] **0.3** Sửa BRD mục 7.6: Render bản free không giữ file SQLite (mất dữ liệu khi service ngủ/restart); thay bằng nơi có ổ lưu trữ bền, hoặc Postgres
- [x] **0.4** Các endpoint POST trả HTTP 200 như sơ đồ BRD (NestJS mặc định trả 201)
- [x] **0.5** `GET /health` báo trạng thái cấu hình `{ status, gemini: "configured" | "fallback" }` để kiểm tra nhanh khoá đã gắn đúng chưa (trường `auth_mode` thêm ở bước 3.3, khi đã có auth)
- [x] **0.6** Tạo `docs/SETUP_CREDENTIALS.md` — phần **Gemini API key**: lấy key ở đâu, điền vào file nào, kiểm tra thế nào
- [x] **0.7** README trỏ tới plan này và file hướng dẫn

## Giai đoạn 1 — Chốt hợp đồng API · M

- [x] **1.1** Áp dụng D1–D4 vào BRD, nâng lên v2.3.0 (thay đổi phạm vi thật: thêm ô bệnh nền, sửa hồ sơ, feedback mới):
  - FR-1.3: mức điều chỉnh calo −300 / +250 (D1)
  - FR-1.4: 3 ô nhập tự do + chip gợi ý (D4); thêm FR-1.6: sửa hồ sơ ở tab "Cá nhân"
  - FR-5.1, FR-5.2: feedback 3 câu hỏi và quy tắc xử lý dấu hiệu nguy hiểm (D2)
  - Mục 6.1: `restrictions` đổi thành 3 chuỗi `allergies`, `injuries`, `health_conditions` (tối đa 300 ký tự mỗi chuỗi)
  - Mục 6.2: nguyên liệu tách `name` / `quantity`, 3 nhóm cố định (D3)
  - Mục 7: thêm NFR quyền riêng tư dữ liệu sức khoẻ (không lưu/ghi log ở server), chống prompt injection, khuyến cáo "không thay thế tư vấn y tế"
- [x] **1.2** Thêm BRD mục 6.4: schema request/response cho đổi món, đổi bài tập, feedback (hiện mới chỉ bàn trong chat, chưa có trong BRD)
- [x] **1.3** Cập nhật backend cho khớp: DTO, interface, hằng số `GOAL_CALORIE_ADJUSTMENT`, prompt Gemini (đưa văn bản tự do vào khối dữ liệu tách biệt). Soạn lại `sample-plan.json` theo schema mới và **đủ 3 ngày** (hiện chỉ có Ngày 1, demo ở chế độ giả lập sẽ thiếu 2 ngày)
- [x] **1.4** Thêm vào wiki `critical-constraints.md`: không lưu dữ liệu sức khoẻ ở server; dấu hiệu nguy hiểm → khuyến cáo, không tự điều chỉnh plan; không hạ calo dưới BMR

→ Sau giai đoạn này, BRD mục 6 là hợp đồng đầy đủ cho mọi endpoint; frontend chỉ cần bám theo.

Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-1-api-contract.md` (hướng B, quyết định Q1–Q4), plan `docs/superpowers/plans/phase-1-api-contract/`.

## Giai đoạn 2 — Backend: kiểm thử nền · M

- [x] **2.1** Unit test `computeDailyTarget()` (`daily-target.ts`): mở rộng từ 3 ca đã có ở giai đoạn 1 ra đủ nam/nữ × 3 mức vận động × 3 mục tiêu (tiêu chí nghiệm thu tuần 5)
- [x] **2.2** ~~Unit test `isNutritionWithinBounds()`~~ — hàm này đã được thay bằng `findPlanViolations()` và có test ở giai đoạn 1 (`plan-validation.spec.ts`)
- [x] **2.3** Unit test `PlanService.generatePlan()` với Gemini giả: kết quả hợp lệ → `source: gemini`; sai hợp đồng → gọi lại → thực đơn mẫu; hết giờ → không gọi lại; khoá sai → thực đơn mẫu (trường hợp không có khoá đã có test ở giai đoạn 1)
- [x] **2.4** E2E `POST /api/v1/generate-plan`: payload đúng → 200, payload sai → 400, `restrictions` kiểu mảng cũ → 400 (test e2e cần bật `ValidationPipe` giống `main.ts`)
- [x] **2.5** *(bổ sung, quyết định Q1)* Test `GeminiService` với SDK `@google/genai` thật trỏ vào server Gemini giả cục bộ (`GEMINI_BASE_URL`): hết giờ, khoá sai, không tự gọi lại, lỗi JSON không lộ nội dung
- [x] **2.6** *(bổ sung, quyết định Q2)* GitHub Actions: build + unit + e2e backend trên Node 24 và 26, kiểm kiểu `ai_workspace`, mỗi lần push

Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-2-backend-tests.md`, plan `docs/superpowers/plans/phase-2-backend-tests/`.

## Giai đoạn 3 — Backend: Tài khoản & Lịch sử (FR-6, FR-7) · L

- [x] **3.1** Thêm TypeORM + SQLite: `better-sqlite3@12` (TypeORM 1.1 không còn driver `sqlite3`, chỉ nhận `better-sqlite3 ^12`; install script được duyệt tường minh trong `package.json`). Entity chỉ dùng kiểu cột có ở cả SQLite và Postgres
- [x] **3.2** Entity `User` (google_sub, email, name) và `PlanRecord` (user, plan_json, target_calories, created_at); bảng tạo bằng migration chạy khi khởi động, không `synchronize`; file DB nằm trong `.gitignore`
- [x] **3.3** `AuthModule`: `POST /api/v1/auth/google`, hai chế độ `AUTH_MODE=mock | google`, JWT hết hạn sau 7 ngày. Chế độ google bắt buộc có `GOOGLE_CLIENT_ID` và `JWT_SECRET` ≥ 32 ký tự (thiếu thì không cho khởi động); chế độ mock được dùng secret mặc định kèm cảnh báo, và bị chặn khi `NODE_ENV=production` trừ khi `ALLOW_MOCK_AUTH=true`. `/health` báo thêm `auth_mode`
- [x] **3.4** Guard: bắt buộc đăng nhập cho API lịch sử; tuỳ chọn cho `generate-plan` (token hợp lệ → lưu lịch sử; token sai → 401; không có token → chạy như cũ, không lưu)
- [x] **3.5** `GET /api/v1/plans/history` (50 plan mới nhất) và `GET /api/v1/plans/history/:id` (plan của người khác → 404)
- [x] **3.6** Test: auth hai chế độ (Google test bằng khoá RSA tự tạo, không gọi mạng), guard, quyền sở hữu plan, migration khớp entity, E2E: đăng nhập giả lập → tạo plan → xem lịch sử
- [x] **3.7** `SETUP_CREDENTIALS.md` — phần **Google Sign-In (backend)**: tạo OAuth Client ID trên Google Cloud Console, điền `.env`, kiểm tra qua `/health`
- [x] **3.8** *(bổ sung, quyết định Q4)* `DELETE /api/v1/me`: xoá tài khoản cùng toàn bộ lịch sử (BRD FR-6.4, v2.4.0)
- [x] **3.9** *(bổ sung khi lập plan)* Smoke test chạy bản build (`npm run test:smoke`) trong CI — bắt lỗi import vòng giữa entity mà vitest không thấy

Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-3-auth-history.md` (quyết định Q1–Q4 ở mục 8), plan `docs/superpowers/plans/phase-3-auth-history/`.

## Giai đoạn 4 — Backend: Đổi món, đổi bài tập, feedback (FR-4, FR-5) · L

- [x] **4.1** Bộ khớp từ khoá cho chế độ giả lập (`data/restriction-keywords.json`, `restriction-matcher.ts`): nhận ra dị ứng/chấn thương phổ biến, gõ có dấu hay không dấu; phần không nhận ra → cảnh báo chung, không nhắc lại chữ người dùng (D4). Lọc luôn thực đơn mẫu của `generate-plan` và kiểm lại mọi kết quả Gemini
- [x] **4.2** `POST /api/v1/meals/swap`: Gemini sinh món thay thế lệch không quá ±10% calo, tránh các hạn chế người dùng nhập, không trùng món đã có trong plan; backend tính lại toàn bộ `grocery_list` (#7). Fallback: kho món Việt `data/swap-meals.json` lọc bằng bộ khớp từ khoá, nhân khẩu phần về đúng calo món cũ; hết món phù hợp → 422
- [x] **4.3** `POST /api/v1/exercises/swap` *(quyết định Q2: Gemini trước)*: động tác nhẹ hơn, cùng nhóm cơ, tránh chấn thương — kết quả Gemini phải qua điều kiện đo được (số hiệp không tăng, không thêm kiểu tải). Fallback: `data/swap-exercises.json` có mức khó 1–3; đã nhẹ nhất → 422
- [x] **4.4** `POST /api/v1/feedback` theo D2: bài tập điều chỉnh bằng quy tắc cố định; món ăn nhờ Gemini *(quyết định Q3)* — ăn nhiều → ngày kế tiếp ~90% mục tiêu, ăn ít → giữ mục tiêu, không có key thì giữ nguyên món kèm cảnh báo. Dấu hiệu nguy hiểm → `safety_warning` và ngày kế tiếp chỉ nghỉ hoặc đi bộ nhẹ. **Không bao giờ hạ calo mục tiêu xuống dưới BMR.** Ngày 3 → plan mới
- [x] **4.5** Test cả 4 phần trên, chạy được khi không có key; dấu hiệu nguy hiểm có test riêng. E2E qua HTTP thật, một đường qua SDK Gemini thật + server giả; smoke test gọi 3 endpoint trên bản build
- [ ] **4.6** *(Tuỳ chọn, để sau)* Dùng `responseSchema` của Gemini để ép JSON đúng cấu trúc ngay từ API — cần khoá thật để đo nó giảm lỗi bao nhiêu (thử bằng `ai_workspace/`); bước kiểm hợp đồng vẫn phải giữ
- [x] **4.7** *(bổ sung, quyết định Q1)* Khoảng calo theo tỉ lệ mục tiêu, kiểm tổng calo ngày (≥ BMR), nhân khẩu phần thực đơn mẫu cho khớp mục tiêu — sửa lỗi thực đơn thấp hơn BMR của nhiều người (BRD NFR-4, v2.5.0)
- [x] **4.8** *(bổ sung, quyết định Q4)* Đã đăng nhập: đổi món, đổi bài, feedback cập nhật plan đã lưu; plan từ feedback ngày 3 lưu mới
- [x] **4.9** *(bổ sung sau khi thử bằng khoá thật)* Đo Gemini thật (`npm run measure:gemini`): để model tự suy nghĩ thì tạo plan mất 37–42 s, vượt giới hạn 15 s nên luôn rơi về thực đơn mẫu. Sửa: prompt ghi rõ danh sách nguyên liệu/động tác backend sẽ loại; `GEMINI_THINKING` (mặc định `off`, 8–13 s); giới hạn 20 s mỗi lần, 40 s tổng; model mặc định `gemini-3.5-flash` (3.8 liên tục quá tải). Gói miễn phí: 20 lần gọi/ngày mỗi model (BRD v2.5.1)

Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-4-swap-feedback.md` (quyết định Q1–Q4 ở mục 8), plan `docs/superpowers/plans/phase-4-swap-feedback/`.

→ **Mốc: backend hoàn chỉnh.** Mọi endpoint kiểm thử được trên Swagger ở chế độ giả lập.

## Giai đoạn 5 — Frontend: nền tảng · M

- [x] **5.1** Thêm package `http`, `provider`, `shared_preferences`
- [x] **5.2** Địa chỉ backend qua `--dart-define=API_BASE_URL` — web: `localhost`; máy ảo Android: `10.0.2.2`; điện thoại thật: IP mạng LAN của máy chạy backend (`lib/config/api_config.dart`). Quyền mạng Android (release), iOS, macOS
- [x] **5.3** Model Dart có `fromJson`/`toJson` theo BRD mục 6 (`lib/models/api/`), đi vòng tròn đúng JSON server trả. Màn hình chuyển sang model mới và xoá view-model cũ `meal_plan.dart` ở 6.7
- [x] **5.4** `ApiClient` (`lib/services/`): gọi mọi endpoint; lỗi → `ApiException` có câu tiếng Việt, không crash (NFR-2); timeout 60 s cho request có Gemini
- [x] **5.5** `PlanProvider` (plan + hồ sơ, lưu `shared_preferences`) và `AuthProvider` (JWT; 401 → đăng xuất)
- [x] **5.6** `MainShell`: chưa có plan → mở Onboarding, đã có → Dashboard; viết lại `widget_test.dart`
- [x] **5.7** Bật CORS trong `configureApp()` qua `CORS_ORIGINS` (trống khi phát triển → `localhost`/`127.0.0.1` mọi cổng; trống khi deploy → tắt), cho phép header `Authorization`
- [x] **5.8** *(bổ sung, quyết định Q1)* Fixture hợp đồng: backend xuất 14 JSON thật vào `frontend_app/test/fixtures/` (`npm run fixtures:update`), test hai phía cùng dùng
- [x] **5.9** *(bổ sung, quyết định Q4)* CI Flutter: `flutter analyze` + `flutter test` (`.github/workflows/frontend.yml`)

Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-5-frontend-foundation.md` (quyết định Q1–Q4 ở mục 8), plan `docs/superpowers/plans/phase-5-frontend-foundation/`.

## Giai đoạn 6 — Frontend: nối MVP (FR-1 → FR-3) · M

- [ ] **6.1** Onboarding: thêm tuổi, giới tính, mức vận động (FR-1.1, FR-1.2 — backend bắt buộc nhưng giao diện chưa có); 3 ô nhập tự do + chip gợi ý + dòng khuyến cáo y tế (D4); validate cùng giới hạn với backend
- [ ] **6.2** Tab "Cá nhân": xem và sửa hồ sơ, lưu trên máy (FR-1.6); sửa xong thì gợi ý tạo lại plan
- [ ] **6.3** Loading: gọi API thật thay cho bộ đếm giờ giả; lỗi → nút thử lại (NFR-1, NFR-2). Có Gemini thì chờ thật khoảng 10–15 giây, tối đa khoảng 40 giây — câu chờ và thanh tiến trình phải hợp với khoảng này; HTTP client của app để timeout dài hơn 40 giây
- [ ] **6.4** Dashboard: hiển thị đủ 3 ngày, 3 bữa/ngày, bài tập, calo và macro (FR-2.3); hiện cảnh báo khi chế độ giả lập chưa kiểm tra được hết hạn chế
- [ ] **6.5** Grocery: dựng từ `grocery_list`; trạng thái tích chọn lưu cục bộ (FR-3.2)
- [ ] **6.6** Widget test dùng backend giả `test/fake_backend.dart` (có từ giai đoạn 5)
- [ ] **6.7** Màn hình đọc/ghi qua `PlanProvider`/`AuthProvider` và model `lib/models/api/`; xoá view-model cũ `lib/models/meal_plan.dart`. Chạy thử trên máy ảo Android (giai đoạn 5 mới build APK và kiểm manifest, chưa chạy app)

## Giai đoạn 7 — Frontend: tính năng nâng cao (FR-4, FR-5) · M

- [ ] **7.1** Nút "Đổi món" gọi API (hiện đang xoay vòng trong danh sách món viết cứng); thay cả plan và checklist bằng plan server trả về. 409 → báo hồ sơ đã đổi, gợi ý tạo plan mới; 422 → báo không còn món thay thế phù hợp
- [ ] **7.2** Nút "Đổi bài" gọi API
- [ ] **7.3** Làm lại bảng feedback theo D2 (3 câu hỏi, câu tình trạng cơ thể chọn nhiều); gọi API, cập nhật ngày kế tiếp; nhận `safety_warning` → hiện khuyến cáo ngừng tập, hỏi ý kiến bác sĩ. **Khoá nút sau khi đã gửi feedback cho một ngày** — backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa

## Giai đoạn 8 — Frontend: Tài khoản & Lịch sử (FR-6, FR-7) · M

- [ ] **8.1** Màn đăng nhập, chọn chế độ bằng `--dart-define=AUTH_MODE`: giả lập → nút "Đăng nhập demo"; thật → package `google_sign_in`. Có nút bỏ qua đăng nhập (đăng nhập là tuỳ chọn theo FR-7)
- [ ] **8.2** Gắn JWT vào request; nhận 401 → yêu cầu đăng nhập lại
- [ ] **8.3** Đổi tab "Thống kê" thành "Lịch sử": danh sách plan cũ, bấm vào xem chi tiết
- [ ] **8.4** `SETUP_CREDENTIALS.md` — phần **Google Sign-In (Flutter)**: Client ID, thẻ meta cho bản web, SHA-1 cho Android

## Giai đoạn 9 — Deploy, nghiệm thu, nộp bài · M

- [ ] **9.1** Chọn nơi deploy: (a) giữ SQLite, dùng host có ổ lưu trữ bền (Railway volume, Fly.io volume, VPS), hoặc (b) chuyển sang Postgres. **Không** dùng Render bản free với SQLite
- [ ] **9.2** Deploy backend, cấu hình biến môi trường trên host: `NODE_ENV=production`, `AUTH_MODE=google`, `GOOGLE_CLIENT_ID`, `JWT_SECRET`, `DATABASE_PATH` trỏ vào ổ lưu trữ bền, `GEMINI_API_KEY`, `CORS_ORIGINS` (địa chỉ bản web, nếu deploy bản web)
- [ ] **9.3** Build app để demo: bản web và/hoặc APK Android, với `--dart-define=API_BASE_URL=https://<địa chỉ backend>`
- [ ] **9.4** Chạy checklist kiểm thử toàn luồng ở cả hai chế độ (giả lập / khoá thật)
- [ ] **9.5** Cập nhật README (cách chạy, ảnh chụp màn hình), Changelog, BRD mục 9, wiki
- [ ] **9.6** Slide báo cáo và video demo

---

## Tiêu chí nghiệm thu (BRD mục 9) → giai đoạn đáp ứng

| Tiêu chí | Giai đoạn |
|---|---|
| Tài liệu đặc tả (BRD) | Đã xong; cập nhật ở 0, 1 |
| Module AI Engine (`ai_workspace/`) | Đã xong phần khung; tinh chỉnh prompt ở 4 |
| Module Backend: chạy local, Swagger, BMR/TDEE đúng | Đã chạy; chứng minh BMR/TDEE bằng test ở 2 |
| Module Frontend: nhập thông số, loading, hiển thị 3 ngày | 5, 6 |
| Tính năng Checklist | 6.5 |
| Tài khoản & Lịch sử | 3, 8 |
| Demo thông suốt Client → Server → AI → Client | 9 |
