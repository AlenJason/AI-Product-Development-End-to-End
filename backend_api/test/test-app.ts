import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { configureApp } from '../src/app.setup.js';

export interface TestApp {
  app: INestApplication;
  close: () => Promise<void>;
}

// Máy dev có thể có khoá Gemini thật, file DB thật, AUTH_MODE=google trong .env (#17):
// ghim env trước khi nạp AppModule (ConfigModule.forRoot đọc .env ngay lúc import), trả lại khi đóng.
// Mặc định: DB trong RAM, đăng nhập giả lập, không có Gemini.
export async function createTestApp(env: Record<string, string> = {}): Promise<TestApp> {
  const pinned: Record<string, string> = {
    DATABASE_PATH: ':memory:',
    AUTH_MODE: 'mock',
    GOOGLE_CLIENT_ID: '',
    JWT_SECRET: '',
    JWT_EXPIRES_IN: '',
    ALLOW_MOCK_AUTH: '',
    GEMINI_API_KEY: '',
    GEMINI_BASE_URL: '',
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
    const { AppModule } = await import('../src/app.module.js');
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
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
