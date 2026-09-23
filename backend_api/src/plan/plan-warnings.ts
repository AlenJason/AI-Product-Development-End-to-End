// Câu cảnh báo trả về trong `warnings` (BRD mục 6.2, NFR-9); app hiển thị nguyên văn.
export const WARNINGS = {
  bmrFloor: (bmr: number) =>
    `Calo mục tiêu đã được nâng lên bằng mức chuyển hoá cơ bản (BMR ${bmr} kcal), vì mức thâm hụt đã chọn sẽ khiến bạn ăn thấp hơn BMR. Không nên ăn thấp hơn mức này nếu không có hướng dẫn của chuyên gia.`,
  healthConditions:
    'Bạn có khai báo tình trạng sức khoẻ: kế hoạch chỉ mang tính tham khảo, không thay thế tư vấn y tế. Hãy hỏi ý kiến bác sĩ trước khi áp dụng.',
  sampleNotFiltered:
    'Đang dùng thực đơn mẫu: thực đơn này chưa được lọc theo dị ứng, chấn thương hay tình trạng sức khoẻ bạn đã nhập. Hãy tự kiểm tra lại từng món và bài tập.',
  historyNotSaved:
    'Chưa lưu được kế hoạch này vào lịch sử do lỗi máy chủ. Kế hoạch vẫn dùng bình thường; muốn lưu thì tạo lại sau.',
};
