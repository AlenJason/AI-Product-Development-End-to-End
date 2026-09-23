import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import type { Repository } from 'typeorm';
import { PlanRecord } from '../database/entities/plan-record.entity.js';
import type { MealPlanResponseDto } from '../plan/dto/meal-plan-response.dto.js';
import type { PlanHistoryResponseDto } from './dto/plan-history-response.dto.js';

export const HISTORY_LIMIT = 50;

@Injectable()
export class HistoryService {
  private readonly logger = new Logger(HistoryService.name);

  constructor(@InjectRepository(PlanRecord) private readonly plans: Repository<PlanRecord>) {}

  // Trả false thay vì ném lỗi: lịch sử lỗi không được làm mất plan vừa tạo xong.
  async save(userId: string, plan: MealPlanResponseDto): Promise<boolean> {
    try {
      await this.plans.insert({
        id: plan.plan_id,
        user_id: userId,
        target_calories: plan.daily_target.target_calories,
        plan_json: plan,
        created_at: new Date(),
      });
      return true;
    } catch (error) {
      // Chỉ ghi thông báo lỗi của DB, không ghi nội dung plan (NFR-7).
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Không lưu được kế hoạch vào lịch sử: ${message}`);
      return false;
    }
  }

  async list(userId: string): Promise<PlanHistoryResponseDto> {
    const records = await this.plans.find({
      select: { id: true, created_at: true, target_calories: true },
      where: { user_id: userId },
      order: { created_at: 'DESC', id: 'DESC' },
      take: HISTORY_LIMIT,
    });
    return {
      plans: records.map((record) => ({
        id: record.id,
        created_at: record.created_at.toISOString(),
        target_calories: record.target_calories,
      })),
    };
  }

  // Plan của người khác trả 404 giống plan không tồn tại, để không lộ là id đó có thật.
  async findOne(userId: string, planId: string): Promise<MealPlanResponseDto> {
    const record = await this.plans.findOne({
      select: { id: true, plan_json: true },
      where: { id: planId, user_id: userId },
    });
    if (!record) throw new NotFoundException('Không tìm thấy kế hoạch này trong lịch sử của bạn.');
    return record.plan_json;
  }
}
