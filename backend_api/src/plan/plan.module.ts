import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { HistoryModule } from '../history/history.module.js';
import { ExerciseSwapService } from './adjust/exercise-swap.service.js';
import { FeedbackService } from './adjust/feedback.service.js';
import { MealSwapService } from './adjust/meal-swap.service.js';
import { PlanAdjustController } from './adjust/plan-adjust.controller.js';
import { RandomSource } from './adjust/random-source.js';
import { PlanController } from './plan.controller.js';
import { PlanService } from './plan.service.js';
import { GeminiService } from './gemini.service.js';

@Module({
  imports: [AuthModule, HistoryModule],
  controllers: [PlanController, PlanAdjustController],
  providers: [PlanService, GeminiService, MealSwapService, ExerciseSwapService, FeedbackService, RandomSource],
})
export class PlanModule {}
