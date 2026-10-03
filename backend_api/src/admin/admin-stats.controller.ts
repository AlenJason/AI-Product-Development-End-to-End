import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiExtraModels,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { AdminAuthGuard } from './admin-auth.guard.js';
import { AdminStatsService } from './admin-stats.service.js';
import {
  AdminGeminiCallsDto,
  AdminMonthDetailDto,
  AdminMonthDto,
  AdminOverviewDto,
  GeminiCallsQueryDto,
  MonthParamDto,
  UsageCountDto,
} from './dto/admin-stats.dto.js';

// API của trang thống kê — chỉ token Admin; chỉ số đếm và nhật ký Gemini, không có dữ liệu cá nhân.
@ApiTags('admin')
@ApiBearerAuth()
@ApiExtraModels(UsageCountDto)
@ApiUnauthorizedResponse({ description: 'Thiếu token, token hết hạn, hoặc không phải token Admin' })
@UseGuards(AdminAuthGuard)
@Controller('api/v1/admin/stats')
export class AdminStatsController {
  constructor(private readonly stats: AdminStatsService) {}

  @Get('overview')
  @ApiOperation({ summary: 'Hôm nay: lượt Gemini từng model, cấu hình Gemini, số tài khoản, giới hạn tần suất' })
  @ApiOkResponse({ type: AdminOverviewDto })
  overview(): Promise<AdminOverviewDto> {
    return this.stats.overview();
  }

  @Get('months')
  @ApiOperation({ summary: 'Số liệu cộng theo tháng (giờ Việt Nam), mới nhất trước' })
  @ApiOkResponse({ type: [AdminMonthDto] })
  months(): Promise<AdminMonthDto[]> {
    return this.stats.months();
  }

  @Get('months/:month')
  @ApiOperation({ summary: 'Từng ngày của một tháng' })
  @ApiOkResponse({ type: AdminMonthDetailDto })
  @ApiBadRequestResponse({ description: 'month không có dạng YYYY-MM' })
  month(@Param() params: MonthParamDto): Promise<AdminMonthDetailDto> {
    return this.stats.month(params.month);
  }

  @Get('gemini-calls')
  @ApiOperation({ summary: 'Nhật ký Gemini của một tháng, mới nhất trước, 50 dòng mỗi trang' })
  @ApiOkResponse({ type: AdminGeminiCallsDto })
  @ApiBadRequestResponse({ description: 'month sai dạng, outcome lạ, hoặc page < 1' })
  geminiCalls(@Query() query: GeminiCallsQueryDto): Promise<AdminGeminiCallsDto> {
    return this.stats.geminiCalls(query.month, query.outcome, query.page);
  }
}
