# Hướng dẫn Thiết kế API & Tích hợp Gemini (Từ ECC Skill & Dự án)

Tài liệu này tổng hợp toàn bộ quy chuẩn thiết kế REST API chuẩn từ **ECC (`api-design` Skill)** kết hợp với kiến trúc tích hợp **Google Gemini SDK** của dự án.

---

## 1. Nguyên Tắc Thiết Kế REST API (ECC API Design)

### 1.1. Cấu trúc URL (Resource Naming)
- Sử dụng danh từ, số nhiều, chữ thường, dạng `kebab-case`.
- Không lồng ghép động từ vào URL.

| Chuẩn (Good) | Không Chuẩn (Bad) | Giải thích |
|---|---|---|
| `GET /api/v1/plans` | `GET /api/v1/getPlans` | Không dùng động từ trong URL |
| `GET /api/v1/users/123/history` | `GET /api/v1/user_history?id=123` | Dùng quan hệ lồng nhau thể hiện sở hữu |
| `POST /api/v1/meals/swap` | `POST /api/v1/swapMeal` | Dùng hành động dạng sub-resource |

### 1.2. Phương thức HTTP (HTTP Methods)
- `GET`: Đọc dữ liệu (Idempotent & Safe).
- `POST`: Tạo mới tài nguyên hoặc kích hoạt tác vụ.
- `PUT`: Thay thế toàn bộ tài nguyên.
- `PATCH`: Cập nhật từng phần của tài nguyên.
- `DELETE`: Xoá tài nguyên.

### 1.3. Mã trạng thái HTTP (HTTP Status Codes)
- **Thành công (2xx)**:
  - `200 OK`: Trả về dữ liệu thành công cho GET, PUT, PATCH.
  - `201 Created`: Tạo mới thành công (POST), kèm header `Location`.
  - `204 No Content`: Xoá hoặc cập nhật thành công không kèm body.
- **Lỗi Client (4xx)**:
  - `400 Bad Request`: Sai định dạng cú pháp JSON.
  - `401 Unauthorized`: Chưa đăng nhập / thiếu token hợp lệ.
  - `403 Forbidden`: Đã đăng nhập nhưng không có quyền truy cập.
  - `404 Not Found`: Không tìm thấy tài nguyên.
  - `409 Conflict`: Trùng lặp dữ liệu (email đã đăng ký, conflict state).
  - `422 Unprocessable Entity`: Dữ liệu không thỏa mãn nghiệp vụ (Validation error).
  - `429 Too Many Requests`: Vượt quá giới hạn gọi API (Rate limit).
- **Lỗi Server (5xx)**:
  - `500 Internal Server Error`: Lỗi hệ thống ngoài dự kiến (không để lộ stack trace ra ngoài).
  - `504 Gateway Timeout`: Hết hạn chờ upstream (Gemini AI timeout).

### 1.4. Chuẩn định dạng Response & Error Format

#### Success Response:
```json
{
  "data": {
    "id": "plan_abc123",
    "days": [...]
  }
}
```

#### Error Response:
```json
{
  "error": {
    "code": "validation_error",
    "message": "Thông tin hồ sơ không hợp lệ",
    "details": [
      {
        "field": "calories",
        "message": "Calories phải nằm trong khoảng 1000 - 5000 kcal",
        "code": "out_of_range"
      }
    ]
  }
}
```

---

## 2. Quy Chuẩn Tích Hợp Gemini AI Cho API

### 2.1. Quản lý SDK & Client
- Gọi Gemini tập trung tại `backend_api/src/plan/gemini.service.ts` qua SDK `@google/genai`.
- Bắt buộc bật `generationConfig.responseMimeType: 'application/json'` để đảm bảo AI sinh JSON hợp lệ.

### 2.2. Kiểm soát Timeout & Retry
- **Timeout đơn**: Cấu hình `GEMINI_TIMEOUT_MS` (mặc định 20.000 ms). Bắt các lỗi `504 DEADLINE_EXCEEDED` và `AbortError` chuyển thành `GeminiTimeoutError`.
- **Tổng Timeout & Retry**: `GEMINI_TOTAL_TIMEOUT_MS` (mặc định 40.000 ms). Tối đa gọi lại **1 lần**.
- **Fallback an toàn**: Nếu Gemini thất bại hoặc timeout, tự động trả về plan/thực đơn mẫu hợp lệ để ứng dụng không bị gián đoạn.

### 2.3. Kiểm tra Hợp đồng Dữ liệu (Contract Validation)
- Mọi dữ liệu JSON do Gemini trả về phải đi qua pipeline kiểm tra nghiêm ngặt:
  1. `validatePlanContract()`: Kiểm tra đúng schema `PlanResponse`.
  2. `ingredientAvoidRule()`: Lọc bỏ thực phẩm dị ứng / kiêng cữ.
  3. `exerciseAvoidRule()` / `capWorkoutLevel()`: Kiểm tra an toàn bài tập và chấn thương.
  4. Cân đối phân bổ Calo và Macro (Protein, Carbs, Fat).

---

## 3. Checklist Thiết Kế & Kiểm Thử API

- [ ] URL dùng danh từ, số nhiều, `kebab-case`.
- [ ] Sử dụng đúng HTTP Method và Status Code.
- [ ] Validate đầu vào bằng schema trước khi xử lý (Zod/DTO).
- [ ] Cấu trúc Error Response thống nhất (`code`, `message`, `details`).
- [ ] Bảo vệ quyền sở hữu tài nguyên (User chỉ truy cập plan/profile của chính mình).
- [ ] Tích hợp cơ chế timeout và fallback cho các API gọi Gemini AI.
- [ ] Chạy unit test & contract test trước khi đưa vào hoạt động (`npm test`).
