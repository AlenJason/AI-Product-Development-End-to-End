import { DataSource } from 'typeorm';
import { User } from '../database/entities/user.entity.js';
import { PlanRecord } from '../database/entities/plan-record.entity.js';
import { sqlParams } from '../database/sql-params.js';
import { GeminiService } from '../plan/gemini.service.js';
import type { RateLimit, RateLimitConfig } from '../rate-limit/rate-limit-config.js';
import { GeminiCall } from '../stats/gemini-call.entity.js';
import { vnDay } from '../stats/stats.service.js';
import type {
  AdminDayDto,
  AdminGeminiCallDto,
  AdminGeminiCallsDto,
  AdminGeminiSummaryDto,
  AdminMonthDetailDto,
  AdminMonthDto,
  AdminOverviewDto,
  UsageCountDto,
} from './dto/admin-stats.dto.js';

// Gói miễn phí của Gemini: 20 lượt mỗi ngày cho mỗi model (#9) — trang Admin cho biết hôm nay đã dùng bao nhiêu.
export const GEMINI_FREE_DAILY_LIMIT = 20;
export const GEMINI_CALLS_PAGE_SIZE = 50;

interface UsageRow {
  period: string;
  metric: string;
  count: number | string;
  total_ms: number | string | null;
}

interface GeminiRow {
  period: string;
  model: string;
  outcome: string;
  calls: number | string;
  total_ms: number | string | null;
}

// Đọc số liệu cho trang Admin. Chỉ số đếm và nhật ký Gemini — không đọc email, hồ sơ hay kế hoạch của ai.
// SQL tổng hợp dùng substr() trên cột ngày dạng chữ (YYYY-MM-DD giờ Việt Nam) nên chạy được trên cả hai DB (#38).
// Tạo bằng factory trong AdminModule (đồng hồ tiêm được để test).
export class AdminStatsService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly gemini: GeminiService,
    private readonly rateLimits: RateLimitConfig,
    private readonly now: () => number = Date.now,
  ) {}

  async overview(): Promise<AdminOverviewDto> {
    const today = vnDay(this.now());
    const { p, params } = sqlParams(this.dataSource, [today]);
    const rows: { model: string; calls: number | string; ok: number | string }[] = await this.dataSource.query(
      `SELECT model, COUNT(*) AS calls, SUM(CASE WHEN outcome = 'ok' THEN 1 ELSE 0 END) AS ok
       FROM gemini_calls WHERE day = ${p(1)} GROUP BY model ORDER BY model`,
      params,
    );
    const { budget, models } = this.gemini;
    return {
      today,
      gemini: {
        configured: this.gemini.isConfigured,
        primary_model: models.primary,
        fallback_model: models.fallback,
        per_call_timeout_ms: budget.perCallMs,
        total_timeout_ms: budget.totalMs,
        daily_limit_per_model: GEMINI_FREE_DAILY_LIMIT,
      },
      gemini_today: rows.map((row) => ({ model: row.model, calls: Number(row.calls), ok: Number(row.ok) })),
      accounts: await this.dataSource.getRepository(User).count(),
      saved_plans: await this.dataSource.getRepository(PlanRecord).count(),
      rate_limits: {
        plan: describeLimit(this.rateLimits.plan),
        adjust: describeLimit(this.rateLimits.adjust),
        admin: describeLimit(this.rateLimits.admin),
      },
    };
  }

  // Mọi tháng có số liệu, mới nhất trước — giữ mãi (quyết định Q5).
  async months(): Promise<AdminMonthDto[]> {
    const usage: UsageRow[] = await this.dataSource.query(
      `SELECT substr(day, 1, 7) AS period, metric, SUM(count) AS count, SUM(total_ms) AS total_ms
       FROM usage_daily GROUP BY substr(day, 1, 7), metric`,
    );
    const gemini: GeminiRow[] = await this.dataSource.query(
      `SELECT substr(day, 1, 7) AS period, model, outcome, COUNT(*) AS calls, SUM(duration_ms) AS total_ms
       FROM gemini_calls GROUP BY substr(day, 1, 7), model, outcome`,
    );
    const months = [...new Set([...usage, ...gemini].map((row) => row.period))].sort().reverse();
    return months.map((month) => ({
      month,
      usage: toUsage(usage.filter((row) => row.period === month)),
      gemini: toGemini(gemini.filter((row) => row.period === month)),
    }));
  }

  // Từng ngày của một tháng ("YYYY-MM", đã kiểm ở DTO).
  async month(month: string): Promise<AdminMonthDetailDto> {
    const { p, params } = sqlParams(this.dataSource, [`${month}-%`]);
    const usage: UsageRow[] = await this.dataSource.query(
      `SELECT day AS period, metric, count, total_ms FROM usage_daily WHERE day LIKE ${p(1)}`,
      params,
    );
    const gemini: GeminiRow[] = await this.dataSource.query(
      `SELECT day AS period, model, outcome, COUNT(*) AS calls, SUM(duration_ms) AS total_ms
       FROM gemini_calls WHERE day LIKE ${p(1)} GROUP BY day, model, outcome`,
      params,
    );
    const days = [...new Set([...usage, ...gemini].map((row) => row.period))].sort();
    const toDay = (day: string): AdminDayDto => ({
      day,
      usage: toUsage(usage.filter((row) => row.period === day)),
      gemini: toGemini(gemini.filter((row) => row.period === day)),
    });
    return { month, days: days.map(toDay) };
  }

  // Nhật ký Gemini của một tháng, mới nhất trước, mỗi trang 50 dòng.
  async geminiCalls(month: string, outcome: string | undefined, page: number): Promise<AdminGeminiCallsDto> {
    const query = this.dataSource
      .getRepository(GeminiCall)
      .createQueryBuilder('call')
      .where('call.day LIKE :month', { month: `${month}-%` });
    if (outcome) query.andWhere('call.outcome = :outcome', { outcome });
    const [rows, total] = await query
      .orderBy('call.id', 'DESC')
      .skip((page - 1) * GEMINI_CALLS_PAGE_SIZE)
      .take(GEMINI_CALLS_PAGE_SIZE)
      .getManyAndCount();
    return {
      month,
      page,
      page_size: GEMINI_CALLS_PAGE_SIZE,
      total,
      calls: rows.map(
        (row): AdminGeminiCallDto => ({
          created_at: row.created_at.toISOString(),
          task: row.task,
          model: row.model,
          attempt: row.attempt,
          outcome: row.outcome,
          http_status: row.http_status,
          duration_ms: row.duration_ms,
          message: row.message,
        }),
      ),
    };
  }
}

function describeLimit(limit: RateLimit | null): string {
  if (!limit) return 'tắt';
  const minutes = limit.ttlMs / 60_000;
  return `${limit.limit} lần / ${Number.isInteger(minutes) ? `${minutes} phút` : `${limit.ttlMs / 1000} giây`}`;
}

function toUsage(rows: UsageRow[]): Record<string, UsageCountDto> {
  return Object.fromEntries(
    rows
      .sort((a, b) => a.metric.localeCompare(b.metric))
      .map((row) => [row.metric, { count: Number(row.count), total_ms: Number(row.total_ms ?? 0) }]),
  );
}

function toGemini(rows: GeminiRow[]): AdminGeminiSummaryDto[] {
  return rows
    .map((row) => ({
      model: row.model,
      outcome: row.outcome,
      calls: Number(row.calls),
      avg_ms: Math.round(Number(row.total_ms ?? 0) / Math.max(1, Number(row.calls))),
    }))
    .sort((a, b) => a.model.localeCompare(b.model) || a.outcome.localeCompare(b.outcome));
}
