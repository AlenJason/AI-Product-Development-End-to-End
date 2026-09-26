# F06 — Tài liệu: BRD v2.6.0, wiki, CLAUDE.md, README, PLAN

## Feature

Ghi lại luật mới và app sau giai đoạn 6. **BRD lên v2.6.0** vì đổi phạm vi và hợp đồng: tuổi 18–100, trường `pregnant_or_breastfeeding`, khi nào không được Giảm mỡ, cách nhập hạn chế (D5), độ khó bài tập theo hồ sơ, ngày theo lịch, NFR-10 an toàn.

| File | Thay đổi |
|---|---|
| `BRD.md` | Phiên bản 2.6.0, ngày 27/09/2026; FR-1.1, FR-1.3, FR-1.4, FR-1.6, FR-2.2, FR-2.4 (mới), mục 6.1 (ví dụ + bảng), NFR-7, NFR-10 (mới) |
| `docs/knowledge/wiki/critical-constraints.md` | #12 thêm cờ mang thai; #30 hồ sơ an toàn, #31 mức động tác ở mọi đường, #32 chip hạn chế ⊆ nhãn backend |
| `docs/knowledge/wiki/flutter-ui.md` | Viết lại: màn hình, khoá lưu mới, icon, test |
| `docs/knowledge/wiki/plan-data-contract.md` | Mục "Hồ sơ an toàn và mức động tác" |
| `docs/knowledge/wiki/swap-and-feedback.md` | Giới hạn mức khi đổi bài và đau khớp |
| `docs/knowledge/wiki/wiki-triggers.md`, `INDEX.md`, `log.md` | Đường dẫn và từ khoá mới |
| `CLAUDE.md` | Repository layout, luồng plan (bước 1, 5), adjust, Frontend architecture, lệnh `tool/update_icons.sh` |
| `README.md` | Cấu trúc thư mục, changelog BRD v2.6.0 |
| `docs/PLAN.md` | BRD v2.6.0; hiện trạng; tích 6.1–6.11, 7.1, 7.2 (làm ở giai đoạn 6); giai đoạn 6 cỡ L; "Để sau" thêm cân macro thực đơn mẫu |

Nội dung dưới đây là diff đúng từng dòng so với HEAD.

## Scope

Docs-only.

## Implementation

### API Routes

Không có.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- BRD "Approved": đổi phạm vi → nâng phiên bản, đánh dấu "*(bổ sung bản 2.6.0)*" tại chỗ sửa.
- Tên file wiki tiếng Anh, nội dung tiếng Việt.

## Definition of Done

- [ ] `grep -c "2.6.0" BRD.md` ≥ 10; `grep -c "^| 3[0-2] |" docs/knowledge/wiki/critical-constraints.md` = 3
- [ ] `grep -rn "meal_plan.dart\|feedback_bottom_sheet" CLAUDE.md docs/knowledge/wiki/flutter-ui.md` không ra dòng nào
- [ ] PLAN: `grep -c "^- \[x\] \*\*6\." docs/PLAN.md` = 11

## Test Checklist

1. **@links**: mọi `[[...]]` trong bài wiki sửa trỏ tới bài có thật
2. **@numbers**: số test trong wiki/README khớp lần chạy cuối (89 Flutter, 320 unit, 74 e2e)
3. Các nhãn khác: không áp dụng

## Tasks

### Task 1 — BRD v2.6.0

```diff
--- a/BRD.md
+++ b/BRD.md
@@ -3,8 +3,8 @@
 **Tên sản phẩm:** Trợ lý AI Gợi ý & Điều chỉnh Thực đơn, Lịch tập Thông minh  
 **Môn học:** AI Product Development End-to-End (Đồ án Kỹ sư / Cử nhân Năm 4)  
 **Đơn vị thực hiện:** Trường Đại học Công nghệ Thông tin và Truyền thông Việt - Hàn (VKU)  
-**Phiên bản:** 2.5.1 (Dành cho Sinh viên thực hành: Flutter & NestJS)  
-**Ngày cập nhật:** 24/09/2026  
+**Phiên bản:** 2.6.0 (Dành cho Sinh viên thực hành: Flutter & NestJS)  
+**Ngày cập nhật:** 27/09/2026  
 **Trạng thái:** Đã phê duyệt (Approved)  
 
 ---
@@ -117,17 +117,18 @@
 ### Giai đoạn 1: MVP Cốt lõi (Bắt buộc hoàn thành để nộp đồ án)
 
 #### FR-1: Khảo sát thông tin (Personalized Onboarding)
-* **FR-1.1:** Giao diện Form nhập: Tuổi, giới tính, chiều cao (cm), cân nặng (kg).
+* **FR-1.1:** Giao diện Form nhập: Tuổi (từ 18 tuổi — công thức Mifflin-St Jeor dành cho người trưởng thành, đúng đối tượng ở mục 3), giới tính, chiều cao (cm), cân nặng (kg); nữ khai thêm *đang mang thai hoặc cho con bú*. Onboarding chia 3 bước — cơ thể → mục tiêu & vận động → hạn chế — có thanh tiến trình, nút tiếp tục luôn ở đáy màn hình. *(bổ sung bản 2.6.0)*
 * **FR-1.2:** Chọn mức độ vận động hằng ngày (Activity Level) — bắt buộc để tính TDEE đúng công thức: *Ít vận động (Sedentary, dân văn phòng)*, *Vận động nhẹ (1–3 buổi tập/tuần)*, *Vận động nhiều (4–5 buổi tập/tuần)*.
-* **FR-1.3:** Chọn mục tiêu: *Giảm mỡ (Cut)* — thâm hụt 300 kcal/ngày, *Tăng cơ (Bulk)* — dư 250 kcal/ngày, hoặc *Duy trì vóc dáng (Maintain)*.
-* **FR-1.4:** Ba ô nhập tự do, tối đa 300 ký tự mỗi ô: *Dị ứng / thực phẩm cần tránh*, *Chấn thương / vùng cơ thể cần tránh*, *Tình trạng sức khoẻ / bệnh nền* (ví dụ tiểu đường, cao huyết áp, gout). Có chip gợi ý bấm nhanh (hải sản, trứng, sữa, đậu phộng, đau gối, đau lưng…); bấm vào chỉ điền sẵn chữ vào ô. Màn hình ghi rõ: gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế. Ở chế độ giả lập (chưa có khoá Gemini), backend nhận ra các dị ứng, chấn thương phổ biến bằng từ khoá (gõ có dấu hay không dấu đều được) để lọc thực đơn mẫu; có phần không nhận ra thì app nhận một câu cảnh báo chung, không nhắc lại chữ người dùng đã nhập. *(bổ sung bản 2.5.0)*
+* **FR-1.3:** Chọn mục tiêu: *Giảm mỡ (Cut)* — thâm hụt 300 kcal/ngày, *Tăng cơ (Bulk)* — dư 250 kcal/ngày, hoặc *Duy trì vóc dáng (Maintain)*. **Không chọn được Giảm mỡ** khi BMI dưới 18,5 (thiếu cân) hoặc đang mang thai / cho con bú: app khoá lựa chọn kèm lý do, backend trả 400 cho mọi request có hồ sơ như vậy. *(bổ sung bản 2.6.0)*
+* **FR-1.4:** Ba mục *Dị ứng / thực phẩm cần tránh*, *Chấn thương / vùng cơ thể cần tránh*, *Tình trạng sức khoẻ / bệnh nền*, mỗi mục một công tắc "Tôi có …" mặc định tắt (= không có). Bật lên thì hiện danh sách phổ biến để tích nhiều mục — dị ứng: hải sản, cá, đậu phộng, trứng, sữa, đậu nành, gluten, mè, nấm, thịt bò, thịt heo, thịt gà; chấn thương: đầu gối, cổ chân, cổ tay / khuỷu tay, lưng / cột sống, vai; bệnh nền: tiểu đường, cao huyết áp, gout, tim mạch, dạ dày — và lựa chọn "Khác" để tự ghi. App ghép lựa chọn thành văn bản, tối đa 300 ký tự mỗi mục (hợp đồng mục 6.1 không đổi). Danh sách dị ứng và chấn thương lấy đúng các nhóm backend nhận ra bằng từ khoá. *(bản 2.6.0 — thay ô nhập tự do và chip điền sẵn chữ)* Màn hình ghi rõ: gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế. Ở chế độ giả lập (chưa có khoá Gemini), backend nhận ra các dị ứng, chấn thương phổ biến bằng từ khoá (gõ có dấu hay không dấu đều được) để lọc thực đơn mẫu; có phần không nhận ra thì app nhận một câu cảnh báo chung, không nhắc lại chữ người dùng đã nhập. *(bổ sung bản 2.5.0)*
 * **FR-1.5 (Logic Deterministic):** Backend tự tính BMI, BMR (công thức Mifflin-St Jeor), TDEE = BMR × hệ số hoạt động (FR-1.2), và calo mục tiêu = TDEE + mức điều chỉnh theo mục tiêu (FR-1.3), **nhưng không bao giờ thấp hơn BMR**. Khi phải nâng lên bằng BMR, response có câu giải thích để app hiển thị. **Tổng calo thực đơn mỗi ngày** cũng phải nằm trong khoảng từ 85% mục tiêu (và không thấp hơn BMR) tới 110% mục tiêu; thực đơn mẫu được nhân khẩu phần cho khớp mục tiêu của từng người. *(bổ sung bản 2.5.0)*
-* **FR-1.6:** Tab "Cá nhân" cho xem và sửa hồ sơ (chỉ số cơ thể, mục tiêu, ba ô ở FR-1.4) bất cứ lúc nào. Hồ sơ chỉ lưu trên máy (`shared_preferences`) và gửi kèm từng request, **không lưu ở server**. Sửa xong, app gợi ý tạo lại plan.
+* **FR-1.6:** Tab "Cá nhân" cho xem và sửa hồ sơ (chỉ số cơ thể, mục tiêu, ba mục ở FR-1.4) bất cứ lúc nào. Hồ sơ chỉ lưu trên máy (`shared_preferences`) và gửi kèm từng request, **không lưu ở server**. Sửa xong, app gợi ý tạo lại plan; tới khi tạo lại, đổi món và feedback vẫn dùng hồ sơ đã tạo plan đang mở. *(bổ sung bản 2.6.0)*
 
 #### FR-2: Khởi tạo kế hoạch 3 ngày (Rolling 3-Day Plan)
 * **FR-2.1 (Thực đơn món Việt):** 3 ngày, mỗi ngày 3 bữa chính (Sáng, Trưa, Tối). Món ăn quen thuộc (phở, bún thịt nạc, canh rau ngót, trứng luộc...). **Ràng buộc đa dạng:** không lặp lại tên món giữa các ngày trong cùng một plan 3 ngày — backend kiểm tra bằng code, không chỉ dặn trong prompt.
-* **FR-2.2 (Bài tập tại nhà):** Lịch tập 3 ngày gồm các động tác Bodyweight (Squat, chống đẩy khuỵu gối, plank...), ghi rõ số hiệp (sets) và số lần (reps).
+* **FR-2.2 (Bài tập tại nhà):** Lịch tập 3 ngày gồm các động tác Bodyweight (Squat, chống đẩy khuỵu gối, plank...), ghi rõ số hiệp (sets) và số lần (reps). **Độ khó theo hồ sơ:** từ 60 tuổi, từ 45 tuổi mà ít vận động, hoặc đang mang thai / cho con bú → chỉ động tác nhẹ nhất (mức 1, không bật nhảy); vận động nhiều và dưới 45 tuổi → được dùng cả động tác nâng cao (mức 3); còn lại tối đa mức 2. Áp cho thực đơn mẫu, kết quả Gemini, đổi bài tập và điều chỉnh sau feedback. *(bổ sung bản 2.6.0)*
 * **FR-2.3 (Hiển thị Calo):** Hiển thị tổng Calo dự tính và phân bổ Protein / Carbs / Fat mỗi ngày. Mỗi món có đủ `calories`, `protein_g`, `carbs_g`, `fat_g`.
+* **FR-2.4 (Ngày theo lịch):** App lưu ngày bắt đầu của plan và mở đúng ngày hôm nay; plan tạo từ feedback ngày 3 bắt đầu từ ngày mai; quá 3 ngày thì gợi ý tạo kế hoạch mới. *(bổ sung bản 2.6.0)*
 
 #### FR-3: Danh sách đi chợ thông minh (Smart Grocery Checklist)
 * **FR-3.1:** Backend tự tổng hợp nguyên liệu của cả 3 ngày thành danh sách 3 nhóm cố định: *Đạm* (thịt, cá, trứng, đậu phụ, sữa), *Rau củ quả*, *Gạo, bún & gia vị* (gạo, bún, mì, gia vị, dầu ăn). Nguyên liệu trùng tên và cùng đơn vị được cộng dồn khối lượng.
@@ -188,6 +189,7 @@
   "weight_kg": 62,
   "activity_level": "light",
   "goal": "cut",
+  "pregnant_or_breastfeeding": false,
   "restrictions": {
     "allergies": "Hải sản",
     "injuries": "Đau gối",
@@ -198,11 +200,12 @@
 
 | Trường | Giá trị |
 |---|---|
-| `age` | số nguyên 10–100 |
+| `age` | số nguyên 18–100 *(bản 2.6.0, trước là 10–100)* |
 | `gender` | `male` / `female` |
 | `height_cm`, `weight_kg` | 100–250 cm, 30–250 kg |
 | `activity_level` | `sedentary` (ít vận động) / `light` (vận động nhẹ) / `active` (vận động nhiều) — FR-1.2 |
-| `goal` | `cut` / `bulk` / `maintain` — FR-1.3 |
+| `goal` | `cut` / `bulk` / `maintain` — FR-1.3. `cut` bị từ chối (400, câu tiếng Việt) khi BMI < 18,5 hoặc `pregnant_or_breastfeeding = true` *(bản 2.6.0)* |
+| `pregnant_or_breastfeeding` | `true` / `false`, mặc định `false`; chỉ được `true` khi `gender = female`. Dữ liệu sức khoẻ: không lưu ở server, không ghi log (NFR-7) *(bổ sung bản 2.6.0)* |
 | `restrictions.allergies`, `.injuries`, `.health_conditions` | văn bản tự do, tối đa 300 ký tự, có thể bỏ trống hoặc bỏ hẳn `restrictions` — FR-1.4. Không lưu ở server (NFR-7) |
 
 ### 6.2. Response — Kế hoạch 3 ngày
@@ -436,10 +439,11 @@
    * Trong lúc code/test, backend chạy tạm trên localhost (`npm run start:dev`) là đủ. Muốn demo/nộp bài với nhiều thiết bị thật hoạt động ổn định lâu dài (không phụ thuộc laptop của nhóm có đang bật hay không), cần **deploy `backend_api/` lên một nơi chạy liên tục**.
    * Vì SQLite là một file trên ổ đĩa của server, nơi deploy phải có **ổ lưu trữ bền** (persistent disk/volume). Nhiều gói hosting miễn phí dùng ổ đĩa tạm: file bị xoá mỗi khi service ngủ, restart hoặc redeploy. Ví dụ, Render bản free không gắn được persistent disk, nên dùng SQLite trên đó sẽ mất toàn bộ tài khoản và lịch sử. Hai hướng đúng: (a) giữ SQLite, chọn host có volume bền (ví dụ Railway volume, Fly.io volume, hoặc VPS); (b) chuyển sang Postgres được quản lý sẵn — TypeORM chỉ cần đổi cấu hình kết nối. Kiểm tra lại gói và giá hiện hành của host trước khi chọn.
 7. **Quyền riêng tư dữ liệu sức khoẻ (bổ sung bản 2.3.0):**
-   * Dị ứng, chấn thương, tình trạng sức khoẻ là dữ liệu cá nhân nhạy cảm (Nghị định 13/2023/NĐ-CP). Chúng chỉ lưu trên máy người dùng, gửi kèm từng request rồi bỏ đi: backend không ghi vào database, không ghi log nội dung request hay nội dung Gemini trả về.
+   * Dị ứng, chấn thương, tình trạng sức khoẻ và việc mang thai / cho con bú là dữ liệu cá nhân nhạy cảm (Nghị định 13/2023/NĐ-CP). Chúng chỉ lưu trên máy người dùng, gửi kèm từng request rồi bỏ đi: backend không ghi vào database, không ghi log nội dung request hay nội dung Gemini trả về.
    * Plan lưu trong lịch sử (FR-7) không chứa các trường này.
 8. **Chống prompt injection (bổ sung bản 2.3.0):** Văn bản tự do của người dùng được đặt trong một khối dữ liệu có thẻ phân cách, bỏ ký tự `<` `>` và xuống dòng, giới hạn 300 ký tự mỗi ô; prompt dặn Gemini coi khối này là dữ liệu, không phải chỉ dẫn. Đầu ra vẫn phải qua bộ kiểm tra ở NFR-4, nên dù bị chèn lệnh cũng không làm hỏng app.
 9. **Khuyến cáo y tế (bổ sung bản 2.3.0):** Onboarding ghi rõ gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế. Khi người dùng có khai tình trạng sức khoẻ, hoặc khi calo mục tiêu phải nâng lên bằng BMR, response có câu giải thích trong `warnings` để app hiển thị.
+10. **An toàn khi lập kế hoạch (bổ sung bản 2.6.0):** Không phục vụ người dưới 18 tuổi; không lập kế hoạch thâm hụt calo cho người thiếu cân (BMI < 18,5) hoặc đang mang thai / cho con bú (FR-1.3); độ khó bài tập giới hạn theo tuổi, mức vận động và thai kỳ (FR-2.2). Backend kiểm ở mọi endpoint nhận hồ sơ, kể cả đổi món, đổi bài, feedback; app khoá lựa chọn theo đúng các ngưỡng đó. Người mang thai / cho con bú nhận thêm khuyến cáo hỏi ý kiến bác sĩ trong `warnings`.
 
 ---
```

### Task 2 — Ràng buộc

```diff
--- a/docs/knowledge/wiki/critical-constraints.md
+++ b/docs/knowledge/wiki/critical-constraints.md
@@ -1,5 +1,5 @@
 ---
-last_updated: 2026-09-26
+last_updated: 2026-09-27
 ---
 
 # Ràng buộc cứng của dự án
@@ -21,7 +21,7 @@
 | 9 | Model Gemini mặc định là `gemini-3.5-flash` (`DEFAULT_MODEL` trong `backend_api/src/plan/gemini.service.ts`, `.env.example` của `backend_api/` và `ai_workspace/`, BRD.md mục 4); đổi qua `GEMINI_MODEL`. Đổi model hay mức suy nghĩ → đo lại bằng `npm run build && npm run measure:gemini` trước khi đổi giá trị mặc định. | Đổi từ `gemini-3.8-flash` ngày 2026-09-24 sau khi đo bằng khoá thật: 3.8 liên tục 503 (quá tải), chưa trả được plan nào; 3.5 đạt hợp đồng trong 8–15 s khi tắt suy nghĩ. Gói miễn phí chỉ 20 lần gọi/ngày cho mỗi model (`GenerateRequestsPerDayPerProjectPerModel-FreeTier`) — xem [[gemini-integration]]. |
 | 10 | Xác thực **chỉ** qua Google Sign-In: `google-auth-library` xác minh ID Token phía backend, backend phát JWT riêng qua `@nestjs/jwt` (`backend_api/src/auth/`). Backend **không được tự lưu hoặc xử lý mật khẩu** người dùng dưới bất kỳ hình thức nào. Lưu trữ dùng SQLite qua `@nestjs/typeorm`, driver `better-sqlite3` bản 12 (`backend_api/src/database/`); `*.sqlite` nằm trong `.gitignore`. | Quyết định 2026-09-22 (BRD mục 4, FR-6, FR-7, NFR-5), có code từ giai đoạn 3. Tự lưu mật khẩu là rủi ro bảo mật không cần thiết khi Google đã lo phần đó. TypeORM 1.x không còn driver `sqlite3` và chỉ nhận `better-sqlite3 ^12` — xem [[auth-and-history]]. |
 | 11 | `database.sqlite` nằm trên **máy chạy `backend_api/`**, không phải trên điện thoại người dùng. Lịch sử kế hoạch (FR-7) xem xuyên thiết bị được là nhờ mọi thiết bị cùng gọi vào một backend, một file DB — khác hẳn `shared_preferences` (luôn cục bộ theo máy). Muốn demo/nộp bài ổn định với nhiều thiết bị thật, cần deploy `backend_api/` lên nơi chạy liên tục **và có ổ lưu trữ bền** — không dùng host có ổ đĩa tạm (ví dụ Render bản free) với SQLite, vì file DB bị xoá khi service ngủ/restart/redeploy. Hoặc chuyển sang Postgres được quản lý sẵn. | Làm rõ 2026-09-22 sau khi có nhầm lẫn rằng SQLite "lưu cục bộ trên thiết bị" giống `shared_preferences`; sửa 2026-09-24 sau khi xác minh Render free không gắn được persistent disk (BRD.md mục 7.6). |
-| 12 | Dị ứng, chấn thương, tình trạng sức khoẻ (`restrictions`) chỉ đi kèm từng request: **không** lưu vào DB (`PlanRecord.plan_json` là response đã trả, vốn không có `restrictions` — `history.e2e-spec.ts` kiểm trực tiếp trong DB), **không** ghi log request body hay nội dung Gemini trả về. Log chỉ ghi thông báo lỗi và vi phạm hợp đồng. | BRD NFR-7 — dữ liệu cá nhân nhạy cảm theo Nghị định 13/2023/NĐ-CP. Thông báo lỗi của `JSON.parse` có trích nội dung đầu vào, nên `gemini.service.ts` thay bằng thông báo chung. Phía app: #28. |
+| 12 | Dị ứng, chấn thương, tình trạng sức khoẻ (`restrictions`) và cờ mang thai / cho con bú (`pregnant_or_breastfeeding`, từ v2.6.0) chỉ đi kèm từng request: **không** lưu vào DB (`PlanRecord.plan_json` là response đã trả, vốn không có `restrictions` — `history.e2e-spec.ts` kiểm trực tiếp trong DB), **không** ghi log request body hay nội dung Gemini trả về. Log chỉ ghi thông báo lỗi và vi phạm hợp đồng. | BRD NFR-7 — dữ liệu cá nhân nhạy cảm theo Nghị định 13/2023/NĐ-CP. Thông báo lỗi của `JSON.parse` có trích nội dung đầu vào, nên `gemini.service.ts` thay bằng thông báo chung. Phía app: #28. |
 | 13 | Calo mục tiêu = `max(TDEE + điều chỉnh, BMR)` (`computeDailyTarget()` trong `backend_api/src/plan/daily-target.ts`); điều chỉnh: cut −300, bulk +250. Sàn BMR áp cho cả **thực đơn thật**: tổng calo mỗi ngày ≥ BMR được kiểm trong `findPlanViolations()`; thực đơn mẫu và món trong kho được nhân khẩu phần (`meal-scaling.ts`) cho khớp mục tiêu; feedback "ăn nhiều hơn" chỉ hạ ngày kế tiếp xuống max(90% mục tiêu, BMR). Mọi tính năng tự tính lại BMR từ `profile`, không tin số `bmr` client gửi lên. | BRD FR-1.3, FR-1.5, FR-5.2 (v2.5.0), quyết định D1, Q4 (giai đoạn 1) và Q1, Q3 (giai đoạn 4). Không có sàn thì người nhỏ con ít vận động bị đặt mục tiêu dưới BMR (ví dụ 1040 kcal khi BMR 1117). Thực đơn mẫu cố định ~1550 kcal/ngày từng thấp hơn BMR của mọi hồ sơ nam trong ma trận test. |
 | 14 | Feedback có dấu hiệu nguy hiểm (`danger_sign`: chóng mặt, khó thở bất thường, đau ngực) → **không** áp các quy tắc điều chỉnh thông thường, kể cả cân đối món ăn; trả `safety_warning` khuyên ngừng tập, hỏi ý kiến bác sĩ, gọi 115 nếu nặng; ngày kế tiếp (hoặc ngày 1 của plan mới) chỉ nghỉ hoặc đi bộ nhẹ. | BRD FR-5.2, quyết định D2. Có code từ giai đoạn 4: `adjustWorkout()` (`src/plan/adjust/workout-rules.ts`) trả `REST_WORKOUT` trước mọi quy tắc khác; `FeedbackService` không gọi Gemini khi có dấu hiệu này. Test riêng trong `workout-rules.spec.ts` và `feedback.service.spec.ts`. |
 | 15 | Mỗi lần gọi Gemini có timeout `GEMINI_TIMEOUT_MS` (mặc định 20 000 ms); cả lần đầu lẫn lần gọi lại không quá `GEMINI_TOTAL_TIMEOUT_MS` (mặc định 40 000 ms). Mọi chỗ gọi Gemini đi qua `generateWithRetry()` (`backend_api/src/plan/gemini-retry.ts`): lỗi hoặc sai hợp đồng → gọi lại đúng 1 lần, chỉ khi còn ≥ 5 s và chỉ dùng phần thời gian còn lại; hết giờ → không gọi lại, dùng ngay dữ liệu soạn sẵn hoặc giữ món cũ. Mức suy nghĩ `GEMINI_THINKING` mặc định `off`. **Không** truyền `retryOptions` cho SDK `@google/genai`. | BRD NFR-1 (v2.5.1). Đo với Gemini thật: để model tự suy nghĩ thì tạo plan mất 37–42 s (~7000 token suy nghĩ), `low` 18–27 s, `off` 8–13 s; giới hạn 15 s cũ khiến gần như mọi lần gọi hết giờ. SDK có cơ chế tự gọi lại (5 lần, chờ tới 60 s) chỉ bật khi có `retryOptions` — lỗi 500 → đúng 1 request, `gemini.service.spec.ts` khoá hành vi này. |
@@ -39,5 +39,8 @@
 | 27 | CORS chỉ cấu hình trong `resolveCorsOptions()` (`backend_api/src/cors-options.ts`), gọi từ `configureApp()` (#18), qua biến `CORS_ORIGINS` (danh sách `http(s)://host[:port]` cách nhau dấu phẩy). Trống khi phát triển → `http://localhost` và `http://127.0.0.1` mọi cổng; trống khi `NODE_ENV=production` → tắt CORS; origin sai dạng → backend không khởi động. Header cho phép phải có `Authorization`; `credentials: false`; không dùng `origin: true` hay `*`. | Quyết định Q2 giai đoạn 5. Trước đó preflight trả 404 nên mọi POST từ bản web bị trình duyệt chặn (phát hiện F1). Đã kiểm trong Chrome thật: origin không khai báo bị chặn cả GET lẫn POST. App mobile không gửi `Origin` nên không bị ảnh hưởng. |
 | 28 | App Flutter gọi backend chỉ qua `ApiClient` (`frontend_app/lib/services/api_client.dart`): timeout 60 s cho request có thể gọi Gemini (dài hơn 40 s của backend — #15), 15 s cho phần còn lại; body đọc bằng UTF-8 từ `bodyBytes`; mọi lỗi thành `ApiException` có câu tiếng Việt cho người dùng. **Không** in request/response body, hồ sơ hay token ra log (`print`, `debugPrint`, `log`); chi tiết lỗi 400 chỉ giữ trong `ValidationException.details`. Hồ sơ (kể cả `restrictions`) và JWT chỉ lưu trên máy bằng `shared_preferences` (web: `localStorage`), khoá có số phiên bản, bản lưu hỏng thì xoá. | BRD NFR-2, NFR-7, mục 4; quyết định Q3 giai đoạn 5. Body chứa dữ liệu sức khoẻ (#12). App hết giờ trước backend thì báo lỗi trong khi plan vẫn đang được tạo (phát hiện F8). Không có `Content-Type` thì package `http` giải mã latin1 — tên món tiếng Việt bị vỡ. |
 | 29 | Quyền mạng: Android khai báo `INTERNET` trong `android/app/src/main/AndroidManifest.xml` (bản release), `usesCleartextTraffic` **chỉ** trong manifest debug; iOS dùng `NSAllowsLocalNetworking` (không dùng `NSAllowsArbitraryLoads`); macOS có `com.apple.security.network.client` trong cả `DebugProfile.entitlements` lẫn `Release.entitlements`. Bản release chỉ gọi backend qua `https://`. | Phát hiện F3, F4 giai đoạn 5: template Flutter chỉ có `INTERNET` trong manifest debug, nên APK demo (PLAN 9.3) sẽ không gọi được mạng; app macOS chạy trong sandbox, thiếu quyền gọi ra ngoài. HTTP của Dart không bị chính sách cleartext của Android chặn (đã thử trên máy ảo Android 16) — cờ cleartext ở bản debug chỉ để phòng thư viện dùng HTTP của hệ thống; iOS chưa kiểm được (không có Xcode). |
+| 30 | Hồ sơ an toàn (BRD FR-1.1, FR-1.3, NFR-10 — v2.6.0): tuổi 18–100; `goal = cut` bị từ chối khi BMI **chưa làm tròn** < 18,5 hoặc `pregnant_or_breastfeeding = true`; `pregnant_or_breastfeeding = true` chỉ hợp lệ khi `gender = female`. Kiểm bằng validator trên `CreatePlanDto` (`profile-safety.ts`, `dto/profile-safety.validator.ts`), nên áp cho cả 4 endpoint nhận hồ sơ. App khoá lựa chọn theo đúng các ngưỡng này trong `frontend_app/lib/models/profile_rules.dart` — đổi ngưỡng phải đổi cả hai phía và test hai phía; backend vẫn là nơi quyết định. | Quyết định D6 (A1–A3). Thử thật: BMI 16,4 + Giảm mỡ nhận plan 1.159 kcal; 14 tuổi + Giảm mỡ không có cảnh báo. Làm tròn BMI trước khi so thì 18,46 lọt thành 18,5. |
+| 31 | Độ khó động tác tối đa theo hồ sơ (`maxExerciseLevel()` trong `backend_api/src/plan/exercise-level.ts`: ≥ 60 tuổi, ≥ 45 tuổi + ít vận động, hoặc mang thai / cho con bú → mức 1; vận động nhiều + < 45 tuổi → mức 3; còn lại → mức 2) áp ở **mọi** đường ra động tác: thực đơn mẫu và kết quả Gemini (`capWorkoutLevel()` thay động tác vượt mức bằng động tác trong kho, không gọi lại Gemini), đổi bài (kho và kết quả Gemini), thay động tác khi feedback báo đau khớp. Luật trong prompt sinh từ chính kho động tác (`exerciseLevelRule()`). Mức lấy từ `data/swap-exercises.json`; động tác không có trong kho chỉ bị coi là vượt mức khi giới hạn là 1 và có tag `jumping`. | Quyết định D6-A4, Q2 giai đoạn 6. Thử thật: mọi hồ sơ nhận cùng buổi tập ở chế độ giả lập, người 65 tuổi ít vận động cũng có Jumping Jacks. Chỉ hạ mức ở một chỗ thì đổi bài hoặc feedback đưa động tác khó trở lại. |
+| 32 | Chip dị ứng / chấn thương của app (`frontend_app/lib/models/restriction_options.dart`) phải là nhãn bộ khớp từ khoá nhận ra. Backend xuất nhãn ra fixture `frontend_app/test/fixtures/restriction_labels.json` (`contract-fixtures.e2e-spec.ts`); `restriction_options_test.dart` kiểm mọi chip, tách theo cùng dấu phân cách như backend. Sửa `restriction-keywords.json` → `npm run fixtures:update` → chạy `flutter test`. App ghép lựa chọn bằng ", " (bộ khớp tách theo dấu phẩy). | Quyết định D5. Chip mà backend không nhận ra thì chế độ giả lập không lọc được, trong khi người dùng tưởng đã được lọc. |
 
 _File này được feature-explore và feature-build load khi phát hiện công việc liên quan tới ràng buộc._
```

### Task 3 — Wiki

```diff
--- a/docs/knowledge/wiki/flutter-ui.md
+++ b/docs/knowledge/wiki/flutter-ui.md
@@ -1,32 +1,50 @@
 ---
-last_updated: 2026-09-26
-tags: [flutter, frontend, hop-dong-api, cors]
+last_updated: 2026-09-27
+tags: [flutter, frontend, hop-dong-api, cors, onboarding]
 ---
 
 # Giao diện Flutter và tầng kết nối API
 
-App Flutter nằm trong `frontend_app/` (package `my_ai_app`). Từ giai đoạn 5, app có tầng kết nối backend: model đọc/ghi đúng hợp đồng BRD mục 6, `ApiClient` gọi mọi endpoint, hai provider lưu plan và phiên đăng nhập trên máy. Các màn hình **vẫn dùng dữ liệu mẫu** tới giai đoạn 6. Ràng buộc liên quan: [[critical-constraints]] #12, #15, #22, #24, #26–#29. Hợp đồng phía backend: [[plan-data-contract]], [[swap-and-feedback]], [[auth-and-history]].
+App Flutter nằm trong `frontend_app/` (package `my_ai_app`, tên hiển thị "SmartFit AI"). Giai đoạn 5 dựng tầng kết nối backend (model theo hợp đồng BRD 6, `ApiClient`, provider lưu trên máy); từ giai đoạn 6 mọi màn hình đọc/ghi qua provider — không còn dữ liệu viết cứng. Ràng buộc liên quan: [[critical-constraints]] #12, #15, #22, #24, #26–#32. Hợp đồng phía backend: [[plan-data-contract]], [[swap-and-feedback]], [[auth-and-history]].
 
 ## Cấu trúc `lib/`
 
 | Đường dẫn | Nội dung |
 |---|---|
-| `main.dart` | `main()` đọc `SharedPreferences`, tạo một `ApiClient` và hai provider; `SmartFitApp` bọc `MaterialApp` bằng `MultiProvider`; `MainShell` điều hướng bằng enum `AppScreen` + `setState` (không có router) |
+| `main.dart` | `main()` bật vẽ dưới thanh hệ thống (`edgeToEdge`), đọc `SharedPreferences`, tạo một `ApiClient` và ba provider; `SmartFitApp(auth:, plans:, grocery:)` bọc `MaterialApp` bằng `MultiProvider`; `MainShell` điều hướng Onboarding → màn chờ → màn chính 4 tab bằng enum `AppScreen` + `setState` (không có router) |
 | `config/api_config.dart` | `resolveApiBaseUrl()` — địa chỉ backend |
 | `models/api/` | Model viết tay theo BRD 6 (`MealPlan`, `Profile`, `AuthResult`, `FeedbackResult`…) và enum mã cố định (`codes.dart`) |
-| `models/meal_plan.dart` | View-model **cũ** (`DayPlan`, `MealItem`, `GroceryCategory`…) màn hình đang dùng với dữ liệu viết cứng — xoá ở giai đoạn 6 |
+| `models/profile_rules.dart` | Giới hạn và luật an toàn giống backend: tuổi 18–100, chiều cao, cân nặng, BMI < 18,5, mang thai → không Giảm mỡ (#30) |
+| `models/restriction_options.dart` | Danh sách chip dị ứng / chấn thương / bệnh nền, ghép và tách chuỗi gửi đi (D5, #32) |
+| `models/plan_schedule.dart` | Ngày bắt đầu của plan, hôm nay là ngày mấy (D6-B1) |
 | `services/` | `ApiClient`, `ApiException` |
-| `providers/` | `PlanProvider`, `AuthProvider` |
-| `screens/`, `widgets/` | Onboarding, Loading, Dashboard, Grocery; `macro_ring`, `feedback_bottom_sheet` |
+| `providers/` | `PlanProvider` (plan, hồ sơ của plan, lịch, bản nháp hồ sơ), `AuthProvider`, `GroceryProvider` (đã mua / đã có sẵn) |
+| `screens/` | `onboarding_screen.dart`, `loading_screen.dart`, `dashboard_screen.dart`, `grocery_screen.dart`, `profile_screen.dart` |
+| `widgets/` | `profile_form.dart` (form hồ sơ dùng chung cho Onboarding và tab Cá nhân), `macro_ring.dart` |
+| `theme/app_colors.dart` | Bảng màu dùng chung |
 
-Chữ trên giao diện và comment viết tiếng Việt.
+Ngoài `lib/`: `tool/make_icon.swift` + `tool/update_icons.sh` vẽ lại icon, `assets/icon/` là hai ảnh gốc. Chữ trên giao diện và comment viết tiếng Việt; số thập phân hiển thị kiểu Việt ("24,8").
 
 ## Luồng mở app
 
 1. `SharedPreferences.getInstance()` đọc hết dữ liệu đã lưu một lần, sau đó đọc đồng bộ — không cần màn chờ.
-2. `AuthProvider` nạp token và user; `PlanProvider` nạp hồ sơ và plan.
-3. `MainShell`: có plan → Dashboard, chưa có → Onboarding. Mở app không gọi mạng, nên có plan thì xem được khi không có mạng (NFR-2).
+2. `AuthProvider` nạp token và user; `PlanProvider` nạp hồ sơ, plan, lịch, bản nháp. Hồ sơ lưu từ trước mà nay bị luật v2.6.0 chặn (dưới 18 tuổi, thiếu cân + Giảm mỡ…) → bỏ plan, giữ hồ sơ để điền sẵn Onboarding (mọi request với hồ sơ đó đều bị 400).
+3. `MainShell`: có plan → màn chính, tab Kế hoạch mở đúng ngày hôm nay; chưa có → Onboarding. Mở app không gọi mạng, nên có plan thì xem được khi không có mạng (NFR-2). App quay lại foreground (ví dụ qua nửa đêm) → tính lại ngày.
 
+## Màn hình
+
+| Màn | Làm gì |
+|---|---|
+| Onboarding | 3 bước (D6-B2): cơ thể (giới tính, mang thai / cho con bú nếu là nữ, tuổi, chiều cao, cân nặng) → mức vận động và mục tiêu → hạn chế. Báo lỗi ngay dưới ô; nút tiếp tục khoá tới khi bước hợp lệ; "Giảm mỡ" bị khoá kèm lý do khi thiếu cân hoặc mang thai (#30). Nút Back của hệ thống quay lại bước trước. Nút luôn ở đáy nên màn hình nhỏ không đẩy nút xuống dưới mép |
+| Hạn chế (D5) | 3 công tắc "Tôi có …" (tắt = không có) → chip chọn nhiều + "Khác" tự ghi; tối đa 300 ký tự mỗi mục; dòng khuyến cáo y tế (NFR-9) |
+| Màn chờ | Gọi `PlanProvider.generate()`; sau 15 s đổi câu "có thể mất tới 40 giây". Lỗi → câu của `ApiException` + "Thử lại", "Sửa hồ sơ", và "Về kế hoạch đang có" nếu đã có plan |
+| Kế hoạch | 3 tab ngày, mở sẵn hôm nay; 3 bữa (calo, đạm, tinh bột, béo, nguyên liệu); tổng ngày so với `daily_target` bằng `MacroRing` (phần trăm thật, có thể > 100%); buổi tập; `warnings`; nhãn "Thực đơn mẫu" khi `source = sample`. Dải nhắc: hồ sơ đã sửa, kế hoạch đã hết (> 3 ngày), chưa tới ngày bắt đầu |
+| Đổi món / đổi bài | Gọi API (FR-4.1, FR-4.2 — chuyển từ giai đoạn 7 lên); khoá mọi nút khi `busy`, vòng xoay đúng nút đang chờ; 409 → câu của server + nút "Tạo mới"; 422 và lỗi khác → câu của server |
+| Đi chợ | Dựng từ `grocery_list` (#7), tên nhóm theo BRD FR-3.1; tích "đã mua"; "đã có sẵn" ẩn khỏi danh sách cần mua, "Hiện lại" → "Cần mua"; tìm kiếm, lọc nhóm. Không có nút thêm nguyên liệu |
+| Cá nhân | Tóm tắt hồ sơ (BMI, calo mục tiêu); sửa bằng cùng form, lưu thành **bản nháp** — plan đang mở vẫn dùng hồ sơ cũ nên đổi món không bị 409; dải "Tạo kế hoạch mới" dùng bản nháp |
+| Lịch sử | Chỗ giữ — đăng nhập và lịch sử ở giai đoạn 8 |
+| Feedback cuối ngày | Chưa có nút — làm lại theo D2 ở giai đoạn 7 |
+
 ## Địa chỉ backend
 
 Đặt bằng `--dart-define=API_BASE_URL=<địa chỉ>` khi `flutter run` / `flutter build`. Không đặt thì:
@@ -60,33 +78,36 @@
 
 ## Model và vòng tròn JSON
 
-Đổi món, đổi bài, feedback gửi lại **nguyên** plan và server kiểm từng ID, con số (#24). Nên `MealPlan.fromJson(json).toJson()` phải bằng đúng `json`: đọc số qua `num` để giữ `22.5` là `22.5` và `640` là `640`. Thiếu trường, sai kiểu, mã lạ → `FormatException` nêu tên trường (`json_read.dart`), không đoán (#26).
+Đổi món, đổi bài, feedback gửi lại **nguyên** plan và server kiểm từng ID, con số (#24). Nên `MealPlan.fromJson(json).toJson()` phải bằng đúng `json`: đọc số qua `num` để giữ `22.5` là `22.5` và `640` là `640`. Thiếu trường, sai kiểu, mã lạ → `FormatException` nêu tên trường (`json_read.dart`), không đoán (#26). `Profile` có `pregnantOrBreastfeeding` (JSON `pregnant_or_breastfeeding`, luôn gửi đi; hồ sơ lưu trước v2.6.0 thiếu trường này thì đọc thành `false`).
 
 ## Fixture hợp đồng
 
-`backend_api/test/contract-fixtures.e2e-spec.ts` gọi thật 14 tình huống (hồ sơ, `/health`, đăng nhập, tạo plan, lịch sử, đổi món, đổi bài, hai kiểu feedback, lỗi 400/401/404/409/422) và so với file JSON trong `frontend_app/test/fixtures/`. UUID, token, thời điểm được thay bằng giá trị cố định; `RandomSource` cố định nên đổi món luôn ra cùng món. App dùng chính các file này cho test vòng tròn, `ApiClient`, provider và widget test.
+`backend_api/test/contract-fixtures.e2e-spec.ts` gọi thật 14 tình huống (hồ sơ, `/health`, đăng nhập, tạo plan, lịch sử, đổi món, đổi bài, hai kiểu feedback, lỗi 400/401/404/409/422) và so với file JSON trong `frontend_app/test/fixtures/`, cộng `restriction_labels.json` — nhãn dị ứng / chấn thương bộ khớp từ khoá nhận ra (#32). UUID, token, thời điểm được thay bằng giá trị cố định; `RandomSource` cố định nên đổi món luôn ra cùng món. App dùng chính các file này cho test vòng tròn, `ApiClient`, provider, màn hình.
 
-Khi đổi hợp đồng BRD 6 ở backend:
+Khi đổi hợp đồng BRD 6 hoặc file từ khoá ở backend:
 
 1. `cd backend_api && npm run fixtures:update` — ghi lại fixture;
-2. sửa model trong `frontend_app/lib/models/api/` tới khi `flutter test` xanh;
-3. commit fixture và model cùng nhau.
+2. sửa model trong `frontend_app/lib/models/api/` (hoặc chip trong `restriction_options.dart`) tới khi `flutter test` xanh;
+3. commit fixture và phần sửa app cùng nhau.
 
-Quên bước 1 → test backend đỏ ("… đã cũ — chạy npm run fixtures:update"); quên bước 2 → `test/models/contract_test.dart` đỏ.
+Quên bước 1 → test backend đỏ ("… đã cũ — chạy npm run fixtures:update"); quên bước 2 → `contract_test.dart` hoặc `restriction_options_test.dart` đỏ.
 
 ## Lưu trên máy
 
 | Khoá `shared_preferences` | Provider | Nội dung |
 |---|---|---|
-| `smartfit.profile.v1` | `PlanProvider` | hồ sơ, kể cả `restrictions` |
+| `smartfit.profile.v1` | `PlanProvider` | hồ sơ đã tạo plan hiện tại, kể cả `restrictions` và cờ mang thai |
 | `smartfit.plan.v1` | `PlanProvider` | plan hiện tại, đúng JSON server trả |
+| `smartfit.plan_schedule.v1` | `PlanProvider` | `plan_id` + ngày bắt đầu (yyyy-mm-dd): tạo mới → hôm nay; feedback ngày 3 → ngày mai; đổi món/bài giữ nguyên |
+| `smartfit.profile_draft.v1` | `PlanProvider` | hồ sơ đã sửa ở tab Cá nhân mà chưa tạo plan mới; giống hồ sơ của plan thì xoá |
+| `smartfit.grocery.v1` | `GroceryProvider` | `plan_id` + món đã mua + món đã có sẵn; khoá mỗi dòng = nhóm + tên + lượng (lượng đổi sau khi đổi món → dòng đó bỏ tích); plan mới → xoá |
 | `smartfit.access_token` | `AuthProvider` | JWT của backend (7 ngày) |
 | `smartfit.user.v1` | `AuthProvider` | `id`, `email`, `name` |
 
 - Số phiên bản trong khoá: đổi định dạng theo cách bản cũ không đọc được thì tăng số.
-- Bản lưu hỏng: plan hỏng → bỏ plan, giữ hồ sơ; hồ sơ hỏng → bỏ cả plan (không có hồ sơ thì không đổi món/feedback được); token không có user → bỏ cả hai.
+- Bản lưu hỏng: plan hỏng → bỏ plan, giữ hồ sơ; hồ sơ hỏng → bỏ cả plan (không có hồ sơ thì không đổi món/feedback được); token không có user → bỏ cả hai; lịch thiếu hoặc của plan khác → coi như bắt đầu hôm nay.
 - Trên web, `shared_preferences` là `localStorage` của trình duyệt: dữ liệu sức khoẻ và token nằm trong trình duyệt. BRD chấp nhận việc lưu trên máy người dùng (NFR-7, D4); backend vẫn không lưu `restrictions` (#12).
-- `PlanProvider.busy` = đang chờ server; gọi thêm khi đang bận bị bỏ qua, không ném lỗi.
+- `PlanProvider.busy` = đang chờ server; gọi thêm khi đang bận bị bỏ qua, không ném lỗi. `PlanProvider` nhận đồng hồ (`now:`) để test đổi ngày.
 
 ## CORS (bản web)
 
@@ -105,23 +126,32 @@
 
 Android: `compileSdk = 36` trong `android/app/build.gradle.kts` — plugin Android của `shared_preferences` đòi biên dịch với API ≥ 36; `targetSdk` vẫn 34. Trước đó file này ghim `compileSdk = 34` và APK không build được. CI chỉ chạy `analyze` + `test` nên không bắt được lỗi kiểu này — đổi package có plugin thì build thử `flutter build apk --debug`.
 
-Đã kiểm: APK debug và release build được; manifest đã gộp của bản debug có `INTERNET` + `usesCleartextTraffic`, bản release có `INTERNET`, không có cleartext. Bản web build và chạy được. Chạy trên máy ảo Android 16 (Pixel 8, API 36, 2026-09-26): `integration_test/backend_smoke_test.dart` gọi backend thật qua `10.0.2.2` — tạo plan, lịch sử, đổi món, đổi bài, feedback, lỗi 409, lưu `shared_preferences` thật — đều xanh; plan đã lưu → mở thẳng Dashboard cả khi backend tắt; plan hỏng → Onboarding, không crash, giữ hồ sơ. Chưa build iOS/macOS (máy không có Xcode).
+## Tên app, icon, màn khởi động, thanh hệ thống (PLAN 6.8)
 
+- Tên "SmartFit AI": `android:label`, `CFBundleDisplayName`, `web/index.html`, `web/manifest.json` (màu thương hiệu `#059669`).
+- Icon: nền xanh, chữ "S" trắng bo tròn và chiếc lá. `tool/update_icons.sh` (macOS, cần `swift` và `sips` có sẵn) vẽ hai ảnh gốc bằng `tool/make_icon.swift` rồi chép đủ kích thước cho Android (icon vuông + icon thích ứng `mipmap-anydpi-v26`), iOS, macOS, web. Kết quả tất định — chạy lại ra đúng từng byte. Ảnh iOS không có kênh trong suốt (App Store bắt buộc).
+- Màn khởi động: Android 12+ vẽ lớp trước của icon thích ứng (hình trắng) trên `windowSplashScreenBackground` = xanh thương hiệu (`values-v31/styles.xml`) — để nền mặc định trắng thì hình biến mất; Android cũ hơn hiện icon giữa nền trắng (`launch_background.xml`).
+- Thanh trạng thái / điều hướng: theme `Theme.Light.NoTitleBar` mặc định tô đen thanh hệ thống và bỏ qua màu Flutter đặt → các theme bật `windowDrawsSystemBarBackgrounds`, nền trong suốt; `main()` bật `SystemUiMode.edgeToEdge`, màn hình dùng `SafeArea`.
+
+Đã kiểm trên máy ảo Android 16 (Pixel 8, API 36): icon trên launcher, màn khởi động, thanh trạng thái sáng, luồng Onboarding → Dashboard → Đi chợ → Cá nhân, cỡ chữ 130%. Chưa build iOS/macOS (máy không có Xcode).
+
 ## Test
 
-- `cd frontend_app && flutter test` — 44 test, không cần backend chạy:
-  - `test/models/contract_test.dart` — vòng tròn fixture, kiểu số, JSON sai hợp đồng;
+- `cd frontend_app && flutter test` — 89 test, không cần backend chạy:
+  - `test/models/` — vòng tròn fixture (`contract_test.dart`), luật hồ sơ, chip hạn chế so với `restriction_labels.json`, lịch ngày;
   - `test/services/api_client_test.dart` — `MockClient` của `package:http/testing`;
-  - `test/providers/` — `SharedPreferences.setMockInitialValues()`;
-  - `test/widget_test.dart` — màn đầu theo dữ liệu đã lưu;
-  - `test/fake_backend.dart` — backend giả trả fixture theo đường dẫn, ghi lại request.
-- `integration_test/backend_smoke_test.dart` — chạy **tay** trên máy ảo/điện thoại khi backend đang chạy ở chế độ giả lập: `flutter test integration_test -d emulator-5554` (điện thoại thật thêm `--dart-define=API_BASE_URL=http://<IP LAN>:3000`). Gọi backend thật qua mạng của thiết bị, dùng `shared_preferences` thật, xoá dữ liệu đã lưu của app trên thiết bị đó. Tự dừng nếu `/health` báo `gemini: configured` (không tốn hạn mức Gemini — #17) hoặc không phải `auth_mode: mock`. `flutter test` (và CI) chỉ chạy thư mục `test/`, không chạy test này.
+  - `test/providers/` — `SharedPreferences.setMockInitialValues()`, đồng hồ giả;
+  - `test/screens/` — từng màn hình; `test/widget_test.dart` — luồng của cả app;
+  - `test/app_harness.dart` — dựng app/màn hình cỡ điện thoại (411×914 dp) với backend giả, dữ liệu đã lưu, đồng hồ giả; `fillOnboarding()`, `scrollTo()` (danh sách chỉ dựng phần đang hiện — cuộn rồi `ensureVisible` trước khi bấm);
+  - `test/fake_backend.dart` — backend giả trả fixture theo đường dẫn, `responses` thay JSON cho một đường dẫn, ghi lại request.
+- `integration_test/backend_smoke_test.dart` — chạy **tay** trên máy ảo/điện thoại khi backend đang chạy ở chế độ giả lập: `flutter test integration_test -d emulator-5554` (điện thoại thật thêm `--dart-define=API_BASE_URL=http://<IP LAN>:3000`). Gọi backend thật qua mạng của thiết bị, dùng `shared_preferences` thật, xoá dữ liệu đã lưu của app trên thiết bị đó; có một test thao tác giao diện (điền Onboarding → plan thật → Dashboard → đổi món). Tự dừng nếu `/health` báo `gemini: configured` (không tốn hạn mức Gemini — #17) hoặc không phải `auth_mode: mock`. `flutter test` (và CI) chỉ chạy thư mục `test/`.
 - Chưa có máy ảo: Android Studio → Device Manager → tạo thiết bị (ví dụ Pixel 8, API 36).
+- `Container` có màu nền bọc `ListTile`/`SwitchListTile`/`ExpansionTile` → Flutter báo lỗi ở bản debug (hiệu ứng bấm bị che) — dùng `Material` có `shape` thay cho `Container`.
 - CI: `.github/workflows/frontend.yml` chạy `flutter analyze` + `flutter test` với Flutter 3.47.5 khi `frontend_app/**` đổi.
-- Code có sẵn chưa theo `dart format` ở khổ dòng nào, nên CI không kiểm format; sửa file cũ thì không format lại cả file (sẽ gộp dòng ở các widget không liên quan).
+- Code viết từ giai đoạn 6 theo `dart format --line-length 120`; file cũ chưa theo định dạng nào thì không format lại cả file (sẽ gộp dòng ở các widget không liên quan). CI không kiểm format.
 
 ## Việc của giai đoạn sau
 
-- **6:** màn hình đọc/ghi qua `PlanProvider`, `AuthProvider` và model `lib/models/api/`, xoá view-model cũ; Loading gọi `PlanProvider.generate()`; lỗi hiện `ApiException.message`; widget test dùng `FakeBackend`; chạy thử trên máy ảo Android.
-- **7:** nút đổi món, đổi bài, bảng feedback; 409 → gợi ý tạo plan mới; `FeedbackResult.safetyWarning` → cảnh báo nổi bật.
-- **8:** Google Sign-In → `AuthProvider.signIn(idToken)`.
+- **7:** bảng feedback cuối ngày theo D2 (3 câu hỏi, chọn nhiều tình trạng cơ thể), khoá sau khi gửi cho một ngày; `FeedbackResult.safetyWarning` → cảnh báo nổi bật. `PlanProvider.submitFeedback()` đã có (plan ngày 3 bắt đầu từ ngày mai).
+- **8:** Google Sign-In → `AuthProvider.signIn(idToken)`; tab Lịch sử.
+- Thực đơn mẫu lệch macro so với mục tiêu (ví dụ tinh bột ~120%, chất béo ~70%) vì chỉ được nhân khẩu phần theo calo; backend không kiểm tỉ lệ macro — Dashboard hiện đúng phần trăm thật. Ghi ở mục "Để sau" của PLAN.
```

```diff
--- a/docs/knowledge/wiki/plan-data-contract.md
+++ b/docs/knowledge/wiki/plan-data-contract.md
@@ -1,5 +1,5 @@
 ---
-last_updated: 2026-09-24
+last_updated: 2026-09-27
 tags: [hop-dong-api, backend, dinh-duong]
 ---
 
@@ -9,13 +9,26 @@
 
 ## Luồng `POST /api/v1/generate-plan`
 
-1. `CreatePlanDto` (`dto/create-plan.dto.ts`) validate request. `restrictions` là ba chuỗi tự do tối đa 300 ký tự, mặc định rỗng.
+1. `CreatePlanDto` (`dto/create-plan.dto.ts`) validate request. `restrictions` là ba chuỗi tự do tối đa 300 ký tự, mặc định rỗng. Từ v2.6.0: tuổi 18–100, `pregnant_or_breastfeeding` (chỉ nữ), và `goal = cut` bị từ chối khi thiếu cân hoặc mang thai (mục "Hồ sơ an toàn" dưới).
 2. `computeDailyTarget()` (`daily-target.ts`) → BMI, BMR, TDEE, mục tiêu calo có sàn BMR, macro 25/45/30.
 3. Có `GEMINI_API_KEY` → `GeminiService.generatePlanContent()` trả JSON thô (chỉ `days`). Không có → bỏ qua bước này.
-4. `parsePlanContent(raw, target)` (`plan-validation.ts`) → class-validator + `findPlanViolations()`; rồi `findRestrictionViolations()` (có nguyên liệu dị ứng đã nhận ra → sai hợp đồng). Sai → `generateWithRetry()` gọi lại 1 lần (trừ khi hết giờ) → thực đơn mẫu `data/sample-plan.json`: lọc theo hạn chế nhận ra (`filterPlanByRestrictions()`), nhân khẩu phần từng ngày cho khớp mục tiêu (`scaleMealsToTotal()`), rồi qua đúng bước kiểm tra này.
+4. `parsePlanContent(raw, target)` (`plan-validation.ts`) → class-validator + `findPlanViolations()`; rồi `findRestrictionViolations()` (có nguyên liệu dị ứng đã nhận ra → sai hợp đồng). Sai → `generateWithRetry()` gọi lại 1 lần (trừ khi hết giờ) → thực đơn mẫu `data/sample-plan.json`: lọc theo hạn chế nhận ra (`filterPlanByRestrictions()`), nhân khẩu phần từng ngày cho khớp mục tiêu (`scaleMealsToTotal()`), rồi qua đúng bước kiểm tra này. Cuối cùng hạ mức động tác theo hồ sơ (`capWorkoutLevel()`) — cho cả kết quả Gemini (không gọi lại) lẫn thực đơn mẫu.
 5. `assemblePlan()` (`plan-assembly.ts`) → `plan_id` (hoặc giữ `plan_id` cũ khi đổi món/feedback), ID món và động tác, sắp bữa, `buildGroceryList()`.
-6. `warnings` (`plan-warnings.ts`): sàn BMR, khuyến cáo y tế, thực đơn mẫu chỉ lọc theo từ khoá, hạn chế chưa nhận ra hết. Không câu nào nhắc lại chữ người dùng nhập.
+6. `warnings` (`plan-warnings.ts`): sàn BMR, khuyến cáo y tế, mang thai / cho con bú, thực đơn mẫu chỉ lọc theo từ khoá, hạn chế chưa nhận ra hết. Không câu nào nhắc lại chữ người dùng nhập.
 
+## Hồ sơ an toàn và mức động tác (BRD v2.6.0)
+
+| Luật | Code |
+|---|---|
+| Tuổi 18–100 | `MIN_AGE`, `MAX_AGE` trong `profile-safety.ts`, dùng ở `@Min`/`@Max` của `CreatePlanDto` |
+| `goal = cut` bị từ chối khi BMI **chưa làm tròn** < 18,5 hoặc `pregnant_or_breastfeeding` | `cutBlockReason()` (`profile-safety.ts`) qua `SafeGoalConstraint` (`dto/profile-safety.validator.ts`) — 400 kèm câu tiếng Việt |
+| `pregnant_or_breastfeeding = true` chỉ khi `gender = female` | `PregnancyNeedsFemaleConstraint` |
+| Mức động tác tối đa: ≥ 60 tuổi, ≥ 45 + ít vận động, mang thai → 1; vận động nhiều + < 45 → 3; còn lại → 2 | `maxExerciseLevel()` (`exercise-level.ts`) |
+
+Validator nằm trên `CreatePlanDto` nên áp cho cả 4 endpoint nhận hồ sơ (`generate-plan` và ba endpoint của [[swap-and-feedback]]). App khoá lựa chọn theo đúng các ngưỡng này (`frontend_app/lib/models/profile_rules.dart`, [[flutter-ui]]). Ràng buộc: [[critical-constraints]] #30, #31.
+
+`capWorkoutLevel(plan, maxLevel, avoidTags)` thay động tác vượt mức bằng động tác trong kho cùng nhóm cơ, mức ≤ giới hạn, không vướng chấn thương, giữ số hiệp — tất định. Động tác không có trong kho (Gemini tự đặt) chỉ bị coi là vượt mức khi giới hạn là 1 và có tag `jumping`. Nhóm cơ nào cũng có động tác mức 1 không tag (`exercise-level.spec.ts` kiểm), nên hạ mức không làm rỗng buổi tập. Prompt ghi luật bằng `exerciseLevelRule()`, dựng từ chính kho.
+
 ## Hai lớp DTO
 
 | File | Dùng cho |
```

```diff
--- a/docs/knowledge/wiki/swap-and-feedback.md
+++ b/docs/knowledge/wiki/swap-and-feedback.md
@@ -1,5 +1,5 @@
 ---
-last_updated: 2026-09-24
+last_updated: 2026-09-27
 tags: [doi-mon, doi-bai-tap, feedback, di-ung, kho-soan-san]
 ---
 
@@ -33,8 +33,9 @@
   - `sets` ≤ cũ;
   - `tags` ⊆ tag cũ;
   - không vướng chấn thương;
-  - không trùng động tác trong buổi.
-- **Kho:** `data/swap-exercises.json` (39 động tác, `level` 1–3), lấy mức thấp hơn động tác cũ, gần mức cũ nhất. Động tác không có trong kho coi như khó nhất.
+  - không trùng động tác trong buổi;
+  - không vượt mức khó cho phép của hồ sơ (`maxExerciseLevel()`, v2.6.0).
+- **Kho:** `data/swap-exercises.json` (39 động tác, `level` 1–3), lấy mức thấp hơn động tác cũ và không quá mức của hồ sơ, gần mức cũ nhất. Động tác không có trong kho coi như khó nhất.
 - **Đã nhẹ nhất** → 422.
 
 ## Feedback (`FeedbackService`, `workout-rules.ts`)
@@ -42,7 +43,7 @@
 | Điều kiện | Buổi tập ngày kế tiếp |
 |---|---|
 | `danger_sign` | Ngày nghỉ (`REST_WORKOUT`), bỏ qua mọi quy tắc khác kể cả ăn uống; `safety_warning` (#14) |
-| `joint_pain` | Thay động tác `jumping`/`kneeling` bằng động tác cùng nhóm cơ trong kho |
+| `joint_pain` | Thay động tác `jumping`/`kneeling` bằng động tác cùng nhóm cơ trong kho, mức không quá mức của hồ sơ |
 | `hard` hoặc `fatigued` | −1 hiệp mỗi động tác, thời lượng ×0,75 (≥ 10 phút) |
 | `sore` | −1 hiệp cho nhóm cơ vừa tập (không cộng dồn), thêm giãn cơ |
 | `easy`, chỉ `normal` | +1 hiệp (≤ 6) |
```

```diff
--- a/docs/knowledge/wiki/wiki-triggers.md
+++ b/docs/knowledge/wiki/wiki-triggers.md
@@ -1,6 +1,6 @@
 ---
 type: meta
-last_updated: 2026-09-26
+last_updated: 2026-09-27
 ---
 
 # Wiki Triggers
@@ -18,10 +18,11 @@
 | `backend_api/src/plan/gemini.service.ts`, `backend_api/test/fake-gemini-server.ts`, `ai_workspace/**` | `gemini-integration.md` |
 | `backend_api/src/plan/dto/**`, `backend_api/src/plan/enums/**`, `backend_api/src/plan/data/**`, `backend_api/src/plan/plan-validation.ts`, `backend_api/src/plan/plan-assembly.ts`, `backend_api/src/plan/daily-target.ts`, `backend_api/src/plan/plan-warnings.ts`, `backend_api/src/plan/text.util.ts`, `backend_api/src/plan/plan.service.ts` | `plan-data-contract.md` |
 | `backend_api/src/auth/**`, `backend_api/src/database/**`, `backend_api/src/history/**`, `backend_api/test/test-app.ts`, `backend_api/test/memory-data-source.ts`, `backend_api/scripts/smoke-test.mjs` | `auth-and-history.md` |
-| `frontend_app/lib/screens/**`, `frontend_app/lib/widgets/**`, `frontend_app/lib/main.dart` | `flutter-ui.md` |
+| `frontend_app/lib/screens/**`, `frontend_app/lib/widgets/**`, `frontend_app/lib/theme/**`, `frontend_app/lib/main.dart` | `flutter-ui.md` |
+| `backend_api/src/plan/profile-safety.ts`, `backend_api/src/plan/dto/profile-safety.validator.ts`, `backend_api/src/plan/exercise-level.ts` | `plan-data-contract.md`, `swap-and-feedback.md`, `critical-constraints.md` (#30, #31) |
 | `frontend_app/lib/models/**`, `frontend_app/lib/services/**`, `frontend_app/lib/providers/**`, `frontend_app/lib/config/**`, `frontend_app/test/**` | `flutter-ui.md`, `critical-constraints.md` (#26, #28) |
 | `backend_api/src/cors-options.ts`, `backend_api/test/cors.e2e-spec.ts`, `backend_api/test/contract-fixtures.e2e-spec.ts` | `flutter-ui.md`, `critical-constraints.md` (#26, #27) |
-| `frontend_app/pubspec.yaml`, `frontend_app/android/**/AndroidManifest.xml`, `frontend_app/ios/Runner/Info.plist`, `frontend_app/macos/Runner/*.entitlements`, `.github/workflows/frontend.yml` | `flutter-ui.md`, `critical-constraints.md` (#29) |
+| `frontend_app/pubspec.yaml`, `frontend_app/android/**/AndroidManifest.xml`, `frontend_app/ios/Runner/Info.plist`, `frontend_app/macos/Runner/*.entitlements`, `.github/workflows/frontend.yml`, `frontend_app/android/app/src/main/res/**`, `frontend_app/web/**`, `frontend_app/tool/**`, `frontend_app/assets/icon/**` | `flutter-ui.md`, `critical-constraints.md` (#29) |
 | `BRD.md` | `product-spec.md` *(chưa có — đọc thẳng BRD.md)* |
 
 Trigger bổ sung (bất kỳ thay đổi nào sau đây → bắt buộc cập nhật khi commit):
@@ -42,6 +43,8 @@
 | đăng nhập / auth / JWT / token / Google Sign-In / tài khoản / lịch sử / history / SQLite / TypeORM / migration / database / guard | `auth-and-history.md` |
 | screen / widget / onboarding / dashboard / giao diện đi chợ / Flutter | `flutter-ui.md` |
 | CORS / API_BASE_URL / dart-define / ApiClient / provider / shared_preferences / fixture hợp đồng / quyền mạng | `flutter-ui.md`, `critical-constraints.md` |
+| thiếu cân / BMI / mang thai / cho con bú / tuổi tối thiểu / độ khó động tác / mức động tác | `plan-data-contract.md`, `critical-constraints.md` |
+| chip hạn chế / ngày trong plan / bản nháp hồ sơ / icon / tên app / màn khởi động / thanh trạng thái | `flutter-ui.md`, `critical-constraints.md` |
 | BRD / roadmap / rubric / phạm vi / FR- / NFR- | `product-spec.md` *(chưa có — đọc thẳng BRD.md)* |
 | tài liệu tham khảo / thư viện / SDK / phiên bản / deprecated | `reference-materials.md` |
```

```diff
--- a/docs/knowledge/wiki/INDEX.md
+++ b/docs/knowledge/wiki/INDEX.md
@@ -1,6 +1,6 @@
 # Mục lục Knowledge Base
 
-_Cập nhật lần cuối: 2026-09-26_
+_Cập nhật lần cuối: 2026-09-27_
 
 ## Danh sách chủ đề
 
@@ -13,7 +13,7 @@
 | [[gemini-integration]]      | Hành vi thật của SDK Gemini (hết giờ, lỗi, không tự gọi lại), cách test không cần khoá |
 | [[auth-and-history]]        | Đăng nhập Google/giả lập, JWT, guard, SQLite + migration, lịch sử kế hoạch; hành vi thư viện đã kiểm chứng |
 | [[swap-and-feedback]]       | Đổi món, đổi bài tập, feedback cuối ngày; bộ khớp từ khoá dị ứng/chấn thương; kho món và động tác soạn sẵn |
-| [[flutter-ui]]              | App Flutter: model theo hợp đồng, ApiClient, provider, lưu trên máy, fixture hợp đồng, CORS, quyền mạng |
+| [[flutter-ui]]              | App Flutter: Onboarding 3 bước, kế hoạch 3 ngày, đi chợ, hồ sơ; ApiClient, provider, lưu trên máy, fixture hợp đồng, CORS, quyền mạng, icon |
 | [[log]]                     | Nhật ký thay đổi wiki theo thời gian                                   |
 
 ## Tra cứu nhanh
```

```diff
--- a/docs/knowledge/wiki/log.md
+++ b/docs/knowledge/wiki/log.md
@@ -19,3 +19,4 @@
 2026-09-26 — Giai đoạn 5 (PLAN.md): thêm bài [[flutter-ui]]; thêm ràng buộc #26 (model Dart đi vòng tròn + fixture hợp đồng), #27 (CORS qua `CORS_ORIGINS`), #28 (app gọi backend qua `ApiClient`, không log body, lưu trên máy), #29 (quyền mạng theo nền tảng); #12 trỏ sang #28; wiki-triggers không còn trỏ tới `flutter-ui.md` như bài chưa có
 2026-09-26 — Kiểm lại giai đoạn 5: [[flutter-ui]] thêm cấu hình build Android (`compileSdk = 36`, trước đó APK không build được sau khi thêm `shared_preferences`) và kết quả kiểm manifest đã gộp của bản debug/release
 2026-09-26 — Chạy trên máy ảo Android 16: [[flutter-ui]] thêm integration test gọi backend thật (chạy tay) và kết quả; sửa lý do của #29 — HTTP của Dart không bị chính sách cleartext của Android chặn
+2026-09-27 — Giai đoạn 6 (PLAN.md): viết lại [[flutter-ui]] (màn hình nối provider, Onboarding 3 bước, khoá lưu mới, icon và màn khởi động, 89 test); [[plan-data-contract]] thêm mục "Hồ sơ an toàn và mức động tác"; [[swap-and-feedback]] giới hạn mức khi đổi bài và khi đau khớp; thêm ràng buộc #30 (hồ sơ an toàn), #31 (mức động tác ở mọi đường), #32 (chip hạn chế ⊆ nhãn backend); #12 thêm cờ mang thai; wiki-triggers có đường dẫn và từ khoá mới
```

### Task 4 — CLAUDE.md, README, PLAN

````diff
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -20,11 +20,11 @@
 
 This is a monorepo with three components:
 
-- **`frontend_app/`** — Flutter app. Since phase 5 it has the API layer (`http`, `provider`, `shared_preferences`; models in `lib/models/api/`, `ApiClient` in `lib/services/`, `PlanProvider`/`AuthProvider` in `lib/providers/`), but the **screens still render hardcoded mock data** through the old view-models in `lib/models/meal_plan.dart` — wiring them to the providers is phase 6. Screen navigation is driven by a local enum (`AppScreen` in `lib/main.dart`), not a router package.
+- **`frontend_app/`** — Flutter app, wired to `backend_api` since phase 6: 3-step onboarding, loading, the 3-day plan (meal/exercise swap via the API), grocery checklist and profile tab all read and write through the providers; no hardcoded data left. Screen navigation is driven by a local enum (`AppScreen` in `lib/main.dart`), not a router package. The end-of-day feedback sheet (phase 7) and login/history (phase 8) are not built yet.
 - **`backend_api/`** — NestJS (TypeScript) service, scaffolded and working: `GET /health` and `POST /api/v1/generate-plan` (see Backend architecture below). Request/response DTOs validated with `class-validator`; Gemini call is wired but falls back to the bundled 3-day `sample-plan.json` when `GEMINI_API_KEY` is unset, Gemini times out, or its output fails contract validation (BRD NFR-2, NFR-4) — the response's `source` field (`gemini` / `sample`) says which one was used. Accounts (Google Sign-In, mock mode by default), `DELETE /api/v1/me`, and plan history on SQLite/TypeORM are built (BRD FR-6, FR-7; PLAN.md phase 3). Meal/exercise swap and end-of-day feedback (BRD §6.4) are built too (PLAN.md phase 4): stateless endpoints that take `{ profile, plan, … }` and return the whole new plan.
 - **`ai_workspace/`** — standalone Node/TypeScript project (own `package.json`, unrelated to `backend_api/`'s dependencies) for iterating on the Gemini prompt via `npm run experiment` before copying the finalized prompt into `backend_api/src/plan/gemini.service.ts`.
 
-When asked to "connect the app to the backend," the plumbing exists (phase 5): screens should read and write through `PlanProvider`/`AuthProvider` (never call `ApiClient` or `http` directly) and show `ApiException.message` on failure. The web build needs the backend's CORS (`CORS_ORIGINS`, see Backend architecture).
+Screens read and write through `PlanProvider`/`AuthProvider`/`GroceryProvider` (never call `ApiClient` or `http` directly) and show `ApiException.message` on failure. The web build needs the backend's CORS (`CORS_ORIGINS`, see Backend architecture).
 
 ## Commands
 
@@ -38,6 +38,7 @@
 flutter analyze                 # static analysis (flutter_lints, default rule set)
 flutter test                    # run all tests (no backend needed; fixtures in test/fixtures/)
 flutter test test/services/api_client_test.dart   # run a single test file
+tool/update_icons.sh           # macOS only: redraw the app icon and copy every size (Android, iOS, macOS, web)
 flutter test integration_test -d emulator-5554   # manual only: real backend_api from the device (mock mode, no GEMINI_API_KEY); wipes the app's saved data there; not in CI
 ```
 
@@ -74,15 +75,15 @@
 
 - `src/app.controller.ts` / `app.service.ts` — `GET /health`, which also reports whether Gemini is configured (`gemini: "configured" | "fallback"`) and the login mode (`auth_mode: "mock" | "google"`) — the quickest way to confirm a key was picked up. `.env` is read once at boot; `start:dev` watch mode does not restart on `.env` edits.
 - `src/plan/` — `POST /api/v1/generate-plan`. The contract is BRD.md §6 (v2.5.0); the wiki article `docs/knowledge/wiki/plan-data-contract.md` maps it to code. Flow:
-  1. `dto/create-plan.dto.ts` validates the request. `dto/restrictions.dto.ts` holds three free-text fields (`allergies`, `injuries`, `health_conditions`, ≤300 chars, default `''`) — sensitive health data: never persist or log them (BRD NFR-7).
+  1. `dto/create-plan.dto.ts` validates the request. `dto/restrictions.dto.ts` holds three free-text fields (`allergies`, `injuries`, `health_conditions`, ≤300 chars, default `''`) — sensitive health data: never persist or log them (BRD NFR-7). Since BRD v2.6.0 the profile also has `pregnant_or_breastfeeding` (female only, same privacy rules), age is 18–100, and `goal = cut` is rejected when the **unrounded** BMI < 18.5 or pregnant/breastfeeding — validators in `dto/profile-safety.validator.ts` using `profile-safety.ts`, so every endpoint that takes a profile enforces it. The app locks the same choices with the same thresholds (`lib/models/profile_rules.dart`).
   2. `daily-target.ts` — pure `computeDailyTarget()`: BMI, BMR (Mifflin-St Jeor), TDEE, target = `max(TDEE + goal adjustment, BMR)` (cut −300, bulk +250), macros 25/45/30. Returns `flooredToBmr` so the service can add a warning.
   3. `gemini.service.ts` — `@google/genai` (`client.models.generateContent()`, result via the `response.text` property; the old `@google/generative-ai` SDK is deprecated — don't reintroduce it). `buildPlanPrompt()` puts user text inside a `<du_lieu_nguoi_dung>` block after `sanitizeUserText()`, spells out what the backend will reject (`ingredientAvoidRule()` / `exerciseAvoidRule()` from the keyword matcher — without it Gemini read "seafood" more narrowly than the checker and served freshwater fish), and reads the allowed codes and calorie bounds from the enums/`mealCalorieBounds()`. Defaults come from measuring the real API (`npm run measure:gemini`, 2026-09-24): model `gemini-3.5-flash` (3.8 kept returning 503), `GEMINI_THINKING=off` (plans take 8–13 s instead of 37–42 s with the model's own thinking), `GEMINI_TIMEOUT_MS=20000` per call and `GEMINI_TOTAL_TIMEOUT_MS=40000` across the retry — `generateWithRetry()` only retries with ≥ 5 s left and gives the retry only the remaining time. The free tier allows 20 requests/day per model. Never pass `retryOptions` to the SDK (it would retry up to 5× with up to 60 s backoff).
   4. `plan-validation.ts` — `parsePlanContent(raw, target)`: class-validator against `dto/plan-content.dto.ts`, then `findPlanViolations(plan, target)`: meal calories as a share of the daily target (`MEAL_CALORIE_SHARE`: breakfast 15–35 %, lunch/dinner 25–45 %), each day's total within [max(85 % target, BMR); 110 % target], calories within 15 % of 4P+4C+9F, no repeated dish. The old fixed bounds (250–600 / 400–800) capped a day at 2200 kcal, below many users' targets, and the day total was never checked. Unknown enum values must fail, never skip a check.
-  5. `plan.service.ts` — orchestration: Gemini through `generateWithRetry()` (`gemini-retry.ts`: retry once, never after a timeout), output also rejected if it contains a recognised allergen → otherwise `data/sample-plan.json`, filtered by `filterPlanByRestrictions()` and scaled per day to the target by `meal-scaling.ts` (the file is written for ~1550 kcal/day), then validated by the same function. Warning texts live in `plan-warnings.ts` and never quote user text.
+  5. `plan.service.ts` — orchestration: Gemini through `generateWithRetry()` (`gemini-retry.ts`: retry once, never after a timeout), output also rejected if it contains a recognised allergen → otherwise `data/sample-plan.json`, filtered by `filterPlanByRestrictions()` and scaled per day to the target by `meal-scaling.ts` (the file is written for ~1550 kcal/day), then validated by the same function. Warning texts live in `plan-warnings.ts` and never quote user text. Exercises are then capped at `maxExerciseLevel(profile)` by `capWorkoutLevel()` (`exercise-level.ts`: ≥ 60, ≥ 45 + sedentary, or pregnant → level 1; active + < 45 → 3; else 2) — for Gemini output too, without calling Gemini again; the prompt states the rule via `exerciseLevelRule()`, built from the exercise pool.
   6. `plan-assembly.ts` — `assemblePlan()` assigns `plan_id` (UUID) and `m{day}_{n}` / `e{day}_{n}` ids, orders meals, and `buildGroceryList()` recomputes the grocery list from structured ingredients. Grocery lists are never taken from Gemini or the client.
   - `dto/meal-plan-response.dto.ts` holds the response classes Swagger shows; `MealDto` / `ExerciseDto` extend the content DTOs with ids. `enums/` holds the fixed codes (meal type, ingredient category/unit, muscle group, exercise tags, plan source).
 - `src/plan/restriction-matcher.ts` + `data/restriction-keywords.json` — keyword matcher for allergies/injuries (mock mode, D4) and for re-checking every Gemini result. Ingredient names are always compared with Vietnamese accents ("cá" fish ≠ "cà" tomato, "bò" ≠ "bơ"); user text is compared accent-insensitively only when typed without accents (NFD does not split "đ" — replaced by hand). It returns keywords/tags and a `hasUnrecognized` flag, never the user's text. `swap-pools.ts` loads and validates `data/swap-meals.json` (21 dishes) and `data/swap-exercises.json` (39 exercises with `level` 1–3) at boot; every exercise in `sample-plan.json` must be in the pool so its level is known.
-- `src/plan/adjust/` — `POST /api/v1/meals/swap`, `/exercises/swap`, `/feedback` (BRD §6.4) behind `OptionalJwtAuthGuard`. `readClientPlan()` recomputes the target from `profile` (mismatch with the plan's `daily_target` → 409) and checks ids/positions + `findPlanViolations()` (→ 400); `rebuildPlan()` keeps `plan_id`/`source` and recomputes ids, grocery list and warnings. Meal swap: Gemini first (±10 % calories, same meal type, no repeat, no allergen), then the pool scaled to the old meal's calories, else 422. Exercise swap: Gemini first, accepted only if same muscle group, sets ≤ old, tags ⊆ old tags, no injury tag; then a lower-`level` pool exercise, else 422. Feedback: fixed rules in `workout-rules.ts` (danger sign → rest day and `safety_warning`, skipping everything else), meals re-planned by Gemini on over/under-eating (never below BMR; no key → unchanged + warning), day 3 → a new plan via `PlanService.generatePlan(profile, { feedbackNote })`. Logged in: swap/feedback update the saved plan (`HistoryService.update()`), day-3 plans are saved as new. `test/plan-fixtures.ts` holds the shared fixtures (`samplePlan()`, `geminiAnswering()`, `firstPick`).
+- `src/plan/adjust/` — `POST /api/v1/meals/swap`, `/exercises/swap`, `/feedback` (BRD §6.4) behind `OptionalJwtAuthGuard`. `readClientPlan()` recomputes the target from `profile` (mismatch with the plan's `daily_target` → 409) and checks ids/positions + `findPlanViolations()` (→ 400); `rebuildPlan()` keeps `plan_id`/`source` and recomputes ids, grocery list and warnings. Meal swap: Gemini first (±10 % calories, same meal type, no repeat, no allergen), then the pool scaled to the old meal's calories, else 422. Exercise swap: Gemini first, accepted only if same muscle group, sets ≤ old, tags ⊆ old tags, no injury tag; then a lower-`level` pool exercise, else 422. Feedback: fixed rules in `workout-rules.ts` (danger sign → rest day and `safety_warning`, skipping everything else), meals re-planned by Gemini on over/under-eating (never below BMR; no key → unchanged + warning), day 3 → a new plan via `PlanService.generatePlan(profile, { feedbackNote })`. Logged in: swap/feedback update the saved plan (`HistoryService.update()`), day-3 plans are saved as new. `test/plan-fixtures.ts` holds the shared fixtures (`samplePlan()`, `geminiAnswering()`, `firstPick`). The profile's exercise level cap also applies to exercise swap (pool and Gemini) and the joint-pain rule.
 - `src/database/` — TypeORM 1.x on SQLite via `better-sqlite3@12` (TypeORM 1.1 only accepts `^12`; there is no `sqlite3` or `node:sqlite` driver). Entities `User` (`google_sub` unique; mock mode uses `mock:<email>`) and `PlanRecord` (`id` = the plan's `plan_id`, `user_id` FK with `ON DELETE CASCADE`, `plan_json` = the exact response, `created_at` set in code with millisecond precision because SQLite's `datetime('now')` default only has seconds). Schema changes go through migrations only (`migrationsRun: true`, never `synchronize`); `migrations.spec.ts` fails with the missing SQL if an entity drifts from the migrations. Relations between the two entities are typed `Relation<...>` — without it the compiled ESM build crashes at boot with `Cannot access 'User' before initialization` while every vitest test still passes.
 - `src/auth/` — `resolveAuthConfig()` validates env at boot and throws (so the app does not start) on a bad config: unknown `AUTH_MODE`, google mode without `GOOGLE_CLIENT_ID` or with a `JWT_SECRET` under 32 chars, mock mode with `NODE_ENV=production` unless `ALLOW_MOCK_AUTH=true`. `IdTokenVerifier` is an abstract-class DI token resolved to `MockIdTokenVerifier` or `GoogleIdTokenVerifier` (`google-auth-library`; always passes `audience` — without it tokens issued to other apps are accepted — and never logs the library's error text, which embeds the token and email). `AuthService` find-or-creates users (handles the unique-constraint race), signs HS256 JWTs whose payload is only `sub`, and re-loads the user on every request so a deleted account gets 401. `JwtAuthGuard` (required) / `OptionalJwtAuthGuard` (no header → guest, bad header → 401) and `@CurrentUser()` live in `jwt-auth.guard.ts`. Routes: `POST /api/v1/auth/google`, `DELETE /api/v1/me`.
 - `src/history/` — `GET /api/v1/plans/history` (50 newest) and `/:id` (another user's plan → 404, non-UUID → 400). `HistoryService.save()` returns `false` instead of throwing, so `generate-plan` still returns the plan (with a `historyNotSaved` warning) when saving fails.
@@ -91,14 +92,16 @@
 
 ## Frontend architecture
 
-- `lib/main.dart` — `main()` awaits `SharedPreferences.getInstance()` before `runApp`, builds one `ApiClient(baseUrl: resolveApiBaseUrl())` and both providers; `SmartFitApp(auth:, plans:)` wraps `MaterialApp` in a `MultiProvider` (tests inject providers backed by `test/fake_backend.dart`). `MainShell` owns navigation (`AppScreen` enum: onboarding → loading → dashboard → grocery; `setState` + `switch` in `_buildBody()`, no router); it opens on the dashboard if `PlanProvider.hasPlan`, else onboarding. The existing files are not `dart format`-ed — don't reformat whole files (it reflows unrelated widgets); CI doesn't check format.
+- `lib/main.dart` — `main()` enables `SystemUiMode.edgeToEdge`, awaits `SharedPreferences.getInstance()`, builds one `ApiClient(baseUrl: resolveApiBaseUrl())` and the three providers; `SmartFitApp(auth:, plans:, grocery:)` wraps `MaterialApp` in a `MultiProvider` (tests inject providers backed by `test/fake_backend.dart` via `test/app_harness.dart`). `MainShell` owns navigation: onboarding → loading (`_generate(profile)`) → home with 4 tabs (plan, grocery, history placeholder, profile); it opens home if `PlanProvider.hasPlan`, else onboarding, and re-renders on app resume so the plan day follows the calendar.
 - `lib/config/api_config.dart` — `resolveApiBaseUrl()`: `--dart-define=API_BASE_URL`, else `http://10.0.2.2:3000` on Android, `http://localhost:3000` elsewhere.
-- `lib/models/api/` — hand-written models for BRD §6 (`MealPlan`, `Profile`, `AuthResult`, `FeedbackResult`…; enums in `codes.dart`). `fromJson(json).toJson()` must equal `json` exactly — swap/feedback send the whole plan back and the server checks every id and number, so numbers are read as `num`; missing fields, wrong types and unknown codes throw `FormatException` naming the field (`json_read.dart`). `test/models/contract_test.dart` round-trips the backend's fixtures.
-- `lib/models/meal_plan.dart` — old UI view-models (`MealItem`, `DayPlan`, `GroceryCategory`…) the screens still use with hardcoded data; removed in phase 6.
-- `lib/services/api_client.dart` — `ApiClient` for all 9 endpoints: 60 s timeout for calls that may hit Gemini (the backend gives up at 40 s), 15 s otherwise; bodies decoded as UTF-8 from `bodyBytes`; every failure becomes a sealed `ApiException` (`api_exception.dart`) whose `message` is Vietnamese UI text (400 details stay in `ValidationException.details`); a 401 on a request that carried a token calls `onUnauthorized`. Never log request/response bodies — they carry health data.
-- `lib/providers/` — `PlanProvider` (profile + plan in `shared_preferences` keys `smartfit.profile.v1` / `smartfit.plan.v1`; `busy` flag, calls while busy are ignored; corrupt data dropped) and `AuthProvider` (`smartfit.access_token`, `smartfit.user.v1`; signs out on 401).
-- `lib/screens/` — one file per screen; `lib/widgets/` — `macro_ring.dart`, `feedback_bottom_sheet.dart`.
-- Network config per platform: `INTERNET` in the main Android manifest, cleartext HTTP only in the debug manifest, iOS `NSAllowsLocalNetworking`, macOS `network.client` in both entitlements (Dart's HTTP isn't subject to Android's cleartext policy — checked on Android 16 — the debug flag is only for platform-stack networking). Android `compileSdk = 36` (`shared_preferences_android` requires it; `targetSdk` stays 34). CI doesn't build an APK, so after adding a package with a native plugin run `flutter build apk --debug` locally.
+- `lib/models/api/` — hand-written models for BRD §6. `fromJson(json).toJson()` must equal `json` exactly — swap/feedback send the whole plan back and the server checks every id and number, so numbers are read as `num`; missing fields, wrong types and unknown codes throw `FormatException` naming the field (`json_read.dart`). `test/models/contract_test.dart` round-trips the backend's fixtures.
+- `lib/models/profile_rules.dart` (limits + safety rules mirroring the backend), `restriction_options.dart` (D5 chips; every allergy/injury chip must be a label the backend keyword matcher knows — checked against `test/fixtures/restriction_labels.json`), `plan_schedule.dart` (plan start date → today's day number).
+- `lib/services/api_client.dart` — `ApiClient` for all 9 endpoints: 60 s timeout for calls that may hit Gemini (the backend gives up at 40 s), 15 s otherwise; bodies decoded as UTF-8 from `bodyBytes`; every failure becomes a sealed `ApiException` (`api_exception.dart`) whose `message` is Vietnamese UI text; a 401 on a request that carried a token calls `onUnauthorized`. Never log request/response bodies — they carry health data.
+- `lib/providers/` — `PlanProvider` (profile of the current plan + plan + schedule + profile draft in `shared_preferences` keys `smartfit.profile.v1` / `.plan.v1` / `.plan_schedule.v1` / `.profile_draft.v1`; edits in the profile tab stay a draft so swaps keep sending the plan's own profile and never hit 409; a stored profile that breaks the v2.6.0 rules drops the plan; `busy` flag, calls while busy are ignored; injectable clock `now:`), `GroceryProvider` (bought / already-have per plan, key = category + name + quantity), `AuthProvider` (`smartfit.access_token`, `smartfit.user.v1`; signs out on 401).
+- `lib/screens/` — onboarding (3 steps), loading, dashboard, grocery, profile; `lib/widgets/profile_form.dart` — form shared by onboarding and the profile tab; `lib/theme/app_colors.dart` — palette. Wrap `ListTile`s in `Material` (not a coloured `Container`) or Flutter asserts in debug.
+- App name/icon/splash: `tool/update_icons.sh` (macOS: `swift` + `sips`) redraws `assets/icon/*.png` with `tool/make_icon.swift` and copies every size for Android (incl. adaptive icon), iOS, macOS, web — deterministic. Android 12+ splash background is the brand green (`values-v31/styles.xml`); the Android themes set `windowDrawsSystemBarBackgrounds` so the status bar is not painted black.
+- Network config per platform: `INTERNET` in the main Android manifest, cleartext HTTP only in the debug manifest (Dart's HTTP isn't subject to Android's cleartext policy — checked on Android 16), iOS `NSAllowsLocalNetworking`, macOS `network.client` in both entitlements. Android `compileSdk = 36` (`shared_preferences_android` requires it; `targetSdk` stays 34). CI doesn't build an APK, so after adding a package with a native plugin run `flutter build apk --debug` locally.
+- Files written since phase 6 follow `dart format --line-length 120`; older files are not formatted — don't reformat them wholesale. CI doesn't check format.
 
 UI strings, labels, and comments are in Vietnamese throughout the existing code — match this when adding to the same screens/widgets.
````

````diff
--- a/README.md
+++ b/README.md
@@ -15,7 +15,7 @@
 ## Cấu trúc thư mục
 
 ```
-frontend_app/    Ứng dụng Flutter (đã có tầng gọi API; màn hình còn dùng dữ liệu mẫu tới giai đoạn 6)
+frontend_app/    Ứng dụng Flutter: Onboarding, kế hoạch 3 ngày (đổi món, đổi bài), đi chợ, hồ sơ — nối backend
 backend_api/     API NestJS — generate-plan (Gemini hoặc thực đơn mẫu), đổi món, đổi bài tập, feedback, đăng nhập Google, lịch sử (SQLite)
 ai_workspace/    Script Node/TS thử nghiệm prompt & schema Gemini, độc lập với backend
 docs/            Kế hoạch triển khai, hướng dẫn gắn khoá, wiki nội bộ
@@ -79,6 +79,12 @@
 
 Đối chiếu theo phiên bản BRD (mục "Phiên bản" trong [BRD.md](BRD.md)), để giảng viên/trợ giảng theo dõi tiến độ trực tiếp trên repo mà không cần đọc từng commit.
 
+### BRD v2.6.0 — 2026-09-27
+- Giai đoạn 6 — app dùng dữ liệu thật: Onboarding 3 bước (thêm tuổi, giới tính, mức vận động), màn chờ gọi API, kế hoạch 3 ngày mở đúng ngày hôm nay với đủ 3 bữa, tổng calo và macro, đổi món và đổi bài gọi API, danh sách đi chợ (đánh dấu đã mua, ẩn món đã có sẵn), tab Cá nhân sửa hồ sơ. Không còn dữ liệu viết cứng
+- Nhập hạn chế mới: công tắc "Tôi có dị ứng / chấn thương / bệnh nền" → chọn từ danh sách phổ biến hoặc tự ghi — người không có hạn chế nào không phải tích gì
+- An toàn: không phục vụ người dưới 18 tuổi; không cho chọn Giảm mỡ khi thiếu cân hoặc đang mang thai / cho con bú; bài tập nhẹ hơn cho người lớn tuổi, ít vận động hoặc mang thai (trước đây mọi người nhận cùng một buổi tập)
+- Tên "SmartFit AI", icon và màn khởi động riêng; sửa dải đen trên thanh trạng thái Android. Kiểm thử: 89 test Flutter, 320 unit và 74 e2e backend; chạy thật trên máy ảo Android 16
+
 ### BRD v2.5.1 — 2026-09-24 → 2026-09-26
 - Giai đoạn 5 — nền tảng kết nối app với backend: app Flutter có model theo đúng hợp đồng API, lớp gọi API báo lỗi bằng tiếng Việt thay vì crash (mất mạng, hết giờ, phiên hết hạn…), lưu kế hoạch và phiên đăng nhập trên máy — mở lại app vẫn xem được kế hoạch khi không có mạng. Backend bật CORS cho bản web (`CORS_ORIGINS`). Backend xuất 14 mẫu JSON thật để test hai phía cùng dùng — đổi hợp đồng mà quên cập nhật phía nào thì test phía đó đỏ. Thêm CI cho Flutter (44 test); sửa quyền mạng Android/iOS/macOS và cấu hình build Android (trước đó APK không build được sau khi thêm package lưu dữ liệu). Màn hình vẫn dùng dữ liệu mẫu tới giai đoạn 6
 - Thử bằng khoá Gemini thật: tạo kế hoạch mất 37–42 giây vì model "suy nghĩ" trước khi trả lời, vượt giới hạn 15 giây nên gần như luôn rơi về thực đơn mẫu. Sửa: tắt chế độ suy nghĩ mặc định (còn 8–15 giây), giới hạn 20 giây mỗi lần gọi và 40 giây tổng; prompt ghi rõ nguyên liệu và động tác backend sẽ loại (trước đó Gemini cho cá nước ngọt khi người dùng dị ứng hải sản). Qua backend thật: `generate-plan` trả kết quả Gemini sau 14 giây
````

```diff
--- a/docs/PLAN.md
+++ b/docs/PLAN.md
@@ -1,6 +1,6 @@
 # Kế hoạch triển khai SmartFit AI
 
-Plan này chia [BRD.md](../BRD.md) (v2.5.1) thành các bước làm được theo thứ tự. BRD vẫn là nguồn yêu cầu; plan chỉ trả lời "làm gì trước, làm gì sau, xong khi nào".
+Plan này chia [BRD.md](../BRD.md) (v2.6.0) thành các bước làm được theo thứ tự. BRD vẫn là nguồn yêu cầu; plan chỉ trả lời "làm gì trước, làm gì sau, xong khi nào".
 
 **Thứ tự tổng thể:** hoàn thiện backend trước (kiểm thử toàn bộ qua Swagger), sau đó mới làm frontend bám theo hợp đồng API đã chốt.
 
@@ -29,10 +29,10 @@
 
 ## Hiện trạng (đã xong)
 
-- [x] BRD v2.5.1 (MVP, tính năng nâng cao, tài khoản & lịch sử, hợp đồng API đầy đủ)
+- [x] BRD v2.6.0 (MVP, tính năng nâng cao, tài khoản & lịch sử, hợp đồng API đầy đủ)
 - [x] Backend: `GET /health`, `POST /api/v1/generate-plan` (tính BMR/TDEE, gọi Gemini, kiểm tra khoảng calo, fallback), đổi món, đổi bài tập, feedback, đăng nhập Google (giả lập mặc định), lịch sử kế hoạch (SQLite), validate DTO, Swagger UI, CORS cho bản web
 - [x] `ai_workspace/`: script thử prompt Gemini
-- [x] Frontend: giao diện Onboarding, Loading, Dashboard, Grocery, bảng Feedback (dữ liệu mẫu); tầng kết nối API — model theo hợp đồng, `ApiClient`, provider, lưu trên máy (giai đoạn 5). Màn hình **chưa nối API** (giai đoạn 6)
+- [x] Frontend: Onboarding 3 bước, màn chờ, kế hoạch 3 ngày (đổi món, đổi bài), đi chợ, hồ sơ — đọc/ghi qua provider, không còn dữ liệu viết cứng (giai đoạn 6). Chưa có: bảng feedback cuối ngày (giai đoạn 7), đăng nhập và lịch sử (giai đoạn 8)
 - [x] Wiki nội bộ `docs/knowledge/`, `CLAUDE.md`
 
 ---
@@ -83,7 +83,7 @@
 | B1 | Plan chỉ có ngày 1–3, không có ngày bắt đầu: hôm sau mở app vẫn "Ngày 1", bỏ dùng lâu thì plan cũ nằm mãi | App lưu ngày bắt đầu trên máy, tự chuyển ngày theo lịch; hết 3 ngày → gợi ý tạo plan mới |
 | B2 | Onboarding sẽ có khoảng 10 trường; trên màn hình 720×1280 nút tạo kế hoạch đã nằm dưới mép màn hình | Chia 3 bước (chỉ số cơ thể → mục tiêu & vận động → hạn chế), thanh tiến trình, nút luôn ở đáy |
 
-A1–A4 đổi hợp đồng và luật dinh dưỡng → BRD v2.6.0 ở giai đoạn 6 (FR-1.1, FR-1.4, FR-1.5, FR-2.2, NFR an toàn). **Để sau** (đã cân nhắc, chưa làm): đi chợ theo số người nấu; tuỳ chọn ăn chay (cần thêm món chay và nhóm từ khoá); đánh dấu bữa ăn ngoài (phải đổi cách backend tính danh sách đi chợ); cảnh báo nhẹ khi BMI ≥ 30 chọn "Tăng cơ".
+A1–A4 đổi hợp đồng và luật dinh dưỡng → BRD v2.6.0 ở giai đoạn 6 (FR-1.1, FR-1.4, FR-1.5, FR-2.2, NFR an toàn). **Để sau** (đã cân nhắc, chưa làm): đi chợ theo số người nấu; tuỳ chọn ăn chay (cần thêm món chay và nhóm từ khoá); đánh dấu bữa ăn ngoài (phải đổi cách backend tính danh sách đi chợ); cảnh báo nhẹ khi BMI ≥ 30 chọn "Tăng cơ"; cân macro của thực đơn mẫu (phát hiện khi chạy thử giai đoạn 6: thực đơn mẫu chỉ được nhân khẩu phần theo calo nên tinh bột ~120%, chất béo ~70% mục tiêu; backend chưa kiểm tỉ lệ macro).
 
 ---
 
@@ -170,24 +170,26 @@
 
 Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-5-frontend-foundation.md` (quyết định Q1–Q4 ở mục 8), plan `docs/superpowers/plans/phase-5-frontend-foundation/`.
 
-## Giai đoạn 6 — Frontend: nối MVP (FR-1 → FR-3) · M
+## Giai đoạn 6 — Frontend: nối MVP (FR-1 → FR-3) · L
 
-- [ ] **6.1** Onboarding chia 3 bước (D6-B2): thêm tuổi (≥ 18), giới tính, mức vận động (FR-1.1, FR-1.2 — backend bắt buộc nhưng giao diện chưa có); khoá "Giảm mỡ" khi BMI < 18,5 hoặc mang thai / cho con bú (D6-A1, A3); nhập hạn chế theo D5 + dòng khuyến cáo y tế (D4); validate cùng giới hạn với backend, báo lỗi ngay khi nhập. Bỏ giá trị điền sẵn 168 / 62; nút tiếp tục phải mang hồ sơ đi (hiện `onNext` không truyền dữ liệu nào)
-- [ ] **6.2** Tab "Cá nhân": xem và sửa hồ sơ, lưu trên máy (FR-1.6); sửa xong thì gợi ý tạo lại plan (hiện ghi cứng "168 cm • 62 kg • Giảm mỡ", không theo Onboarding)
-- [ ] **6.3** Loading: gọi API thật thay cho bộ đếm giờ giả; lỗi → nút thử lại (NFR-1, NFR-2). Có Gemini thì chờ thật khoảng 10–15 giây, tối đa khoảng 40 giây — câu chờ và thanh tiến trình phải hợp với khoảng này; HTTP client của app để timeout dài hơn 40 giây. Bỏ nút "Xem trước kế hoạch ngay" và các câu chờ bịa số liệu ("Cân đối Macro: 140g Carbs, 65g Protein…", "phù hợp ngân sách")
-- [ ] **6.4** Dashboard: hiển thị đủ 3 ngày, 3 bữa/ngày, bài tập, calo và macro (FR-2.3); hiện cảnh báo khi chế độ giả lập chưa kiểm tra được hết hạn chế. Thấy khi chạy trên máy ảo (giai đoạn 5): ngày ghi cứng "Thứ Ba, 15/9/2026"; thiếu bữa sáng; bộ chọn S1–S5 là 5 ngày và bấm không đổi nội dung; món/động tác không theo hạn chế đã chọn (vẫn có cá khi dị ứng hải sản); chưa hiện tổng calo và macro mỗi ngày (FR-2.3) — widget `macro_ring.dart` có sẵn nhưng chưa dùng; nhãn "Dễ", "Không tạ", chữ "T", "3 ngày" ghi cứng; hiện `warnings` của plan
-- [ ] **6.5** Grocery: dựng từ `grocery_list`; trạng thái tích chọn lưu cục bộ (FR-3.2). Tên nhóm theo BRD FR-3.1 (*Đạm*, *Rau củ quả*, *Gạo, bún & gia vị* — hiện là "Thịt & Thủy hải sản", "Gia vị & nguyên liệu khác"); thêm thao tác xoá món đã có sẵn trong tủ lạnh (FR-3.2); quyết định giữ hay bỏ nút "Thêm nguyên liệu" (không có trong BRD)
-- [ ] **6.6** Widget test dùng backend giả `test/fake_backend.dart` (có từ giai đoạn 5)
-- [ ] **6.7** Màn hình đọc/ghi qua `PlanProvider`/`AuthProvider` và model `lib/models/api/`; xoá view-model cũ `lib/models/meal_plan.dart`. Thao tác lại toàn luồng trên máy ảo Android và chạy `flutter test integration_test`
-- [ ] **6.8** Tên app hiển thị "my_ai_app" (Android, web) và "My Ai App" (iOS) → "SmartFit AI"; icon vẫn là icon mặc định của Flutter; màn khởi động còn logo Flutter; thanh trạng thái màu đen trên nền app sáng
-- [ ] **6.9** *(D6-A1, A2, A3)* Backend: tuổi tối thiểu 18; BMI < 18,5 hoặc mang thai / cho con bú mà chọn `cut` → 400 kèm câu tiếng Việt; test + fixture hợp đồng xuất lại; BRD v2.6.0
-- [ ] **6.10** *(D6-A4)* Backend: chọn mức động tác theo tuổi và `activity_level` cho thực đơn mẫu và kho đổi bài; prompt Gemini cùng luật; đo lại bằng `npm run measure:gemini` nếu đổi prompt
-- [ ] **6.11** *(D6-B1)* App lưu ngày bắt đầu plan, Dashboard mở đúng ngày theo lịch; quá 3 ngày → gợi ý tạo plan mới
+- [x] **6.1** Onboarding chia 3 bước (D6-B2): thêm tuổi (≥ 18), giới tính, mức vận động (FR-1.1, FR-1.2 — backend bắt buộc nhưng giao diện chưa có); khoá "Giảm mỡ" khi BMI < 18,5 hoặc mang thai / cho con bú (D6-A1, A3); nhập hạn chế theo D5 + dòng khuyến cáo y tế (D4); validate cùng giới hạn với backend, báo lỗi ngay khi nhập. Bỏ giá trị điền sẵn 168 / 62; nút tiếp tục phải mang hồ sơ đi (hiện `onNext` không truyền dữ liệu nào)
+- [x] **6.2** Tab "Cá nhân": xem và sửa hồ sơ, lưu trên máy (FR-1.6); sửa xong thì gợi ý tạo lại plan (hiện ghi cứng "168 cm • 62 kg • Giảm mỡ", không theo Onboarding)
+- [x] **6.3** Loading: gọi API thật thay cho bộ đếm giờ giả; lỗi → nút thử lại (NFR-1, NFR-2). Có Gemini thì chờ thật khoảng 10–15 giây, tối đa khoảng 40 giây — câu chờ và thanh tiến trình phải hợp với khoảng này; HTTP client của app để timeout dài hơn 40 giây. Bỏ nút "Xem trước kế hoạch ngay" và các câu chờ bịa số liệu ("Cân đối Macro: 140g Carbs, 65g Protein…", "phù hợp ngân sách")
+- [x] **6.4** Dashboard: hiển thị đủ 3 ngày, 3 bữa/ngày, bài tập, calo và macro (FR-2.3); hiện cảnh báo khi chế độ giả lập chưa kiểm tra được hết hạn chế. Thấy khi chạy trên máy ảo (giai đoạn 5): ngày ghi cứng "Thứ Ba, 15/9/2026"; thiếu bữa sáng; bộ chọn S1–S5 là 5 ngày và bấm không đổi nội dung; món/động tác không theo hạn chế đã chọn (vẫn có cá khi dị ứng hải sản); chưa hiện tổng calo và macro mỗi ngày (FR-2.3) — widget `macro_ring.dart` có sẵn nhưng chưa dùng; nhãn "Dễ", "Không tạ", chữ "T", "3 ngày" ghi cứng; hiện `warnings` của plan
+- [x] **6.5** Grocery: dựng từ `grocery_list`; trạng thái tích chọn lưu cục bộ (FR-3.2). Tên nhóm theo BRD FR-3.1 (*Đạm*, *Rau củ quả*, *Gạo, bún & gia vị* — hiện là "Thịt & Thủy hải sản", "Gia vị & nguyên liệu khác"); thêm thao tác xoá món đã có sẵn trong tủ lạnh (FR-3.2); quyết định giữ hay bỏ nút "Thêm nguyên liệu" (không có trong BRD)
+- [x] **6.6** Widget test dùng backend giả `test/fake_backend.dart` (có từ giai đoạn 5)
+- [x] **6.7** Màn hình đọc/ghi qua `PlanProvider`/`AuthProvider` và model `lib/models/api/`; xoá view-model cũ `lib/models/meal_plan.dart`. Thao tác lại toàn luồng trên máy ảo Android và chạy `flutter test integration_test`
+- [x] **6.8** Tên app hiển thị "my_ai_app" (Android, web) và "My Ai App" (iOS) → "SmartFit AI"; icon vẫn là icon mặc định của Flutter; màn khởi động còn logo Flutter; thanh trạng thái màu đen trên nền app sáng
+- [x] **6.9** *(D6-A1, A2, A3)* Backend: tuổi tối thiểu 18; BMI < 18,5 hoặc mang thai / cho con bú mà chọn `cut` → 400 kèm câu tiếng Việt; test + fixture hợp đồng xuất lại; BRD v2.6.0
+- [x] **6.10** *(D6-A4)* Backend: chọn mức động tác theo tuổi và `activity_level` cho thực đơn mẫu và kho đổi bài; prompt Gemini cùng luật; đo lại bằng `npm run measure:gemini` nếu đổi prompt
+- [x] **6.11** *(D6-B1)* App lưu ngày bắt đầu plan, Dashboard mở đúng ngày theo lịch; quá 3 ngày → gợi ý tạo plan mới
 
+Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-6-connect-mvp.md` (quyết định Q1–Q4 ở mục 8), plan `docs/superpowers/plans/phase-6-connect-mvp/`. Nút đổi món, đổi bài làm luôn ở giai đoạn này (7.1, 7.2 — quyết định Q3); nút feedback ẩn tới giai đoạn 7.
+
 ## Giai đoạn 7 — Frontend: tính năng nâng cao (FR-4, FR-5) · M
 
-- [ ] **7.1** Nút "Đổi món" gọi API (hiện đang xoay vòng trong danh sách món viết cứng); thay cả plan và checklist bằng plan server trả về. 409 → báo hồ sơ đã đổi, gợi ý tạo plan mới; 422 → báo không còn món thay thế phù hợp
-- [ ] **7.2** Nút "Đổi bài" gọi API
+- [x] **7.1** Nút "Đổi món" gọi API (hiện đang xoay vòng trong danh sách món viết cứng); thay cả plan và checklist bằng plan server trả về. 409 → báo hồ sơ đã đổi, gợi ý tạo plan mới; 422 → báo không còn món thay thế phù hợp *(làm ở giai đoạn 6, quyết định Q3)*
+- [x] **7.2** Nút "Đổi bài" gọi API *(làm ở giai đoạn 6, quyết định Q3)*
 - [ ] **7.3** Làm lại bảng feedback theo D2 (3 câu hỏi, câu tình trạng cơ thể chọn nhiều); gọi API, cập nhật ngày kế tiếp; nhận `safety_warning` → hiện khuyến cáo ngừng tập, hỏi ý kiến bác sĩ. **Khoá nút sau khi đã gửi feedback cho một ngày** — backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa. Bỏ câu báo viết sẵn "AI đã cân đối lại thực đơn Ngày 2!" (hiện hiện ra dù không có gì thay đổi)
 
 ## Giai đoạn 8 — Frontend: Tài khoản & Lịch sử (FR-6, FR-7) · M
```

### Task 5 — Cổng kiểm tra F06

```bash
grep -c "2.6.0" BRD.md                                            # ≥ 10
grep -c "^| 3[0-2] |" docs/knowledge/wiki/critical-constraints.md # 3
grep -c "^- \[x\] \*\*6\." docs/PLAN.md                            # 11
grep -rn "meal_plan.dart\|feedback_bottom_sheet" CLAUDE.md docs/knowledge/wiki/flutter-ui.md || echo "sạch"
```
