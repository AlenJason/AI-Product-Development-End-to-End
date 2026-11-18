# SmartFit AI — API Documentation & Specification (Đặc tả Chi tiết Giao tiếp API)

> **Dự án:** SmartFit AI — Backend API (NestJS 12, Node.js ESM)  
> **Swagger UI Trực quan:** [http://localhost:3000/docs](http://localhost:3000/docs)  
> **OpenAPI JSON Spec:** [http://localhost:3000/docs-json](http://localhost:3000/docs-json)  
> **Chuẩn hợp đồng:** BRD v2.6.0 (§6 API Contract)  
> **Sơ đồ luồng dữ liệu:** [FLOWCHARTS.md](FLOWCHARTS.md)  
> **Định dạng dữ liệu:** JSON UTF-8

---

## 1. Thông tin Kết nối, Môi trường & Xác thực

### 1.1. Địa chỉ Máy chủ (Base URLs)
* **Môi trường Trình duyệt Web / macOS / Desktop:** `http://localhost:3000`
* **Môi trường Android Emulator:** `http://10.0.2.2:3000`
* **Thiết bị thật (Physical Mobile qua mạng Wi-Fi LAN):** `http://<IP-may-tinh-cung-mang>:3000`

### 1.2. Cơ chế Xác thực (Authentication & Authorization)
Hệ thống sử dụng chuẩn **Bearer Token (JWT - HS256)** với thời hạn 7 ngày:
* **Header bắt buộc đối với endpoint bảo mật:**
  ```http
  Authorization: Bearer <access_token>
  ```
* **Chế độ Xác thực Linh hoạt (`OptionalJwtAuthGuard`):**
  * **Chế độ Khách (Guest Mode):** Nếu request không truyền token, hệ thống vẫn phục vụ đầy đủ tính năng tạo thực đơn, đổi món/bài, feedback bằng tính toán AI trong bộ nhớ tạm (không lưu MySQL).
  * **Chế độ Thành viên:** Nếu có kèm token hợp lệ, hệ thống sẽ tự động lưu hoặc cập nhật kế hoạch vào bảng `plan_records` và cập nhật thông tin thể trạng người dùng vào bảng `users`.

---

## 2. Bảng Mã Lỗi Chuẩn (HTTP Status Codes)

| Mã HTTP | Tên chuẩn | Ý nghĩa trong hệ thống SmartFit AI |
|---|---|---|
| **200** | OK | Yêu cầu xử lý thành công, trả về dữ liệu JSON tương ứng. |
| **204** | No Content | Xử lý thành công nhưng không có nội dung trả về (ví dụ `DELETE /api/v1/me`). |
| **400** | Bad Request | Dữ liệu đầu vào sai định dạng DTO hoặc vi phạm rào cản an toàn lâm sàng D6 (BMI < 18.5 chọn Cut, tuổi ngoài 18–100). |
| **401** | Unauthorized | Thiếu Bearer Token, token sai định dạng, token hết hạn (sau 7 ngày) hoặc tài khoản đã bị xóa. |
| **403** | Forbidden | Người dùng tìm cách truy cập hoặc sửa đổi kế hoạch thuộc về tài khoản khác. |
| **404** | Not Found | Không tìm thấy tài nguyên (ví dụ ID kế hoạch không tồn tại trong DB). |
| **409** | Conflict | Xung đột dữ liệu: Email đã được đăng ký, hoặc xung đột phiên phản hồi feedback cùng ngày. |
| **422** | Unprocessable Entity | Hợp đồng đúng cú pháp nhưng logic không thực hiện được (ví dụ không còn món ăn/bài tập thay thế phù hợp trong kho). |
| **503** | Service Unavailable | Không thể kết nối cơ sở dữ liệu bền vững hoặc lỗi tạm thời từ dịch vụ lưu trữ. |

---

## 3. Chi tiết Danh sách Endpoint (API Specifications)

### 3.1. Nhóm Hệ thống (System Health)

#### `GET /health`
* **Mô tả:** Kiểm tra trạng thái hoạt động của máy chủ, AI provider và cơ chế xác thực.
* **Xác thực:** Không yêu cầu.
* **Response (200 OK):**
  ```json
  {
    "status": "ok",
    "auth_mode": "mock",
    "ai_provider": "groq",
    "model": "openai/gpt-oss-120b",
    "uptime_seconds": 342
  }
  ```

---

### 3.2. Nhóm Xác thực & Tài khoản (Authentication & Profile)

#### `POST /api/v1/auth/register`
* **Mô tả:** Đăng ký tài khoản người dùng mới. Mật khẩu được băm an toàn bằng thuật toán `scrypt`.
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
* **Lỗi:** `400 Bad Request` (email không hợp lệ, mật khẩu < 6 ký tự), `409 Conflict` (email đã tồn tại).

#### `POST /api/v1/auth/login`
* **Mô tả:** Đăng nhập bằng email và mật khẩu đã đăng ký.
* **Request Body:**
  ```json
  {
    "email": "user@vku.udn.vn",
    "password": "Password123!"
  }
  ```
* **Response (200 OK):** Trả về `access_token` và đối tượng `user`.
* **Lỗi:** `401 Unauthorized` (sai mật khẩu hoặc email không tồn tại).

#### `POST /api/v1/auth/google`
* **Mô tả:** Xác thực bằng Google ID Token (hỗ trợ Mock Token `mock:<email>` khi ở chế độ `AUTH_MODE=mock`).
* **Request Body:**
  ```json
  {
    "id_token": "mock:testuser@vku.edu.vn"
  }
  ```
* **Response (200 OK):** Trả về `access_token` và `user`.

#### `POST /api/v1/auth/change-password`
* **Mô tả:** Đổi mật khẩu cho người dùng hiện tại.
* **Xác thực:** Yêu cầu Bearer Token (`JwtAuthGuard`).
* **Request Body:**
  ```json
  {
    "current_password": "OldPassword123!",
    "new_password": "NewPassword456!"
  }
  ```
* **Response (200 OK):** `{ "message": "Đổi mật khẩu thành công." }`

#### `GET /api/v1/me/profile`
* **Mô tả:** Lấy thông tin thể trạng đã lưu của tài khoản đăng nhập để tự động nạp (Auto-fill) vào form Onboarding/Cá nhân, tránh người dùng phải nhập lại.
* **Xác thực:** Yêu cầu Bearer Token (`JwtAuthGuard`).
* **Response (200 OK):**
  ```json
  {
    "profile": {
      "age": 22,
      "gender": "female",
      "height_cm": 168,
      "weight_kg": 62,
      "activity_level": "light",
      "goal": "cut",
      "pregnant_or_breastfeeding": false
    }
  }
  ```
  *(Nếu người dùng mới chưa từng lưu thông tin, trả về `{"profile": null}`)*

#### `PUT /api/v1/me/profile`
* **Mô tả:** Lưu hoặc cập nhật thông tin thể trạng của tài khoản vào database.
* **Bảo vệ quyền riêng tư (D4 & D5):** Hệ thống chỉ lọc lưu các chỉ số cơ bản (`age`, `height_cm`, `weight_kg`, `gender`, `activity_level`, `goal`). Bất kỳ trường nhạy cảm y tế nào (`allergies`, `injuries`, `health_conditions`) sẽ bị tự động bóc tách và loại bỏ trước khi ghi DB.
* **Xác thực:** Yêu cầu Bearer Token (`JwtAuthGuard`).
* **Request Body:**
  ```json
  {
    "age": 23,
    "gender": "female",
    "height_cm": 168,
    "weight_kg": 61,
    "activity_level": "light",
    "goal": "maintain",
    "pregnant_or_breastfeeding": false
  }
  ```
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "profile": {
      "age": 23,
      "gender": "female",
      "height_cm": 168,
      "weight_kg": 61,
      "activity_level": "light",
      "goal": "maintain",
      "pregnant_or_breastfeeding": false
    }
  }
  ```

#### `DELETE /api/v1/me`
* **Mô tả:** Xóa vĩnh viễn tài khoản và toàn bộ lịch sử kế hoạch liên quan (Cascade delete).
* **Xác thực:** Yêu cầu Bearer Token (`JwtAuthGuard`).
* **Response (204 No Content).**

---

### 3.3. Nhóm Kế hoạch Ăn uống & Tập luyện (Plan Management)

#### `POST /api/v1/generate-plan`
* **Mô tả:** Sinh kế hoạch 3 ngày cuốn chiếu dựa trên thông tin thể trạng, mục tiêu và hạn chế sức khỏe. Tích hợp chi tiết hướng dẫn nấu nướng và giá thành ước tính nguyên liệu.
* **Xác thực:** Tùy chọn (`OptionalJwtAuthGuard`).
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
* **Rào cản an toàn lâm sàng (400 Bad Request):**
  * `BMI < 18.5` và chọn `goal: "cut"`: Bị từ chối với thông điệp khuyến cáo y tế.
  * `age < 18` hoặc `age > 100`: Bị từ chối.
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
      "macros": {
        "protein_g": 102,
        "carbs_g": 184,
        "fat_g": 54
      }
    },
    "days": [
      {
        "day_number": 1,
        "date_offset": 0,
        "meals": [
          {
            "id": "m1_1",
            "meal_type": "breakfast",
            "name": "Bún bò Huế nạc",
            "calories": 420,
            "protein_g": 28,
            "carbs_g": 52,
            "fat_g": 11,
            "cooking_time_minutes": 20,
            "difficulty": "Dễ",
            "chef_tip": "Hạn chế húp hết nước béo nếu bạn đang trong giai đoạn giảm mỡ.",
            "ingredients": [
              {
                "category": "protein",
                "name": "Bắp bò nạc",
                "quantity": "100g",
                "estimated_price_vnd": 35000
              },
              {
                "category": "carb",
                "name": "Bún sợi to",
                "quantity": "150g",
                "estimated_price_vnd": 6000
              },
              {
                "category": "produce",
                "name": "Rau thơm, giá, hành lá",
                "quantity": "50g",
                "estimated_price_vnd": 5000
              }
            ],
            "recipe_steps": [
              {
                "step_number": 1,
                "title": "Sơ chế nguyên liệu",
                "description": "Trụng sơ bún qua nước sôi. Thịt bò rửa sạch thái lát mỏng. Rau thơm rửa sạch để ráo."
              },
              {
                "step_number": 2,
                "title": "Nấu nước dùng",
                "description": "Đun sôi nước hầm xương thanh, nêm chút mắm ruốc pha loãng và sả đập dập tạo mùi thơm đặc trưng."
              },
              {
                "step_number": 3,
                "title": "Làm chín thịt",
                "description": "Thả lát bắp bò vào nước dùng sôi chần nhanh cho thịt vừa chín tới mềm ngọt, không để lâu bị dai."
              },
              {
                "step_number": 4,
                "title": "Trình bày & Thưởng thức",
                "description": "Cho bún ra tô, xếp thịt lên trên, chan nước dùng nóng hổi, rắc hành ngò và dùng kèm đĩa rau ghém."
              }
            ],
            "recipe_notes": "Nước dùng thanh đạm, ít dầu mỡ."
          }
        ],
        "workout": {
          "id": "w1",
          "name": "Thân trên cơ bản không tạ",
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
              "instruction": "Đứng cách tường 1 sải tay, đặt hai lòng bàn tay ngang ngực, đẩy nhịp nhàng có kiểm soát."
            }
          ]
        }
      }
    ],
    "grocery_list": [
      {
        "category": "protein",
        "items": [
          { "name": "Bắp bò nạc", "quantity": "100g", "estimated_price_vnd": 35000 }
        ]
      },
      {
        "category": "carb",
        "items": [
          { "name": "Bún sợi to", "quantity": "150g", "estimated_price_vnd": 6000 }
        ]
      },
      {
        "category": "produce",
        "items": [
          { "name": "Rau thơm, giá, hành lá", "quantity": "50g", "estimated_price_vnd": 5000 }
        ]
      }
    ],
    "estimated_total_price_vnd": 46000,
    "warnings": []
  }
  ```

#### `POST /api/v1/meals/swap`
* **Mô tả:** Đổi một món ăn trong kế hoạch lấy món ăn tương đương calo (dao động trong ngưỡng cho phép `±10%`), tự động tính lại danh sách đi chợ và chi phí.
* **Request Body:**
  ```json
  {
    "profile": { ... },
    "plan": { ... },
    "day_number": 1,
    "meal_id": "m1_1"
  }
  ```
* **Response (200 OK):** Trả về đối tượng `{ "plan": { ... } }` với món mới đã được thay thế.
* **Lỗi:** `422 Unprocessable Entity` (không tìm thấy món thay thế phù hợp trong kho).

#### `POST /api/v1/exercises/swap`
* **Mô tả:** Đổi một bài tập sang động tác thay thế nhẹ hơn cùng nhóm cơ, tuân thủ chấn thương của người dùng.
* **Request Body:**
  ```json
  {
    "profile": { ... },
    "plan": { ... },
    "day_number": 1,
    "exercise_id": "e1_1"
  }
  ```
* **Response (200 OK):** Trả về đối tượng `{ "plan": { ... } }` với bài tập mới.

#### `POST /api/v1/feedback`
* **Mô tả:** Gửi phản hồi cuối ngày để hệ thống tự động thích ứng kế hoạch các ngày tiếp theo.
* **Quy tắc an toàn lâm sàng D2 (Dấu hiệu nguy hiểm):** Nếu người dùng báo cáo triệu chứng chóng mặt, khó thở, đau ngực (`danger_signs`), hệ thống **ngắt không gọi AI rebalance**, trả về khuyến cáo y tế lập tức và tự động gán ngày hôm sau nghỉ ngơi hoặc đi bộ nhẹ.
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
* **Response (200 OK):**
  ```json
  {
    "plan": { ... },
    "summary": "Đã giảm khối lượng bài tập thân trên và bổ sung thêm tinh bột cho ngày mai.",
    "danger_warning": null
  }
  ```

---

### 3.4. Nhóm Lịch sử Kế hoạch (History)

#### `GET /api/v1/plans/history`
* **Mô tả:** Lấy danh sách tóm tắt các kế hoạch của tài khoản đã đăng nhập, sắp xếp theo thời gian mới nhất lên đầu.
* **Xác thực:** Yêu cầu Bearer Token (`JwtAuthGuard`).
* **Response (200 OK):**
  ```json
  {
    "plans": [
      {
        "id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
        "target_calories": 1633,
        "created_at": "2026-11-18T10:30:00.000Z"
      }
    ]
  }
  ```

#### `GET /api/v1/plans/history/:id`
* **Mô tả:** Lấy toàn bộ nội dung JSON chi tiết của một kế hoạch theo UUID.
* **Xác thực:** Yêu cầu Bearer Token (`JwtAuthGuard`).
* **Response (200 OK):** Toàn văn JSON của kế hoạch 3 ngày (`MealPlanResponseDto`).
* **Lỗi:** `400 Bad Request` (id không phải UUID), `404 Not Found` (không tồn tại hoặc thuộc tài khoản khác).
