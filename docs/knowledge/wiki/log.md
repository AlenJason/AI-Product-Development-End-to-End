# Nhật ký thay đổi Wiki

Ghi lại các thay đổi wiki theo thời gian. Chỉ thêm vào, không xóa.

---

2026-09-22 — Khởi tạo wiki qua /kb-init
2026-09-22 — Dịch toàn bộ wiki sang tiếng Việt; thêm bài [[reference-materials]] tổng hợp tài liệu/công nghệ liên quan (Gemini SDK, NestJS, Flutter, Bảng thành phần thực phẩm Việt Nam, công thức Mifflin-St Jeor)
2026-09-22 — Đổi tên file tai-lieu-tham-khao.md → reference-materials.md (quy ước: tên file tiếng Anh, nội dung tiếng Việt)
2026-09-22 — Migrate `backend_api/` và `ai_workspace/` từ `@google/generative-ai` (đã khai tử) sang `@google/genai`; nâng model mặc định `gemini-2.5-flash` → `gemini-3.8-flash`; cập nhật BRD.md mục 4 khớp theo; đã build + smoke-test lại backend, cập nhật critical-constraints.md mục 8–9 từ "phát hiện" sang "đã fix"
2026-09-22 — Quyết định thêm tài khoản người dùng (Google Sign-In) + lịch sử kế hoạch (FR-6, FR-7), kéo theo cần DB (SQLite/TypeORM) — cập nhật BRD.md lên v2.2.0 (mục 4, 5, 6.3, 7, 8, 9), thêm ràng buộc #10 vào critical-constraints.md, thêm mảng trọng tâm #5 vào docs/knowledge/CLAUDE.md. Chưa có code — chỉ mới là quyết định kiến trúc, chờ xác nhận trước khi scaffold
2026-09-22 — Làm rõ trong BRD.md (NFR mục 7.6) và critical-constraints.md (ràng buộc #11): SQLite nằm trên máy chạy backend, không phải trên thiết bị người dùng — tránh nhầm lẫn với shared_preferences
2026-09-24 — PLAN.md giai đoạn 0: sửa reference-materials.md (ràng buộc `sdk: ^3.13.1` đã thoả yêu cầu Dart 3.9+ của shared_preferences — ghi "cần nâng" trước đó là sai); sửa ràng buộc #11: host deploy phải có ổ lưu trữ bền, Render free không dùng được với SQLite; thêm reference-materials.md mục 1.4 về auth key thay cho standard key của Gemini API
