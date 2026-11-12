# Groq: nhà cung cấp AI mặc định

Sau khi người dùng xác nhận tạo kế hoạch Groq thành công trên app, toàn bộ đường gọi AI runtime đã chuyển sang Groq: tạo kế hoạch, đổi món, đổi bài, cân đối bữa ăn sau feedback và tạo chu kỳ mới ngày 3. Luật an toàn, validation, kho dự phòng, auth/history không thay đổi. Gemini còn giữ làm lựa chọn tương thích và kiểm thử lịch sử; trong chế độ Groq không khởi tạo Google SDK client.

Trong `.env` (không commit khóa):

```dotenv
PLAN_AI_PROVIDER=groq
GROQ_API_KEY=
GROQ_MODEL=openai/gpt-oss-120b
GROQ_TIMEOUT_MS=60000
GROQ_TOTAL_TIMEOUT_MS=90000
```

Chạy PowerShell từ backend_api:

```powershell
npm.cmd run build
node --env-file=.env scripts/test-groq-plan.mjs
npm.cmd run start:dev
```

Script dùng hồ sơ tổng hợp, tối đa hai lần gọi trong giới hạn tổng, không in khóa hoặc thông tin sức khỏe. `passed: true` chỉ khi source là `groq`, nội dung vượt validation backend, có ba ngày, grocery và IDs được backend dựng. `source: sample` là fallback, không tính Groq thành công. Dùng JSON mode, chưa dùng strict JSON Schema; validation cấu trúc/calo/dị ứng vẫn bắt buộc ở backend.

Sau đó thử app Flutter: tạo kế hoạch và kiểm tra nhãn `Kế hoạch do AI tạo (groq)`. API response có thêm source `groq`; client Flutter đã được cập nhật để parse và lưu giá trị này. Các bản client cũ cần cập nhật.

`GET /health` có `ai_provider: groq`, `ai_status: configured|fallback`. Trường `gemini` cũ chỉ phản ánh cấu hình Gemini để giữ tương thích client. `configured` xác nhận có khóa, chưa chứng minh kết nối hay chất lượng model.

Quay lại Gemini bằng `PLAN_AI_PROVIDER=gemini`, rồi restart backend. Không cần đổi khóa Gemini.

Tài liệu nhà cung cấp: https://console.groq.com/docs/openai và https://console.groq.com/docs/structured-outputs.

## Bằng chứng thử ban đầu 26/10/2026

- Backend typecheck, build, lint đạt; 383 unit và 84 E2E đạt. Có test HTTP endpoint với phản hồi Groq giả và lỗi 403, cùng unit cho 401/429/timeout/JSON sai/truncated.
- Flutter: 23 tests contract và màn tạo kế hoạch đạt, gồm roundtrip source `groq`.
- Live Groq: chưa chạy do thiếu GROQ_API_KEY. Script dừng trước khi gọi mạng. Không coi test giả lập là phép đo chất lượng hoặc latency thật; chưa chuyển toàn bộ dự án.

Sau đó người dùng cung cấp ảnh app có source `groq`, mục tiêu 1960 kcal; ngày 1 và 3 cộng đúng 1960. Đây là bằng chứng tạo kế hoạch thật trên máy người dùng, không phải nghiệm thu các chức năng còn lại. Prompt đã bổ sung tên bài tiếng Việt và không sử dụng ghế/chai nước; các quy tắc ngôn ngữ/dụng cụ hiện là hướng dẫn prompt, chưa phải validator ngữ nghĩa.

Client Flutter chờ tối đa 105 giây cho request AI, lớn hơn budget tổng Groq mặc định 90 giây. Nếu tăng budget backend cần điều chỉnh client tương ứng. `source` của plan sau swap vẫn giữ nguồn tạo ban đầu theo hợp đồng, không dùng nó để kết luận provider của từng lần đổi.

`ai_workspace/npm run experiment` chạy lại đúng pipeline backend (build backend trước), đọc khóa từ backend_api/.env. Script Gemini cũ chỉ chạy nếu gọi rõ `experiment:gemini:legacy`.

## Kết quả sau chuyển toàn bộ đường gọi AI — 26/10/2026

- Typecheck/build/lint, 384 unit, 85 E2E và smoke bản build đạt. Flutter: 36 tests contract/API client/màn tạo kế hoạch đạt.
- Live tạo kế hoạch: source groq, 14.401ms gồm lần đầu bị validation loại rồi lần sau đạt; 3 ngày × 3 bữa, target1624, tổng1770/1780/1770 trong khoảng contract. Không tuyên bố khớp tuyệt đối target hoặc macro tối ưu.
- Live đổi món: 2032ms; đổi bài: 843ms; feedback cân đối bữa: 2039ms. Mỗi tác vụ một HTTP200 từ Groq, kết quả được chấp nhận và dùng, không phải fallback.
- Lệnh thử ba chức năng: `node --env-file=.env scripts/test-groq-adjustments.mjs`. Dùng hồ sơ tổng hợp; dừng khi bị401/403/429; không in khóa hoặc hồ sơ. Tối đa hai lần cho mỗi chức năng.
- Chu kỳ mới ngày3 và an toàn đã qua E2E giả lập; chưa gọi live riêng cho tất cả nhóm hồ sơ/ngày3 hoặc nghiệm thu UI/device.
