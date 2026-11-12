// Only fixed codes and DTO paths may leave the validator. Never use provider
// messages, names, ingredients or health text as diagnostic/repair instructions.
export interface PlanValidationIssue {
  validator:
    'class-validator' | 'plan-rules' | 'restrictions' | 'groq-response';
  kind: 'schema' | 'semantic' | 'safety' | 'response';
  code: string;
  path: string;
}

const HINTS: Record<string, string> = {
  EXERCISE_VERIFICATION:
    'Match name/instructions, movement features, muscle group, equipment, load tags and the actual user profile. For a new exercise include movement and profile_fit; a catalog name is not required. Do not lower claimed difficulty or remove tags to bypass restrictions. Known exercises retain reviewed metadata; respect workload caps.',
  JSON_OBJECT: 'Return one JSON object, not an array or scalar.',
  REQUIRED: 'Supply the required field using the original JSON contract.',
  ARRAY_SIZE:
    'Use exactly 3 days and 3 meals per day; respect other array bounds.',
  TYPE: 'Use the required JSON type; numbers must not be strings.',
  ENUM: 'Use only enum codes listed in the original prompt.',
  RANGE: 'Respect the original numeric and string length bounds.',
  SCHEMA: 'Follow the original DTO structure and required fields.',
  MEAL_TYPES: 'Each day needs one breakfast, one lunch and one dinner.',
  DAY_CALORIES:
    'Sum all three meals and keep the day within the original range, never below BMR.',
  MEAL_CALORIES:
    'Keep this meal within its meal_type calorie range from the original prompt.',
  MACRO_CALORIES:
    'Require abs(calories - (4*protein_g + 4*carbs_g + 9*fat_g)) <= 0.15*calories.',
  DUPLICATE_MEAL: 'Use distinct meal names across all nine meals.',
  RESTRICTION_CONFLICT:
    'Recheck every original ingredient and exercise restriction; do not remove restrictions.',
  INVALID_JSON: 'Return complete valid JSON without markdown or explanation.',
  INCOMPLETE_OUTPUT:
    'Return the complete three-day object within the output limit.',
};

const DTO_PATH =
  /^days(?:\[\d{1,3}\])?(?:\.(?:meals|workout|exercises|ingredients|meal_type|name|portion|calories|protein_g|carbs_g|fat_g|amount|unit|category|title|duration_minutes|sets|reps_or_duration|muscle_group|tags)(?:\[\d{1,3}\])?)*$/;

export function safePlanPath(path: string): string {
  return path === '$' || DTO_PATH.test(path) ? path : '$';
}

export function safePlanIssues(
  issues: readonly PlanValidationIssue[],
): PlanValidationIssue[] {
  return issues.slice(0, 12).map((issue) => ({
    validator: [
      'class-validator',
      'plan-rules',
      'restrictions',
      'groq-response',
    ].includes(issue.validator)
      ? issue.validator
      : 'class-validator',
    kind: ['schema', 'semantic', 'safety', 'response'].includes(issue.kind)
      ? issue.kind
      : 'schema',
    code: Object.hasOwn(HINTS, issue.code) ? issue.code : 'SCHEMA',
    path: safePlanPath(issue.path),
  }));
}

export function planRepairInstructions(
  issues: readonly PlanValidationIssue[],
): string {
  if (issues.length === 0) return '';
  const feedback = safePlanIssues(issues).map(({ code, path }) => ({
    code,
    path,
    rule: HINTS[code],
  }));
  return [
    '',
    '<plan_validation_feedback>',
    JSON.stringify(feedback),
    '</plan_validation_feedback>',
    'Tạo lại toàn bộ JSON 3 ngày; ưu tiên sửa các trường trên, rồi tự kiểm tra lại toàn bộ quy tắc ban đầu. Không bỏ hạn chế, không hạ sàn BMR. Không trả giải thích.',
  ].join('\n');
}
