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
      { provide: ConfigService, useValue: { get: (key: string) => ({ PLAN_AI_PROVIDER: 'gemini', ...env })[key] } },
      { provide: AUTH_CONFIG, useValue: { mode: AuthMode.MOCK } },
    ],
  }).compile();

  return app.get<AppController>(AppController);
}

describe('AppController', () => {
  describe('health', () => {
    it('reports Groq configuration without claiming live connectivity', async () => {
      const controller = await createController({ PLAN_AI_PROVIDER: 'groq', GROQ_API_KEY: 'test-key' });
      expect(controller.getHealth()).toMatchObject({ ai_provider: 'groq', ai_status: 'configured', gemini: 'fallback' });
    });
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
