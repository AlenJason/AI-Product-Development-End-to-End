import type { CreatePlanDto } from './dto/create-plan.dto.js';

// Câu cảnh báo trả về trong `warnings` (BRD mục 6.2, NFR-9); app hiển thị nguyên văn.
// Không câu nào được chứa lại chữ người dùng nhập: plan có thể được lưu vào lịch sử (#12).
export const WARNINGS = {
  bmrFloor: (bmr: number) =>
    `Calo mục tiêu đã được nâng lên bằng mức chuyển hoá cơ bản (BMR ${bmr} kcal), vì mức thâm hụt đã chọn sẽ khiến bạn ăn thấp hơn BMR. Không nên ăn thấp hơn mức này nếu không có hướng dẫn của chuyên gia.`,
  healthConditions:
    'Bạn có khai báo tình trạng sức khoẻ: kế hoạch chỉ mang tính tham khảo, không thay thế tư vấn y tế. Hãy hỏi ý kiến bác sĩ trước khi áp dụng.',
  sampleKeywordFiltered:
    'Đang dùng thực đơn mẫu: món ăn và bài tập chỉ được lọc theo các dị ứng, chấn thương phổ biến (ví dụ hải sản, đậu phộng, đau gối); tình trạng sức khoẻ chưa được xét. Hãy tự kiểm tra lại trước khi áp dụng.',
  restrictionsIncomplete:
    'Có dị ứng hoặc chấn thương bạn nhập mà chế độ mẫu chưa nhận ra hoặc chưa lọc được. Hãy tự kiểm tra kỹ các món và bài tập liên quan.',
  historyNotSaved:
    'Chưa lưu được kế hoạch này vào lịch sử do lỗi máy chủ. Kế hoạch vẫn dùng bình thường; muốn lưu thì tạo lại sau.',
  mealsNotRebalanced:
    'Chưa cân đối lại được món ăn ngày kế tiếp theo phản hồi của bạn, nên thực đơn ngày đó giữ nguyên.',
};

// Cảnh báo chỉ phụ thuộc hồ sơ — mọi endpoint trả plan đều tính lại, không lấy `warnings` client gửi lên.
export function profileWarnings(profile: CreatePlanDto, flooredToBmr: boolean, bmr: number): string[] {
  const warnings: string[] = [];
  if (flooredToBmr) warnings.push(WARNINGS.bmrFloor(bmr));
  if (profile.restrictions.health_conditions) warnings.push(WARNINGS.healthConditions);
  return warnings;
}

export function hasRestrictions(profile: CreatePlanDto): boolean {
  const { allergies, injuries, health_conditions } = profile.restrictions;
  return Boolean(allergies || injuries || health_conditions);
}

// safety_warning khi feedback có dấu hiệu nguy hiểm (BRD FR-5.2, #14).
export const SAFETY_WARNING_MESSAGE =
  'Bạn vừa báo chóng mặt, khó thở bất thường hoặc đau ngực. Hãy ngừng tập và hỏi ý kiến bác sĩ trước khi tập lại. Nếu triệu chứng nặng hoặc kéo dài, gọi cấp cứu 115 ngay. Ngày kế tiếp chỉ nên nghỉ ngơi hoặc đi bộ nhẹ.';
