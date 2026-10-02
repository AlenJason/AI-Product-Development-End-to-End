import type { DataSource } from 'typeorm';

interface Row {
  hits: number | string;
  window_ends_at: number | string;
}

export interface RateLimitResult {
  totalHits: number;
  // Số giây tới hết cửa sổ đếm (≥ 1) — cũng là Retry-After khi bị chặn.
  timeToExpire: number;
  isBlocked: boolean;
}

// Rút gọn bảng: cửa sổ nào hết hạn quá một ngày thì xoá (chạy khi mở cửa sổ mới, không phải mỗi request).
const KEEP_EXPIRED_MS = 86_400_000;

// Cửa sổ cố định: lượt đầu mở cửa sổ `ttlMs`, các lượt sau cộng dồn tới khi cửa sổ hết; vượt `limit` → bị chặn tới
// hết cửa sổ. Lưu trong DB chứ không trong RAM vì trên Vercel mỗi instance có bộ nhớ riêng (P17 giai đoạn 9). Cộng dồn
// bằng một câu INSERT … ON CONFLICT … RETURNING — nguyên tử trên cả SQLite lẫn Postgres, nên nhiều instance cùng đếm đúng.
export class RateLimitStore {
  constructor(
    private readonly dataSource: DataSource,
    private readonly now: () => number = Date.now,
  ) {}

  async increment(key: string, ttlMs: number, limit: number): Promise<RateLimitResult> {
    const now = this.now();
    const p = this.placeholder;
    const rows: Row[] = await this.dataSource.query(
      `INSERT INTO rate_limits ("key", hits, window_ends_at) VALUES (${p(1)}, 1, ${p(2)})
       ON CONFLICT ("key") DO UPDATE SET
         hits = CASE WHEN rate_limits.window_ends_at <= ${p(3)} THEN 1 ELSE rate_limits.hits + 1 END,
         window_ends_at = CASE WHEN rate_limits.window_ends_at <= ${p(3)} THEN ${p(2)} ELSE rate_limits.window_ends_at END
       RETURNING hits, window_ends_at`,
      this.params([key, now + ttlMs, now]),
    );
    const totalHits = Number(rows[0].hits);
    const timeToExpire = Math.max(1, Math.ceil((Number(rows[0].window_ends_at) - now) / 1000));
    if (totalHits === 1) {
      await this.dataSource.query(
        `DELETE FROM rate_limits WHERE window_ends_at < ${p(1)}`,
        this.params([now - KEEP_EXPIRED_MS]),
      );
    }
    return { totalHits, timeToExpire, isBlocked: totalHits > limit };
  }

  private get isPostgres(): boolean {
    return this.dataSource.options.type === 'postgres';
  }

  // Câu SQL dùng lại một tham số nhiều lần: Postgres có $1, $2…; better-sqlite3 không dùng lại được `?` nên dùng
  // tham số có tên (@p1…) truyền bằng một object.
  private readonly placeholder = (index: number): string => (this.isPostgres ? `$${index}` : `@p${index}`);

  private params(values: unknown[]): unknown[] {
    if (this.isPostgres) return values;
    return [Object.fromEntries(values.map((value, index) => [`p${index + 1}`, value]))];
  }
}
