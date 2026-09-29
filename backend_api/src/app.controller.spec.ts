import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AUTH_CONFIG, AuthMode } from './auth/auth-config.js';

async function createController(env: Record<string, string | undefined>) {
  const app: TestingModule = await Test.createTestingModule({
    controllers: [AppController],
    providers: [
      AppService,
      { provide: ConfigService, useValue: { get: (key: string) => env[key] } },
      { provide: AUTH_CONFIG, useValue: { mode: AuthMode.MOCK } },
    ],
  }).compile();

  return app.get<AppController>(AppController);
}

describe('AppController', () => {
  describe('health', () => {
    it('reports gemini fallback when GEMINI_API_KEY is unset', async () => {
      const controller = await createController({});
      expect(controller.getHealth()).toEqual({ status: 'ok', gemini: 'fallback', auth_mode: 'mock' });
    });

    it('reports gemini configured when GEMINI_API_KEY is set', async () => {
      const controller = await createController({ GEMINI_API_KEY: 'test-key' });
      expect(controller.getHealth()).toEqual({ status: 'ok', gemini: 'configured', auth_mode: 'mock' });
    });
  });
});
