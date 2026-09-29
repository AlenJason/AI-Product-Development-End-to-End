# Brainstorm: Giai đoạn 3 — Backend: Tài khoản & Lịch sử (FR-6, FR-7)
**Source:** `docs/PLAN.md` (giai đoạn 3, bước 3.1–3.7) + `BRD.md` v2.3.0 (mục 4 — CSDL & xác thực, FR-6, FR-7, mục 6.3, NFR-5, NFR-6, NFR-7)
**Date:** 2026-09-24

## 1. Phạm vi

- Lưu trữ: TypeORM + SQLite, entity `User` và `PlanRecord`, file DB nằm trong `.gitignore`.
- `POST /api/v1/auth/google`: `AUTH_MODE=mock | google`, backend phát JWT riêng, hết hạn sau 7 ngày (NFR-5).
- Guard: bắt buộc cho API lịch sử; tuỳ chọn cho `generate-plan` (token hợp lệ → lưu lịch sử; token sai → 401; không token → như cũ).
- `GET /api/v1/plans/history`, `GET /api/v1/plans/history/:id` (plan của người khác → 404).
- `/health` báo thêm `auth_mode`; hướng dẫn Google Sign-In phía backend trong `SETUP_CREDENTIALS.md`.

## 2. Ngữ cảnh đã nạp

- Wiki: `INDEX.md`, `wiki-triggers.md`, `critical-constraints.md` (#1–#18), `plan-data-contract.md`, `gemini-integration.md`. Từ khoá auth/token/DB không khớp bài nào — `wiki-triggers.md` ghi rõ chưa có trigger auth/DB vì trước giờ chưa có code phần này; sau giai đoạn này cần thêm.
- Điều kiện nạp ràng buộc: **có** (auth, DB, endpoint mới). Liên quan trực tiếp: #3 (bí mật qua `.env`), #10 (chỉ Google, không lưu mật khẩu, SQLite qua TypeORM, file DB gitignore), #11 (DB ở server, host phải có ổ bền), #12 (không lưu dữ liệu sức khoẻ — kể cả trong `PlanRecord`), #16 (ID do server gán), #17 (test không gọi dịch vụ thật), #18 (cấu hình app ở `configureApp()`).

## 3. Phát hiện — kiểm chứng ngày 2026-09-24

| # | Phát hiện | Cách kiểm |
|---|---|---|
| F1 | **TypeORM đã lên 1.x** (1.1.1). `@nestjs/typeorm` 12.0.1 nhận `typeorm ^0.3.0 \|\| ^1.0.0-dev` → dùng được với Nest 12. | `npm view` |
| F2 | **TypeORM 1.x bỏ driver `sqlite3` cũ và không hỗ trợ `node:sqlite`** (SQLite có sẵn trong Node). Driver SQLite còn lại: `better-sqlite3`, `sqljs`. | Cài thử, liệt kê `node_modules/typeorm/driver/` |
| F3 | TypeORM 1.1.1 chỉ nhận **`better-sqlite3` ^12**, trong khi bản mới nhất là 13.0.3 → phải ghim `better-sqlite3@12`, cài bản mới nhất sẽ lệch phiên bản. | `npm view typeorm peerDependencies` |
| F4 | **`better-sqlite3@12` cài được và chạy được trên Node 26**: npm 11 chỉ *cảnh báo* install script (`prebuild-install`) "chưa được duyệt", không chặn; binary dựng sẵn được tải về. `npm install-scripts approve better-sqlite3` ghi `"allowScripts": {"better-sqlite3@12.11.1": true}` vào `package.json` — duyệt tường minh, phòng khi npm sau này chặn hẳn. | Cài thử trong thư mục tạm |
| F5 | `google-auth-library` 11.1.0 cần Node ≥ 22 (CI dùng 24, 26 — ổn). `verifyIdToken()` tải khoá công khai của Google qua mạng → không test trực tiếp được theo ràng buộc #17; cần bọc sau một provider để test thay được. | `npm view` |
| F6 | **Nguy cơ lớn nhất của chế độ giả lập:** nếu deploy với `AUTH_MODE=mock`, ai gửi `mock:<email-bất-kỳ>` cũng đăng nhập được thành người đó → **đọc được lịch sử của người khác**. | Suy ra từ thiết kế PLAN 3.3 |
| F7 | **DB bị xoá sạch trên host không có ổ bền** (ràng buộc #11) trong khi JWT cũ vẫn còn hạn → token hợp lệ nhưng user không còn trong DB. Phải trả 401 để app đăng nhập lại, không được lỗi 500. | Suy ra từ #11 |
| F8 | *(Ngoài phạm vi, ghi nhận cho giai đoạn 5)* `configureApp()` chưa bật CORS. Flutter web chạy ở cổng khác sẽ bị trình duyệt chặn, nhất là khi gửi header `Authorization`. | Đọc `app.setup.ts` |

## 4. Các hướng tiếp cận

Ba câu hỏi thiết kế độc lập; mỗi câu có một lựa chọn khuyến nghị.

### 4.1. Driver SQLite

| Lựa chọn | Ưu | Nhược |
|---|---|---|
| **`better-sqlite3@12`** *(khuyến nghị)* | Đúng BRD; file DB thật, ghi từng thay đổi; nhanh; phổ biến | Binary native (có bản dựng sẵn cho Windows/macOS/Linux); phải ghim bản 12 và duyệt install script |
| `sqljs` (WebAssembly) | Không có binary native nào, chạy mọi nơi | Nạp cả DB vào RAM và ghi lại **toàn bộ file** mỗi lần lưu; dễ mất dữ liệu nếu tiến trình chết giữa lúc ghi |

Hai driver dùng chung entity, đổi qua lại chỉ là đổi cấu hình — nếu máy của thành viên nào không lấy được binary dựng sẵn, chuyển sang `sqljs` mà không sửa entity.

### 4.2. Tạo bảng

| Lựa chọn | Ưu | Nhược |
|---|---|---|
| **Migration** *(khuyến nghị)* — một migration đầu tiên viết bằng API `Table` của TypeORM (không phải SQL riêng của SQLite), `migrationsRun: true` khi khởi động | Không bao giờ tự xoá cột/dữ liệu; chạy được cả SQLite lẫn Postgres; test dùng đúng migration đó nên kiểm luôn migration | Thêm một file; sửa entity về sau phải viết thêm migration |
| `synchronize: true` | Không phải viết gì | TypeORM tự sửa bảng theo entity, có thể **xoá cột và dữ liệu** khi đổi entity — nguy hiểm khi đã deploy |

### 4.3. Kiểm tra đăng nhập

| Lựa chọn | Ưu | Nhược |
|---|---|---|
| **Guard tự viết + `JwtService`** *(khuyến nghị)* — đúng cách tài liệu NestJS phần Authentication hướng dẫn | Ít thư viện; đọc là hiểu; guard "tuỳ chọn" viết gọn | Tự viết khoảng 40 dòng |
| Passport (`@nestjs/passport`, `passport-jwt`) | Mẫu phổ biến | Thêm 3 thư viện và một lớp trừu tượng cho chỉ 1 kiểu token; guard "tuỳ chọn" (không token vẫn qua, token sai thì 401) phải vặn cấu hình |

Xác minh token Google đặt sau một provider `IdTokenVerifier` có hai bản: bản `mock` (kiểm định dạng `mock:<email>`) và bản `google` (`OAuth2Client.verifyIdToken`, `audience` = `GOOGLE_CLIENT_ID`). Chọn theo `AUTH_MODE` khi khởi động; test thay bằng bản giả — không bao giờ gọi Google (#17).

## 5. Thiết kế đề xuất (để `/feature-plan` chi tiết hoá)

**Entity** — kiểu cột ghi rõ, chỉ dùng kiểu có ở cả SQLite và Postgres:

- `User`: `id` (UUID, server sinh), `google_sub` (duy nhất; bản mock dùng `mock:<email>`), `email`, `name`, `created_at`.
- `PlanRecord`: `id` = `plan_id` của plan (UUID do server gán — #16), `user` (xoá user thì xoá theo), `target_calories` (để trả danh sách không phải đọc JSON), `plan_json` (`simple-json` — đúng `MealPlanResponseDto`, **không chứa `restrictions`** — #12), `created_at`.

**Cấu hình** (`.env`): `DATABASE_PATH` (mặc định `database.sqlite`, như BRD mục 4), `AUTH_MODE` (mặc định `mock`), `GOOGLE_CLIENT_ID` (có thể nhiều, cách nhau dấu phẩy — web/Android/iOS có Client ID khác nhau), `JWT_SECRET`, `JWT_EXPIRES_IN` (mặc định `7d`). `AUTH_MODE=google` mà thiếu `JWT_SECRET` hoặc `GOOGLE_CLIENT_ID` → không cho khởi động.

**Luồng:**

- `POST /api/v1/auth/google { id_token }` → xác minh → tìm hoặc tạo user theo `google_sub` → JWT chỉ chứa `sub` = user id (không email, không dữ liệu sức khoẻ) → `{ access_token, user }` (BRD 6.3).
- `generate-plan` + token hợp lệ → lưu `PlanRecord`. Lưu thất bại (DB lỗi) → **vẫn trả plan**, thêm cảnh báo "Chưa lưu được vào lịch sử" vào `warnings` — người dùng không mất plan chỉ vì lịch sử lỗi.
- `GET /plans/history` → 50 plan mới nhất `{ id, created_at, target_calories }` (BRD 6.3). `GET /plans/history/:id` → `id` không phải UUID → 400; không có hoặc của người khác → **404** (không để lộ plan đó có tồn tại).

## 6. Edge case

- **Token hết hạn / sai chữ ký / sai định dạng** → 401, app đăng nhập lại (PLAN 8.2).
- **Token hợp lệ nhưng user không còn trong DB** (F7) → 401, không phải 500.
- **Hai lần đăng nhập đầu tiên cùng lúc** của cùng một tài khoản → trùng khoá duy nhất `google_sub` → bắt lỗi rồi đọc lại user, không trả 500.
- **Google trả `email_verified: false`** → từ chối (401).
- **`id_token` thiếu hoặc không phải chuỗi** → 400 (validate DTO); **token không xác minh được** → 401.
- **Test không đụng file DB thật và không gọi Google:** e2e ghim `DATABASE_PATH=:memory:`, `AUTH_MODE=mock` trước khi nạp `AppModule` (giống cách ghim Gemini ở giai đoạn 2); nhánh `google` test bằng `IdTokenVerifier` giả.
- **Lịch sử không chứa dữ liệu sức khoẻ:** test e2e gửi chuỗi bí mật trong `restrictions`, đọc lại plan từ lịch sử, kiểm không có chuỗi đó (#12).
- **CI:** `npm ci` trên GitHub cần tải được binary `better-sqlite3` cho Linux Node 24/26; nếu job đỏ vì binary, chuyển driver sang `sqljs`.

## 7. Câu hỏi mở — cần trả lời trước `/feature-plan`

1. **Driver:** `better-sqlite3@12` (khuyến nghị) hay `sqljs`?
2. **Tạo bảng:** migration (khuyến nghị) hay `synchronize`?
3. **Chế độ đăng nhập giả lập khi deploy (F6):** (a) chặn mặc định — khi `NODE_ENV=production` mà `AUTH_MODE=mock` thì không cho khởi động, trừ khi đặt thêm `ALLOW_MOCK_AUTH=true` cho buổi demo có chủ đích *(khuyến nghị)*; (b) luôn cho phép, chỉ cảnh báo trong log và `/health`; (c) cấm hẳn khi deploy.
4. **Xoá tài khoản:** thêm `DELETE /api/v1/me` (xoá user và toàn bộ lịch sử)? Không có trong BRD, nhưng quyền yêu cầu xoá dữ liệu cá nhân là một quyền của người dùng theo Nghị định 13/2023/NĐ-CP; làm thêm khoảng 20 dòng code và 2 test.

## 8. Quyết định (2026-09-24)

| Câu hỏi | Quyết định |
|---|---|
| Q1 | **`better-sqlite3@12`**, duyệt install script tường minh trong `package.json`. |
| Q2 | **Migration** — một migration đầu tiên viết bằng API `Table` của TypeORM, `migrationsRun: true`, `synchronize: false`. |
| Q3 | **Chặn mặc định, mở bằng cờ:** `NODE_ENV=production` + `AUTH_MODE=mock` → không khởi động, trừ khi đặt `ALLOW_MOCK_AUTH=true`. |
| Q4 | **Có** `DELETE /api/v1/me` (cần đăng nhập, trả 204, xoá user và toàn bộ `PlanRecord`). Đây là thay đổi phạm vi → BRD nâng lên **v2.4.0** (thêm FR-6.4, mục 6.3, NFR-5 về chặn đăng nhập giả lập khi deploy). |

**Bước tiếp theo:** `/feature-plan phase-3-auth-history`.
