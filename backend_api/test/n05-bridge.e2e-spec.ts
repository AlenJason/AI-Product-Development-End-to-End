import { createTestApp } from './test-app.js';
import { geminiOff, samplePlan } from './plan-fixtures.js';
import { PLAN_AI, type PlanAi } from '../src/plan/ai-provider.js';
import type { CreatePlanDto } from '../src/plan/dto/create-plan.dto.js';
import { GroqPlanService } from '../src/plan/groq-plan.service.js';
import { DataSource } from 'typeorm';
import { FeedbackReceipt } from '../src/database/entities/feedback-receipt.entity.js';

// Opt-in host integration bridge: only reachable while this test is running.
// No production routes, no real credentials/provider, no user DB.
it.skipIf(process.env.N05_BRIDGE !== '1')(
  'serves isolated Nest HTTP for Flutter N05 fullflow',
  async () => {
    const ai = {
      ...geminiOff,
      providerName: 'groq',
      enabled: true,
      isConfigured: true,
      budget: { totalMs: 1000, perCallMs: 500 },
      generatePlanContent: async (profile: CreatePlanDto) => ({
        days: (await samplePlan(profile)).days,
      }),
      generateJson: async () => ({ invalid: true }),
    } as unknown as PlanAi;
    const app = await createTestApp({}, (builder) =>
      builder
        .overrideProvider(PLAN_AI)
        .useValue(ai)
        .overrideProvider(GroqPlanService)
        .useValue(ai),
    );
    try {
      await app.app.listen(3998, '127.0.0.1');
      await new Promise<void>((resolve, reject) => {
        const timer = setTimeout(() => {
          clearInterval(poll);
          reject(new Error('N05 bridge timed out'));
        }, 900000);
        const poll = setInterval(() => {
          void app.app
            .get(DataSource)
            .getRepository(FeedbackReceipt)
            .countBy({ status: 'completed' })
            .then((count) => {
              if (count === 3) {
                clearInterval(poll);
                clearTimeout(timer);
                setTimeout(resolve, 1000);
              }
            });
        }, 200);
      });
    } finally {
      await app.close();
    }
  },
  910000,
);
