import type { ExerciseContentDto, WorkoutContentDto } from './dto/plan-content.dto.js';
import { MuscleGroup } from './enums/exercise.enum.js';

// Động tác dựng sẵn cho quy tắc feedback (BRD FR-5.2) và khi lọc hết động tác của một buổi.

export const WALK_EXERCISE: ExerciseContentDto = {
  name: 'Đi bộ nhẹ',
  sets: 1,
  reps_or_duration: '10-15 phút',
  muscle_group: MuscleGroup.CARDIO,
  tags: [],
};

export const STRETCH_EXERCISE: ExerciseContentDto = {
  name: 'Giãn cơ nhẹ các nhóm cơ đã tập',
  sets: 1,
  reps_or_duration: '5 phút',
  muscle_group: MuscleGroup.FULL_BODY,
  tags: [],
};

// Ngày sau khi báo dấu hiệu nguy hiểm: chỉ nghỉ hoặc đi bộ nhẹ (BRD FR-5.2, #14).
export const REST_WORKOUT: WorkoutContentDto = {
  title: 'Nghỉ ngơi — chỉ đi bộ nhẹ nếu thấy khoẻ',
  duration_minutes: 15,
  exercises: [{ ...WALK_EXERCISE, name: 'Đi bộ nhẹ (chỉ khi đã hết chóng mặt, khó thở, đau ngực)' }],
};
