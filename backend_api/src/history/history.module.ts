import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { PlanRecord } from '../database/entities/plan-record.entity.js';
import { PlanMealItem } from '../database/entities/plan-meal-item.entity.js';
import { PlanWorkoutItem } from '../database/entities/plan-workout-item.entity.js';
import { HistoryController } from './history.controller.js';
import { HistoryService } from './history.service.js';

@Module({
  imports: [AuthModule, TypeOrmModule.forFeature([PlanRecord, PlanMealItem, PlanWorkoutItem])],
  controllers: [HistoryController],
  providers: [HistoryService],
  exports: [HistoryService],
})
export class HistoryModule {}
