# Giai đoạn 3 — Backend: Tài khoản & Lịch sử (FR-6, FR-7) — Plan

**Status:** ready
**Brainstorm:** `docs/superpowers/brainstorms/phase-3-auth-history.md` (quyết định Q1–Q4 ở mục 8)
**Executor:** thực thi trực tiếp theo spec (`/feature-build` bản hiện tại chỉ nhận cấu trúc Next.js).
**Commit:** một commit + push cho cả giai đoạn sau F05, lên nhánh đang làm việc (hiện là `Thien-Source`), không mở pull request. Cổng kiểm tra CI của F04 chỉ chạy được sau khi push.

## Features

| ID | Tên | Phạm vi | Bước PLAN |
|---|---|---|---|
| F01 | Cơ sở dữ liệu: TypeORM + SQLite (`better-sqlite3@12`), entity, migration, `createTestApp()` | API (hạ tầng) | 3.1, 3.2 |
| F02 | Đăng nhập `AUTH_MODE=mock\|google`, JWT, guard, `DELETE /api/v1/me`, `/health` báo `auth_mode` | API | 3.3, 3.4, 3.6, 3.8 |
| F03 | Lịch sử: lưu khi `generate-plan`, `GET /api/v1/plans/history`, `/:id` | API | 3.4, 3.5, 3.6 |
| F04 | Smoke test trên bản build + bước CI | CI | 3.9 (mới) |
| F05 | BRD v2.4.0, `SETUP_CREDENTIALS.md` mục 2, wiki, CLAUDE.md, README, PLAN.md | Docs | 3.7 |

## Thứ tự thực hiện

F01 → F02 → F03 → F04 → F05. Mỗi feature phụ thuộc feature liền trước; sau mỗi feature, build và toàn bộ test đều xanh (số test ghi trong từng spec).

## Code trong spec đã được chạy thật

Toàn bộ code trong F01–F04 được viết và chạy trên một bản sao `backend_api/` ở thư mục nháp (repo không bị đụng), theo đúng thứ tự F01 → F04. Ở mỗi mốc đều đã chạy build, unit test, e2e; F03, F04 chạy thêm server thật. Code trong spec được chép nguyên văn từ bản sao đó.

| Mốc | Unit | E2E | Kiểm thêm |
|---|---|---|---|
| Hiện tại | 9 file, 61 test | 2 file, 12 test | — |
| Sau F01 | 10 file, 64 test | 2 file, 12 test | `node dist/main.js` lên được, không tạo file DB khi test |
| Sau F02 | 14 file, 120 test | 3 file, 24 test | cấu hình sai → không khởi động, in lý do |
| Sau F03 | 15 file, 126 test | 4 file, 36 test | file DB thật: đăng nhập → tạo plan → khởi động lại → xem lại bằng token cũ = 200 |
| Sau F04 | — | — | `npm run test:smoke` đạt |

Kiểm ngược (mutation): cố ý làm hỏng 10 chỗ quan trọng; lần nào cũng có test đỏ. Các chỗ đã làm hỏng: bỏ `audience`, lệch migration, guard tuỳ chọn nuốt token sai, xem được plan người khác, log lộ token/email, bỏ kiểm `email_verified`, bỏ xử lý đăng nhập đồng thời, token của user đã xoá vẫn qua, không kiểm `NODE_ENV`, lưu lỗi mà không cảnh báo. `oxlint` không thêm cảnh báo mới.

Độ trễ đo trên máy dev (chế độ giả lập, file DB): đăng nhập ~2 ms, `generate-plan` kèm lưu lịch sử ~7 ms, danh sách lịch sử ~2 ms.

## Phát hiện khi lập plan (ngoài brainstorm)

| # | Phát hiện | Xử lý |
|---|---|---|
| P1 | Hai entity import lẫn nhau → bản build ESM ném `ReferenceError` lúc khởi động; **toàn bộ unit test và e2e vẫn xanh** vì vitest chạy thẳng `.ts` | `Relation<>` (F01), smoke test bản build trong CI (F04), ràng buộc mới #20 |
| P2 | Migration viết bằng API `Table` lệch entity ở hai chỗ (độ dài `id`, mặc định `created_at`) | Viết lại cho khớp; `migrations.spec.ts` so schema diff (F01), ràng buộc mới #19 |
| P3 | Mặc định `datetime('now')` của SQLite chỉ chính xác tới giây → thứ tự lịch sử không xác định | `created_at` do code gán, lưu tới mili-giây (F01) |
| P4 | `verifyIdToken()` không có `audience` thì nhận token của app khác | Không cho tạo verifier khi thiếu Client ID, có test (F02) |
| P5 | Thông báo lỗi của `google-auth-library` chứa token và email | Chỉ log phần trước dấu `:`, có test (F02) |
| P6 | `@nestjs/jwt` 12 không nhận `string` cho `expiresIn` | Tự đổi `JWT_EXPIRES_IN` ra số giây, kiểm lúc khởi động (F02) |
| P7 | `@nestjs/typeorm` mặc định thử kết nối lại 9 × 3 giây | `retryAttempts: 0` (F01) |
| P8 | `tsc` trên `test/` báo lỗi có sẵn: `supertest/types` không tồn tại | Helper e2e mới bỏ import đó, sửa luôn 2 file e2e cũ (F01). Lỗi còn lại ở `daily-target.spec.ts` có từ trước, không thuộc giai đoạn này |

## Ràng buộc từ wiki

Không có ràng buộc nào mâu thuẫn với quyết định của brainstorm. Ràng buộc được test khoá lại trong giai đoạn này:

| Ràng buộc | Test |
|---|---|
| #10 không lưu mật khẩu, SQLite qua TypeORM, file DB ignore | F01 (migration), F01 cổng kiểm tra (`git status`) |
| #12 không lưu dữ liệu sức khoẻ, không log token/email | F03 (đọc thẳng `plan_json` trong DB), F02 (log từ chối đăng nhập) |
| #16 ID do server gán | F03 (`plan_records.id` = `plan_id`) |
| #17 test không gọi Google/Gemini, không đụng DB thật | F01 (`createTestApp()`, `createMemoryDataSource()`), F02 (khoá RSA tự tạo) |
| #18 `configureApp()` | F02 (Swagger có bearer auth, kiểm trong e2e) |

Ràng buộc mới ghi vào wiki ở F05: #19 (schema chỉ đổi qua migration), #20 (`Relation<>` + smoke test bản build), #21 (cấu hình đăng nhập, chặn mock khi production), #22 (401/404 của API cần đăng nhập).

## Việc chuyển sang giai đoạn sau

- **CORS** (brainstorm F8): chưa bật; thêm bước 5.7 vào PLAN.md ở F05.
- **Google Sign-In phía Flutter** và kiểm tra đăng nhập bằng tài khoản Google thật: giai đoạn 8 (8.4).

## Danh sách file

- `specs/F01-database.md`
- `specs/F02-auth.md`
- `specs/F03-history.md`
- `specs/F04-smoke-ci.md`
- `specs/F05-docs.md`
- `project.json`
- `README.md`
