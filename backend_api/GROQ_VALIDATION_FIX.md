# Generate Plan: sửa AI_EXERCISE_LOAD_CONFLICT — 01/11/2026

Phạm vi: báo cáo lịch sử của bản sửa validation. Chính sách bài tập ngoài kho đã được cập nhật sau đó; xem [GROQ_INTEGRATION.md](GROQ_INTEGRATION.md) và [roadmap hiện tại](../docs/PLAN.md). Các test counts trong báo cáo này giữ theo thời điểm kiểm tra, không phải tổng suite hiện tại.

## Kết luận dựa trên response thực tế

Hai response người dùng cung cấp đều HTTP200, finish_reason=stop, JSON parse thành công. Đây là lỗi validation tại `assessedExercise()` trong ai-exercise.ts, không phải timeout/network ở hai requests đó. Code cũ ném Error thường, PlanService gom vào TRANSPORT_OR_INTERNAL_ERROR; mã console đó đã che mất nguyên nhân.

Điều kiện cũ gây lỗi:

```ts
loads.some(tag => !tags.includes(tag)) ||
matchRestrictions(profile.restrictions).avoidTags.some(tag => tags.includes(tag) || loads.includes(tag))
```

Nhánh trái: thiếu tag mà regex suy ra. Nhánh phải: tag thực tế/AI tự khai vi phạm hạn chế đã khai. Không có hồ sơ request trong log, nên không suy đoán avoidTags hoặc tuổi thật. Các test dùng hồ sơ tổng hợp có kiểm soát, không lưu hồ sơ người dùng.

## Vị trí lỗi cũ và các bất thường

Các vị trí dưới đây ghi ngày/bài bắt đầu từ1; diagnostic trong code dùng index bắt đầu từ0.

| Attempt | Ngày/bài | Bài / dữ liệu | Phân tích |
|---|---|---|---|
| 1 | 1/1 | Đứng lên ngồi xuống ghế (không dùng ghế) | Tên tham chiếu ghế rồi phủ nhận ghế; chưa có identity đã xác minh. Không tin level1/equipment none để nhận ngay. |
| 1 | 1/2 | Plank tường, tags=[] | Regex chung `plank` suy ra wrist_load; thiếu tag → AI_EXERCISE_LOAD_CONFLICT. Đây là điểm từ chối tái hiện được độc lập với restrictions. |
| 1 | 1/3 | Marching, instructions có “không nhảy” | Regex cũ vẫn thấy “nhảy”, suy ra jumping rồi báo thiếu tag. False positive về phủ định. |
| 1 | 2/1 | Hip hinge đứng, tags=[kneeling] | Tư thế đứng nhưng khai quỳ. Nhánh cấm tải có thể từ chối nếu hồ sơ cấm kneeling; không có hồ sơ nên không khẳng định nhánh này đã chạy. |
| 1 | 2/2 | Đẩy tường (wall push‑up), tags=[] | Regex push-up yêu cầu wrist_load chung, dù metadata Chống đẩy tường trong kho hiện có tags=[]. Chưa ưu tiên alias/metadata cụ thể. |
| 1 | 2/3 | Chạy tại chỗ chậm, “không bật nhảy” | False positive phủ định giống1/3; identity/impact chưa được xác minh riêng. |
| 1 | 3/1 | Ngồi đứng từ ghế (không dùng ghế), instructions ngồi sàn | Tên và hướng dẫn không cùng cơ chế; thêm kneeling không chứng minh phù hợp. |
| 1 | 3/2 | Chống đẩy tường (wall push‑up), tags=[] | Cùng vấn đề alias/regex wrist như2/2. |
| 1 | 3/3 | Thở sâu + giãn cơ tay, instructions giơ tay cao | Bài kết hợp chưa có metadata độc lập; không kết luận nhẹ chỉ từ assessment. |
| 2 | 1/1 | Đi bộ tại chỗ | Có identity/mức/tag/workload trong kho để đối chiếu. |
| 2 | 1/2 | Squat tự hỗ trợ tường, tags=[kneeling] | Đứng dựa tường không đồng nghĩa quỳ. Có thể là điểm dừng trước1/3 nếu hồ sơ cấm kneeling. |
| 2 | 1/3 | Plank khuỷu tay, tags=[kneeling] | Regex cũ vẫn yêu cầu wrist_load. Alias Plank cẳng tay trong dữ liệu dự án là level2/tags=[], không được đổi thành level1 do AI tự khai. |
| 2 | 2/1 | Marching trên chỗ | Có thể chuẩn hóa qua alias reviewed → Đi bộ tại chỗ. |
| 2 | 2/2 | Gập người đứng (Standing knee raise), tags=[kneeling] | Tên Việt/Anh không nhất quán, hướng dẫn nâng gối đứng; kneeling sai tư thế. Không tự sửa identity theo suy đoán. |
| 2 | 2/3 | Side plank trên đầu gối, chống khuỷu tay | Regex plank cũ bắt wrist dù hướng dẫn chống khuỷu. Biến thể chưa xác minh không tự nhận level1. |
| 2 | 3/1 | Step touch, “không nhảy” | False positive jumping do phủ định; identity vẫn phải được xác minh. |
| 2 | 3/2 | Wall push‑up, tags=[kneeling] | Alias được xác minh theo Chống đẩy tường; tag quỳ sai có thể sửa từ metadata đáng tin cậy của identity đó. |
| 2 | 3/3 | Bird‑dog trên sàn, tags=[], instructions nằm sấp | Thiếu kneeling/wrist_load so với Bird-dog đã có, nhưng hướng dẫn nằm sấp còn mâu thuẫn identity. Không chỉ thêm tags rồi chấp nhận. Workload12 lần mỗi bên cũng vượt bản Bird-dog10 lần mỗi bên hiện có. |

Attempt1 chắc chắn vướng nhánh thiếu wrist_load tại1/2 trong code cũ. Attempt2 chắc chắn có lỗi đó tại1/3; thứ tự dừng thực tế có thể sớm hơn ở1/2 nếu restrictions cấm kneeling. Không thể kết luận thứ tự tuyệt đối của attempt2 nếu thiếu request profile. Diagnostic mới giải quyết chính khoảng trống này.

## Thay đổi

1. Thêm exercise-verification.ts: normalize Unicode/hyphen; exact alias reviewed cho wall push-up, forearm/elbow plank, Bird-dog, marching. Không fuzzy-match mọi tên mới, không cho AI tự khai canonical ID đáng tin.
2. Ưu tiên metadata trong swap-exercises.json: level, nhóm cơ, tags, sets/reps. Sửa metadata AI sai chỉ khi identity đã xác minh và instructions không giới thiệu cơ chế/tải mâu thuẫn.
3. Xử lý phủ định “không nhảy/không bật nhảy”; không suy wrist_load cho mọi plank cẳng tay/khuỷu tay. Đây không phải phép bỏ tag: plank/biến thể chưa xác minh vẫn bị từ chối hoặc thay.
4. Không tin level/impact/equipment tự khai. Known forearm plank level2 không thể thành level1 chỉ nhờ JSON AI. Workload phải cùng đơn vị và không vượt bản đã xác minh; không auto giảm trường khó để làm proposal PASS.
5. Unknown/contradictory/profile-too-hard/excess-workload trong Generate: chọn động tác đã kiểm cùng nhóm cơ, lọc level/restrictions/equipment, kiểm lại trước dùng. Nếu nhóm đó không có bodyweight phù hợp, dùng cardio nhẹ đã kiểm; hết lựa chọn thì từ chối, retry/fallback toàn plan theo quy tắc hiện có. Swap vẫn giữ cùng nhóm cơ và yêu cầu nhẹ hơn như contract cũ.
6. Không tự thêm đề xuất AI vào kho. Muốn nhận thêm identity mới như bài chính thức cần metadata được rà soát riêng; assessment do model tự khai không phải bằng chứng độc lập. Chính sách này thay thế việc chấp nhận bài ngoài kho chỉ từ self-assessment ở lượt trước, theo yêu cầu hiện tại.
7. Plan source vẫn nguồn tạo kế hoạch, không phải nguồn từng bài. Khi có thay bài, warnings nói rõ có bài dùng dữ liệu dự phòng; metadata repair cũng có cảnh báo. Món ăn AI không bị đổi chỉ vì lỗi metadata một bài tập. Validation món/calo/macro/restrictions vẫn chạy sau chuẩn hóa.
8. Prompt giải thích tags/tư thế/phủ định/tên và instructions; có ví dụ metadata dự án cho Chống đẩy tường, Plank cẳng tay, Bird-dog. Không yêu cầu model tự hạ level hoặc bỏ tags.

## Diagnostic an toàn

`exercise_validation` ghi error_code, day_index, exercise_index, violated_rule, expected/actual enum/tags/số đã lọc và action repaired/replaced/rejected. Không ghi tên bài tự do, instructions, profile, key hoặc raw response vào console production. Lỗi cuối cùng không thay được là ExerciseValidationError → plan_validation_failed, không còn gán nhầm TRANSPORT_OR_INTERNAL_ERROR. Retry nhận EXERCISE_VERIFICATION và đúng DTO path, không mang theo text AI/profile.

GROQ_DEBUG_RESPONSES bị vô hiệu hóa khi NODE_ENV=production, kể cả flag=true. Local debug vẫn theo flag đã có; không sửa .env trong lượt này. Dữ liệu dự án là nguồn metadata hiện hữu, không phải chứng nhận y khoa; keyword matching vẫn có giới hạn, không tuyên bố xác minh ngữ nghĩa lâm sàng tuyệt đối.

## Regression / kết quả

- test/fixtures/groq-exercise-load-conflicts.json: đúng2 responses, chỉ giữ exercises/assessment cần tái hiện; bỏ meals, profile, request IDs, timestamps, usage, key và reasoning.
- exercise-load-regression.spec.ts tái hiện nhánh cũ, cả2 normalization, cả2 Generate với Groq client mock; kiểm metadata false/level/workload, invariants, diagnostic không rò rỉ text, retry path và phân loại validation.
- HTTP E2E đưa từng fixture vào POST /api/v1/generate-plan với hồ sơ tổng hợp65 tuổi/chấn thương gối; giữ món AI, thay bài phù hợp, response đúng contract, không xuất assessment, không có tag cấm.
- Unit tests cập nhật rõ policy: metadata sai ở identity đã biết được sửa thay vì bắt buộc retry; self-assessment của unknown không còn đủ để nhận. Privacy test xác nhận production tắt ghi response.
- **464 unit /35 files PASS;115 E2E /9 files PASS;typecheck/lint/build PASS.** Không sửa Flutter/API contract/N01–N04/persistence; không chạy lại Flutter vì không thay frontend.

Files chính: ai-exercise.ts, exercise-verification.ts, plan.service.ts, plan-diagnostics.ts, groq-plan.service.ts, adjust/exercise-swap-validation.ts; các unit/HTTP E2E liên quan, fixture2responses; tài liệu này, GROQ_INTEGRATION.md và docs/PLAN.md. Giữ thay đổi chưa commit có trước, không reset/clean/commit/push.

## Live sau sửa

Không có request Groq thật nào do agent gửi trong lượt này. Hai HTTP200 trước đó chứng minh provider kết nối được; chưa chứng minh bản sửa chạy live.

1. Restart backend trong backend_api bằng npm.cmd run start:dev, không đổi .env/key/quota.
2. Trên app tạo đúng1 kế hoạch mới; plan đã lưu N04 không tự đổi. Có thể dùng hồ sơ test đã dùng trước để đối chiếu nhưng không dán hồ sơ nhạy cảm vào log/chat.
3. Console xem exercise_validation với index0-based và action; nếu bài được thay, app phải có warning. source groq có thể đi kèm một số bài dự phòng, không diễn giải là mọi bài đều từ AI.
4. Nếu không thể xác minh/thay, log phải là plan_validation_failed với mã và vị trí cụ thể. Nếu HTTP429 thì ghi riêng rate-limit, không nhầm với lỗi metadata. Debug TXT local chứa trace/validation để đối chiếu.
5. Món ăn hoặc restrictions khác vẫn có thể không đạt; không khẳng định response thật sẽ PASS mọi điều kiện chỉ vì đã sửa lỗi exercise. Không bấm tạo lại liên tục để ép PASS.

Roadmap giữ45/69 DONE (65,22%); LIVE sau sửa và nghiệm thu Android chưa xác minh, không tự nâng N05/N08.
