# Hướng dẫn gắn khoá thật (Gemini API, Google Sign-In)

Mặc định dự án chạy ở **chế độ giả lập**, không cần khoá nào: backend trả dữ liệu mẫu thay cho Gemini. Chỉ cần làm theo file này khi muốn dùng AI thật (hoặc đăng nhập Google thật, sau khi phần đó được làm).

| Dịch vụ | Trạng thái trong code | Hướng dẫn |
|---|---|---|
| Gemini API | Đã có | [Mục 1](#1-gemini-api-key) |
| Google Sign-In — backend | Chưa làm ([PLAN.md](PLAN.md) bước 3.7) | [Mục 2](#2-google-sign-in) |
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

Chưa có trong code. Tính năng đăng nhập được làm ở giai đoạn 3 (backend) và giai đoạn 8 (Flutter) của [PLAN.md](PLAN.md). Khi làm xong, backend mặc định chạy `AUTH_MODE=mock` (đăng nhập giả lập, không cần tài khoản Google Cloud), và mục này sẽ hướng dẫn tạo OAuth Client ID, điền `.env` phía backend và cấu hình phía Flutter.
