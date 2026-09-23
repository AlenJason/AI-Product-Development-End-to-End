import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { AppService, type HealthStatus } from './app.service.js';

@ApiTags('health')
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get('health')
  @ApiOkResponse({
    description:
      'gemini = "configured" khi đã có GEMINI_API_KEY, "fallback" khi đang dùng dữ liệu mẫu',
  })
  getHealth(): HealthStatus {
    return this.appService.getHealth();
  }
}
