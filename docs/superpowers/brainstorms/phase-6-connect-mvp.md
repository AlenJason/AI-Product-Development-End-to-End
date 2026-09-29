# Brainstorm: Giai đoạn 6 — Frontend: nối MVP (FR-1 → FR-3)
**Source:** `docs/PLAN.md` (giai đoạn 6, bước 6.1–6.11; quyết định D5, D6) + `BRD.md` v2.5.1 (FR-1, FR-2, FR-3, mục 6.1–6.2, NFR-1, NFR-2, NFR-4, NFR-7, NFR-9)
**Date:** 2026-09-26

## 1. Phạm vi

| Bước | Nội dung |
|---|---|
| 6.1 | Onboarding 3 bước (D6-B2): tuổi ≥ 18, giới tính, chiều cao, cân nặng, mức vận động, mục tiêu; hạn chế theo D5; khoá "Giảm mỡ" khi thiếu cân hoặc mang thai / cho con bú (D6-A1, A3) |
| 6.2 | Tab "Cá nhân": xem, sửa hồ sơ; sửa xong gợi ý tạo lại plan (FR-1.6) |
| 6.3 | Màn chờ gọi API thật; lỗi → thử lại (NFR-1, NFR-2) |
| 6.4 | Dashboard: 3 ngày, 3 bữa, bài tập, calo + macro mỗi ngày, `warnings` (FR-2.3, NFR-9) |
| 6.5 | Đi chợ dựng từ `grocery_list`; đánh dấu đã mua / xoá món có sẵn, lưu trên máy (FR-3) |
| 6.6, 6.7 | Widget test với `FakeBackend`; màn hình dùng provider và model `lib/models/api/`, xoá view-model cũ |
| 6.8 | Tên app, icon, màn khởi động, thanh trạng thái |
| 6.9 | Backend: tuổi ≥ 18; thiếu cân hoặc mang thai / cho con bú mà chọn `cut` → 400 (D6-A1, A2, A3); BRD v2.6.0 |
| 6.10 | Backend: mức động tác theo tuổi và `activity_level` (D6-A4) |
| 6.11 | App biết hôm nay là ngày mấy của plan (D6-B1) |

Giai đoạn này **không** làm: bảng feedback mới (7.3), đăng nhập và lịch sử trong app (8.x), các mục "để sau" của D6.

## 2. Ngữ cảnh đã nạp

- **Wiki:**
  - `INDEX.md`, `wiki-triggers.md`. Từ khoá khớp: onboarding, dashboard, Flutter → `flutter-ui.md`; calo, BMR, macro → `plan-data-contract.md`; dị ứng, chấn thương, kho động tác → `swap-and-feedback.md`; prompt → `gemini-integration.md`.
  - `critical-constraints.md` (#1–#29). **Điều kiện nạp ràng buộc: có** — đổi phần kiểm hợp lệ của endpoint (6.9), luật dinh dưỡng và prompt Gemini (6.10), dữ liệu sức khoẻ (D5, A3).
  - `flutter-ui.md`: màn hình vẫn dùng view-model cũ; `PlanProvider` lưu `smartfit.profile.v1` + `smartfit.plan.v1`; `ApiException.message` là câu tiếng Việt hiện thẳng cho người dùng.
  - `swap-and-feedback.md`: `readClientPlan()` tính lại mục tiêu từ `profile`, khác `daily_target` → 409; kho 39 động tác có `level` 1–3; bộ khớp tách chữ theo dấu phẩy, chấm phẩy, "và", "hoặc".
- **Ràng buộc áp dụng trực tiếp:**
  - #2, #13: mọi hồ sơ qua cùng một bộ kiểm, calo không dưới BMR — luật mới A1/A3 thêm vào cùng chỗ.
  - #12, #28: tình trạng mang thai là dữ liệu sức khoẻ — không lưu DB, không log; app không in ra log.
  - #15, #17: đổi prompt Gemini → đo lại bằng `npm run measure:gemini` (chạy tay, tốn hạn mức); test không gọi Gemini thật.
  - #23: mục nào người dùng tích phải được bộ khớp nhận ra.
  - #24: mọi endpoint nhận `profile` qua `CreatePlanDto` → luật mới áp cả đổi món, đổi bài, feedback.
  - #25: mỗi nhóm cơ có động tác mức 1 (`swap-pools.spec.ts`) — điều kiện để A4 luôn tìm được động tác thay.
  - #26: đổi hợp đồng → `npm run fixtures:update` + sửa model Dart trong cùng commit.
  - #7: danh sách đi chợ do server tính; app chỉ lưu trạng thái hiển thị (đã mua / đã có).

## 3. Phát hiện — kiểm chứng ngày 2026-09-26

| # | Phát hiện | Cách kiểm |
|---|---|---|
| F1 | **Onboarding không mang dữ liệu nào đi:** `onNext` là `VoidCallback`; chiều cao/cân nặng điền sẵn `168`/`62`; chỉ có 2 ô tích cứng; thiếu tuổi, giới tính, mức vận động (backend bắt buộc) | `onboarding_screen.dart` dòng 4, 14–17, 232; chạy trên máy ảo |
| F2 | **Màn chờ là đồng hồ giả:** `Timer.periodic(900ms)` qua 4 câu có số liệu bịa ("140g Carbs, 65g Protein, 32g Fat", "phù hợp ngân sách"); nút "Xem trước kế hoạch ngay" | `loading_screen.dart` dòng 18–21, 31, 104 |
| F3 | **Dashboard toàn dữ liệu viết cứng:** chỉ có bữa trưa/tối; ngày "Thứ Ba, 15/9/2026"; bộ chọn S1–S5 (5 ngày) không đổi nội dung; nhãn "Dễ", "Không tạ", chữ "T"; đổi món/đổi bài xoay vòng danh sách viết sẵn; `MacroRing` có sẵn nhưng không màn nào dùng | `dashboard_screen.dart` dòng 23–60, 120–155, 203, 256, 269, 490–492; `grep MacroRing` |
| F4 | **Đi chợ:** tên nhóm khác BRD FR-3.1; thiếu "xoá món đã có sẵn" (FR-3.2); có nút "Thêm nguyên liệu" ngoài BRD; dấu tích mất khi mở lại app | `grocery_screen.dart` dòng 94–102, 481–507; chạy trên máy ảo |
| F5 | Tab "Thống kê" và "Cá nhân" là trang giữ chỗ có số liệu viết cứng ("1.850 kcal", "168 cm • 62 kg • Giảm mỡ") | `main.dart` `_buildPlaceholderScreen` |
| F6 | **Backend chấp nhận hồ sơ rủi ro:** BMI 16,4 + `cut` → 1.159 kcal, chỉ có cảnh báo sàn BMR; 14 tuổi + `cut` → không cảnh báo; tuổi hợp lệ từ 10 | Gọi `generate-plan` bản build, chế độ giả lập; `create-plan.dto.ts` `@Min(10)` |
| F7 | **Mọi hồ sơ nhận cùng buổi tập** ở chế độ giả lập (người 65 tuổi ít vận động cũng có Jumping Jacks). Thực đơn mẫu chỉ có động tác mức 1–2; kho 39 động tác (mức 1: 15, mức 2: 15, mức 3: 9), nhóm cơ nào cũng có mức 1; `exerciseCandidates(group, { maxLevel })` đã có, đang dùng để lọc chấn thương | Đọc `sample-plan.json`, `swap-exercises.json`, `restriction-filter.ts` |
| F8 | Bộ khớp tách chữ theo `, ; . / + &` và "và/hoặc/với" → app ghép mục đã tích bằng ", " là được; chip "Cổ tay / khuỷu tay" tách thành hai từ khoá đều nhận ra. Ô "Khác" backend không nhận ra → cảnh báo `restrictionsIncomplete` (đã có) | `restriction-matcher.ts` dòng 36 |
| F9 | **Plan không có ngày bắt đầu:** `PlanProvider` chỉ lưu hồ sơ + plan; `history` có `created_at` nhưng chỉ khi đăng nhập | `plan_provider.dart`, BRD 6.2 |
| F10 | **Sửa hồ sơ làm hỏng đổi món:** đổi chiều cao, cân nặng, tuổi, mức vận động hay mục tiêu → mục tiêu calo đổi → mọi lần đổi món/feedback trên plan cũ trả 409 | `readClientPlan()`; `error_409` trong fixture |
| F11 | Tên app "my_ai_app" (Android, web), "My Ai App" (iOS); icon và màn khởi động là logo Flutter; thanh trạng thái đen trên nền sáng | `AndroidManifest.xml`, `web/index.html`, `Info.plist`; ảnh chụp máy ảo |
| F12 | **Khối lượng:** ~1.900 dòng giao diện phải viết lại hoặc nối (dashboard 621, grocery 530, onboarding 261, feedback 183, loading 118, macro_ring 117, view-model 99), cộng 2 thay đổi backend. PLAN ghi "M" là thấp — thực tế cỡ **L** | `wc -l` |

## 4. Các hướng tiếp cận

### Hướng A — Nối theo cấu trúc hiện có *(khuyến nghị)*

Giữ điều hướng `AppScreen` + `setState` của `MainShell` (BRD mục 4 chọn `setState`/`Provider`). Mỗi màn đọc/ghi qua `PlanProvider`; thêm một provider nhỏ cho hồ sơ đang sửa và trạng thái đi chợ. Làm backend (6.9, 6.10) trước để hợp đồng chốt rồi mới dựng form.

- **Ưu:** ít thay đổi kiến trúc, bám BRD, tận dụng nền giai đoạn 5 (provider, `FakeBackend`, fixture).
- **Nhược:** `MainShell` dài thêm; điều hướng bằng enum không có nút Back hệ thống cho từng bước onboarding (phải tự xử lý).

### Hướng B — Dựng lại khung: router + controller cho từng màn

`go_router`, mỗi màn một `ChangeNotifier` riêng, gom widget dùng chung vào `lib/widgets/`.

- **Ưu:** cấu trúc gọn cho giai đoạn 7–8; nút Back, deep link có sẵn.
- **Nhược:** thêm package ngoài lựa chọn của BRD; viết lại điều hướng đang chạy; khối lượng vốn đã lớn (F12).

### Hướng C — Hướng A, chia hai nửa, kéo đổi món/đổi bài lên

Như A, nhưng: nửa đầu = backend + onboarding + màn chờ (tạo được plan thật); nửa sau = dashboard, đi chợ, cá nhân, ngày trong plan, tên app. Nối luôn nút "Đổi món"/"Đổi bài" với API (7.1, 7.2 — provider đã có và đã test) thay vì để nút chết khi xoá view-model cũ.

- **Ưu:** không có giai đoạn nào để nút hiển thị mà không làm gì; mỗi nửa commit + push và chạy thử trên máy ảo được.
- **Nhược:** đổi thứ tự PLAN (7.1, 7.2 lên giai đoạn 6).

### Đối chiếu ràng buộc

| Ràng buộc | A | B | C |
|---|---|---|---|
| BRD mục 4 (`setState`/`Provider`, `http`) | ✓ | ✗ thêm `go_router` | ✓ |
| #7 danh sách đi chợ do server tính | ✓ | ✓ | ✓ |
| #12, #28 không log / không lưu server dữ liệu sức khoẻ | ✓ | ✓ | ✓ |
| #24 gửi đúng hồ sơ đã tạo plan (F10) | cần tách "hồ sơ của plan" và "hồ sơ đang sửa" | như A | như A |
| #26 đổi hợp đồng kèm fixture + model | ✓ nếu backend làm trước | ✓ | ✓ |

## 5. Thiết kế đề xuất (hướng A + cách chia của C)

### 5.1 Backend (6.9, 6.10) — làm trước

- **Tuổi 18–100** (`@Min(18)`); `sample-plan.spec.ts` đổi hồ sơ biên tuổi 10 → 18.
- **A1:** BMI < 18,5 và `goal = cut` → 400, câu tiếng Việt: "Chỉ số BMI của bạn đang dưới 18,5 (thiếu cân) nên không nên giảm mỡ. Hãy chọn Duy trì hoặc Tăng cơ." Kiểm trong cùng lớp hồ sơ nên áp cho cả 4 endpoint (#24). App nhận lỗi này qua `ValidationException` — nên message phải là câu tiếng Việt và app hiện nguyên (khác các lỗi 400 khác đang hiện câu chung).
- **A3:** cách biểu diễn là câu hỏi mở Q1 — khuyến nghị thêm trường `pregnant_or_breastfeeding` (boolean, mặc định `false`, chỉ hợp lệ khi `gender = female`) vào hồ sơ; `true` + `cut` → 400; `true` → cảnh báo "hỏi ý kiến bác sĩ". Không lưu DB, không log (#12).
- **A4:** `capWorkoutLevel(plan, maxLevel)` — cùng cơ chế `filterPlanByRestrictions()`: động tác có mức > giới hạn đổi sang động tác cùng nhóm cơ, mức ≤ giới hạn, không vướng chấn thương. Áp cho thực đơn mẫu và **cả kết quả Gemini** (xử lý tất định sau khi Gemini trả, không bắt Gemini tự đúng — động tác Gemini tự đặt không có trong kho thì giữ, trừ khi giới hạn là 1 và động tác có tag `jumping`). Prompt ghi thêm mức tối đa. Bảng mức là câu hỏi Q2.
- **BRD v2.6.0:** FR-1.1 (tuổi ≥ 18, câu hỏi mang thai), FR-1.3 (khi nào không được chọn Giảm mỡ), FR-1.4 (cách nhập D5), FR-2.2 (mức động tác), 6.1 (bảng trường), NFR mới "An toàn khi lập kế hoạch".
- `npm run fixtures:update`; model Dart `Profile` thêm trường (nếu Q1 = a); `contract_test.dart` xanh.

### 5.2 Nhập hồ sơ (6.1, 6.2)

- **Onboarding 3 bước**, thanh tiến trình, nút ở đáy (không bị đẩy xuống dưới mép màn hình nhỏ), nút Back của hệ thống quay lại bước trước:
  1. **Cơ thể:** tuổi, giới tính, chiều cao, cân nặng; nữ thì thêm "Đang mang thai hoặc cho con bú?" (đặt ở bước 1 để bước 2 biết có khoá "Giảm mỡ" không).
  2. **Mục tiêu & vận động:** 3 mức vận động (mô tả theo FR-1.2), 3 mục tiêu; "Giảm mỡ" bị khoá kèm lý do khi BMI < 18,5 hoặc mang thai / cho con bú. App tự tính BMI chỉ để khoá lựa chọn; backend vẫn là nơi quyết định (400).
  3. **Hạn chế (D5):** 3 công tắc "Tôi có dị ứng / chấn thương / bệnh nền", mặc định tắt → bật ra danh sách chip chọn nhiều + "Khác" (ô tự ghi). Dòng khuyến cáo y tế (NFR-9). Nếu bật bệnh nền: câu "Chế độ hiện tại chưa điều chỉnh thực đơn theo bệnh nền" khi backend không có Gemini (`/health` → `gemini: fallback`).
- **Danh sách chip** (nhãn gửi đi phải nằm trong `restriction-keywords.json`):
  - Dị ứng: Hải sản (tôm, cua, mực, nghêu…), Cá, Đậu phộng, Trứng, Sữa, Đậu nành, Gluten (bột mì), Mè (vừng), Nấm, Thịt bò, Thịt heo, Thịt gà.
  - Chấn thương: Đầu gối, Cổ chân, Cổ tay / khuỷu tay, Lưng / cột sống, Vai.
  - Bệnh nền: Tiểu đường, Cao huyết áp, Gout, Tim mạch, Dạ dày.
  - Ghép: các nhãn + phần "Khác", nối bằng ", ", tối đa 300 ký tự (đếm cả phần ghép, báo ngay khi vượt).
- **Chống lệch danh sách:** backend xuất thêm fixture `restriction_labels.json` (nhãn dị ứng, chấn thương từ file từ khoá) trong `contract-fixtures.e2e-spec.ts`; test Flutter kiểm mọi chip nằm trong đó.
- **Validate** cùng giới hạn backend: tuổi 18–100 (số nguyên), chiều cao 100–250, cân nặng 30–250; báo lỗi ngay dưới ô.
- **Hồ sơ của plan và hồ sơ đang sửa (F10):** `PlanProvider.profile` vẫn là hồ sơ đã tạo plan hiện tại — đổi món/feedback luôn gửi hồ sơ này, nên không bị 409. Tab "Cá nhân" sửa một bản nháp lưu riêng (`smartfit.profile_draft.v1`); khác hồ sơ của plan → dải nhắc "Hồ sơ đã thay đổi — tạo kế hoạch mới để áp dụng" + nút tạo lại. Dùng cùng widget form với onboarding.

### 5.3 Tạo plan (6.3)

- Bước 3 onboarding (hoặc nút "Tạo kế hoạch mới") → `PlanProvider.generate(profile)` → màn chờ.
- Màn chờ theo `busy`: spinner + câu chờ thật ("Đang lập thực đơn món Việt cho bạn…"); sau 15 s đổi câu "Gemini đang làm, có thể mất tới 40 giây"; không có số liệu bịa, bỏ nút "Xem trước".
- Lỗi → hiện `ApiException.message` + "Thử lại" + "Sửa hồ sơ". 400 của A1/A3 quay về đúng bước onboarding.
- Không có nút huỷ (request tối đa ~40 s, huỷ phía app không dừng được Gemini).

### 5.4 Dashboard (6.4) và ngày trong plan (6.11)

- 3 tab ngày (bỏ S1–S5), mỗi ngày: nhãn ngày theo lịch, 3 bữa (sáng, trưa, tối) với calo + macro, tổng ngày so với `daily_target` bằng `MacroRing`, buổi tập (tên, thời lượng, động tác, số hiệp).
- Dải `warnings` (hiện nguyên văn, thu gọn được); nhãn nhỏ "Thực đơn mẫu" khi `source = sample`.
- **Ngày trong plan:** lưu `smartfit.plan_meta.v1 = { plan_id, start_date }` (ngày theo giờ máy).
  - Tạo plan → bắt đầu hôm nay; plan sinh từ feedback ngày 3 → bắt đầu ngày mai.
  - Mở app → chọn sẵn tab của hôm nay; chưa tới ngày bắt đầu → "Bắt đầu từ ngày mai"; quá ngày 3 → dải "Kế hoạch đã hết — tạo kế hoạch mới".
  - Đổi món/đổi bài giữ `plan_id` → giữ ngày bắt đầu.
- **Đổi món, đổi bài** gọi `PlanProvider.swapMeal/swapExercise` (Q3): khoá nút khi `busy`; 409 → câu của server + nút "Tạo kế hoạch mới"; 422 → câu của server.
- Bỏ nhãn "Dễ", chữ "T" viết cứng; giữ "Không dụng cụ" (FR-2.2 luôn là bodyweight).

### 5.5 Đi chợ (6.5)

- Dựng từ `grocery_list`, tên nhóm theo BRD FR-3.1 (*Đạm*, *Rau củ quả*, *Gạo, bún & gia vị*), giữ tìm kiếm và lọc theo nhóm.
- Mỗi dòng: tích "đã mua"; vuốt hoặc nút "Đã có sẵn" để ẩn (FR-3.2), có "Hiện lại".
- Trạng thái lưu `smartfit.grocery.v1 = { plan_id, bought: [...], have: [...] }`, khoá mỗi dòng = nhóm + tên + `quantity` → đổi món làm lượng thay đổi thì dòng đó bỏ tích (cần mua thêm); plan mới (`plan_id` khác) → xoá trạng thái.
- Nút "Thêm nguyên liệu": câu hỏi Q4.

### 5.6 Hoàn thiện (6.7, 6.8, 6.6)

- Xoá `lib/models/meal_plan.dart`; `feedback_bottom_sheet.dart` giữ tới giai đoạn 7 hoặc ẩn nút (theo Q3).
- Tên "SmartFit AI" ở Android/iOS/web; icon và màn khởi động màu thương hiệu `#00875A` (tự tạo bằng SVG → PNG; thay được khi nhóm có logo); thanh trạng thái sáng.
- Tab "Thống kê": bỏ số liệu viết cứng, ghi "Lịch sử kế hoạch — có ở giai đoạn 8".
- Test: widget test từng màn với `FakeBackend` + fixture; `integration_test` thêm luồng onboarding → dashboard trên máy ảo; kiểm lại cỡ chữ 130% và màn hình 720×1280.

## 6. Edge case

- **Hồ sơ cũ trên máy không còn hợp lệ** (tuổi 17 lưu từ trước, hoặc thiếu cân + `cut`): mọi request trả 400 → app đưa về bước onboarding tương ứng, giữ các giá trị khác.
- **Plan cũ lưu trên máy** của hồ sơ nay bị cấm (thiếu cân + `cut`): xem được, nhưng đổi món/feedback trả 400 → dải nhắc sửa hồ sơ.
- **Đổi giới tính sang nam** khi đã bật mang thai → trường tự về `false` (hoặc backend 400 nếu Q1 = a).
- **Tắt công tắc** dị ứng sau khi đã tích → gửi chuỗi rỗng, nhưng giữ lựa chọn trong bản nháp để bật lại không phải chọn lại.
- **Chuỗi ghép vượt 300 ký tự** → khoá nút tiếp tục, báo số ký tự.
- **Mở app qua nửa đêm** → tab ngày cập nhật khi app trở lại foreground (`AppLifecycleState.resumed`).
- **Đổi giờ máy về quá khứ** (trước ngày bắt đầu) → hiện "Bắt đầu từ …", không lỗi.
- **Mất mạng khi bấm đổi món** → `NetworkException`, món cũ giữ nguyên.
- **Backend có Gemini, chờ 40 s** → màn chờ vẫn đúng câu; app hết giờ ở 60 s.
- **Gemini trả động tác không có trong kho** cho người mức 1 → giữ, trừ khi có tag `jumping` (A4).
- **Không có động tác mức ≤ giới hạn** cho một nhóm cơ (không xảy ra nhờ #25) → bỏ động tác đó; buổi rỗng → `WALK_EXERCISE` như lọc chấn thương.

## 7. Câu hỏi mở — cần trả lời trước `/feature-plan`

1. **A3 — biểu diễn "mang thai / cho con bú":**
   - (a) trường mới `pregnant_or_breastfeeding` (boolean) trong hồ sơ; backend kiểm được, rõ ràng *(khuyến nghị)*;
   - (b) một chip trong ô bệnh nền + backend nhận từ khoá "mang thai", "cho con bú" (không đổi hợp đồng, nhưng dựa vào chữ);
   - (c) chỉ app khoá lựa chọn, backend không kiểm.
2. **A4 — giới hạn mức động tác:**
   - (a) tuổi ≥ 60, hoặc ≥ 45 và ít vận động → mức 1; còn lại ít vận động / vận động nhẹ → mức ≤ 2 (như thực đơn mẫu hiện nay); vận động nhiều và < 45 tuổi → cho phép mức 3 *(khuyến nghị)*;
   - (b) chỉ hạ mức cho người lớn tuổi / ít vận động, không bao giờ nâng lên mức 3;
   - (c) chỉ theo mức vận động: ít → 1, nhẹ → 2, nhiều → 3, không xét tuổi.
3. **Nút đổi món / đổi bài ở giai đoạn 6:**
   - (a) nối luôn với API (7.1, 7.2 chuyển lên giai đoạn 6); nút feedback ẩn tới giai đoạn 7 *(khuyến nghị)*;
   - (b) tạm khoá cả ba nút tới giai đoạn 7.
4. **Nút "Thêm nguyên liệu" ở màn đi chợ** (không có trong BRD):
   - (a) bỏ *(khuyến nghị — đúng FR-3.2, bớt việc)*;
   - (b) giữ, nguyên liệu tự thêm lưu trên máy, tách khỏi danh sách server tính.

Không hỏi, theo khuyến nghị (đổi được nếu muốn):

- Hướng A, chia hai nửa như C; ước lượng giai đoạn 6 đổi từ M thành L.
- Tách "hồ sơ của plan" và "hồ sơ đang sửa" (F10).
- Plan tạo từ feedback ngày 3 bắt đầu từ ngày mai.
- Trạng thái đi chợ khoá theo cả lượng (`quantity`).
- Icon tự tạo màu thương hiệu, thay được khi có logo.

## 8. Quyết định (2026-09-26)

| Câu hỏi | Quyết định |
|---|---|
| Q1 | **Trường mới `pregnant_or_breastfeeding`** (boolean, mặc định `false`, chỉ hợp lệ khi `gender = female`) trong hồ sơ; `true` + `cut` → 400; `true` → cảnh báo hỏi ý kiến bác sĩ. Không lưu DB, không log (#12). Đổi hợp đồng BRD 6.1 → xuất lại fixture, sửa model Dart |
| Q2 | **Giới hạn mức theo tuổi + mức vận động:** ≥ 60 tuổi, hoặc ≥ 45 và ít vận động → mức 1; còn lại ít vận động / vận động nhẹ → mức ≤ 2; vận động nhiều và < 45 tuổi → cho phép mức 3. Áp cho thực đơn mẫu và kết quả Gemini (xử lý tất định sau khi Gemini trả) |
| Q3 | **Nối nút đổi món / đổi bài với API ở giai đoạn 6** (7.1, 7.2 chuyển lên); nút feedback ẩn tới giai đoạn 7 |
| Q4 | **Bỏ nút "Thêm nguyên liệu"** — đúng BRD FR-3.2 |

Các mục "không hỏi" ở cuối mục 7 giữ theo khuyến nghị. BRD lên **v2.6.0** (FR-1.1, FR-1.3, FR-1.4, FR-2.2, 6.1, NFR an toàn).

**Bước tiếp theo:** `/feature-plan phase-6-connect-mvp`.
