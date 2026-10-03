import { Injectable, Logger } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { sqlParams } from '../database/sql-params.js';
import type { GeminiAttempt } from '../plan/gemini-retry.js';
import type { RateLimitBucket } from '../rate-limit/rate-limit.guard.js';
import { GeminiCall } from './gemini-call.entity.js';

// Ngày tính theo giờ Việt Nam (UTC+7, không có giờ mùa hè) — người dùng và Admin đều ở Việt Nam.
const VN_OFFSET_MS = 7 * 3_600_000;

export function vnDay(epochMs: number): string {
  return new Date(epochMs + VN_OFFSET_MS).toISOString().slice(0, 10);
}

// Loại số liệu đếm theo ngày. Kế hoạch: theo nguồn (gồm cả kế hoạch mới từ đánh giá ngày 3) và theo người gọi
// generate-plan; đổi món / đổi bài: Gemini, kho soạn sẵn, hay không tìm được (422).
export type UsageMetric =
  | 'plan.gemini'
  | 'plan.sample'
  | 'plan.guest'
  | 'plan.signed_in'
  | 'meal_swap.gemini'
  | 'meal_swap.pool'
  | 'meal_swap.none'
  | 'exercise_swap.gemini'
  | 'exercise_swap.pool'
  | 'exercise_swap.none'
  | 'feedback.total'
  | 'feedback.rebalanced'
  | 'feedback.unchanged'
  | `rate_limited.${RateLimitBucket}`
  | 'admin.login.ok'
  | 'admin.login.failed';

// Ghi số liệu cho trang thống kê. Không bao giờ làm hỏng request của người dùng: lỗi DB chỉ thành một dòng log cảnh
// báo và số liệu thiếu một lần. Gọi trước khi trả response (Vercel có thể dừng function ngay sau khi trả).
@Injectable()
export class StatsService {
  private readonly logger = new Logger(StatsService.name);

  constructor(
    private readonly dataSource: DataSource,
    private readonly now: () => number = Date.now,
  ) {}

  async count(metric: UsageMetric, durationMs = 0): Promise<void> {
    try {
      const { p, params } = sqlParams(this.dataSource, [vnDay(this.now()), metric, Math.round(durationMs)]);
      await this.dataSource.query(
        `INSERT INTO usage_daily (day, metric, count, total_ms) VALUES (${p(1)}, ${p(2)}, 1, ${p(3)})
         ON CONFLICT (day, metric) DO UPDATE SET
           count = usage_daily.count + 1,
           total_ms = usage_daily.total_ms + ${p(3)}`,
        params,
      );
    } catch (error) {
      this.logger.warn(`Không ghi được số liệu ${metric}: ${(error as Error).message}`);
    }
  }

  async recordGeminiCall(attempt: GeminiAttempt): Promise<void> {
    try {
      const now = this.now();
      await this.dataSource.getRepository(GeminiCall).insert({
        day: vnDay(now),
        created_at: new Date(now),
        task: attempt.task,
        model: attempt.model,
        attempt: attempt.attempt,
        outcome: attempt.outcome,
        http_status: attempt.httpStatus ?? null,
        duration_ms: Math.round(attempt.durationMs),
        message: attempt.message?.slice(0, 300) ?? null,
      });
    } catch (error) {
      this.logger.warn(`Không ghi được nhật ký Gemini: ${(error as Error).message}`);
    }
  }
}
