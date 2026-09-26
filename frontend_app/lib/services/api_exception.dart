// Lỗi khi gọi backend_api. `message` là câu tiếng Việt hiện thẳng cho người dùng — không bao giờ chứa
// body request/response hay dữ liệu hồ sơ.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

// Không tới được máy chủ: mất mạng, sai địa chỉ, backend chưa chạy, CORS chặn (web).
class NetworkException extends ApiException {
  const NetworkException() : super('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.');
}

class ApiTimeoutException extends ApiException {
  const ApiTimeoutException() : super('Máy chủ phản hồi quá lâu. Vui lòng thử lại sau ít phút.');
}

// 400. `details` là câu của class-validator (tiếng Anh, chỉ tên trường, không có giá trị) — để debug, không hiện
// cho người dùng.
class ValidationException extends ApiException {
  const ValidationException(this.details) : super('Thông tin gửi lên chưa hợp lệ. Vui lòng kiểm tra lại hồ sơ.');

  final List<String> details;
}

// 401: phiên đăng nhập hết hạn/tài khoản đã xoá, hoặc id_token không hợp lệ khi đăng nhập.
class UnauthorizedException extends ApiException {
  const UnauthorizedException() : super('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
}

class NotFoundException extends ApiException {
  const NotFoundException() : super('Không tìm thấy kế hoạch này.');
}

// 409: plan được tạo cho hồ sơ khác (mục tiêu calo đã đổi) — cần tạo plan mới (BRD 6.4).
class PlanOutdatedException extends ApiException {
  const PlanOutdatedException([super.message = 'Kế hoạch này không còn khớp với hồ sơ. Hãy tạo kế hoạch mới.']);
}

// 422: không tìm được món/động tác thay thế phù hợp (BRD 6.4).
class NoReplacementException extends ApiException {
  const NoReplacementException([super.message = 'Chưa tìm được lựa chọn thay thế phù hợp.']);
}

// 5xx, mã lạ, hoặc body không đúng hợp đồng.
class ServerException extends ApiException {
  const ServerException([this.statusCode]) : super('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.');

  final int? statusCode;
}
