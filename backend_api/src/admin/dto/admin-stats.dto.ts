import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Matches, Max, Min } from 'class-validator';

const MONTH_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;
const OUTCOMES = ['ok', 'timeout', 'overloaded', 'quota', 'invalid', 'error'];

export class MonthParamDto {
  @ApiProperty({ example: '2026-10' })
  @Matches(MONTH_PATTERN, { message: 'month phải có dạng YYYY-MM' })
  month: string;
}

export class GeminiCallsQueryDto {
  @ApiProperty({ example: '2026-10' })
  @Matches(MONTH_PATTERN, { message: 'month phải có dạng YYYY-MM' })
  month: string;

  @ApiPropertyOptional({ enum: OUTCOMES })
  @IsOptional()
  @IsIn(OUTCOMES)
  outcome?: string;

  @ApiPropertyOptional({ example: 1, default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100_000)
  page: number = 1;
}

export class UsageCountDto {
  @ApiProperty({ example: 12 })
  count: number;

  @ApiProperty({ example: 180_000, description: 'Tổng thời gian (ms) — chia cho count ra trung bình' })
  total_ms: number;
}

export class AdminGeminiSummaryDto {
  @ApiProperty({ example: 'gemini-3.5-flash' })
  model: string;

  @ApiProperty({ example: 'overloaded', enum: OUTCOMES })
  outcome: string;

  @ApiProperty({ example: 4 })
  calls: number;

  @ApiProperty({ example: 20_400 })
  avg_ms: number;
}

class AdminGeminiConfigDto {
  @ApiProperty()
  configured: boolean;

  @ApiProperty({ example: 'gemini-3.5-flash' })
  primary_model: string;

  @ApiProperty({ example: 'gemini-3.6-flash', nullable: true, type: String })
  fallback_model: string | null;

  @ApiProperty({ example: 45_000 })
  per_call_timeout_ms: number;

  @ApiProperty({ example: 50_000 })
  total_timeout_ms: number;

  @ApiProperty({ example: 20 })
  daily_limit_per_model: number;
}

class AdminGeminiTodayDto {
  @ApiProperty({ example: 'gemini-3.5-flash' })
  model: string;

  @ApiProperty({ example: 7, description: 'Số lần gọi hôm nay (giờ Việt Nam) — gói miễn phí cho 20 lần mỗi model' })
  calls: number;

  @ApiProperty({ example: 5 })
  ok: number;
}

class AdminRateLimitsDto {
  @ApiProperty({ example: '5 lần / 10 phút' })
  plan: string;

  @ApiProperty({ example: '30 lần / 10 phút' })
  adjust: string;

  @ApiProperty({ example: '5 lần / 15 phút' })
  admin: string;
}

export class AdminOverviewDto {
  @ApiProperty({ example: '2026-10-03', description: 'Hôm nay theo giờ Việt Nam' })
  today: string;

  @ApiProperty({ type: AdminGeminiConfigDto })
  gemini: AdminGeminiConfigDto;

  @ApiProperty({ type: [AdminGeminiTodayDto] })
  gemini_today: AdminGeminiTodayDto[];

  @ApiProperty({ example: 42, description: 'Số tài khoản (chỉ đếm)' })
  accounts: number;

  @ApiProperty({ example: 130, description: 'Số kế hoạch đã lưu trong lịch sử (chỉ đếm)' })
  saved_plans: number;

  @ApiProperty({ type: AdminRateLimitsDto })
  rate_limits: AdminRateLimitsDto;
}

export class AdminMonthDto {
  @ApiProperty({ example: '2026-10' })
  month: string;

  @ApiProperty({
    type: 'object',
    additionalProperties: { $ref: '#/components/schemas/UsageCountDto' },
    example: { 'plan.gemini': { count: 12, total_ms: 180_000 } },
  })
  usage: Record<string, UsageCountDto>;

  @ApiProperty({ type: [AdminGeminiSummaryDto] })
  gemini: AdminGeminiSummaryDto[];
}

export class AdminDayDto {
  @ApiProperty({ example: '2026-10-03' })
  day: string;

  @ApiProperty({ type: 'object', additionalProperties: { $ref: '#/components/schemas/UsageCountDto' } })
  usage: Record<string, UsageCountDto>;

  @ApiProperty({ type: [AdminGeminiSummaryDto] })
  gemini: AdminGeminiSummaryDto[];
}

export class AdminMonthDetailDto {
  @ApiProperty({ example: '2026-10' })
  month: string;

  @ApiProperty({ type: [AdminDayDto] })
  days: AdminDayDto[];
}

export class AdminGeminiCallDto {
  @ApiProperty({ example: '2026-10-03T04:36:15.120Z' })
  created_at: string;

  @ApiProperty({ example: 'plan', enum: ['plan', 'meal_swap', 'exercise_swap', 'feedback'] })
  task: string;

  @ApiProperty({ example: 'gemini-3.5-flash' })
  model: string;

  @ApiProperty({ example: 1 })
  attempt: number;

  @ApiProperty({ example: 'overloaded', enum: OUTCOMES })
  outcome: string;

  @ApiProperty({ example: 503, nullable: true, type: Number })
  http_status: number | null;

  @ApiProperty({ example: 20_412 })
  duration_ms: number;

  @ApiProperty({ example: '503 UNAVAILABLE — This model is currently experiencing high demand.', nullable: true, type: String })
  message: string | null;
}

export class AdminGeminiCallsDto {
  @ApiProperty({ example: '2026-10' })
  month: string;

  @ApiProperty({ example: 1 })
  page: number;

  @ApiProperty({ example: 50 })
  page_size: number;

  @ApiProperty({ example: 37 })
  total: number;

  @ApiProperty({ type: [AdminGeminiCallDto] })
  calls: AdminGeminiCallDto[];
}
