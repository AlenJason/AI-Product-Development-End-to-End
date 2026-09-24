import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsDefined, IsEnum, IsInt, Matches, Max, Min, ValidateNested } from 'class-validator';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import { CreatePlanDto } from './create-plan.dto.js';
import { MealPlanResponseDto } from './meal-plan-response.dto.js';

// Request/response của đổi món, đổi bài tập, feedback (BRD mục 6.4). Backend không lưu trạng thái:
// client gửi cả hồ sơ lẫn plan hiện tại, nhận lại cả plan mới.

// @IsDefined: thiếu hẳn trường thì @ValidateNested bỏ qua không kiểm, service nhận undefined và trả 500.
export class AdjustPlanDto {
  @ApiProperty({ type: CreatePlanDto, description: 'Hồ sơ hiện tại, cùng cấu trúc request 6.1' })
  @IsDefined()
  @ValidateNested()
  @Type(() => CreatePlanDto)
  profile: CreatePlanDto;

  @ApiProperty({ type: MealPlanResponseDto, description: 'Plan đang dùng, đúng như server đã trả' })
  @IsDefined()
  @ValidateNested()
  @Type(() => MealPlanResponseDto)
  plan: MealPlanResponseDto;
}

export class SwapMealDto extends AdjustPlanDto {
  @ApiProperty({ example: 'm1_2' })
  @Matches(/^m[1-3]_[1-3]$/, { message: 'meal_id phải có dạng m{ngày}_{bữa}, ví dụ m1_2' })
  meal_id: string;
}

export class SwapExerciseDto extends AdjustPlanDto {
  @ApiProperty({ example: 'e1_3' })
  @Matches(/^e[1-3]_[1-8]$/, { message: 'exercise_id phải có dạng e{ngày}_{thứ tự}, ví dụ e1_3' })
  exercise_id: string;
}

export class FeedbackDto extends AdjustPlanDto {
  @ApiProperty({ example: 1, description: '1–2: điều chỉnh ngày kế tiếp; 3: tạo plan 3 ngày mới (FR-5.3)' })
  @IsInt()
  @Min(1)
  @Max(3)
  day_number: number;

  @ApiProperty({ enum: Intensity, example: Intensity.HARD })
  @IsEnum(Intensity)
  intensity: Intensity;

  @ApiProperty({ enum: BodyState, isArray: true, example: [BodyState.SORE] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(5)
  @IsEnum(BodyState, { each: true })
  body_states: BodyState[];

  @ApiProperty({ enum: Eating, example: Eating.OVER })
  @IsEnum(Eating)
  eating: Eating;
}

export class PlanEnvelopeDto {
  @ApiProperty({ type: MealPlanResponseDto })
  plan: MealPlanResponseDto;
}

export class SafetyWarningDto {
  @ApiProperty({ example: 'Hãy ngừng tập và hỏi ý kiến bác sĩ…' })
  message: string;
}

export class FeedbackResponseDto extends PlanEnvelopeDto {
  @ApiProperty({ type: SafetyWarningDto, nullable: true, description: 'Khác null khi có dấu hiệu nguy hiểm' })
  safety_warning: SafetyWarningDto | null;
}
