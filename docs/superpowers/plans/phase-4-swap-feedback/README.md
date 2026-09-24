# Giai đoạn 4 — Backend: Đổi món, đổi bài tập, feedback (FR-4, FR-5) — Plan

**Status:** ready
**Brainstorm:** `docs/superpowers/brainstorms/phase-4-swap-feedback.md` (quyết định Q1–Q4 ở mục 8)
**Executor:** thực thi trực tiếp theo spec (`/feature-build` bản hiện tại chỉ nhận cấu trúc Next.js).
**Commit:** một commit + push cho cả giai đoạn sau F07, lên nhánh đang làm việc (hiện là `Thien-Source`), không mở pull request. CI chạy sau khi push.

## Features

| ID | Tên | Phạm vi | Bước PLAN |
|---|---|---|---|
| F01 | `generate-plan` v2.5.0: tổng calo theo mục tiêu, bộ khớp từ khoá, kho soạn sẵn, lọc thực đơn mẫu, gọi lại Gemini dùng chung | API | 4.1, 4.7 (mới, Q1) |
| F02 | Nhận plan từ client, DTO mục 6.4, cập nhật lịch sử | API | 4.8 (mới, Q4) |
| F03 | Đổi món | API | 4.2 |
| F04 | Đổi bài tập (Gemini trước, kho dự phòng — Q2) | API | 4.3 |
| F05 | Feedback cuối ngày (quy tắc cố định, dấu hiệu nguy hiểm, cân đối món bằng Gemini — Q3, ngày 3 → plan mới) | API | 4.4 |
| F06 | Ba endpoint + lịch sử, e2e, smoke test, lint | API + CI | 4.5 |
| F07 | BRD v2.5.0, wiki, CLAUDE.md, README, PLAN.md, SETUP_CREDENTIALS | Docs | — |

## Thứ tự thực hiện

F01 → F02 → F03 → F04 → F05 → F06 → F07. Sau mỗi feature, typecheck, build và toàn bộ test đều xanh.

## Code trong spec đã được chạy thật

Code của F01–F06 được viết và chạy trên một bản sao `backend_api/` (và `ai_workspace/`) trong thư mục nháp, không đụng repo. Sau đó, để chắc mỗi feature tự đứng được, các file được áp **lần lượt từng feature** lên bản gốc hiện tại của repo, và ở mỗi mốc đều chạy typecheck, build, unit, e2e. Code trong spec chép nguyên văn từ bản đã chạy.

| Mốc | Unit | E2E | Kiểm thêm |
|---|---|---|---|
| Hiện tại | 15 file, 126 test | 4 file, 36 test | — |
| Sau F01 | 19 file, 183 test | 4 file, 37 test | prompt `ai_workspace` giống hệt backend |
| Sau F02 | 20 file, 196 test | 37 | — |
| Sau F03 | 21 file, 208 test | 37 | — |
| Sau F04 | 22 file, 216 test | 37 | — |
| Sau F05 | 24 file, 240 test | 37 | — |
| Sau F06 | 24 file, 240 test | 5 file, 58 test | smoke test gọi 3 endpoint mới trên bản build; `npm run lint` sạch |

**Kiểm ngược (mutation).** Cố ý làm hỏng 14 hành vi; lần nào cũng có test đỏ:

- dấu hiệu nguy hiểm không thay buổi tập;
- nguy hiểm mà vẫn cân đối món;
- bỏ kiểm tổng calo ngày;
- tổng ngày được dưới BMR;
- thực đơn mẫu không nhân khẩu phần;
- không báo 409;
- không kiểm ID theo vị trí;
- món Gemini có chất dị ứng vẫn được nhận;
- động tác Gemini nhiều hiệp hơn vẫn được nhận;
- log lộ từ khoá dị ứng;
- cập nhật plan của người khác;
- bỏ dấu hết (cà chua → cá);
- ăn nhiều mà ngày sau không nhẹ hơn;
- thiếu `plan` → 500.

Smoke test cũng đỏ khi xoá một file JSON khỏi `dist/`.

**Độ trễ** đo trên bản build chạy thật, chế độ giả lập:

| Thao tác | Độ trễ |
|---|---|
| `generate-plan` | 6–7 ms |
| Đổi món | ~6 ms |
| Đổi bài tập | ~4 ms |
| Feedback | ~4 ms |
| Mọi đường có Gemini | tệ nhất ~30 s (2 × `GEMINI_TIMEOUT_MS`), như `generate-plan` |

## Phát hiện khi lập plan (ngoài brainstorm)

| # | Phát hiện | Xử lý |
|---|---|---|
| P1 | Bỏ dấu cả chữ người dùng nhập → "dị ứng cà chua" bị hiểu thành dị ứng **cá**: cá bị lọc, còn cà chua không có cảnh báo | Chỉ bỏ dấu khi người dùng gõ không dấu; tên nguyên liệu luôn so có dấu (F01, ràng buộc mới #23) |
| P2 | Request thiếu hẳn `plan` trả **500**: `@ValidateNested()` bỏ qua trường không có | `@IsDefined()` cho `profile`, `plan` (F02, #24) — e2e phát hiện |
| P3 | Thực đơn mẫu có "Nước mắm" → với dị ứng hải sản, kết quả Gemini giống thực đơn mẫu bị bước kiểm dị ứng mới loại. Test cũ dùng "Hải sản" cho đường Gemini hợp lệ | Đổi dị ứng mẫu trong test sang "Đậu phộng"; thêm test cho hành vi mới (F01) |
| P4 | Log gọi Gemini đổi dạng thành `(lần N, <thao tác>)` khi tách vòng gọi lại ra dùng chung | Cập nhật `SETUP_CREDENTIALS.md` mục 1.3 (F07) |
| P5 | Cảnh báo lint `no-misused-spread` tăng từ 2 lên 27 — DTO chỉ chứa dữ liệu, chép thành object thường là cố ý | Tắt quy tắc trong `.oxlintrc.json`; `npm run lint` sạch (F06) |
| P6 | Glob asset `plan/data/*.json` có sẵn đã bao ba file JSON mới | Không sửa `nest-cli.json`; smoke test kiểm bằng cách xoá file khỏi `dist/` (F06) |
| P7 | `Repository.update()` ghi đúng cột `simple-json` | Kiểm với SQLite trong RAM (F02) |

## Ràng buộc từ wiki

Không có ràng buộc nào mâu thuẫn với các quyết định của brainstorm. Hai câu đã cũ trong PLAN.md (4.2 "cập nhật `grocery_list` theo `source_meal_ids`" — mâu thuẫn #7) được sửa ở F07. Ràng buộc được test khoá lại trong giai đoạn này:

| Ràng buộc | Test |
|---|---|
| #2 kiểm mọi plan (nay có khoảng calo theo mục tiêu, tổng ngày, plan client gửi lên) | `plan-validation.spec.ts`, `client-plan.spec.ts`, `adjust.e2e-spec.ts` (400) |
| #7 danh sách đi chợ tính lại | `meal-swap.service.spec.ts`, `client-plan.spec.ts` |
| #12 không lưu/log dữ liệu sức khoẻ | `plan.service.spec.ts`, `meal-swap.service.spec.ts`, `restriction-filter.spec.ts` (log), `adjust.e2e-spec.ts` (response và DB) |
| #13 sàn BMR — cả thực đơn thật | `sample-plan.spec.ts` (20 hồ sơ), `feedback.service.spec.ts` |
| #14 dấu hiệu nguy hiểm | `workout-rules.spec.ts`, `feedback.service.spec.ts` (`describe` riêng), `adjust.e2e-spec.ts` |
| #15 không gọi lại sau khi hết giờ | `meal-swap.service.spec.ts`, `adjust.e2e-spec.ts` (server giả không trả lời) |
| #16 ID do server gán, `plan_id` giữ khi sửa | `client-plan.spec.ts`, `meal-swap.service.spec.ts`, `feedback.service.spec.ts` |
| #17 test không gọi dịch vụ thật | Gemini giả trong unit test, server Gemini giả trong e2e |
| #22 401/không đụng plan người khác | `history.service.spec.ts`, `adjust.e2e-spec.ts` |

Ràng buộc mới ghi vào wiki ở F07: #23 (bộ khớp từ khoá), #24 (nhận plan từ client), #25 (kho soạn sẵn); sửa #2, #13, #14, #15.

## Việc chuyển sang giai đoạn sau

- **4.6 `responseSchema`:** để sau, khi có khoá thật để đo bằng `ai_workspace/`.
- **App (giai đoạn 7):** xử lý 409 (gợi ý tạo plan mới) và 422; khoá nút feedback sau khi gửi — F07 ghi vào PLAN.md.
- **Prompt đổi món, đổi bài, cân đối món ăn** chưa có bản thử trong `ai_workspace/`.

## Danh sách file

- `specs/F01-calories-restrictions.md`
- `specs/F02-client-plan.md`
- `specs/F03-meal-swap.md`
- `specs/F04-exercise-swap.md`
- `specs/F05-feedback.md`
- `specs/F06-endpoints-e2e.md`
- `specs/F07-docs.md`
- `project.json`
- `README.md`
