import type { INestApplication } from '@nestjs/common';
import { Test, type TestingModuleBuilder } from '@nestjs/testing';
import request from 'supertest';
import { configureApp } from '../src/app.setup.js';
import { TEST_DATABASE_URL, resetPostgres } from './postgres-test-db.js';

export interface TestApp {
  app: INestApplication;
  close: () => Promise<void>;
}

// Máy dev có thể có khoá Gemini thật, file DB thật, AUTH_MODE=google trong .env (#17):
// ghim env trước khi nạp AppModule (ConfigModule.forRoot đọc .env ngay lúc import), trả lại khi đóng.
// Mặc định: DB trong RAM, đăng nhập giả lập, không có Gemini. Có TEST_DATABASE_URL → Postgres đó, xoá sạch mỗi lần.
// `configure` ghi đè provider khi cần kết quả tất định (ví dụ RandomSource khi xuất fixture hợp đồng).
export async function createTestApp(
  env: Record<string, string> = {},
  configure: (builder: TestingModuleBuilder) => TestingModuleBuilder = (builder) => builder,
): Promise<TestApp> {
  const pinned: Record<string, string> = {
    DATABASE_PATH: ':memory:',
    DATABASE_URL: TEST_DATABASE_URL,
    DATABASE_RUN_MIGRATIONS: '',
    VERCEL: '',
    AUTH_MODE: 'mock',
    GOOGLE_CLIENT_ID: '',
    JWT_SECRET: '',
    JWT_EXPIRES_IN: '',
    ALLOW_MOCK_AUTH: '',
    GEMINI_API_KEY: '',
    GEMINI_BASE_URL: '',
    GEMINI_MODEL: '',
    // Test cũ đếm đúng 1 lần gọi lại; test model dự phòng tự bật bằng `env`.
    GEMINI_FALLBACK_MODEL: 'off',
    GEMINI_THINKING: '',
    GEMINI_TIMEOUT_MS: '',
    GEMINI_TOTAL_TIMEOUT_MS: '',
    CORS_ORIGINS: '',
    // Test cũ tạo nhiều plan trong một app; test giới hạn tần suất tự bật bằng `env`.
    RATE_LIMIT_PLAN: 'off',
    RATE_LIMIT_ADJUST: 'off',
    RATE_LIMIT_ADMIN: 'off',
    ADMIN_USERNAME: '',
    ADMIN_PASSWORD_HASH: '',
    ADMIN_TOKEN_TTL: '',
    TRUST_PROXY_HOPS: '',
    ...env,
  };
  const saved = Object.fromEntries(Object.keys(pinned).map((key) => [key, process.env[key]]));
  const restore = () => {
    for (const [key, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  };
  Object.assign(process.env, pinned);

  try {
    if (pinned.DATABASE_URL) await resetPostgres(pinned.DATABASE_URL);
    const { AppModule } = await import('../src/app.module.js');
    const moduleRef = await configure(Test.createTestingModule({ imports: [AppModule] })).compile();
    const app = moduleRef.createNestApplication({ logger: false });
    configureApp(app);
    await app.init();
    return {
      app,
      close: async () => {
        await app.close();
        restore();
      },
    };
  } catch (error) {
    restore();
    throw error;
  }
}

export interface LoginBody {
  access_token: string;
  user: { id: string; email: string; name: string };
}

// Đăng nhập giả lập (AUTH_MODE=mock): id_token là "mock:<email>".
export async function loginMock(testApp: TestApp, email: string): Promise<LoginBody> {
  const res = await request(testApp.app.getHttpServer())
    .post('/api/v1/auth/google')
    .send({ id_token: `mock:${email}` })
    .expect(200);
  return res.body as LoginBody;
}
