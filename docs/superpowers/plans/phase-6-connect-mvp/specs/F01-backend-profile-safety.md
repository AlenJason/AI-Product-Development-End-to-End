# F01 — Backend: hồ sơ an toàn (D6 A1–A3) + hợp đồng + model Dart `Profile`

## Feature

Ba luật an toàn mới cho hồ sơ (BRD v2.6.0 — FR-1.1, FR-1.3, NFR-10), kiểm ở **mọi** endpoint nhận hồ sơ vì cùng nằm trên `CreatePlanDto` (#24):

| Luật | Kết quả |
|---|---|
| A2: tuổi 18–100 (trước là 10–100) | tuổi 17 → 400 |
| A1: `goal = cut` + BMI **chưa làm tròn** < 18,5 | 400, câu "Chỉ số BMI dưới 18,5 (thiếu cân) nên không chọn được Giảm mỡ…" |
| A3: trường mới `pregnant_or_breastfeeding` (boolean, mặc định `false`) | `true` + `cut` → 400 "Đang mang thai hoặc cho con bú…"; `true` + nam → 400; `true` → cảnh báo `pregnancy` trong `warnings` |

Ngưỡng và câu thông báo nằm chung một file (`profile-safety.ts`) — app Flutter dùng đúng các ngưỡng này ở F03. Làm tròn BMI trước khi so thì 18,46 lọt thành 18,5 (test khoá).

Đổi hợp đồng → xuất lại fixture (#26): `profile.json` có thêm `pregnant_or_breastfeeding`, `error_400.json` đổi câu tuổi tối thiểu, thêm `restriction_labels.json` (nhãn bộ khớp từ khoá nhận ra — dùng ở F03, #32). Model Dart `Profile` thêm trường trong cùng feature để test vòng tròn vẫn xanh.

## Scope

API + model Dart:

- `backend_api/src/plan/profile-safety.ts`, `profile-safety.spec.ts`, `dto/profile-safety.validator.ts` (mới)
- `backend_api/src/plan/dto/create-plan.dto.ts`, `plan-warnings.ts` (sửa)
- `backend_api/test/generate-plan.e2e-spec.ts`, `adjust.e2e-spec.ts`, `contract-fixtures.e2e-spec.ts` (sửa)
- `frontend_app/test/fixtures/profile.json`, `error_400.json` (sinh lại), `restriction_labels.json` (mới, sinh bằng lệnh)
- `frontend_app/lib/models/api/json_read.dart`, `profile.dart`, `test/models/contract_test.dart` (sửa)

## Implementation

### API Routes

Không thêm route. Luật mới chạy trong `ValidationPipe` trước khi vào service — request bị từ chối không gọi Gemini (e2e kiểm `fake.requests` rỗng). **Độ trễ:** thêm vài phép tính trên mỗi request, không đổi đáng kể.

**Khoá API bên ngoài:** không có. Test không gọi Gemini thật (#17).

### UI Components

Không có (form khoá lựa chọn ở F04).

### DB / KV Changes

Không có. `pregnant_or_breastfeeding` là dữ liệu sức khoẻ: không lưu DB, không log, không có trong response (#12 — e2e kiểm).

### Ràng buộc áp dụng

- **#12** cờ mang thai không lưu, không log, không nằm trong response.
- **#17, #18** e2e qua `createTestApp()`; `ValidationPipe` trong `configureApp()`.
- **#24** luật nằm trên `CreatePlanDto` nên đổi món, đổi bài, feedback cũng từ chối hồ sơ vi phạm (e2e kiểm 2 endpoint).
- **#26** fixture và model Dart đổi trong cùng feature.
- Ràng buộc mới **#30** ghi vào wiki ở F06.

## Definition of Done

- [ ] `npm run fixtures:update` sinh lại `profile.json`, `error_400.json` và thêm `restriction_labels.json`; chạy lại lần hai không đổi file
- [ ] `npm test` → `Tests  268 passed (268)`; `npm run test:e2e` → `Tests  74 passed (74)`
- [ ] `npm run typecheck`, `build`, `test:smoke`, `lint` sạch
- [ ] `flutter analyze` sạch, `flutter test` → `+45: All tests passed!`

## Test Checklist

1. **@happy**: hồ sơ hợp lệ vẫn tạo plan; mang thai + Duy trì → 200 kèm cảnh báo `pregnancy`, response không có `pregnant_or_breastfeeding`
2. **@validation**: tuổi 17, nam + mang thai, `pregnant_or_breastfeeding: 'có'` → 400
3. **@safety**: BMI 16,4 + `cut` → 400 câu có "thiếu cân"; mang thai + `cut` → 400 câu có "mang thai"; không gọi Gemini
4. **@boundary**: BMI 18,46 bị chặn, 18,51 qua (unit)
5. **@adjust**: đổi bài với hồ sơ thiếu cân + `cut`, feedback với hồ sơ 17 tuổi → 400
6. **@contract**: vòng tròn `Profile` với fixture mới; hồ sơ lưu trước v2.6.0 (thiếu trường) đọc thành `false`
7. **@auth**, **@timeout**, **@token**, **@db**: không đổi

## Tasks

### Task 1 — Luật và câu thông báo

`backend_api/src/plan/profile-safety.ts`:

```ts
import { Gender } from './enums/gender.enum.js';

// Hồ sơ không được phép thâm hụt calo (BRD FR-1.1, FR-1.3, v2.6.0; quyết định D6 A1–A3). Kiểm ở mọi endpoint nhận
// hồ sơ (`SafeGoalConstraint` trên `CreatePlanDto`). App Flutter khoá lựa chọn theo đúng các ngưỡng này
// (`frontend_app/lib/models/profile_rules.dart`); backend vẫn là nơi quyết định.

// Công thức Mifflin-St Jeor dành cho người trưởng thành; đối tượng BRD mục 3 là sinh viên và người đi làm.
export const MIN_AGE = 18;
export const MAX_AGE = 100;
// Ngưỡng thiếu cân của WHO.
export const UNDERWEIGHT_BMI = 18.5;

export const PROFILE_SAFETY_MESSAGES = {
  underweightCut:
    'Chỉ số BMI dưới 18,5 (thiếu cân) nên không chọn được Giảm mỡ. Hãy chọn Duy trì vóc dáng hoặc Tăng cơ.',
  pregnantCut:
    'Đang mang thai hoặc cho con bú thì không chọn được Giảm mỡ. Hãy chọn Duy trì vóc dáng và hỏi ý kiến bác sĩ.',
  pregnantNotFemale: 'pregnant_or_breastfeeding chỉ được là true khi gender là female.',
} as const;

export interface SafetyProfile {
  gender: Gender;
  height_cm: number;
  weight_kg: number;
  pregnant_or_breastfeeding?: boolean;
}

// BMI chưa làm tròn: làm tròn trước khi so sẽ cho 18,46 thành 18,5 và lọt qua ngưỡng.
export function bodyMassIndex(heightCm: number, weightKg: number): number {
  const heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

// Lý do không được chọn Giảm mỡ, hoặc null. Chiều cao/cân nặng sai kiểu → NaN → không chặn (validator khác báo lỗi).
export function cutBlockReason(profile: SafetyProfile): string | null {
  if (profile.pregnant_or_breastfeeding === true) return PROFILE_SAFETY_MESSAGES.pregnantCut;
  if (bodyMassIndex(profile.height_cm, profile.weight_kg) < UNDERWEIGHT_BMI) return PROFILE_SAFETY_MESSAGES.underweightCut;
  return null;
}
```

`backend_api/src/plan/profile-safety.spec.ts`:

```ts
import { Gender } from './enums/gender.enum.js';
import { bodyMassIndex, cutBlockReason, PROFILE_SAFETY_MESSAGES } from './profile-safety.js';

const body = (height_cm: number, weight_kg: number, pregnant_or_breastfeeding = false) => ({
  gender: Gender.FEMALE,
  height_cm,
  weight_kg,
  pregnant_or_breastfeeding,
});

describe('cutBlockReason (BRD FR-1.3, v2.6.0)', () => {
  it('blocks cutting when underweight (BMI < 18.5)', () => {
    expect(bodyMassIndex(160, 42)).toBeCloseTo(16.4, 1);
    expect(cutBlockReason(body(160, 42))).toBe(PROFILE_SAFETY_MESSAGES.underweightCut);
  });

  it('compares the unrounded BMI, so 18.46 is still underweight', () => {
    expect(bodyMassIndex(170, 53.35)).toBeCloseTo(18.46, 2);
    expect(cutBlockReason(body(170, 53.35))).toBe(PROFILE_SAFETY_MESSAGES.underweightCut);
    expect(cutBlockReason(body(170, 53.5))).toBeNull();
  });

  it('blocks cutting while pregnant or breastfeeding, whatever the BMI', () => {
    expect(cutBlockReason(body(160, 70, true))).toBe(PROFILE_SAFETY_MESSAGES.pregnantCut);
  });

  it('allows a normal profile and ignores invalid numbers (other validators report them)', () => {
    expect(cutBlockReason(body(168, 62))).toBeNull();
    expect(cutBlockReason(body(Number.NaN, 62))).toBeNull();
  });
});
```

### Task 2 — Validator trên `CreatePlanDto`

`backend_api/src/plan/dto/profile-safety.validator.ts`:

```ts
import {
  type ValidationArguments,
  ValidatorConstraint,
  type ValidatorConstraintInterface,
} from 'class-validator';
import { Gender } from '../enums/gender.enum.js';
import { Goal } from '../enums/goal.enum.js';
import { cutBlockReason, PROFILE_SAFETY_MESSAGES, type SafetyProfile } from '../profile-safety.js';

// `goal = cut` bị từ chối khi thiếu cân hoặc mang thai / cho con bú (BRD FR-1.3, v2.6.0).
@ValidatorConstraint({ name: 'safeGoal' })
export class SafeGoalConstraint implements ValidatorConstraintInterface {
  validate(goal: unknown, args: ValidationArguments): boolean {
    return goal !== Goal.CUT || cutBlockReason(args.object as SafetyProfile) === null;
  }

  defaultMessage(args: ValidationArguments): string {
    return cutBlockReason(args.object as SafetyProfile) ?? '';
  }
}

@ValidatorConstraint({ name: 'pregnancyNeedsFemale' })
export class PregnancyNeedsFemaleConstraint implements ValidatorConstraintInterface {
  validate(value: unknown, args: ValidationArguments): boolean {
    return value !== true || (args.object as SafetyProfile).gender === Gender.FEMALE;
  }

  defaultMessage(): string {
    return PROFILE_SAFETY_MESSAGES.pregnantNotFemale;
  }
}
```

`backend_api/src/plan/dto/create-plan.dto.ts`:

```diff
--- a/backend_api/src/plan/dto/create-plan.dto.ts
+++ b/backend_api/src/plan/dto/create-plan.dto.ts
@@ -1,24 +1,29 @@
 import { Type } from 'class-transformer';
 import {
+  IsBoolean,
   IsEnum,
   IsInt,
   IsNumber,
+  IsOptional,
   Max,
   Min,
+  Validate,
   ValidateNested,
 } from 'class-validator';
 import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
 import { ActivityLevel } from '../enums/activity-level.enum.js';
 import { Gender } from '../enums/gender.enum.js';
 import { Goal } from '../enums/goal.enum.js';
+import { MAX_AGE, MIN_AGE } from '../profile-safety.js';
+import { PregnancyNeedsFemaleConstraint, SafeGoalConstraint } from './profile-safety.validator.js';
 import { RestrictionsDto } from './restrictions.dto.js';
 
 // Khớp với JSON request schema ở BRD.md mục 6.1.
 export class CreatePlanDto {
-  @ApiProperty({ example: 22 })
+  @ApiProperty({ example: 22, minimum: MIN_AGE, maximum: MAX_AGE })
   @IsInt()
-  @Min(10)
-  @Max(100)
+  @Min(MIN_AGE)
+  @Max(MAX_AGE)
   age: number;
 
   @ApiProperty({ enum: Gender, example: Gender.FEMALE })
@@ -41,10 +46,18 @@
   @IsEnum(ActivityLevel)
   activity_level: ActivityLevel;
 
-  @ApiProperty({ enum: Goal, example: Goal.CUT })
+  @ApiProperty({ enum: Goal, example: Goal.CUT, description: 'cut bị từ chối khi BMI < 18,5 hoặc pregnant_or_breastfeeding' })
   @IsEnum(Goal)
+  @Validate(SafeGoalConstraint)
   goal: Goal;
 
+  // Dữ liệu sức khoẻ như `restrictions`: không lưu DB, không ghi log (NFR-7, #12).
+  @ApiPropertyOptional({ example: false, description: 'Đang mang thai hoặc cho con bú — chỉ khi gender = female' })
+  @IsOptional()
+  @IsBoolean()
+  @Validate(PregnancyNeedsFemaleConstraint)
+  pregnant_or_breastfeeding: boolean = false;
+
   @ApiPropertyOptional({ type: RestrictionsDto })
   @ValidateNested()
   @Type(() => RestrictionsDto)
```

### Task 3 — Cảnh báo mang thai

```diff
--- a/backend_api/src/plan/plan-warnings.ts
+++ b/backend_api/src/plan/plan-warnings.ts
@@ -7,6 +7,8 @@
     `Calo mục tiêu đã được nâng lên bằng mức chuyển hoá cơ bản (BMR ${bmr} kcal), vì mức thâm hụt đã chọn sẽ khiến bạn ăn thấp hơn BMR. Không nên ăn thấp hơn mức này nếu không có hướng dẫn của chuyên gia.`,
   healthConditions:
     'Bạn có khai báo tình trạng sức khoẻ: kế hoạch chỉ mang tính tham khảo, không thay thế tư vấn y tế. Hãy hỏi ý kiến bác sĩ trước khi áp dụng.',
+  pregnancy:
+    'Bạn đang mang thai hoặc cho con bú: nhu cầu năng lượng và dưỡng chất khác người thường, bài tập đã giới hạn ở mức nhẹ nhất. Kế hoạch chỉ mang tính tham khảo — hãy hỏi ý kiến bác sĩ trước khi áp dụng.',
   sampleKeywordFiltered:
     'Đang dùng thực đơn mẫu: món ăn và bài tập chỉ được lọc theo các dị ứng, chấn thương phổ biến (ví dụ hải sản, đậu phộng, đau gối); tình trạng sức khoẻ chưa được xét. Hãy tự kiểm tra lại trước khi áp dụng.',
   restrictionsIncomplete:
@@ -22,6 +24,7 @@
   const warnings: string[] = [];
   if (flooredToBmr) warnings.push(WARNINGS.bmrFloor(bmr));
   if (profile.restrictions.health_conditions) warnings.push(WARNINGS.healthConditions);
+  if (profile.pregnant_or_breastfeeding) warnings.push(WARNINGS.pregnancy);
   return warnings;
 }
```

### Task 4 — E2E

```diff
--- a/backend_api/test/generate-plan.e2e-spec.ts
+++ b/backend_api/test/generate-plan.e2e-spec.ts
@@ -83,10 +83,31 @@
     ['ô nhập dài hơn 300 ký tự', { restrictions: { allergies: 'a'.repeat(301) } }],
     ['tuổi không phải số', { age: 'hai mươi' }],
     ['mục tiêu ngoài danh sách', { goal: 'lose_weight' }],
+    ['tuổi dưới 18 (v2.6.0)', { age: 17 }],
+    ['mang thai nhưng giới tính nam (v2.6.0)', { gender: 'male', pregnant_or_breastfeeding: true, goal: 'maintain' }],
+    ['pregnant_or_breastfeeding không phải boolean', { pregnant_or_breastfeeding: 'có' }],
   ])('rejects %s with 400', async (_label, overrides) => {
     await post(body(overrides)).expect(400);
   });
 
+  // BRD FR-1.3 (v2.6.0): câu tiếng Việt giải thích lý do, không gọi Gemini.
+  it.each([
+    ['thiếu cân (BMI 16,4)', { height_cm: 160, weight_kg: 42 }, 'thiếu cân'],
+    ['đang mang thai hoặc cho con bú', { pregnant_or_breastfeeding: true }, 'mang thai'],
+  ])('refuses to plan a calorie deficit when %s', async (_label, overrides, reason) => {
+    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
+    const res = await post(body({ ...overrides, goal: 'cut' })).expect(400);
+    expect(res.body.message.join(' ')).toContain(reason);
+    expect(fake.requests).toHaveLength(0);
+  });
+
+  it('plans maintenance while pregnant, with the pregnancy warning and never echoing the flag back', async () => {
+    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
+    const res = await post(body({ goal: 'maintain', pregnant_or_breastfeeding: true })).expect(200);
+    expect(res.body.warnings.join(' ')).toContain('mang thai');
+    expect(JSON.stringify(res.body)).not.toContain('pregnant_or_breastfeeding');
+  });
+
   it('accepts a request without restrictions', async () => {
     fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
     const res = await post(BASE).expect(200);
```

```diff
--- a/backend_api/test/adjust.e2e-spec.ts
+++ b/backend_api/test/adjust.e2e-spec.ts
@@ -109,6 +109,8 @@
     ['no plan', 'exercises/swap', () => ({ profile: PROFILE, exercise_id: 'e1_1' })],
     ['no profile', 'meals/swap', (plan) => ({ plan, meal_id: 'm1_1' })],
     ['a plan that is not an object', 'meals/swap', () => ({ profile: PROFILE, plan: 'abc', meal_id: 'm1_1' })],
+    ['an underweight profile that cuts (v2.6.0)', 'exercises/swap', (plan) => ({ profile: { ...PROFILE, weight_kg: 45 }, plan, exercise_id: 'e1_1' })],
+    ['a profile under 18 (v2.6.0)', 'feedback', (plan) => ({ profile: { ...PROFILE, age: 17 }, plan, day_number: 1, intensity: 'hard', body_states: ['normal'], eating: 'on_plan' })],
   ])('answers 400 to %s', async (_label, path, build) => {
     await post(path, build(await generate())).expect(400);
   });
```

### Task 5 — Fixture hợp đồng

```diff
--- a/backend_api/test/contract-fixtures.e2e-spec.ts
+++ b/backend_api/test/contract-fixtures.e2e-spec.ts
@@ -19,9 +19,16 @@
   weight_kg: 62,
   activity_level: 'light',
   goal: 'cut',
+  pregnant_or_breastfeeding: false,
   restrictions: { allergies: 'Hải sản', injuries: 'Đau gối', health_conditions: 'Tiểu đường' },
 };
 
+// Nhãn dị ứng / chấn thương bộ khớp từ khoá nhận ra. Mọi chip gợi ý của app phải nằm trong đây (D5) —
+// test Flutter `restriction_options_test.dart` kiểm, nên sửa file từ khoá mà quên app thì test đó đỏ.
+const KEYWORDS = JSON.parse(
+  readFileSync(new URL('../src/plan/data/restriction-keywords.json', import.meta.url), 'utf-8'),
+) as { allergies: { labels: string[] }[]; injuries: { labels: string[] }[] };
+
 describe('Fixture hợp đồng cho Flutter (e2e)', () => {
   let testApp: TestApp;
   const fixedIds = new Map<string, string>();
@@ -64,6 +71,10 @@
 
   it('matches every committed fixture', async () => {
     check('profile', PROFILE);
+    check('restriction_labels', {
+      allergies: KEYWORDS.allergies.flatMap((group) => group.labels),
+      injuries: KEYWORDS.injuries.flatMap((group) => group.labels),
+    });
     check('health', (await http().get('/health').expect(200)).body);
 
     const login = await loginMock(testApp, 'sv@vku.edu.vn');
```

```bash
cd backend_api
npm run fixtures:update   # Tests  1 passed (1) — profile.json, error_400.json đổi; restriction_labels.json mới
npm run fixtures:update   # lần hai: git status không đổi
```

### Task 6 — Model Dart `Profile`

```diff
--- a/frontend_app/lib/models/api/json_read.dart
+++ b/frontend_app/lib/models/api/json_read.dart
@@ -27,6 +27,12 @@
   throw FormatException('"$field" phải là số');
 }
 
+bool readBool(Json json, String field) {
+  final value = json[field];
+  if (value is bool) return value;
+  throw FormatException('"$field" phải là true/false');
+}
+
 int readInt(Json json, String field) {
   final value = json[field];
   if (value is int) return value;
```

```diff
--- a/frontend_app/lib/models/api/profile.dart
+++ b/frontend_app/lib/models/api/profile.dart
@@ -1,3 +1,5 @@
+import 'dart:convert';
+
 import 'codes.dart';
 import 'json_read.dart';
 
@@ -11,6 +13,7 @@
     required this.weightKg,
     required this.activityLevel,
     required this.goal,
+    this.pregnantOrBreastfeeding = false,
     this.restrictions = const Restrictions(),
   });
 
@@ -20,6 +23,8 @@
   final num weightKg;
   final ActivityLevel activityLevel;
   final Goal goal;
+  // Chỉ có nghĩa khi gender = female; true thì backend không cho chọn Giảm mỡ (BRD FR-1.3, v2.6.0).
+  final bool pregnantOrBreastfeeding;
   final Restrictions restrictions;
 
   factory Profile.fromJson(Json json) => Profile(
@@ -29,6 +34,9 @@
         weightKg: readNum(json, 'weight_kg'),
         activityLevel: readCode(json, 'activity_level', ActivityLevel.values, (v) => v.code),
         goal: readCode(json, 'goal', Goal.values, (v) => v.code),
+        // Hồ sơ lưu trước v2.6.0 không có trường này.
+        pregnantOrBreastfeeding:
+            json['pregnant_or_breastfeeding'] == null ? false : readBool(json, 'pregnant_or_breastfeeding'),
         restrictions: json['restrictions'] == null
             ? const Restrictions()
             : Restrictions.fromJson(readMap(json['restrictions'], 'restrictions')),
@@ -41,8 +49,12 @@
         'weight_kg': weightKg,
         'activity_level': activityLevel.code,
         'goal': goal.code,
+        'pregnant_or_breastfeeding': pregnantOrBreastfeeding,
         'restrictions': restrictions.toJson(),
       };
+
+  // So sánh theo JSON gửi đi: hai hồ sơ bằng nhau thì cho ra cùng một plan.
+  bool sameAs(Profile other) => jsonEncode(toJson()) == jsonEncode(other.toJson());
 }
 
 // Ba ô nhập tự do, tối đa 300 ký tự mỗi ô (BRD FR-1.4) — giới hạn này kiểm ở form (giai đoạn 6) và ở backend.
```

```diff
--- a/frontend_app/test/models/contract_test.dart
+++ b/frontend_app/test/models/contract_test.dart
@@ -32,6 +32,12 @@
       expect(Profile.fromJson(json).toJson(), equals(json));
     });
 
+    test('hồ sơ lưu trước v2.6.0 (không có pregnant_or_breastfeeding) vẫn đọc được', () {
+      final json = loadFixture('profile')..remove('pregnant_or_breastfeeding');
+      expect(Profile.fromJson(json).pregnantOrBreastfeeding, isFalse);
+      expect(() => Profile.fromJson({...loadFixture('profile'), 'pregnant_or_breastfeeding': 'có'}), throwsFormatException);
+    });
+
     test('auth_login, history, health', () {
       final auth = loadFixture('auth_login');
       expect(AuthResult.fromJson(auth).toJson(), equals(auth));
```

### Task 7 — Cổng kiểm tra F01

```bash
cd backend_api && npm run typecheck && npm run build
npm test            # Tests  268 passed (268)
npm run test:e2e    # Tests  74 passed (74)
npm run test:smoke && npm run lint
cd ../frontend_app && flutter analyze && flutter test   # +45: All tests passed!
```
