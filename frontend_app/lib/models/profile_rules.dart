import 'api/codes.dart';
import 'api/profile.dart';

// Giới hạn và luật an toàn giống hệt backend (`backend_api/src/plan/dto/create-plan.dto.ts`,
// `profile-safety.ts`, BRD 6.1 và FR-1.3 v2.6.0). App dùng để báo lỗi ngay khi nhập và khoá lựa chọn;
// backend vẫn kiểm lại và trả 400.
const minAge = 18;
const maxAge = 100;
const minHeightCm = 100;
const maxHeightCm = 250;
const minWeightKg = 30;
const maxWeightKg = 250;
const restrictionMaxLength = 300;
const underweightBmi = 18.5;

const underweightCutMessage =
    'Chỉ số BMI dưới 18,5 (thiếu cân) nên không chọn được Giảm mỡ. Hãy chọn Duy trì vóc dáng hoặc Tăng cơ.';
const pregnantCutMessage =
    'Đang mang thai hoặc cho con bú thì không chọn được Giảm mỡ. Hãy chọn Duy trì vóc dáng và hỏi ý kiến bác sĩ.';

// Số nhập vào ô: chấp nhận cả dấu phẩy thập phân kiểu Việt ("62,5").
num? parseNumber(String text) => num.tryParse(text.trim().replaceAll(',', '.'));

String? ageError(String text) {
  final value = int.tryParse(text.trim());
  if (text.trim().isEmpty) return 'Nhập tuổi';
  if (value == null) return 'Tuổi phải là số nguyên';
  if (value < minAge) return 'SmartFit dành cho người từ $minAge tuổi';
  if (value > maxAge) return 'Tuổi tối đa là $maxAge';
  return null;
}

String? heightError(String text) => _rangeError(text, 'chiều cao', minHeightCm, maxHeightCm, 'cm');

String? weightError(String text) => _rangeError(text, 'cân nặng', minWeightKg, maxWeightKg, 'kg');

String? _rangeError(String text, String label, num min, num max, String unit) {
  if (text.trim().isEmpty) return 'Nhập $label';
  final value = parseNumber(text);
  if (value == null) return '${label[0].toUpperCase()}${label.substring(1)} phải là số';
  if (value < min || value > max) return 'Trong khoảng $min–$max $unit';
  return null;
}

// BMI chưa làm tròn — so với ngưỡng giống backend (làm tròn trước sẽ cho 18,46 lọt thành 18,5).
double bodyMassIndex(num heightCm, num weightKg) {
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

// Lý do không được chọn Giảm mỡ, hoặc null.
String? cutBlockReason({required num heightCm, required num weightKg, required bool pregnantOrBreastfeeding}) {
  if (pregnantOrBreastfeeding) return pregnantCutMessage;
  if (bodyMassIndex(heightCm, weightKg) < underweightBmi) return underweightCutMessage;
  return null;
}

// Hồ sơ đã lưu trên máy có còn hợp lệ theo luật hiện tại không (hồ sơ lưu trước v2.6.0 có thể dưới 18 tuổi).
List<String> profileProblems(Profile profile) => [
  ?ageError('${profile.age}'),
  ?heightError('${profile.heightCm}'),
  ?weightError('${profile.weightKg}'),
  if (profile.pregnantOrBreastfeeding && profile.gender != Gender.female) 'Chỉ nữ mới khai báo mang thai / cho con bú',
  if (profile.goal == Goal.cut)
    ?cutBlockReason(
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      pregnantOrBreastfeeding: profile.pregnantOrBreastfeeding,
    ),
  for (final text in [
    profile.restrictions.allergies,
    profile.restrictions.injuries,
    profile.restrictions.healthConditions,
  ])
    if (text.length > restrictionMaxLength) 'Mỗi mục hạn chế tối đa $restrictionMaxLength ký tự',
];
