import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CreatePlanDto } from './dto/create-plan.dto.js';
import { PlanService } from './plan.service.js';
import type { MealPlanResponse } from './interfaces/plan.interface.js';

@ApiTags('plan')
@Controller('api/v1')
export class PlanController {
  constructor(private readonly planService: PlanService) {}

  @Post('generate-plan')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Sinh kế hoạch ăn uống & tập luyện 3 ngày (BRD FR-1, FR-2)' })
  @ApiOkResponse({ description: 'Kế hoạch 3 ngày theo schema ở BRD.md mục 6.2' })
  generatePlan(@Body() dto: CreatePlanDto): Promise<MealPlanResponse> {
    return this.planService.generatePlan(dto);
  }
}
