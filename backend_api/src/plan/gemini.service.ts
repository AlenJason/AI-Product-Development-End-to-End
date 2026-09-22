import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenAI } from '@google/genai';
import { CreatePlanDto } from './dto/create-plan.dto.js';
import type { DailyTarget, MealPlanResponse } from './interfaces/plan.interface.js';

@Injectable()
export class GeminiService {
  private readonly logger = new Logger(GeminiService.name);
  private readonly client: GoogleGenAI | null;
  private readonly model: string;

  constructor(private readonly config: ConfigService) {
    const apiKey = this.config.get<string>('GEMINI_API_KEY');
    this.model = this.config.get<string>('GEMINI_MODEL') ?? 'gemini-3.8-flash';
    this.client = apiKey ? new GoogleGenAI({ apiKey }) : null;
  }

  get isConfigured(): boolean {
    return this.client !== null;
  }

  // Sinh kế hoạch 3 ngày bằng Gemini Structured Output JSON Mode (BRD.md mục 4 & 6.2).
  async generatePlan(
    dto: CreatePlanDto,
    dailyTarget: DailyTarget,
  ): Promise<MealPlanResponse> {
    if (!this.client) {
      throw new Error('GEMINI_API_KEY chưa được cấu hình trong .env');
    }

    const prompt = this.buildPrompt(dto, dailyTarget);
    const response = await this.client.models.generateContent({
      model: this.model,
      contents: prompt,
      config: { responseMimeType: 'application/json' },
    });
    const text = response.text;

    if (!text) {
      throw new Error('Gemini trả về response rỗng');
    }

    try {
      return JSON.parse(text) as MealPlanResponse;
    } catch (error) {
      this.logger.error('Gemini trả về JSON không hợp lệ', text);
      throw error;
    }
  }

  private buildPrompt(dto: CreatePlanDto, dailyTarget: DailyTarget): string {
    return [
      'Bạn là chuyên gia dinh dưỡng & thể hình người Việt.',
      `Hãy tạo kế hoạch ăn uống 3 ngày (mỗi ngày 3 bữa: sáng/trưa/tối) và bài tập bodyweight tại nhà cho người dùng có:`,
      `- Mục tiêu: ${dto.goal}`,
      `- Calo mục tiêu mỗi ngày: ${dailyTarget.target_calories} kcal (protein ${dailyTarget.protein_g}g, carbs ${dailyTarget.carbs_g}g, fat ${dailyTarget.fat_g}g)`,
      `- Dị ứng cần tránh: ${dto.restrictions.allergies.join(', ') || 'không có'}`,
      `- Chấn thương cần tránh động tác ảnh hưởng: ${dto.restrictions.injuries.join(', ') || 'không có'}`,
      'Yêu cầu bắt buộc: chỉ dùng món ăn gia đình Việt Nam bình dân, không lặp lại tên món giữa 3 ngày, bài tập không cần dụng cụ.',
      'Trả về đúng cấu trúc JSON theo schema: { plan_id, daily_target, days: [{ day_number, day_name, meals: [{ meal_id, meal_type, name, portion, calories, protein_g, ingredients }], workout: { title, duration_minutes, exercises: [{ exercise_id, name, sets, reps_or_duration, target_muscle }] } }], grocery_list: [{ category, items: [{ name, source_meal_ids }] }] }.',
      'Không thêm giải thích, chỉ trả về JSON thuần.',
    ].join('\n');
  }
}
