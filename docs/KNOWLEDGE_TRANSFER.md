# SmartFit AI — Development Communication & Knowledge Transfer
(Tài liệu Chuyển giao Tri thức & Quy chuẩn Phát triển)

> **Dành cho:** Kỹ sư phần mềm mới gia nhập dự án, giảng viên hướng dẫn, hội đồng đánh giá kỹ thuật và người kế thừa mã nguồn SmartFit AI.  
> **Phiên bản:** 1.0 (Tháng 11/2026)

---

## 1. Hướng dẫn Onboarding Kỹ sư Mới trong 10 phút (Quickstart)

### 1.1. Yêu cầu Môi trường (Prerequisites)
* **Node.js:** v22+ hoặc v24 LTS (hỗ trợ native ESM).
* **Flutter SDK:** v3.47+ (Dart v3.x).
* **Database:** MySQL v8.0+ (hoặc dùng chế độ SQLite in-memory tự động cho test).
* **Trình quản lý gói:** `npm` cho backend, `flutter pub` cho frontend.

### 1.2. Khởi động Backend (`backend_api/`)
```bash
cd backend_api
npm install
cp .env.example .env     # Hệ thống mặc định chạy Mock Mode không cần API key ngoài
npm run start:dev        # Chạy máy chủ tại http://localhost:3000, Swagger tại /docs
```
* **Cờ môi trường quan trọng:**
  * `PLAN_AI_PROVIDER=groq`: Sử dụng Groq AI làm động cơ chính (khi có `GROQ_API_KEY`).
  * Không có key: Hệ thống tự động kích hoạt `source: "sample"` (Thực đơn mẫu fallback an toàn).
  * `AUTH_MODE=mock`: Chấp nhận token `mock:<email>` để test nhanh mà không cần tạo tài khoản thật.

### 1.3. Khởi động Frontend (`frontend_app/`)
```bash
cd frontend_app
flutter pub get
flutter run -d chrome    # Chạy bản Web (kết nối backend tại http://localhost:3000)

# Chạy trên máy ảo Android:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Chạy trên điện thoại thật (cùng mạng Wi-Fi với máy tính):
flutter run --dart-define=API_BASE_URL=http://<IP-LAN-may-tinh>:3000
```

---

## 2. Quy trình Làm việc Git & Giao tiếp Nhóm (Git Workflow)

### 2.1. Chiến lược Phân nhánh (Branching Strategy)
* `main`: Nhánh production ổn định, luôn luôn chạy pass 100% test và build.
* `feat/<ten-tinh-nang>`: Nhánh phát triển tính năng mới.
* `fix/<ten-loi>`: Nhánh sửa lỗi.

### 2.2. Quy ước Đặt tên Commit (Commit Conventions)
Dự án áp dụng chuẩn Conventional Commits có thể kết hợp Tiếng Việt hoặc Tiếng Anh rõ ràng:
* `feat(app): ...` — Tính năng mới phía Flutter UI.
* `feat(plan): ...` — Cải tiến logic sinh thực đơn hoặc thuật toán calo.
* `fix(auth): ...` — Vá lỗi xác thực hoặc mật khẩu.
* `chore(backend): ...` — Nâng cấp thư viện hoặc cấu hình hệ thống.
* `docs: ...` — Cập nhật tài liệu kiến trúc hoặc roadmap.

### 2.3. Hợp đồng Kiểm thử trước khi Merge (Definition of Done)
Bất kỳ Pull Request (PR) nào mở vào `main` bắt buộc phải vượt qua:
1. `npm run typecheck` (Backend không có lỗi TypeScript).
2. `npm run lint` (0 lỗi oxlint).
3. `npm test` (500+ unit test pass).
4. `npm run test:e2e` (Kiểm thử đầu-cuối in-memory SQLite pass).
5. `flutter analyze` (Frontend 0 warning, 0 error).
6. `flutter test` (190+ Flutter tests pass).

---

## 3. Tóm tắt Quyết định Kỹ thuật Cốt lõi (Decisions D1–D6)

Người kế thừa dự án **BẮT BUỘC** phải hiểu rõ 6 quyết định thiết kế này để không làm phá vỡ logic nghiệp vụ:

| Mã | Quyết định | Ý nghĩa kỹ thuật |
|---|---|---|
| **D1** | Điều chỉnh calo theo mục tiêu | Giảm mỡ −300 kcal, Tăng cơ +250 kcal, Duy trì 0 kcal. Calo mục tiêu không bao giờ được thấp hơn BMR. |
| **D2** | Phản hồi cuối ngày 3 câu hỏi | 1) Cường độ (Nhẹ/Vừa/Mệt), 2) Thể trạng (Mỏi cơ/Đau khớp/Uể oải), 3) Ăn uống. **Dấu hiệu nguy hiểm (chóng mặt, tức ngực)** ➔ Ngừng tập, khuyến cáo đi khám, ngày sau chỉ nghỉ ngơi (không gọi AI). |
| **D3** | Phân tách nguyên liệu đi chợ | Trả `name` và `quantity` riêng, gom theo 3 nhóm cố định (*Đạm*, *Rau củ*, *Tinh bột & Gia vị*). |
| **D4 & D5** | Dữ liệu sức khỏe chỉ lưu trên máy | Dị ứng, chấn thương, bệnh nền **chỉ lưu tại client `shared_preferences`**, gửi tạm trong request body rồi huỷ. **CẤM lưu vào database hoặc in ra server log.** |
| **D6** | Rào cản an toàn lâm sàng | BMI < 18.5 cấm chọn giảm cân (trả 400); Tuổi tối thiểu 18; Mang thai/cho con bú cấm thâm hụt calo và khóa bài tập ở cấp độ 1 nhẹ nhàng. |

---

## 4. Ma trận Xử lý Sự cố Thường gặp (Troubleshooting Matrix)

| Hiện tượng lỗi | Nguyên nhân gốc rễ | Cách xử lý nhanh |
|---|---|---|
| **App Web báo "Lỗi kết nối máy chủ"** | Trình duyệt chặn CORS Preflight. | Đảm bảo biến `CORS_ORIGINS` trong `backend_api/.env` để trống (trong môi trường dev) để backend chấp nhận mọi port của `localhost`. |
| **Điện thoại thật không kết nối được backend** | 1. Tường lửa Windows chặn cổng 3000.<br>2. Sai địa chỉ IP LAN. | 1. Mở Windows Firewall cho phép Inbound traffic cổng 3000.<br>2. Chạy `ipconfig`, lấy IPv4 LAN và truyền `--dart-define=API_BASE_URL=http://<IP>:3000`. |
| **Backend crash khi khởi động:** `Cannot access 'User' before initialization` | ESM Circular Dependency giữa các Entity TypeORM. | Luôn bọc quan hệ bảng trong `Relation<T>`, ví dụ: `user: Relation<User>`. Tuyệt đối không khai báo trần `user: User`. |
| **Import file TypeScript bị báo lỗi Cannot find module** | Node.js ESM yêu cầu đường dẫn import tương đối phải có đuôi `.js`. | Luôn viết: `import { PlanService } from './plan.service.js'`, không viết `./plan.service`. |
| **Lỗi gọi Groq AI:** `429 Too Many Requests` | Vượt hạn mức gói miễn phí của Groq. | Hệ thống sẽ tự động chuyển sang dùng thực đơn mẫu an toàn (`source: "sample"`), dịch vụ không bị gián đoạn. |

---

## 5. Danh mục Bàn giao & Tài sản Dự án (Handover Checklist)

* [x] **Mã nguồn đầy đủ:** Đã đẩy lên GitHub `https://github.com/AlenJason/AI-Product-Development-End-to-End`.
* [x] **Tài liệu đặc tả yêu cầu (Product Specs):** [`BRD.md`](../BRD.md) v2.6.0.
* [x] **Bản đồ lộ trình & tiến độ thực tế:** [`docs/PLAN.md`](PLAN.md).
* [x] **Tài liệu kiến trúc hệ thống:** [`docs/ARCHITECTURE.md`](ARCHITECTURE.md).
* [x] **Đặc tả API & Hợp đồng dữ liệu:** [`docs/API_DOCUMENTATION.md`](API_DOCUMENTATION.md).
* [x] **Tài liệu cấu hình AI Agent:** [`AGENTS.md`](../AGENTS.md) và [`.agents/skills/`](../.agents/skills).
* [x] **Hướng dẫn sử dụng cho người dùng cuối:** [`docs/USER_GUIDE.md`](USER_GUIDE.md).
* [x] **Hướng dẫn thiết lập API Key & Cơ sở dữ liệu:** [`docs/SETUP_CREDENTIALS.md`](SETUP_CREDENTIALS.md).
