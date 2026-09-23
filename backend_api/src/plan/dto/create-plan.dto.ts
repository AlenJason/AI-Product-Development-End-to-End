import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsNumber,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ActivityLevel } from '../enums/activity-level.enum.js';
import { Gender } from '../enums/gender.enum.js';
import { Goal } from '../enums/goal.enum.js';
import { RestrictionsDto } from './restrictions.dto.js';

// Khớp với JSON request schema ở BRD.md mục 6.1.
export class CreatePlanDto {
  @ApiProperty({ example: 22 })
  @IsInt()
  @Min(10)
  @Max(100)
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

  @ApiProperty({ enum: Goal, example: Goal.CUT })
  @IsEnum(Goal)
  goal: Goal;

  @ApiPropertyOptional({ type: RestrictionsDto })
  @ValidateNested()
  @Type(() => RestrictionsDto)
  restrictions: RestrictionsDto = new RestrictionsDto();
}
