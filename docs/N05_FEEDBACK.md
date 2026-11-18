# N05 — Daily Feedback & Adaptive Plan

Ngày kiểm tra: 01/11/2026. N05 **CODE COMPLETE / AUTOMATED TEST PASS**. Nghiệm thu Pixel 2 và Groq live sau thay đổi: **UNVERIFIED**. N04/N06 vẫn giữ cổng Android riêng.

## Luồng và contract

Dashboard hoặc màn Kế hoạch → Feedback (ba câu D2) → `PlanProvider` → `POST /api/v1/feedback` → `FeedbackService` → rules/`PLAN_AI` → validation → SQLite receipt → response → snapshot local → Dashboard/Calendar.

Giữ endpoint và JSON hiện có: `profile`, `plan`, `day_number` **1–3**, `intensity` (`easy/moderate/hard`), `body_states` (`normal/sore/joint_pain/fatigued/danger_sign`), `eating` (`on_plan/over/under`). Response vẫn `{plan, safety_warning}`. Không thêm ghi chú hoặc câu hỏi ngoài DTO. DTO chỉ lưu mã `danger_sign`, vì vậy màn xem lại dùng nhãn chung “Dấu hiệu bất thường”, không suy diễn người dùng từng báo đau ngực.

UI có loading, khóa thao tác khi gửi, lỗi, retry, đã gửi, xem lại và cảnh báo sức khỏe. Thông báo thành công căn cứ ngày thực sự thay đổi; không mặc định nói AI đã cân đối món. Màn hình giữ theme, Manrope, gradient/card; có kiểm thử cỡ Pixel 2 và text scale 2. Đây là widget test trên host, chưa phải chạy emulator.

## Idempotency bền vững

- Migration `1793498400000-feedback-receipts` bổ sung bảng SQLite, khóa chính kép `(plan_id, day_number)`. Database hiện có được migrate tự động khi startup; không dùng synchronize và không thay database người dùng trong tests.
- SHA-256 của request chuẩn hóa bao gồm hồ sơ, kế hoạch gốc và câu trả lời; thứ tự key và thứ tự body states không tạo yêu cầu khác. Receipt gắn tài khoản hoặc guest. Không ghi hồ sơ vào log hoặc receipt; receipt chứa hash và kết quả kế hoạch cần replay.
- Claim bằng `INSERT OR IGNORE`. Cùng process/cùng body chờ chung promise; process khác trả 409 khi đang xử lý. Body khác hoặc owner khác cùng khóa trả 409. Plan đã lưu thuộc tài khoản khác bị chặn 403 trước khi claim.
- Kết quả chỉ được trả sau khi lưu receipt `completed`. Retry đọc lại kết quả, không chạy điều chỉnh hoặc tạo chu kỳ lần nữa. Đóng/mở SQLite và tạo service mới vẫn replay được.
- Lease 10 phút và token fencing cho phép phục hồi request bị bỏ dở. Worker cũ không thể ghi đè worker mới sau khi mất lease. Không giữ transaction database xuyên suốt cuộc gọi AI.
- Giới hạn: bảo đảm một **kết quả được commit** cho mỗi khóa; không thể bảo đảm AI chỉ được gọi đúng một lần nếu process chết trước lúc commit. Các instance phải dùng cùng file SQLite; đây không phải cơ chế đồng bộ nhiều máy với các file DB riêng biệt.
- Retry ngày 1/2 không ghi lại lịch sử server để tránh ghi đè feedback ngày sau hoặc swap mới hơn. Insert lịch sử chu kỳ mới có thể replay mà không ghi đè bản đã tồn tại. Lịch sử tài khoản vẫn dùng cơ chế warning hiện có nếu ghi thất bại; receipt là nơi xác nhận xử lý N05.

## Persistence và lỗi mạng

Snapshot `smartfit.plan_state.v2` giữ schema version 2, thêm các trường tùy chọn: `feedback_pending`, `feedback_receipts`, `next_cycle`, `history`. Dữ liệu N04 thiếu các trường này vẫn đọc được. Không tạo provider trùng lặp.

Trước HTTP, app lưu request gốc vào `feedback_pending`; đây **không phải trạng thái đã gửi thành công**. Chỉ sau response hợp lệ và ghi snapshot thành công mới công bố kế hoạch/receipt. Mất mạng, timeout, 5xx hoặc lỗi ghi cuối cùng giữ kế hoạch cũ và request chờ. Restart → retry đúng request gốc. Trong lúc chờ, không cho swap/generate làm thay đổi request đó; vẫn lưu được profile draft. Lỗi 400/422 chắc chắn bị từ chối giải phóng pending để sửa và thử lại; 409 giữ pending vì có thể là request đang được xử lý.

Checklist vẫn lưu theo plan/category/name/quantity; giữ dấu tích của dòng không đổi, bỏ dấu tích khi quantity đổi. Khi chuyển chu kỳ, dữ liệu checklist cũ được đưa vào `history` của `smartfit.grocery.v1`; chu kỳ mới có checklist riêng. Nếu app đóng ngay giữa hai lần lưu plan/grocery, lần restore đọc plan_id và phục hồi đúng dữ liệu theo chu kỳ, không gán dấu tích cũ cho plan mới.

Không có mock production. Offline vẫn xem bản lưu, receipts và lịch sử; thao tác API báo lỗi và không sinh dữ liệu thay thế ở Flutter. Xóa dữ liệu ứng dụng sẽ xóa các bản lưu local; multi-device sync thuộc phạm vi N07.

## Ngày 1, 2, 3

| Phản hồi | Kết quả |
|---|---|
| Ngày 1 | Chỉ thay ngày 2; giữ ngày 1 và 3, plan_id và ngày bắt đầu |
| Ngày 2 | Chỉ thay ngày 3; giữ ngày 1 và 2 |
| Ngày 3 | Tạo plan_id mới, lưu chu kỳ chờ bắt đầu ngày lịch sau ngày 3; giữ chu kỳ cũ đang hiển thị |

Flutter từ chối response ngày 1/2 nếu backend thay ngày ngoài phạm vi. Chu kỳ mới chỉ được kích hoạt bằng commit local khi đến ngày bắt đầu, tại startup/resume/midnight. Không gọi AI khi mở app. Nếu ghi chuyển chu kỳ thất bại, giữ cả plan cũ và chu kỳ chờ, có nút thử lại. Thời gian dùng ngày lịch/timezone thiết bị theo `PlanSchedule` N04, không dùng số giờ đã trôi qua.

Lịch sử chu kỳ trong màn Kế hoạch là chỉ xem, có thể chọn từng ngày và xem feedback đã lưu. Profile draft không bị áp dụng ngầm vào chu kỳ mới. Không tự nhảy ngày khi người dùng xem Calendar.

## Safety và fallback

- Workout chủ yếu do rules hiện có điều chỉnh: hard/fatigued giảm tải; sore giảm nhóm cơ đã tập; joint pain loại tải liên quan; chỉ easy + normal mới có thể tăng trong giới hạn đã kiểm tra.
- `safeFeedbackWorkout` đối chiếu metadata đã kiểm chứng, giới hạn sets/workload và kiểm restrictions. Public plan không mang assessment của provider; bài không thể xác minh lại ở ranh giới feedback được thay bằng bài đã kiểm chứng mức nhẹ phù hợp, hoặc prescription nghỉ/đi bộ đã duyệt. Không tin metadata do client/AI tự khai. Generate/Swap vẫn giữ policy cho AI đề xuất bài ngoài kho như trước.
- Schema response, calo/macros và restrictions được kiểm trước khi lưu. Không nới validation để PASS.
- Under/over gọi chung `PLAN_AI` cho món ngày sau; kết quả sai JSON, vi phạm dị ứng hoặc provider lỗi → giữ món hợp lệ cũ và trả warnings. Workout rules vẫn có thể thay đổi; UI không nói Groq đã cân đối thành công khi chỉ có fallback.
- Danger signs bỏ qua AI cho phần phản hồi, dùng prescription nghỉ/đi bộ nhẹ và warning hiện có, không chẩn đoán. Ngày 3 danger dùng đường sample an toàn hiện có và kiểm restrictions. Ngày 3 Groq không tạo được chu kỳ hợp lệ → 422, không thay plan cũ.

## Bằng chứng kiểm thử

| Kiểm tra | Kết quả cuối |
|---|---|
| Backend unit | **507 PASS / 0 FAIL**, 39 files; snapshot source HEAD C11, đối chiếu C12 ngày 01/11/2026 |
| Backend E2E toàn suite | **119 PASS / 0 FAIL / 1 SKIP**; bridge opt-in SKIP trong suite, kết quả chạy riêng bên dưới là lịch sử |
| Backend typecheck / lint / build | **PASS** |
| Flutter toàn suite | **183 PASS / 0 FAIL / 3 SKIP**: 2 test HTTP N01 opt-in, 1 test HTTP N05 opt-in; snapshot source HEAD C11, đối chiếu C12 ngày 01/11/2026 |
| N05 Flutter → Nest HTTP local chạy riêng | **Lịch sử: 1 PASS / 0 FAIL / 0 SKIP**; chưa chạy lại trong C12 |
| Nest bridge AI giả lập chạy riêng | **Lịch sử: 1 PASS / 0 FAIL / 0 SKIP**; chưa chạy lại trong C12 |
| Flutter analyze | **No issues found** |
| Flutter build apk --debug --no-pub | **Lịch sử: PASS**, `frontend_app/build/app/outputs/flutter-apk/app-debug.apk`; chưa build lại trong C12 |
| Pixel 2 runtime, Groq live sau sửa | **UNVERIFIED** |

Kết quả lịch sử trước các regression mới là 485 unit /38 files và Flutter 171 PASS /3 SKIP. Các số hiện tại ở bảng trên không thay thế bằng chứng lịch sử APK/bridge bằng một lần nghiệm thu mới. Kiểm thử tổng thể sẽ chạy lại trên HEAD sau commit C12.

Backend tests dùng migrated SQLite thật ở RAM/temp file và provider giả lập. Bao gồm concurrent/day3, request conflict, restart DB, lease recovery, lỗi claim/result persistence, danger, schema, provider timeout/JSON/restrictions, fallback và replay không ghi đè history. Flutter tests kiểm form/entry/disabled/double tap, retry, restore, lỗi ghi trước/sau HTTP, calendar, queue/activation failure, draft/checklist, bảo toàn các ngày khác và các luồng N01–N04.

HTTP integration riêng chạy Generate → Meal Swap (AI giả lập không hợp lệ nên dùng pool hợp lệ) → Grocery → feedback 1/2/3 → restart → ngày tiếp theo. Bridge dùng Nest thật + SQLite cô lập, không key thật. Lần thử bridge đầu có lỗi cấu hình/source và hết thời gian chờ; đã sửa bridge, chạy lại đạt PASS như trên. Không dùng kết quả các lần thất bại làm bằng chứng PASS. Build có warning SDK XML/native-access từ toolchain nhưng exit 0 và có APK.

Chạy lại tự động:

```powershell
cd D:\AI-Product-Development-End-to-End\backend_api
npm.cmd run typecheck
npm.cmd run lint
npm.cmd run build
npm.cmd test
npm.cmd run test:e2e

cd D:\AI-Product-Development-End-to-End\frontend_app
flutter analyze
flutter test
flutter build apk --debug
```

HTTP integration cô lập, hai terminal:

```powershell
# Terminal 1: bridge tự đóng sau khi 3 receipt được commit.
cd D:\AI-Product-Development-End-to-End\backend_api
$env:N05_BRIDGE='1'
npm.cmd run test:e2e -- test/n05-bridge.e2e-spec.ts --reporter=verbose
Remove-Item Env:N05_BRIDGE

# Terminal 2: chỉ trỏ vào bridge test, không trỏ production.
cd D:\AI-Product-Development-End-to-End\frontend_app
flutter test --no-pub --dart-define=N05_BACKEND_URL=http://127.0.0.1:3998 test/services/n05_backend_local_test.dart
```

## Nghiệm thu Pixel 2

Việc tạo plan mới trong bước thủ công có thể gọi Groq theo `.env` của người chạy. Assistant chưa thực hiện phần này.

1. Chạy backend: `cd D:\AI-Product-Development-End-to-End\backend_api`, `npm.cmd run start:dev`. Sao lưu DB/dev data nếu cần giữ dữ liệu kiểm thử hiện có.
2. Mở emulator và lấy ID thật:

```powershell
cd D:\AI-Product-Development-End-to-End\frontend_app
flutter emulators --launch Pixel_2
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Thay `emulator-5554` bằng ID liệt kê thực tế, không gõ dấu `< >` trong PowerShell.

3. Generate → đổi món/bài → tích Grocery → lưu profile draft. Từ Dashboard mở “Hoàn thành ngày & phản hồi”; chọn hard/normal/on_plan và gửi. Trong lúc gửi thử nhấn lặp: chỉ một kết quả.
4. Xác nhận ngày 1 giữ nguyên, chỉ ngày 2 đổi; Calendar vẫn là ngày 1. Mở lại app: “Đã gửi phản hồi”, không còn nút gửi lần nữa; draft/checklist còn.
5. Dùng dữ liệu/emulator thử nghiệm có ngày hệ thống tương ứng ngày 2, rồi ngày 3; tắt tự động ngày/giờ của emulator nếu đổi ngày bằng Settings. Không đổi đồng hồ máy dev. Mỗi lần đưa app về nền rồi mở lại để kích hoạt lifecycle.
6. Ngày 2 gửi, xác nhận chỉ ngày 3 đổi. Ngày 3 gửi, xác nhận plan cũ còn hiển thị và có ngày bắt đầu chu kỳ mới là ngày mai. Tắt/mở app trước ngày bắt đầu vẫn giữ chu kỳ cũ. Sang ngày bắt đầu → chu kỳ mới/ngày 1; lịch sử chu kỳ trước và feedback còn.
7. Tắt mạng hoặc dừng backend trước gửi: không success, plan/checklist không mất. Bật lại rồi retry; thử đóng/mở app trước retry. Dùng proxy/test bridge nếu cần mô phỏng “backend xử lý xong nhưng response bị mất”; không dùng thao tác xóa app data để kiểm restart.
8. Với plan/cycle thử nghiệm khác, chọn dấu hiệu bất thường: xem warning/rest, không tăng cường độ và không gọi AI cho danger path. Kiểm cỡ chữ lớn, nút Back, navigation và xem lịch sử chỉ đọc.

Ghi video/screenshot, log request count và kết quả từng bước trước khi nghiệm thu N04/N06 hoặc gắn nhãn LIVE VERIFIED.

## File thuộc thay đổi N05

Backend (đường dẫn dưới `backend_api/`):

- `src/database/data-source-options.ts`, `src/database/migrations.spec.ts`
- `src/database/entities/feedback-receipt.entity.ts` (mới), `src/database/migrations/1793498400000-feedback-receipts.ts` (mới)
- `src/plan/adjust/feedback.service.ts`, `src/plan/adjust/plan-adjust.controller.ts`, `src/history/history.service.ts`
- `src/plan/adjust/feedback-workout.ts`, `feedback-workout.spec.ts`, `feedback-persistence.spec.ts` (mới)
- `test/adjust.e2e-spec.ts`, `test/groq-plan.e2e-spec.ts`, `test/n05-feedback.e2e-spec.ts`, `test/n05-bridge.e2e-spec.ts` (hai file cuối mới)

Flutter (đường dẫn dưới `frontend_app/`):

- `lib/models/api/account.dart`, `lib/models/feedback_state.dart` (mới)
- `lib/providers/plan_provider.dart`, `lib/providers/grocery_provider.dart`, `lib/routes.dart`
- `lib/screens/feedback/daily_feedback_screen.dart`, `lib/screens/plan/plan_screen.dart`, `lib/widgets/plan_status.dart`
- `test/fake_backend.dart`, `test/providers/plan_provider_test.dart`, `test/providers/grocery_provider_test.dart`
- `test/providers/n05_feedback_test.dart`, `test/services/n05_backend_local_test.dart` (mới)
- `test/screens/feedback_api_test.dart`, `test/screens/n03_integration_test.dart`

Tài liệu: `docs/PLAN.md`, `docs/N05_FEEDBACK.md` (mới). Đây là file list của N05; Git còn nhiều thay đổi có sẵn từ các lượt trước. Không commit/push, không sửa `.env`, không gọi Groq live.
