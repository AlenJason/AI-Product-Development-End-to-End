import { ApiProperty } from '@nestjs/swagger';

export class PlanSummaryDto {
  @ApiProperty({ format: 'uuid', description: 'plan_id của kế hoạch' })
  id: string;

  @ApiProperty({ example: '2026-09-22T10:00:00.000Z', description: 'Thời điểm tạo, ISO 8601 (UTC)' })
  created_at: string;

  @ApiProperty({ example: 1850 })
  target_calories: number;
}

export class PlanHistoryResponseDto {
  @ApiProperty({ type: [PlanSummaryDto], description: `Tối đa 50 kế hoạch, mới nhất trước` })
  plans: PlanSummaryDto[];
}
