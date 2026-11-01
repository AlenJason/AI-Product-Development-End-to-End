# Groq integration — 31/10/2026

Hiện trạng đối chiếu C12 ngày 01/11/2026: Generate/Swap dùng Groq mặc định và fallback có validation; N05 đã có receipt SQLite bền vững và UI/persistence. Xem [N05_FEEDBACK.md](../docs/N05_FEEDBACK.md) và [roadmap](../docs/PLAN.md) cho trạng thái hiện tại. Các mục theo ngày bên dưới là lịch sử từng lượt triển khai; các câu “N05 chưa DONE” hoặc “chưa có khóa bền” không mô tả HEAD hiện tại. Pixel 2 và Groq live sau các thay đổi mới vẫn UNVERIFIED.

## Cập nhật: bài tập AI ngoài kho theo hồ sơ — 31/10/2026

Theo yêu cầu mới, đã bỏ giới hạn chọn tên từ JSON trong cả prompt Generate và Exercise Swap. Các mô tả catalog-only bên dưới là nhật ký phiên bản trước, được thay thế bởi cập nhật này.

- Groq được đề xuất bài thực tế ngoài kho, xét tuổi + activity + thai kỳ/restrictions. Không yêu cầu AI sáng chế động tác hoặc ép mọi bài phải có tên mới. JSON chỉ còn là nguồn metadata bổ trợ cho bài đã biết và kho fallback khi AI thất bại, không phải danh sách tên bắt buộc.
- Bài ngoài kho bắt buộc có assessment nội bộ: difficulty_level1–3, equipment=none, impact, instructions. Kiểm mức trần theo profile_rules hiện có (≥60 tuổi hoặc ≥45 ít vận động/pregnancy → mức1); low-impact khi mức1; số hiệp/lần/thời lượng có trần phần mềm; tags từ nội dung và keyword restrictions; từ chối tải/dụng cụ mâu thuẫn. Đây là kiểm tra ràng buộc phần mềm dựa trên thông tin AI và keywords, không phải xác minh lâm sàng độc lập. Văn bản tự do ngoài keyword rules vẫn có giới hạn như trước.
- Generate giữ bài ngoài kho hợp lệ. Swap vẫn cùng nhóm cơ, không trùng, không thêm tag tải, không tăng số hiệp/workload; cùng mức chỉ được nhận bài ngoài kho nếu giảm số hiệp hoặc workload. Không thêm bài AI vào file JSON. Fallback và422 giữ nguyên.
- Assessment được gỡ trước DTO/response/persistence, cả Generate và Swap: API Flutter không đổi, UI/N04 không sửa. Metadata của bài mới không được lưu thành difficulty contract mới; swap từ bài cũ chưa biết mức dùng giới hạn suy đoán thận trọng hiện có và kiểm giảm workload, không tuyên bố đo chính xác độ khó sinh học.
- Files: thêm src/plan/ai-exercise.ts và ai-exercise.spec.ts; sửa gemini.service.ts (prompt dùng chung Groq), plan.service.ts, adjust/adjust-prompts.ts, adjust/exercise-swap.service.ts, adjust/exercise-swap-validation.ts; cập nhật gemini-prompt.spec.ts và test/groq-adjustments.e2e-spec.ts; docs/PLAN.md và báo cáo này.
- Kiểm thử cuối: **448 unit/33 files;113 E2E/9 files PASS**. Typecheck/lint/build PASS. Có test mock Groq qua HTTP trả bài ngoài JSON cho người65 tuổi, giữ đúng tên trong response; swap ngoài kho thành công; invalid metadata/workload/dụng cụ/impact/restrictions bị loại; metadata không lọt public API. Không sửa Flutter, không chạy lại Flutter suite trong lượt này.
- **LIVE UNVERIFIED:** không gọi Groq thật, không đổi .env, không commit/push. Restart backend rồi tạo plan mới hoặc chủ động đổi bài để thử. Plan cũ N04 đã lưu không tự thay; tên phổ biến vẫn có thể trùng kho vì AI được phép chọn bài đó.
- Roadmap giữ **45/69 DONE (65,22%)**; không nâng task vì chưa có live/device evidence.

## Kết luận và bằng chứng

CODE COMPLETE cho phần chọn provider/backend và handler feedback hiện có. AUTOMATED TEST PASS. **LIVE UNVERIFIED**: không gọi Groq thật, không đọc/in khóa, không sửa `.env`, không commit/push. N05 chưa DONE; chưa nghiệm thu Pixel 2 hoặc khóa feedback bền qua restart.

Quan trọng: trước lượt này `PlanModule` đã có factory cung cấp Groq dưới token `GeminiService` khi `PLAN_AI_PROVIDER=groq`. Vì vậy nhìn tên service/import rồi kết luận swap chưa dùng Groq là sai. Test HTTP hiện có đã bao phủ bốn luồng; lượt này làm rõ DI bằng token `PLAN_AI`, bổ sung kiểm chứng và sửa các khoảng trống validation/provenance/feedback UI.

## Truy vết Before / After

| Chức năng / endpoint | Trước lượt này | Sau lượt này | Validator / fallback | Flutter / coverage |
|---|---|---|---|---|
| Generate `POST /api/v1/generate-plan` → PlanService | Groq trực tiếp; Gemini tùy cấu hình | Giữ Groq mặc định, cùng instance được chọn; Gemini chỉ khi cấu hình rõ | DTO, 3 ngày/3 bữa, calo/macro/BMR, restrictions, cap mức tập; sample-plan khi AI không đạt | GeneratingPlanScreen → PlanProvider.generate; unit + Groq HTTP E2E |
| Meal `POST /api/v1/meals/swap` → MealSwapService | Token Gemini thực tế là Groq trong Groq mode | Inject PLAN_AI rõ ràng; cảnh báo nguồn riêng lần swap | DTO, cùng bữa, ±10%, macro/day target, không trùng, nguyên liệu tránh; pool cũng phải qua cùng checks; hết lựa chọn →422 | SwapActionSheet → swapMeal, server rebuild grocery, checklist N04; unit + failure HTTP E2E |
| Exercise `POST /api/v1/exercises/swap` → ExerciseSwapService | Token alias Groq; AI tự đặt tên chưa xác minh được độ khó vẫn có thể qua | PLAN_AI, tên/metadata đã kiểm chứng, nhẹ hơn, workload không tăng | DTO, cùng nhóm cơ, tags/injury, không trùng, level/profile cap, workload cùng đơn vị; pool phải qua cùng validator, hết lựa chọn →422 | SwapActionSheet → swapExercise; busy/error/retry và persistence sau success; unit + HTTP E2E |
| Feedback `POST /api/v1/feedback` → FeedbackService | Rebalance qua token alias Groq; ngày3 qua PlanService; UI cũ còn mock | PLAN_AI, exact-request dedup, nguồn rebalance, ngày3 Groq fail→422 giữ cycle cũ; UI gọi API | Workout bằng rule engine; under/over mới gọi AI cho bữa ngày sau; danger bypass AI/rest; rebalance lỗi giữ meals; ngày3 bình thường generate mới | DailyFeedbackScreen → submitFeedback thật; cảnh báo server qua dialog; unit + HTTP E2E + widget |

## Provider, timeout và retry

- `PLAN_AI` factory chọn một instance GroqPlanService khi provider không khai báo hoặc bằng `groq`; cấu hình `gemini` mới tạo GeminiService. Token GeminiService là `useExisting: PLAN_AI` để tương thích; không có hai client Groq.
- Groq vẫn dùng endpoint/client/JSON mode hiện có, model cấu hình GROQ_MODEL, per-call/total budget hiện có. Không thêm SDK hoặc sửa API contract.
- Tối đa hai attempts trong tổng budget; lỗi nội dung/5xx có thể retry một lần. HTTP4xx gồm429 và timeout dừng, không retry bão quota. Retry của provider khác với gửi trùng feedback.
- Generate giữ diagnostics/repair cũ. Adjustment log chỉ provider/task/attempt/category/count/status, không error body/prompt/key. Missing key có NOT_CONFIGURED; fallback có NO_VALID_AI_RESULT và lỗi trước đó chỉ rõ category.

## Nguồn kết quả và tính tương thích

Không thêm field/enum response. `plan.source` vẫn là nguồn tạo plan ban đầu, không đại diện cho từng món/bài sau chỉnh sửa. Dùng `warnings` string[] hiện có cho nguồn của **lần điều chỉnh mới nhất**, ví dụ `[AI:exercise-swap:groq]` hoặc `[AI:exercise-swap:fallback]`; lỗi không thay được trả HTTP422. Flutter PlanNotice đang hiển thị warnings, không cần làm lại UI. Gemini mode giữ output/fixtures tương thích cũ.

## Giới hạn safety được nêu rõ

- AI đổi bài phải chọn tên có metadata trong kho đã duyệt. Đây vẫn là Groq chọn phương án theo prompt, không giả nhận JSON fallback là AI. Tên mới chưa có mức khó/dụng cụ không được nhận chỉ vì AI nói hợp lệ.
- Kiểm số lần/thời lượng có định dạng xác minh được và cùng đơn vị; fallback có thể giảm số lần/thời lượng để không tăng so với bài cũ. Không thể so sánh định lượng lần với giây nên từ chối trường hợp đó.
- Contract hiện không có trường dụng cụ riêng; kiểm dựa vào catalog bodyweight hiện có, không thêm field. Text chấn thương/bệnh nền tự do chỉ có keyword rules hiện hữu và cảnh báo phần chưa nhận diện; không khẳng định an toàn y khoa tuyệt đối.
- Khi AI rebalance thất bại, giữ món và ngày hiện tại; rule engine vẫn có thể điều chỉnh workout ngày sau theo feedback. Với ngày3 Groq thất bại, trả422 giữ plan cũ; danger vẫn ưu tiên nghỉ/cảnh báo và không gọi AI.
- Dedup feedback: cùng payload đang chạy dùng chung promise; kết quả thành công cache 5 phút/tối đa100 entries, clone chống mutation. Lỗi không cache nên retry được. Không bền qua restart/nhiều backend instance, không thay khóa theo ngày của N05.

## Files thuộc lượt thay đổi

Backend: `src/plan/{ai-provider,plan.module,plan.service,groq-plan.service,gemini.service,gemini-retry}.ts`; `src/plan/adjust/{adjust-prompts,meal-swap.service,exercise-swap.service,exercise-swap-validation,feedback.service}.ts`; tests `src/plan/adjust/{exercise-swap.service.spec,groq-adjustments.spec}.ts`, `test/{adjust,groq-plan,groq-adjustments}.e2e-spec.ts`.

Flutter: `lib/screens/feedback/daily_feedback_screen.dart`, `lib/routes.dart` (thêm alias /feedback), `test/screens/feedback_api_test.dart`, `test/fake_backend.dart` (HTTP500 thật trong fake transport thay vì đọc fixture không tồn tại).

Docs: tài liệu này và `docs/PLAN.md`. Các file dirty có từ trước được giữ nguyên nội dung ngoài phạm vi cần sửa; Git diff với HEAD không phải danh sách riêng của lượt này.

## Kết quả kiểm thử

- `npm.cmd test -- --reporter=dot`: **429 PASS /32 files**.
- `npm.cmd run test:e2e -- --reporter=dot`: **110 PASS /9 files**.
- `npm.cmd run typecheck`, `npm.cmd run lint`, `npm.cmd run build`: PASS.
- `flutter analyze --no-pub`: No issues found.
- `flutter test --no-pub --reporter expanded`: **162 PASS, 2 SKIP** (live HTTP opt-in).
- `flutter build apk --debug --no-pub`: PASS, app-debug.apk. Java/SDK warnings hiện hữu không chặn build.
- Mock Groq bằng fetch trong unit/E2E; Nest HTTP routing/DI, outgoing URL/body, schema/invalidJSON/restrictions, retry/timeout/429/503, fallback/error, feedback dedup/danger/day3 được kiểm. Không thay thế bằng chứng live.
- Flutter kiểm busy/anti-duplicate, profile của plan dù có draft, error/retry giữ snapshot, persistence sau success, danger_sign/dialog và expired guard. N01–N04 suites pass. Không còn import/use MockDataProvider trong production lib; file định nghĩa cũ còn để bảo toàn, không đăng ký.

## Kiểm thử live có kiểm soát trên Pixel 2 (người dùng chủ động thực hiện)

Chưa có yêu cầu cấp phép chạy live trong lượt này; agent không thực hiện các bước live sau.

1. Backend: kiểm cấu hình riêng tư `PLAN_AI_PROVIDER=groq`, GROQ_API_KEY/GROQ_MODEL; restart bằng `npm.cmd run start:dev` trong backend_api. Không đưa khóa vào Flutter hay log.
2. Frontend: `flutter emulators --launch Pixel_2`, `flutter devices`, rồi `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000` (thay emulator-5554 nếu ID thực tế khác).
3. Chỉ tạo một plan bằng hồ sơ phù hợp; xem nhãn source Groq. HTTP200/source sample chỉ chứng minh fallback, không tính live AI PASS.
4. Đổi một món; đối chiếu backend ai_task_result/provider groq/source groq và warning `[AI:meal-swap:groq]`, món/Grocery trên app. Tích checklist trước; phần nguyên liệu không đổi vẫn giữ tích.
5. Đổi một bài có lựa chọn nhẹ hơn (ví dụ Squat tay không); kiểm ai_task_result/source groq và `[AI:exercise-swap:groq]`. Nếu fallback thì ghi fallback cùng lý do, không tính Groq PASS; nếu bài đã nhẹ nhất thì422 đúng, bài cũ giữ nguyên.
6. Feedback screen handler đã nối API, nhưng entry/navigation đầy đủ theo Figma và khóa ngày vẫn thuộc N05. Khi chưa có entry trên app, kiểm backend bằng Swagger `http://localhost:3000/docs`, POST /api/v1/feedback: dùng profile và **toàn bộ plan server trả**, day_number1 hoặc2, eating under/over, intensity moderate, body_states normal. So sánh chỉ ngày kế tiếp thay đổi và `[AI:feedback-meals:groq]`. eating on_plan/danger không yêu cầu gọi AI. Không tự gửi nhiều lần để ép PASS.
7. Tắt backend rồi thử swap/feedback và mở lại app: lỗi mạng, bản lưu không mất. Đối với Groq timeout/rate-limit/invalid JSON, dùng automated mock tests thay vì cố tình đốt quota live. Ghi từng chức năng LIVE VERIFIED chỉ sau khi có kết quả thực tế.

## Roadmap

Giữ **45/69 DONE (65,22%)**, không tăng task DONE. N04 còn manual Android; N05 vẫn chưa nghiệm thu toàn UI/persistent day lock; N08 live measurement chưa đạt. Không commit/push, không thay .env.
## Debug response cục bộ — 01/11/2026

Theo yêu cầu lưu output để điều tra lỗi: thêm GROQ_DEBUG_RESPONSES=true vào .env local, không đổi key/model. Sau restart, client ghi backend_api/debug/groq-responses.txt khi chạy backend từ thư mục backend_api. File giữ HTTP status/body, content/parsed JSON, trace UUID và validation issues hoặc exception message từ Generate. Không lưu prompt/Authorization; che giá trị GROQ_API_KEY nếu bị response lặp lại. Thư mục debug đã gitignored. Có thể chứa nội dung sức khỏe trong response; tắt flag thành false sau khi điều tra. Tests pin flag false; không tự gọi Groq thật. Log lỗi ghi file không làm request API thất bại. Hiện file mới chỉ có header chờ request thực tế; không tạo output AI giả.

Kiểm chứng: 452 unit +113 E2E PASS; typecheck/lint PASS. Không thay validator hoặc tăng roadmap DONE.

## Sửa validation từ response thực tế — 01/11/2026

Chính sách hiện hành: [GROQ_VALIDATION_FIX.md](GROQ_VALIDATION_FIX.md). Ưu tiên metadata/alias đã xác minh; sửa metadata sai có căn cứ, thay bài không xác minh hoặc vượt profile bằng bài đã kiểm; không tin self-assessment. Sửa false-positive phủ định/plank và phân loại lỗi. 464 unit +115 E2E, typecheck/lint/build PASS; không gọi AI thật/không đổi .env. Các mô tả cũ chấp nhận unknown từ self-assessment ở phần nhật ký trước đã được thay thế.

## Policy hiện hành: AI chọn bài theo hồ sơ, không khóa tên trong kho — 01/11/2026

Theo yêu cầu mới của người dùng, bỏ bộ ba ví dụ cố định và bỏ điều kiện từ chối một bài chỉ vì không tìm được tên/alias trong catalog. Các đoạn catalog-only trong lịch sử phía trên không còn là chính sách hiện hành.

- Prompt gửi trong data block: age, gender, height_cm, weight_kg, activity_level, goal, pregnant_or_breastfeeding và allergies/injuries/health_conditions. Đây là ngữ cảnh người dùng, không phải chỉ dẫn có quyền ghi đè rules. Chỉ biết bệnh nền người dùng đã khai, không tự suy đoán hoặc chẩn đoán.
- Generate và Swap dùng cùng prompt profile-based, bỏ ba tên mẫu và đổi tên workout trong schema example thành placeholder cần thay. Đề nghị phân bố vận động theo khả năng giữa các ngày, không sao chép nguyên ví dụ. Không ép tạo tên lạ nếu một bài phổ biến thực sự phù hợp.
- Bài đã biết vẫn dùng metadata canonical. Bài mới có assessment.movement (position/balance/tempo) và assessment.profile_fit (age/activity/restrictions_considered/reason). Backend kiểm ngữ cảnh đúng request, đối chiếu tên/hướng dẫn, suy bổ sung tags tải, mức tối thiểu từ tư thế/tác động/thăng bằng và kiểm volume/profile cap. Chỉ ghi difficulty_level=1 không còn đủ; tên mới tự nó không còn là lý do loại.
- Đây là kiểm tra ràng buộc phần mềm trên đề xuất AI, không phải xác minh y khoa độc lập hoặc xác nhận rằng mọi bệnh nền đều đã được xử lý đúng. Reason/health context không ra console hoặc public plan. Internal assessment được gỡ trước response/persistence. Giữ disclaimers hiện có.
- Thất bại kiểm tra mới dùng bài dự phòng đã kiểm hoặc lỗi có kiểm soát; không tự ghi bài mới vào JSON. Swap giữ cùng nhóm cơ, không tăng workload/sets/tags; khi metadata bài gốc không được lưu trong public contract, lấy giả định thận trọng về mức gốc, không tự coi bài gốc là khó.
- Files: thêm profile-exercise.ts/spec; sửa ai-exercise.ts/spec, exercise-verification.ts (action assessed), gemini.service.ts (profile data + schema), adjust/adjust-prompts.ts, adjust/exercise-swap-validation.ts, plan-diagnostics.ts, test/groq-adjustments.e2e-spec.ts. Không sửa Flutter/API contract/.env.
- Tests: **474 unit/36 files +117 E2E/9 files PASS**, typecheck/lint/build PASS. Có HTTP E2E kiểm prompt thực sự chứa tuổi/bệnh nền/chấn thương và giữ một bài ngoài kho qua Generate/Swap; sai ngữ cảnh, sai tư thế, thiếu dữ liệu hoặc vượt tải bị từ chối/fallback. Không gọi Groq thật; LIVE sau sửa UNVERIFIED.
- Restart backend rồi tạo plan mới/đổi bài để kiểm; dữ liệu đã lưu N04 không tự đổi. Giữ45/69 DONE (65,22%), không commit/push.
