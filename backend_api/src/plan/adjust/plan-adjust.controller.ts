import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiConflictResponse,
  ApiForbiddenResponse,
  ApiServiceUnavailableResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
  ApiUnprocessableEntityResponse,
} from '@nestjs/swagger';
import {
  CurrentUser,
  OptionalJwtAuthGuard,
} from '../../auth/jwt-auth.guard.js';
import type { User } from '../../database/entities/user.entity.js';
import { HistoryService } from '../../history/history.service.js';
import {
  FeedbackDto,
  FeedbackResponseDto,
  PlanEnvelopeDto,
  SwapExerciseDto,
  SwapMealDto,
} from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { WARNINGS } from '../plan-warnings.js';
import { ExerciseSwapService } from './exercise-swap.service.js';
import { FeedbackService } from './feedback.service.js';
import { MealSwapService } from './meal-swap.service.js';

@ApiTags('plan')
@ApiBearerAuth()
@ApiBadRequestResponse({
  description:
    'Request hoặc plan gửi lên sai hợp đồng, hoặc ID không có trong plan',
})
@ApiConflictResponse({
  description:
    'Plan được tạo cho hồ sơ khác (mục tiêu calo đã đổi) — cần tạo plan mới',
})
@ApiUnauthorizedResponse({
  description:
    'Có gửi token nhưng token sai, hết hạn, hoặc tài khoản đã bị xoá',
})
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
  @ApiOperation({ summary: 'Đổi một món, calo lệch ±10% (BRD FR-4.1)' })
  @ApiOkResponse({ type: PlanEnvelopeDto })
  @ApiUnprocessableEntityResponse({
    description: 'Không còn món thay thế phù hợp',
  })
  async swapMeal(
    @Body() dto: SwapMealDto,
    @CurrentUser() user: User | undefined,
  ): Promise<PlanEnvelopeDto> {
    return { plan: await this.record(user, await this.meals.swap(dto), false) };
  }

  @Post('exercises/swap')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Đổi một động tác sang bài nhẹ hơn cùng nhóm cơ (BRD FR-4.2)',
  })
  @ApiOkResponse({ type: PlanEnvelopeDto })
  @ApiUnprocessableEntityResponse({
    description: 'Không còn động tác nhẹ hơn phù hợp',
  })
  async swapExercise(
    @Body() dto: SwapExerciseDto,
    @CurrentUser() user: User | undefined,
  ): Promise<PlanEnvelopeDto> {
    return {
      plan: await this.record(user, await this.exercises.swap(dto), false),
    };
  }

  @Post('feedback')
  @ApiForbiddenResponse({
    description: 'Kế hoạch đã lưu thuộc tài khoản khác.',
  })
  @ApiServiceUnavailableResponse({
    description:
      'Không thể ghi nhận kết quả bền vững; giữ plan cũ và retry nguyên request.',
  })
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Điều chỉnh kế hoạch theo phản hồi cuối ngày (BRD FR-5)',
  })
  @ApiConflictResponse({
    description:
      'Khóa plan_id + day_number đang xử lý, đã có nội dung khác hoặc plan không khớp hồ sơ; retry phải giữ nguyên request.',
  })
  @ApiOkResponse({ type: FeedbackResponseDto })
  async submitFeedback(
    @Body() dto: FeedbackDto,
    @CurrentUser() user: User | undefined,
  ): Promise<FeedbackResponseDto> {
    const result = await this.feedback.apply(dto, user?.id ?? null);
    // Replaying day 1 must not overwrite later day-2 feedback or newer swaps in history.
    const plan =
      result.replayed && !result.isNewPlan
        ? result.response.plan
        : await this.record(user, result.response.plan, result.isNewPlan);
    return { ...result.response, plan };
  }

  private async record(
    user: User | undefined,
    plan: MealPlanResponseDto,
    isNew: boolean,
  ): Promise<MealPlanResponseDto> {
    if (!user) return plan;
    const saved = isNew
      ? await this.history.save(user.id, plan)
      : await this.history.update(user.id, plan);
    if (!saved) plan.warnings.push(WARNINGS.historyNotSaved);
    return plan;
  }
}
