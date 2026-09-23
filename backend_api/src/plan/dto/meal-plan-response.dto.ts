import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { IngredientCategory } from '../enums/ingredient.enum.js';
import { PlanSource } from '../enums/plan-source.enum.js';
import { ExerciseContentDto, MealContentDto } from './plan-content.dto.js';

// Plan hoàn chỉnh server trả về (BRD mục 6.2): có ID, mục tiêu calo và danh sách đi chợ do server tính.

export class MealDto extends MealContentDto {
  @ApiProperty({ example: 'm1_1' })
  @IsString()
  @IsNotEmpty()
  meal_id: string;
}

export class ExerciseDto extends ExerciseContentDto {
  @ApiProperty({ example: 'e1_1' })
  @IsString()
  @IsNotEmpty()
  exercise_id: string;
}

export class WorkoutDto {
  @ApiProperty({ example: 'Vận động toàn thân tại nhà' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  title: string;

  @ApiProperty({ example: 20 })
  @IsInt()
  @Min(5)
  @Max(60)
  duration_minutes: number;

  @ApiProperty({ type: [ExerciseDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(8)
  @ValidateNested({ each: true })
  @Type(() => ExerciseDto)
  exercises: ExerciseDto[];
}

export class DayPlanDto {
  @ApiProperty({ example: 1 })
  @IsInt()
  @Min(1)
  @Max(3)
  day_number: number;

  @ApiProperty({ type: [MealDto] })
  @IsArray()
  @ArrayMinSize(3)
  @ArrayMaxSize(3)
  @ValidateNested({ each: true })
  @Type(() => MealDto)
  meals: MealDto[];

  @ApiProperty({ type: WorkoutDto })
  @ValidateNested()
  @Type(() => WorkoutDto)
  workout: WorkoutDto;
}

export class GroceryItemDto {
  @ApiProperty({ example: 'Gạo tẻ' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: '540g' })
  @IsString()
  @IsNotEmpty()
  quantity: string;

  @ApiProperty({ example: ['m1_2', 'm1_3'] })
  @IsArray()
  @IsString({ each: true })
  source_meal_ids: string[];
}

export class GroceryCategoryDto {
  @ApiProperty({ enum: IngredientCategory, example: IngredientCategory.PANTRY })
  @IsEnum(IngredientCategory)
  category: IngredientCategory;

  @ApiProperty({ type: [GroceryItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => GroceryItemDto)
  items: GroceryItemDto[];
}

export class DailyTargetDto {
  @ApiProperty({ example: 22 })
  @IsNumber()
  bmi: number;

  @ApiProperty({ example: 1399 })
  @IsNumber()
  bmr: number;

  @ApiProperty({ example: 1924 })
  @IsNumber()
  tdee: number;

  @ApiProperty({ example: 1624 })
  @IsNumber()
  target_calories: number;

  @ApiProperty({ example: 102 })
  @IsNumber()
  protein_g: number;

  @ApiProperty({ example: 183 })
  @IsNumber()
  carbs_g: number;

  @ApiProperty({ example: 54 })
  @IsNumber()
  fat_g: number;
}

export class MealPlanResponseDto {
  @ApiProperty({ example: '3f1c2b7e-6a55-4c1a-9f0e-2d9b1c7a4e10' })
  @IsUUID()
  plan_id: string;

  @ApiProperty({ enum: PlanSource, example: PlanSource.GEMINI })
  @IsEnum(PlanSource)
  source: PlanSource;

  @ApiProperty({ type: [String], example: [] })
  @IsArray()
  @IsString({ each: true })
  warnings: string[];

  @ApiProperty({ type: DailyTargetDto })
  @ValidateNested()
  @Type(() => DailyTargetDto)
  daily_target: DailyTargetDto;

  @ApiProperty({ type: [DayPlanDto] })
  @IsArray()
  @ArrayMinSize(3)
  @ArrayMaxSize(3)
  @ValidateNested({ each: true })
  @Type(() => DayPlanDto)
  days: DayPlanDto[];

  @ApiProperty({ type: [GroceryCategoryDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => GroceryCategoryDto)
  grocery_list: GroceryCategoryDto[];
}
