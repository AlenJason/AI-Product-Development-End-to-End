import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  Max,
  Min,
  Validate,
  ValidateNested,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ActivityLevel } from '../enums/activity-level.enum.js';
import { Gender } from '../enums/gender.enum.js';
import { Goal } from '../enums/goal.enum.js';
import { MAX_AGE, MIN_AGE } from '../profile-safety.js';
import { PregnancyNeedsFemaleConstraint, SafeGoalConstraint } from './profile-safety.validator.js';
import { RestrictionsDto } from './restrictions.dto.js';

// Khớp với JSON request schema ở BRD.md mục 6.1.
export class CreatePlanDto {
  @ApiProperty({ example: 22, minimum: MIN_AGE, maximum: MAX_AGE })
  @IsInt()
  @Min(MIN_AGE)
  @Max(MAX_AGE)
  age: number;

  @ApiProperty({ enum: Gender, example: Gender.FEMALE })
  @IsEnum(Gender)
  gender: Gender;

  @ApiProperty({ example: 168 })
  @IsNumber()
  @Min(100)
  @Max(250)
  height_cm: number;

  @ApiProperty({ example: 62 })
  @IsNumber()
  @Min(30)
  @Max(250)
  weight_kg: number;

  @ApiProperty({ enum: ActivityLevel, example: ActivityLevel.LIGHT })
  @IsEnum(ActivityLevel)
  activity_level: ActivityLevel;

  @ApiProperty({ enum: Goal, example: Goal.CUT, description: 'cut bị từ chối khi BMI < 18,5 hoặc pregnant_or_breastfeeding' })
  @IsEnum(Goal)
  @Validate(SafeGoalConstraint)
  goal: Goal;

  // Dữ liệu sức khoẻ như `restrictions`: không lưu DB, không ghi log (NFR-7, #12).
  @ApiPropertyOptional({ example: false, description: 'Đang mang thai hoặc cho con bú — chỉ khi gender = female' })
  @IsOptional()
  @IsBoolean()
  @Validate(PregnancyNeedsFemaleConstraint)
  pregnant_or_breastfeeding: boolean = false;

  @ApiPropertyOptional({ type: RestrictionsDto })
  @ValidateNested()
  @Type(() => RestrictionsDto)
  restrictions: RestrictionsDto = new RestrictionsDto();
}
