# AGENTS.md — SmartFit AI

> **Lưu ý:** Theo chuẩn cấu hình AI agent chính thức từ OpenAI / ChatGPT ([learn.chatgpt.com/docs/agent-configuration/agents-md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)), tên tệp tiêu chuẩn cho agent là [**`AGENTS.md`**](AGENTS.md). Tệp này được tạo song song để đảm bảo tính tương thích tuyệt đối cho cả hai cách gọi (`agent.md` và `AGENTS.md`).
>
> **Single source of truth cho tiến độ & roadmap:** [`docs/PLAN.md`](docs/PLAN.md).
> **Yêu cầu & hợp đồng API:** [`BRD.md`](BRD.md) (v2.6.0).

---

## 1. Project Overview & Architecture

**SmartFit AI** là hệ thống lập kế hoạch dinh dưỡng và tập luyện thích ứng 3 ngày cho người Việt (Dự án tốt nghiệp VKU).

### Cấu trúc Monorepo

- **`backend_api/`**: NestJS 12 (TypeScript, Node.js ESM).
  - **Database:** TypeORM kết nối MySQL (`smartfit_db`) cho lưu trữ thật; SQLite in-memory (`better-sqlite3`) cho test tự động.
  - **AI Engine:** Groq API (`PLAN_AI_PROVIDER=groq`, model `openai/gpt-oss-120b` qua `GroqPlanService`) với cơ chế fallback tự động về `src/plan/data/sample-plan.json` khi thiếu API key hoặc lỗi mạng.
  - **Auth:** Email + Mật khẩu (băm `scrypt`), JWT 7 ngày, hỗ trợ Guest Mode (`AUTH_MODE=mock`).
  - **Swagger API docs:** `http://localhost:3000/docs`.
- **`frontend_app/`**: Flutter 3.x (Android, iOS, macOS, Web).
  - **State Management:** `Provider` / `ChangeNotifier` (`PlanProvider`, `AuthProvider`, `GroceryProvider`).
  - **Lưu trữ cục bộ:** `shared_preferences`.
  - **Giao diện:** Tiếng Việt, Material 3 (brand green).
- **`ai_workspace/`**: Dự án Node/TS độc lập để thử nghiệm prompt (`npm run experiment`) trước khi đưa vào backend.
- **`docs/`**: `PLAN.md` (roadmap chính), `BRD.md` (đặc tả nghiệp vụ v2.6.0), các quyết định kỹ thuật `D1`–`D6`.

---

## 2. Dev Environment Tips

### Lệnh chạy & Quản lý gói

- **Backend (`backend_api/`):**
  ```bash
  cd backend_api
  npm install
  cp .env.example .env     # Tùy chọn: GROQ_API_KEY, AUTH_MODE, MySQL config
  npm run start:dev        # Chạy NestJS watch mode tại http://localhost:3000
  ```
- **Frontend (`frontend_app/`):**
  ```bash
  cd frontend_app
  flutter pub get
  flutter run -d chrome    # Chạy Web debug (kết nối backend http://localhost:3000)
  # Android emulator:
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  # Thiết bị thật qua mạng LAN:
  flutter run --dart-define=API_BASE_URL=http://192.168.1.x:3000
  ```
- **Prompt Experiments (`ai_workspace/`):**
  ```bash
  cd ai_workspace
  npm install
  npm run experiment
  ```

### Chế độ giả lập (Mock Mode)

- Hệ thống mặc định chạy được ngay mà không cần API key ngoài:
  - Thiếu `GROQ_API_KEY` → tự chuyển sang thực đơn mẫu chuẩn (`source: "sample"`).
  - `AUTH_MODE=mock` → cho phép token dạng `mock:<email>`, bỏ qua Google OAuth để test nhanh.

---

## 3. Testing & Verification Instructions (Quy ước kiểm thử)

### Hợp đồng kiểm thử (Definition of Done)

1. **Tuyệt đối không đánh dấu DONE bất kỳ task nào khi chưa chạy và pass kiểm thử.**
2. **Không xoá, bỏ qua hoặc comment-out test bị fail** để ép CI pass. Phải sửa code gốc để test pass.
3. Khi thay đổi schema API giữa Backend và Frontend, phải cập nhật fixture và kiểm tra đồng bộ cả hai bên.

### Kiểm thử Backend (`backend_api/`)

```bash
# Typecheck toàn bộ src và test
npm run typecheck

# Lint kiểm tra lỗi cú pháp và type (oxlint)
npm run lint

# Chạy toàn bộ Unit tests (500+ tests)
npm test

# Chạy riêng 1 file test:
npx vitest run src/plan/plan.service.spec.ts
npx vitest run -t "tên test case"

# Chạy E2E tests (SQLite in-memory)
npm run test:e2e

# Build và chạy smoke test:
npm run build
npm run test:smoke

# Cập nhật fixtures khi đổi contract BRD §6:
npm run fixtures:update
```

### Kiểm thử Frontend (`frontend_app/`)

```bash
# Phân tích tĩnh code Flutter (0 warning, 0 error)
flutter analyze

# Chạy toàn bộ test (190+ tests, không cần bật backend)
flutter test

# Chạy một file test cụ thể:
flutter test test/services/api_client_test.dart
flutter test test/models/contract_test.dart

# Format code theo chuẩn 120 ký tự:
dart format --line-length 120 lib/ test/
```

---

## 4. Architectural & Coding Conventions

### Quy tắc Backend (`backend_api/`)

1. **Node ESM (`"type": "module"`):** Mọi import tương đối trong TypeScript **BẮT BUỘC** phải có đuôi `.js` (ví dụ `import { PlanService } from './plan.service.js'`).
2. **Quan hệ TypeORM:** Luôn bọc kiểu quan hệ entity trong `Relation<T>` (ví dụ `user: Relation<User>`) để tránh lỗi crash ESM circular dependency khi khởi động.
3. **Database Migration:** Không dùng `synchronize: true` trên môi trường thật/dev chung. Thay đổi bảng phải qua migration (`migrationsRun: true`).
4. **DTO & Validation:** DTO đầu vào phải khai báo decorator của `class-validator`. Pipe toàn cục sẽ tự động lọc thuộc tính lạ (`whitelist: true`).

### Quy tắc Frontend (`frontend_app/`)

1. **Provider Architecture:** Widget **KHÔNG ĐƯỢC** gọi trực tiếp `ApiClient` hay `http`. Mọi thao tác phải thông qua `PlanProvider`, `AuthProvider` hoặc `GroceryProvider`.
2. **Độ chính xác hợp đồng API:** Model `lib/models/api/` phải đảm bảo `fromJson(json).toJson() == json`. Giá trị số dùng kiểu `num`.
3. **Xử lý lỗi & Giao diện:** Lỗi API trả về bọc trong `ApiException` với thông điệp Tiếng Việt thân thiện. Wrap `ListTile` trong `Material` thay vì `Container` màu để tránh assertion trong debug mode.

---

## 5. Security & Safety Guardrails (Rào cản an toàn nghiêm ngặt)

1. **Bảo mật dữ liệu sức khoẻ nhạy cảm (D4 & D5):**
   - Thông tin dị ứng, chấn thương và bệnh nền (`allergies`, `injuries`, `health_conditions`) **TUYỆT ĐỐI KHÔNG LƯU VÀO DATABASE** và **KHÔNG GHI VÀO LOG SERVER**.
   - Dữ liệu chỉ lưu trên máy người dùng (`shared_preferences`), gửi tạm qua request để tính toán rồi giải phóng khỏi bộ nhớ.
2. **An toàn y tế & tập luyện (D6):**
   - **BMI < 18.5:** Chặn chọn "Giảm mỡ" ở cả UI và Backend (trả mã 400). Chỉ cho phép "Duy trì" hoặc "Tăng cơ".
   - **Độ tuổi tối thiểu:** 18 tuổi (18–100).
   - **Phụ nữ mang thai / cho con bú:** Nghiêm cấm thâm hụt calo, ép bài tập về mức 1 nhẹ nhàng.
   - **Dấu hiệu nguy hiểm khi tập (D2):** Khi user báo chóng mặt, khó thở, đau ngực trong feedback cuối ngày → **KHÔNG gọi AI cân đối lại bài**, lập tức hiển thị khuyến cáo ngưng tập, đi khám bác sĩ và gán ngày hôm sau nghỉ ngơi hoặc đi bộ nhẹ.
3. **Bảo mật bí mật cấu hình:** Không commit `.env` hoặc API keys lên git.

---

## 6. Directory-Specific Routing (Bản đồ thư mục cho Agent)

| Nghiệp vụ / Tính năng | Đường dẫn chính |
|---|---|
| **Tạo kế hoạch & Tính chỉ số (BMR/TDEE)** | `backend_api/src/plan/daily-target.ts`<br>`backend_api/src/plan/plan.service.ts`<br>`backend_api/src/plan/plan-validation.ts` |
| **Prompt AI & Dữ liệu mẫu Fallback** | `backend_api/src/plan/groq-plan.service.ts`<br>`backend_api/src/plan/data/sample-plan.json`<br>`backend_api/src/plan/data/restriction-keywords.json` |
| **Đổi món, đổi bài & Feedback cuối ngày** | `backend_api/src/plan/adjust/`<br>`backend_api/src/plan/swap-pools.ts` |
| **Tài khoản & Xác thực** | `backend_api/src/auth/`<br>`backend_api/src/database/entities/user.entity.ts` |
| **Màn hình & Điều hướng Flutter** | `frontend_app/lib/screens/`<br>`frontend_app/lib/main.dart` (`AppScreen` & `MainShell`) |
| **Quản lý State Flutter** | `frontend_app/lib/providers/plan_provider.dart`<br>`frontend_app/lib/providers/auth_provider.dart`<br>`frontend_app/lib/providers/grocery_provider.dart` |
| **Lộ trình phát triển & Trạng thái** | `docs/PLAN.md` |

---

## 7. Vòng lặp phản hồi của Agent (Continuous Feedback Loop)

Khi agent phát hiện lỗi lặp lại, đặc thù công cụ, hoặc quy ước mới của repo trong quá trình phát triển, hãy cập nhật lại vào tệp này (`AGENTS.md` / `agent.md`) để các phiên làm việc tiếp theo của AI tự động kế thừa.
