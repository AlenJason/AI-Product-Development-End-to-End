# SmartFit AI — System Flowcharts & Sequence Diagrams (Sơ đồ Luồng Dữ liệu & Trình tự)

> **Dự án:** SmartFit AI — Hệ thống gợi ý & điều chỉnh thực đơn món Việt và bài tập thích ứng 3 ngày  
> **Chuẩn kỹ thuật:** Mermaid Diagram Standards  
> **Tài liệu tham chiếu:** [API_DOCUMENTATION.md](API_DOCUMENTATION.md), [ARCHITECTURE.md](ARCHITECTURE.md), [BRD.md](../BRD.md) v2.6.0  

---

## Mục lục Sơ đồ
1. [Sơ đồ 1: Kiến trúc Tổng thể & Luồng Giao tiếp Hệ thống](#1-kiến-trúc-tổng-thể--luồng-giao-tiếp-hệ-thống)
2. [Sơ đồ 2: Luồng Xác thực & Tự động Đồng bộ Hồ sơ Thể chất](#2-luồng-xác-thực--tự-động-đồng-bộ-hồ-sơ-thể-chất)
3. [Sơ đồ 3: Luồng Khởi tạo Kế hoạch An toàn & Động cơ AI Hybrid](#3-luồng-khởi-tạo-kế-hoạch-an-toàn--động-cơ-ai-hybrid)
4. [Sơ đồ 4: Luồng Trích xuất Hướng dẫn Nấu ăn & Ước tính Ngân sách](#4-luồng-trích-xuất-hướng-dẫn-nấu-ăn--ước-tính-ngân-sách)
5. [Sơ đồ 5: Luồng Đổi món, Đổi bài & Vòng lặp Phản hồi Cuối ngày Thích ứng](#5-luồng-đổi-món-đổi-bài--vòng-lặp-phản-hồi-cuối-ngày-thích-ứng)
6. [Sơ đồ 6: Luồng Bảo mật Quyền riêng tư & Dữ liệu Nhạy cảm (D4 & D5)](#6-luồng-bảo-mật-quyền-riêng-tư--dữ-liệu-nhạy-cảm-d4--d5)

---

## 1. Kiến trúc Tổng thể & Luồng Giao tiếp Hệ thống

Sơ đồ mô tả sự tương tác giữa 4 tầng chính: Client (Flutter), API Gateway / Backend (NestJS), Động cơ Trí tuệ Nhân tạo (Groq / Gemini / Fallback), và Cơ sở dữ liệu (MySQL / LocalStorage).

```mermaid
flowchart TD
    subgraph Client ["Tầng Client (Flutter App)"]
        UI["Giao diện người dùng (Screens & Widgets)"]
        Prov["Quản lý trạng thái (Provider: Plan, Auth, Grocery)"]
        Pref[("Local Storage (shared_preferences)\n- JWT token\n- Dị ứng, chấn thương, bệnh nền D4/D5")]
        UI <--> Prov
        Prov <--> Pref
    end

    subgraph Backend ["Tầng Máy chủ API (NestJS 12)"]
        Pipes["ValidationPipe (class-validator & sanitization)"]
        Guards{"Auth Guard (JwtAuthGuard / OptionalJwtAuthGuard)"}
        AuthCtrl["Auth Controller (/auth, /me)"]
        PlanCtrl["Plan Controller (/generate-plan)"]
        AdjustCtrl["Adjust Controller (/meals/swap, /exercises/swap, /feedback)"]
        HistCtrl["History Controller (/plans/history)"]
        
        Pipes --> Guards
        Guards --> AuthCtrl
        Guards --> PlanCtrl
        Guards --> AdjustCtrl
        Guards --> HistCtrl
    end

    subgraph AI ["Tầng Động cơ AI (Hybrid AI Engine)"]
        GroqService["GroqPlanService (openai/gpt-oss-120b)"]
        GeminiService["GeminiService (gemini-2.5-flash)"]
        FallbackEngine["Fallback Engine (sample-plan.json & swap-pools)"]
    end

    subgraph Storage ["Tầng Cơ sở Dữ liệu"]
        MySQL[("MySQL smartfit_db\n- users\n- plan_records\n- feedback_receipts")]
    end

    Prov -- "HTTP REST Request (JSON UTF-8)" --> Pipes
    AuthCtrl <--> MySQL
    HistCtrl <--> MySQL
    PlanCtrl <--> MySQL
    AdjustCtrl <--> MySQL

    PlanCtrl --> GroqService
    PlanCtrl --> GeminiService
    GroqService -. "Timeout / Lỗi / Thiếu Key" .-> FallbackEngine
    GeminiService -. "Timeout / Lỗi / Thiếu Key" .-> FallbackEngine
    AdjustCtrl --> FallbackEngine
    AdjustCtrl -. "AI Prompt Rebalance" .-> GroqService
```

---

## 2. Luồng Xác thực & Tự động Đồng bộ Hồ sơ Thể chất

Quy trình giải quyết bài toán: Người dùng chỉ cần nhập hồ sơ thể chất (tuổi, chiều cao, cân nặng, giới tính, mục tiêu, mức vận động) trong lần đầu tiên; các lần đăng nhập tiếp theo hệ thống tự động nạp hồ sơ từ DB vào ứng dụng mà không bắt nhập lại.

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant App as Flutter Client (UI & AuthProvider)
    participant API as NestJS Backend (AuthController)
    participant DB as MySQL (users table)
    participant Local as Local Storage (shared_preferences)

    User->>App: Nhập Email & Mật khẩu
    App->>API: POST /api/v1/auth/login
    API->>DB: Truy vấn user & xác thực mật khẩu (scrypt)
    DB-->>API: User Record
    API-->>App: HTTP 200 OK (access_token + user info)
    App->>Local: Lưu access_token & user profile

    opt Tự động nạp hồ sơ thể chất
        App->>API: GET /api/v1/me/profile (Header: Bearer token)
        API->>DB: SELECT profile_json FROM users WHERE id = :userId
        DB-->>API: profile_json
        API-->>App: HTTP 200 OK {"profile": {...}}
        alt Hồ sơ đã tồn tại trong DB
            App->>App: Tự động điền (Auto-fill) vào BasicInfoScreen & ActivityScreen
            App-->>User: Hiển thị giao diện sẵn sàng, không cần nhập lại
        else Tài khoản mới (profile là null)
            App-->>User: Mở form nhập liệu Onboarding ban đầu
        end
    end

    opt Khi người dùng tạo kế hoạch mới hoặc chỉnh sửa hồ sơ
        User->>App: Cập nhật chỉ số mới (ví dụ cân nặng)
        App->>API: PUT /api/v1/me/profile (Header: Bearer token)
        API->>API: Lọc bỏ thông tin nhạy cảm D4/D5 (chỉ giữ tuổi, chiều cao, cân nặng, giới tính)
        API->>DB: UPDATE users SET profile_json = :profile WHERE id = :userId
        DB-->>API: Cập nhật thành công
        API-->>App: HTTP 200 OK {"success": true}
    end
```

---

## 3. Luồng Khởi tạo Kế hoạch An toàn & Động cơ AI Hybrid

Luồng xử lý tính toán năng lượng y khoa (Mifflin-St Jeor), kiểm tra rào cản lâm sàng (D6) và điều phối giữa mô hình ngôn ngữ lớn (Groq LLM) và bộ quy tắc dự phòng mẫu (Fallback Engine).

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant App as Flutter Client (PlanProvider)
    participant API as NestJS Backend (PlanService)
    participant Safety as Profile Safety Validator (D6)
    participant AI as GroqPlanService (Groq API)
    participant Fallback as Fallback Data Engine
    participant DB as MySQL (plan_records)

    User->>App: Nhấn "Tạo kế hoạch 3 ngày"
    App->>API: POST /api/v1/generate-plan (Payload thể trạng & mục tiêu)
    
    API->>Safety: Kiểm tra rào cản an toàn lâm sàng (D6)
    alt BMI < 18.5 chọn "Giảm mỡ" (Cut) HOẶC Tuổi ngoài 18-100
        Safety-->>API: Vi phạm an toàn lâm sàng
        API-->>App: HTTP 400 Bad Request (Thông điệp cảnh báo y tế)
        App-->>User: Hiển thị hộp thoại cảnh báo an toàn
    else Hợp lệ
        API->>API: Tính BMR (Mifflin-St Jeor) & TDEE
        API->>API: Áp dụng quy tắc calo D1 (Cut: -300, Bulk: +250, Maintain: 0)
        API->>API: Tính Macro chuẩn (25% Đạm, 45% Tinh bột, 30% Chất béo)
        
        alt Có GROQ_API_KEY & Network ổn định
            API->>AI: Gửi System Prompt + Dữ liệu người dùng (Timeout: 20s)
            AI-->>API: Trả về JSON kế hoạch 3 ngày
            API->>API: Validate JSON Schema & kiểm tra tỷ lệ dinh dưỡng
        else Thiếu Key / Timeout / Lỗi Schema
            API->>Fallback: Kích hoạt Fallback Engine
            Fallback->>Fallback: Lấy sample-plan.json
            Fallback->>Fallback: Scale khẩu phần khớp target calories
            Fallback->>Fallback: Lọc dị ứng & chấn thương theo từ khóa
            Fallback-->>API: Trả về kế hoạch an toàn (source: "sample")
        end

        opt Người dùng đã đăng nhập
            API->>DB: INSERT INTO plan_records (id, user_id, plan_json)
        end

        API-->>App: HTTP 200 OK (Kế hoạch 3 ngày hoàn chỉnh)
        App-->>User: Hiển thị Dashboard kế hoạch ăn & tập
    end
```

---

## 4. Luồng Trích xuất Hướng dẫn Nấu ăn & Ước tính Ngân sách

Mô tả cách ứng dụng tổ chức dữ liệu chi tiết cho từng món ăn (nguyên liệu, lượng gam, giá tiền ước tính VND, các bước sơ chế - chế biến - trình bày) và bộ lọc theo mức giá.

```mermaid
flowchart TD
    Plan["Dữ liệu Kế hoạch 3 ngày (MealPlan)"] --> Days["3 Ngày cuốn chiếu"]
    Days --> Meals["Danh sách món ăn (Sáng, Trưa, Tối, Phụ)"]

    subgraph MealDetail ["Chi tiết Món ăn (Meal Data Contract)"]
        Nutrition["Thông tin Dinh dưỡng\n- Calo (kcal)\n- Đạm (g), Tinh bột (g), Béo (g)"]
        
        Ingredients["Danh sách Nguyên liệu (Ingredients)\n- Tên nguyên liệu (Thịt bò, Rau muống...)\n- Định lượng chuẩn khẩu phần (150g, 200g...)\n- Giá tiền ước tính VND (dựa theo thời giá VN)"]
        
        CookingGuide["Hướng dẫn Nấu chi tiết (RecipeGuide)\n- Thời gian nấu (phút)\n- Độ khó (Dễ / Trung bình / Khó)\n- Các bước nấu đánh số thứ tự (recipe_steps):\n  * Bước 1: Sơ chế nguyên liệu\n  * Bước 2: Nấu nước dùng / Chế biến chính\n  * Bước 3: Làm chín & Nêm nếm\n  * Bước 4: Trình bày & Thưởng thức\n- Lời khuyên đầu bếp (chef_tip) lành mạnh"]
    end

    Meals --> Nutrition
    Meals --> Ingredients
    Meals --> CookingGuide

    subgraph GroceryAggregator ["Tổng hợp Đi chợ & Ngân sách"]
        Filter["Bộ lọc Ngân sách / Mức giá\n(Tiết kiệm, Tiêu chuẩn, Thịnh soạn)"]
        Group["Gom nhóm 3 loại (D3):\n1. Đạm (Protein)\n2. Rau củ quả (Produce)\n3. Tinh bột & Gia vị (Carb & Pantry)"]
        TotalCost["Tổng ước tính chi phí nguyên liệu (VND)"]
    end

    Ingredients --> GroceryAggregator
```

---

## 5. Luồng Đổi món, Đổi bài & Vòng lặp Phản hồi Cuối ngày Thích ứng

Sơ đồ thích ứng rolling 3-day cycle: Cho phép đổi món ăn (lệch calo ≤ ±10%), đổi bài tập (nhẹ hơn cùng nhóm cơ), và vòng lặp phản hồi cuối ngày với rào cản ngắt khẩn cấp D2 (Danger Signs Circuit Breaker).

```mermaid
flowchart TD
    StartFeedback["Cuối mỗi ngày (Ngày 1 / 2 / 3)"] --> FeedbackForm["Form phản hồi 3 câu hỏi (D2):\n1. Cường độ tập: Nhẹ / Vừa / Rất mệt\n2. Thể trạng: Bình thường, Căng cơ, Đau khớp, Thiếu ngủ, Chóng mặt/Đau ngực\n3. Ăn uống: Đủ / Nhiều hơn / Ít hơn"]

    FeedbackForm --> CheckDanger{"Có dấu hiệu nguy hiểm?\n(chóng mặt, khó thở, đau ngực)"}

    CheckDanger -- "CÓ (Dấu hiệu nguy hiểm)" --> D2SafeAction["Rào cản an toàn D2 (Circuit Breaker)\n- KHÔNG gọi AI rebalance\n- Phát thông báo dừng tập & đi khám bác sĩ\n- Tự động gán ngày tiếp theo: NGHỈ hoặc Đi bộ nhẹ"]
    
    CheckDanger -- "KHÔNG" --> SendAPI["Gửi POST /api/v1/feedback lên server"]

    SendAPI --> CheckDay{"Ngày số mấy?"}
    
    CheckDay -- "Ngày 1 hoặc Ngày 2" --> AdjustNext["Điều chỉnh ngày kế tiếp:\n- Mệt/đau khớp: Giảm hiệp, đổi bài nhẹ, thêm giãn cơ\n- Ăn thừa/thiếu: Bù trừ calo hợp lý (không dưới BMR)"]
    AdjustNext --> KeepPlanID["Giữ nguyên plan_id hiện tại & lưu DB"]

    CheckDay -- "Ngày 3 (Kết thúc chu kỳ)" --> NewCycle["Khởi tạo chu kỳ 3 ngày mới:\n- Sinh plan_id mới hoàn toàn\n- Cập nhật mục tiêu thể lực mới"]

    subgraph InteractiveSwaps ["Tính năng Đổi linh hoạt giữa chu kỳ"]
        MealSwap["Đổi món ăn (/meals/swap)\n- Tìm món tương đương calo ±10%\n- Tự động cập nhật lại danh sách đi chợ"]
        ExSwap["Đổi bài tập (/exercises/swap)\n- Tìm động tác nhẹ hơn cùng nhóm cơ\n- Tôn trọng giới hạn chấn thương"]
    end
```

---

## 6. Luồng Bảo mật Quyền riêng tư & Dữ liệu Nhạy cảm (D4 & D5)

Thiết kế kiến trúc bảo vệ dữ liệu sức khỏe người dùng: Tuyệt đối không lưu vết bệnh lý cá nhân tại cơ sở dữ liệu trung tâm.

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant UI as Màn hình Cá nhân / Onboarding
    participant Local as Client Local Storage (Offline)
    participant Memory as Backend Memory (RAM Ephemeral)
    participant DB as MySQL Database

    User->>UI: Nhập thông tin sức khỏe (Dị ứng hải sản, đau khớp gối, trào ngược)
    UI->>Local: Ghi vào shared_preferences trên máy thiết bị

    Note over UI, Local: Dữ liệu nhạy cảm chỉ nằm an toàn trên thiết bị của người dùng

    User->>UI: Tạo hoặc điều chỉnh kế hoạch
    UI->>Memory: Gửi kèm trong Body Request (chỉ đọc trong phiên xử lý)
    
    Note over Memory: Bộ lọc từ khóa & AI Prompt xử lý trong RAM tạm

    Memory->>Memory: Lọc món ăn, lọc bài tập, tính toán kế hoạch an toàn
    
    Memory->>DB: Lưu user profile & kế hoạch (ĐÃ LỌC BỎ HOÀN TOÀN DỊ ỨNG & BỆNH LÝ)
    
    Note over DB: Bảng users & plan_records TUYỆT ĐỐI KHÔNG CÓ cột allergies, injuries, health_conditions

    Memory-->>UI: Trả về kết quả kế hoạch
    Note over Memory: Dữ liệu nhạy cảm được hủy hoàn toàn khỏi RAM (Garbage Collected)
```
