# Hướng dẫn gắn khoá thật (Gemini API, Google Sign-In)

Mặc định dự án chạy ở **chế độ giả lập**, không cần khoá nào: backend trả dữ liệu mẫu thay cho Gemini. Chỉ cần làm theo file này khi muốn dùng AI thật (hoặc đăng nhập Google thật).

| Dịch vụ | Trạng thái trong code | Hướng dẫn |
|---|---|---|
| Gemini API | Đã có | [Mục 1](#1-gemini-api-key) |
| Google Sign-In — backend | Đã có | [Mục 2](#2-google-sign-in) |
| Google Sign-In — Flutter | Đã có (giai đoạn 8); bản web đã thử với Client ID thật (2026-10-01), Android và macOS chưa | [Mục 3](#3-google-sign-in-trong-app-flutter) |

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
GEMINI_MODEL=gemini-3.5-flash
GEMINI_THINKING=off
GEMINI_TIMEOUT_MS=20000
GEMINI_TOTAL_TIMEOUT_MS=40000
```

Ba dòng cuối là giá trị mặc định, bỏ đi cũng được — nhưng nếu `.env` của bạn copy từ bản cũ có `GEMINI_MODEL=gemini-3.8-flash` hay `GEMINI_TIMEOUT_MS=15000` thì phải sửa hoặc xoá, vì giá trị trong `.env` thắng giá trị mặc định:

- `GEMINI_THINKING` — mức "suy nghĩ" của model trước khi trả lời: `off` (mặc định, tạo plan 8–15 giây), `low` (18–27 giây), `default` (model tự quyết, 37–42 giây). Số đo ngày 24/09/2026 với `gemini-3.5-flash`.
- `GEMINI_TIMEOUT_MS` — giới hạn mỗi lần gọi (ms); `GEMINI_TOTAL_TIMEOUT_MS` — giới hạn tổng cả lần gọi lại. Hết giờ thì backend dùng dữ liệu soạn sẵn ngay.
- **Hạn mức gói miễn phí: 20 lần gọi mỗi ngày cho mỗi model.** Tạo plan tốn 1–2 lần, đổi món/đổi bài/feedback mỗi thao tác 1–2 lần. Hết hạn mức thì app vẫn chạy bằng dữ liệu soạn sẵn.

`GEMINI_BASE_URL` trong `.env.example` chỉ dùng khi chạy test với server Gemini giả — **để trống** khi dùng thật, nếu không backend sẽ gửi request (kèm khoá) tới địa chỉ đó thay vì Google.

Sau đó **khởi động lại backend** (Ctrl+C rồi chạy lại `npm run start:dev`). Backend chỉ đọc `.env` lúc khởi động; chế độ watch tự khởi động lại khi sửa code nhưng **không** khi sửa `.env`.

### 1.3. Kiểm tra

1. Mở `http://localhost:3000/health`. Kết quả phải có `"gemini":"configured"`.
   Trường này chỉ cho biết backend **đã thấy** key, chưa chắc key hợp lệ.
2. Gọi thử `POST /api/v1/generate-plan` trên Swagger (`http://localhost:3000/docs`) và xem trường `source` trong kết quả:
   - `"source": "gemini"` → Gemini thật đã trả kết quả hợp lệ.
   - `"source": "sample"` → backend đã dùng thực đơn mẫu. Xem terminal đang chạy backend để biết lý do: dòng `Lỗi khi gọi Gemini (lần 1, tạo kế hoạch): …` (khoá sai, hết hạn mức, model sai, hết giờ) hoặc `Kết quả Gemini không đạt hợp đồng (lần 1, tạo kế hoạch): …` (Gemini trả sai định dạng hay số liệu; backend tự gọi lại một lần). App vẫn chạy bình thường vì backend tự dùng dữ liệu mẫu.

   Đổi món, đổi bài tập và cân đối món ăn sau feedback ghi log cùng dạng, với tên thao tác tương ứng (`đổi món`, `đổi bài tập`, `cân đối món ăn`). Khi Gemini không dùng được, đổi món và đổi bài tập lấy từ kho soạn sẵn; cân đối món ăn thì giữ nguyên món và app nhận một câu cảnh báo.

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
| Log báo `429 RESOURCE_EXHAUSTED` … `limit: 20` | Hết 20 lần gọi/ngày của model đó (gói miễn phí) | Đợi sang ngày hôm sau, hoặc đổi `GEMINI_MODEL` sang model khác (hạn mức tính riêng từng model), hoặc bật thanh toán cho project; trong lúc đó backend vẫn trả dữ liệu soạn sẵn |
| Log báo `429` nhưng vài phút sau lại chạy | Vượt giới hạn số lần gọi mỗi phút | Chờ khoảng 1 phút |
| Log báo `503 UNAVAILABLE` … `high demand` | Model đang quá tải phía Google (gặp nhiều với `gemini-3.8-flash`) | Thử lại sau, hoặc dùng `GEMINI_MODEL=gemini-3.5-flash` |
| Log báo `400` … `Thinking level … is not supported` | Model không hỗ trợ mức suy nghĩ đã chọn | Đổi `GEMINI_THINKING` (ví dụ `off`) |
| Log báo model không tồn tại | `GEMINI_MODEL` sai tên | Xem tên model tại [ai.google.dev/gemini-api/docs/models](https://ai.google.dev/gemini-api/docs/models) |
| Log báo `Gemini không phản hồi sau 20000 ms` | Model suy nghĩ lâu (`GEMINI_THINKING` khác `off`) hoặc mạng chậm | Đặt `GEMINI_THINKING=off`; nếu vẫn thường xuyên hết giờ, tăng `GEMINI_TIMEOUT_MS` và `GEMINI_TOTAL_TIMEOUT_MS` rồi khởi động lại backend |
| Log báo `Kết quả Gemini không đạt hợp đồng` lặp lại nhiều lần | Prompt chưa đủ chặt với model đang dùng | Thử prompt bằng `ai_workspace/` (mục 1.4), chỉnh rồi chép sang `backend_api/src/plan/gemini.service.ts` |

### 1.6. Đo lại khi đổi model hoặc mức suy nghĩ

```bash
cd backend_api
npm run build
npm run measure:gemini                                              # mặc định: gemini-3.5-flash × default/low/off
MEASURE_MODELS=gemini-3.8-flash MEASURE_THINKING=off npm run measure:gemini   # chọn model/mức khác
```

Script dùng đúng prompt và bước kiểm của backend, in thời gian và kết quả từng lần gọi. Mỗi cấu hình tốn 4 lần gọi — để ý hạn mức 20 lần/ngày.

### 1.7. Quay lại chế độ giả lập

Để trống `GEMINI_API_KEY=` trong `.env`, khởi động lại backend. `/health` sẽ báo `"fallback"`.

### 1.8. Bảo mật key

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

Cấu hình phía Flutter (Web Client ID lúc build, SHA-1 cho Android, Client ID cho macOS, nguồn được phép cho bản web): [mục 3](#3-google-sign-in-trong-app-flutter). Trên Android và macOS, app xin ID Token cho Web Client ID (tham số `serverClientId`), nên backend chủ yếu cần Web Client ID.

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
- Bản web của app chạy ở địa chỉ khác backend nên cần CORS. Khi phát triển, để trống `CORS_ORIGINS` (cho `localhost` mọi cổng). Khi deploy bản web, đặt `CORS_ORIGINS=https://<địa chỉ bản web>` — cùng địa chỉ khai báo ở "Authorized JavaScript origins" của Web Client ID (giai đoạn 8). Để trống khi `NODE_ENV=production` thì chỉ app mobile gọi được.

Khởi động lại backend. Thiếu `GOOGLE_CLIENT_ID`, hoặc `JWT_SECRET` ngắn hơn 32 ký tự → backend dừng ngay lúc khởi động và in lý do.

### 2.4. Kiểm tra

1. `http://localhost:3000/health` phải có `"auth_mode":"google"`.
2. Gửi `POST /api/v1/auth/google` với `{"id_token": "abc"}` → 401, và terminal backend có dòng `Từ chối Google ID Token: Wrong number of segments in token`. Nghĩa là backend đang xác minh bằng Google và không còn nhận `mock:`.
3. Kiểm tra trọn vẹn (đăng nhập bằng tài khoản Google thật) bằng nút đăng nhập trong app — [mục 3.6](#36-kiểm-tra).

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

- `JWT_SECRET` bảo vệ giống khoá Gemini (mục 1.8): chỉ nằm trong `.env`, không commit; khi deploy thì khai báo trên trang cấu hình của host.
- Không commit file DB (`*.sqlite`) — nó chứa email và tên người dùng thật.
- JWT chỉ chứa id người dùng. Log của backend không ghi token hay email khi từ chối đăng nhập.

---

## 3. Google Sign-In trong app Flutter

Code đã có (giai đoạn 8). Bản web đã thử với Client ID thật ngày 2026-10-01 (mục 3.6); Android và macOS mới kiểm bằng bản giả — ai thử lần đầu, ghi kết quả vào [PLAN.md](PLAN.md) bước 9.4.

### 3.1. App chọn cách đăng nhập thế nào

Khi mở bảng đăng nhập (màn chào lần đầu, tab Cá nhân, tab Lịch sử, nút "Đăng nhập lại"), app gọi `GET /health` và xem `auth_mode`:

| `auth_mode` của backend | App hiện |
|---|---|
| `mock` (mặc định) | Ô email + "Đăng nhập demo" — app gửi `mock:<email>`. Chạy trên mọi nền tảng, không cần gì ở mục này |
| `google` | Nút đăng nhập Google — cần làm các bước dưới cho từng nền tảng |

Mọi nền tảng dùng **một** giá trị lúc build: Web Client ID (mục 2.2, cũng là `GOOGLE_CLIENT_ID` của backend):

```bash
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=1234567890-abc123def456.apps.googleusercontent.com
```

Web dùng nó làm `clientId`; Android và macOS dùng làm `serverClientId`, để ID Token được cấp cho đúng Client ID mà backend kiểm. Thiếu giá trị này, app ghi "Bản app này chưa được cấu hình đăng nhập Google" và vẫn dùng được như khách. Client ID không phải bí mật, nhưng mỗi nhóm có một cái riêng nên không ghi cứng vào repo.

### 3.2. Web

1. Ở Web Client ID (mục 2.2), mục **Authorized JavaScript origins** phải có đúng địa chỉ trang, gồm cả cổng: `http://localhost:5050` khi phát triển, `https://<địa chỉ bản web>` khi deploy.
2. Chạy ở cổng cố định rồi mở `http://localhost:5050` bằng Chrome thường (đã đăng nhập Google):

   ```bash
   flutter run -d web-server --web-port 5050 --dart-define=GOOGLE_WEB_CLIENT_ID=<Web Client ID>
   ```

   - Không dùng cổng 5000 trên macOS: AirPlay Receiver nghe sẵn cổng này, `localhost:5000` trả trang 403 của AirTunes (gặp 2026-10-01). Muốn dùng 5000 thì tắt **System Settings → General → AirDrop & Handoff → AirPlay Receiver**.
   - `flutter run -d chrome` mở một Chrome riêng ở chế độ điều khiển tự động, chưa đăng nhập; Google có thể chặn đăng nhập trong trình duyệt đó.

3. Web không dùng được nút tự vẽ: Google bắt buộc nút của Google Identity Services, app hiện nút đó trong bảng đăng nhập (`renderButton()` của `google_sign_in_web`).
4. Bản web deploy cần thêm `CORS_ORIGINS` ở backend (mục 2.3).

### 3.3. Android

1. Lấy SHA-1 của khoá ký app. Bản debug và bản release hiện ký cùng khoá debug (`android/app/build.gradle.kts`):

   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   # hoặc
   cd frontend_app/android && ./gradlew signingReport
   ```

   Mỗi máy dev có khoá debug riêng, nên mỗi máy một SHA-1. Khi có khoá release riêng, thêm SHA-1 của nó.
2. Trang **Clients** → **Create client** → **Android**: package name `com.example.my_ai_app`, dán SHA-1. Tạo một Android client cho mỗi SHA-1.
3. Không dán Android Client ID vào app: Google nhận ra app qua package + SHA-1. App chỉ cần Web Client ID (mục 3.1).
4. Máy ảo phải là bản có Google Play (Device Manager → cột Play Store) và đã thêm một tài khoản Google trong Settings.

### 3.4. macOS

1. Trang **Clients** → **Create client** → **iOS** (macOS dùng loại này): Bundle ID `com.example.myAiApp` (`macos/Runner/Configs/AppInfo.xcconfig`). Copy Client ID và **iOS URL scheme** (Client ID đảo ngược, dạng `com.googleusercontent.apps.1234567890-xyz`).
2. Thêm vào `macos/Runner/Info.plist`:

   ```xml
   <key>GIDClientID</key>
   <string>1234567890-xyz.apps.googleusercontent.com</string>
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.1234567890-xyz</string>
       </array>
     </dict>
   </array>
   ```

3. Bật keychain sharing — thêm vào **cả** `macos/Runner/DebugProfile.entitlements` và `Release.entitlements`:

   ```xml
   <key>keychain-access-groups</key>
   <array>
     <string>$(AppIdentifierPrefix)com.google.GIDSignIn</string>
   </array>
   ```

   Entitlement này bắt buộc ký app bằng Apple Developer Team: mở `macos/Runner.xcworkspace` → Runner → **Signing & Capabilities** → chọn Team. Không có Team thì `flutter build macos` dừng với lỗi `"Runner" has entitlements that require signing with a development certificate` (đã thử 2026-10-01). Vì vậy repo **không** chứa các dòng ở bước 2–3: CI build bản macOS không ký.
4. Thêm Client ID loại iOS vào `GOOGLE_CLIENT_ID` của backend (cách nhau dấu phẩy, cạnh Web Client ID) — phòng khi ID Token được cấp cho Client ID này.
5. Chạy: `flutter run -d macos --dart-define=GOOGLE_WEB_CLIENT_ID=<Web Client ID>`.

### 3.5. Windows

`google_sign_in` không có bản Windows. Khi backend dùng Google, app trên Windows ghi "Đăng nhập Google chưa hỗ trợ trên Windows" và chạy như khách (đủ tính năng trừ lịch sử). Khi backend giả lập, "Đăng nhập demo" vẫn có. Người dùng Windows muốn có lịch sử thì mở bản web trên trình duyệt. Đăng nhập Google riêng cho Windows cần tự làm luồng trình duyệt + PKCE và client secret loại Desktop — chưa làm (brainstorm giai đoạn 8, P5).

### 3.6. Kiểm tra

1. Backend: `http://localhost:3000/health` có `"auth_mode":"google"` (mục 2.4).
2. App: tab Cá nhân → "Đăng nhập" → thấy nút Google (không phải ô email).
3. Đăng nhập → tab Cá nhân hiện tên, email; tạo kế hoạch → tab Lịch sử có kế hoạch đó, nhãn "Đang dùng".
4. Đăng nhập cùng tài khoản trên nền tảng khác → thấy cùng lịch sử (FR-7.3).

Đã thử 2026-10-01 — bản web trên Chrome (macOS), backend `AUTH_MODE=google` với Web Client ID thật, app ở trạng thái *Testing*: nút "Đăng nhập bằng Google" hiện ở màn chào → hộp chọn tài khoản → màn đồng ý chỉ xin tên, ảnh hồ sơ, email → app vào Onboarding; backend tạo tài khoản với `google_sub` của Google (không phải `mock:`), tên và email lấy từ Google; tạo kế hoạch → tab Lịch sử có kế hoạch đó, nhãn "Đang dùng", xem lại được; đổi món → kế hoạch lưu trên server đổi theo; "Xoá tài khoản" → server không còn tài khoản và lịch sử, app về khách.

### 3.7. Lỗi thường gặp

| App báo | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| "Bản app này chưa được cấu hình đăng nhập Google" | Build thiếu `--dart-define=GOOGLE_WEB_CLIENT_ID` | Build lại với giá trị đó (mục 3.1) |
| Web trên macOS: `localhost:5000` ra trang 403 (máy chủ "AirTunes"), không phải app | AirPlay Receiver chiếm cổng 5000 | Dùng cổng khác (mục 3.2) và thêm origin của cổng đó |
| Android: "Đăng nhập Google chưa được cấu hình đúng…" | Package name hoặc SHA-1 của Android client không khớp bản đang chạy; Web Client ID sai | Kiểm lại mục 3.3 — mỗi máy dev một SHA-1 |
| Android: không hiện hộp chọn tài khoản | Máy ảo không có Google Play, chưa có tài khoản Google | Mục 3.3 bước 4 |
| Web: nút Google không hiện, hoặc cửa sổ Google báo `origin_mismatch` | Địa chỉ trang (cả cổng) chưa có trong Authorized JavaScript origins | Mục 3.2 |
| macOS: "Đăng nhập Google chưa được cấu hình đúng…" | Thiếu `GIDClientID`, URL scheme, hoặc keychain sharing | Mục 3.4 |
| "Máy chủ không chấp nhận lần đăng nhập này" | Backend trả 401: token cấp cho Client ID khác `GOOGLE_CLIENT_ID`, tài khoản chưa xác minh email | Xem dòng log của backend (mục 2.5) |
| Tài khoản cụ thể không đăng nhập được | App ở trạng thái *Testing*, tài khoản chưa có trong **Test users** | Mục 2.2 bước 5 |
| "Đăng nhập Google chưa hỗ trợ trên Windows" | Đúng như thiết kế | Mục 3.5 |
