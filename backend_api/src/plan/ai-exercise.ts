import type { CreatePlanDto } from './dto/create-plan.dto.js';
import type { ExerciseContentDto } from './dto/plan-content.dto.js';
import { maxExerciseLevel } from './exercise-level.js';
import { exerciseCandidates, toPlanExercise } from './swap-pools.js';
import { normalizeKey } from './text.util.js';
import { matchRestrictions } from './restriction-matcher.js';
import { workload } from './adjust/exercise-swap-validation.js';
import { MuscleGroup, ExerciseTag } from './enums/exercise.enum.js';
import {
  assessProfileExercise,
  profileAssessmentExample,
} from './profile-exercise.js';
import {
  exerciseKey,
  verifiedExercise,
  inferredLoads,
  metadataOf,
  ExerciseValidationError,
  type ExerciseDiagnostic,
} from './exercise-verification.js';

const object = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === 'object' && !Array.isArray(v);
export function assessedExercise(
  raw: unknown,
  profile: CreatePlanDto,
): { value: unknown; level?: number; repair?: ExerciseDiagnostic } {
  if (!object(raw)) return { value: raw };
  const actual = metadataOf(raw),
    a = object(raw.assessment) ? raw.assessment : {};
  const fail = (
    code: string,
    rule: string,
    expected: Record<string, unknown>,
  ): never => {
    throw new ExerciseValidationError(code, rule, expected, actual);
  };
  const known =
    typeof raw.name === 'string' ? verifiedExercise(raw.name) : undefined;
  const instructions = typeof a.instructions === 'string' ? a.instructions : '';
  const text = exerciseKey(
    `${typeof raw.name === 'string' ? raw.name : ''} ${instructions}`,
  );
  if (
    /\b(barbell|dumbbell|kettlebell|may tap|ta don|ta tay|xa don|day khang luc|chai nuoc)\b/.test(
      text,
    )
  )
    fail('AI_EXERCISE_EQUIPMENT_CONFLICT', 'BODYWEIGHT_ONLY', {
      equipment: 'none',
    });
  if (!known) {
    if (
      typeof raw.name === 'string' &&
      /khong dung ghe/.test(exerciseKey(raw.name))
    )
      fail(
        'AI_EXERCISE_INSTRUCTION_CONFLICT',
        'CONTRADICTORY_SUPPORT_IDENTITY',
        { support: 'unambiguous verified movement' },
      );
    if (
      actual.tags.includes(ExerciseTag.KNEELING) &&
      /\b(dung|standing|squat)\b/.test(text)
    )
      fail('AI_EXERCISE_LOAD_CONFLICT', 'STANDING_WITH_KNEELING_TAG', {
        posture: 'standing',
        kneeling: false,
      });
    return assessProfileExercise(raw, profile);
  }
  if (/\b(ghe|chai nuoc)\b/.test(exerciseKey(known!.name)))
    fail('AI_EXERCISE_EQUIPMENT_CONFLICT', 'VERIFIED_EQUIPMENT_REQUIRED', {
      equipment: 'none',
      verified_equipment: /chai nuoc/.test(exerciseKey(known!.name))
        ? 'bottle'
        : 'chair',
    });
  if (
    known!.name === 'Bird-dog' &&
    /\bnam sap\b/.test(exerciseKey(instructions))
  )
    fail('AI_EXERCISE_INSTRUCTION_CONFLICT', 'IDENTITY_INSTRUCTION_CONFLICT', {
      position: 'quadruped',
    });
  if (
    known!.name === 'Chống đẩy tường' &&
    /\b(nam sap|nam san|chong day san)\b/.test(exerciseKey(instructions))
  )
    fail('AI_EXERCISE_INSTRUCTION_CONFLICT', 'IDENTITY_INSTRUCTION_CONFLICT', {
      support: 'wall',
    });
  const introduced = inferredLoads(instructions).filter(
    (tag) =>
      !known!.tags.includes(tag) &&
      !(tag === ExerciseTag.WRIST_LOAD && known!.name === 'Chống đẩy tường'),
  );
  if (introduced.length)
    fail(
      'AI_EXERCISE_INSTRUCTION_CONFLICT',
      'INSTRUCTIONS_ADD_UNVERIFIED_LOAD',
      { verified_tags: known!.tags, unexpected_tags: introduced },
    );
  if (known!.level > maxExerciseLevel(profile))
    fail('AI_EXERCISE_LEVEL_CONFLICT', 'PROFILE_LEVEL_CAP', {
      max_level: maxExerciseLevel(profile),
      verified_level: known!.level,
    });
  const avoid = matchRestrictions(profile.restrictions).avoidTags;
  if (known!.tags.some((t) => avoid.includes(t)))
    fail('AI_EXERCISE_LOAD_CONFLICT', 'FORBIDDEN_VERIFIED_LOAD', {
      forbidden_tags: avoid,
      verified_tags: known!.tags,
    });
  const baseline = workload(known!.reps_or_duration),
    volume =
      typeof raw.reps_or_duration === 'string'
        ? workload(raw.reps_or_duration)
        : null;
  const knownLimit = baseline?.max ?? 0;
  if (
    !Number.isInteger(raw.sets) ||
    Number(raw.sets) < 1 ||
    Number(raw.sets) > known!.sets ||
    !baseline ||
    !volume ||
    volume.unit !== baseline.unit ||
    volume.max > knownLimit
  )
    fail('AI_EXERCISE_VOLUME_CONFLICT', 'VERIFIED_WORKLOAD_CAP', {
      max_sets: known!.sets,
      max_workload: knownLimit,
      unit: baseline?.unit ?? 'INVALID',
    });
  const { assessment: _, ...rest } = raw;
  const impact = known!.tags.includes(ExerciseTag.JUMPING)
    ? 'high'
    : known!.level === 1
      ? 'low'
      : 'moderate';
  const value = {
    ...rest,
    name: known!.name,
    muscle_group: known!.muscle_group,
    tags: [...known!.tags],
  };
  const changed =
    actual.muscle_group !== known!.muscle_group ||
    !actual.tags_valid ||
    JSON.stringify([...actual.tags].sort()) !==
      JSON.stringify([...known!.tags].sort()) ||
    (object(raw.assessment) &&
      (a.difficulty_level !== known!.level ||
        a.equipment !== 'none' ||
        a.impact !== impact));
  return {
    value,
    level: known!.level,
    ...(changed
      ? {
          repair: {
            error_code: 'AI_EXERCISE_METADATA_REPAIRED',
            day_index: -1,
            exercise_index: -1,
            violated_rule: 'VERIFIED_METADATA_WINS',
            expected: {
              muscle_group: known!.muscle_group,
              tags: known!.tags,
              difficulty_level: known!.level,
              equipment: 'none',
              impact,
            },
            actual,
            action: 'repaired' as const,
          },
        }
      : {}),
  };
}

export function prepareAiPlanExercises(
  raw: unknown,
  profile: CreatePlanDto,
  onDiagnostic?: (d: ExerciseDiagnostic) => void,
): unknown {
  if (!object(raw) || !Array.isArray(raw.days)) return raw;
  const avoidTags = matchRestrictions(profile.restrictions).avoidTags,
    maxLevel = maxExerciseLevel(profile);
  return {
    ...raw,
    days: raw.days.map((day, di) => {
      if (
        !object(day) ||
        !object(day.workout) ||
        !Array.isArray(day.workout.exercises)
      )
        return day;
      const used = new Set<string>();
      return {
        ...day,
        workout: {
          ...day.workout,
          exercises: day.workout.exercises.map((e, ei) => {
            try {
              const result = assessedExercise(e, profile);
              if (result.repair)
                onDiagnostic?.({
                  ...result.repair,
                  day_index: di,
                  exercise_index: ei,
                });
              if (object(result.value) && typeof result.value.name === 'string')
                used.add(normalizeKey(result.value.name));
              return result.value;
            } catch (error) {
              if (!(error instanceof ExerciseValidationError)) throw error;
              error.day_index = di;
              error.exercise_index = ei;
              const group =
                object(e) &&
                Object.values(MuscleGroup).includes(
                  e.muscle_group as MuscleGroup,
                )
                  ? (e.muscle_group as MuscleGroup)
                  : null;
              if (!group) {
                onDiagnostic?.(error.diagnostic());
                throw error;
              }
              const candidates = exerciseCandidates(group, {
                avoidTags,
                excludeNames: used,
                maxLevel,
              }).filter((c) => !/(chai nước|ghế)/iu.test(c.name));
              if (!candidates.length)
                candidates.push(
                  ...exerciseCandidates(MuscleGroup.CARDIO, {
                    avoidTags,
                    excludeNames: used,
                    maxLevel: 1,
                  }),
                );
              for (const c of candidates) {
                const replacement = toPlanExercise(c);
                try {
                  const verified = assessedExercise(replacement, profile)
                    .value as ExerciseContentDto;
                  used.add(normalizeKey(verified.name));
                  onDiagnostic?.(error.diagnostic('replaced'));
                  return verified;
                } catch {
                  /* Try the next independently validated candidate. */
                }
              }
              onDiagnostic?.(error.diagnostic());
              throw error;
            }
          }),
        },
      };
    }),
  };
}

export function aiExerciseInstructions(profile: CreatePlanDto): string[] {
  return [
    '- Chọn bài từ kiến thức thể dục theo hồ sơ đã cung cấp; không giới hạn theo kho bài mẫu hoặc lặp một bộ ba cố định.',
    '- Phân bố nhóm cơ/vận động giữa các ngày theo khả năng; có thể lặp khởi động, nhưng không sao chép nguyên buổi tập cho mọi ngày chỉ vì ví dụ JSON.',
    '- Đề xuất bài có thật, tên và hướng dẫn phải cùng một động tác. Không ghi tên có ghế rồi mô tả không dùng ghế; không ghi tư thế chống bốn điểm nhưng hướng dẫn lại nằm sấp.',
    `- Mức khó tối đa ${maxExerciseLevel(profile)}. Tuổi ${profile.age}, vận động ${profile.activity_level}; xét cả thai kỳ và hạn chế. Không tự khai difficulty_level thấp để vượt mức.`,
    '- Mỗi bài thêm assessment nội bộ: {"difficulty_level":1,"equipment":"none","impact":"low","instructions":"Mô tả rõ tư thế và cách thực hiện, tối thiểu20 ký tự"}. Bài đã biết được đối chiếu metadata chuẩn; bài mới được kiểm cấu trúc vận động và hồ sơ, không bắt buộc có tên trong kho.',
    '- Tags là loại tải, không phải nhóm cơ: kneeling chỉ khi thực sự quỳ/chịu tải đầu gối, không gắn cho squat hay nâng gối đứng. wrist_load cho chống tay chịu tải, không tự gắn cho plank cẳng tay/khuỷu tay. overhead khi đưa tay qua đầu.',
    '- Không bỏ tags để lách chấn thương. Không nhảy/không bật nhảy nghĩa là không có jumping; tên, instructions, impact và tags phải nhất quán.',
    '- Bodyweight, không tạ/máy/dây/chai nước. Bài ngoài kho được nhận khi metadata vận động và ngữ cảnh hồ sơ nhất quán; không bị loại chỉ vì tên mới. Mức1 tối đa3 hiệp/20 lần hoặc60 giây; mức2 tối đa4 hiệp/30 lần hoặc90 giây; mức3 tối đa6 hiệp/40 lần hoặc120 giây.',
    '- assessment.movement mô tả position (standing/seated_floor/supine/prone/quadruped/forearm_support/hand_support), balance (stable/single_leg), tempo (controlled/explosive). Backend suy tải và kiểm lại giới hạn, không chỉ tin difficulty_level.',
    '- assessment.profile_fit phải đúng age/activity_level, restrictions_considered=true và reason giải thích ngắn theo tuổi, bệnh nền/chấn thương đã khai. Không chẩn đoán hoặc khẳng định an toàn tuyệt đối; thông tin không rõ thì đề xuất thận trọng.',
    JSON.stringify(profileAssessmentExample(profile)),
  ];
}
