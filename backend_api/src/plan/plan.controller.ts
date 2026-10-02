import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiTooManyRequestsResponse,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { CurrentUser, OptionalJwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { User } from '../database/entities/user.entity.js';
import { HistoryService } from '../history/history.service.js';
import { RateLimit, RateLimitGuard } from '../rate-limit/rate-limit.guard.js';
import { CreatePlanDto } from './dto/create-plan.dto.js';
import { MealPlanResponseDto } from './dto/meal-plan-response.dto.js';
import { PlanService } from './plan.service.js';
import { WARNINGS } from './plan-warnings.js';

@ApiTags('plan')
@Controller('api/v1')
export class PlanController {
  constructor(
    private readonly planService: PlanService,
    private readonly history: HistoryService,
  ) {}

  @Post('generate-plan')
  @HttpCode(HttpStatus.OK)
  // Thứ tự: biết người gọi trước (OptionalJwtAuthGuard), rồi mới đếm lượt — theo tài khoản hoặc theo IP (PLAN 9.7).
  @UseGuards(OptionalJwtAuthGuard, RateLimitGuard)
  @RateLimit('plan')
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Sinh kế hoạch ăn uống & tập luyện 3 ngày (BRD FR-1, FR-2)',
    description: 'Đăng nhập là tuỳ chọn: có token hợp lệ thì kế hoạch được lưu vào lịch sử (FR-7.1).',
  })
  @ApiOkResponse({ type: MealPlanResponseDto, description: 'Kế hoạch 3 ngày theo BRD.md mục 6.2' })
  @ApiUnauthorizedResponse({ description: 'Có gửi token nhưng token sai, hết hạn, hoặc tài khoản đã bị xoá' })
  @ApiTooManyRequestsResponse({
    description: 'Quá số lần tạo plan cho phép (RATE_LIMIT_PLAN) — header Retry-After là số giây phải chờ',
  })
  async generatePlan(
    @Body() dto: CreatePlanDto,
    @CurrentUser() user: User | undefined,
  ): Promise<MealPlanResponseDto> {
    const plan = await this.planService.generatePlan(dto);
    if (user && !(await this.history.save(user.id, plan))) {
      plan.warnings.push(WARNINGS.historyNotSaved);
    }
    return plan;
  }
}
