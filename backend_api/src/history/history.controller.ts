import { Controller, Get, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { CurrentUser, JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { User } from '../database/entities/user.entity.js';
import { MealPlanResponseDto } from '../plan/dto/meal-plan-response.dto.js';
import { PlanHistoryResponseDto } from './dto/plan-history-response.dto.js';
import { HistoryService } from './history.service.js';

@ApiTags('history')
@ApiBearerAuth()
@ApiUnauthorizedResponse({ description: 'Chưa đăng nhập, token sai/hết hạn, hoặc tài khoản đã bị xoá' })
@UseGuards(JwtAuthGuard)
@Controller('api/v1/plans/history')
export class HistoryController {
  constructor(private readonly history: HistoryService) {}

  @Get()
  @ApiOperation({ summary: 'Danh sách kế hoạch đã tạo, mới nhất trước (BRD FR-7.2)' })
  @ApiOkResponse({ type: PlanHistoryResponseDto })
  list(@CurrentUser() user: User): Promise<PlanHistoryResponseDto> {
    return this.history.list(user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Xem lại một kế hoạch (BRD FR-7.2)' })
  @ApiOkResponse({ type: MealPlanResponseDto })
  @ApiBadRequestResponse({ description: 'id không phải UUID' })
  @ApiNotFoundResponse({ description: 'Không có, hoặc thuộc tài khoản khác' })
  findOne(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string): Promise<MealPlanResponseDto> {
    return this.history.findOne(user.id, id);
  }
}
