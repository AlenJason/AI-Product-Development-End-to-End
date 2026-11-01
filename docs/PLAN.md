# SmartFit AI — Roadmap chính thức

## N05 — Daily Feedback & Adaptive Plan — 01/11/2026

**Task 7.3 DONE theo acceptance UI/API/persistence/idempotency/lifecycle tự động; Pixel 2 và Groq live vẫn UNVERIFIED.** N04/N06 không nâng trạng thái Android. Tiến độ hiện tại **46/69 DONE = 66,67%**; các số 45/69 trong nhật ký bên dưới là bằng chứng trước N05.

- Dashboard/Calendar có entry feedback ba câu D2, loading/error/retry/đã gửi/xem lại/safety warning; success dựa trên thay đổi thực tế. Không dùng mock production hoặc provider trùng lặp.
- SQLite migration lưu receipt `(plan_id, day_number)` 1–3, request hash/owner/lease/fencing/result; retry, concurrent, restart không áp dụng thêm. Flutter lưu request chờ và receipt trong snapshot N04, chỉ công bố sau ghi thành công.
- Ngày 1→chỉ ngày 2, ngày 2→chỉ ngày 3; ngày 3 chuẩn bị chu kỳ ngày mai, giữ plan cũ đến ngày bắt đầu; giữ lịch sử, draft và checklist theo chu kỳ. Danger ưu tiên rules; kiểm schema/restrictions/metadata/workload, giữ plan cũ khi thất bại.
- **Đối chiếu C12 ngày 01/11/2026 trên snapshot source HEAD C11:** 507 unit PASS /39 files; Flutter 183 PASS /3 SKIP. Backend E2E gần nhất: 119 PASS /1 bridge opt-in SKIP; typecheck/lint/build và Flutter analyze PASS trong các snapshot commit đã kiểm tra. SKIP không được tính là PASS. Kiểm thử tổng thể sẽ chạy lại trên HEAD sau commit C12.
- **Bằng chứng lịch sử N05:** 485 unit /38 files, Flutter 171 PASS /3 SKIP, APK debug PASS. Bridge Nest và Flutter HTTP N05 từng được ghi nhận chạy riêng, mỗi bên 1 PASS: Generate→Swap→Grocery→feedback 1/2/3→restart→chu kỳ mới, dùng AI giả lập/SQLite cô lập. C12 chưa chạy lại APK hoặc bridge; Pixel 2 và Groq live vẫn UNVERIFIED.
- Không sửa `.env`, không gọi Groq live, không commit/push; bảo toàn thay đổi có sẵn. [Kiến trúc, file list, giới hạn và nghiệm thu Pixel 2](N05_FEEDBACK.md).

## AI chọn bài theo hồ sơ, gỡ khóa catalog — 01/11/2026

Yêu cầu mới: lấy tuổi/thể trạng/vận động/bệnh nền/chấn thương làm ngữ cảnh chọn bài, không chỉ tham khảo vài tên mẫu. Đã bỏ bộ ba anchor và điều kiện bắt buộc tên có trong kho; bài mới được đánh giá qua movement + profile_fit, kiểm tải/vị trí/ngữ cảnh và giới hạn N02. Bài đã biết vẫn ưu tiên metadata canonical, JSON chỉ là fallback khi proposal không đạt. Metadata do AI khai không phải chứng nhận y khoa độc lập; không hứa xử lý đúng mọi bệnh nền từ text tự do.

**474 unit +117 E2E PASS; typecheck/lint/build PASS.** E2E xác nhận hồ sơ/bệnh nền thực sự có trong prompt và bài ngoài kho được giữ qua Generate/Swap. Không gọi Groq thật, không sửa .env/Flutter/public contract/persistence, không commit/push. LIVE vẫn UNVERIFIED; **45/69 DONE (65,22%)** giữ nguyên. [Policy và file list mới nhất](../backend_api/GROQ_INTEGRATION.md) thay phần catalog-only của lượt trước.

## Sửa Generate validation từ response Groq HTTP200 — 01/11/2026

Root cause xác nhận: AI_EXERCISE_LOAD_CONFLICT bị gom nhầm thành TRANSPORT_OR_INTERNAL_ERROR; regex plank suy wrist_load quá rộng, không hiểu “không nhảy”, AI còn khai sai tags/tư thế/level. Đã thêm xác minh canonical/exact aliases từ dữ liệu hiện có, metadata repair có căn cứ và fallback từng bài trước final validation; không tự tin assessment AI. Warnings phân biệt có bài thay bằng dữ liệu dự phòng; giữ món AI và API/UI/persistence.

- Regression fixture2responses đã loại meals/profile/IDs/reasoning; unit + HTTP E2E kiểm cả2 responses, metadata/workload/unknown/age/restrictions, logs chỉ metadata đã lọc và production tắt raw response debug.
- **464 unit /35 files +115 E2E /9 files PASS;typecheck/lint/build PASS.** Không gọi Groq thật, không sửa .env hoặc Flutter; không commit/push. LIVE sau sửa vẫn UNVERIFIED. **45/69 DONE (65,22%)** giữ nguyên.
- [Báo cáo root cause, audit từng ngày/bài, policy và live checklist](../backend_api/GROQ_VALIDATION_FIX.md). Nhật ký self-assessment ngoài kho trước đó được thay thế: bài chưa xác minh phải từ chối/thay theo yêu cầu mới, không giảm safety để PASS.

## Mở rộng bài tập AI ngoài kho theo hồ sơ — 31/10/2026

**CODE COMPLETE / AUTOMATED PASS / LIVE UNVERIFIED.** Yêu cầu mới thay chính sách catalog-only của lượt trước: bỏ danh sách tên bắt buộc trong Generate/Swap; bài ngoài JSON có assessment nội bộ và qua checks tuổi/activity/pregnancy, mức khó, tác động, dụng cụ, tags/restrictions và workload mới được dùng. Giữ fallback JSON khi AI không hợp lệ; không tự ghi bài AI vào kho; không đổi response/UI/persistence N04. Tuổi không phải yếu tố duy nhất. Đây là kiểm tra ràng buộc phần mềm, không khẳng định y khoa hoặc metadata AI được xác minh độc lập.

- **Tests:** 448 unit/33 files +113 E2E/9 files PASS; typecheck/lint/build PASS. Test HTTP mock Groq chứng minh Generate và Swap giữ bài ngoài kho; assessment không ra API, người65 tuổi/ít vận động/pregnancy không vượt mức nhẹ, sai metadata/thiết bị/tải bị từ chối. Flutter không sửa/không chạy lại trong lượt này.
- **Files/evidence:** [báo cáo cập nhật](../backend_api/GROQ_INTEGRATION.md), ai-exercise.ts/spec, Generate/shared prompts, exercise swap validator/service và HTTP E2E tests.
- **Live:** chưa gọi Groq thật hoặc thao tác thiết bị; restart backend + tạo plan mới/đổi bài mới thấy policy mới. Bản lưu cũ không tự đổi. Không sửa .env, không commit/push; giữ thay đổi chưa commit. **45/69 DONE (65,22%)** giữ nguyên, N04/N05/N08 không tự nâng trạng thái.

## Hoàn thiện Groq cho Generate / Swap / Feedback — 31/10/2026

**CODE COMPLETE trong scope backend + handler feedback hiện có; AUTOMATED TEST PASS; LIVE UNVERIFIED.** Không gọi Groq thật hoặc sửa .env. Giữ **45/69 DONE (65,22%)**, không tự nâng N05/N08. N04 manual Android và khóa feedback bền theo ngày vẫn còn.

- **Đính chính truy vết:** PlanModule trước lượt này đã ánh xạ GeminiService → Groq khi PLAN_AI_PROVIDER=groq; tên/import Gemini không chứng minh đang gọi Google. Thay bằng token PLAN_AI rõ ràng dùng chung instance cho Generate/MealSwap/ExerciseSwap/Feedback; GeminiService còn alias tương thích và chỉ dùng Gemini thật khi cấu hình explicit gemini.
- **Safety:** đổi bài kiểm metadata catalog bodyweight, level nhẹ hơn/profile cap, tags/injury, số hiệp và workload không tăng; unknown difficulty/equipment bị từ chối. AI/fallback dùng cùng validator;422 khi không có lựa chọn. Meal giữ checks dị ứng/calo/macro/day/grocery. Không nới validator hoặc thêm field API.
- **Nguồn:** giữ source nguồn tạo plan, dùng warnings hiện có phân biệt nguồn lần adjustment; diagnostics Groq không echo key/prompt/provider body. Timeout/429 không retry, sai nội dung/5xx tối đa hai attempts trong budget.
- **Feedback:** under/over dùng Groq cho meals ngày sau; workout theo rule engine; danger bypass AI/rest. Groq day3 fail→422 giữ cycle cũ. Dedup cùng payload trong process (5 phút/100 results), không thay persistent lock N05. Màn feedback cũ bỏ MockDataProvider, gọi PlanProvider/API thật, busy/error/retry/safety dialog; không mở rộng navigation/UI N05.
- **Bằng chứng:** backend 429 unit/32 files +110 E2E/9 files PASS; typecheck/lint/build PASS. Flutter analyze sạch;162 PASS,2 SKIP;APK debug PASS. Groq trong tests là mock fetch, không phải live. N01–N04 regression PASS. Android runtime/live provider vẫn UNVERIFIED.
- **Chi tiết:** [Groq integration report](../backend_api/GROQ_INTEGRATION.md) có Before/After từng endpoint, validator/fallback, file list, giới hạn catalog/restrictions/dedup và hướng dẫn Pixel2/Swagger. Không commit/push; bảo toàn thay đổi chưa commit từ trước.

## N04 — Startup, Persistence và Daily Plan Lifecycle — 31/10/2026

**PARTIAL ở mức work package:** implementation và automated acceptance đạt; Android runtime/offline/restart trên Pixel 2 và real-backend smoke **UNVERIFIED**. Không lấy APK build làm bằng chứng chạy thiết bị. Task 5.6, 6.2, 6.11 đạt criteria hiện hành → DONE; 5.10 BUGGY → PARTIAL (thiếu device/release gates); 6.5 giữ DONE. Tiến độ hiện tại **45/69 DONE = 65,22%**. Các số ở nhật ký cũ bên dưới là bằng chứng lịch sử.

- **Startup:** SmartFitBootstrap hiển thị loading khi đọc preferences, khôi phục xong mới dựng providers và chọn Dashboard nếu có plan hợp lệ, Welcome nếu chưa có. Lỗi đọc bộ nhớ có Retry. Không HTTP/Groq/generate khi mở hoặc resume.
- **Persistence:** snapshot `smartfit.plan_state.v2` gồm version/profile/plan/schedule/draft; chỉ công bố state sau khi ghi thành công. Đọc và migrate v1 hoàn toàn hợp lệ, neo ngày bắt đầu cho legacy chưa có lịch; giữ mirrors tương thích. Swap giữ lịch và draft. Bản lưu hỏng/sai kiểu/khác version được giữ nguyên và cảnh báo; draft hỏng không che plan hợp lệ. Restore lỗi không tự xóa/ghi đè bản gốc. Checklist bought/have lưu theo plan và khóa gồm lượng, ghi tuần tự, giữ phần không đổi sau swap.
- **Profile:** hiển thị dữ liệu thật; editor điền mọi field và D5 từ hồ sơ/draft, tái dùng OnboardingProvider/profile_rules/restriction fields N02. “Chỉ lưu” lưu draft, không API; “Lưu & tạo lại” lưu draft rồi qua GeneratingPlanScreen/API thật. Thất bại giữ plan/profile cũ và draft; thành công mới thay plan, bắt đầu hôm nay và bỏ draft. Swap/feedback dùng profile của plan cũ đến lúc thay thành công.
- **Calendar/offline:** ngày theo calendar/timezone thiết bị, cập nhật ở midnight/resume, chọn ngày 1/2/3 có ngày lịch. Trước ngày bắt đầu có preview notice; sau ngày 3 có expiry notice và CTA tạo mới chủ động, vẫn xem bản lưu. Không tự tạo chu kỳ N05. Xem plan/checklist không cần mạng; lỗi API không sinh mock hoặc làm mất bản lưu.
- **UI/regression:** giữ AppTheme/Manrope/colors/layout 430px/navigation và các component Figma; profile/editor dùng cùng UI kit. Gỡ đăng ký MockDataProvider ở root. Không sửa backend, Groq, API contract, .env; không commit/push. N01/N02/N03 automated suites pass, gồm safety, request IDs, retry và swaps/grocery.
- **Kiểm thử:** `flutter analyze --no-pub`: No issues found; `flutter test --no-pub --reporter expanded`: **158 PASS, 2 SKIP, 0 FAIL** (hai live HTTP opt-in không chạy backend); `flutter build apk --debug --no-pub`: PASS, `frontend_app/build/app/outputs/flutter-apk/app-debug.apk`. Java native-access/SDK XML warnings hiện hữu không chặn build. 27 test mới trong [n04_persistence_test.dart](../frontend_app/test/providers/n04_persistence_test.dart), [n04_lifecycle_test.dart](../frontend_app/test/screens/n04_lifecycle_test.dart): startup/loading/retry/restart/no HTTP, swaps/draft/checklist restore, failed disk write, offline API failure, generate success/failure, invalid/legacy/versioned storage, midnight/resume/future/expiry, ngày 1–3, editor validation, responsive Pixel2 1x/2x + keyboard. Đây là unit/widget/HTTP fixture evidence, chưa phải Android runtime/live Groq.
- **File sửa N04:** `lib/main.dart`, `lib/routes.dart`; models `api/json_read.dart`, `plan_schedule.dart`; providers `auth_provider.dart` (auth sai kiểu không chặn offline startup), `plan_provider.dart`, `grocery_provider.dart`, `onboarding_provider.dart`; screens `auth/welcome_screen.dart`, `grocery/grocery_screen.dart`, `home/home_screen.dart`, `onboarding/{basic_info_screen,generating_plan_screen,restrictions_screen}.dart`, `plan/{plan_screen,generated_plan_screen}.dart`, `profile/{profile_screen,edit_profile_sheet}.dart`; widgets `plan_content.dart`, `plan_lifecycle.dart`, `plan_status.dart`, `restriction_fields.dart`; tests provider plan/grocery và hai file N04 trên; `docs/PLAN.md`. Bảo toàn thay đổi chưa commit có từ trước, không tính tất cả Git diff là N04.
- **Pixel 2 — manual còn UNVERIFIED:** backend: `npm run start:dev`; frontend: `flutter emulators --launch Pixel_2`, `flutter devices`, `flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:3000`. Tạo plan → swap món/bài → tích bought/have → force-stop và mở lại: Dashboard và dữ liệu đúng. Tắt backend/mạng rồi mở lại: vẫn xem ngày 1–3/checklist; swap/regenerate báo lỗi, không mất dữ liệu. Chỉ lưu hồ sơ → restart kiểm draft và plan cũ; Lưu & tạo lại khi backend tắt giữ plan, bật lại Retry thành công mới thay. Kiểm future/day2/expiry/resume qua midnight, text lớn/bàn phím/Back. Không clear data/uninstall khi kiểm restart. Ghi kết quả thực tế trước khi đóng 5.10/N04.
- **Tiếp theo:** manual N04/5.10; N05 feedback thật và persistent lock; N06 full integration/device gates. Không triển khai thêm các gói này trong lượt N04.

## Sửa Groq plan validation / diagnostic — 31/10/2026

**Kiểm chứng offline PASS; Groq LIVE UNVERIFIED.** Không gọi Groq thật, không đọc/in giá trị khóa, không sửa .env; không tăng DONE/69. Giữ **42/69 DONE (60,87%)**. Đây là sửa chất lượng/khả năng chẩn đoán của pipeline AI, chưa đủ đóng toàn bộ N08.

### Điều đã chứng minh và giới hạn nguyên nhân

Không có raw response của lần người dùng thấy 3 lỗi rồi 1 lỗi (hoặc 1 rồi 2), nên không thể gán chắc một lỗi lịch sử cho calo, macro hoặc schema. Không bỏ validation hay nới sàn BMR để che lỗi.

Bốn regression tests được viết trước sửa và đều FAIL trên baseline:
1. JSON minh họa cuối prompt có 1 ngày × 1 bữa, chuỗi rỗng và calories/amount bằng 0. Chính parsePlanContent từ chối mẫu này với 10 lỗi cấu trúc. Mẫu định dạng mâu thuẫn contract 3 ngày × 3 bữa và các trường bắt buộc.
2. Câu macro chưa chỉ rõ mẫu số; validator dùng abs(calories - (4P+4C+9F)) <= 0.15*calories, không phải 15% của 4P+4C+9F.
3. DayContentDto.workout thiếu IsDefined: bỏ workout vẫn lọt parsePlanContent và có thể lỗi khi kiểm restrictions/assembly sau đó.
4. Hai request retry có prompt giống hệt; lần 2 không biết mã lỗi/trường vi phạm lần 1. Mỗi kết quả được kiểm độc lập nên số lỗi không nhất thiết giảm.

Các lỗi code trên đã tái hiện/sửa. Chưa chứng minh chúng là nguyên nhân duy nhất của mọi lần Groq fallback hoặc rằng model live đã ổn định hơn.

### Thay đổi implementation

| File/hàm | Thay đổi |
|---|---|
| gemini.service.ts / buildPlanPrompt, planPromptExample, MACRO_RULE | Ví dụ JSON đủ 3×3, trường bắt buộc và số liệu theo target; chia 25/40/35 cộng đúng tổng; công thức macro đúng phép kiểm; nêu kiểu/độ dài/số lượng theo DTO. Prompt dùng chung nên Gemini cũng nhận các chỉ dẫn này. |
| dto/plan-content.dto.ts / DayContentDto.workout | IsDefined chặn thiếu/null workout ở bước schema, đúng trường vốn bắt buộc theo contract; không thêm trường response. |
| plan-validation.ts / parsePlanStructure, parsePlanContent, inspectPlan | Giữ errors cũ cho callers; thêm issues nội bộ gồm validator/kind/code/path; không đổi ranges hoặc tolerance. |
| restriction-filter.ts / findRestrictionIssues | Cùng predicates dị ứng/tag chấn thương, xuất mã/path cố định; không xuất keyword hoặc tên món/bài. |
| plan-diagnostics.ts | Allowlist mã, validator, kind và đường dẫn DTO; chỉ đưa tối đa 12 issue vào log/repair; error_count vẫn cho biết tổng. Không đưa raw error/name/health/AI body vào log. |
| groq-plan.service.ts / generatePlanContent, GroqContentError | Chỉ lần retry nối feedback lỗi đã rút gọn vào prompt. Phân loại JSON lỗi/truncated thành code cố định, không log body nhà cung cấp. |
| plan.service.ts / generateWithGemini nhánh Groq | Log JSON có event, provider, attempt, elapsed_ms, code/path; retry tối đa 2 trong budget cũ, không retry 4xx/timeout, không khởi động retry nếu còn <5s; fallback source sample giữ nguyên. |

Không coercion chuỗi số, không tự điền dữ liệu AI thiếu, không rescale để biến output sai thành PASS. trim/JSON parsing và normalizeKey hiện có được giữ; numeric strings vẫn TYPE, thiếu workout vẫn REQUIRED. Request/response công khai, source, Gemini integration, restrictions và logic cap exercise không đổi.

Ví dụ log mới (minh họa bằng dữ liệu tổng hợp, không phải log lịch sử người dùng):
```json
{"event":"plan_validation_failed","provider":"groq","attempt":1,"elapsed_ms":7,"error_count":1,"issues":[{"validator":"plan-rules","kind":"semantic","code":"MACRO_CALORIES","path":"days[0].meals[0]"}]}
```
Mã chính: REQUIRED/TYPE/ENUM/ARRAY_SIZE/RANGE (schema), DAY_CALORIES/MEAL_CALORIES/MACRO_CALORIES/MEAL_TYPES/DUPLICATE_MEAL (semantic), RESTRICTION_CONFLICT (safety). INVALID_JSON/INCOMPLETE_OUTPUT/HTTP_ERROR/TIMEOUT thuộc response/transport.

### Kiểm chứng thực tế đã chạy

- Thêm 26 unit tests trong groq-validation-regression.spec.ts (4) và plan-diagnostics.spec.ts (22): prompt/DTO parity, target 944=BMR, 1624 và 2806; missing/wrong types/enum, semantic, retry chữa được, hai lần vẫn sai, limit/budget, không log sentinel key/health/raw exception, giữ restrictions.
- Thêm 6 E2E trong test/groq-validation.e2e-spec.ts: Nest thật + GroqPlanService thật + HTTP upstream local. Test-only routing chặn mọi origin khác endpoint Groq và chuyển đúng endpoint đó sang loopback; không đổi URL production. Quan sát request body/path và response: repair TYPE, một rồi hai MACRO_CALORIES, missing workout, fallback vẫn >= BMR 944, 429 chỉ một call và hang timeout không retry.
- Không có Postman CLI/simulation có sẵn trong checkout; dùng Node HTTP stand-in cục bộ và test harness của repo. Không cài hay publish môi trường mới.
- npm test -- --reporter=dot: **410/410 PASS**, 31 files.
- npm run test:e2e -- --reporter=dot: **91/91 PASS**, 8 files.
- npm run typecheck, npm run lint: **PASS**, lint không còn cảnh báo mới.
- npm run build và npm run test:smoke: **PASS**; smoke chạy build thật với DB RAM/AI keys rỗng, kiểm generate/history/swap/feedback/auth/ownership.
- Không sửa bất kỳ tệp Flutter nào trong đợt này, không chạy lại Flutter analyze/tests. Contract được kiểm qua E2E response và các test backend N01/N02/N03 liên quan; không gọi đó là Flutter/device runtime acceptance mới.

### Hướng dẫn live có kiểm soát (người dùng tự chạy)

Backend local: npm run start:dev trong backend_api. Pixel_2 dùng API_BASE_URL=http://10.0.2.2:3000. Tạo đúng một kế hoạch bằng cùng hồ sơ lần trước, kiểm source=groq hay sample và đọc event/code/path mới nếu fallback. Một lần bấm có tối đa hai request AI; không bấm lặp nhiều lần.

Hoặc sau build, người dùng có thể chạy đúng một lần script tổng hợp hiện có:
```powershell
cd D:\AI-Product-Development-End-to-End\backend_api
node --env-file=.env scripts/test-groq-plan.mjs
```
Script báo source/elapsed/counts, không in key hay raw prompt. Nó dùng hồ sơ tổng hợp mặc định, không thay cho việc tái hiện đúng hồ sơ cũ. Chỉ source=groq mới là AI-generated success; source=sample là fallback. Agent chưa chạy lệnh live này.

Không commit/push/reset/clean; bảo toàn thay đổi chưa commit có sẵn, UI Figma và N01/N02/N03. Full live latency/acceptance vẫn UNVERIFIED; roadmap 69 task không tăng từ sửa bug.


## Khôi phục UI từ Figma export — 31/10/2026

**Đã triển khai và kiểm chứng code/UI theo ZIP; nghiệm thu toàn bộ vẫn PARTIAL.** Giữ 42/69 DONE (60,87%): đây là khắc phục thiếu sót presentation của N03, không thêm task DONE. N03 giữ kết quả kết nối dữ liệu; không diễn giải kết quả đó thành pixel-perfect hoặc device full-flow acceptance.

### Nguồn đối chiếu và phạm vi

Nguồn chính: file người dùng cung cấp `SmartFit AI Mobile App Design.zip`, SHA256 `4F56BCD3096C178365C14B76382D06FD9387A5304D79E836A389AA2A752E49D2`. Đọc React `src/App.tsx`, tokens/layout `src/index.css` và các frame PNG 390×844 trong `ui-reference/frames`; không dựa vào một screenshot. Không truy cập live Figma trong đợt này và không chạy script từ ZIP.

| Nhóm | Frame export | Phần đã khôi phục |
|---|---|---|
| Design system/navigation | CSS tokens, 01, 08–14 | Manrope offline 400–800 + OFL, xanh 16A34A/22C55E, canvas F6F8F7, radius 12/16/20, nút gradient, icon, bottom navigation; Navigator và sheet tối đa 430px trên web |
| Home/Plan | 08, 09 | Header, energy/progress/macros, carousel món, tab ngày, thẻ meals/workout; dữ liệu và ID qua PlanProvider |
| Meal/Workout Detail & Swap | 10–13, 23 | Hero, macro/ingredients, thống kê buổi tập, danh sách động tác, sticky action và sheet cuộn được; giữ request/error/retry/busy/409/422 |
| Grocery | 14 | Summary checklist, nhóm nguyên liệu, bought/have/khôi phục, tìm kiếm/lọc thu gọn; không thêm dữ liệu tự tạo |
| Welcome/Onboarding/Generating/Generated | 01, 03–07, 09 | Hình người vẽ native theo CSS, logo, header/progress, body form adaptive 2 cột, activity cards, safety notices, loading/error; Generated tái dùng Plan vì không có frame riêng |
| Empty/error/fallback | 24 | Empty CTA, notices, source/sample badge, retry, giữ plan cũ khi lỗi |

### Bảo toàn N01/N02/N03 và khác biệt có chủ đích

- Không sửa backend, AI provider, API contract, .env hoặc logic PlanProvider/GroceryProvider/ApiClient trong phiên restoration. Không thêm provider/client; không đưa MockDataProvider trở lại các màn N03.
- Giữ onboarding **3 bước**, ranges/rawBMI/pregnancy/restrictions và Back/Next của N02 thay vì bốn bước sample trong ZIP. Form trống vẫn trống; nút chỉ bật khi dữ liệu hợp lệ.
- N01 tiếp tục chờ response và persistence trước navigation, không dùng timer giả hoặc progress hoàn thành giả.
- Swap dùng ID thật và hồ sơ của plan; response thay cả plan/grocery rồi lưu. Export có preview món/bài và nút chọn, nhưng API hiện chọn rồi áp dụng sau request: sheet không bịa phương án hoặc kết quả trước khi server trả.
- Backend không có photo URL, recipe, exercise video, calories-burn hoặc difficulty được đảm bảo: dùng artwork trung tính, không gán ba ảnh món mẫu của ZIP cho món AI bất kỳ; không thêm chỉ dẫn hoặc khẳng định an toàn không có trong response.
- Dashboard hiển thị **năng lượng của kế hoạch**, không diễn giải thành calories đã ăn hoặc mức hoàn thành luyện tập. Không hardcode tên người/ngày/calories mẫu.
- Các khác biệt trên được ghi ở từng cặp ảnh; chưa kết luận pixel-perfect hay owner visual sign-off.

### Bằng chứng kiểm chứng

- Theo nhóm: design-system regression N01/N02 17/17; Dashboard ID test 1/1; detail/swap N03 6/6; Grocery/provider + N03 10/10; onboarding/generate regression 17/17. Sau tinh chỉnh từ ảnh, N03 + render/overflow 24/24.
- **flutter analyze --no-pub: PASS, No issues found.** Đã sửa 11 lint style phát hiện trong lần kiểm đầu.
- **flutter test --no-pub --reporter expanded: 131 PASS, 2 SKIP** ở bản source cuối. Hai test N01 HTTP local opt-in skip vì không có N01_BACKEND_URL; không tính là live-service PASS.
- **flutter build apk --debug --no-pub: PASS**, artifact `frontend_app/build/app/outputs/flutter-apk/app-debug.apk`. Có cảnh báo Android SDK XML/native-access nhưng exit 0.
- Thêm `frontend_app/test/screens/ui_restoration_test.dart`: 18 tests cho 10 màn/chặng chính, sheet, loading/error/empty, web width, dài tên/khẩu phần/reps/nguyên liệu, cuộn, keyboard. Kiểm kích thước 320×568, 411×731 (Pixel 2 logic), 390×844; text scale 2×; không phát hiện overflow ở các trường hợp này.
- Test helper N02 được cập nhật đợi layout sau ensureVisible và tap ChoiceChip thực tế khi label có cấu trúc nhiều dòng; không thay assertion hay bỏ safety tests.
- Render **17 PNG widget** với font Manrope + MaterialIcons; chụp thêm **2 PNG Android runtime**. Bộ ảnh và trang so sánh là artifact local `artifacts/ui-restoration/comparison.html`, chưa được duyệt đưa vào Git và không có trong checkout sạch. Đây là ghi nhận lịch sử, không thay nghiệm thu Pixel 2 hiện tại. Tái tạo ảnh widget bằng `flutter test test/screens/ui_restoration_test.dart --dart-define=UI_SCREENSHOTS=true`.
- **Android smoke PASS giới hạn:** AVD Pixel_2, 1080×1920, density 420; cập nhật APK với install -r, mở Welcome, bấm Bắt đầu ngay → Onboarding bước cơ thể; ảnh `android-pixel2-welcome.png` và `android-pixel2-onboarding.png`. Không gọi Groq/backend. Đã tắt đúng emulator headless do agent khởi động sau kiểm tra.
- **UNVERIFIED:** Generate → Dashboard → Detail → Swap → Grocery với HTTP thật trên Android, đầy đủ vòng đời/offline/keyboard native; chưa đo parity trực quan tự động/pixel-diff. Widget screenshots dùng fixture, không phải dữ liệu live Groq.

### Files và giới hạn giao nộp

Presentation thay đổi ở theme, main builder, navigation, Home/Plan/Meal/Workout/Grocery, Welcome/Onboarding/Generating/Generated và widgets dùng chung. Thêm fonts/OFL và UI tests/artifacts; không đổi persistence keys, request DTO hoặc response parser. Đọc Git trước khi sửa và giữ các thay đổi chưa commit có sẵn. Không commit/push, không reset/clean, không triển khai N04–N10.

Task 6.6/6.7 vẫn PARTIAL: đã có N03 + restoration coverage và Android smoke, nhưng profile/startup/model migration/fixture gate/full device E2E chưa hoàn tất. Không tăng dashboard từ công việc sửa UI.


## Cập nhật N03 — 30/10/2026

**N03: DONE trong phạm vi kết nối UI/API đã yêu cầu.** Dashboard, Plan, chi tiết món/bài, swap và Grocery dùng PlanProvider/GroceryProvider hiện có; không còn MockDataProvider trong các màn N03. Backend contract và lựa chọn Groq/Gemini không đổi. Màn kết quả N01 thêm nút mở Dashboard; giữ nguyên onboarding/safety/generate.

- **Code:** request swap gửi nguyên profile của plan + plan + meal_id/exercise_id; response thay cả plan, lưu theo cơ chế hiện có. Grocery dùng grocery_list server, giữ checklist theo category+name+quantity, hỗ trợ đã mua/đã có sẵn/khôi phục/tìm kiếm/lọc. Không có danh sách phương án thay thế giả hoặc nút thêm nguyên liệu tự tạo.
- **Kiểm thử:** flutter analyze: no issues; flutter test --no-pub --reporter expanded: **113 PASS, 2 SKIP**, gồm regression N01/N02 và 6 widget integration tests N03 trong test/screens/n03_integration_test.dart. Các test N03 dùng MockClient/FakeBackend: dashboard/current-day/ID/empty, chọn ngày và exercise ID, swap món/bài success/error/retry/busy/request-profile/persistence, 409 regenerate, detail thiếu, grocery swap/checklist.
- **Build:** flutter build apk --debug --no-pub: PASS; artifact frontend_app/build/app/outputs/flutter-apk/app-debug.apk. Có cảnh báo SDK XML version, build exit 0.
- **Tích hợp/nghiệm thu:** các widget tests đi qua ApiClient thật với HTTP giả; không gọi backend local/Groq thật trong phiên N03. Hai test HTTP local opt-in N01 bị skip vì không khai báo N01_BACKEND_URL. Android runtime/emulator/manual full-flow: **UNVERIFIED**. Không coi APK build là bằng chứng runtime.
- **Roadmap:** 6.4, 6.5, 7.1, 7.2 → DONE; **42/69 = 60,87%**. 6.6 và 6.7 vẫn PARTIAL vì còn profile/startup/model migration/fixture gate/device ngoài scope N03. 6.11 vẫn PARTIAL: N03 chỉ đọc todayNumber hiện có, chưa làm đầy đủ resume/expiry N04.
- **Giới hạn:** không có video/hướng dẫn nấu hoặc hướng dẫn động tác trong contract nên UI không tự tạo; chưa bổ sung test opt-in N03 với backend thật. Mock infrastructure còn giữ cho feedback và phần ngoài N03. Không commit/push, không sửa .env.

Các số 38/69 và kết quả trước ngày này bên dưới phần lịch sử Groq/N01/N02 là baseline tại thời điểm ghi nhận; dashboard mục 3 là hiện trạng mới.
## Cập nhật triển khai Groq — 26/10/2026

Theo yêu cầu người dùng sau khi thử tạo kế hoạch thành công trên app, Groq trở thành nhà cung cấp AI runtime mặc định. Phần này bổ sung bằng chứng mới; các kết quả Gemini và mô tả nhà cung cấp ở baseline 14/10 bên dưới là lịch sử. Không tăng tỷ lệ task khi chưa nghiệm thu đầy đủ tiêu chí UI/device.

### Đã hoàn thành trong đợt chuyển AI

- Tạo kế hoạch, đổi món, đổi bài, cân đối bữa ăn sau feedback và tạo chu kỳ mới ngày 3 dùng Groq. Trong chế độ Groq không tạo Google SDK client; giữ Gemini làm lựa chọn tương thích.
- Cấu hình qua GROQ_API_KEY/GROQ_MODEL/GROQ_TIMEOUT_MS/GROQ_TOTAL_TIMEOUT_MS; mặc định model openai/gpt-oss-120b, budget 60s mỗi lần/90s tổng. Không retry 401/403/429 hoặc timeout Groq.
- Giữ validation, giới hạn calo/BMR, lọc hạn chế, fallback, luật nguy hiểm, auth/history và quyền sở hữu. source bổ sung groq; Flutter parse/lưu/hiển thị được.
- Flutter chờ request AI 105s; health bổ sung ai_provider/ai_status, không coi configured là bằng chứng live.
- Lệnh experiment mặc định dùng đúng prompt/pipeline backend; system-prompt.md trỏ về code thay vì sao chép prompt cũ. BRD/README/credentials được ghi rõ thay đổi provider.

### Bằng chứng kiểm chứng mới

- Backend: 384 unit, 85 E2E đạt; typecheck/build/lint và smoke bản build đạt. E2E kiểm tất cả đường gọi Groq, cả chu kỳ mới và nhánh nguy hiểm không gọi AI.
- Flutter: 36 tests contract, API client và màn tạo kế hoạch đạt. Đây không phải full device acceptance.
- Groq thật bằng hồ sơ tổng hợp: tạo plan source=groq, đủ 3 ngày × 3 bữa, 14.401ms tổng; lần đầu không đạt validation, lần sau đạt. Target 1624 kcal; các ngày 1770/1780/1770 kcal nằm trong khoảng được contract cho phép, không phải khớp tuyệt đối target.
- Groq thật: đổi món 2032ms, đổi bài 843ms, cân đối bữa ăn sau feedback 2039ms. Mỗi chức năng HTTP200 từ Groq một lần; nội dung được validator chấp nhận và dùng trong kết quả, không tính fallback là thành công.
- Bằng chứng app do người dùng cung cấp: source groq, target1960; tổng ngày1/ngày3 đúng1960. Chưa đo latency dưới tải, chưa nghiệm thu tất cả nhóm hồ sơ hoặc thiết bị.

### Tiến độ và thứ tự sắp tới

Giữ dashboard 38/69 DONE (55,07%) theo tiêu chí task hiện có. Việc thay provider là nền AI, không đồng nghĩa đã xong N03–N10. Không tự tick các task còn thiếu fixture, UI, Google login, CI, release hoặc production.

1. **N03:** nối dashboard/kế hoạch/chi tiết món và bài tập/đổi món/đổi bài/đi chợ với PlanProvider và API thật; bỏ MockDataProvider ở các màn chức năng.
2. **N04:** mở lại saved plan, sửa hồ sơ/tạo lại, lịch ba ngày/hết hạn và lưu checklist đi chợ.
3. **N05:** nối feedback UI với API, cảnh báo nguy hiểm, ngày tiếp theo, chu kỳ mới ngày3 và chống gửi lặp.
4. **N06:** phục hồi fixture exporter/contract gate, kiểm thử UI toàn luồng và Android/device; không chỉ test provider hoặc mock HTTP.
5. **N07–N09:** tài khoản/lịch sử trên UI, Google Sign-In, củng cố prompt/chất lượng đầu ra, lint/release/CI. Việc chuyển Groq chỉ giải quyết một phần N08; chưa đóng toàn bộ N08.
6. **N10:** deploy có lưu trữ bền, nghiệm thu full-flow, ảnh minh chứng, slides và video.

Giới hạn còn lại: JSON mode chưa strict schema; yêu cầu tên bài tiếng Việt/không dụng cụ mới được bổ sung prompt, chưa có kiểm tra ngữ nghĩa đầy đủ. Free tier vẫn có quota, không bảo đảm production hoặc mọi lần gọi thành công. Hướng dẫn chạy và script thử thật ở [GROQ_TRIAL.md](../backend_api/GROQ_TRIAL.md).

## 1. Project Overview

**Single source of truth:** `docs/PLAN.md`. Cập nhật hợp nhất: **14/10/2026**. Mọi Coding Agent đọc và cập nhật trạng thái tại đây; không tạo roadmap tổng thể song song.

[BRD](../BRD.md) v2.6.0 là nguồn yêu cầu sản phẩm đã phê duyệt. Roadmap này quản lý thứ tự, trạng thái và nghiệm thu; các [implementation plans](superpowers/plans/) giữ nguyên để tra cứu thiết kế, subtasks và test. Nếu tiêu chí lịch sử trong spec đã được phiên bản BRD mới thay thế, dùng yêu cầu mới đã duyệt và ghi bằng chứng; không âm thầm bỏ tiêu chí còn hiệu lực.

App Android dùng Flutter/Dart, Provider/ChangeNotifier, named routes và shared_preferences; backend dùng NestJS/TypeScript, TypeORM/better-sqlite3 và Gemini SDK @google/genai. Native Android chỉ là Flutter host, không phải Kotlin/Compose app.

Thứ tự mục tiêu: backend có hợp đồng và kiểm thử → Flutter nối API → tính năng nâng cao/tài khoản → deploy và nghiệm thu. Luồng khôi phục hiện tại ưu tiên N01–N06 ở mục 10. Trước implementation giai đoạn 1–8, đối chiếu BRD và spec hiện có; quy trình lập spec ban đầu dùng /feature-explore → /feature-plan. /feature-build bản Next.js chưa áp dụng cho repo này; không tự triển khai hay đổi scope khi chỉ đang cập nhật tài liệu.

### Chế độ giả lập và dịch vụ thật

| Dịch vụ | Giả lập | Chế độ thật |
|---|---|---|
| Gemini | Không GEMINI_API_KEY → dữ liệu mẫu | Key chỉ ở backend env; xem [credentials](SETUP_CREDENTIALS.md) |
| Auth | AUTH_MODE=mock, mock:<email>; tạo user/JWT/history thật | AUTH_MODE=google + client ID + JWT secret; production mock bị chặn trừ override demo chủ đích |

### Quyết định D1–D6 được bảo toàn

Đoạn dưới lưu nguyên quyết định đã duyệt từ roadmap cũ. Những câu mô tả hiện trạng/lần chạy trong đoạn này là **lịch sử quyết định**, không thay trạng thái ở mục 5. D5 thay phần giao diện của D4; D6 bổ sung safety/lịch/ba bước. Các mục “Để sau” giữ ngoài 69 task, chưa được coi là scope implementation đã duyệt.

Giao diện Flutter (thiết kế từ Figma) và backend/BRD từng lệch nhau ở 4 điểm dưới. Các quyết định này được áp dụng ở giai đoạn 1.

**D1 — Mức điều chỉnh calo theo mục tiêu:** theo giao diện. Giảm mỡ −300 kcal/ngày, tăng cơ +250 kcal/ngày (backend đang để −500 / +300, sẽ sửa).

**D2 — Feedback cuối ngày:** gồm 3 câu hỏi.

| Câu hỏi | Lựa chọn | Tác động lên ngày kế tiếp |
|---|---|---|
| Cường độ buổi tập hôm nay (chọn 1) | Nhẹ nhàng / Vừa sức / Rất mệt | Tăng nhẹ / Giữ nguyên / Giảm khối lượng tập |
| Tình trạng cơ thể khi hoặc sau khi tập (chọn nhiều) | Bình thường · Căng mỏi cơ · Đau khớp (gối, cổ tay, vai…) · Uể oải, thiếu ngủ · ⚠️ Chóng mặt, khó thở bất thường, đau ngực | Căng mỏi cơ → giảm hiệp nhóm cơ đó, thêm giãn cơ. Đau khớp → bỏ động tác bật nhảy, chống quỳ. Uể oải → rút ngắn buổi tập. **⚠️ Dấu hiệu nguy hiểm → không tự điều chỉnh plan; hiện khuyến cáo ngừng tập và hỏi ý kiến bác sĩ; ngày kế tiếp chỉ nghỉ hoặc đi bộ nhẹ** |
| Ăn uống (chọn 1) | Đúng thực đơn / Ăn nhiều hơn / Ăn ít hơn hoặc bỏ bữa | Cân đối lại món ăn ngày kế tiếp (không hạ calo dưới BMR) |

**D3 — Nguyên liệu đi chợ:** API trả `name` và `quantity` riêng (ví dụ `{ "name": "Ức gà", "quantity": "450g" }`), nhóm nguyên liệu là danh sách cố định 3 nhóm để giao diện gắn icon.

**D4 — Hạn chế và sức khoẻ ở Onboarding:** người dùng tự nhập, sửa được về sau.

- 3 ô nhập tự do: *Dị ứng / thực phẩm cần tránh*, *Chấn thương / vùng cơ thể cần tránh*, *Tình trạng sức khoẻ / bệnh nền* (mới — ví dụ tiểu đường, cao huyết áp, gout).
- Có chip gợi ý bấm nhanh (hải sản, trứng, sữa, đậu phộng, đau gối, đau lưng…); bấm vào chỉ điền sẵn chữ vào ô, không thay cho ô nhập.
- Sửa bất cứ lúc nào ở tab "Cá nhân" (hiện đang là placeholder).
- **Lưu trên máy, không lưu ở server.** Thông tin sức khoẻ gửi kèm từng request rồi bỏ đi; backend không ghi vào DB, không ghi log. Đây là dữ liệu cá nhân nhạy cảm theo Nghị định 13/2023/NĐ-CP.
- **Có Gemini:** văn bản tự do đưa vào prompt, đặt trong khối dữ liệu tách biệt, giới hạn 300 ký tự mỗi ô để hạn chế prompt injection.
- **Chế độ giả lập:** code khớp từ khoá phổ biến (tôm, cua, sữa, gối…). Nếu có nội dung không nhận ra, app cảnh báo rằng chưa kiểm tra được toàn bộ hạn chế.
- App ghi rõ: gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế; người có bệnh nền nên hỏi ý kiến bác sĩ.

**D5 — Cách nhập hạn chế (2026-09-26, góp ý khi chạy thử trên Android; thay phần giao diện của D4):** Onboarding hiện có hai ô tích cứng "Dị ứng hải sản", "Đau khớp gối" — người không dị ứng hay không chấn thương thì không có lựa chọn "không", người dị ứng thứ khác thì không nhập được.

- Ba mục *Dị ứng*, *Chấn thương*, *Tình trạng sức khoẻ*, mỗi mục một công tắc "Tôi có …", mặc định tắt (= không có).
- Bật lên → danh sách phổ biến, tích được nhiều mục, và lựa chọn "Khác" mở ô tự ghi. Tổng chuỗi ghép không quá 300 ký tự.
- Danh sách dị ứng và chấn thương lấy đúng các nhóm backend nhận ra (`backend_api/src/plan/data/restriction-keywords.json`: hải sản, tôm, cua, cá, mực, nghêu/sò/ốc, đậu phộng, trứng, sữa, đậu nành, gluten, thịt bò, thịt heo, thịt gà, mè, nấm; đầu gối, cổ chân, cổ tay/khuỷu tay, lưng, vai), để mục nào được tích cũng được lọc ở chế độ giả lập. Cần test hai phía để danh sách app không lệch file từ khoá.
- Tình trạng sức khoẻ (tiểu đường, cao huyết áp, gout…): chỉ được đưa vào prompt khi có Gemini; chế độ giả lập **chưa** điều chỉnh thực đơn theo bệnh nền, chỉ hiện khuyến cáo — giao diện phải nói rõ.
- App ghép lựa chọn thành chuỗi gửi đi, hợp đồng API (BRD 6.1) không đổi. Phần "Khác" backend không nhận ra → cảnh báo "chưa nhận ra hết" (đã có).
- Tab "Cá nhân" dùng cùng cách nhập. BRD FR-1.4 sửa theo ở giai đoạn 6.

**D6 — An toàn sức khoẻ và luồng dùng hằng ngày (2026-09-26, rà theo 3 nhóm người dùng của BRD mục 3, thử thật trên backend và máy ảo):**

| # | Vấn đề đã thử | Quyết định |
|---|---|---|
| A1 | Nữ 160 cm / 42 kg (BMI 16,4) chọn "Giảm mỡ" → plan 1.159 kcal, chỉ có cảnh báo sàn BMR | BMI < 18,5 không được chọn "Giảm mỡ" (backend 400 + form khoá lựa chọn, gợi ý "Duy trì"/"Tăng cơ") |
| A2 | 14 tuổi chọn "Giảm mỡ" → plan thâm hụt, không cảnh báo; backend nhận tuổi từ 10, Mifflin-St Jeor dành cho người lớn | Tuổi tối thiểu **18** ở backend và form (đối tượng BRD: sinh viên, người đi làm) |
| A3 | Không khai báo được mang thai / cho con bú | Thêm vào danh sách sức khoẻ của D5; có mục này thì không cho thâm hụt calo |
| A4 | Mọi hồ sơ nhận cùng buổi tập ở chế độ giả lập (người 65 tuổi ít vận động cũng có Jumping Jacks) | Chọn mức động tác (kho đã có `level` 1–3) theo tuổi và `activity_level`; prompt Gemini ghi cùng luật |
| B1 | Plan chỉ có ngày 1–3, không có ngày bắt đầu: hôm sau mở app vẫn "Ngày 1", bỏ dùng lâu thì plan cũ nằm mãi | App lưu ngày bắt đầu trên máy, tự chuyển ngày theo lịch; hết 3 ngày → gợi ý tạo plan mới |
| B2 | Onboarding sẽ có khoảng 10 trường; trên màn hình 720×1280 nút tạo kế hoạch đã nằm dưới mép màn hình | Chia 3 bước (chỉ số cơ thể → mục tiêu & vận động → hạn chế), thanh tiến trình, nút luôn ở đáy |

A1–A4 đổi hợp đồng và luật dinh dưỡng → BRD v2.6.0 ở giai đoạn 6 (FR-1.1, FR-1.4, FR-1.5, FR-2.2, NFR an toàn). **Để sau** (đã cân nhắc, chưa làm): đi chợ theo số người nấu; tuỳ chọn ăn chay (cần thêm món chay và nhóm từ khoá); đánh dấu bữa ăn ngoài (phải đổi cách backend tính danh sách đi chợ); cảnh báo nhẹ khi BMI ≥ 30 chọn "Tăng cơ". **Đã làm sau giai đoạn 6 (27/09/2026):** cân macro của thực đơn mẫu và kho món đổi (phát hiện khi chạy thử giai đoạn 6: thực đơn mẫu chỉ được nhân khẩu phần theo calo nên tinh bột ~120%, chất béo ~70% mục tiêu) — nay mỗi ngày lệch 25/45/30 không quá 3 điểm, có test (ràng buộc #33).

---

## 2. Current Project Status

Hiện trạng đối chiếu C12 ngày 01/11/2026: N01–N03 đã nối Onboarding/Generate/Dashboard/Swap/Grocery với API. Startup N04 khôi phục plan hợp lệ vào Dashboard, chưa có plan thì Welcome, có loading/retry; không tự gọi AI. N05 feedback dùng API thật, receipt SQLite và snapshot local, có pending/retry, chu kỳ chờ và lịch sử. Kiểm thử trên host đạt theo bảng đầu tài liệu; N04 vẫn PARTIAL và N06 chưa được nghiệm thu Android/Pixel 2. Groq live sau các thay đổi mới và release vẫn UNVERIFIED.

Baseline lịch sử là báo cáo audit trong cuộc hội thoại ngày 14/10/2026; không tìm thấy báo cáo full audit lưu trong repository. Phase1_Report và Phase_2_Final_Report là báo cáo lịch sử, không thay kết quả hiện tại. Lượt consolidation ban đầu đọc code/test/workflows và toàn bộ hai PLAN/BRD/38 specs, không chạy lại build hoặc test. Bảng tiếp theo và ghi nhận N01/N02 bên dưới giữ bằng chứng ở thời điểm đó; không phải kết quả C12 và không dùng để hạ trạng thái implementation hiện tại.

| Cổng kiểm audit 14/10/2026 | Kết quả và giới hạn |
|---|---|
| Backend typecheck/build/lint | PASS local |
| Backend unit | 28 file, 369 tests PASS |
| Backend E2E | 6 file, 73 tests PASS |
| Backend dist smoke | PASS health/auth/generate/history/swap/feedback/ownership/day3 |
| AI workspace tsc --noEmit | PASS; prompt chưa đồng bộ |
| Flutter analyze / flutter test | Sạch / 64 tests PASS; không có testWidgets hiện tại |
| APK debug / web | Build PASS; release/thiết bị chưa nghiệm thu |
| Android :app:lintDebug | FAIL: 2 PropertyEscape errors ở local.properties, 7 warnings; offline attempt thiếu cache, online attempt chạy xong |
| Live Google/Gemini, production, CI đúng commit | UNVERIFIED |

Môi trường audit: Windows, Node24.11.1, Flutter3.47.1/Dart3.13.1; CI Flutter ghim3.47.5. Không lấy test count lịch sử trong spec làm số lượng test hiện tại.

### Quy tắc trạng thái và mức bằng chứng

| Trạng thái | Cách dùng |
|---|---|
| DONE | Đáp ứng scope/criteria, có bằng chứng kiểm tra tương ứng; task tài liệu/config không tự chứng minh tính năng UI |
| PARTIAL | Có phần đạt nhưng thiếu tiêu chí bắt buộc |
| NOT STARTED | Chưa có implementation/artifact cần thiết trong checkout |
| BLOCKED | Phụ thuộc cần thiết đang thiếu, nêu rõ blocker |
| BUGGY | Có implementation nhưng đường xử lý trái yêu cầu được xác định từ source/test |
| UNVERIFIED | Chưa đủ evidence để kết luận; không tính hoàn thành |

Mỗi task có scope, acceptance criteria, evidence/gap và dependency tại mục 5. Khi cập nhật, ghi riêng bốn mức: **code/config/tài liệu**, **kiểm thử**, **tích hợp**, **nghiệm thu**. Test provider không chứng minh UI gọi provider; build không chứng minh runtime; CI file không chứng minh CI pass. Task chưa đạt toàn scope không được tick DONE. Commit/push là thao tác giao nộp theo ủy quyền, không phải bằng chứng tính năng; consolidation này không commit/push.

Kết quả mới cho N01 ngày 14/10/2026: analyze sạch; toàn bộ 78 tests pass khi bật hai tests HTTP local; APK debug build pass. Các test dịch vụ thật chỉ chạy khi khai báo N01_BACKEND_URL; mặc định suite bỏ qua hai test này. Chi tiết và giới hạn Android/Gemini ở [N01](#n01). Chỉ nâng task 6.3 đã kiểm chứng; các task còn lại không được nâng trạng thái.

N02 bổ sung ngày 14/10/2026: analyze sạch; 108/108 tests pass với HTTP local; APK debug build pass. Chỉ cập nhật task 6.1 (DONE) và coverage 6.6 (PARTIAL); N01 giữ nguyên trạng thái/evidence lịch sử. Thao tác N02 trên emulator/device vẫn UNVERIFIED.

## 3. Progress Dashboard

| Trạng thái | Task |
|---|---:|
| DONE | 46 |
| PARTIAL | 13 |
| NOT STARTED | 4 |
| BLOCKED | 1 |
| BUGGY | 0 |
| UNVERIFIED | 5 |
| **Total** | **69** |
| **Completion** | **66.67%** |

Completion = DONE / Total ×100 =46/69×100. PARTIAL/UNVERIFIED không tính DONE. Mẫu số là 69 task roadmap: task/subtask/criteria trong 38 specs được ánh xạ, không cộng lặp; N01–N10 là nhóm triển khai của task hiện có, không phải mười task mới. Chưa dùng trọng số công sức vì chưa có estimate thống nhất.

## 4. Phase 0–9 Roadmap

| Phase | Phạm vi | Size | Total | DONE | PARTIAL | NOT STARTED | BLOCKED | BUGGY | UNVERIFIED | Completion |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | Dọn dẹp & chuẩn bị | S | 7 | 7 | 0 | 0 | 0 | 0 | 0 | 100.00% |
| 1 | Chốt hợp đồng API | M | 4 | 3 | 1 | 0 | 0 | 0 | 0 | 75.00% |
| 2 | Backend: kiểm thử nền | M | 6 | 5 | 0 | 0 | 0 | 0 | 1 | 83.33% |
| 3 | Backend: tài khoản & lịch sử | L | 9 | 8 | 1 | 0 | 0 | 0 | 0 | 88.89% |
| 4 | Backend: đổi món, đổi bài, feedback | L | 9 | 7 | 1 | 1 | 0 | 0 | 0 | 77.78% |
| 5 | Frontend: nền tảng | M | 10 | 7 | 1 | 0 | 1 | 0 | 1 | 70.00% |
| 6 | Frontend: nối MVP | L | 11 | 6 | 5 | 0 | 0 | 0 | 0 | 54.55% |
| 7 | Frontend: tính năng nâng cao | M | 3 | 3 | 0 | 0 | 0 | 0 | 0 | 100.00% |
| 8 | Frontend: tài khoản & lịch sử | M | 4 | 0 | 2 | 2 | 0 | 0 | 0 | 0.00% |
| 9 | Deploy, nghiệm thu, nộp bài | M | 6 | 0 | 2 | 1 | 0 | 0 | 3 | 0.00% |

Phase 6 có sáu task DONE: 6.3 qua N01, 6.1 qua N02, 6.4 và 6.5 qua N03, 6.2 và 6.11 qua N04. Task 6.6 PARTIAL vì có tests Onboarding/FakeBackend và generate, chưa có bộ kiểm toàn màn hình/device. Dashboard và grocery đã nối qua N03; startup/profile/calendar đạt automated acceptance N04, nghiệm thu thiết bị còn thiếu.

| Phase | Implementation plan | Điều kiện chuyển milestone |
|---|---|---|
| 0 | Chưa có phase plan riêng trong checkout | Đạt task criteria và backend gates; AI thật/CI ghi riêng |
| 1 | [Spec/README](superpowers/plans/phase-1-api-contract/README.md) | Đạt task criteria và backend gates; AI thật/CI ghi riêng |
| 2 | [Spec/README](superpowers/plans/phase-2-backend-tests/README.md) | Đạt task criteria và backend gates; AI thật/CI ghi riêng |
| 3 | [Spec/README](superpowers/plans/phase-3-auth-history/README.md) | Đạt task criteria và backend gates; AI thật/CI ghi riêng |
| 4 | [Spec/README](superpowers/plans/phase-4-swap-feedback/README.md) | Đạt task criteria và backend gates; AI thật/CI ghi riêng |
| 5 | [Spec/README](superpowers/plans/phase-5-frontend-foundation/README.md) | Đạt UI request/response + error/safety + tests/device acceptance |
| 6 | [Spec/README](superpowers/plans/phase-6-connect-mvp/README.md) | Đạt UI request/response + error/safety + tests/device acceptance |
| 7 | Chưa có phase plan riêng trong checkout | Đạt UI request/response + error/safety + tests/device acceptance |
| 8 | Chưa có phase plan riêng trong checkout | Đạt UI request/response + error/safety + tests/device acceptance |
| 9 | Chưa có phase plan riêng trong checkout | Production/storage/full-flow và artifact nghiệm thu |

Các brainstorm được plan lịch sử nhắc tới dưới `docs/superpowers/brainstorms/` chưa có trong checkout; ghi nhận thiếu trace, không tạo broken link hoặc suy luận quyết định mới.

## 5. Detailed Task Checklist

Chỉ các heading “Task” bên dưới định nghĩa 69 task duy nhất. Checkbox của task cha và Status luôn nhất quán; criteria còn lại được đọc từ scope gốc, acceptance hiện hành và spec đính kèm. Phạm vi gốc giữ nguyên để không mất yêu cầu; các chú thích “hiện tại/đã có/sẽ sửa” trong phạm vi gốc là lịch sử, không phải trạng thái mới.

<a id="task-0-1"></a>

### Task 0.1 — SDK/auth/DB và roadmap trong CLAUDE

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** Sửa `CLAUDE.md`: `gemini.service.ts` đã dùng `@google/genai` (đang ghi SDK cũ); thêm quyết định auth/DB; trỏ tới plan này
- **Acceptance criteria hiện hành:** CLAUDE dùng @google/genai; ghi auth/DB và liên kết roadmap chính.
- **Evidence / lý do chưa đạt:** Đã đối chiếu nội dung SDK/auth/database; các mô tả frontend cũ còn thuộc 9.5.
- **Source / tests:** [CLAUDE.md](../CLAUDE.md).

<a id="task-0-2"></a>

### Task 0.2 — Dart SDK trong wiki

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** Sửa lỗi trong wiki `reference-materials.md`: ràng buộc `sdk: ^3.13.1` trong `pubspec.yaml` **đã thoả** yêu cầu Dart 3.9+ của `shared_preferences`, không cần nâng như đã ghi
- **Acceptance criteria hiện hành:** Wiki ghi sdk ^3.13.1 đã đáp ứng yêu cầu Dart 3.9+, không yêu cầu nâng SDK vô cớ.
- **Evidence / lý do chưa đạt:** Nội dung đã sửa đúng; đối chiếu pubspec.
- **Source / tests:** [reference-materials.md](knowledge/wiki/reference-materials.md).

<a id="task-0-3"></a>

### Task 0.3 — Yêu cầu lưu trữ SQLite

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** Sửa BRD mục 7.6: Render bản free không giữ file SQLite (mất dữ liệu khi service ngủ/restart); thay bằng nơi có ổ lưu trữ bền, hoặc Postgres
- **Acceptance criteria hiện hành:** BRD ghi SQLite cần host có storage bền hoặc Postgres; không dùng Render free với SQLite.
- **Evidence / lý do chưa đạt:** BRD §7.6 đã ghi yêu cầu; lựa chọn host thực tế chưa được xác minh ở 9.1.
- **Source / tests:** [BRD.md](../BRD.md).

<a id="task-0-4"></a>

### Task 0.4 — HTTP status POST

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** Các endpoint POST trả HTTP 200 như sơ đồ BRD (NestJS mặc định trả 201)
- **Acceptance criteria hiện hành:** Mọi POST thành công trả 200; DELETE account trả 204 theo hợp đồng riêng.
- **Evidence / lý do chưa đạt:** E2E và smoke audit pass; decorators HttpCode đúng.
- **Source / tests:** [plan.controller.ts](../backend_api/src/plan/plan.controller.ts); [plan-adjust.controller.ts](../backend_api/src/plan/adjust/plan-adjust.controller.ts); [auth.controller.ts](../backend_api/src/auth/auth.controller.ts).

<a id="task-0-5"></a>

### Task 0.5 — Health configuration

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** `GET /health` báo trạng thái cấu hình `{ status, gemini: "configured" | "fallback" }` để kiểm tra nhanh khoá đã gắn đúng chưa (trường `auth_mode` thêm ở bước 3.3, khi đã có auth)
- **Acceptance criteria hiện hành:** GET /health trả status, gemini configured/fallback và auth_mode khi có auth.
- **Evidence / lý do chưa đạt:** Health qua E2E và smoke audit pass.
- **Source / tests:** [app.service.ts](../backend_api/src/app.service.ts); [app.e2e-spec.ts](../backend_api/test/app.e2e-spec.ts).

<a id="task-0-6"></a>

### Task 0.6 — Hướng dẫn Gemini credentials

- [x] **Status: DONE**
- **Dependency:** Không có prerequisite task riêng.
- **Phạm vi gốc:** Tạo `docs/SETUP_CREDENTIALS.md` — phần **Gemini API key**: lấy key ở đâu, điền vào file nào, kiểm tra thế nào
- **Acceptance criteria hiện hành:** Có cách lấy key, đặt backend env, kiểm tra source/health, bảo mật và lỗi thường gặp.
- **Evidence / lý do chưa đạt:** Mục Gemini đã có đủ hướng dẫn; không chứng minh key thật của deployment.
- **Source / tests:** [SETUP_CREDENTIALS.md](SETUP_CREDENTIALS.md).

<a id="task-0-7"></a>

### Task 0.7 — README liên kết roadmap

- [x] **Status: DONE**
- **Dependency:** [0.6](#task-0-6)
- **Phạm vi gốc:** README trỏ tới plan này và file hướng dẫn
- **Acceptance criteria hiện hành:** README trỏ roadmap chính và hướng dẫn credentials.
- **Evidence / lý do chưa đạt:** Liên kết đã có; consolidation làm rõ quyền quản lý trạng thái.
- **Source / tests:** [README.md](../README.md).

<a id="task-1-1"></a>

### Task 1.1 — BRD và quyết định D1–D4

- [x] **Status: DONE**
- **Dependency:** [0.1](#task-0-1), [0.2](#task-0-2), [0.3](#task-0-3)
- **Phạm vi gốc:** Áp dụng D1–D4 vào BRD, nâng lên v2.3.0 (thay đổi phạm vi thật: thêm ô bệnh nền, sửa hồ sơ, feedback mới):
  - FR-1.3: mức điều chỉnh calo −300 / +250 (D1)
  - FR-1.4: 3 ô nhập tự do + chip gợi ý (D4); thêm FR-1.6: sửa hồ sơ ở tab "Cá nhân"
  - FR-5.1, FR-5.2: feedback 3 câu hỏi và quy tắc xử lý dấu hiệu nguy hiểm (D2)
  - Mục 6.1: `restrictions` đổi thành 3 chuỗi `allergies`, `injuries`, `health_conditions` (tối đa 300 ký tự mỗi chuỗi)
  - Mục 6.2: nguyên liệu tách `name` / `quantity`, 3 nhóm cố định (D3)
  - Mục 7: thêm NFR quyền riêng tư dữ liệu sức khoẻ (không lưu/ghi log ở server), chống prompt injection, khuyến cáo "không thay thế tư vấn y tế"
- **Acceptance criteria hiện hành:** BRD có calorie -300/+250, restrictions ba chuỗi ≤300 ký tự, profile edit, feedback ba câu, grocery name/quantity, privacy/injection/disclaimer; áp cập nhật D5/D6 đã duyệt.
- **Evidence / lý do chưa đạt:** BRD v2.6.0 bảo toàn phạm vi; năm JSON block parse được trong audit. Scope task này là tài liệu, không phải UI hoàn thành.
- **Source / tests:** [BRD.md](../BRD.md).
- **Spec, subtasks và cổng kiểm:** [1/F01](superpowers/plans/phase-1-api-contract/specs/F01-brd-contract.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-1-2"></a>

### Task 1.2 — Hợp đồng adjustment API

- [x] **Status: DONE**
- **Dependency:** [1.1](#task-1-1)
- **Phạm vi gốc:** Thêm BRD mục 6.4: schema request/response cho đổi món, đổi bài tập, feedback (hiện mới chỉ bàn trong chat, chưa có trong BRD)
- **Acceptance criteria hiện hành:** BRD §6.4 mô tả request/response và lỗi cho meal swap, exercise swap, feedback.
- **Evidence / lý do chưa đạt:** Hợp đồng đã có; tests backend audit pass.
- **Source / tests:** [BRD.md](../BRD.md); [adjust-plan.dto.ts](../backend_api/src/plan/dto/adjust-plan.dto.ts).
- **Spec, subtasks và cổng kiểm:** [1/F01](superpowers/plans/phase-1-api-contract/specs/F01-brd-contract.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-1-3"></a>

### Task 1.3 — DTO, sample, pipeline và prompt đồng bộ

- [ ] **Status: PARTIAL**
- **Dependency:** [1.1](#task-1-1), [1.2](#task-1-2)
- **Phạm vi gốc:** Cập nhật backend cho khớp: DTO, interface, hằng số `GOAL_CALORIE_ADJUSTMENT`, prompt Gemini (đưa văn bản tự do vào khối dữ liệu tách biệt). Soạn lại `sample-plan.json` theo schema mới và **đủ 3 ngày** (hiện chỉ có Ngày 1, demo ở chế độ giả lập sẽ thiếu 2 ngày)
- **Acceptance criteria hiện hành:** DTO/enums khớp BRD; sample đủ ba ngày; target/validation/assembly và fallback được nối; văn bản user tách biệt; prompt AI workspace đồng bộ backend; xóa interfaces/helpers cũ theo spec.
- **Evidence / lý do chưa đạt:** Backend build/test pass trong audit; workspace còn timeout 15s, model 3.8 và thiếu luật mức/pregnancy so với backend 20s/40s, model 3.5.
- **Source / tests:** [plan.service.ts](../backend_api/src/plan/plan.service.ts); [gemini.service.ts](../backend_api/src/plan/gemini.service.ts); [generate-plan-experiment.ts](../ai_workspace/generate-plan-experiment.ts); [system-prompt.md](../ai_workspace/prompts/system-prompt.md).
- **Spec, subtasks và cổng kiểm:** [1/F02](superpowers/plans/phase-1-api-contract/specs/F02-plan-types-validation.md); [1/F03](superpowers/plans/phase-1-api-contract/specs/F03-daily-target.md); [1/F04](superpowers/plans/phase-1-api-contract/specs/F04-plan-assembly.md); [1/F05](superpowers/plans/phase-1-api-contract/specs/F05-sample-plan.md); [1/F06](superpowers/plans/phase-1-api-contract/specs/F06-generate-plan-pipeline.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-1-4"></a>

### Task 1.4 — Wiki về privacy và safety

- [x] **Status: DONE**
- **Dependency:** [1.1](#task-1-1)
- **Phạm vi gốc:** Thêm vào wiki `critical-constraints.md`: không lưu dữ liệu sức khoẻ ở server; dấu hiệu nguy hiểm → khuyến cáo, không tự điều chỉnh plan; không hạ calo dưới BMR
- **Acceptance criteria hiện hành:** Wiki có không lưu/log health data, danger signs ưu tiên nghỉ/khuyến cáo, không dưới BMR.
- **Evidence / lý do chưa đạt:** Các ràng buộc đã có; không coi đây là bằng chứng UI áp dụng.
- **Source / tests:** [critical-constraints.md](knowledge/wiki/critical-constraints.md).
- **Spec, subtasks và cổng kiểm:** [1/F07](superpowers/plans/phase-1-api-contract/specs/F07-docs-wiki.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-2-1"></a>

### Task 2.1 — Ma trận BMR/TDEE

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3)
- **Phạm vi gốc:** Unit test `computeDailyTarget()` (`daily-target.ts`): mở rộng từ 3 ca đã có ở giai đoạn 1 ra đủ nam/nữ × 3 mức vận động × 3 mục tiêu (tiêu chí nghiệm thu tuần 5)
- **Acceptance criteria hiện hành:** Test nam/nữ × ba mức vận động × ba mục tiêu; expected độc lập; bao gồm sàn BMR và rounding .5.
- **Evidence / lý do chưa đạt:** Unit suite audit pass, có ma trận và boundary cases.
- **Source / tests:** [daily-target.spec.ts](../backend_api/src/plan/daily-target.spec.ts).
- **Spec, subtasks và cổng kiểm:** [2/F01](superpowers/plans/phase-2-backend-tests/specs/F01-daily-target-matrix.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-2-2"></a>

### Task 2.2 — Plan validation tests

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3)
- **Phạm vi gốc:** ~~Unit test `isNutritionWithinBounds()`~~ — hàm này đã được thay bằng `findPlanViolations()` và có test ở giai đoạn 1 (`plan-validation.spec.ts`)
- **Acceptance criteria hiện hành:** findPlanViolations thay isNutritionWithinBounds; kiểm cấu trúc, enum, bữa/ngày, calories, macro và trùng món bằng tests.
- **Evidence / lý do chưa đạt:** Unit audit pass; task được nghiệm thu theo hàm thay thế đã ghi trong PLAN.
- **Source / tests:** [plan-validation.spec.ts](../backend_api/src/plan/plan-validation.spec.ts).

<a id="task-2-3"></a>

### Task 2.3 — Generate retry/fallback tests

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3)
- **Phạm vi gốc:** Unit test `PlanService.generatePlan()` với Gemini giả: kết quả hợp lệ → `source: gemini`; sai hợp đồng → gọi lại → thực đơn mẫu; hết giờ → không gọi lại; khoá sai → thực đơn mẫu (trường hợp không có khoá đã có test ở giai đoạn 1)
- **Acceptance criteria hiện hành:** Gemini đúng dùng source gemini; sai gọi lại tối đa một lần rồi sample; timeout không retry; invalid key/fallback và log không lộ health data được kiểm.
- **Evidence / lý do chưa đạt:** Unit audit pass; error/timeout/retry branches có assertions.
- **Source / tests:** [plan.service.spec.ts](../backend_api/src/plan/plan.service.spec.ts); [gemini-retry.spec.ts](../backend_api/src/plan/gemini-retry.spec.ts).
- **Spec, subtasks và cổng kiểm:** [2/F03](superpowers/plans/phase-2-backend-tests/specs/F03-plan-service-retry.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-2-4"></a>

### Task 2.4 — Generate HTTP E2E

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3), [2.3](#task-2-3)
- **Phạm vi gốc:** E2E `POST /api/v1/generate-plan`: payload đúng → 200, payload sai → 400, `restrictions` kiểu mảng cũ → 400 (test e2e cần bật `ValidationPipe` giống `main.ts`)
- **Acceptance criteria hiện hành:** Payload đúng 200; sai/array restrictions cũ 400; dùng configureApp/ValidationPipe; SDK thật gọi server giả; Swagger schema và không trả health text được kiểm.
- **Evidence / lý do chưa đạt:** Backend E2E audit pass.
- **Source / tests:** [generate-plan.e2e-spec.ts](../backend_api/test/generate-plan.e2e-spec.ts); [app.setup.ts](../backend_api/src/app.setup.ts).
- **Spec, subtasks và cổng kiểm:** [2/F04](superpowers/plans/phase-2-backend-tests/specs/F04-e2e-generate-plan.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-2-5"></a>

### Task 2.5 — SDK thật với Gemini giả

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3)
- **Phạm vi gốc:** *(bổ sung, quyết định Q1)* Test `GeminiService` với SDK `@google/genai` thật trỏ vào server Gemini giả cục bộ (`GEMINI_BASE_URL`): hết giờ, khoá sai, không tự gọi lại, lỗi JSON không lộ nội dung
- **Acceptance criteria hiện hành:** GEMINI_BASE_URL route SDK thật tới server local; timeout/key/500/JSON lỗi có test; SDK không tự retry; log không lộ dữ liệu.
- **Evidence / lý do chưa đạt:** Unit audit pass. Task bổ sung được giữ nguyên từ PLAN phụ.
- **Source / tests:** [gemini.service.spec.ts](../backend_api/src/plan/gemini.service.spec.ts); [fake-gemini-server.ts](../backend_api/test/fake-gemini-server.ts).
- **Spec, subtasks và cổng kiểm:** [2/F02](superpowers/plans/phase-2-backend-tests/specs/F02-gemini-service-real-sdk.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-2-6"></a>

### Task 2.6 — CI backend Node matrix và AI typecheck

- [ ] **Status: UNVERIFIED**
- **Dependency:** [2.1](#task-2-1), [2.2](#task-2-2), [2.3](#task-2-3), [2.4](#task-2-4), [2.5](#task-2-5)
- **Phạm vi gốc:** *(bổ sung, quyết định Q2)* GitHub Actions: build + unit + e2e backend trên Node 24 và 26, kiểm kiểu `ai_workspace`, mỗi lần push
- **Acceptance criteria hiện hành:** Push/PR đúng path chạy build/unit/E2E trên Node 24 và 26, typecheck AI workspace; run của đúng commit hoàn tất success; docs-only không kích hoạt backend job.
- **Evidence / lý do chưa đạt:** Workflow có và AI typecheck local audit pass; chưa có URL/result CI run cho commit hiện tại.
- **Source / tests:** [backend.yml](../.github/workflows/backend.yml); [package.json](../ai_workspace/package.json).
- **Spec, subtasks và cổng kiểm:** [2/F05](superpowers/plans/phase-2-backend-tests/specs/F05-github-actions.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-3-1"></a>

### Task 3.1 — TypeORM và SQLite driver

- [x] **Status: DONE**
- **Dependency:** [2.4](#task-2-4)
- **Phạm vi gốc:** Thêm TypeORM + SQLite: `better-sqlite3@12` (TypeORM 1.1 không còn driver `sqlite3`, chỉ nhận `better-sqlite3 ^12`; install script được duyệt tường minh trong `package.json`). Entity chỉ dùng kiểu cột có ở cả SQLite và Postgres
- **Acceptance criteria hiện hành:** TypeORM/better-sqlite3@12 được cấu hình; install-script allowance; entity column types tương thích SQLite/Postgres.
- **Evidence / lý do chưa đạt:** Database unit/E2E audit pass.
- **Source / tests:** [package.json](../backend_api/package.json); [data-source-options.ts](../backend_api/src/database/data-source-options.ts).
- **Spec, subtasks và cổng kiểm:** [3/F01](superpowers/plans/phase-3-auth-history/specs/F01-database.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-3-2"></a>

### Task 3.2 — Entities và migrations

- [x] **Status: DONE**
- **Dependency:** [3.1](#task-3-1)
- **Phạm vi gốc:** Entity `User` (google_sub, email, name) và `PlanRecord` (user, plan_json, target_calories, created_at); bảng tạo bằng migration chạy khi khởi động, không `synchronize`; file DB nằm trong `.gitignore`
- **Acceptance criteria hiện hành:** User/PlanRecord đúng trường; migration startup, synchronize false, FK cascade, schema diff sạch; DB ignored; ESM relations không làm build boot lỗi.
- **Evidence / lý do chưa đạt:** Migration tests và smoke bản build audit pass.
- **Source / tests:** [migrations.spec.ts](../backend_api/src/database/migrations.spec.ts); [plan-record.entity.ts](../backend_api/src/database/entities/plan-record.entity.ts); [.gitignore](../backend_api/.gitignore).
- **Spec, subtasks và cổng kiểm:** [3/F01](superpowers/plans/phase-3-auth-history/specs/F01-database.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-3-3"></a>

### Task 3.3 — Backend Google/mock auth và JWT

- [x] **Status: DONE**
- **Dependency:** [3.2](#task-3-2)
- **Phạm vi gốc:** `AuthModule`: `POST /api/v1/auth/google`, hai chế độ `AUTH_MODE=mock | google`, JWT hết hạn sau 7 ngày. Chế độ google bắt buộc có `GOOGLE_CLIENT_ID` và `JWT_SECRET` ≥ 32 ký tự (thiếu thì không cho khởi động); chế độ mock được dùng secret mặc định kèm cảnh báo, và bị chặn khi `NODE_ENV=production` trừ khi `ALLOW_MOCK_AUTH=true`. `/health` báo thêm `auth_mode`
- **Acceptance criteria hiện hành:** Hai mode; Google verify signature/audience/issuer/expiry/email; JWT mặc định 7d; google cần client ID/secret ≥32; production mock bị chặn trừ override chủ đích; health auth_mode.
- **Evidence / lý do chưa đạt:** Auth unit/E2E audit pass bằng Google tokens ký offline; OAuth live chưa nghiệm thu ở 9.4.
- **Source / tests:** [auth-config.ts](../backend_api/src/auth/auth-config.ts); [id-token-verifier.spec.ts](../backend_api/src/auth/id-token-verifier.spec.ts); [auth.service.spec.ts](../backend_api/src/auth/auth.service.spec.ts).
- **Spec, subtasks và cổng kiểm:** [3/F02](superpowers/plans/phase-3-auth-history/specs/F02-auth.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-3-4"></a>

### Task 3.4 — JWT guards

- [x] **Status: DONE**
- **Dependency:** [3.3](#task-3-3)
- **Phạm vi gốc:** Guard: bắt buộc đăng nhập cho API lịch sử; tuỳ chọn cho `generate-plan` (token hợp lệ → lưu lịch sử; token sai → 401; không có token → chạy như cũ, không lưu)
- **Acceptance criteria hiện hành:** History bắt buộc auth; generate tùy chọn; token đúng lưu, sai 401, không token chạy guest; account đã xóa bị từ chối.
- **Evidence / lý do chưa đạt:** Guard và HTTP tests audit pass.
- **Source / tests:** [jwt-auth.guard.spec.ts](../backend_api/src/auth/jwt-auth.guard.spec.ts); [history.e2e-spec.ts](../backend_api/test/history.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [3/F02](superpowers/plans/phase-3-auth-history/specs/F02-auth.md); [3/F03](superpowers/plans/phase-3-auth-history/specs/F03-history.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-3-5"></a>

### Task 3.5 — History list/detail và ownership

- [x] **Status: DONE**
- **Dependency:** [3.2](#task-3-2), [3.4](#task-3-4)
- **Phạm vi gốc:** `GET /api/v1/plans/history` (50 plan mới nhất) và `GET /api/v1/plans/history/:id` (plan của người khác → 404)
- **Acceptance criteria hiện hành:** 50 plan mới nhất; ID hợp lệ; không tiết lộ plan user khác (404); detail đúng plan; kiểm persistence sau restart khi nghiệm thu storage thật.
- **Evidence / lý do chưa đạt:** List/detail/ownership unit/E2E và smoke audit pass; storage deployment/restart thuộc 9.1/9.4.
- **Source / tests:** [history.service.ts](../backend_api/src/history/history.service.ts); [history.e2e-spec.ts](../backend_api/test/history.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [3/F03](superpowers/plans/phase-3-auth-history/specs/F03-history.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-3-6"></a>

### Task 3.6 — Auth/history/database tests

- [x] **Status: DONE**
- **Dependency:** [3.3](#task-3-3), [3.4](#task-3-4), [3.5](#task-3-5)
- **Phạm vi gốc:** Test: auth hai chế độ (Google test bằng khoá RSA tự tạo, không gọi mạng), guard, quyền sở hữu plan, migration khớp entity, E2E: đăng nhập giả lập → tạo plan → xem lịch sử
- **Acceptance criteria hiện hành:** Auth hai mode offline, guard, owner, schema migration; HTTP login mock → generate → history; test DB RAM và env được khôi phục.
- **Evidence / lý do chưa đạt:** Unit/E2E audit pass; không chạy Google/Gemini live.
- **Source / tests:** [auth.e2e-spec.ts](../backend_api/test/auth.e2e-spec.ts); [history.e2e-spec.ts](../backend_api/test/history.e2e-spec.ts); [test-app.ts](../backend_api/test/test-app.ts).
- **Spec, subtasks và cổng kiểm:** [3/F03](superpowers/plans/phase-3-auth-history/specs/F03-history.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-3-7"></a>

### Task 3.7 — Backend Google setup docs

- [x] **Status: DONE**
- **Dependency:** [3.3](#task-3-3)
- **Phạm vi gốc:** `SETUP_CREDENTIALS.md` — phần **Google Sign-In (backend)**: tạo OAuth Client ID trên Google Cloud Console, điền `.env`, kiểm tra qua `/health`
- **Acceptance criteria hiện hành:** OAuth Client ID/env/health/diagnosis được hướng dẫn; Flutter configuration được tách sang 8.4.
- **Evidence / lý do chưa đạt:** Phần backend đã có; phần Flutter còn chưa làm.
- **Source / tests:** [SETUP_CREDENTIALS.md](SETUP_CREDENTIALS.md).
- **Spec, subtasks và cổng kiểm:** [3/F05](superpowers/plans/phase-3-auth-history/specs/F05-docs.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-3-8"></a>

### Task 3.8 — Backend xóa tài khoản

- [x] **Status: DONE**
- **Dependency:** [3.2](#task-3-2), [3.4](#task-3-4)
- **Phạm vi gốc:** *(bổ sung, quyết định Q4)* `DELETE /api/v1/me`: xoá tài khoản cùng toàn bộ lịch sử (BRD FR-6.4, v2.4.0)
- **Acceptance criteria hiện hành:** DELETE /api/v1/me authenticated trả 204; account và history bị xóa cascade; token cũ bị từ chối.
- **Evidence / lý do chưa đạt:** Backend tests audit pass; UI deletion chưa nối ở N07.
- **Source / tests:** [auth.controller.ts](../backend_api/src/auth/auth.controller.ts); [auth.e2e-spec.ts](../backend_api/test/auth.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [3/F02](superpowers/plans/phase-3-auth-history/specs/F02-auth.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-3-9"></a>

### Task 3.9 — Build smoke và CI

- [ ] **Status: PARTIAL**
- **Dependency:** [3.6](#task-3-6), [2.6](#task-2-6)
- **Phạm vi gốc:** *(bổ sung khi lập plan)* Smoke test chạy bản build (`npm run test:smoke`) trong CI — bắt lỗi import vòng giữa entity mà vitest không thấy
- **Acceptance criteria hiện hành:** Smoke boot dist/main.js, kiểm assets/ESM và HTTP; workflow chạy smoke trên Node matrix; có run success của đúng commit.
- **Evidence / lý do chưa đạt:** Smoke local audit pass; CI run chưa được xác minh. Không chạy mutation sửa source trong consolidation.
- **Source / tests:** [smoke-test.mjs](../backend_api/scripts/smoke-test.mjs); [backend.yml](../.github/workflows/backend.yml).
- **Spec, subtasks và cổng kiểm:** [3/F04](superpowers/plans/phase-3-auth-history/specs/F04-smoke-ci.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-4-1"></a>

### Task 4.1 — Restriction matcher và fallback filtering

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3), [2.5](#task-2-5)
- **Phạm vi gốc:** Bộ khớp từ khoá cho chế độ giả lập (`data/restriction-keywords.json`, `restriction-matcher.ts`): nhận ra dị ứng/chấn thương phổ biến, gõ có dấu hay không dấu; phần không nhận ra → cảnh báo chung, không nhắc lại chữ người dùng (D4). Lọc luôn thực đơn mẫu của `generate-plan` và kiểm lại mọi kết quả Gemini
- **Acceptance criteria hiện hành:** Keyword có/không dấu, không nhầm cá/cà; lọc sample và kiểm Gemini; unknown warning chung không echo user; pools validate startup.
- **Evidence / lý do chưa đạt:** Unit/E2E audit pass.
- **Source / tests:** [restriction-matcher.spec.ts](../backend_api/src/plan/restriction-matcher.spec.ts); [restriction-filter.spec.ts](../backend_api/src/plan/restriction-filter.spec.ts); [swap-pools.spec.ts](../backend_api/src/plan/swap-pools.spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F01](superpowers/plans/phase-4-swap-feedback/specs/F01-calories-restrictions.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-4-2"></a>

### Task 4.2 — Backend meal swap

- [x] **Status: DONE**
- **Dependency:** [4.1](#task-4-1), [4.7](#task-4-7)
- **Phạm vi gốc:** `POST /api/v1/meals/swap`: Gemini sinh món thay thế lệch không quá ±10% calo, tránh các hạn chế người dùng nhập, không trùng món đã có trong plan; backend tính lại toàn bộ `grocery_list` (#7). Fallback: kho món Việt `data/swap-meals.json` lọc bằng bộ khớp từ khoá, nhân khẩu phần về đúng calo món cũ; hết món phù hợp → 422
- **Acceptance criteria hiện hành:** Gemini trước/fallback pool; đúng meal type; calories ±10%, không dị ứng/trùng; recompute grocery; thiếu candidate 422; nguyên plan giữ khi lỗi.
- **Evidence / lý do chưa đạt:** Unit/E2E/smoke audit pass.
- **Source / tests:** [meal-swap.service.spec.ts](../backend_api/src/plan/adjust/meal-swap.service.spec.ts); [adjust.e2e-spec.ts](../backend_api/test/adjust.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F03](superpowers/plans/phase-4-swap-feedback/specs/F03-meal-swap.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-4-3"></a>

### Task 4.3 — Backend exercise swap

- [x] **Status: DONE**
- **Dependency:** [4.1](#task-4-1)
- **Phạm vi gốc:** `POST /api/v1/exercises/swap` *(quyết định Q2: Gemini trước)*: động tác nhẹ hơn, cùng nhóm cơ, tránh chấn thương — kết quả Gemini phải qua điều kiện đo được (số hiệp không tăng, không thêm kiểu tải). Fallback: `data/swap-exercises.json` có mức khó 1–3; đã nhẹ nhất → 422
- **Acceptance criteria hiện hành:** Cùng nhóm cơ, sets không tăng, không thêm load tags, tránh injury/profile limit; fallback mức nhẹ hơn; không có 422.
- **Evidence / lý do chưa đạt:** Unit/E2E/smoke audit pass.
- **Source / tests:** [exercise-swap.service.spec.ts](../backend_api/src/plan/adjust/exercise-swap.service.spec.ts); [adjust.e2e-spec.ts](../backend_api/test/adjust.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F04](superpowers/plans/phase-4-swap-feedback/specs/F04-exercise-swap.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-4-4"></a>

### Task 4.4 — Backend feedback

- [x] **Status: DONE**
- **Dependency:** [4.1](#task-4-1), [4.7](#task-4-7)
- **Phạm vi gốc:** `POST /api/v1/feedback` theo D2: bài tập điều chỉnh bằng quy tắc cố định; món ăn nhờ Gemini *(quyết định Q3)* — ăn nhiều → ngày kế tiếp ~90% mục tiêu, ăn ít → giữ mục tiêu, không có key thì giữ nguyên món kèm cảnh báo. Dấu hiệu nguy hiểm → `safety_warning` và ngày kế tiếp chỉ nghỉ hoặc đi bộ nhẹ. **Không bao giờ hạ calo mục tiêu xuống dưới BMR.** Ngày 3 → plan mới
- **Acceptance criteria hiện hành:** D2 ba câu; workout deterministic; ăn nhiều khoảng 90%, ăn ít giữ target, không dưới BMR; mock warning; danger nghỉ/khuyến cáo/không Gemini; ngày 3 plan mới.
- **Evidence / lý do chưa đạt:** Unit/E2E/smoke audit pass; UI riêng ở 7.3.
- **Source / tests:** [feedback.service.spec.ts](../backend_api/src/plan/adjust/feedback.service.spec.ts); [workout-rules.spec.ts](../backend_api/src/plan/adjust/workout-rules.spec.ts); [adjust.e2e-spec.ts](../backend_api/test/adjust.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F05](superpowers/plans/phase-4-swap-feedback/specs/F05-feedback.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-4-5"></a>

### Task 4.5 — Adjustment HTTP/SDK/smoke tests

- [x] **Status: DONE**
- **Dependency:** [4.2](#task-4-2), [4.3](#task-4-3), [4.4](#task-4-4), [4.8](#task-4-8)
- **Phạm vi gốc:** Test cả 4 phần trên, chạy được khi không có key; dấu hiệu nguy hiểm có test riêng. E2E qua HTTP thật, một đường qua SDK Gemini thật + server giả; smoke test gọi 3 endpoint trên bản build
- **Acceptance criteria hiện hành:** Cả ba endpoints, guest/auth, lỗi 400/401/409/422, owner/history, danger/day3; SDK thật server giả; typecheck/build/lint/unit/E2E/smoke pass.
- **Evidence / lý do chưa đạt:** Các cổng local audit pass.
- **Source / tests:** [adjust.e2e-spec.ts](../backend_api/test/adjust.e2e-spec.ts); [smoke-test.mjs](../backend_api/scripts/smoke-test.mjs).
- **Spec, subtasks và cổng kiểm:** [4/F06](superpowers/plans/phase-4-swap-feedback/specs/F06-endpoints-e2e.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-4-6"></a>

### Task 4.6 — responseSchema tùy chọn

- [ ] **Status: NOT STARTED**
- **Dependency:** [4.9](#task-4-9)
- **Phạm vi gốc:** *(Tuỳ chọn, để sau)* Dùng `responseSchema` của Gemini để ép JSON đúng cấu trúc ngay từ API — cần khoá thật để đo nó giảm lỗi bao nhiêu (thử bằng `ai_workspace/`); bước kiểm hợp đồng vẫn phải giữ
- **Acceptance criteria hiện hành:** Nếu chọn làm: đo với key thật khả năng giảm lỗi JSON; giữ contract validation hiện có; không chặn MVP.
- **Evidence / lý do chưa đạt:** Không có responseSchema; scope tùy chọn, chưa triển khai.
- **Source / tests:** [gemini.service.ts](../backend_api/src/plan/gemini.service.ts).

<a id="task-4-7"></a>

### Task 4.7 — Calorie bounds và sample scaling

- [x] **Status: DONE**
- **Dependency:** [1.3](#task-1-3), [2.1](#task-2-1)
- **Phạm vi gốc:** *(bổ sung, quyết định Q1)* Khoảng calo theo tỉ lệ mục tiêu, kiểm tổng calo ngày (≥ BMR), nhân khẩu phần thực đơn mẫu cho khớp mục tiêu — sửa lỗi thực đơn thấp hơn BMR của nhiều người (BRD NFR-4, v2.5.0)
- **Acceptance criteria hiện hành:** Breakfast 15–35%, lunch/dinner 25–45%; ngày max(85% target,BMR) đến 110%; scale calorie/macro/ingredients; sample ±3 kcal cho ma trận/extremes.
- **Evidence / lý do chưa đạt:** Unit/E2E audit pass; macro balancing constraint #33 cũng có tests.
- **Source / tests:** [plan-validation.ts](../backend_api/src/plan/plan-validation.ts); [sample-plan.spec.ts](../backend_api/src/plan/sample-plan.spec.ts); [meal-scaling.spec.ts](../backend_api/src/plan/meal-scaling.spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F01](superpowers/plans/phase-4-swap-feedback/specs/F01-calories-restrictions.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-4-8"></a>

### Task 4.8 — Adjustment lưu history

- [x] **Status: DONE**
- **Dependency:** [3.5](#task-3-5), [4.1](#task-4-1)
- **Phạm vi gốc:** *(bổ sung, quyết định Q4)* Đã đăng nhập: đổi món, đổi bài, feedback cập nhật plan đã lưu; plan từ feedback ngày 3 lưu mới
- **Acceptance criteria hiện hành:** Authenticated cập nhật đúng owner; không chạm plan user khác; day3 lưu mới; DB lỗi giữ response kèm warning.
- **Evidence / lý do chưa đạt:** Unit/E2E/smoke audit pass.
- **Source / tests:** [history.service.spec.ts](../backend_api/src/history/history.service.spec.ts); [adjust.e2e-spec.ts](../backend_api/test/adjust.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [4/F02](superpowers/plans/phase-4-swap-feedback/specs/F02-client-plan.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-4-9"></a>

### Task 4.9 — Tuning và đo Gemini thật

- [ ] **Status: PARTIAL**
- **Dependency:** [4.1](#task-4-1), [4.7](#task-4-7)
- **Phạm vi gốc:** *(bổ sung sau khi thử bằng khoá thật)* Đo Gemini thật (`npm run measure:gemini`): để model tự suy nghĩ thì tạo plan mất 37–42 s, vượt giới hạn 15 s nên luôn rơi về thực đơn mẫu. Sửa: prompt ghi rõ danh sách nguyên liệu/động tác backend sẽ loại; `GEMINI_THINKING` (mặc định `off`, 8–13 s); giới hạn 20 s mỗi lần, 40 s tổng; model mặc định `gemini-3.5-flash` (3.8 liên tục quá tải). Gói miễn phí: 20 lần gọi/ngày mỗi model (BRD v2.5.1)
- **Acceptance criteria hiện hành:** Prompt ghi rõ loại trừ; thinking off mặc định; 20s/call,40s tổng; default model 3.5; phép đo live lưu model/config/latency/violations/fallback, workspace tương ứng.
- **Evidence / lý do chưa đạt:** Backend tuning có; workspace lệch; audit không gọi key thật. Số quota/latency ghi cũ chỉ là dữ liệu lịch sử, không cam kết hiện tại. Kiểm tra 14/10/2026: backend không có key trong process hoặc .env; live vẫn UNVERIFIED. Tests lỗi SDK/fallback pass; model mặc định đã deprecated theo Google. Xem [kiểm chứng Gemini](#gemini-verification).
- **Source / tests:** [gemini.service.ts](../backend_api/src/plan/gemini.service.ts); [measure-gemini.mjs](../backend_api/scripts/measure-gemini.mjs); [generate-plan-experiment.ts](../ai_workspace/generate-plan-experiment.ts).

<a id="task-5-1"></a>

### Task 5.1 — Flutter packages

- [x] **Status: DONE**
- **Dependency:** [1.2](#task-1-2)
- **Phạm vi gốc:** Thêm package `http`, `provider`, `shared_preferences`
- **Acceptance criteria hiện hành:** http/provider/shared_preferences có trong pubspec/lock; app biên dịch và tests dùng được.
- **Evidence / lý do chưa đạt:** Flutter tests, APK debug/web build audit pass.
- **Source / tests:** [pubspec.yaml](../frontend_app/pubspec.yaml); [pubspec.lock](../frontend_app/pubspec.lock).
- **Spec, subtasks và cổng kiểm:** [5/F02](superpowers/plans/phase-5-frontend-foundation/specs/F02-packages-platform.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-5-2"></a>

### Task 5.2 — API URL và quyền mạng

- [x] **Status: DONE**
- **Dependency:** [5.1](#task-5-1)
- **Phạm vi gốc:** Địa chỉ backend qua `--dart-define=API_BASE_URL` — web: `localhost`; máy ảo Android: `10.0.2.2`; điện thoại thật: IP mạng LAN của máy chạy backend (`lib/config/api_config.dart`). Quyền mạng Android (release), iOS, macOS
- **Acceptance criteria hiện hành:** API_BASE_URL override; Android emulator 10.0.2.2, web localhost, phone LAN; INTERNET main; debug cleartext; iOS local networking/macOS network.client; configuration tests pass.
- **Evidence / lý do chưa đạt:** Config tests và APK build audit pass; quyền config không thay nghiệm thu thiết bị hay HTTPS release.
- **Source / tests:** [api_config.dart](../frontend_app/lib/config/api_config.dart); [api_config_test.dart](../frontend_app/test/config/api_config_test.dart); [AndroidManifest.xml](../frontend_app/android/app/src/main/AndroidManifest.xml).
- **Spec, subtasks và cổng kiểm:** [5/F02](superpowers/plans/phase-5-frontend-foundation/specs/F02-packages-platform.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-5-3"></a>

### Task 5.3 — Dart API models

- [x] **Status: DONE**
- **Dependency:** [5.1](#task-5-1), [1.2](#task-1-2)
- **Phạm vi gốc:** Model Dart có `fromJson`/`toJson` theo BRD mục 6 (`lib/models/api/`), đi vòng tròn đúng JSON server trả. Màn hình chuyển sang model mới và xoá view-model cũ `meal_plan.dart` ở 6.7
- **Acceptance criteria hiện hành:** fromJson/toJson round-trip nguyên JSON/numbers; missing/type/unknown codes fail; fixtures plan/feedback/auth/history/health; UI migration thuộc 6.7.
- **Evidence / lý do chưa đạt:** Model tests audit pass; fixture mới từ HTTP chưa được đảm bảo ở 5.8.
- **Source / tests:** [contract_test.dart](../frontend_app/test/models/contract_test.dart); [meal_plan.dart](../frontend_app/lib/models/api/meal_plan.dart).
- **Spec, subtasks và cổng kiểm:** [5/F03](superpowers/plans/phase-5-frontend-foundation/specs/F03-dart-models.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-5-4"></a>

### Task 5.4 — ApiClient

- [x] **Status: DONE**
- **Dependency:** [5.2](#task-5-2), [5.3](#task-5-3)
- **Phạm vi gốc:** `ApiClient` (`lib/services/`): gọi mọi endpoint; lỗi → `ApiException` có câu tiếng Việt, không crash (NFR-2); timeout 60 s cho request có Gemini
- **Acceptance criteria hiện hành:** Chín endpoints; injected HTTP client; UTF8 bodyBytes; Vietnamese ApiException; 60s Gemini/15s còn lại; parse errors captured; 401 callback và login không token cũ; không log body.
- **Evidence / lý do chưa đạt:** Service tests audit pass; chưa chứng minh UI gọi API.
- **Source / tests:** [api_client_test.dart](../frontend_app/test/services/api_client_test.dart); [api_client.dart](../frontend_app/lib/services/api_client.dart).
- **Spec, subtasks và cổng kiểm:** [5/F04](superpowers/plans/phase-5-frontend-foundation/specs/F04-api-client.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-5-5"></a>

### Task 5.5 — Plan/Auth providers và persistence

- [x] **Status: DONE**
- **Dependency:** [5.4](#task-5-4)
- **Phạm vi gốc:** `PlanProvider` (plan + hồ sơ, lưu `shared_preferences`) và `AuthProvider` (JWT; 401 → đăng xuất)
- **Acceptance criteria hiện hành:** Save/restore plan/profile/JWT; corrupt storage xử lý; busy lock; 401 signout; swap/feedback whole plan; pending profile riêng; không log health.
- **Evidence / lý do chưa đạt:** Provider tests audit pass; UI integration còn thiếu.
- **Source / tests:** [plan_provider_test.dart](../frontend_app/test/providers/plan_provider_test.dart); [auth_provider_test.dart](../frontend_app/test/providers/auth_provider_test.dart).
- **Spec, subtasks và cổng kiểm:** [5/F05](superpowers/plans/phase-5-frontend-foundation/specs/F05-providers.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-5-6"></a>

### Task 5.6 — Startup theo saved plan và widget test

- [x] **Status: DONE**
- **Dependency:** [5.5](#task-5-5)
- **Phạm vi gốc:** `MainShell`: chưa có plan → mở Onboarding, đã có → Dashboard; viết lại `widget_test.dart`
- **Acceptance criteria hiện hành:** No plan → onboarding; valid saved plan → dashboard offline; corrupt plan không crash; widget test xác minh không gọi mạng lúc mở.
- **Evidence:** N04 (31/10/2026): implementation và unit/widget tests đạt criteria hiện hành; analyze sạch, 158 PASS/2 SKIP, APK debug PASS. Chi tiết/giới hạn Android ở nhật ký N04 đầu tài liệu.
- **Source / tests:** [main.dart](../frontend_app/lib/main.dart); [app_harness.dart](../frontend_app/test/app_harness.dart).
- **Spec, subtasks và cổng kiểm:** [5/F06](superpowers/plans/phase-5-frontend-foundation/specs/F06-main-shell-ci.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-5-7"></a>

### Task 5.7 — CORS

- [x] **Status: DONE**
- **Dependency:** [2.4](#task-2-4)
- **Phạm vi gốc:** Bật CORS trong `configureApp()` qua `CORS_ORIGINS` (trống khi phát triển → `localhost`/`127.0.0.1` mọi cổng; trống khi deploy → tắt), cho phép header `Authorization`
- **Acceptance criteria hiện hành:** Dev empty localhost/127.0.0.1; production empty off; origin allowlist validated; GET/POST/DELETE, Authorization/Content-Type; configureApp chung.
- **Evidence / lý do chưa đạt:** CORS unit/E2E audit pass.
- **Source / tests:** [cors-options.spec.ts](../backend_api/src/cors-options.spec.ts); [cors.e2e-spec.ts](../backend_api/test/cors.e2e-spec.ts).
- **Spec, subtasks và cổng kiểm:** [5/F01](superpowers/plans/phase-5-frontend-foundation/specs/F01-backend-cors-fixtures.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-5-8"></a>

### Task 5.8 — Fixture exporter và contract gate

- [ ] **Status: BLOCKED**
- **Dependency:** [3.6](#task-3-6), [4.5](#task-4-5), [5.7](#task-5-7)
- **Phạm vi gốc:** *(bổ sung, quyết định Q1)* Fixture hợp đồng: backend xuất 14 JSON thật vào `frontend_app/test/fixtures/` (`npm run fixtures:update`), test hai phía cùng dùng
- **Acceptance criteria hiện hành:** Xuất 14 fixtures nền + restriction_labels bổ sung; HTTP response normalized/deterministic; hai lần xuất không đổi; sửa fixture làm backend E2E fail; Flutter dùng cùng fixtures.
- **Evidence / lý do chưa đạt:** fixtures:update trỏ test/contract-fixtures.e2e-spec.ts không tồn tại; 15 JSON đã có nhưng không có current response comparison/exporter.
- **Source / tests:** [package.json](../backend_api/package.json); [fixture_loader.dart](../frontend_app/test/fixture_loader.dart).
- **Spec, subtasks và cổng kiểm:** [5/F01](superpowers/plans/phase-5-frontend-foundation/specs/F01-backend-cors-fixtures.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-5-9"></a>

### Task 5.9 — Flutter CI

- [ ] **Status: UNVERIFIED**
- **Dependency:** [5.6](#task-5-6), [5.8](#task-5-8)
- **Phạm vi gốc:** *(bổ sung, quyết định Q4)* CI Flutter: `flutter analyze` + `flutter test` (`.github/workflows/frontend.yml`)
- **Acceptance criteria hiện hành:** Workflow analyze/test trên Flutter đã ghim; run của đúng commit success; không gọi dịch vụ thật.
- **Evidence / lý do chưa đạt:** Workflow có; local analyze/64 tests audit pass; remote run chưa xác minh.
- **Source / tests:** [frontend.yml](../.github/workflows/frontend.yml).
- **Spec, subtasks và cổng kiểm:** [5/F06](superpowers/plans/phase-5-frontend-foundation/specs/F06-main-shell-ci.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-5-10"></a>

### Task 5.10 — Android smoke và offline restoration

- [ ] **Status: PARTIAL**
- **Dependency:** [5.2](#task-5-2), [5.5](#task-5-5), [5.6](#task-5-6)
- **Phạm vi gốc:** *(bổ sung sau khi kiểm lại)* Chạy trên máy ảo Android 16: sửa `compileSdk` 34 → 36 (APK không build được sau khi thêm `shared_preferences`); `integration_test/backend_smoke_test.dart` gọi backend thật từ máy ảo (chạy tay); mở app có plan đã lưu → Dashboard kể cả khi backend tắt, plan hỏng → Onboarding
- **Acceptance criteria hiện hành:** compileSdk≥36; APK debug/release; real backend smoke từ emulator; save/restore khi backend off; corrupt plan → onboarding; integration test an toàn mock.
- **Evidence:** N04 startup/offline restoration unit/widget pass, compileSdk36/APK debug pass; real backend smoke từ emulator và release/device acceptance còn UNVERIFIED. integration_test/backend_smoke_test.dart chưa có.
- **Source / tests:** [build.gradle.kts](../frontend_app/android/app/build.gradle.kts); [main.dart](../frontend_app/lib/main.dart).

<a id="task-6-1"></a>

### Task 6.1 — Onboarding ba bước, D5 và safety

- [x] **Status: DONE**
- **Dependency:** [5.5](#task-5-5), [6.9](#task-6-9), [6.10](#task-6-10)
- **Phạm vi gốc:** Onboarding chia 3 bước (D6-B2): thêm tuổi (≥ 18), giới tính, mức vận động (FR-1.1, FR-1.2 — backend bắt buộc nhưng giao diện chưa có); khoá "Giảm mỡ" khi BMI < 18,5 hoặc mang thai / cho con bú (D6-A1, A3); nhập hạn chế theo D5 + dòng khuyến cáo y tế (D4); validate cùng giới hạn với backend, báo lỗi ngay khi nhập. Bỏ giá trị điền sẵn 168 / 62; nút tiếp tục phải mang hồ sơ đi (hiện `onNext` không truyền dữ liệu nào)
- **Acceptance criteria hiện hành:** Body → goal/activity → restrictions, progress/bottom button/back; age18–100,height100–250,weight30–250; blank không dùng fallback; BMI<18.5/pregnancy khóa cut; nữ pregnancy; D5 toggle off/multi/Other≤300; disclaimer; gửi Profile.
- **Evidence / lý do chưa đạt:** N02 ngày 14/10/2026: ba bước, dữ liệu raw không fallback, validators profile_rules, pregnancy/rawBMI/cut, D5 và counter300, back/forward/retry giữ dữ liệu, guard trước request. Unit/widget tests trên viewport Pixel2 và live HTTP, analyze, APK debug đều pass; xem [N02](#n02). Device manual N02 còn UNVERIFIED, không đồng nghĩa integration/device milestone6.7 đạt.
- **Source / tests:** [basic_info_screen.dart](../frontend_app/lib/screens/onboarding/basic_info_screen.dart); [goal_screen.dart](../frontend_app/lib/screens/onboarding/goal_screen.dart); [restrictions_screen.dart](../frontend_app/lib/screens/onboarding/restrictions_screen.dart); [validation tests](../frontend_app/test/providers/onboarding_validation_test.dart); [widget tests N02](../frontend_app/test/screens/onboarding_n02_test.dart).
- **Spec, subtasks và cổng kiểm:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-6-2"></a>

### Task 6.2 — Profile edit và regenerate

- [x] **Status: DONE**
- **Dependency:** [6.1](#task-6-1), [5.5](#task-5-5)
- **Phạm vi gốc:** Tab "Cá nhân": xem và sửa hồ sơ, lưu trên máy (FR-1.6); sửa xong thì gợi ý tạo lại plan (hiện ghi cứng "168 cm • 62 kg • Giảm mỡ", không theo Onboarding)
- **Acceptance criteria hiện hành:** Xem/sửa mọi field và D5 như onboarding; save local draft riêng; gợi ý regenerate; swap/feedback vẫn dùng profile của plan tới khi tạo lại.
- **Evidence:** N04 (31/10/2026): implementation và unit/widget tests đạt criteria hiện hành; analyze sạch, 158 PASS/2 SKIP, APK debug PASS. Chi tiết/giới hạn Android ở nhật ký N04 đầu tài liệu.
- **Source / tests:** [edit_profile_sheet.dart](../frontend_app/lib/screens/profile/edit_profile_sheet.dart); [plan_provider.dart](../frontend_app/lib/providers/plan_provider.dart).
- **Spec, subtasks và cổng kiểm:** [6/F03](superpowers/plans/phase-6-connect-mvp/specs/F03-app-logic.md); [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-6-3"></a>

### Task 6.3 — Loading tạo plan thật

- [x] **Status: DONE**
- **Dependency:** [6.1](#task-6-1), [5.4](#task-5-4)
- **Phạm vi gốc:** Loading: gọi API thật thay cho bộ đếm giờ giả; lỗi → nút thử lại (NFR-1, NFR-2). Có Gemini thì chờ thật khoảng 10–15 giây, tối đa khoảng 40 giây — câu chờ và thanh tiến trình phải hợp với khoảng này; HTTP client của app để timeout dài hơn 40 giây. Bỏ nút "Xem trước kế hoạch ngay" và các câu chờ bịa số liệu ("Cân đối Macro: 140g Carbs, 65g Protein…", "phù hợp ngân sách")
- **Acceptance criteria hiện hành:** Gọi PlanProvider.generate(Profile); success mới mở home; error/retry; timeout app>40s; progress không bịa dữ liệu hoặc skip kế hoạch.
- **Evidence / lý do chưa đạt:** N01 ngày 14/10/2026: request thật qua PlanProvider.generate; chờ parse/lưu rồi mở kết quả, không timer hoặc client mock fallback; lỗi network/timeout/400/500/JSON sai có retry. Widget tests, HTTP backend local thật, analyze và APK debug pass; xem [N01](#n01).
- **Source / tests:** [generating_plan_screen.dart](../frontend_app/lib/screens/onboarding/generating_plan_screen.dart); [plan_provider.dart](../frontend_app/lib/providers/plan_provider.dart); [widget tests N01](../frontend_app/test/screens/generating_plan_screen_test.dart); [HTTP live tests N01](../frontend_app/test/services/n01_backend_live_test.dart).
- **Spec, subtasks và cổng kiểm:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-6-4"></a>

### Task 6.4 — Dashboard/Plan dữ liệu thật

- [x] **Status: DONE**
- **Dependency:** [6.3](#task-6-3), [5.3](#task-5-3), [6.11](#task-6-11)
- **Phạm vi gốc:** Dashboard: hiển thị đủ 3 ngày, 3 bữa/ngày, bài tập, calo và macro (FR-2.3); hiện cảnh báo khi chế độ giả lập chưa kiểm tra được hết hạn chế. Thấy khi chạy trên máy ảo (giai đoạn 5): ngày ghi cứng "Thứ Ba, 15/9/2026"; thiếu bữa sáng; bộ chọn S1–S5 là 5 ngày và bấm không đổi nội dung; món/động tác không theo hạn chế đã chọn (vẫn có cá khi dị ứng hải sản); chưa hiện tổng calo và macro mỗi ngày (FR-2.3) — widget `macro_ring.dart` có sẵn nhưng chưa dùng; nhãn "Dễ", "Không tạ", chữ "T", "3 ngày" ghi cứng; hiện `warnings` của plan
- **Acceptance criteria hiện hành:** Ba ngày×ba bữa, workout/calories/macros đầy đủ; chọn ngày đổi nội dung; labels theo response; warnings/disclaimer/source; không hardcoded date/profile/calorie.
- **Evidence / lý do chưa đạt:** N03: Dashboard/Plan đọc plan thật, current day và chọn ngày; hiển thị meals/workout/calories/macros/source/warnings/disclaimer. Widget tests ID thật, chọn ngày và empty state đạt; analyze/tests/APK pass. Android runtime chưa nghiệm thu (6.7).
- **Source / tests:** [home_screen.dart](../frontend_app/lib/screens/home/home_screen.dart); [plan_screen.dart](../frontend_app/lib/screens/plan/plan_screen.dart); [mock_data_provider.dart](../frontend_app/lib/providers/mock_data_provider.dart).
- **Spec, subtasks và cổng kiểm:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-6-5"></a>

### Task 6.5 — Grocery đồng bộ và lưu checklist

- [x] **Status: DONE**
- **Dependency:** [6.4](#task-6-4), [5.5](#task-5-5)
- **Phạm vi gốc:** Grocery: dựng từ `grocery_list`; trạng thái tích chọn lưu cục bộ (FR-3.2). Tên nhóm theo BRD FR-3.1 (*Đạm*, *Rau củ quả*, *Gạo, bún & gia vị* — hiện là "Thịt & Thủy hải sản", "Gia vị & nguyên liệu khác"); thêm thao tác xoá món đã có sẵn trong tủ lạnh (FR-3.2); quyết định giữ hay bỏ nút "Thêm nguyên liệu" (không có trong BRD)
- **Acceptance criteria hiện hành:** Dựng từ grocery_list, ba nhóm BRD; persist bought/have; ẩn/khôi phục món có sẵn; key category+name+quantity; swap/new plan cập nhật; chốt bỏ/giữ add ingredient theo BRD.
- **Evidence / lý do chưa đạt:** N03: UI nối grocery_list và GroceryProvider; nhóm BRD, bought/have/khôi phục/tìm kiếm/lọc, bỏ add ingredient. Widget test swap cập nhật grocery, giữ dòng không đổi; persistence provider tests đạt.
- **Source / tests:** [grocery_screen.dart](../frontend_app/lib/screens/grocery/grocery_screen.dart); [grocery_provider.dart](../frontend_app/lib/providers/grocery_provider.dart).
- **Spec, subtasks và cổng kiểm:** [6/F03](superpowers/plans/phase-6-connect-mvp/specs/F03-app-logic.md); [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-6-6"></a>

### Task 6.6 — Widget tests FakeBackend

- [ ] **Status: PARTIAL**
- **Dependency:** [5.8](#task-5-8), [6.1](#task-6-1), [6.2](#task-6-2), [6.3](#task-6-3), [6.4](#task-6-4), [6.5](#task-6-5)
- **Phạm vi gốc:** Widget test dùng backend giả `test/fake_backend.dart` (có từ giai đoạn 5)
- **Acceptance criteria hiện hành:** Harness/FakeBackend kiểm onboarding/loading/plan/grocery/profile/startup/swap; assert request/response, errors/safety và no unexpected HTTP; chạy flutter test.
- **Evidence / lý do chưa đạt:** N01/N02 regression giữ nguyên; N03 có dashboard/plan/ID/swap/grocery tests. Restoration 31/10 thêm 18 tests render/overflow/keyboard và toàn suite 131 PASS, 2 SKIP. Profile/startup và các gate còn thiếu của task chưa đạt, giữ PARTIAL.
- **Source / tests:** [app_harness.dart](../frontend_app/test/app_harness.dart); [fake_backend.dart](../frontend_app/test/fake_backend.dart); [widget tests N02](../frontend_app/test/screens/onboarding_n02_test.dart).
- **Spec, subtasks và cổng kiểm:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-6-7"></a>

### Task 6.7 — UI integration, model migration và device E2E

- [ ] **Status: PARTIAL**
- **Dependency:** [6.1](#task-6-1), [6.2](#task-6-2), [6.3](#task-6-3), [6.4](#task-6-4), [6.5](#task-6-5), [6.6](#task-6-6)
- **Phạm vi gốc:** Màn hình đọc/ghi qua `PlanProvider`/`AuthProvider` và model `lib/models/api/`; xoá view-model cũ `lib/models/meal_plan.dart`. Thao tác lại toàn luồng trên máy ảo Android và chạy `flutter test integration_test`
- **Acceptance criteria hiện hành:** Screens qua Plan/Auth/Grocery providers và models/api; không gọi HTTP trực tiếp; loại model cũ/mock production flow; integration_test gồm UI → backend thật từ Android, fake/no-key safety.
- **Evidence / lý do chưa đạt:** N03/restoration dùng models/api và providers cho các màn đã nối; widget/mock-HTTP tests đạt, Android Pixel_2 smoke Welcome → Onboarding đạt. Feedback/profile còn model/mock cũ ngoài N03, fixture gate và integration_test UI → backend thật trên Android còn thiếu; giữ PARTIAL.
- **Source / tests:** [main.dart](../frontend_app/lib/main.dart); [meal_plan.dart](../frontend_app/lib/models/meal_plan.dart); [api_client.dart](../frontend_app/lib/services/api_client.dart).
- **Spec, subtasks và cổng kiểm:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-6-8"></a>

### Task 6.8 — Branding/platform UI

- [ ] **Status: PARTIAL**
- **Dependency:** [6.7](#task-6-7)
- **Phạm vi gốc:** Tên app hiển thị "my_ai_app" (Android, web) và "My Ai App" (iOS) → "SmartFit AI"; icon vẫn là icon mặc định của Flutter; màn khởi động còn logo Flutter; thanh trạng thái màu đen trên nền app sáng
- **Acceptance criteria hiện hành:** SmartFit AI trên Android/web/iOS/macOS; deterministic icons/adaptive/splash; Android12+ green; bars sáng/visible; build APK/web và kiểm launcher/device.
- **Evidence / lý do chưa đạt:** Config/assets/build có; device chưa kiểm trong audit; lint có năm icon warnings; icon script macOS chưa chạy lại.
- **Source / tests:** [AndroidManifest.xml](../frontend_app/android/app/src/main/AndroidManifest.xml); [update_icons.sh](../frontend_app/tool/update_icons.sh); [manifest.json](../frontend_app/web/manifest.json).
- **Spec, subtasks và cổng kiểm:** [6/F05](superpowers/plans/phase-6-connect-mvp/specs/F05-branding.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-6-9"></a>

### Task 6.9 — Backend safe profile và fixtures

- [ ] **Status: PARTIAL**
- **Dependency:** [1.2](#task-1-2), [5.3](#task-5-3), [5.8](#task-5-8)
- **Phạm vi gốc:** *(D6-A1, A2, A3)* Backend: tuổi tối thiểu 18; BMI < 18,5 hoặc mang thai / cho con bú mà chọn `cut` → 400 kèm câu tiếng Việt; test + fixture hợp đồng xuất lại; BRD v2.6.0
- **Acceptance criteria hiện hành:** Age≥18; raw BMI<18.5+cut400; pregnancy+cut400, male+pregnancy400; warnings; áp mọi profile endpoint; BRDv2.6; Dart model/fixtures xuất lại và verified.
- **Evidence / lý do chưa đạt:** Backend/model tests audit pass; fixture exporter/comparison thiếu ở5.8 nên chưa đủ acceptance toàn task.
- **Source / tests:** [create-plan.dto.ts](../backend_api/src/plan/dto/create-plan.dto.ts); [profile-safety.spec.ts](../backend_api/src/plan/profile-safety.spec.ts); [profile_rules_test.dart](../frontend_app/test/models/profile_rules_test.dart).
- **Spec, subtasks và cổng kiểm:** [6/F01](superpowers/plans/phase-6-connect-mvp/specs/F01-backend-profile-safety.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-6-10"></a>

### Task 6.10 — Exercise level mọi đường và prompt

- [ ] **Status: PARTIAL**
- **Dependency:** [4.1](#task-4-1), [4.3](#task-4-3), [4.4](#task-4-4), [6.9](#task-6-9)
- **Phạm vi gốc:** *(D6-A4)* Backend: chọn mức động tác theo tuổi và `activity_level` cho thực đơn mẫu và kho đổi bài; prompt Gemini cùng luật; đo lại bằng `npm run measure:gemini` nếu đổi prompt
- **Acceptance criteria hiện hành:** Pregnancy/age≥60/age≥45 sedentary→level1; active<45→3; khác≤2; sample/Gemini/swap/feedback đều cap, tránh injury; không tăng calls; workspace prompt identical và đo thật khi thay prompt.
- **Evidence / lý do chưa đạt:** Backend tests audit pass; workspace thiếu level/pregnancy; live measurement chưa xác minh.
- **Source / tests:** [exercise-level.spec.ts](../backend_api/src/plan/exercise-level.spec.ts); [gemini-prompt.spec.ts](../backend_api/src/plan/gemini-prompt.spec.ts); [generate-plan-experiment.ts](../ai_workspace/generate-plan-experiment.ts).
- **Spec, subtasks và cổng kiểm:** [6/F02](superpowers/plans/phase-6-connect-mvp/specs/F02-backend-exercise-level.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-6-11"></a>

### Task 6.11 — Plan schedule và expiry

- [x] **Status: DONE**
- **Dependency:** [5.5](#task-5-5)
- **Phạm vi gốc:** *(D6-B1)* App lưu ngày bắt đầu plan, Dashboard mở đúng ngày theo lịch; quá 3 ngày → gợi ý tạo plan mới
- **Acceptance criteria hiện hành:** Persist start date; date-only theo local calendar; dashboard hôm nay; feedbackday3 new plan bắt đầu ngày mai; hết3ngày gợi ý generate; resume cập nhật ngày.
- **Evidence:** N04 (31/10/2026): implementation và unit/widget tests đạt criteria hiện hành; analyze sạch, 158 PASS/2 SKIP, APK debug PASS. Chi tiết/giới hạn Android ở nhật ký N04 đầu tài liệu.
- **Source / tests:** [plan_schedule.dart](../frontend_app/lib/models/plan_schedule.dart); [plan_provider.dart](../frontend_app/lib/providers/plan_provider.dart); [plan_schedule_test.dart](../frontend_app/test/models/plan_schedule_test.dart).
- **Spec, subtasks và cổng kiểm:** [6/F03](superpowers/plans/phase-6-connect-mvp/specs/F03-app-logic.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-7-1"></a>

### Task 7.1 — Meal swap UI

- [x] **Status: DONE**
- **Dependency:** [4.2](#task-4-2), [6.4](#task-6-4), [6.5](#task-6-5), [6.7](#task-6-7)
- **Phạm vi gốc:** Nút "Đổi món" gọi API (hiện đang xoay vòng trong danh sách món viết cứng); thay cả plan và checklist bằng plan server trả về. 409 → báo hồ sơ đã đổi, gợi ý tạo plan mới; 422 → báo không còn món thay thế phù hợp *(làm ở giai đoạn 6, quyết định Q3)*
- **Bổ sung từ PLAN chính trước hợp nhất:** Nút "Đổi món" thay cả plan và checklist bằng plan server trả về. 409 → báo hồ sơ đã đổi, gợi ý tạo plan mới; 422 → báo không còn món thay thế phù hợp
- **Acceptance criteria hiện hành:** Truyền đúng meal_id cho mọi bữa; PlanProvider.swapMeal; full response cập nhật plan/grocery; busy/error/409regenerate/422keep-old; không mock nutrient claims.
- **Evidence / lý do chưa đạt:** N03: detail nhận meal_id từ route; swap gọi PlanProvider.swapMeal, giữ nguyên profile/plan, full response cập nhật và lưu; tests success/422/retry/busy/409 giữ plan cũ đạt. Không tạo alternatives/nutrients giả.
- **Source / tests:** [meal_detail_screen.dart](../frontend_app/lib/screens/meal/meal_detail_screen.dart); [meal_swap_sheet.dart](../frontend_app/lib/screens/meal/meal_swap_sheet.dart).
- **Spec, subtasks và cổng kiểm:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-7-2"></a>

### Task 7.2 — Exercise swap UI

- [x] **Status: DONE**
- **Dependency:** [4.3](#task-4-3), [6.4](#task-6-4), [6.7](#task-6-7)
- **Phạm vi gốc:** Nút "Đổi bài" gọi API *(làm ở giai đoạn 6, quyết định Q3)*
- **Acceptance criteria hiện hành:** Truyền đúng exercise_id/day; PlanProvider.swapExercise; response update/error/busy; workout các ngày không shared mutable; không hardcoded safety.
- **Evidence / lý do chưa đạt:** N03: detail nhận exercise_id từ route; swap gọi PlanProvider.swapExercise với profile của plan; loading/error/retry/busy, full response và persistence được kiểm. UI không dùng shared mock workout.
- **Source / tests:** [workout_swap_sheet.dart](../frontend_app/lib/screens/workout/workout_swap_sheet.dart); [mock_data_provider.dart](../frontend_app/lib/providers/mock_data_provider.dart).
- **Spec, subtasks và cổng kiểm:** [6/F04](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-7-3"></a>

### Task 7.3 — Feedback end-of-day UI

- [x] **Status: DONE**
- **Dependency:** [4.4](#task-4-4), [6.7](#task-6-7), [6.11](#task-6-11)
- **Phạm vi gốc:** Làm lại bảng feedback theo D2 (3 câu hỏi, câu tình trạng cơ thể chọn nhiều); gọi API, cập nhật ngày kế tiếp; nhận `safety_warning` → hiện khuyến cáo ngừng tập, hỏi ý kiến bác sĩ. **Khoá nút sau khi đã gửi feedback cho một ngày** — backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa. Bỏ câu báo viết sẵn "AI đã cân đối lại thực đơn Ngày 2!" (hiện hiện ra dù không có gì thay đổi)
- **Bổ sung từ PLAN chính trước hợp nhất:** Làm lại bảng feedback theo D2 (3 câu hỏi, câu tình trạng cơ thể chọn nhiều); gọi API, cập nhật ngày kế tiếp; nhận `safety_warning` → hiện khuyến cáo ngừng tập, hỏi ý kiến bác sĩ. **Khoá nút sau khi đã gửi feedback cho một ngày** — backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa
- **Acceptance criteria hiện hành:** Ba câu D2/body multi; gửi mã BRD; update ngày sau; safetyWarning nổi bật/ngừng tập/hỏi bác sĩ; day3 lịch ngày mai; persist lock plan/day; không success text viết sẵn khi không đổi.
- **Evidence:** N05 có UI ba câu D2/entry từ Dashboard và Plan, API thật, SQLite receipt bền theo plan/day, snapshot pending/completed, error/retry/success chính xác, warning/rest và day3 queue đến ngày mai. Tests bao gồm concurrent, restart DB/app, lỗi ghi, bảo toàn ngày cũ/draft/checklist, lịch sử và HTTP fullflow với AI giả lập. Nghiệm thu Android/Groq live vẫn UNVERIFIED, không đồng nghĩa toàn bộ phase đã được nghiệm thu trên thiết bị.
- **Source / tests:** [daily_feedback_screen.dart](../frontend_app/lib/screens/feedback/daily_feedback_screen.dart), [PlanProvider](../frontend_app/lib/providers/plan_provider.dart), [FeedbackService](../backend_api/src/plan/adjust/feedback.service.ts), [N05 evidence/file list](N05_FEEDBACK.md).

<a id="task-8-1"></a>

### Task 8.1 — Mock/Google login và skip

- [ ] **Status: PARTIAL**
- **Dependency:** [3.3](#task-3-3), [5.5](#task-5-5)
- **Phạm vi gốc:** Màn đăng nhập, chọn chế độ bằng `--dart-define=AUTH_MODE`: giả lập → nút "Đăng nhập demo"; thật → package `google_sign_in`. Có nút bỏ qua đăng nhập (đăng nhập là tuỳ chọn theo FR-7)
- **Acceptance criteria hiện hành:** AUTH_MODE dart-define; demo button/mock token hoặc google_sign_in ID token; AuthProvider.signIn; optional skip; loading/error/account UI.
- **Evidence / lý do chưa đạt:** Provider test pass; Google button chỉ vào onboarding; không google_sign_in/mode thực thi.
- **Source / tests:** [welcome_screen.dart](../frontend_app/lib/screens/auth/welcome_screen.dart); [auth_provider.dart](../frontend_app/lib/providers/auth_provider.dart); [pubspec.yaml](../frontend_app/pubspec.yaml).

<a id="task-8-2"></a>

### Task 8.2 — JWT và login-again UI

- [ ] **Status: PARTIAL**
- **Dependency:** [8.1](#task-8-1), [3.8](#task-3-8)
- **Phạm vi gốc:** Gắn JWT vào request; nhận 401 → yêu cầu đăng nhập lại
- **Acceptance criteria hiện hành:** JWT gửi request cần auth; restore session; 401 logout và gợi ý login lại; không lưu Google ID token; logout/delete calls dùng provider thật.
- **Evidence / lý do chưa đạt:** JWT/401 provider tests pass; UI không signIn/login-again; deletion chỉ navigate, không DELETE/signout.
- **Source / tests:** [api_client.dart](../frontend_app/lib/services/api_client.dart); [auth_provider.dart](../frontend_app/lib/providers/auth_provider.dart); [delete_account_sheet.dart](../frontend_app/lib/screens/settings/delete_account_sheet.dart).

<a id="task-8-3"></a>

### Task 8.3 — History UI

- [ ] **Status: NOT STARTED**
- **Dependency:** [3.5](#task-3-5), [8.1](#task-8-1), [8.2](#task-8-2)
- **Phạm vi gốc:** Đổi tab "Thống kê" thành "Lịch sử": danh sách plan cũ, bấm vào xem chi tiết
- **Acceptance criteria hiện hành:** Tab Lịch sử list/date/calories/detail; authenticated/error/loading/empty; user khác404; cùng Google tài khoản trên thiết bị khác thấy history.
- **Evidence / lý do chưa đạt:** API history có; không screen/tab lịch sử trong routes/main.
- **Source / tests:** [main_screen.dart](../frontend_app/lib/screens/main_screen.dart); [routes.dart](../frontend_app/lib/routes.dart); [api_client.dart](../frontend_app/lib/services/api_client.dart).

<a id="task-8-4"></a>

### Task 8.4 — Flutter Google setup docs

- [ ] **Status: NOT STARTED**
- **Dependency:** [8.1](#task-8-1)
- **Phạm vi gốc:** `SETUP_CREDENTIALS.md` — phần **Google Sign-In (Flutter)**: Client ID, thẻ meta cho bản web, SHA-1 cho Android
- **Acceptance criteria hiện hành:** Android/iOS/web IDs, serverClientId, AndroidSHA-1, web meta, mode/build flags và troubleshooting; không đặt secret trong app.
- **Evidence / lý do chưa đạt:** Phần Flutter ghi chưa làm.
- **Source / tests:** [SETUP_CREDENTIALS.md](SETUP_CREDENTIALS.md).

<a id="task-9-1"></a>

### Task 9.1 — Host và durable storage

- [ ] **Status: UNVERIFIED**
- **Dependency:** [3.2](#task-3-2)
- **Phạm vi gốc:** Chọn nơi deploy: (a) giữ SQLite, dùng host có ổ lưu trữ bền (Railway volume, Fly.io volume, VPS), hoặc (b) chuyển sang Postgres. **Không** dùng Render bản free với SQLite
- **Acceptance criteria hiện hành:** Chốt SQLite+volume(host phù hợp) hoặc Postgres; không Renderfree+SQLite; ghi deployment choice và verify restart persistence.
- **Evidence / lý do chưa đạt:** Không có endpoint/config/log host đã xác minh; có thể tồn tại ngoài checkout.
- **Source / tests:** [BRD.md](../BRD.md).

<a id="task-9-2"></a>

### Task 9.2 — Production backend deployment

- [ ] **Status: UNVERIFIED**
- **Dependency:** [9.1](#task-9-1), [3.3](#task-3-3), [5.7](#task-5-7)
- **Phạm vi gốc:** Deploy backend, cấu hình biến môi trường trên host: `NODE_ENV=production`, `AUTH_MODE=google`, `GOOGLE_CLIENT_ID`, `JWT_SECRET`, `DATABASE_PATH` trỏ vào ổ lưu trữ bền, `GEMINI_API_KEY`, `CORS_ORIGINS` (địa chỉ bản web, nếu deploy bản web)
- **Acceptance criteria hiện hành:** Host dùng NODE_ENVproduction,AUTH_MODEgoogle,clientID,secret,database durable,Gemini key,CORS origins; HTTPS/health/auth/storage chạy; secrets không commit.
- **Evidence / lý do chưa đạt:** Không có production endpoint/result được xác minh; config code không chứng minh deployment.
- **Source / tests:** [SETUP_CREDENTIALS.md](SETUP_CREDENTIALS.md); [auth-config.ts](../backend_api/src/auth/auth-config.ts).

<a id="task-9-3"></a>

### Task 9.3 — Demo web/APK với production URL

- [ ] **Status: UNVERIFIED**
- **Dependency:** [9.2](#task-9-2), [6.7](#task-6-7), [6.8](#task-6-8)
- **Phạm vi gốc:** Build app để demo: bản web và/hoặc APK Android, với `--dart-define=API_BASE_URL=https://<địa chỉ backend>`
- **Acceptance criteria hiện hành:** Build --dart-define API_BASE_URL=https://host; release network/signing/appID phù hợp; cài/chạy được, không còn mock-only production screens.
- **Evidence / lý do chưa đạt:** APK debug/web local audit pass; release dùng debug signing/templateID; chưa có production API build nghiệm thu.
- **Source / tests:** [build.gradle.kts](../frontend_app/android/app/build.gradle.kts); [api_config.dart](../frontend_app/lib/config/api_config.dart).

<a id="task-9-4"></a>

### Task 9.4 — Full-flow acceptance mock/real

- [ ] **Status: PARTIAL**
- **Dependency:** [6.6](#task-6-6), [6.7](#task-6-7), [7.1](#task-7-1), [7.2](#task-7-2), [7.3](#task-7-3), [8.2](#task-8-2), [8.3](#task-8-3), [9.3](#task-9-3)
- **Phạm vi gốc:** Chạy checklist kiểm thử toàn luồng ở cả hai chế độ (giả lập / khoá thật)
- **Acceptance criteria hiện hành:** Client→Server→AI→Client; mock/no-key và real keys; validation/safety/offline/swap/grocery/feedback/auth/history/delete; Android restart/calendar/device; logs không health; lưu evidence.
- **Evidence / lý do chưa đạt:** Backend local tests pass; UI/device/live Google/Gemini/production chưa nghiệm thu.
- **Source / tests:** [smoke-test.mjs](../backend_api/scripts/smoke-test.mjs); [app_harness.dart](../frontend_app/test/app_harness.dart).

<a id="task-9-5"></a>

### Task 9.5 — README/changelog/BRD rubric/wiki

- [ ] **Status: PARTIAL**
- **Dependency:** [9.4](#task-9-4)
- **Phạm vi gốc:** Cập nhật README (cách chạy, ảnh chụp màn hình), Changelog, BRD mục 9, wiki
- **Acceptance criteria hiện hành:** Docs khớp code/status; screenshots/cách chạy; changelog; BRD§9 rubric phản ánh nghiệm thu, không đổi scope; link/wiki index/triggers; roadmap chỉ docs/PLAN.md.
- **Evidence / lý do chưa đạt:** Consolidation chỉ hoàn tất roadmap và references; docs/screenshots/full release acceptance còn thiếu; không tự tick BRD.
- **Source / tests:** [README.md](../README.md); [CLAUDE.md](../CLAUDE.md); [flutter-ui.md](knowledge/wiki/flutter-ui.md).
- **Spec, subtasks và cổng kiểm:** [1/F07](superpowers/plans/phase-1-api-contract/specs/F07-docs-wiki.md); [2/F06](superpowers/plans/phase-2-backend-tests/specs/F06-docs-wiki.md); [3/F05](superpowers/plans/phase-3-auth-history/specs/F05-docs.md); [4/F07](superpowers/plans/phase-4-swap-feedback/specs/F07-docs.md); [5/F07](superpowers/plans/phase-5-frontend-foundation/specs/F07-docs.md); [6/F06](superpowers/plans/phase-6-connect-mvp/specs/F06-docs.md). Xem bảng tiêu chí spec bên dưới; không bỏ checklist con.

<a id="task-9-6"></a>

### Task 9.6 — Slides và video demo

- [ ] **Status: NOT STARTED**
- **Dependency:** [9.4](#task-9-4), [9.5](#task-9-5)
- **Phạm vi gốc:** Slide báo cáo và video demo
- **Acceptance criteria hiện hành:** Slide giải thích yêu cầu/kiến trúc/test/limits; video full-flow; artifact/link có và mở được.
- **Evidence / lý do chưa đạt:** Không có slide/video artifact trong repo; tài liệu bên ngoài chưa được xác minh.
- **Source / tests:** [README.md](../README.md).

### Chỉ mục acceptance criteria của 38 feature specs

Mọi spec gốc được giữ nguyên, gồm Implementation, Tasks, Definition of Done, Test Checklist và phase gates trong project.json. Bảng dưới ánh xạ mỗi feature về task roadmap; các tiêu chí nguyên văn được bảo toàn ngay sau bảng. Expected test counts, phiên bản BRD cũ và số liệu timing là mốc lịch sử; yêu cầu semantic/safety chưa bị BRD mới thay thế vẫn phải đạt. Các dòng template “không áp dụng” không tạo task mới. Trạng thái spec lịch sử không được dùng để ghi đè Status của task.

| Feature | Task roadmap | Spec |
|---|---|---|
| P1-F01 | [1.1](#task-1-1), [1.2](#task-1-2) | [F01-brd-contract.md](superpowers/plans/phase-1-api-contract/specs/F01-brd-contract.md) |
| P1-F02 | [1.3](#task-1-3) | [F02-plan-types-validation.md](superpowers/plans/phase-1-api-contract/specs/F02-plan-types-validation.md) |
| P1-F03 | [1.3](#task-1-3) | [F03-daily-target.md](superpowers/plans/phase-1-api-contract/specs/F03-daily-target.md) |
| P1-F04 | [1.3](#task-1-3) | [F04-plan-assembly.md](superpowers/plans/phase-1-api-contract/specs/F04-plan-assembly.md) |
| P1-F05 | [1.3](#task-1-3) | [F05-sample-plan.md](superpowers/plans/phase-1-api-contract/specs/F05-sample-plan.md) |
| P1-F06 | [1.3](#task-1-3) | [F06-generate-plan-pipeline.md](superpowers/plans/phase-1-api-contract/specs/F06-generate-plan-pipeline.md) |
| P1-F07 | [1.4](#task-1-4), [9.5](#task-9-5) | [F07-docs-wiki.md](superpowers/plans/phase-1-api-contract/specs/F07-docs-wiki.md) |
| P2-F01 | [2.1](#task-2-1) | [F01-daily-target-matrix.md](superpowers/plans/phase-2-backend-tests/specs/F01-daily-target-matrix.md) |
| P2-F02 | [2.5](#task-2-5) | [F02-gemini-service-real-sdk.md](superpowers/plans/phase-2-backend-tests/specs/F02-gemini-service-real-sdk.md) |
| P2-F03 | [2.3](#task-2-3) | [F03-plan-service-retry.md](superpowers/plans/phase-2-backend-tests/specs/F03-plan-service-retry.md) |
| P2-F04 | [2.4](#task-2-4) | [F04-e2e-generate-plan.md](superpowers/plans/phase-2-backend-tests/specs/F04-e2e-generate-plan.md) |
| P2-F05 | [2.6](#task-2-6) | [F05-github-actions.md](superpowers/plans/phase-2-backend-tests/specs/F05-github-actions.md) |
| P2-F06 | [9.5](#task-9-5) | [F06-docs-wiki.md](superpowers/plans/phase-2-backend-tests/specs/F06-docs-wiki.md) |
| P3-F01 | [3.1](#task-3-1), [3.2](#task-3-2) | [F01-database.md](superpowers/plans/phase-3-auth-history/specs/F01-database.md) |
| P3-F02 | [3.3](#task-3-3), [3.4](#task-3-4), [3.8](#task-3-8) | [F02-auth.md](superpowers/plans/phase-3-auth-history/specs/F02-auth.md) |
| P3-F03 | [3.4](#task-3-4), [3.5](#task-3-5), [3.6](#task-3-6) | [F03-history.md](superpowers/plans/phase-3-auth-history/specs/F03-history.md) |
| P3-F04 | [3.9](#task-3-9) | [F04-smoke-ci.md](superpowers/plans/phase-3-auth-history/specs/F04-smoke-ci.md) |
| P3-F05 | [3.7](#task-3-7), [9.5](#task-9-5) | [F05-docs.md](superpowers/plans/phase-3-auth-history/specs/F05-docs.md) |
| P4-F01 | [4.1](#task-4-1), [4.7](#task-4-7) | [F01-calories-restrictions.md](superpowers/plans/phase-4-swap-feedback/specs/F01-calories-restrictions.md) |
| P4-F02 | [4.8](#task-4-8) | [F02-client-plan.md](superpowers/plans/phase-4-swap-feedback/specs/F02-client-plan.md) |
| P4-F03 | [4.2](#task-4-2) | [F03-meal-swap.md](superpowers/plans/phase-4-swap-feedback/specs/F03-meal-swap.md) |
| P4-F04 | [4.3](#task-4-3) | [F04-exercise-swap.md](superpowers/plans/phase-4-swap-feedback/specs/F04-exercise-swap.md) |
| P4-F05 | [4.4](#task-4-4) | [F05-feedback.md](superpowers/plans/phase-4-swap-feedback/specs/F05-feedback.md) |
| P4-F06 | [4.5](#task-4-5) | [F06-endpoints-e2e.md](superpowers/plans/phase-4-swap-feedback/specs/F06-endpoints-e2e.md) |
| P4-F07 | [9.5](#task-9-5) | [F07-docs.md](superpowers/plans/phase-4-swap-feedback/specs/F07-docs.md) |
| P5-F01 | [5.7](#task-5-7), [5.8](#task-5-8) | [F01-backend-cors-fixtures.md](superpowers/plans/phase-5-frontend-foundation/specs/F01-backend-cors-fixtures.md) |
| P5-F02 | [5.1](#task-5-1), [5.2](#task-5-2) | [F02-packages-platform.md](superpowers/plans/phase-5-frontend-foundation/specs/F02-packages-platform.md) |
| P5-F03 | [5.3](#task-5-3) | [F03-dart-models.md](superpowers/plans/phase-5-frontend-foundation/specs/F03-dart-models.md) |
| P5-F04 | [5.4](#task-5-4) | [F04-api-client.md](superpowers/plans/phase-5-frontend-foundation/specs/F04-api-client.md) |
| P5-F05 | [5.5](#task-5-5) | [F05-providers.md](superpowers/plans/phase-5-frontend-foundation/specs/F05-providers.md) |
| P5-F06 | [5.6](#task-5-6), [5.9](#task-5-9) | [F06-main-shell-ci.md](superpowers/plans/phase-5-frontend-foundation/specs/F06-main-shell-ci.md) |
| P5-F07 | [9.5](#task-9-5) | [F07-docs.md](superpowers/plans/phase-5-frontend-foundation/specs/F07-docs.md) |
| P6-F01 | [6.9](#task-6-9) | [F01-backend-profile-safety.md](superpowers/plans/phase-6-connect-mvp/specs/F01-backend-profile-safety.md) |
| P6-F02 | [6.10](#task-6-10) | [F02-backend-exercise-level.md](superpowers/plans/phase-6-connect-mvp/specs/F02-backend-exercise-level.md) |
| P6-F03 | [6.2](#task-6-2), [6.5](#task-6-5), [6.11](#task-6-11) | [F03-app-logic.md](superpowers/plans/phase-6-connect-mvp/specs/F03-app-logic.md) |
| P6-F04 | [6.1](#task-6-1), [6.2](#task-6-2), [6.3](#task-6-3), [6.4](#task-6-4), [6.5](#task-6-5), [6.6](#task-6-6), [6.7](#task-6-7), [7.1](#task-7-1), [7.2](#task-7-2) | [F04-app-screens.md](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md) |
| P6-F05 | [6.8](#task-6-8) | [F05-branding.md](superpowers/plans/phase-6-connect-mvp/specs/F05-branding.md) |
| P6-F06 | [9.5](#task-9-5) | [F06-docs.md](superpowers/plans/phase-6-connect-mvp/specs/F06-docs.md) |

#### P1-F01 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-1-api-contract/specs/F01-brd-contract.md); task: [1.1](#task-1-1), [1.2](#task-1-2).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] Header ghi `2.3.0`, ngày `24/09/2026`
> - [ ] FR-1.3, FR-1.4, FR-1.5, FR-1.6, FR-2.1, FR-2.3, FR-3.1, FR-4.1, FR-4.2, FR-5 đúng văn bản ở Tasks
> - [ ] Mục 6 đổi tên, 6.1 / 6.2 viết lại, 6.4 thêm mới; 6.3 giữ nguyên
> - [ ] NFR-1, NFR-2, NFR-4 sửa; NFR-7, NFR-8, NFR-9 thêm mới
> - [ ] Mọi khối ```json trong BRD parse được (cổng kiểm tra F01)
> - [ ] Không còn chuỗi `sample_plan.json`, `"allergies": [`, `source_meal_ids` kiểu cũ (mô tả cập nhật từng phần) trong BRD
> - [x] All API routes complete within deployment timeout — không áp dụng (F01 không đụng code)
> - [x] Auth check at top of each protected handler — không áp dụng (không có route cần đăng nhập)

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: chạy lệnh cổng kiểm tra F01 → in `N json blocks ok`
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng
> 4. **@partial-fail**: `grep -n "sample_plan.json\|\"allergies\": \[" BRD.md` → không có kết quả
> 5. **@token**: không áp dụng
> 6. **@db**: không áp dụng


#### P1-F02 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-1-api-contract/specs/F02-plan-types-validation.md); task: [1.3](#task-1-3).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `parsePlanContent()` trả `{ plan, errors: [] }` cho plan đúng hợp đồng, `{ plan: null, errors }` cho mọi trường hợp sai
> - [ ] `meal_type` ngoài `breakfast | lunch | dinner` → lỗi (không còn `return true`)
> - [ ] Trường ngoài hợp đồng (ví dụ `grocery_list`, `plan_id` do Gemini tự thêm) bị loại bỏ, không gây lỗi
> - [ ] `npm run build` không lỗi, `npm test` xanh
> - [x] All API routes complete within deployment timeout — không áp dụng (chưa đổi route)
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: plan đúng hợp đồng → `errors` rỗng, `plan.days` có 3 phần tử
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng (hàm thuần, không I/O)
> 4. **@partial-fail**: `meal_type: "Bữa sáng"`; thiếu ngày; calo ngoài khoảng; calo lệch macro; trùng món; ngày thiếu một loại bữa; input không phải object → đều trả `plan: null`
> 5. **@token**: không áp dụng
> 6. **@db**: không áp dụng


#### P1-F03 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-1-api-contract/specs/F03-daily-target.md); task: [1.3](#task-1-3).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `GOAL_CALORIE_ADJUSTMENT`: cut −300, bulk +250, maintain 0
> - [ ] Nữ 22 tuổi, 168 cm, 62 kg, vận động nhẹ, giảm mỡ → `{ bmi: 22, bmr: 1399, tdee: 1924, target_calories: 1624, protein_g: 102, carbs_g: 183, fat_g: 54 }`, `flooredToBmr: false`
> - [ ] Nữ 22 tuổi, 150 cm, 45 kg, ít vận động, giảm mỡ → `target_calories` = `bmr` = 1117, `flooredToBmr: true`
> - [ ] `npm run build` không lỗi, `npm test` xanh
> - [x] All API routes complete within deployment timeout — không áp dụng (hàm thuần)
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: ví dụ BRD mục 6.2 ra đúng từng con số
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng
> 4. **@partial-fail**: người nhỏ con, ít vận động, giảm mỡ → được nâng lên bằng BMR, không ra số dưới BMR
> 5. **@token**: không áp dụng
> 6. **@db**: không áp dụng


#### P1-F04 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-1-api-contract/specs/F04-plan-assembly.md); task: [1.3](#task-1-3).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `plan_id` là UUID v4; `source`, `warnings`, `daily_target` giữ nguyên như truyền vào
> - [ ] Bữa trong mỗi ngày được sắp breakfast → lunch → dinner, bất kể thứ tự Gemini trả về
> - [ ] Nguyên liệu trùng tên (không phân biệt hoa thường, khoảng trắng) và cùng đơn vị được cộng dồn; `source_meal_ids` không lặp
> - [ ] Cùng nguyên liệu khác đơn vị nằm ở hai dòng
> - [ ] Nhóm theo thứ tự protein → produce → pantry, bỏ nhóm rỗng
> - [ ] `npm run build` không lỗi, `npm test` xanh
> - [x] All API routes complete within deployment timeout — không áp dụng (hàm thuần)
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: 3 ngày × (Gạo tẻ 100 g trưa + 80 g tối) → một dòng `540g` với 6 `source_meal_ids` đúng thứ tự
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng
> 4. **@partial-fail**: `Dầu ăn` 1 tbsp và `dầu ăn ` 1 tsp → hai dòng `1 muỗng canh`, `1 muỗng cà phê`
> 5. **@token**: không áp dụng
> 6. **@db**: không áp dụng


#### P1-F05 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-1-api-contract/specs/F05-sample-plan.md); task: [1.3](#task-1-3).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `sample-plan.json` qua `parsePlanContent()` không lỗi
> - [ ] 3 ngày, 9 tên món khác nhau, không có hải sản hay đậu phộng
> - [ ] Ghép qua `assemblePlan()` ra dòng `Gạo tẻ — 540g` với 6 `source_meal_ids`
> - [ ] `npm run build` không lỗi, `npm test` xanh
> - [x] All API routes complete within deployment timeout — đường fallback < 100 ms
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: thực đơn mẫu qua bộ kiểm tra; ghép ra danh sách đi chợ đúng
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng (đọc file cục bộ)
> 4. **@partial-fail**: nếu ai đó sửa file mẫu sai hợp đồng về sau → test này đỏ trước khi lên tới người dùng
> 5. **@token**: không áp dụng
> 6. **@db**: không áp dụng


#### P1-F06 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-1-api-contract/specs/F06-generate-plan-pipeline.md); task: [1.3](#task-1-3).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] Request có `restrictions` dạng chuỗi → 200; dạng mảng kiểu cũ → 400; không có `restrictions` → 200
> - [ ] Không có `GEMINI_API_KEY` → response `source: "sample"`, đủ 3 ngày, `grocery_list` do server tính
> - [ ] Có nhập hạn chế ở chế độ mẫu → `warnings` chứa câu "Đang dùng thực đơn mẫu…"
> - [ ] Có `health_conditions` → `warnings` chứa khuyến cáo y tế; calo bị nâng lên bằng BMR → `warnings` chứa giải thích
> - [ ] Swagger (`/docs-json`) có schema `MealPlanResponseDto`
> - [ ] `interfaces/plan.interface.ts`, `nutrition-sanity.util.ts` đã xoá, không còn chỗ nào import
> - [ ] `ai_workspace` dùng đúng prompt mới
> - [ ] `npm run build` không lỗi, `npm test` và `npm run test:e2e` xanh
> - [ ] All API routes complete within deployment timeout — đường mẫu < 100 ms; đường Gemini có giới hạn cứng 15 s/lần, tệ nhất ~30 s
> - [x] Auth check at top of each protected handler — không áp dụng (`generate-plan` chưa cần đăng nhập; giai đoạn 3 thêm guard tuỳ chọn)

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: không khoá → `source: "sample"`, 3 ngày, `daily_target.target_calories = 1624` với hồ sơ ví dụ BRD
> 2. **@auth**: không áp dụng ở giai đoạn này
> 3. **@timeout**: `GeminiTimeoutError` → không gọi lại (test đầy đủ với Gemini giả ở PLAN bước 2.3)
> 4. **@partial-fail**: `restrictions` kiểu mảng → 400; khối dữ liệu trong prompt không bị phá bởi người dùng gõ thẻ đóng; có hạn chế ở chế độ mẫu → có cảnh báo
> 5. **@token**: khoá sai → lỗi được log, dùng thực đơn mẫu (kiểm bằng tay khi có khoá; test tự động với Gemini giả ở PLAN bước 2.3)
> 6. **@db**: không áp dụng


#### P1-F07 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-1-api-contract/specs/F07-docs-wiki.md); task: [1.4](#task-1-4), [9.5](#task-9-5).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `critical-constraints.md` có #1–#16, các hàng #2, #6, #7 đúng văn bản mới
> - [ ] `plan-data-contract.md` tồn tại và có trong `INDEX.md`
> - [ ] `wiki-triggers.md` không còn nhắc `nutrition-sanity.util.ts` hay `interfaces/**`
> - [ ] `CLAUDE.md` không còn nhắc `nutrition-sanity.util.ts`, `interfaces/plan.interface.ts`
> - [ ] PLAN.md: 1.1–1.4 đánh dấu `[x]`, giai đoạn 1 ghi `· M`, giai đoạn 2 đã chỉnh
> - [ ] README có mục `BRD v2.3.0`
> - [x] All API routes complete within deployment timeout — không áp dụng
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: `grep -c 'plan-data-contract' docs/knowledge/wiki/INDEX.md` → `1`; `grep -c '^- \[x\] \*\*1\.' docs/PLAN.md` → `4`
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng
> 4. **@partial-fail**: `grep -rn "nutrition-sanity\|plan.interface" CLAUDE.md docs/knowledge/wiki/wiki-triggers.md` → không có kết quả (ràng buộc #2 cố ý nhắc tên file cũ để giải thích lý do, nên không đưa vào lệnh kiểm tra)
> 5. **@token**: không áp dụng
> 6. **@db**: không áp dụng


#### P2-F01 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-2-backend-tests/specs/F01-daily-target-matrix.md); task: [2.1](#task-2-1).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] 18 trường hợp mới pass, 3 test cũ vẫn pass (`Tests  21 passed (21)`)
> - [ ] Có ít nhất 1 trường hợp bị nâng lên BMR và 1 trường hợp nằm đúng ranh giới làm tròn .5
> - [x] All API routes complete within deployment timeout — không áp dụng (không đổi route)
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: 17 trường hợp thông thường khớp từng con số
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng
> 4. **@partial-fail**: nữ · ít vận động · giảm mỡ → `flooredToBmr: true`, mục tiêu = BMR
> 5. **@token**: không áp dụng
> 6. **@db**: không áp dụng


#### P2-F02 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-2-backend-tests/specs/F02-gemini-service-real-sdk.md); task: [2.5](#task-2-5).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `GEMINI_BASE_URL` trống → client tạo như cũ; có giá trị → request tới đúng địa chỉ đó
> - [ ] 6 test trong `gemini.service.spec.ts` pass, chạy dưới 2 giây (test hết giờ dùng timeout 200 ms)
> - [ ] Test lỗi 500 xác nhận đúng **1** request
> - [ ] `npm run build` không lỗi; `npm test` xanh (9 file)
> - [x] All API routes complete within deployment timeout — không đổi route
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: server trả JSON hợp lệ → nhận đúng object; request chứa khối `<du_lieu_nguoi_dung>` và `"responseMimeType":"application/json"`
> 2. **@auth**: không áp dụng (không có đăng nhập người dùng ở giai đoạn này)
> 3. **@timeout**: server không trả lời → `GeminiTimeoutError` sau ~200 ms
> 4. **@partial-fail**: 500 → `ApiError` 500 và đúng 1 request; văn bản không phải JSON → lỗi chung, không chứa nội dung
> 5. **@token**: 400 "API key not valid" → `ApiError` 400 được ném tiếp
> 6. **@db**: không áp dụng


#### P2-F03 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-2-backend-tests/specs/F03-plan-service-retry.md); task: [2.3](#task-2-3).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] 9 test pass (3 cũ + 6 mới)
> - [ ] Số lần gọi Gemini được kiểm đúng ở mọi nhánh: 1 (hợp lệ), 2 (sai rồi đúng), 2 (sai hai lần), 1 (hết giờ), 2 (khoá sai)
> - [ ] Log bị theo dõi có ít nhất 1 dòng, và không dòng nào chứa chuỗi sức khoẻ
> - [x] All API routes complete within deployment timeout — không đổi route
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: Gemini trả nội dung hợp lệ → `source: gemini`, 1 lần gọi, không có cảnh báo "thực đơn mẫu"
> 2. **@auth**: không áp dụng
> 3. **@timeout**: `GeminiTimeoutError` → `source: sample`, đúng 1 lần gọi
> 4. **@partial-fail**: sai hợp đồng rồi đúng → `source: gemini`, 2 lần gọi; sai hai lần → `source: sample`, 2 lần gọi, có cảnh báo
> 5. **@token**: `ApiError` 400 hai lần → `source: sample`, 2 lần gọi
> 6. **@db**: không áp dụng


#### P2-F04 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-2-backend-tests/specs/F04-e2e-generate-plan.md); task: [2.4](#task-2-4).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `main.ts` chỉ còn tạo app, gọi `configureApp()`, `listen()`
> - [ ] 11 test trong `generate-plan.e2e-spec.ts` pass; `npm run test:e2e` → `Tests  12 passed (12)` (tính cả test `/health`)
> - [ ] Không test nào gửi request ra ngoài máy (server giả nghe `127.0.0.1`)
> - [ ] Biến môi trường được khôi phục sau khi chạy
> - [ ] `npm run build` không lỗi; server thật (`npm run start`) vẫn trả 400 cho `restrictions` kiểu mảng — cấu hình không mất khi tách hàm
> - [ ] All API routes complete within deployment timeout — e2e toàn file < 5 s
> - [x] Auth check at top of each protected handler — không áp dụng (`generate-plan` chưa cần đăng nhập)

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: server giả trả thực đơn hợp lệ → 200, `source: gemini`, UUID, 3 ngày, `daily_target` đúng ví dụ BRD, 3 nhóm đi chợ, 1 request
> 2. **@auth**: không áp dụng
> 3. **@timeout**: server giả không trả lời → 200, `source: sample`, đúng 1 request
> 4. **@partial-fail**: server giả trả sai hợp đồng → 2 request → `source: sample` + cảnh báo; 5 kiểu request sai → 400
> 5. **@token**: (khoá bị từ chối đã phủ ở F02, F03)
> 6. **@db**: không áp dụng


#### P2-F05 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-2-backend-tests/specs/F05-github-actions.md); task: [2.6](#task-2-6).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] Sau khi push, run "Backend CI" của commit đó kết thúc `success` cho cả 3 job (Node 24, Node 26, ai_workspace)
> - [ ] Commit chỉ sửa tài liệu (không đụng 3 đường dẫn trên) không kích hoạt workflow
> - [x] All API routes complete within deployment timeout — không đổi route
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: push lên `Thien-Source` → 3 job xanh
> 2. **@auth**: không áp dụng
> 3. **@timeout**: mỗi job có `timeout-minutes: 10` để job treo không ăn hết phút miễn phí
> 4. **@partial-fail**: `fail-fast: false` — Node 24 đỏ vẫn cho Node 26 chạy xong, để biết lỗi chỉ ở một phiên bản hay ở cả hai
> 5. **@token**: không có secret nào được dùng
> 6. **@db**: không áp dụng


#### P2-F06 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-2-backend-tests/specs/F06-docs-wiki.md); task: [9.5](#task-9-5).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `gemini-integration.md` tồn tại, có trong `INDEX.md`
> - [ ] `critical-constraints.md` có #1–#18
> - [ ] PLAN.md: giai đoạn 2 ghi `· M`, 2.1–2.6 đều `[x]`
> - [ ] README có dòng Changelog giai đoạn 2 và link tab Actions
> - [x] All API routes complete within deployment timeout — không áp dụng
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: `grep -c 'gemini-integration' docs/knowledge/wiki/INDEX.md` → `1`; `grep -c '^- \[x\] \*\*2\.' docs/PLAN.md` → `6`
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng
> 4. **@partial-fail**: mọi `[[link]]` trong wiki trỏ tới file có thật
> 5. **@token**: không áp dụng
> 6. **@db**: không áp dụng


#### P3-F01 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-3-auth-history/specs/F01-database.md); task: [3.1](#task-3-1), [3.2](#task-3-2).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm ls better-sqlite3` → `better-sqlite3@12.x`; `package.json` có `allowScripts` cho `better-sqlite3`
> - [ ] `migrations.spec.ts`: 3 test pass (schema diff rỗng, khoá ngoại bật, `down` xoá sạch)
> - [ ] `npm test` → `Test Files  10 passed (10)`, `Tests  64 passed (64)`
> - [ ] `npm run test:e2e` → `Tests  12 passed (12)`; sau khi chạy, `ls backend_api/*.sqlite*` không có file nào
> - [ ] `npm run build` rồi `node dist/main.js` khởi động được (không `ReferenceError`), `/health` trả 200
> - [ ] `git status --short` không bao giờ hiện file `*.sqlite*`
> - [x] All API routes complete within deployment timeout — không thêm route
> - [x] Auth check at top of each protected handler — không áp dụng (chưa có route cần đăng nhập)

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: DB trong RAM chạy migration → schema khớp entity; `/health` và `generate-plan` e2e vẫn pass với DB bật
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng (không thêm route)
> 4. **@partial-fail**: `retryAttempts: 0` — mở DB lỗi thì khởi động thất bại ngay, không treo 27 giây vì thử lại
> 5. **@token**: không áp dụng
> 6. **@db**: migration tạo đúng bảng, cột, khoá ngoại, chỉ mục; `down` xoá sạch; khoá ngoại bật


#### P3-F02 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-3-auth-history/specs/F02-auth.md); task: [3.3](#task-3-3), [3.4](#task-3-4), [3.8](#task-3-8).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm test` → `Test Files  14 passed (14)`, `Tests  120 passed (120)`
> - [ ] `npm run test:e2e` → `Test Files  3 passed (3)`, `Tests  24 passed (24)`
> - [ ] `NODE_ENV=production node dist/main.js` dừng ngay, in lý do có chữ `ALLOW_MOCK_AUTH`
> - [ ] `AUTH_MODE=google JWT_SECRET=short GOOGLE_CLIENT_ID=abc node dist/main.js` dừng ngay, in lý do có chữ `32 ký tự`
> - [ ] Không test nào gửi request ra ngoài máy
> - [ ] All API routes complete within deployment timeout — mọi route < 5 ms ở chế độ mock
> - [ ] Auth check at top of each protected handler — `DELETE /me` có `JwtAuthGuard`

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: `mock:an@vku.edu.vn` → 200, JWT 3 phần, đăng nhập lại (khác hoa thường) → cùng `user.id`; Google ID Token hợp lệ (ký bằng khoá test) → định danh đúng, email chữ thường
> 2. **@auth**: không header / header sai dạng / không phải JWT / JWT ký bằng secret khác / `alg: none` / thiếu `sub` → 401; `DELETE /me` rồi dùng lại token cũ → 401
> 3. **@timeout**: mọi route < 5 ms ở chế độ mock; chế độ google chỉ gọi mạng khi tải chứng chỉ lần đầu
> 4. **@partial-fail**: hai lần đăng nhập đầu tiên chạy đua → không 500, vẫn một user; cấu hình sai → không khởi động, in lý do
> 5. **@token**: ID Token hết hạn / sai `aud` / sai `iss` / khoá lạ / payload bị sửa / `email_verified: false` → 401; JWT hết hạn → 401; log từ chối không chứa token hay email
> 6. **@db**: xoá tài khoản xoá luôn plan của người đó, plan người khác còn nguyên


#### P3-F03 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-3-auth-history/specs/F03-history.md); task: [3.4](#task-3-4), [3.5](#task-3-5), [3.6](#task-3-6).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm test` → `Test Files  15 passed (15)`, `Tests  126 passed (126)`
> - [ ] `npm run test:e2e` → `Test Files  4 passed (4)`, `Tests  36 passed (36)`
> - [ ] Chạy thật (`node dist/main.js` với `DATABASE_PATH` là file): đăng nhập → tạo plan → khởi động lại server → xem lại plan bằng token cũ vẫn 200
> - [ ] All API routes complete within deployment timeout — history < 5 ms, generate-plan chỉ thêm < 5 ms
> - [ ] Auth check at top of each protected handler — `JwtAuthGuard` trên `HistoryController`, `OptionalJwtAuthGuard` trên `generate-plan`

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: đăng nhập → tạo plan → danh sách có đúng `id`, `target_calories`, `created_at` ISO → xem lại bằng `id` ra đúng response lúc tạo
> 2. **@auth**: không token / token rác / JWT ký secret khác → 401; plan của người khác → 404 và không có trong danh sách của họ; `abc` → 400 khi đã đăng nhập, 401 khi chưa
> 3. **@timeout**: history < 5 ms; generate-plan không chậm hơn đáng kể
> 4. **@partial-fail**: bảng `plan_records` bị xoá → generate-plan vẫn 200, đủ 3 ngày, có cảnh báo "Chưa lưu được kế hoạch…"; token sai ở generate-plan → 401 và không lưu gì
> 5. **@token**: tài khoản đã xoá → token cũ gọi history → 401
> 6. **@db**: 55 plan → trả 50, mới nhất trước; hai plan cách nhau vài ms giữ đúng thứ tự; không token → không thêm dòng; `plan_json` không chứa chuỗi dị ứng/bệnh nền; xoá tài khoản → 0 dòng của người đó


#### P3-F04 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-3-auth-history/specs/F04-smoke-ci.md); task: [3.9](#task-3-9).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm run build && npm run test:smoke` → `Smoke test đạt: /health, đăng nhập giả lập, generate-plan, lịch sử.`
> - [ ] Kiểm ngược: đổi `user: Relation<User>` thành `user: User` trong `plan-record.entity.ts`, build lại → smoke test thoát mã 1, log có `ReferenceError: Cannot access 'User' before initialization`; trả lại như cũ → đạt
> - [ ] Sau khi push: run CI mới nhất của `Thien-Source` là `completed success` trên Node 24 và 26
> - [x] All API routes complete within deployment timeout — không sửa route
> - [x] Auth check at top of each protected handler — không sửa route

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: bản build lên được, 5 request đều đúng
> 2. **@auth**: bước lịch sử dùng JWT thật do server phát
> 3. **@timeout**: server không lên sau 20 giây → thất bại, không treo CI (job còn `timeout-minutes: 10`)
> 4. **@partial-fail**: server thoát sớm → báo ngay `Server thoát sớm (mã …)` kèm log, không chờ hết 20 giây
> 5. **@token**: không áp dụng
> 6. **@db**: migration chạy được trên bản build (bảng tồn tại, plan lưu và đọc lại được)


#### P3-F05 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-3-auth-history/specs/F05-docs.md); task: [3.7](#task-3-7), [9.5](#task-9-5).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] BRD ghi `**Phiên bản:** 2.4.0`, có FR-6.4 và `DELETE /api/v1/me` ở mục 6.3
> - [ ] `SETUP_CREDENTIALS.md` không còn chữ "Chưa có trong code"
> - [ ] `critical-constraints.md` có #1–#22; `auth-and-history.md` có trong `INDEX.md`; mọi `[[link]]` trỏ tới file có thật
> - [ ] PLAN.md: 3.1–3.9 đều `[x]`, có bước 5.7 (CORS)
> - [ ] README có mục Changelog `BRD v2.4.0`
> - [x] All API routes complete within deployment timeout — không áp dụng
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: `grep -c '^- \[x\] \*\*3\.' docs/PLAN.md` → `9`; `grep -c 'auth-and-history' docs/knowledge/wiki/INDEX.md` → `1`; `grep -cE '^\| (19|20|21|22) \|' docs/knowledge/wiki/critical-constraints.md` → `4`
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng
> 4. **@partial-fail**: `grep -o '\[\[[a-z-]*\]\]' docs/knowledge/wiki/*.md | sort -u` — mỗi tên có file `docs/knowledge/wiki/<tên>.md`
> 5. **@token**: không áp dụng
> 6. **@db**: không áp dụng


#### P4-F01 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-4-swap-feedback/specs/F01-calories-restrictions.md); task: [4.1](#task-4-1), [4.7](#task-4-7).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm run typecheck` sạch; `npm run build` sạch
> - [ ] `npm test` → `Test Files  19 passed (19)`, `Tests  183 passed (183)`
> - [ ] `npm run test:e2e` → `Tests  37 passed (37)`
> - [ ] `sample-plan.spec.ts`: 20 hồ sơ (18 của ma trận + 2 hồ sơ cực trị trong giới hạn BRD 6.1) — thực đơn mẫu khớp mục tiêu ±3 kcal, không dưới BMR
> - [ ] Prompt của `ai_workspace` giống hệt prompt backend cho cùng hồ sơ ví dụ (Task 9); `cd ai_workspace && npx tsc --noEmit` sạch
> - [ ] All API routes complete within deployment timeout — chế độ mẫu < 10 ms, Gemini tệ nhất ~30 s như trước
> - [x] Auth check at top of each protected handler — không đổi guard

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: hồ sơ nam vận động nhiều tăng cơ (mục tiêu 2806) → thực đơn mẫu mỗi ngày 2803–2809 kcal; khoảng calo trong prompt tính từ mục tiêu
> 2. **@auth**: không áp dụng
> 3. **@timeout**: Gemini hết giờ → không gọi lại (test cũ vẫn xanh qua `generateWithRetry()`)
> 4. **@partial-fail**: Gemini trả món có "Nước mắm" cho người dị ứng hải sản → gọi lại → thực đơn mẫu đã lọc, không còn tôm/cá/mắm; phần hạn chế không nhận ra → cảnh báo chung, không nhắc lại chữ
> 5. **@token**: không áp dụng
> 6. **@db**: không đổi schema; e2e lịch sử của giai đoạn 3 vẫn xanh


#### P4-F02 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-4-swap-feedback/specs/F02-client-plan.md); task: [4.8](#task-4-8).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm test` → `Test Files  20 passed (20)`, `Tests  196 passed (196)`
> - [ ] `npm run test:e2e` → `Tests  37 passed (37)`
> - [ ] `client-plan.spec.ts`: 10 test (plan hợp lệ; 409 hai kiểu; 400 sáu kiểu; `rebuildPlan` giữ `plan_id`, tính lại đi chợ và cảnh báo)
> - [ ] `history.service.spec.ts`: 9 test (thêm 3: cập nhật đúng chủ, bỏ qua plan chưa lưu, DB lỗi → false)
> - [x] All API routes complete within deployment timeout — chưa có route
> - [x] Auth check at top of each protected handler — chưa có route

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: plan server vừa trả, gửi lại nguyên vẹn → qua; `rebuildPlan` giữ `plan_id`
> 2. **@auth**: `update()` với người khác → plan của chủ không đổi
> 3. **@timeout**: không áp dụng
> 4. **@partial-fail**: DB lỗi khi cập nhật → `false`, không ném lỗi
> 5. **@token**: không áp dụng
> 6. **@db**: cập nhật đúng dòng, `plan_json` đọc lại khớp; plan chưa lưu → không thêm dòng


#### P4-F03 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-4-swap-feedback/specs/F03-meal-swap.md); task: [4.2](#task-4-2).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm test` → `Test Files  21 passed (21)`, `Tests  208 passed (208)`
> - [ ] `meal-swap.service.spec.ts`: 12 test
> - [ ] All API routes complete within deployment timeout — kho ~6 ms, Gemini tệ nhất 30 s
> - [x] Auth check at top of each protected handler — không có (endpoint dùng guard tuỳ chọn ở F06)

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: không Gemini → món khác, cùng bữa, cùng calo, `plan_id` giữ nguyên, 9 món khác tên nhau, danh sách đi chợ có nguyên liệu mới và không còn nguyên liệu riêng của món cũ; có Gemini → dùng món Gemini, gọi 1 lần
> 2. **@auth**: không áp dụng ở tầng service
> 3. **@timeout**: Gemini hết giờ → 1 lần gọi, dùng kho
> 4. **@partial-fail**: Gemini trả calo ngoài ±10% / khác bữa / trùng món / macro sai → gọi lại; trả món có hải sản cho người dị ứng hải sản → bị loại, log không nêu "hải sản" hay tên món; kho hết món phù hợp → 422
> 5. **@token**: khoá Gemini bị từ chối → xử lý như lỗi, dùng kho (đường chung `generateWithRetry()`, đã có test ở F01)
> 6. **@db**: không áp dụng


#### P4-F04 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-4-swap-feedback/specs/F04-exercise-swap.md); task: [4.3](#task-4-3).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm test` → `Test Files  22 passed (22)`, `Tests  216 passed (216)`
> - [ ] `exercise-swap.service.spec.ts`: 8 test
> - [ ] All API routes complete within deployment timeout — kho ~4 ms, Gemini tệ nhất 30 s
> - [x] Auth check at top of each protected handler — guard tuỳ chọn ở F06

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: "Squat tay không" (mức 2) → động tác chân mức 1, số hiệp ≤ 3, bữa ăn và `plan_id` giữ nguyên; có Gemini → dùng động tác Gemini đạt điều kiện
> 2. **@auth**: không áp dụng ở tầng service
> 3. **@timeout**: đường chung `generateWithRetry()` (test ở F01, F03)
> 4. **@partial-fail**: Gemini trả nhóm cơ khác / nhiều hiệp hơn / thêm tag `jumping` / trùng động tác → 2 lần gọi → kho mức 1; động tác đã nhẹ nhất → 422
> 5. **@token**: như F03
> 6. **@db**: không áp dụng


#### P4-F05 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-4-swap-feedback/specs/F05-feedback.md); task: [4.4](#task-4-4).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm test` → `Test Files  24 passed (24)`, `Tests  240 passed (240)`
> - [ ] `workout-rules.spec.ts`: 15 test (3 test dấu hiệu nguy hiểm); `feedback.service.spec.ts`: 9 test (2 test dấu hiệu nguy hiểm)
> - [ ] All API routes complete within deployment timeout — không Gemini ~4 ms; có Gemini tệ nhất 30 s
> - [x] Auth check at top of each protected handler — guard tuỳ chọn ở F06

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: rất mệt → ngày 2 mỗi động tác −1 hiệp, ngày 1 và 3 giữ nguyên, `plan_id` giữ; ăn nhiều + Gemini → ngày 2 có 3 món mới, tổng 1460 kcal, prompt ghi "khoảng 1462 kcal, trong khoảng 1399–1624"
> 2. **@auth**: không áp dụng ở tầng service
> 3. **@timeout**: đường chung `generateWithRetry()`
> 4. **@partial-fail**: Gemini lập ngày dưới BMR (1280 < 1399) hoặc không nhẹ hơn (1700 > 1624) → 2 lần gọi → giữ món cũ + `mealsNotRebalanced`; không có khoá → giữ món + cảnh báo
> 5. **@token**: như F03
> 6. **@db**: không áp dụng (ngày 3 lưu mới ở F06)
>
> Dấu hiệu nguy hiểm (#14): trả `safety_warning` (có số 115), ngày kế tiếp là ngày nghỉ, món ăn giữ nguyên dù chọn "ăn nhiều", Gemini **không** bị gọi; ghi đè cả "nhẹ nhàng" và các trạng thái khác; áp cả cho ngày 1 của plan mới khi feedback ngày 3.


#### P4-F06 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-4-swap-feedback/specs/F06-endpoints-e2e.md); task: [4.5](#task-4-5).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm run test:e2e` → `Test Files  5 passed (5)`, `Tests  58 passed (58)`
> - [ ] `npm test` → `Test Files  24 passed (24)`, `Tests  240 passed (240)`
> - [ ] `npm run build && npm run test:smoke` → `Smoke test đạt: /health, đăng nhập giả lập, generate-plan, lịch sử, đổi món, đổi bài tập, feedback.`
> - [ ] `npm run lint` không in cảnh báo nào
> - [ ] All API routes complete within deployment timeout — bảng độ trễ ở trên
> - [ ] Auth check at top of each protected handler — `OptionalJwtAuthGuard` ở cấp class

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**:
>    - đổi món → `plan_id` giữ, món khác, cùng calo;
>    - đổi bài → cùng nhóm cơ;
>    - feedback ngày 1 → ngày 2 ngắn hơn;
>    - ngày 3 → `plan_id` mới;
>    - qua SDK thật + server Gemini giả → món Gemini đề xuất, đúng 1 request, request có khối `du_lieu_nguoi_dung`
> 2. **@auth**: token sai → 401; đăng nhập → lịch sử cập nhật (xem lại bằng `GET /plans/history/:id` ra đúng plan mới); người khác gửi plan đó → plan của chủ không đổi; khách → không ghi gì
> 3. **@timeout**: server Gemini giả không trả lời → dùng kho, đúng 1 request
> 4. **@partial-fail**: 400 cho 7 kiểu request sai (`meal_id` sai dạng, plan sửa tay, `body_states` rỗng, ngày 4, thiếu `plan`, thiếu `profile`, `plan` không phải object); 409 khi hồ sơ đổi; 422 khi động tác đã nhẹ nhất
> 5. **@token**: token sai ở cả ba route → 401, không âm thầm bỏ qua lịch sử
> 6. **@db**: feedback ngày 3 → lịch sử có 2 plan, mới nhất trước; response và `plan_json` trong DB không chứa chuỗi dị ứng bí mật


#### P4-F07 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-4-swap-feedback/specs/F07-docs.md); task: [9.5](#task-9-5).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] BRD ghi `**Phiên bản:** 2.5.0`; NFR-4 không còn "250–600"
> - [ ] `critical-constraints.md` có #1–#25; `swap-and-feedback.md` có trong `INDEX.md`; mọi `[[link]]` trỏ tới file có thật; `wiki-triggers.md` không còn `api-routes.md`
> - [ ] PLAN.md: 4.1–4.5, 4.7, 4.8 là `[x]`; 4.6 là `[ ]`
> - [ ] README có mục Changelog `BRD v2.5.0`
> - [x] All API routes complete within deployment timeout — không áp dụng
> - [x] Auth check at top of each protected handler — không áp dụng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: các lệnh ở Task 9 in đúng số mong đợi
> 2. **@auth**: không áp dụng
> 3. **@timeout**: không áp dụng
> 4. **@partial-fail**: mọi `[[link]]` trong wiki có file tương ứng
> 5. **@token**: không áp dụng
> 6. **@db**: không áp dụng


#### P5-F01 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-5-frontend-foundation/specs/F01-backend-cors-fixtures.md); task: [5.7](#task-5-7), [5.8](#task-5-8).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm run fixtures:update` sinh đúng 14 file trong `frontend_app/test/fixtures/`; chạy lại lần hai không đổi file nào (`git status` sạch)
> - [ ] `npm test` → `Test Files  26 passed (26)`, `Tests  264 passed (264)`
> - [ ] `npm run test:e2e` → `Test Files  7 passed (7)`, `Tests  66 passed (66)`
> - [ ] Sửa tay một fixture → `npm run test:e2e` đỏ, thông báo "… đã cũ — chạy npm run fixtures:update"
> - [ ] `npm run typecheck`, `npm run build`, `npm run test:smoke`, `npm run lint` sạch
> - [ ] Không route nào đổi hành vi với request không có `Origin` (app mobile)

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: preflight từ `http://localhost:5000` xin `POST` + `Authorization` → 204, có `Access-Control-Allow-Origin` đúng origin và `Access-Control-Allow-Headers` chứa `Authorization` (`cors.e2e-spec.ts`)
> 2. **@auth**: origin lạ (`https://evil.example`) → không có `Access-Control-Allow-Origin`; request không có `Origin` → không có header CORS nào
> 3. **@config**: `CORS_ORIGINS=https://smartfit.example` → chỉ origin đó; `NODE_ENV=production` + trống → không header; `CORS_ORIGINS=*` → `createTestApp()` ném lỗi (backend không lên); unit test kiểm thêm origin có đường dẫn
> 4. **@contract**: 14 fixture khớp response thật; hợp đồng đổi → đỏ
> 5. **@timeout**: không có route mới; preflight không chạm service
> 6. **@partial-fail**: không áp dụng
> 7. **@token**: fixture `error_401` là response thật khi thiếu token
> 8. **@db**: không đổi schema


#### P5-F02 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-5-frontend-foundation/specs/F02-packages-platform.md); task: [5.1](#task-5-1), [5.2](#task-5-2).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `flutter pub get` thành công; `pubspec.lock` có `http`, `provider`, `shared_preferences`
> - [ ] `flutter analyze` → `No issues found!`
> - [ ] `flutter test test/config` → `All tests passed!` (2 test)
> - [ ] `plutil -lint ios/Runner/Info.plist macos/Runner/*.entitlements` → `OK`; `xmllint --noout android/app/src/{main,debug}/AndroidManifest.xml` sạch
> - [ ] `flutter build web --dart-define=API_BASE_URL=http://localhost:3000` → `✓ Built build/web`

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: `API_BASE_URL` đặt → dùng đúng giá trị, bỏ `/` cuối
> 2. **@platform**: không đặt → Android `10.0.2.2`, web/iOS/macOS `localhost`; chuỗi toàn khoảng trắng coi như không đặt
> 3. **@auth**: không áp dụng
> 4. **@timeout**: không áp dụng
> 5. **@partial-fail**: không áp dụng
> 6. **@token**: không áp dụng
> 7. **@db**: không áp dụng


#### P5-F03 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-5-frontend-foundation/specs/F03-dart-models.md); task: [5.3](#task-5-3).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `flutter analyze` → `No issues found!`
> - [ ] `flutter test test/models` → `All tests passed!` (12 test)
> - [ ] Mọi fixture plan (`generate_plan`, `meals_swap`, `exercises_swap`, `feedback`, `feedback_danger`) đi vòng tròn `fromJson` → `toJson` bằng đúng JSON gốc
> - [ ] Mã lạ, thiếu trường, sai kiểu → `FormatException` có tên trường

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: vòng tròn cho 5 fixture plan, `profile`, `auth_login`, `history`, `health`
> 2. **@numbers**: `calories` vẫn `int`, `protein_g` vẫn `double` sau vòng tròn
> 3. **@invalid**: `meal_type: "Bữa sáng"` → `FormatException` chứa `meal_type`; thiếu `daily_target`; `plan_id: 123`
> 4. **@codes**: `FeedbackAnswers` ghi `joint_pain`, `on_plan` (mã có dấu gạch dưới)
> 5. **@auth**, **@timeout**, **@partial-fail**, **@token**, **@db**: không áp dụng


#### P5-F04 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-5-frontend-foundation/specs/F04-api-client.md); task: [5.4](#task-5-4).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `flutter analyze` → `No issues found!`
> - [ ] `flutter test test/services` → `All tests passed!` (13 test)
> - [ ] Mọi mã lỗi của fixture (`error_400` … `error_422`) thành đúng lớp `ApiException`
> - [ ] Không có `print`/`debugPrint`/`log` nào trong `lib/services/`: `grep -rn "print\|log(" lib/services` không ra gì

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: `generatePlan` gửi POST JSON UTF-8 đúng hồ sơ (kể cả "Hải sản"), không có `Authorization` khi là khách; đổi món/đổi bài/feedback gửi đúng body; đăng nhập, xoá tài khoản (204), plan trong lịch sử, `/health`
> 2. **@auth**: có token → `Authorization: Bearer …`; 401 có gửi token → `onUnauthorized` gọi đúng 1 lần; 401 khi đăng nhập (không gửi token) → không gọi
> 3. **@timeout**: server không trả lời → `ApiTimeoutException` (timeout 20 ms trong test)
> 4. **@partial-fail**: 500, HTML 502, `not json`, `{"plan":{"plan_id":1}}`, mảng → `ServerException`; `ClientException` → `NetworkException`
> 5. **@token**: 409/422 hiện đúng câu tiếng Việt của server; 400 giữ `details`, `message` không chứa tên trường
> 6. **@encoding**: response không có `Content-Type` vẫn đọc đúng tiếng Việt
> 7. **@db**: không áp dụng


#### P5-F05 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-5-frontend-foundation/specs/F05-providers.md); task: [5.5](#task-5-5).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `flutter analyze` → `No issues found!`
> - [ ] `flutter test test/providers` → `All tests passed!` (14 test)
> - [ ] Tạo plan → khoá `smartfit.plan.v1` chứa đúng JSON fixture; provider mới tạo lại từ cùng `SharedPreferences` đọc được đúng plan
> - [ ] Bản lưu hỏng không làm crash, bị xoá

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: tạo plan → lưu cả hai khoá → mở lại đọc đúng; đổi món, đổi bài, feedback thay plan và gửi đúng plan đang có
> 2. **@auth**: đăng nhập → token gắn vào request sau và được lưu; mở lại app đọc token; xoá tài khoản → `DELETE /api/v1/me` + đăng xuất
> 3. **@token**: server 401 khi có token → đăng xuất, xoá khoá, `accessToken` = null; đăng nhập lại thất bại khi đang đăng nhập → giữ phiên cũ
> 4. **@partial-fail**: 409 → ném `PlanOutdatedException`, plan cũ giữ nguyên, `busy` về `false`
> 5. **@busy**: đang chờ server → `busy`; gọi thêm bị bỏ qua (chỉ 1 request), trạng thái báo `[true, false]`
> 6. **@db**: plan hỏng → xoá plan giữ hồ sơ; hồ sơ hỏng → xoá hết; token không có user → xoá hết
> 7. **@timeout**: như F04


#### P5-F06 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-5-frontend-foundation/specs/F06-main-shell-ci.md); task: [5.6](#task-5-6), [5.9](#task-5-9).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `flutter analyze` → `No issues found!`
> - [ ] `flutter test` → `+44: All tests passed!` (2 config + 12 model + 13 ApiClient + 14 provider + 3 widget)
> - [ ] `flutter build web` thành công
> - [ ] Workflow `Frontend CI` xanh trên GitHub sau khi push

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: máy chưa có gì → Onboarding ("Thiết lập mục tiêu 3 ngày"), không request nào
> 2. **@offline**: có plan + hồ sơ đã lưu → Dashboard, không request nào
> 3. **@partial-fail**: plan đã lưu hỏng → Onboarding, không crash
> 4. **@auth**, **@timeout**, **@token**, **@db**: không áp dụng (đã test ở F04, F05)


#### P5-F07 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-5-frontend-foundation/specs/F07-docs.md); task: [9.5](#task-9-5).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `grep -rn "chưa có — tạo ở giai đoạn 5" docs/knowledge/` không ra dòng nào
> - [ ] `critical-constraints.md` có #26–#29; `INDEX.md` có `[[flutter-ui]]`
> - [ ] PLAN.md: 5.1–5.9 đã tích; 6.6, 6.7, 9.2, 9.3 cập nhật
> - [ ] README: cách chạy app với backend trên từng nền tảng; changelog có giai đoạn 5
> - [ ] CLAUDE.md không còn câu "no `http`, `provider`, or `shared_preferences`" hay "Not yet wired"

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@links**: mọi `[[...]]` trong `flutter-ui.md` trỏ tới bài có thật (`critical-constraints`, `plan-data-contract`, `swap-and-feedback`, `auth-and-history`)
> 2. **@commands**: lệnh trong README/CLAUDE.md chạy được như ghi (`flutter test`, `npm run fixtures:update`)
> 3. Các nhãn **@auth**, **@timeout**, **@partial-fail**, **@token**, **@db**: không áp dụng


#### P6-F01 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-6-connect-mvp/specs/F01-backend-profile-safety.md); task: [6.9](#task-6-9).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm run fixtures:update` sinh lại `profile.json`, `error_400.json` và thêm `restriction_labels.json`; chạy lại lần hai không đổi file
> - [ ] `npm test` → `Tests  268 passed (268)`; `npm run test:e2e` → `Tests  74 passed (74)`
> - [ ] `npm run typecheck`, `build`, `test:smoke`, `lint` sạch
> - [ ] `flutter analyze` sạch, `flutter test` → `+45: All tests passed!`

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: hồ sơ hợp lệ vẫn tạo plan; mang thai + Duy trì → 200 kèm cảnh báo `pregnancy`, response không có `pregnant_or_breastfeeding`
> 2. **@validation**: tuổi 17, nam + mang thai, `pregnant_or_breastfeeding: 'có'` → 400
> 3. **@safety**: BMI 16,4 + `cut` → 400 câu có "thiếu cân"; mang thai + `cut` → 400 câu có "mang thai"; không gọi Gemini
> 4. **@boundary**: BMI 18,46 bị chặn, 18,51 qua (unit)
> 5. **@adjust**: đổi bài với hồ sơ thiếu cân + `cut`, feedback với hồ sơ 17 tuổi → 400
> 6. **@contract**: vòng tròn `Profile` với fixture mới; hồ sơ lưu trước v2.6.0 (thiếu trường) đọc thành `false`
> 7. **@auth**, **@timeout**, **@token**, **@db**: không đổi


#### P6-F02 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-6-connect-mvp/specs/F02-backend-exercise-level.md); task: [6.10](#task-6-10).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `npm test` → `Tests  320 passed (320)`; `npm run test:e2e` → `Tests  74 passed (74)`, fixture không đổi
> - [ ] `npm run typecheck`, `build`, `test:smoke`, `lint` sạch; `cd ai_workspace && npx tsc --noEmit` sạch
> - [ ] Prompt `ai_workspace` trùng từng dòng với `buildPlanPrompt()` cho hồ sơ thử nghiệm

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@happy**: bảng `maxExerciseLevel` 10 hồ sơ; hồ sơ mặc định (mức 2) giữ nguyên thực đơn mẫu
> 2. **@elderly**: 65 tuổi ít vận động → mọi động tác mức 1, không `jumping`, cùng nhóm cơ, giữ số hiệp
> 3. **@gemini**: kết quả Gemini có động tác mức 2 cho người 60 tuổi → hạ mức, Gemini chỉ được gọi 1 lần
> 4. **@injury**: hạ mức vẫn tránh chấn thương — ca chỉ còn Bird-dog (quỳ gối) bị bỏ thay vì chọn
> 5. **@swap**: Gemini đề xuất "Lunge lùi" (mức 2) cho người 65 tuổi → bị từ chối 2 lần → 422
> 6. **@feedback**: đau khớp với giới hạn mức 1 → động tác thay đều mức 1
> 7. **@prompt**: dòng luật mức 1/mức 2/không có; luật mang thai nằm sau khối dữ liệu người dùng; prompt đổi bài có cùng luật
> 8. **@pregnancy**: mang thai → cảnh báo + mức 1
> 9. **@auth**, **@token**, **@db**: không đổi


#### P6-F03 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-6-connect-mvp/specs/F03-app-logic.md); task: [6.2](#task-6-2), [6.5](#task-6-5), [6.11](#task-6-11).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `flutter analyze` → `No issues found!`
> - [ ] `flutter test` → `+67: All tests passed!` (giao diện cũ vẫn chạy)

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@rules**: giới hạn tuổi/chiều cao/cân nặng, dấu phẩy thập phân; BMI 18,46 bị chặn, 18,51 qua; mang thai → chặn; hồ sơ 17 tuổi / thiếu cân + Giảm mỡ / nam + mang thai có lỗi
> 2. **@chips**: mọi chip dị ứng/chấn thương ⊆ nhãn backend; tắt công tắc → rỗng; ghép/tách vòng tròn; chuỗi gõ tay cũ tách được; > 300 ký tự báo lỗi
> 3. **@schedule**: 23:30 tạo plan → 0:01 hôm sau là ngày 2; < 1, > 3; qua tháng; lưu/đọc lại
> 4. **@provider**: tạo plan → lịch hôm nay; mở hôm sau → ngày 2; đổi món giữ lịch; feedback ngày 3 → plan mới bắt đầu ngày mai; plan giai đoạn 5 chưa có lịch → hôm nay; nháp khác hồ sơ → chờ, đổi món vẫn gửi hồ sơ cũ; nháp giống → xoá; `generate()` bỏ nháp; hồ sơ 17 tuổi → bỏ plan giữ hồ sơ
> 5. **@grocery**: đã mua, đã có sẵn, mở lại còn; khoá gồm lượng; plan mới → xoá; bản lưu của plan khác / hỏng → bỏ
> 6. **@auth**, **@timeout**, **@token**: không đổi


#### P6-F04 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-6-connect-mvp/specs/F04-app-screens.md); task: [6.1](#task-6-1), [6.2](#task-6-2), [6.3](#task-6-3), [6.4](#task-6-4), [6.5](#task-6-5), [6.6](#task-6-6), [6.7](#task-6-7), [7.1](#task-7-1), [7.2](#task-7-2).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `flutter analyze` → `No issues found!`; `flutter test` → `+89: All tests passed!`
> - [ ] `flutter test integration_test -d emulator-5554` (backend giả lập đang chạy) → `+3: All tests passed!`
> - [ ] Không còn `meal_plan.dart`, `feedback_bottom_sheet.dart`; không còn chữ "15/9/2026", "1.850", "168 cm • 62 kg" viết cứng

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@onboarding**: tiếp tục khoá tới khi hợp lệ; 17 tuổi báo lỗi; ô mang thai chỉ với nữ; thiếu cân → thẻ Giảm mỡ có biểu tượng khoá, bấm không chọn được; mang thai → khoá Giảm mỡ, gửi kèm cờ; bước 3 ghép đúng chuỗi; Back quay lại bước, giữ dữ liệu; điền sẵn hồ sơ cũ
> 2. **@dashboard**: mở đúng ngày hôm nay, bữa sáng, tổng calo, lưu ý (2), nhãn thực đơn mẫu; đổi ngày; 2 ngày sau → Ngày 3; 4 ngày sau → dải "đã hết" + tạo mới; đổi món gọi API và hiện món mới; 409 → câu server + "Tạo mới", plan giữ nguyên; hồ sơ nháp → dải nhắc
> 3. **@grocery**: nhóm BRD, không có "Thêm nguyên liệu"; tích tăng bộ đếm, mở lại còn; đã có sẵn → ẩn, "Cần mua" trả lại; tìm kiếm, lọc
> 4. **@profile**: sửa mục tiêu → nháp (hồ sơ của plan giữ nguyên), ẩn calo cũ, tạo mới dùng nháp
> 5. **@app**: chưa có plan → Onboarding, không gọi mạng; có plan → Dashboard, không gọi mạng; plan hỏng → Onboarding; hồ sơ 17 tuổi → Onboarding báo lỗi; Onboarding → màn chờ → Dashboard, body đúng hạn chế và cờ; lỗi → "Chưa tạo được kế hoạch" → Thử lại → Dashboard; 4 tab
> 6. **@device** (integration_test, tay): điền Onboarding → backend thật → Dashboard → đổi món
> 7. **@auth**, **@token**, **@db**: không đổi


#### P6-F05 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-6-connect-mvp/specs/F05-branding.md); task: [6.8](#task-6-8).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `tool/update_icons.sh` chạy trên macOS, sinh lại đúng từng byte
> - [ ] `plutil -lint ios/Runner/Info.plist` OK; `xmllint --noout android/app/src/main/AndroidManifest.xml android/app/src/main/res/*/*.xml` sạch
> - [ ] `flutter build apk --debug` và `flutter build web` thành công
> - [ ] Trên máy ảo Android: launcher hiện "SmartFit AI" với icon mới; màn khởi động nền xanh; thanh trạng thái sáng, thấy giờ và pin

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@icon**: `sips -g hasAlpha assets/icon/icon.png` → `no`; icon_foreground → `yes`
> 2. **@android**: APK debug build được; `aapt2 dump xmltree … AndroidManifest.xml` có `label` "SmartFit AI"
> 3. **@device**: ảnh chụp launcher, màn khởi động, Onboarding (thanh trạng thái sáng)
> 4. **@web**: `build/web/index.html` có `<title>SmartFit AI</title>`
> 5. **@auth**, **@timeout**, **@token**, **@db**: không áp dụng


#### P6-F06 — tiêu chí gốc

Nguồn: [spec](superpowers/plans/phase-6-connect-mvp/specs/F06-docs.md); task: [9.5](#task-9-5).

**Definition of Done (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> - [ ] `grep -c "2.6.0" BRD.md` ≥ 10; `grep -c "^| 3[0-2] |" docs/knowledge/wiki/critical-constraints.md` = 3
> - [ ] `grep -rn "meal_plan.dart\|feedback_bottom_sheet" CLAUDE.md docs/knowledge/wiki/flutter-ui.md` không ra dòng nào
> - [ ] PLAN: `grep -c "^- \[x\] \*\*6\." docs/PLAN.md` = 11

**Test Checklist (nguyên văn, trạng thái checkbox cũ không có hiệu lực):**

> 1. **@links**: mọi `[[...]]` trong bài wiki sửa trỏ tới bài có thật
> 2. **@numbers**: số test trong wiki/README khớp lần chạy cuối (89 Flutter, 320 unit, 74 e2e)
> 3. Các nhãn khác: không áp dụng

## 6. Completed Work

Các task sau DONE trong scope được định nghĩa ở mục5; không suy rộng thành app hoàn chỉnh.

- Phase0: [0.1](#task-0-1) SDK/auth/DB và roadmap trong CLAUDE; [0.2](#task-0-2) Dart SDK trong wiki; [0.3](#task-0-3) Yêu cầu lưu trữ SQLite; [0.4](#task-0-4) HTTP status POST; [0.5](#task-0-5) Health configuration; [0.6](#task-0-6) Hướng dẫn Gemini credentials; [0.7](#task-0-7) README liên kết roadmap.
- Phase1: [1.1](#task-1-1) BRD và quyết định D1–D4; [1.2](#task-1-2) Hợp đồng adjustment API; [1.4](#task-1-4) Wiki về privacy và safety.
- Phase2: [2.1](#task-2-1) Ma trận BMR/TDEE; [2.2](#task-2-2) Plan validation tests; [2.3](#task-2-3) Generate retry/fallback tests; [2.4](#task-2-4) Generate HTTP E2E; [2.5](#task-2-5) SDK thật với Gemini giả.
- Phase3: [3.1](#task-3-1) TypeORM và SQLite driver; [3.2](#task-3-2) Entities và migrations; [3.3](#task-3-3) Backend Google/mock auth và JWT; [3.4](#task-3-4) JWT guards; [3.5](#task-3-5) History list/detail và ownership; [3.6](#task-3-6) Auth/history/database tests; [3.7](#task-3-7) Backend Google setup docs; [3.8](#task-3-8) Backend xóa tài khoản.
- Phase4: [4.1](#task-4-1) Restriction matcher và fallback filtering; [4.2](#task-4-2) Backend meal swap; [4.3](#task-4-3) Backend exercise swap; [4.4](#task-4-4) Backend feedback; [4.5](#task-4-5) Adjustment HTTP/SDK/smoke tests; [4.7](#task-4-7) Calorie bounds và sample scaling; [4.8](#task-4-8) Adjustment lưu history.
- Phase5: [5.1](#task-5-1) Flutter packages; [5.2](#task-5-2) API URL và quyền mạng; [5.3](#task-5-3) Dart API models; [5.4](#task-5-4) ApiClient; [5.5](#task-5-5) Plan/Auth providers và persistence; [5.7](#task-5-7) CORS.

Macro balancing sau phase6 đã có sample/pool tests và wiki constraint#33; giữ là bổ sung của4.7, không thêm task vào mẫu số.

- Phase 6: [6.3](#task-6-3) Loading tạo plan thật (N01) và [6.1](#task-6-1) Onboarding/validation/safety (N02), ngày 14/10/2026.

- N03 (30/10/2026): [6.4](#task-6-4), [6.5](#task-6-5), [7.1](#task-7-1), [7.2](#task-7-2) DONE; device/full integration vẫn thuộc 6.7/9.4.

## 7. Remaining Work

- **PARTIAL:** [5.10](#task-5-10), [6.6](#task-6-6), [1.3](#task-1-3), [3.9](#task-3-9), [4.9](#task-4-9), [6.7](#task-6-7), [6.8](#task-6-8), [6.9](#task-6-9), [6.10](#task-6-10), [8.1](#task-8-1), [8.2](#task-8-2), [9.4](#task-9-4), [9.5](#task-9-5).
- **NOT STARTED:** [4.6](#task-4-6), [8.3](#task-8-3), [8.4](#task-8-4), [9.6](#task-9-6).
- **BLOCKED:** [5.8](#task-5-8).
- **BUGGY:** Không còn task thuộc nhóm này sau N05; các cổng Android/triển khai vẫn nằm trong PARTIAL/UNVERIFIED.
- **UNVERIFIED:** [2.6](#task-2-6), [5.9](#task-5-9), [9.1](#task-9-1), [9.2](#task-9-2), [9.3](#task-9-3).

Không nâng trạng thái2.6/5.9 từ workflow file; cần run đúng commit. Deploy ngoài repo có thể tồn tại nhưng9.1–9.3 vẫn UNVERIFIED tới khi có endpoint/config/result. 4.6 tùy chọn không chặn MVP.

## 8. Known Bugs & Technical Debt

| ID | Priority | Evidence / tác động | Task |
|---|---|---|---|
| A01 | P0 — đã sửa N01 | GeneratingPlanScreen gọi API thật, chờ lưu trước navigation; widget và HTTP local tests pass | [6.3](#task-6-3) |
| A02 | P1 — đã sửa N02 | Form ba bước, validators/safety/D5, không defaults/fallback; unit/widget/live HTTP pass | [6.1](#task-6-1) |
| A03 | Đã sửa N05 | Warning dialog + bản lưu, danger bypass AI/rest; unit/E2E/widget PASS, device UNVERIFIED | [7.3](#task-7-3) |
| A04 | Đã sửa N05 | Chỉ ngày tiếp theo, eating qua API, SQLite lock + retry, day3 queue/activation/history; HTTP fullflow PASS | [7.3](#task-7-3) |
| A05 | Đã sửa N03 | Route/detail/swap dùng meal_id thật, có widget tests | [7.1](#task-7-1) |
| A06 | Đã sửa N03 | UI đọc API plan và thay toàn response; không dùng shared mock workout | [7.2](#task-7-2) |
| A07 | P1 | Google/delete buttons chỉ navigate, không auth/DELETE/signout | [8.1](#task-8-1), [8.2](#task-8-2) |
| A08 | Đã sửa N03 | UI dùng meals và grocery_list từ response, swap đồng bộ qua provider | [6.4](#task-6-4), [6.5](#task-6-5) |
| A09 | P2 — checklist đã nối N03 | N04 sửa profile/startup; unit/widget pass, Android runtime còn UNVERIFIED | [6.2](#task-6-2), [6.5](#task-6-5), [5.6](#task-5-6) |
| A10 | P2 | Fixture script target thiếu; không gate response HTTP vs fixture | [5.8](#task-5-8) |
| A11 | P2 | Có widget tests N01/N02; còn thiếu test toàn UI/device và integration_test | [6.6](#task-6-6), [6.7](#task-6-7) |
| A12 | P2 | Workspace model/timeout/safety prompt lệch backend | [1.3](#task-1-3), [4.9](#task-4-9), [6.10](#task-6-10) |
| A13 | P2 | Lint2 PropertyEscape errors ở ignored local.properties;7warnings gồm OldTargetApi,ObsoleteSdkInt,5IconLauncherShape | [5.10](#task-5-10), [6.8](#task-6-8), [9.3](#task-9-3) |
| A14 | P2 | Release signing debug và application ID com.example.my_ai_app | [9.3](#task-9-3) |
| A15 | P2 | CI backend thiếu typecheck/lint/fixture-only trigger; frontend không build APK | [2.6](#task-2-6), [5.9](#task-5-9) |
| A16 | P3 | Hai service/model systems; model cũ toJson rỗng, SmartFitService không caller UI | [6.7](#task-6-7) |
| A17 | P2 | Docs mô tả89tests/UI tích hợp; checkout64tests/UI mock; brainstorm references chưa có file | [9.5](#task-9-5) |

Bugs chức năng là findings từ đường xử lý source trong audit, chưa tái hiện bằng thao tác emulator ở phiên đó. Lint lỗi local configuration không đồng nghĩa APK build fail. Chưa có dữ liệu memory/frame/coverage/live latency để khẳng định pass hoặc lỗi performance. Giữ constraints privacy, injection và auth của BRD/wiki; không coi dev mock secret là production credential.

## 9. Dependencies

Dependency từng task ở mục5 là quan hệ kỹ thuật, không ép thứ tự số tăng. Có thể dùng phần backend của6.9/6.10 đã verified để nối UI trong khi hoàn thiện fixture/measurement; điều đó không đổi trạng thái task cha. Một prerequisite PARTIAL cần kiểm phần API/contract cần dùng; không tuyên bố milestone đạt chỉ vì dependency có file.

Chuỗi chính: contract/validation → backend/auth/adjustment → model/client/provider → form/generate/plan → grocery/profile/calendar/swap → feedback/auth/history → acceptance/deploy. Fixture gate5.8 và tests6.6 phải được phục hồi trước khi chốt integration6.7.

Dependency feature gốc vẫn nằm trong project.json từng phase:

- [phase-1-api-contract/project.json](superpowers/plans/phase-1-api-contract/project.json): F02 cần F01; F03 cần F02; F04 cần F02; F05 cần F02, F04; F06 cần F03, F05; F07 cần F06.
- [phase-2-backend-tests/project.json](superpowers/plans/phase-2-backend-tests/project.json): F04 cần F02; F05 cần F01, F02, F03, F04; F06 cần F05.
- [phase-3-auth-history/project.json](superpowers/plans/phase-3-auth-history/project.json): F02 cần F01; F03 cần F02; F04 cần F03; F05 cần F04.
- [phase-4-swap-feedback/project.json](superpowers/plans/phase-4-swap-feedback/project.json): F02 cần F01; F03 cần F02; F04 cần F02; F05 cần F03; F06 cần F03, F04, F05; F07 cần F06.
- [phase-5-frontend-foundation/project.json](superpowers/plans/phase-5-frontend-foundation/project.json): F03 cần F01; F04 cần F02, F03; F05 cần F04; F06 cần F05; F07 cần F06.
- [phase-6-connect-mvp/project.json](superpowers/plans/phase-6-connect-mvp/project.json): F02 cần F01; F03 cần F01; F04 cần F03; F05 cần F04; F06 cần F05.

## 10. Next Implementation Priorities

N01–N10 là work packages ánh xạ69 task hiện có; không có checkbox DONE riêng, không tăng denominator. Ưu tiên N01–N06 để khôi phục Flutter↔backend; N06 chuẩn bị sớm và khóa nghiệm thu sau khi UI được nối. Tài liệu này không cấp quyền commit/push/deploy.

| ID | Priority / Size | Phạm vi task, việc cần làm | Dependency | Acceptance criteria |
|---|---|---|---|---|
| N01 — DONE | P0 / L | [6.1](#task-6-1), [6.3](#task-6-3): Profile → PlanProvider.generate; bỏ mock loading | API/models/providers hiện có | Profile đổi request; chỉ success mới mở màn kết quả plan thật; error/retry/busy; không timer giả; [evidence](#n01) |
| N02 — DONE | P1 / M | [6.1](#task-6-1), [6.9](#task-6-9), [6.10](#task-6-10): Áp form rules/D5/pregnancy/disclaimer | Làm cùng N01, dùng backend safety đã kiểm | Ba bước; ranges; rawBMI; khóa cut; toggleoff,Other≤300; chips khớp backend; [evidence](#n02) |
| N03 — DONE | P1 / L | [6.4](#task-6-4), [6.5](#task-6-5), [6.7](#task-6-7), [7.1](#task-7-1), [7.2](#task-7-2): UI API models/PlanProvider; đúng meal/exercise IDs | N01,N02 | N03 widget tests/analyze/full tests/APK pass; 3×3meals, fullplan/grocery, 409regenerate/422keep, không shared mock state; device gate ở 6.7 còn PARTIAL |
| N04 — PARTIAL | P1 / M | [5.6](#task-5-6), [5.10](#task-5-10), [6.2](#task-6-2), [6.5](#task-6-5), [6.11](#task-6-11): Startup/profile/grocery/schedule persistence | N03 | Offline savedplan; corrupt no crash; draft riêng; bought/have persisted; calendar/resume/expiry |
| N05 | DONE, automated scope / L | [7.3](#task-7-3): Feedback API/safety/nextday/day3/persistent lock | N03,N04 | Đạt UI/API/SQLite/local lifecycle; [evidence](N05_FEEDBACK.md). Pixel 2/Groq live UNVERIFIED |
| N06 | P2 / M | [5.8](#task-5-8), [6.6](#task-6-6), [6.7](#task-6-7), [9.4](#task-9-4): Fixture gate, widget/integration tests | Chuẩn bị ngay; final gate sau N01–N05 | HTTP fixtures deterministic; sửa fixture fail; widget request/error/safety; Android UI→backend fullflow |
| N07 | P1 / L | [8.1](#task-8-1), [8.2](#task-8-2), [8.3](#task-8-3), [8.4](#task-8-4): Mock/Google login, logout/delete/history và setupdocs | N03,N04 | OAuth/mock qua provider; DELETE thật;401loginagain; list/detail/crossdevice đúng owner |
| N08 | P2 / M | [1.3](#task-1-3), [4.9](#task-4-9), [6.10](#task-6-10), [9.5](#task-9-5): Workspace đồng bộ backend; phép đo AI thật; docs thực trạng | Backendprompt; app N03–N05 khi nghiệm thu | Cùng profile→prompt cùng rules; log measurement/config/result; docs không claim sai |
| N09 | P2 / M | [2.6](#task-2-6), [5.9](#task-5-9), [5.10](#task-5-10), [6.8](#task-6-8), [9.3](#task-9-3): Lint,releaseID/signing và CI gates | N06 | Lint0errors; release phù hợp; typecheck/lint/APK/fixturestrigger; run đúng commit verified |
| N10 | P1 / L | [9.1](#task-9-1), [9.2](#task-9-2), [9.3](#task-9-3), [9.4](#task-9-4), [9.5](#task-9-5), [9.6](#task-9-6): Deploy/storage/full acceptance/screenshots/slides/video | N05–N09; quyền deploy riêng | HTTPS; restart history bền; cả mock/real fullflow; artifact/checklist và demo evidence |

<a id="n01"></a>

### N01 — Onboarding gọi backend thật (14/10/2026)

- [x] **Status: DONE** trong phạm vi tạo/lưu/hiển thị kết quả tối thiểu. Task 6.3 được nâng DONE; 6.1 giữ BUGGY vì còn N02. N01 không thêm task vào denominator 69.
- **Code:** OnboardingProvider.toProfile ánh xạ giới tính/activity/goal và restrictions; RestrictionsScreen truyền snapshot Profile qua route; GeneratingPlanScreen dùng PlanProvider hiện có, spinner theo request, lỗi ApiException và retry cùng hồ sơ; chống retry lặp/provider busy; không navigate khi lỗi hoặc dispose. Không thêm client/provider mới, không đổi backend contract.
- **Integration:** POST /api/v1/generate-plan → ApiClient parse → PlanProvider lưu plan/profile/schedule → /plan/3day (GeneratedPlanScreen chỉ đọc plan thật, warnings/source). Response sample từ backend HTTP200/no-key là response hợp lệ, không phải client fallback khi API lỗi. Không nối dashboard/swap/grocery của N03.
- **Tests:** [onboarding mapping tests](../frontend_app/test/providers/onboarding_provider_test.dart), [widget flow/error/retry tests](../frontend_app/test/screens/generating_plan_screen_test.dart), [live HTTP tests](../frontend_app/test/services/n01_backend_live_test.dart). Đã kiểm thao tác form làm đổi JSON request, response mới lưu, dữ liệu restore đúng, loading không tự hoàn tất sau 8 giây, network/timeout/400/500/badJSON không navigation/mock, retry, duplicate tap và disposed screen.
- **Commands/result:** flutter analyze --no-pub sạch; flutter test --no-pub --reporter expanded --dart-define=N01_BACKEND_URL=http://127.0.0.1:3998 **78/78 PASS**; flutter build apk --debug --no-pub **PASS**. Backend bản build chạy local riêng, AUTH_MODE=mock, GEMINI_API_KEY rỗng, DATABASE_PATH=:memory:, health được kiểm trước request. Hai profiles trả plan IDs/target khác; live widget loading → HTTP → persistence → màn kết quả pass.
- **Acceptance:** ánh xạ đúng contract, reuse provider/client, loading/error/retry, persistence và success-only navigation đều đạt bằng unit/widget/live HTTP trên host; không thay model/mock khi API lỗi. Các tests/provider hiện có vẫn pass.
- **UNVERIFIED:** thao tác APK trên emulator/điện thoại và Gemini/Google thật/production. Không tuyên bố device hoặc AI end-to-end nghiệm thu; việc đó thuộc các gate N06/N10.
- **Còn lại ngoài N01:** form vẫn bốn bước/defaults và thiếu pregnancy/safety/D5 (N02); màn kết quả chỉ đọc, chưa dùng shell/dashboard cũ, swap/grocery/profile/calendar vẫn chờ N03–N04. Các task khác giữ baseline, không tự tick.
- **Tiếp theo:** N02, sau đó N03; không triển khai tiếp tự động trong lượt N01.

<a id="n02"></a>

### N02 — Onboarding, validation và safety (14/10/2026)

- [x] **Status: DONE** cho phạm vi frontend Onboarding. Task6.1 BUGGY→DONE;6.6 NOT STARTED→PARTIAL nhờ tests form/FakeBackend. 6.9/6.10 giữ PARTIAL vì exporter/fixture và workspace prompt/live measurement ngoài N02 chưa đạt. Không đổi N01 hoặc task không liên quan.
- **Luồng:** cơ thể → mục tiêu & vận động → hạn chế → N01 Profile/PlanProvider/API/persistence/kết quả thật. Raw text, gender/pregnancy, goal/activity, toggle/chips/Khác được giữ trong OnboardingProvider qua Back/Next và backend-error/Retry. Không timer/mock fallback/client/provider/dependency mới; backend không sửa.
- **Validation/safety và nguồn:** dùng profile_rules.dart, restriction_options.dart; BRD FR-1.1–1.4/§6.1 và backend CreatePlanDto/profile-safety. Tuổi nguyên18–100, cao100–250cm,nặng30–250kg; nhận dấu phẩy decimal; số không hữu hạn bị chặn như IsNumber backend; required/unknown selections chặn. BMI chưa làm tròn<18.5 hoặc pregnancy khóa Giảm mỡ; male+pregnancy chặn và không tự xóa flag/đổi goal để vượt luật.
- **D5:** ba công tắc mặc định tắt; nhiều chip từ nhãn backend + Khác; compose/trim bằng helper hiện có; bộ đếm và lỗi≤300 tính cả chip/separator/phần Khác; không truncate; tắt toggle/Khác không mất dữ liệu nhưng phần tắt không gửi. Disclaimer tham khảo và cảnh báo mock chưa điều chỉnh theo bệnh nền; không phát minh chế độ ăn/chay hoặc ngưỡng sức khỏe mới.
- **Request gate:** form chỉ submit khi tất cả criteria hợp lệ; loading route cũng kiểm profileProblems trước HTTP; _openingPlan và N01 in-flight/busy guards ngăn request lặp; failure không navigate, dữ liệu còn để sửa/retry.
- **Files/tests:** [provider](../frontend_app/lib/providers/onboarding_provider.dart), [body](../frontend_app/lib/screens/onboarding/basic_info_screen.dart), [goal/activity](../frontend_app/lib/screens/onboarding/activity_screen.dart), [restrictions](../frontend_app/lib/screens/onboarding/restrictions_screen.dart), [rules](../frontend_app/lib/models/profile_rules.dart), [unit validation](../frontend_app/test/providers/onboarding_validation_test.dart), [widget N02](../frontend_app/test/screens/onboarding_n02_test.dart). N01 tests giữ assertions request/error/retry/persistence/navigation, cập nhật thao tác cho layout3bước và dữ liệu hợp lệ explicit thay default.
- **Kiểm chứng:** flutter analyze --no-pub: sạch; flutter test --no-pub --reporter expanded --dart-define=N01_BACKEND_URL=http://127.0.0.1:3998: **108/108 PASS,0FAIL**; flutter build apk --debug --no-pub: **PASS**. Unit có boundary/blank/NaN/Infinity/unknown/BMI/pregnancy/300; widget viewport Pixel2 411×731dp có giữ dữ liệu/error-clear/submit duplicate/backend failure/N01 regression; HTTP local thật kiểm profile/pregnancy/restrictions/response/persistence và live widget navigation. Backend mock-auth/no-key/DB RAM, không gọi Gemini/Google thật.
- **UNVERIFIED:** thao tác N02 trực tiếp trên APK Pixel2, Gemini/Google/production. Người dùng đã xác nhận N01 chạy trên emulator trong yêu cầu; không suy ra N02 đã manual pass từ xác nhận đó. Không nâng các gate device/release vì build/widget pass.
- **Manual Pixel2:** chạy backend local no-key; cài APK hoặc flutter run với API_BASE_URL=http://10.0.2.2:3000. (1) Form ban đầu trống,1/3,button disabled; thử17/18/100/101,field trống và62,5. (2) Nữ160/42: cut disabled; thử Nữ+pregnancy, rồi đổiNam thấy lỗi và flag còn cho đến khi tự bỏ; chọnDuy trì. (3) Step3 toggleoff; bật chip vàKhác, nhập301 phải error/disabled, sửa300 hợp lệ; Back/Next giữ text/chips. (4) Submit liên tục chỉ1request; tắt backend thấy lỗi, không kết quả; Retry/Sửa hồ sơ giữ data; bật backend và retry thấy plan thật. (5) Keyboard/scroll/nút đáy trên màn nhỏ không che input hoặc mất nút. Không tick manual gate trước khi có kết quả.
- **Tiếp theo:** N03 khi được yêu cầu; chưa sửa dashboard/swap/grocery/feedback hoặc profile/calendar ngoài scope.

<a id="gemini-verification"></a>

### Kiểm chứng tích hợp Gemini (14/10/2026)

**Thử model theo yêu cầu người dùng:** đổi GEMINI_MODEL trong .env (ignored) sang gemini-3.8-flash, giữ các setting khác; đúng một request SDK thật với profile tổng hợp trả HTTP403 PERMISSION_DENIED sau490ms, không có output để validate. LIVE GEMINI FAIL; đổi model không khắc phục quyền project trong phép thử này. Không in key, không gọi thêm, không đổi task status/contract/source. Backend đang chạy cần restart để nạp .env mới.

**Cập nhật 23:01 (14/10/2026):** log backend do người dùng cung cấp xác nhận 403 PERMISSION_DENIED: project bị từ chối truy cập (khác lỗi 503 trước đó); không thể khắc phục quyền project chỉ bằng Flutter hoặc retry, cần kiểm tra quyền/giới hạn trong Google AI Studio/Cloud và liên hệ support nếu vẫn bị từ chối. Không gọi thêm live API. Đồng thời tái hiện độc lập lỗi fallback BMR: profile tổng hợp nữ19/150cm/48,2kg/sedentary/cut, Gemini giả403 → HTTP500 trước sửa vì tổng1163 < BMR1164. Đã sửa scaleMealsToTotal phân bổ phần dư lớn nhất để tổng nguyên đúng target, không hạ BMR/nới validation/đổi contract. Regression cùng request → HTTP200/source sample/tổng1164 mỗi ngày; unit kiểm mọi target900–3500 trên ba ngày mẫu, giữ tỷ lệ trong1kcal và macro tolerance. 376 unit +82 E2E PASS; typecheck PASS. Files: meal-scaling.ts, meal-scaling.spec.ts, generate-plan.e2e-spec.ts. Không sửa Flutter/N01/N02, không commit/push, trạng thái task và thống kê giữ nguyên. Live Gemini thành công vẫn chưa được xác minh.

**Cập nhật live sau khi người dùng xác nhận đã thay khóa (14/10/2026): LIVE GEMINI FAIL.** Một request qua GeminiService/SDK thật, profile tổng hợp, model cấu hình gemini-3.5-flash, không base URL giả: Google trả ApiError HTTP 503 sau 3.776 ms. Không nhận nội dung để parse/validate schema; helper không dùng fallback. Endpoint production không được gọi trong phép thử này; logic PlanService hiện có sẽ retry tối đa một lần rồi source=sample khi lỗi tiếp diễn. Không gọi thêm để tránh tiêu hao quota, không in khóa, không thay billing/runtime/contract. Task 4.9 giữ PARTIAL; N01/N02 và thống kê giữ nguyên. Kết quả này thay cho UNVERIFIED về kết nối SDK trong lần kiểm tra trước; thành công sinh plan/live endpoint vẫn UNVERIFIED.

- **LIVE GEMINI: UNVERIFIED.** Không có backend_api/.env hoặc GEMINI_API_KEY trong process của phiên kiểm tra. Không sử dụng khóa xuất hiện trong chat; cần thu hồi và cấu hình khóa mới riêng tại backend. Không có request nào gửi tới Google, không tiêu hao quota hoặc thay đổi billing. Không nâng task 4.9 hay gate nghiệm thu Gemini; N01/N02 và thống kê 38/69 DONE (55,07%) giữ nguyên.
- **Code/config:** SDK @google/genai, models.generateContent; key GEMINI_API_KEY; model GEMINI_MODEL (mặc định gemini-3.5-flash); GEMINI_BASE_URL trống để gọi Google. ConfigModule đọc .env theo working directory, cần khởi động trong backend_api. git check-ignore xác nhận backend_api/.env bị ignore; file không tracked. Health configured chỉ chứng minh có key, không chứng minh key hợp lệ hoặc model gọi được.
- **Model:** [Google](https://ai.google.dev/gemini-api/docs/whats-new-gemini-3.5) hiện ghi 3.5 deprecated, tự chuyển request sang 3.6. Có thể đặt GEMINI_MODEL=gemini-3.6-flash và GEMINI_THINKING=low (thinkingLevel) cho lần live sau; chưa thay default source hoặc tuyên bố model accessible với tài khoản cụ thể. thinkingBudget=0 cũ vẫn được Google mô tả là tương thích ngược, nhưng thinkingLevel được khuyến nghị cho Gemini 3.x.
- **Pipeline/contract:** POST /api/v1/generate-plan → PlanService → GeminiService → JSON.parse → DTO/class-validator + kiểm ba ngày/bữa/calo/macro/trùng món + kiểm dị ứng/chấn thương nhận diện → giới hạn mức bài tập → assemblePlan với IDs/grocery server tính. Thiếu key/lỗi/JSON/schema/safety không đạt → sample theo BRD NFR-2, source=sample; source=gemini chỉ khi nội dung đạt. HTTP 200 hoặc ảnh plan không chứng minh AI thật. Flutter GeneratedPlanScreen phân biệt nguồn và hiển thị warnings. Health conditions tự do không có semantic validator đủ để chứng minh an toàn y khoa.
- **Timeout/retry/gaps:** mặc định 20s/call, 40s tổng; tối đa hai attempts, timeout AbortError/504 không retry. Không bật SDK retryOptions; còn thiếu backoff/Retry-After cho 429 và throttling/concurrency/quota guard ở cấp app. Sai key/model vẫn retry một lần theo logic hiện tại. Không đổi contract hay runtime logic trong lượt này.
- **Automated evidence:** 375/375 unit (28 files), 81/81 E2E (6 files), typecheck/lint PASS. Thêm tests thiếu key trước HTTP, 403/404/429, ngắt mạng, response rỗng; E2E invalid key/model/quota/500/network/JSON/rỗng kiểm source=sample, response/warnings và số attempts. Schema sai, timeout, recognised allergen, BMI/pregnancy đã có tests và được chạy lại. SDK thật chỉ gọi fake server local, không phải live Gemini.
- **Regression:** flutter test --no-pub --reporter compact: 106 PASS, 2 SKIP (tests HTTP local opt-in, không chạy backend local trong lượt này), 0 FAIL. N01/N02 validation/mapping/back/loading/retry/persistence tests pass; không sửa Flutter hoặc triển khai N03–N05.
- **Files kiểm thử:** [SDK tests](../backend_api/src/plan/gemini.service.spec.ts), [E2E](../backend_api/test/generate-plan.e2e-spec.ts), [fake server](../backend_api/test/fake-gemini-server.ts). Lần live tiếp theo dùng profile tổng hợp không chứa PII, xác minh model accessibility trước, gọi endpoint một lần và ghi model/config/HTTP/latency/schema/source; sample phải ghi FAIL cho mục tiêu AI thật, không báo PASS theo HTTP 200. Không chạy measure:gemini toàn bộ vì script thực hiện nhiều request.

## 11. MVP Acceptance Criteria

Rubric/scope gốc giữ ở [BRD](../BRD.md); checklist này phục vụ nghiệm thu, không sửa business requirements. Đánh giá tất cả FR/NFR liên quan, kể cả subtasks trong38specs.

| Tiêu chí | Task | Evidence hiện tại | Kết luận milestone |
|---|---|---|---|
| BRD/hợp đồng/JSON | 1.1,1.2 | Docs/JSON được kiểm audit | Tài liệu đạt; không chứng minh UI |
| Backend local/Swagger/BMR/TDEE/fallback | 2.1–2.5,4.1,4.7 | Unit/E2E/smoke audit pass | Backend local đạt scope kiểm thử |
| AI workspace prompt/structuredJSON đúng backend | 1.3,4.9,6.10 | Typecheck có, prompt lệch | Chưa đạt |
| Form thật/safety/ba bước | 6.1,6.9 | N02 form/safety tests và HTTP local pass; device N02 chưa manual | Frontend criteria đạt; backend fixture/device gates còn riêng |
| Client generate/loading/3ngày×3bữa/workout/macros/warnings | 6.3,6.4,6.7 | N01/N03 tạo/lưu/dashboard/plan thật, widget tests pass; device gate 6.7 còn thiếu | Chưa đạt toàn milestone |
| Profile/checklist/offline/calendar | 5.6,6.2,6.5,6.11 | Checklist N03; startup/profile/calendar N04 unit/widget pass; Android runtime còn UNVERIFIED | Chưa đạt |
| Swap/feedback/danger/day3 | 7.1–7.3 | N03/N05 đạt automated UI/API/persistence/HTTP fullflow; Pixel 2/Groq live còn thiếu | Code/tests đạt; device acceptance UNVERIFIED |
| Google/history/delete/crossdevice | 8.1–8.4 | Backend có, UI chưa nối | Chưa đạt scope tài khoản bổ sung |
| UI/integration/realservice acceptance | 6.6,6.7,9.4 | Thiếu widget/integration;live chưa kiểm | Chưa đạt |
| Demo Client→Server→AI→Client và báo cáo | 9.3–9.6 | Local builds không thay fullflow | Chưa đạt |

Kịch bản bắt buộc: adult valid và range errors; rawBMI dưới18.5; pregnancy/malepregnancy; allergies/injuries/unknown health warning; no-key fallback; timeout/badJSON; chọn mọi ngày/bữa và swap đúngID; không có candidate422; profile mismatch409; grocery recompute/persist/have; corrupt storage/offline/restart; calendar qua tháng/day3/expiry/resume; normal/sore/jointpain/fatigue/danger/eating feedback và anti-repeat; guest/auth401/owner404/historylimit/delete/crossdevice. Không log health text, không đặt API key trong app.

## 12. Release Readiness Checklist

Đây là các gate nghiệm thu, không phải task mới trong dashboard69. Chỉ tick khi có bằng chứng cùng build/commit được giao nộp.

- [ ] N01–N06 đạt UI↔backend, safety, persistence và integration tests; không còn production mock data route.
- [ ] Unit/E2E/typecheck/lint/Flutter analyze/tests và APK/web phù hợp mục tiêu release chạy lại trên build cuối; lưu command/result.
- [ ] Android lint không error; signing/appID/networkHTTPS hoàn tất; launcher/splash/systembars và device lifecycle được kiểm.
- [ ] Fixture exporter/comparison phục hồi; CI đúng commit/version/runtime verified; screenshots/docs mô tả đúng trạng thái.
- [ ] Google auth/history/delete/401/crossdevice nghiệm thu khi release gồm scope tài khoản; OAuth Flutter setup có đủ.
- [ ] Gemini prompt/model/thinking/timebudget đồng bộ; đo dịch vụ thật có evidence; fallback/safety không bị bỏ khi AI lỗi.
- [ ] Host/storage bền,productionenv/secrets/CORS/HTTPS; plan history tồn tại qua restart; guest/auth fullflow verified.
- [ ] README/changelog/wiki/BRD rubric đúng nghiệm thu; video/slides/demo artifact mở được; báo cáo các giới hạn chưa kiểm.
- [ ] Chủ dự án xác nhận phạm vi và artifact giao nộp; chỉ commit/push/deploy khi được ủy quyền riêng.

### Ghi nhận hợp nhất

Hai đầu vào trước hợp nhất có67/69 task; union69. Bổ sung2.5 và2.6 vào roadmap chính. Giữ nguyên69ID,38implementation specs, scope/subcriteria, D1–D6 và mục deferred. Baseline36/14/5/1/8/5 không được nâng từ việc sửa docs;9.5 vẫn PARTIAL. Các references roadmap được chuẩn hóa về tài liệu này.
