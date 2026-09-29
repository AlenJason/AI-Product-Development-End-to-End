---
last_updated: 2026-09-24
tags: [auth, jwt, google-sign-in, sqlite, typeorm, lich-su]
---

# Tài khoản & lịch sử kế hoạch

Backend có đăng nhập Google (FR-6) và lịch sử kế hoạch xem được trên mọi thiết bị (FR-7), xây ở giai đoạn 3. Bài này ghi cách các phần nối với nhau, những hành vi thư viện đã kiểm chứng ngày 2026-09-24, và cách test mà không gọi Google hay đụng file DB thật. Ràng buộc liên quan: [[critical-constraints]] #10–#12, #17–#22. Hợp đồng plan: [[plan-data-contract]]. Hướng dẫn gắn Client ID thật: `docs/SETUP_CREDENTIALS.md` mục 2.

## Thành phần

| Thư mục | Vai trò |
|---|---|
| `backend_api/src/database/` | Entity `User`, `PlanRecord`; migration `InitialSchema1790208000000`; `dataSourceOptions()` dùng chung cho app và test; `DatabaseModule` (TypeORM + `better-sqlite3`) |
| `backend_api/src/auth/` | `resolveAuthConfig()` kiểm cấu hình lúc khởi động; `IdTokenVerifier` (bản `Mock…` / `Google…`); `AuthService` (đăng nhập, xác thực JWT, xoá tài khoản); `JwtAuthGuard`, `OptionalJwtAuthGuard`, `@CurrentUser()`; `POST /api/v1/auth/google`, `DELETE /api/v1/me` |
| `backend_api/src/history/` | `HistoryService` (lưu, liệt kê 50 plan mới nhất, xem lại); `GET /api/v1/plans/history`, `/:id` |
| `backend_api/src/plan/plan.controller.ts` | `generate-plan` với guard tuỳ chọn: có user thì lưu; lưu lỗi thì thêm cảnh báo, vẫn trả plan |

## Luồng

1. App gửi `id_token` → `IdTokenVerifier` (chọn theo `AUTH_MODE`) trả `{ sub, email, name }`.
2. `AuthService` tìm user theo `google_sub`; chưa có thì tạo. Nếu hai request đăng nhập lần đầu chạy cùng lúc, request thua đụng khoá duy nhất và đọc lại user.
3. Backend phát JWT HS256, payload chỉ có `sub` = id người dùng, hết hạn theo `JWT_EXPIRES_IN`.
4. Mỗi request có token: guard kiểm chữ ký và hạn dùng, rồi **tra user trong DB**. Token hợp lệ mà user đã bị xoá (xoá tài khoản, DB bị làm mới trên host không có ổ bền) → 401, không phải 500.

## Cấu hình

| Biến | Mặc định | Ghi chú |
|---|---|---|
| `DATABASE_PATH` | `database.sqlite` | tính từ thư mục chạy backend; test dùng `:memory:` |
| `AUTH_MODE` | `mock` | `mock` \| `google` |
| `GOOGLE_CLIENT_ID` | — | bắt buộc khi `google`; nhiều giá trị cách nhau dấu phẩy |
| `JWT_SECRET` | secret dev (chỉ `mock`) | bắt buộc ≥ 32 ký tự khi `google` |
| `JWT_EXPIRES_IN` | `7d` | `<số dương><s\|m\|h\|d>` |
| `ALLOW_MOCK_AUTH` | — | `true` mới cho `mock` chạy khi `NODE_ENV=production` |

Cấu hình sai → backend không khởi động và in lý do (xem bảng lỗi trong `SETUP_CREDENTIALS.md` mục 2.5).

## Hành vi thư viện đã kiểm chứng (2026-09-24)

| Thư viện | Hành vi | Hệ quả trong code |
|---|---|---|
| TypeORM 1.1.1 | Bỏ driver `sqlite3`, không có driver `node:sqlite`; SQLite chỉ còn `better-sqlite3` và `sqljs`. Peer dependency `better-sqlite3 ^12` (bản mới nhất là 13) | Ghim `better-sqlite3@12`, duyệt install script bằng `npm install-scripts approve better-sqlite3` |
| TypeORM + SQLite | Mặc định của `@CreateDateColumn` là `datetime('now')`, chỉ chính xác tới giây | `plan_records.created_at` là cột thường, code gán `new Date()` (lưu tới mili-giây, UTC) |
| TypeORM + SQLite | `@PrimaryGeneratedColumn('uuid')` sinh cột `varchar` không có độ dài | Migration phải ghi đúng như vậy; `migrations.spec.ts` so schema diff để bắt lệch |
| TypeORM + SQLite | Vi phạm khoá duy nhất → `QueryFailedError`, `driverError.code = 'SQLITE_CONSTRAINT_UNIQUE'` (Postgres: `23505`) | `isUniqueViolation()` nhận cả hai |
| TypeORM + better-sqlite3 | `PRAGMA foreign_keys` bật sẵn | `ON DELETE CASCADE` hoạt động: xoá user xoá luôn plan |
| TypeScript ESM + `emitDecoratorMetadata` | Hai entity import lẫn nhau: bản build ghi `design:type` trỏ tới class chưa khởi tạo → `ReferenceError` lúc khởi động. Vitest **không** bắt được | Quan hệ khai báo bằng `Relation<...>`; `npm run test:smoke` chạy bản build trong CI |
| `google-auth-library` 11.1.0 | `verifyIdToken()` **không có `audience` thì chấp nhận token của app khác** | `GoogleIdTokenVerifier` không cho tạo khi danh sách Client ID rỗng; test khoá lại |
| `google-auth-library` 11.1.0 | Thông báo lỗi chép nguyên token/payload (có email) sau dấu `:` | Chỉ log phần trước dấu `:` |
| `google-auth-library` 11.1.0 | Chứng chỉ Google lấy qua `getFederatedSignonCertsAsync()` và cache theo `Cache-Control` | Test thay hàm này bằng khoá RSA tự tạo — chạy offline, vẫn dùng code kiểm chữ ký thật |
| `@nestjs/jwt` 12 | `expiresIn` có kiểu `StringValue \| number` (gói `ms`), `string` từ `.env` không qua `tsc` | `resolveAuthConfig()` tự đổi `7d` ra số giây |
| `@nestjs/typeorm` 12 | Mặc định thử kết nối lại 9 lần × 3 giây | `retryAttempts: 0` — lỗi mở file SQLite không tự hết |

## Test không cần Google, không đụng DB thật

- Unit: `createMemoryDataSource()` (`backend_api/test/memory-data-source.ts`) mở SQLite trong RAM bằng đúng migration của app. `AuthService` và `HistoryService` được test trên DB đó, không mock repository.
- `GoogleIdTokenVerifier`: ký ID Token bằng khoá RSA tạo trong test, thay chỗ tải chứng chỉ Google.
- E2E: `createTestApp()` (`backend_api/test/test-app.ts`) ghim `DATABASE_PATH=:memory:`, `AUTH_MODE=mock`, các biến JWT/Google, `GEMINI_*` trước khi nạp `AppModule`, và trả lại khi đóng. `loginMock()` đăng nhập bằng `mock:<email>`.
- Smoke: `npm run test:smoke` chạy `dist/main.js` và gọi 5 request (#20).

## Việc để sau

- **CORS** chưa bật: Flutter web chạy ở cổng khác sẽ bị trình duyệt chặn, nhất là khi có header `Authorization` — PLAN 5.7.
- **Chuyển sang Postgres** (nếu host không có ổ bền, #11): đổi `type` trong `dataSourceOptions()`. Entity dùng kiểu chung, nhưng migration hiện có biểu thức SQLite (`datetime('now')`), nên cần viết một migration khởi tạo mới cho Postgres.
