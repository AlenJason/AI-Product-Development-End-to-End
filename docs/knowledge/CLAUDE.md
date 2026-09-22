# Cấu trúc Knowledge Base

## Đây là gì

Knowledge base cho **SmartFit AI** — đồ án VKU: ứng dụng Flutter + NestJS + Gemini lên kế hoạch ăn uống món Việt và tập luyện tại nhà theo chu kỳ 3 ngày cuốn chiếu.

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
3. Giao diện Flutter trong `frontend_app/` — screens/widgets và (khi làm tới) kết nối API
4. Kỷ luật phạm vi sản phẩm — BRD.md là nguồn spec đã được duyệt; thay đổi tính năng cần đối chiếu lại, không tự ý lệch khỏi tài liệu
5. Xác thực Google Sign-In + lưu lịch sử kế hoạch qua SQLite/TypeORM (BRD v2.2.0, FR-6/FR-7) — quyết định kiến trúc đã chốt, chưa có code
