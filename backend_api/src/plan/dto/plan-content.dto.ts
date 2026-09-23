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
  IsPositive,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { ExerciseTag, MuscleGroup } from '../enums/exercise.enum.js';
import { IngredientCategory, IngredientUnit } from '../enums/ingredient.enum.js';
import { MealType } from '../enums/meal-type.enum.js';

// Nội dung plan do Gemini hoặc thực đơn mẫu tạo ra (BRD mục 6.2), chưa có ID và danh sách đi chợ.

export class IngredientDto {
  @ApiProperty({ example: 'Ức gà' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  name: string;

  @ApiProperty({ example: 150 })
  @IsNumber()
  @IsPositive()
  @Max(5000)
  amount: number;

  @ApiProperty({ enum: IngredientUnit, example: IngredientUnit.G })
  @IsEnum(IngredientUnit)
  unit: IngredientUnit;

  @ApiProperty({ enum: IngredientCategory, example: IngredientCategory.PROTEIN })
  @IsEnum(IngredientCategory)
  category: IngredientCategory;
}

export class MealContentDto {
  @ApiProperty({ enum: MealType, example: MealType.BREAKFAST })
  @IsEnum(MealType)
  meal_type: MealType;

  @ApiProperty({ example: 'Bún thịt bò nạc' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name: string;

  @ApiProperty({ example: '1 tô vừa' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  portion: string;

  @ApiProperty({ example: 410 })
  @IsNumber()
  @IsPositive()
  calories: number;

  @ApiProperty({ example: 25 })
  @IsNumber()
  @Min(0)
  protein_g: number;

  @ApiProperty({ example: 55 })
  @IsNumber()
  @Min(0)
  carbs_g: number;

  @ApiProperty({ example: 10 })
  @IsNumber()
  @Min(0)
  fat_g: number;

  @ApiProperty({ type: [IngredientDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(15)
  @ValidateNested({ each: true })
  @Type(() => IngredientDto)
  ingredients: IngredientDto[];
}

export class ExerciseContentDto {
  @ApiProperty({ example: 'Squat tay không' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  name: string;

  @ApiProperty({ example: 3 })
  @IsInt()
  @Min(1)
  @Max(6)
  sets: number;

  @ApiProperty({ example: '12-15 lần' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  reps_or_duration: string;

  @ApiProperty({ enum: MuscleGroup, example: MuscleGroup.LEGS })
  @IsEnum(MuscleGroup)
  muscle_group: MuscleGroup;

  @ApiProperty({ enum: ExerciseTag, isArray: true, example: [] })
  @IsArray()
  @IsEnum(ExerciseTag, { each: true })
  tags: ExerciseTag[] = [];
}

export class WorkoutContentDto {
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

  @ApiProperty({ type: [ExerciseContentDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(8)
  @ValidateNested({ each: true })
  @Type(() => ExerciseContentDto)
  exercises: ExerciseContentDto[];
}

export class DayContentDto {
  @ApiProperty({ type: [MealContentDto] })
  @IsArray()
  @ArrayMinSize(3)
  @ArrayMaxSize(3)
  @ValidateNested({ each: true })
  @Type(() => MealContentDto)
  meals: MealContentDto[];

  @ApiProperty({ type: WorkoutContentDto })
  @ValidateNested()
  @Type(() => WorkoutContentDto)
  workout: WorkoutContentDto;
}

export class PlanContentDto {
  @ApiProperty({ type: [DayContentDto] })
  @IsArray()
  @ArrayMinSize(3)
  @ArrayMaxSize(3)
  @ValidateNested({ each: true })
  @Type(() => DayContentDto)
  days: DayContentDto[];
}
