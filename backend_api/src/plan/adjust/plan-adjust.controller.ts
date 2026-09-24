import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiConflictResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
  ApiUnprocessableEntityResponse,
} from '@nestjs/swagger';
import { CurrentUser, OptionalJwtAuthGuard } from '../../auth/jwt-auth.guard.js';
import type { User } from '../../database/entities/user.entity.js';
import { HistoryService } from '../../history/history.service.js';
import { FeedbackDto, FeedbackResponseDto, PlanEnvelopeDto, SwapExerciseDto, SwapMealDto } from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { WARNINGS } from '../plan-warnings.js';
import { ExerciseSwapService } from './exercise-swap.service.js';
import { FeedbackService } from './feedback.service.js';
import { MealSwapService } from './meal-swap.service.js';

// Đổi món, đổi bài tập, feedback (BRD mục 6.4). Đăng nhập tuỳ chọn như generate-plan: có token hợp lệ thì
// cập nhật plan đã lưu (hoặc lưu mới plan từ feedback ngày 3) — quyết định Q4 giai đoạn 4.
@ApiTags('plan')
@ApiBearerAuth()
@ApiBadRequestResponse({ description: 'Request hoặc plan gửi lên sai hợp đồng, hoặc ID không có trong plan' })
@ApiConflictResponse({ description: 'Plan được tạo cho hồ sơ khác (mục tiêu calo đã đổi) — cần tạo plan mới' })
@ApiUnauthorizedResponse({ description: 'Có gửi token nhưng token sai, hết hạn, hoặc tài khoản đã bị xoá' })
@UseGuards(OptionalJwtAuthGuard)
@Controller('api/v1')
export class PlanAdjustController {
  constructor(
    private readonly meals: MealSwapService,
    private readonly exercises: ExerciseSwapService,
    private readonly feedback: FeedbackService,
    private readonly history: HistoryService,
  ) {}

  @Post('meals/swap')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đổi một món, calo lệch ≤ ±10% (BRD FR-4.1)' })
  @ApiOkResponse({ type: PlanEnvelopeDto })
  @ApiUnprocessableEntityResponse({ description: 'Không còn món thay thế phù hợp' })
  async swapMeal(@Body() dto: SwapMealDto, @CurrentUser() user: User | undefined): Promise<PlanEnvelopeDto> {
    return { plan: await this.record(user, await this.meals.swap(dto), false) };
  }

  @Post('exercises/swap')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đổi một động tác sang động tác nhẹ hơn, cùng nhóm cơ (BRD FR-4.2)' })
  @ApiOkResponse({ type: PlanEnvelopeDto })
  @ApiUnprocessableEntityResponse({ description: 'Không còn động tác nhẹ hơn phù hợp' })
  async swapExercise(@Body() dto: SwapExerciseDto, @CurrentUser() user: User | undefined): Promise<PlanEnvelopeDto> {
    return { plan: await this.record(user, await this.exercises.swap(dto), false) };
  }

  @Post('feedback')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Feedback cuối ngày: điều chỉnh ngày kế tiếp, ngày 3 tạo plan mới (BRD FR-5)' })
  @ApiOkResponse({ type: FeedbackResponseDto })
  async submitFeedback(@Body() dto: FeedbackDto, @CurrentUser() user: User | undefined): Promise<FeedbackResponseDto> {
    const { response, isNewPlan } = await this.feedback.apply(dto);
    return { ...response, plan: await this.record(user, response.plan, isNewPlan) };
  }

  private async record(user: User | undefined, plan: MealPlanResponseDto, isNew: boolean): Promise<MealPlanResponseDto> {
    if (!user) return plan;
    const saved = isNew ? await this.history.save(user.id, plan) : await this.history.update(user.id, plan);
    if (!saved) plan.warnings.push(WARNINGS.historyNotSaved);
    return plan;
  }
}
