# SmartFit AI — API Documentation (Tài liệu Đặc tả API)

> **Dự án:** SmartFit AI Backend API (NestJS 12)  
> **Swagger UI trực tiếp:** `http://localhost:3000/docs` (JSON: `http://localhost:3000/docs-json`)  
> **Chuẩn hợp đồng:** BRD v2.6.0 (§6 API Contract)  
> **Định dạng dữ liệu:** JSON UTF-8

---

## 1. Thông tin Kết nối & Xác thực (Overview & Authentication)

### 1.1. Địa chỉ máy chủ (Base URL)
* **Local Development (Web / Desktop / macOS):** `http://localhost:3000`
* **Android Emulator:** `http://10.0.2.2:3000`
* **Thiết bị thật (Physical Device qua Wi-Fi LAN):** `http://<IP-may-tinh>:3000`

### 1.2. Cơ chế Xác thực (Authentication)
* Hệ thống sử dụng chuẩn **Bearer Token (JWT - HS256)** có thời hạn 7 ngày.
* Với các endpoint yêu cầu đăng nhập, client phải truyền header:
  ```http
  Authorization: Bearer <access_token>
  ```
* Các endpoint có cờ `OptionalJwtAuthGuard` (`generate-plan`, `swap`, `feedback`) hoạt động ở cả 2 chế độ:
  * Nếu **không truyền token**: Xử lý ở chế độ Khách (Guest Mode), kế hoạch trả về bình thường nhưng không tự động lưu vào MySQL.
  * Nếu **có truyền token**: Kế hoạch sẽ được tự động lưu hoặc cập nhật vào bảng `plan_records` của tài khoản đó.

---

## 2. Danh sách Endpoints Chi tiết

### 2.1. Nhóm Hệ thống (System)

#### `GET /health`
* **Mô tả:** Kiểm tra trạng thái hoạt động của máy chủ và cấu hình dịch vụ ngoài.
* **Xác thực:** Không yêu cầu.
* **Response (200 OK):**
  ```json
  {
    "status": "ok",
    "auth_mode": "mock",
    "ai_provider": "groq",
    "model": "openai/gpt-oss-120b",
    "uptime_seconds": 128
  }
  ```

---

### 2.2. Nhóm Xác thực & Tài khoản (Auth & Accounts)

#### `POST /api/v1/auth/register`
* **Mô tả:** Đăng ký tài khoản mới bằng Email và Mật khẩu. Mật khẩu được băm bằng thuật toán `scrypt`.
* **Request Body:**
  ```json
  {
    "email": "user@vku.udn.vn",
    "password": "Password123!",
    "name": "Nguyễn Văn A"
  }
  ```
* **Response (200 OK):**
  ```json
  {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "11111111-2222-3333-4444-555555555555",
      "email": "user@vku.udn.vn",
      "name": "Nguyễn Văn A"
    }
  }
  ```
* **Lỗi (409 Conflict):** Email này đã được đăng ký trên hệ thống.

#### `POST /api/v1/auth/login`
* **Mô tả:** Đăng nhập bằng Email và Mật khẩu.
* **Request Body:**
  ```json
  {
    "email": "user@vku.udn.vn",
    "password": "Password123!"
  }
  ```
* **Response (200 OK):** Trả về `access_token` và thông tin `user`.
* **Lỗi (401 Unauthorized):** Email hoặc mật khẩu không chính xác.

#### `POST /api/v1/auth/change-password`
* **Mô tả:** Đổi mật khẩu cho tài khoản đang đăng nhập.
* **Xác thực:** Yêu cầu Bearer Token (`JwtAuthGuard`).
* **Request Body:**
  ```json
  {
    "current_password": "OldPassword123!",
    "new_password": "NewPassword456!"
  }
  ```
* **Response (200 OK):** `{ "message": "Đổi mật khẩu thành công" }`

#### `DELETE /api/v1/me`
* **Mô tả:** Xoá vĩnh viễn tài khoản và toàn bộ lịch sử kế hoạch liên quan (Cascade delete).
* **Xác thực:** Yêu cầu Bearer Token.
* **Response (200 OK):** `{ "success": true }`

---

### 2.3. Nhóm Kế hoạch Dinh dưỡng & Tập luyện (Plan Management)

#### `POST /api/v1/generate-plan`
* **Mô tả:** Tạo mới kế hoạch 3 ngày cuốn chiếu dựa trên thông tin thể trạng và mục tiêu.
* **Xác thực:** Tuỳ chọn (`OptionalJwtAuthGuard`).
* **Request Body:**
  ```json
  {
    "age": 22,
    "gender": "female",
    "height_cm": 168,
    "weight_kg": 62,
    "activity_level": "light",
    "goal": "cut",
    "pregnant_or_breastfeeding": false,
    "restrictions": {
      "allergies": "Hải sản, tôm cua",
      "injuries": "Đau khớp gối",
      "health_conditions": "Đau dạ dày"
    }
  }
  ```
* **Rào cản an toàn (400 Bad Request):**
  * `BMI < 18.5` mà chọn `goal: "cut"`: Bị từ chối với thông báo y tế.
  * Tuổi ngoài khoảng `18 - 100`: Bị từ chối.
* **Response (200 OK):**
  ```json
  {
    "plan_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "source": "groq",
    "daily_target": {
      "bmi": 21.97,
      "bmr": 1406,
      "tdee": 1933,
      "target_calories": 1633,
      "macros": { "protein_g": 102, "carbs_g": 184, "fat_g": 54 }
    },
    "days": [
      {
        "day_number": 1,
        "date_offset": 0,
        "meals": [
          {
            "id": "m1_1",
            "meal_type": "breakfast",
            "name": "Bún mọc sườn",
            "calories": 405,
            "protein_g": 26,
            "carbs_g": 48,
            "fat_g": 12,
            "ingredients": [
              { "category": "protein", "name": "Thịt nạc băm", "quantity": "80g" },
              { "category": "carb", "name": "Bún tươi", "quantity": "150g" }
            ],
            "recipe_notes": "Nấu nước dùng thanh, hạn chế mỡ màng."
          }
        ],
        "workout": {
          "id": "w1",
          "name": "Thân trên cơ bản",
          "focus_muscle_groups": ["chest", "back"],
          "exercises": [
            {
              "id": "e1_1",
              "name": "Hít đất trên tường (Wall Push-ups)",
              "muscle_group": "chest",
              "sets": 3,
              "reps_or_duration": "10-12 lần",
              "difficulty_level": 1,
              "video_search_query": "Wall Push-ups home workout",
              "instruction": "Đứng cách tường 1 sải tay, chống tay đẩy ngực nhịp nhàng."
            }
          ]
        }
      }
    ],
    "grocery_list": [
      {
        "category": "protein",
        "items": [{ "name": "Thịt nạc băm", "quantity": "80g" }]
      }
    ],
    "warnings": []
  }
  ```

#### `POST /api/v1/meals/swap`
* **Mô tả:** Đổi một món ăn cụ thể trong ngày lấy một món ăn tương đương về calo và dinh dưỡng.
* **Request Body:** Gửi toàn văn `profile`, `plan`, `day_number` và `meal_id` cần đổi.
* **Response (200 OK):** Trả về toàn bộ bản JSON kế hoạch mới sau khi đã thay thế món ăn và tính lại danh sách đi chợ.

#### `POST /api/v1/exercises/swap`
* **Mô tả:** Đổi một bài tập lấy bài tập thay thế cùng nhóm cơ, tuân thủ chấn thương và cấp độ tập.
* **Request Body:** Gửi `profile`, `plan`, `day_number` và `exercise_id` cần đổi.
* **Response (200 OK):** Trả về bản JSON kế hoạch mới.

#### `POST /api/v1/feedback`
* **Mô tả:** Gửi phản hồi cuối ngày để hệ thống điều chỉnh kế hoạch các ngày tiếp theo.
* **Request Body:**
  ```json
  {
    "profile": { ... },
    "plan": { ... },
    "day_number": 1,
    "answers": {
      "intensity": "heavy",
      "body_status": ["sore_muscles"],
      "nutrition": "ate_less"
    }
  }
  ```
* **Đặc biệt (Quy tắc D2 - Dấu hiệu nguy hiểm):** Nếu `body_status` chứa `"danger_signs"`, API trả về khuyến cáo y tế ngay lập tức và tự động gán ngày kế tiếp nghỉ ngơi hoặc đi bộ nhẹ mà không gọi LLM.

---

### 2.4. Nhóm Lịch sử Kế hoạch (History)

#### `GET /api/v1/plans/history`
* **Mô tả:** Lấy danh sách 50 kế hoạch gần nhất của người dùng đăng nhập.
* **Xác thực:** Yêu cầu Bearer Token.
* **Response (200 OK):**
  ```json
  {
    "plans": [
      {
        "id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
        "target_calories": 1633,
        "created_at": "2026-11-15T08:00:00.000Z"
      }
    ]
  }
  ```

#### `GET /api/v1/plans/history/:id`
* **Mô tả:** Lấy toàn bộ nội dung chi tiết của một kế hoạch đã lưu theo ID.
* **Xác thực:** Yêu cầu Bearer Token (không được xem kế hoạch của người dùng khác -> 404).
