# Hướng dẫn gắn khoá thật (Gemini API, Google Sign-In)

Mặc định dự án chạy ở **chế độ giả lập**, không cần khoá nào: backend trả dữ liệu mẫu thay cho Gemini. Chỉ cần làm theo file này khi muốn dùng AI thật (hoặc đăng nhập Google thật).

| Dịch vụ | Trạng thái trong code | Hướng dẫn |
|---|---|---|
| Gemini API | Đã có | [Mục 1](#1-gemini-api-key) |
| Google Sign-In — backend | Đã có | [Mục 2](#2-google-sign-in) |
| Google Sign-In — Flutter | Chưa làm ([PLAN.md](PLAN.md) bước 8.4) | [Mục 2](#2-google-sign-in) |

---

## 1. Gemini API key

### 1.1. Lấy key

1. Vào [aistudio.google.com/apikey](https://aistudio.google.com/apikey), đăng nhập bằng tài khoản Google.
2. Bấm **Create API key**. Khi được hỏi, chọn hoặc tạo một Google Cloud project.
3. Copy key vừa tạo.

> **Key tạo trước 28/05/2026 có thể không dùng được nữa.** Từ ngày đó, key mới tạo trên AI Studio là loại *auth key*; trong tháng 9/2026 Gemini API bắt đầu từ chối key loại *Standard*. Nếu nhóm đang dùng một key cũ, xem cột **Key Type** trên trang API Keys — nếu ghi "Standard" thì tạo key mới. Code không cần sửa gì, chỉ thay giá trị trong `.env`.

### 1.2. Điền key vào backend

```bash
cd backend_api
cp .env.example .env   # bỏ qua nếu đã có file .env
```

Mở `backend_api/.env` và điền:

```
GEMINI_API_KEY=<key vừa copy>
GEMINI_MODEL=gemini-3.8-flash
```

Tuỳ chọn: `GEMINI_TIMEOUT_MS=15000` — giới hạn thời gian mỗi lần gọi Gemini (ms). Hết giờ thì backend dùng thực đơn mẫu ngay.

`GEMINI_BASE_URL` trong `.env.example` chỉ dùng khi chạy test với server Gemini giả — **để trống** khi dùng thật, nếu không backend sẽ gửi request (kèm khoá) tới địa chỉ đó thay vì Google.

Sau đó **khởi động lại backend** (Ctrl+C rồi chạy lại `npm run start:dev`). Backend chỉ đọc `.env` lúc khởi động; chế độ watch tự khởi động lại khi sửa code nhưng **không** khi sửa `.env`.

### 1.3. Kiểm tra

1. Mở `http://localhost:3000/health`. Kết quả phải có `"gemini":"configured"`.
   Trường này chỉ cho biết backend **đã thấy** key, chưa chắc key hợp lệ.
2. Gọi thử `POST /api/v1/generate-plan` trên Swagger (`http://localhost:3000/docs`) và xem trường `source` trong kết quả:
   - `"source": "gemini"` → Gemini thật đã trả kết quả hợp lệ.
   - `"source": "sample"` → backend đã dùng thực đơn mẫu. Xem terminal đang chạy backend để biết lý do: dòng `Lỗi khi gọi Gemini (lần 1): …` (khoá sai, hết hạn mức, model sai, hết giờ) hoặc `Kết quả Gemini không đạt hợp đồng (lần 1): …` (Gemini trả sai định dạng hay số liệu; backend tự gọi lại một lần). App vẫn chạy bình thường vì backend tự dùng dữ liệu mẫu.

### 1.4. Thử key nhanh bằng `ai_workspace/`

Cách nhanh nhất để biết key có dùng được không, vì lỗi hiện thẳng trên terminal thay vì bị fallback che đi:

```bash
cd ai_workspace
cp .env.example .env   # điền GEMINI_API_KEY giống như ở backend
npm install            # lần đầu
npm run experiment
```

Script in ra prompt, JSON Gemini trả về, và kết quả kiểm tra khoảng calo từng bữa.

### 1.5. Lỗi thường gặp

| Hiện tượng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| `/health` vẫn báo `"fallback"` | Chưa khởi động lại backend; file `.env` đặt sai chỗ (phải là `backend_api/.env`); gõ sai tên biến | Kiểm tra lại đường dẫn và tên biến, khởi động lại |
| Log báo `API key not valid` | Copy thiếu ký tự, hoặc key đã bị xoá | Copy lại hoặc tạo key mới |
| Log báo lỗi xác thực/quyền truy cập dù key copy đúng | Key loại *Standard* đã bị từ chối (xem lưu ý ở mục 1.1) | Tạo key mới trên AI Studio |
| Log báo `RESOURCE_EXHAUSTED` (429) | Hết hạn mức miễn phí | Đợi hạn mức hồi lại hoặc dùng project khác; trong lúc đó backend vẫn trả dữ liệu mẫu |
| Log báo model không tồn tại | `GEMINI_MODEL` sai tên | Xem tên model tại [ai.google.dev/gemini-api/docs/models](https://ai.google.dev/gemini-api/docs/models) |
| Log báo `Gemini không phản hồi sau 15000 ms` | Mạng chậm hoặc model phản hồi chậm | Thử lại; nếu thường xuyên xảy ra, tăng `GEMINI_TIMEOUT_MS` trong `.env` rồi khởi động lại backend |
| Log báo `Kết quả Gemini không đạt hợp đồng` lặp lại nhiều lần | Prompt chưa đủ chặt với model đang dùng | Thử prompt bằng `ai_workspace/` (mục 1.4), chỉnh rồi chép sang `backend_api/src/plan/gemini.service.ts` |

### 1.6. Quay lại chế độ giả lập

Để trống `GEMINI_API_KEY=` trong `.env`, khởi động lại backend. `/health` sẽ báo `"fallback"`.

### 1.7. Bảo mật key

- Key chỉ được nằm trong `backend_api/.env` và `ai_workspace/.env`. Cả hai file đã nằm trong `.gitignore`; trước khi commit vẫn nên chạy `git status` để chắc `.env` không xuất hiện.
- **Không bao giờ đặt key trong app Flutter.** App gọi backend, backend mới gọi Gemini. Key đặt trong app web/mobile có thể bị lấy ra từ file cài đặt.
- Lỡ để lộ key (commit nhầm, gửi qua chat, chụp màn hình): tạo key mới, cập nhật `.env`, rồi xoá key cũ trên trang API Keys. Chỉ xoá commit là không đủ, vì lịch sử Git vẫn giữ key.
- Khi deploy (PLAN.md giai đoạn 9): khai báo biến môi trường trong trang cấu hình của host, không upload file `.env`.

---

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
