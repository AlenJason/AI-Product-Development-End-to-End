import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { HistoryModule } from '../history/history.module.js';
import { PlanController } from './plan.controller.js';
import { PlanService } from './plan.service.js';
import { GeminiService } from './gemini.service.js';

@Module({
  imports: [AuthModule, HistoryModule],
  controllers: [PlanController],
  providers: [PlanService, GeminiService],
})
export class PlanModule {}
