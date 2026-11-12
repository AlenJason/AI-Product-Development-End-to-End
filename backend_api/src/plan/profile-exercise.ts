import type { CreatePlanDto } from './dto/create-plan.dto.js';
import { maxExerciseLevel } from './exercise-level.js';
import { ExerciseTag, MuscleGroup } from './enums/exercise.enum.js';
import { matchRestrictions } from './restriction-matcher.js';
import { workload } from './adjust/exercise-swap-validation.js';
import {
  exerciseKey,
  inferredLoads,
  metadataOf,
  ExerciseValidationError,
  type ExerciseDiagnostic,
} from './exercise-verification.js';
const object = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === 'object' && !Array.isArray(v);

// Unknown names are not a rejection criterion. These are conservative software
// checks on a proposal, not independent medical verification of model claims.
export function assessProfileExercise(
  raw: Record<string, unknown>,
  profile: CreatePlanDto,
): {
  value: Record<string, unknown>;
  level: number;
  repair: ExerciseDiagnostic;
} {
  const actual = metadataOf(raw),
    a = object(raw.assessment) ? raw.assessment : {},
    m = object(a.movement) ? a.movement : {},
    fit = object(a.profile_fit) ? a.profile_fit : {};
  const fail = (
    code: string,
    rule: string,
    expected: Record<string, unknown>,
  ): never => {
    throw new ExerciseValidationError(code, rule, expected, actual);
  };
  if (
    typeof raw.name !== 'string' ||
    !raw.name.trim() ||
    /can thay|can chon|placeholder/.test(exerciseKey(raw.name)) ||
    !Object.values(MuscleGroup).includes(raw.muscle_group as MuscleGroup) ||
    !actual.tags_valid
  )
    fail('AI_EXERCISE_ASSESSMENT_INVALID', 'EXERCISE_STRUCTURE', {
      valid_name: true,
      enum_metadata: true,
    });
  if (
    !Number.isInteger(a.difficulty_level) ||
    Number(a.difficulty_level) < 1 ||
    Number(a.difficulty_level) > 3 ||
    a.equipment !== 'none' ||
    !['low', 'moderate', 'high'].includes(String(a.impact)) ||
    typeof a.instructions !== 'string' ||
    a.instructions.trim().length < 20 ||
    a.instructions.length > 800
  )
    fail('AI_EXERCISE_ASSESSMENT_INVALID', 'MOVEMENT_ASSESSMENT_REQUIRED', {
      equipment: 'none',
      instructions_required: true,
    });
  const positions = [
    'standing',
    'seated_floor',
    'supine',
    'prone',
    'quadruped',
    'forearm_support',
    'hand_support',
  ];
  if (
    !positions.includes(String(m.position)) ||
    !['stable', 'single_leg'].includes(String(m.balance)) ||
    !['controlled', 'explosive'].includes(String(m.tempo))
  )
    fail('AI_EXERCISE_ASSESSMENT_INVALID', 'MOVEMENT_FEATURES_REQUIRED', {
      position: positions,
      balance: ['stable', 'single_leg'],
      tempo: ['controlled', 'explosive'],
    });
  // Check context identity without logging age/condition text in diagnostics.
  if (
    fit.age !== profile.age ||
    fit.activity_level !== profile.activity_level ||
    fit.restrictions_considered !== true ||
    typeof fit.reason !== 'string' ||
    fit.reason.trim().length < 20 ||
    fit.reason.length > 500
  )
    fail('AI_EXERCISE_PROFILE_CONFLICT', 'PROFILE_CONTEXT_MISMATCH', {
      context_matches: true,
      restrictions_considered: true,
    });
  const text = exerciseKey(`${raw.name as string} ${a.instructions as string}`);
  if (
    m.position === 'standing' &&
    /\b(nam sap|nam ngua|quy|chong khuyu|chong canh tay|chong ban tay)\b/.test(
      text,
    )
  )
    fail('AI_EXERCISE_INSTRUCTION_CONFLICT', 'POSITION_INSTRUCTION_CONFLICT', {
      position: 'standing',
    });
  if (m.position === 'standing' && !/\b(dung|standing)\b/.test(text))
    fail(
      'AI_EXERCISE_INSTRUCTION_CONFLICT',
      'POSITION_UNSUPPORTED_BY_DESCRIPTION',
      { position: 'standing' },
    );
  if (
    m.position === 'forearm_support' &&
    !/\b(cang tay|khuyu tay|forearm|elbow)\b/.test(text)
  )
    fail(
      'AI_EXERCISE_INSTRUCTION_CONFLICT',
      'POSITION_UNSUPPORTED_BY_DESCRIPTION',
      { position: 'forearm_support' },
    );
  if (
    /\b(ghe|chai nuoc|ta tay|barbell|dumbbell|may tap|day khang luc)\b/.test(
      text,
    )
  )
    fail('AI_EXERCISE_EQUIPMENT_CONFLICT', 'BODYWEIGHT_ONLY', {
      equipment: 'none',
    });
  const required = new Set(inferredLoads(text));
  if (m.position === 'quadruped') {
    required.add(ExerciseTag.KNEELING);
    required.add(ExerciseTag.WRIST_LOAD);
  }
  if (m.position === 'hand_support') required.add(ExerciseTag.WRIST_LOAD);
  if (/\b(gap lung|uon lung|xoay than|superman|hip hinge)\b/.test(text))
    required.add(ExerciseTag.BACK_LOAD);
  const tags = [...new Set([...actual.tags, ...required])];
  if (
    (tags.includes(ExerciseTag.JUMPING) || m.tempo === 'explosive') &&
    a.impact !== 'high'
  )
    fail('AI_EXERCISE_IMPACT_CONFLICT', 'MOVEMENT_IMPACT_CONFLICT', {
      impact: 'high',
    });
  if (
    matchRestrictions(profile.restrictions).avoidTags.some((tag) =>
      tags.includes(tag),
    )
  )
    fail('AI_EXERCISE_LOAD_CONFLICT', 'FORBIDDEN_MOVEMENT_LOAD', {
      required_tags: [...required],
    });
  const derived =
    tags.includes(ExerciseTag.JUMPING) ||
    m.tempo === 'explosive' ||
    a.impact === 'high'
      ? 3
      : m.balance === 'single_leg' ||
          /\b(mot chan|single leg)\b/.test(text) ||
          m.position === 'hand_support' ||
          m.position === 'forearm_support' ||
          tags.includes(ExerciseTag.WRIST_LOAD) ||
          tags.includes(ExerciseTag.BACK_LOAD)
        ? 2
        : 1;
  const level = Math.max(derived, Number(a.difficulty_level));
  if (level > maxExerciseLevel(profile))
    fail('AI_EXERCISE_LEVEL_CONFLICT', 'PROFILE_LEVEL_CAP', {
      max_level: maxExerciseLevel(profile),
      movement_level: derived,
    });
  if (level === 1 && (a.impact !== 'low' || m.tempo !== 'controlled'))
    fail('AI_EXERCISE_IMPACT_CONFLICT', 'LOW_LEVEL_MOVEMENT_CONFLICT', {
      impact: 'low',
      tempo: 'controlled',
    });
  const volume =
    typeof raw.reps_or_duration === 'string'
      ? workload(raw.reps_or_duration)
      : null;
  const limits =
    level === 1
      ? { sets: 3, reps: 20, seconds: 60 }
      : level === 2
        ? { sets: 4, reps: 30, seconds: 90 }
        : { sets: 6, reps: 40, seconds: 120 };
  if (
    !Number.isInteger(raw.sets) ||
    Number(raw.sets) < 1 ||
    Number(raw.sets) > limits.sets ||
    !volume ||
    volume.max > (volume.unit === 'reps' ? limits.reps : limits.seconds)
  )
    fail('AI_EXERCISE_VOLUME_CONFLICT', 'PROFILE_WORKLOAD_CAP', {
      max_sets: limits.sets,
      max_reps: limits.reps,
      max_seconds: limits.seconds,
    });
  const { assessment: _, ...value } = raw;
  return {
    value: { ...value, tags },
    level,
    repair: {
      error_code: 'AI_EXERCISE_PROFILE_ASSESSED',
      day_index: -1,
      exercise_index: -1,
      violated_rule: 'PROFILE_MOVEMENT_CHECKS',
      expected: {
        movement_level: derived,
        max_level: maxExerciseLevel(profile),
        required_tags: [...required],
      },
      actual,
      action: 'assessed',
    },
  };
}

export function profileAssessmentExample(
  profile: Pick<CreatePlanDto, 'age' | 'activity_level'>,
) {
  return {
    difficulty_level: 1,
    equipment: 'none',
    impact: 'low',
    instructions: 'Mô tả tư thế và cách thực hiện bài được chọn, 20–160 ký tự.',
    movement: { position: 'standing', balance: 'stable', tempo: 'controlled' },
    profile_fit: {
      age: profile.age,
      activity_level: profile.activity_level,
      restrictions_considered: true,
      reason:
        'Giải thích lựa chọn theo tuổi, thể lực và hạn chế đã khai; không khẳng định điều trị bệnh.',
    },
  };
}
