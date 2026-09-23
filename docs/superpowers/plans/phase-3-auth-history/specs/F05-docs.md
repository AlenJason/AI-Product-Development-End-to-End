# F05 — BRD v2.4.0, hướng dẫn Google Sign-In, wiki, CLAUDE.md, README, PLAN.md

## Feature

Ghi lại phạm vi mới và những gì học được ở giai đoạn 3:

- **BRD v2.4.0** (quyết định Q4 là thay đổi phạm vi): FR-6.4 xoá tài khoản; mục 6.3 ghi đủ mã lỗi, giới hạn lịch sử, `DELETE /api/v1/me`, cách `generate-plan` xử lý token; NFR-5 thêm quy tắc chặn đăng nhập giả lập khi deploy (Q3) và yêu cầu cấu hình chế độ google; mục 4 ghi driver `better-sqlite3`.
- **`SETUP_CREDENTIALS.md` mục 2** (PLAN 3.7): chế độ giả lập, tạo OAuth Client ID, điền `.env`, kiểm tra, lỗi thường gặp. Phần Flutter vẫn để giai đoạn 8.
- **Wiki:** bài mới `auth-and-history.md`; ràng buộc #10, #12, #17, #18 cập nhật, thêm #19–#22; trigger cho `src/auth/`, `src/database/`, `src/history/`.
- **CLAUDE.md, README (Changelog), PLAN.md** (đánh dấu 3.1–3.9, thêm bước CORS vào giai đoạn 5 theo brainstorm F8).

## Scope

Docs:

- `BRD.md`
- `docs/SETUP_CREDENTIALS.md`
- `docs/knowledge/wiki/auth-and-history.md` (mới), `critical-constraints.md`, `INDEX.md`, `wiki-triggers.md`, `log.md`
- `docs/knowledge/CLAUDE.md`
- `CLAUDE.md`, `README.md`, `docs/PLAN.md`

## Implementation

### API Routes

Không sửa code.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

Feature này thêm #19–#22 và cập nhật #10, #12, #17, #18 trong `critical-constraints.md`.

## Definition of Done

- [ ] BRD ghi `**Phiên bản:** 2.4.0`, có FR-6.4 và `DELETE /api/v1/me` ở mục 6.3
- [ ] `SETUP_CREDENTIALS.md` không còn chữ "Chưa có trong code"
- [ ] `critical-constraints.md` có #1–#22; `auth-and-history.md` có trong `INDEX.md`; mọi `[[link]]` trỏ tới file có thật
- [ ] PLAN.md: 3.1–3.9 đều `[x]`, có bước 5.7 (CORS)
- [ ] README có mục Changelog `BRD v2.4.0`
- [x] All API routes complete within deployment timeout — không áp dụng
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: `grep -c '^- \[x\] \*\*3\.' docs/PLAN.md` → `9`; `grep -c 'auth-and-history' docs/knowledge/wiki/INDEX.md` → `1`; `grep -cE '^\| (19|20|21|22) \|' docs/knowledge/wiki/critical-constraints.md` → `4`
2. **@auth**: không áp dụng
3. **@timeout**: không áp dụng
4. **@partial-fail**: `grep -o '\[\[[a-z-]*\]\]' docs/knowledge/wiki/*.md | sort -u` — mỗi tên có file `docs/knowledge/wiki/<tên>.md`
5. **@token**: không áp dụng
6. **@db**: không áp dụng

## Tasks

### Task 1 — `BRD.md` → v2.4.0

1. Dòng phiên bản: `**Phiên bản:** 2.3.0 (…)` → `**Phiên bản:** 2.4.0 (Dành cho Sinh viên thực hành: Flutter & NestJS)`. Ngày cập nhật giữ `24/09/2026`.

2. Mục 4, gạch đầu dòng **SQLite + TypeORM** — thay bằng:

```markdown
  * **SQLite + TypeORM** (`@nestjs/typeorm`, driver `better-sqlite3` bản 12 — TypeORM 1.x không còn driver `sqlite3`): file DB dạng `database.sqlite` ngay trong `backend_api/` (đổi bằng `DATABASE_PATH`), không cần cài đặt server DB riêng — đúng tinh thần "môi trường chạy đơn giản" (NFR mục 7). Bảng được tạo bằng migration chạy tự động khi khởi động, không dùng `synchronize`. File DB phải được thêm vào `.gitignore` vì có thể chứa dữ liệu người dùng thật khi demo.
```

3. Mục 5, FR-6 — thêm sau FR-6.3:

```markdown
* **FR-6.4** *(bổ sung bản 2.4.0)*: Người dùng tự xoá được tài khoản của mình: backend xoá tài khoản cùng toàn bộ lịch sử kế hoạch (`DELETE /api/v1/me`). Đây là quyền yêu cầu xoá dữ liệu cá nhân theo Nghị định 13/2023/NĐ-CP.
```

4. Mục 6.3 — thay toàn bộ (từ tiêu đề `### 6.3.` tới trước `### 6.4.`) bằng:

````markdown
### 6.3. Xác thực & Lịch sử (bổ sung bản 2.2.0, chi tiết hoá ở bản 2.4.0)

**`POST /api/v1/auth/google`** — request:
```json
{ "id_token": "eyJhbGciOi..." }
```
Response (200):
```json
{
  "access_token": "eyJhbGciOi...",
  "user": { "id": "uuid", "email": "sv@vku.edu.vn", "name": "Nguyễn Văn A" }
}
```
`id_token` thiếu hoặc không phải chuỗi → 400. Token không xác minh được (sai chữ ký, hết hạn, cấp cho app khác, email chưa xác minh) → 401. Ở chế độ đăng nhập giả lập (`AUTH_MODE=mock`, mặc định khi phát triển), backend nhận `"id_token": "mock:<email>"` thay cho token Google thật.

`access_token` là JWT của SmartFit: hết hạn sau 7 ngày, chỉ chứa id người dùng. Các API cần đăng nhập nhận nó qua header `Authorization: Bearer <access_token>` và trả **401** khi thiếu token, token sai hoặc hết hạn, hoặc tài khoản đã bị xoá.

**`GET /api/v1/plans/history`** — cần đăng nhập. Tối đa 50 kế hoạch, mới nhất trước; `created_at` theo ISO 8601 (UTC). Response:
```json
{
  "plans": [
    { "id": "uuid", "created_at": "2026-09-22T10:00:00.000Z", "target_calories": 1850 }
  ]
}
```

**`GET /api/v1/plans/history/:id`** — cần đăng nhập. Response: đúng cấu trúc `MealPlanResponse` như mục 6.2, giống hệt lúc tạo. `id` không phải UUID → 400; không có, hoặc là plan của tài khoản khác → 404.

**`DELETE /api/v1/me`** *(bổ sung bản 2.4.0, FR-6.4)* — cần đăng nhập. Xoá tài khoản và toàn bộ lịch sử; trả 204, không có nội dung. Token cũ không dùng được nữa.

**Lưu lịch sử khi tạo plan (FR-7.1):** `POST /api/v1/generate-plan` không có header `Authorization` → chạy như khách, không lưu. Có header với token hợp lệ → lưu plan; nếu lưu lỗi, vẫn trả plan và thêm một câu vào `warnings`. Có header nhưng token sai hoặc hết hạn → 401, để app biết cần đăng nhập lại thay vì âm thầm không lưu.
````

5. Mục 7, NFR-5 — thêm hai gạch đầu dòng cuối:

```markdown
   * JWT chỉ chứa id người dùng, không chứa email hay dữ liệu sức khoẻ. Chế độ `AUTH_MODE=google` bắt buộc có `GOOGLE_CLIENT_ID` và `JWT_SECRET` dài ít nhất 32 ký tự; thiếu thì backend không khởi động. *(bổ sung bản 2.4.0)*
   * Đăng nhập giả lập (`AUTH_MODE=mock`) cho phép bất kỳ ai đăng nhập thành người khác, nên chỉ dùng khi phát triển hoặc demo: backend **không khởi động** khi `NODE_ENV=production` mà vẫn để `AUTH_MODE=mock`, trừ khi đặt `ALLOW_MOCK_AUTH=true` có chủ đích cho buổi demo không có dữ liệu thật. *(bổ sung bản 2.4.0)*
```

6. Mục 8, dòng **Tuần 6** — `hoàn thiện `/api/v1/auth/google`, `/api/v1/plans/history`;` → `hoàn thiện `/api/v1/auth/google`, `/api/v1/plans/history`, `DELETE /api/v1/me`;`

### Task 2 — `docs/SETUP_CREDENTIALS.md`

1. Câu mở đầu: `(hoặc đăng nhập Google thật, sau khi phần đó được làm)` → `(hoặc đăng nhập Google thật)`.
2. Bảng trạng thái, dòng backend: `| Google Sign-In — backend | Đã có | [Mục 2](#2-google-sign-in) |`.
3. Thay toàn bộ mục 2 bằng:

````markdown
## 2. Google Sign-In

### 2.1. Chế độ giả lập (mặc định)

Backend mặc định chạy `AUTH_MODE=mock`: `POST /api/v1/auth/google` nhận `{"id_token": "mock:<email>"}` (ví dụ `mock:sv@vku.edu.vn`) thay cho token Google thật. Phần còn lại chạy thật: tạo tài khoản trong file DB, phát JWT, lưu và xem lịch sử. Không cần tài khoản Google Cloud.

Thử trên Swagger (`http://localhost:3000/docs`):

1. `POST /api/v1/auth/google` với `{"id_token": "mock:sv@vku.edu.vn"}` → copy `access_token`.
2. Bấm **Authorize** (góc trên bên phải), dán `access_token`, bấm **Authorize**.
3. Gọi `POST /api/v1/generate-plan`, rồi `GET /api/v1/plans/history` → thấy plan vừa tạo.

> Ở chế độ giả lập, ai gửi `mock:<email>` cũng đăng nhập được thành email đó và đọc được lịch sử của người đó. Vì vậy backend **từ chối khởi động** khi `NODE_ENV=production` mà vẫn để `AUTH_MODE=mock`. Chỉ đặt `ALLOW_MOCK_AUTH=true` khi cố ý deploy một bản demo không có dữ liệu thật.

### 2.2. Tạo OAuth Client ID

1. Mở trang **Clients** của Google Auth Platform: [console.developers.google.com/auth/clients](https://console.developers.google.com/auth/clients). Chọn hoặc tạo một project (có thể dùng chung project với Gemini).
2. Nếu được yêu cầu, điền trang **Branding** (tên app, email hỗ trợ). Phạm vi mặc định cho đăng nhập là đủ, không cần thêm scope nào.
3. Bấm **Create client**, chọn **Web application**. Ở **Authorized JavaScript origins**, thêm địa chỉ chạy Flutter web khi phát triển: `http://localhost` và `http://localhost:<cổng>`. Nên chạy Flutter web ở cổng cố định, ví dụ `flutter run -d chrome --web-port 5000`.
4. Copy **Client ID**, dạng `1234567890-abc123def456.apps.googleusercontent.com`.
5. Trang **Audience**: khi app còn ở trạng thái *Testing*, chỉ các tài khoản trong danh sách **Test users** đăng nhập được. Thêm email của các thành viên nhóm và người chấm demo.

Client ID không phải bí mật (nó nằm sẵn trong app). **Client secret** thì là bí mật — backend không cần nó, đừng copy vào `.env` hay vào app.

Cấu hình phía Flutter (Client ID cho Android/iOS, SHA-1, thẻ meta cho bản web) làm ở [PLAN.md](PLAN.md) bước 8.4. Trên Android/iOS, app thường xin ID Token cho Web Client ID (tham số `serverClientId`), nên backend chỉ cần Web Client ID.

### 2.3. Điền vào backend

Mở `backend_api/.env`:

```
AUTH_MODE=google
GOOGLE_CLIENT_ID=<Web Client ID vừa copy>
JWT_SECRET=<chuỗi ngẫu nhiên, ít nhất 32 ký tự>
JWT_EXPIRES_IN=7d
```

Tạo `JWT_SECRET`:

```bash
openssl rand -base64 48
# hoặc, không có openssl:
node -e "console.log(require('node:crypto').randomBytes(48).toString('base64'))"
```

- `GOOGLE_CLIENT_ID` nhận nhiều giá trị cách nhau dấu phẩy, khi app gửi ID Token cấp cho nhiều Client ID khác nhau (ví dụ Web và iOS).
- Đổi `JWT_SECRET` thì mọi phiên đăng nhập cũ hết hiệu lực: người dùng phải đăng nhập lại, dữ liệu không mất.
- `DATABASE_PATH` (mặc định `database.sqlite`, tính từ thư mục chạy backend) là file chứa tài khoản và lịch sử. File này đã nằm trong `.gitignore`.

Khởi động lại backend. Thiếu `GOOGLE_CLIENT_ID`, hoặc `JWT_SECRET` ngắn hơn 32 ký tự → backend dừng ngay lúc khởi động và in lý do.

### 2.4. Kiểm tra

1. `http://localhost:3000/health` phải có `"auth_mode":"google"`.
2. Gửi `POST /api/v1/auth/google` với `{"id_token": "abc"}` → 401, và terminal backend có dòng `Từ chối Google ID Token: Wrong number of segments in token`. Nghĩa là backend đang xác minh bằng Google và không còn nhận `mock:`.
3. Kiểm tra trọn vẹn (đăng nhập bằng tài khoản Google thật) cần nút đăng nhập trong app Flutter — [PLAN.md](PLAN.md) giai đoạn 8.

### 2.5. Lỗi thường gặp

| Hiện tượng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| Backend dừng lúc khởi động: `AUTH_MODE=google cần GOOGLE_CLIENT_ID` hoặc `cần JWT_SECRET dài ít nhất 32 ký tự` | Thiếu hoặc sai biến trong `.env` | Điền theo mục 2.3 |
| Backend dừng: `Không khởi động với AUTH_MODE=mock khi NODE_ENV=production` | Deploy mà vẫn để đăng nhập giả lập | Đặt `AUTH_MODE=google` (hoặc `ALLOW_MOCK_AUTH=true` nếu cố ý demo giả lập) |
| Đăng nhập trả 401, log: `Wrong recipient, payload audience != requiredAudience` | ID Token được cấp cho một Client ID khác với `GOOGLE_CLIENT_ID` | Thêm Client ID đó vào `GOOGLE_CLIENT_ID`, hoặc sửa `serverClientId` phía Flutter |
| 401, log: `Token used too late` | ID Token Google đã hết hạn (khoảng 1 giờ), hoặc đồng hồ máy chạy backend bị lệch | App lấy token mới rồi gửi ngay; kiểm tra giờ hệ thống |
| 401 `Tài khoản Google chưa xác minh email` | Tài khoản Google chưa xác minh email | Dùng tài khoản khác |
| Không đăng nhập được bằng một tài khoản cụ thể | App đang ở trạng thái *Testing*, tài khoản chưa có trong **Test users** | Thêm vào trang **Audience** |
| Mọi API cần đăng nhập trả 401 sau khi khởi động lại hoặc deploy lại | Đã đổi `JWT_SECRET`; hoặc file DB bị xoá (host không có ổ lưu trữ bền) | Đăng nhập lại. Nếu mất cả lịch sử, xem lại nơi deploy ([PLAN.md](PLAN.md) bước 9.1) |

### 2.6. Quay lại chế độ giả lập

Đặt `AUTH_MODE=mock` (hoặc xoá dòng đó), khởi động lại backend. Tài khoản đã tạo bằng Google thật vẫn nằm trong DB, nhưng không đăng nhập được bằng `mock:<email>` vì định danh khác nhau.

### 2.7. Bảo mật

- `JWT_SECRET` bảo vệ giống khoá Gemini (mục 1.7): chỉ nằm trong `.env`, không commit; khi deploy thì khai báo trên trang cấu hình của host.
- Không commit file DB (`*.sqlite`) — nó chứa email và tên người dùng thật.
- JWT chỉ chứa id người dùng. Log của backend không ghi token hay email khi từ chối đăng nhập.
````

### Task 3 — Bài wiki `docs/knowledge/wiki/auth-and-history.md`

````markdown
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
````

### Task 4 — `docs/knowledge/wiki/critical-constraints.md`

1. `last_updated: 2026-09-24` giữ nguyên.
2. Câu mở đầu: `…trước khi đụng vào `backend_api/src/plan/`, prompt Gemini, hoặc hợp đồng request/response.` → `…trước khi đụng vào `backend_api/src/` (plan, auth, database, history), prompt Gemini, hoặc hợp đồng request/response.`
3. Thay dòng #10:

```markdown
| 10 | Xác thực **chỉ** qua Google Sign-In: `google-auth-library` xác minh ID Token phía backend, backend phát JWT riêng qua `@nestjs/jwt` (`backend_api/src/auth/`). Backend **không được tự lưu hoặc xử lý mật khẩu** người dùng dưới bất kỳ hình thức nào. Lưu trữ dùng SQLite qua `@nestjs/typeorm`, driver `better-sqlite3` bản 12 (`backend_api/src/database/`); `*.sqlite` nằm trong `.gitignore`. | Quyết định 2026-09-22 (BRD mục 4, FR-6, FR-7, NFR-5), có code từ giai đoạn 3. Tự lưu mật khẩu là rủi ro bảo mật không cần thiết khi Google đã lo phần đó. TypeORM 1.x không còn driver `sqlite3` và chỉ nhận `better-sqlite3 ^12` — xem [[auth-and-history]]. |
```

4. Dòng #12, cột quy tắc: `…**không** lưu vào DB (kể cả `PlanRecord` ở giai đoạn 3)…` → `…**không** lưu vào DB (`PlanRecord.plan_json` là response đã trả, vốn không có `restrictions` — `history.e2e-spec.ts` kiểm trực tiếp trong DB)…`
5. Thay dòng #17:

```markdown
| 17 | Test **không bao giờ** gọi Gemini hay Google thật, và không đụng file DB thật. Test cần Gemini dùng server giả `backend_api/test/fake-gemini-server.ts` qua `GEMINI_BASE_URL`. E2E tạo app bằng `createTestApp()` (`backend_api/test/test-app.ts`), hàm này ghim `DATABASE_PATH=:memory:`, `AUTH_MODE=mock`, biến JWT/Google và `GEMINI_*` **trước** khi nạp `AppModule`. Unit test cần DB dùng `createMemoryDataSource()`. Xác minh Google ID Token được test bằng khoá RSA tự tạo. `GEMINI_BASE_URL` luôn để trống khi chạy thật và khi deploy. | Máy dev có thể có khoá thật, `AUTH_MODE=google` hay file DB trong `.env`: test gọi thật sẽ chậm, tốn hạn mức, kết quả không cố định, gửi dữ liệu test ra ngoài, hoặc ghi vào DB thật. CI không có khoá nào nên cũng không chạy được test gọi thật. |
```

6. Dòng #18, cột quy tắc: `Cấu hình app (`ValidationPipe`, Swagger) chỉ nằm ở…` → `Cấu hình app (`ValidationPipe`, Swagger kèm `addBearerAuth()`) chỉ nằm ở…`
7. Thêm 4 dòng sau #18:

```markdown
| 19 | Schema DB chỉ đổi qua **migration** (`backend_api/src/database/migrations/`, chạy tự động nhờ `migrationsRun: true`). **Không bao giờ** bật `synchronize`. Đổi entity → viết migration mới, thêm vào mảng `migrations` trong `dataSourceOptions()`; `migrations.spec.ts` so schema diff của TypeORM và in ra đúng câu SQL còn thiếu. | Quyết định Q2 giai đoạn 3. `synchronize` tự sửa bảng theo entity và có thể xoá cột kèm dữ liệu khi đã deploy. Migration đầu tiên từng lệch entity ở hai chỗ (độ dài `id`, mặc định `created_at`) mà không test nào khác phát hiện. |
| 20 | Quan hệ giữa hai entity import lẫn nhau phải khai báo kiểu `Relation<...>` (từ `typeorm`). Mọi thay đổi có thể chỉ hỏng khi chạy bản build (entity, asset, cách nạp module) phải qua `npm run build && npm run test:smoke`; CI chạy bước này sau e2e. | Phát hiện khi lập plan giai đoạn 3: thiếu `Relation<>` → bản build ESM ném `ReferenceError: Cannot access 'User' before initialization` lúc khởi động, trong khi toàn bộ unit test và e2e (chạy qua vitest) vẫn xanh. Cùng loại với lỗi thiếu asset ở #5. |
| 21 | Đăng nhập: `AUTH_MODE=mock` **không** được chạy khi `NODE_ENV=production`, trừ khi `ALLOW_MOCK_AUTH=true`. Chế độ `google` bắt buộc `GOOGLE_CLIENT_ID` và `JWT_SECRET` ≥ 32 ký tự. `verifyIdToken()` luôn truyền `audience`; định danh bằng `sub`, không bằng email; từ chối `email_verified` khác `true`. JWT ký HS256, payload chỉ có `sub` = id người dùng. Không log `error.message` của `google-auth-library`. Cả hai ràng buộc cấu hình được kiểm lúc khởi động trong `resolveAuthConfig()`. | Quyết định Q3 giai đoạn 3 (BRD NFR-5 v2.4.0): ở chế độ mock, ai cũng đăng nhập được thành người khác và đọc lịch sử của họ. Đã kiểm bằng thư viện thật: thiếu `audience` thì token cấp cho app khác vẫn qua; thông báo lỗi của thư viện chứa token và email (NFR-7). |
| 22 | API cần đăng nhập: thiếu token / token sai / hết hạn / user không còn trong DB → **401**, không bao giờ 500. Plan của người khác → **404** như plan không tồn tại. `generate-plan` có header `Authorization` mà token sai → 401 (không âm thầm chạy như khách); không có header → chạy như khách. Lưu lịch sử lỗi → vẫn trả plan kèm cảnh báo `historyNotSaved`. | BRD mục 6.3 (v2.4.0). Token còn hạn nhưng DB đã bị làm mới là chuyện thường gặp trên host không có ổ bền (#11). 404 thay cho 403 để không lộ `id` nào có thật. |
```

### Task 5 — `INDEX.md`, `wiki-triggers.md`, `log.md`, `docs/knowledge/CLAUDE.md`

`docs/knowledge/wiki/INDEX.md` — thêm dòng trước `[[log]]`:

```markdown
| [[auth-and-history]]        | Đăng nhập Google/giả lập, JWT, guard, SQLite + migration, lịch sử kế hoạch; hành vi thư viện đã kiểm chứng |
```

`docs/knowledge/wiki/wiki-triggers.md`:

- Thay đoạn `Dự án không có `lib/auth/`, `middleware.ts`, hay thư mục database/ORM (…). Thêm vào nếu sau này thay đổi.` bằng: `Auth và database của backend nằm ở `backend_api/src/auth/`, `src/database/`, `src/history/` (từ giai đoạn 3) — trigger ở bảng dưới. Flutter chỉ lưu `access_token` và plan hiện tại bằng `shared_preferences`.`
- Bảng theo đường dẫn — thêm dòng:

```markdown
| `backend_api/src/auth/**`, `backend_api/src/database/**`, `backend_api/src/history/**`, `backend_api/test/test-app.ts`, `backend_api/test/memory-data-source.ts`, `backend_api/scripts/smoke-test.mjs` | `auth-and-history.md` |
```

- Bảng theo từ khoá — thêm dòng:

```markdown
| đăng nhập / auth / JWT / token / Google Sign-In / tài khoản / lịch sử / history / SQLite / TypeORM / migration / database / guard | `auth-and-history.md` |
```

- Danh sách "Trigger bổ sung" — thêm: `- Thêm hoặc sửa entity trong `backend_api/src/database/entities/` (phải kèm migration — `critical-constraints.md` #19)`

`docs/knowledge/wiki/log.md` — thêm cuối file:

```
2026-09-24 — Giai đoạn 3 (PLAN.md): thêm bài [[auth-and-history]] (đăng nhập, JWT, SQLite + migration, lịch sử; hành vi TypeORM 1.x, better-sqlite3 12, google-auth-library 11 đã kiểm chứng); cập nhật ràng buộc #10, #12, #17, #18; thêm #19 (chỉ đổi schema qua migration), #20 (`Relation<>` + smoke test bản build), #21 (cấu hình đăng nhập, chặn mock khi production), #22 (401/404 của API cần đăng nhập); wiki-triggers có trigger auth/database
```

`docs/knowledge/CLAUDE.md`, mảng trọng tâm 5 → `5. Xác thực Google Sign-In + lịch sử kế hoạch qua SQLite/TypeORM (BRD FR-6, FR-7) — có code từ giai đoạn 3, xem [[auth-and-history]]`

### Task 6 — `CLAUDE.md` (gốc repo)

1. Mục "How work is planned", câu mock: `` `AUTH_MODE=mock` (planned, phase 3) → fake Google tokens accepted `` → `` `AUTH_MODE=mock` (default) → `id_token` of the form `mock:<email>` accepted, everything after that (user row, JWT, history) is real; the backend refuses to boot with `NODE_ENV=production` + mock unless `ALLOW_MOCK_AUTH=true` ``
2. Gạch đầu dòng `backend_api/`: thay câu `Google Sign-In, SQLite/TypeORM, and plan history (BRD FR-6, FR-7) are decided but **not built yet** (PLAN.md phase 3).` bằng `Accounts (Google Sign-In, mock mode by default), `DELETE /api/v1/me`, and plan history on SQLite/TypeORM are built (BRD FR-6, FR-7; PLAN.md phase 3).`
3. Khối lệnh Backend — thay 3 dòng:

```bash
cp .env.example .env            # all optional: no GEMINI_API_KEY → sample data; AUTH_MODE=mock → fake logins
npm run test:e2e                # vitest e2e tests (test/*.e2e-spec.ts)
npm run test:smoke              # after npm run build: boots dist/main.js and calls /health, login, generate-plan, history
```

4. Đoạn "Tests never call the real Gemini API…" — thay bằng:

```markdown
Tests never call the real Gemini or Google APIs and never touch a real database file. `test/fake-gemini-server.ts` is a local HTTP server that speaks Gemini's `generateContent` format; the real `@google/genai` SDK is pointed at it through `GEMINI_BASE_URL` (leave that empty in real runs). Every e2e file builds the app through `createTestApp()` (`test/test-app.ts`), which pins `DATABASE_PATH=:memory:`, `AUTH_MODE=mock`, the JWT/Google vars, and `GEMINI_*` *before* dynamically importing `AppModule` (a developer's `.env` may hold real values) and restores them on close; `loginMock()` logs in with `mock:<email>`. Unit tests that need a database use `createMemoryDataSource()` (`test/memory-data-source.ts`), which runs the real migration on an in-memory SQLite. Google ID token verification is tested offline by signing tokens with a throwaway RSA key and stubbing `getFederatedSignonCertsAsync()`. Vitest runs `.ts` sources directly, so it cannot catch failures that only exist in the compiled build (missing assets, ESM circular imports between entities) — `npm run test:smoke` covers those. GitHub Actions (`.github/workflows/backend.yml`) runs build + unit + e2e + smoke on Node 24 and 26 on every push touching `backend_api/` or `ai_workspace/`, with no secrets.
```

5. Mục "Backend architecture" — sửa gạch đầu dòng `/health` thành `…reports whether Gemini is configured (`gemini: "configured" | "fallback"`) and the login mode (`auth_mode: "mock" | "google"`)…`. Thêm ba gạch đầu dòng sau gạch đầu dòng `src/plan/` (trước gạch đầu dòng ESM):

```markdown
- `src/database/` — TypeORM 1.x on SQLite via `better-sqlite3@12` (TypeORM 1.1 only accepts `^12`; there is no `sqlite3` or `node:sqlite` driver). Entities `User` (`google_sub` unique; mock mode uses `mock:<email>`) and `PlanRecord` (`id` = the plan's `plan_id`, `user_id` FK with `ON DELETE CASCADE`, `plan_json` = the exact response, `created_at` set in code with millisecond precision because SQLite's `datetime('now')` default only has seconds). Schema changes go through migrations only (`migrationsRun: true`, never `synchronize`); `migrations.spec.ts` fails with the missing SQL if an entity drifts from the migrations. Relations between the two entities are typed `Relation<...>` — without it the compiled ESM build crashes at boot with `Cannot access 'User' before initialization` while every vitest test still passes.
- `src/auth/` — `resolveAuthConfig()` validates env at boot and throws (so the app does not start) on a bad config: unknown `AUTH_MODE`, google mode without `GOOGLE_CLIENT_ID` or with a `JWT_SECRET` under 32 chars, mock mode with `NODE_ENV=production` unless `ALLOW_MOCK_AUTH=true`. `IdTokenVerifier` is an abstract-class DI token resolved to `MockIdTokenVerifier` or `GoogleIdTokenVerifier` (`google-auth-library`; always passes `audience` — without it tokens issued to other apps are accepted — and never logs the library's error text, which embeds the token and email). `AuthService` find-or-creates users (handles the unique-constraint race), signs HS256 JWTs whose payload is only `sub`, and re-loads the user on every request so a deleted account gets 401. `JwtAuthGuard` (required) / `OptionalJwtAuthGuard` (no header → guest, bad header → 401) and `@CurrentUser()` live in `jwt-auth.guard.ts`. Routes: `POST /api/v1/auth/google`, `DELETE /api/v1/me`.
- `src/history/` — `GET /api/v1/plans/history` (50 newest) and `/:id` (another user's plan → 404, non-UUID → 400). `HistoryService.save()` returns `false` instead of throwing, so `generate-plan` still returns the plan (with a `historyNotSaved` warning) when saving fails.
```

6. Gạch đầu dòng `src/app.setup.ts` — thêm `, with bearer auth so Swagger shows an Authorize button` sau `mounts Swagger at `/docs` (JSON at `/docs-json`)`.

### Task 7 — `README.md`

1. Cấu trúc thư mục, dòng `backend_api/` → `backend_api/     API NestJS — /health, generate-plan (Gemini hoặc thực đơn mẫu), đăng nhập Google, lịch sử kế hoạch (SQLite)`
2. Câu dưới khối cấu trúc → `Dự án chạy được ngay khi chưa có khoá nào (chế độ giả lập: thực đơn mẫu thay cho Gemini, đăng nhập bằng `mock:<email>` thay cho Google). Muốn dùng Gemini hay Google Sign-In thật: xem [docs/SETUP_CREDENTIALS.md](docs/SETUP_CREDENTIALS.md).`
3. Khối lệnh Backend, dòng `cp` → `cp .env.example .env   # để nguyên = chạy giả lập (thực đơn mẫu, đăng nhập giả lập); điền khoá = dùng thật`
4. Mục Changelog — thêm trên `### BRD v2.3.0`:

```markdown
### BRD v2.4.0 — 2026-09-24
- Giai đoạn 3 — tài khoản & lịch sử: đăng nhập Google (`POST /api/v1/auth/google`), JWT hết hạn sau 7 ngày, lịch sử 50 kế hoạch mới nhất xem lại được trên mọi thiết bị (`GET /api/v1/plans/history`, `/:id`), dữ liệu lưu bằng SQLite + TypeORM với migration. Mặc định chạy chế độ đăng nhập giả lập (`mock:<email>`), không cần tài khoản Google Cloud; cách gắn Client ID thật ở [docs/SETUP_CREDENTIALS.md](docs/SETUP_CREDENTIALS.md) mục 2
- Tạo kế hoạch khi đã đăng nhập thì tự lưu vào lịch sử; lưu lỗi vẫn trả kế hoạch kèm cảnh báo. Kế hoạch trong lịch sử không chứa dị ứng, chấn thương hay tình trạng sức khoẻ (có test kiểm thẳng trong DB). Xem kế hoạch của tài khoản khác → 404
- Thêm `DELETE /api/v1/me` (FR-6.4): xoá tài khoản cùng toàn bộ lịch sử. Backend không khởi động nếu deploy (`NODE_ENV=production`) mà vẫn để đăng nhập giả lập, trừ khi bật cờ `ALLOW_MOCK_AUTH=true` có chủ đích
- Kiểm thử: thêm 65 unit test và 24 e2e (không test nào gọi Google hay ghi file DB thật); thêm smoke test chạy bản build như server thật trong CI, bắt được một lỗi khởi động mà toàn bộ unit test và e2e không thấy
```

### Task 8 — `docs/PLAN.md`

1. Dòng đầu: `Plan này chia [BRD.md](../BRD.md) (v2.3.0)` → `(v2.4.0)`.
2. Bảng "Chạy giả lập trước", dòng Google Sign-In, cột giả lập — thêm cuối: ` Bị chặn khi `NODE_ENV=production`, trừ khi `ALLOW_MOCK_AUTH=true``.
3. "Hiện trạng": `- [x] BRD v2.3.0 (…)` → `- [x] BRD v2.4.0 (…)`; dòng Backend thêm `, đăng nhập Google (giả lập mặc định), lịch sử kế hoạch (SQLite)` trước `, validate DTO, Swagger UI`.
4. Thay các bước giai đoạn 3 bằng:

```markdown
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
```

5. Giai đoạn 5 — thêm sau 5.6:

```markdown
- [ ] **5.7** Bật CORS trong `configureApp()` (`backend_api/src/app.setup.ts`) cho địa chỉ Flutter web, cho phép header `Authorization` — không có thì trình duyệt chặn mọi request từ bản web chạy ở cổng khác (phát hiện ở giai đoạn 3)
```

6. Bước 9.2 → `- [ ] **9.2** Deploy backend, cấu hình biến môi trường trên host: `NODE_ENV=production`, `AUTH_MODE=google`, `GOOGLE_CLIENT_ID`, `JWT_SECRET`, `DATABASE_PATH` trỏ vào ổ lưu trữ bền, `GEMINI_API_KEY``

### Task 9 — Cổng kiểm tra F05

```bash
grep -c '^- \[x\] \*\*3\.' docs/PLAN.md                                   # 9
grep -c '5\.7' docs/PLAN.md                                               # ≥ 1
grep -c 'auth-and-history' docs/knowledge/wiki/INDEX.md                    # 1
grep -cE '^\| (19|20|21|22) \|' docs/knowledge/wiki/critical-constraints.md  # 4
grep -c 'Phiên bản:\*\* 2.4.0' BRD.md                                      # 1
grep -c 'Chưa có trong code' docs/SETUP_CREDENTIALS.md                    # 0
for name in $(grep -oh '\[\[[a-z-]*\]\]' docs/knowledge/wiki/*.md | sort -u | tr -d '[]'); do
  [ -f "docs/knowledge/wiki/$name.md" ] || echo "THIẾU: $name"
done                                                                      # không in gì
```
