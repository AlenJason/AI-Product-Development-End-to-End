# Cấu trúc Knowledge Base

Roadmap chính thức duy nhất: [docs/PLAN.md](../PLAN.md). Đọc trạng thái thực tế và acceptance criteria ở đó trước khi dùng wiki hoặc spec lịch sử để tiếp tục code.

## Đây là gì

Knowledge base cho **SmartFit AI** — đồ án VKU: ứng dụng Flutter + NestJS lên kế hoạch ăn uống món Việt và tập luyện tại nhà theo chu kỳ 3 ngày cuốn chiếu. AI runtime mặc định là Groq; Gemini giữ làm lựa chọn tương thích. Các bài wiki theo ngày có thể mô tả kiến trúc lịch sử.

## Cách tổ chức

- `raw/` — nguồn thô chưa xử lý: tài liệu API, ghi chú nghiên cứu, transcript. Không sửa tay.
- `wiki/` — wiki đã được tổ chức, do AI duy trì. Không sửa tay.
- `outputs/` — câu trả lời, báo cáo, phân tích do AI tạo ra.

## Quy tắc viết wiki

- Mỗi chủ đề có một file `.md` riêng trong `wiki/`
- Mỗi bài wiki bắt đầu bằng một đoạn tóm tắt
- Liên kết chủ đề liên quan bằng cú pháp `[[tên-chủ-đề]]`
- Duy trì `INDEX.md` liệt kê mọi chủ đề kèm mô tả một dòng
- Khi có nguồn dữ liệu thô mới, cập nhật lại các bài wiki liên quan

## Các mảng trọng tâm

1. Thiết kế API NestJS trong `backend_api/` — validate DTO, tính BMR/TDEE, hợp đồng endpoint
2. Tích hợp Gemini structured output — thiết kế prompt, tuân thủ JSON schema, kiểm tra hợp lý dữ liệu dinh dưỡng
3. Giao diện Flutter trong `frontend_app/` — screens/widgets và tầng kết nối API (có từ giai đoạn 5, xem [[flutter-ui]])
4. Kỷ luật phạm vi sản phẩm — BRD.md là nguồn spec đã được duyệt; thay đổi tính năng cần đối chiếu lại, không tự ý lệch khỏi tài liệu
5. Xác thực Google Sign-In + lịch sử kế hoạch qua SQLite/TypeORM (BRD FR-6, FR-7) — có code từ giai đoạn 3, xem [[auth-and-history]]
6. Đổi món, đổi bài tập, feedback cuối ngày (BRD FR-4, FR-5) — có code từ giai đoạn 4, xem [[swap-and-feedback]]
