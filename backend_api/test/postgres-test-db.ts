import pg from 'pg';

// Postgres cho test (#17: không bao giờ là DB production): CI dùng service container, máy dev đặt tay
// (ví dụ Postgres cục bộ). Không đặt → test chỉ chạy trên SQLite như trước.
export const TEST_DATABASE_URL = process.env.TEST_DATABASE_URL?.trim() ?? '';

// Xoá sạch rồi tạo lại schema `public` — như mở SQLite :memory: mới; app tự chạy migration khi khởi động.
export async function resetPostgres(url: string): Promise<void> {
  const client = new pg.Client({ connectionString: url });
  await client.connect();
  try {
    await client.query('DROP SCHEMA public CASCADE');
    await client.query('CREATE SCHEMA public');
  } finally {
    await client.end();
  }
}
