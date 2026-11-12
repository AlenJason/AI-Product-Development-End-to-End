import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthModule } from '../auth/auth.module.js';
import { HistoryModule } from '../history/history.module.js';
import { PlanController } from './plan.controller.js';
import { PlanService } from './plan.service.js';
import { GeminiService } from './gemini.service.js';
import { MealSwapService } from './adjust/meal-swap.service.js';
import { ExerciseSwapService } from './adjust/exercise-swap.service.js';
import { FeedbackService } from './adjust/feedback.service.js';
import { PlanAdjustController } from './adjust/plan-adjust.controller.js';
import { RandomSource } from './adjust/random-source.js';
import { GroqPlanService } from './groq-plan.service.js';
import { PLAN_AI } from './ai-provider.js';

@Module({
  imports: [AuthModule, HistoryModule],
  controllers: [PlanController, PlanAdjustController],
  providers: [
    PlanService,
    GroqPlanService,
    // Compatibility token: older tests and constructors inject GeminiService.
    // In Groq mode every AI caller receives Groq; no Google SDK client is created.
    {
      provide: PLAN_AI,
      inject: [ConfigService, GroqPlanService],
      useFactory: (config: ConfigService, groq: GroqPlanService) =>
        groq.enabled ? groq : new GeminiService(config),
    },
    { provide: GeminiService, useExisting: PLAN_AI },
    MealSwapService,
    ExerciseSwapService,
    FeedbackService,
    RandomSource,
  ],
})
export class PlanModule {}
