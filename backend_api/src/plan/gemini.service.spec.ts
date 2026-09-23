import type { ConfigService } from '@nestjs/config';
import { startFakeGemini, type FakeGemini } from '../../test/fake-gemini-server.js';
import { CreatePlanDto } from './dto/create-plan.dto.js';
import { RestrictionsDto } from './dto/restrictions.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { Gender } from './enums/gender.enum.js';
import { Goal } from './enums/goal.enum.js';
import { GeminiService, GeminiTimeoutError } from './gemini.service.js';

const target = { bmi: 22, bmr: 1399, tdee: 1924, target_calories: 1624, protein_g: 102, carbs_g: 183, fat_g: 54 };
const SECRET = 'BENH-NEN-BI-MAT-123';

function profile(): CreatePlanDto {
  return Object.assign(new CreatePlanDto(), {
    age: 22,
    gender: Gender.FEMALE,
    height_cm: 168,
    weight_kg: 62,
    activity_level: ActivityLevel.LIGHT,
    goal: Goal.CUT,
    restrictions: Object.assign(new RestrictionsDto(), { health_conditions: SECRET }),
  });
}

function service(env: Record<string, string>): GeminiService {
  return new GeminiService({ get: (key: string) => env[key] } as unknown as ConfigService);
}

describe('GeminiService — SDK thật, server Gemini giả', () => {
  let fake: FakeGemini;
  let gemini: GeminiService;

  beforeAll(async () => {
    fake = await startFakeGemini();
    gemini = service({ GEMINI_API_KEY: 'test-key', GEMINI_BASE_URL: fake.url, GEMINI_TIMEOUT_MS: '200' });
  });

  afterAll(() => fake.close());

  it('is not configured without an API key', () => {
    expect(service({}).isConfigured).toBe(false);
  });

  it('returns the parsed JSON and sends the prompt in JSON mode', async () => {
    fake.reply({ kind: 'json', body: { days: [] } });
    await expect(gemini.generatePlanContent(profile(), target)).resolves.toEqual({ days: [] });
    expect(fake.requests).toHaveLength(1);
    expect(fake.requests[0]).toContain('du_lieu_nguoi_dung');
    expect(fake.requests[0]).toContain('"responseMimeType":"application/json"');
  });

  it('turns a timeout into GeminiTimeoutError', async () => {
    fake.reply({ kind: 'hang' });
    await expect(gemini.generatePlanContent(profile(), target)).rejects.toBeInstanceOf(GeminiTimeoutError);
  });

  it('sends exactly one request on HTTP 500 — the SDK must not retry on its own (#15)', async () => {
    fake.reply({ kind: 'error', status: 500, message: 'boom' });
    await expect(gemini.generatePlanContent(profile(), target)).rejects.toMatchObject({
      name: 'ApiError',
      status: 500,
    });
    expect(fake.requests).toHaveLength(1);
  });

  it('passes a rejected API key through as ApiError 400', async () => {
    fake.reply({ kind: 'error', status: 400, message: 'API key not valid. Please pass a valid API key.' });
    await expect(gemini.generatePlanContent(profile(), target)).rejects.toMatchObject({ status: 400 });
  });

  it('never echoes Gemini output in the error when the text is not JSON (#12)', async () => {
    fake.reply({ kind: 'text', text: `không phải JSON ${SECRET}` });
    const error = await gemini.generatePlanContent(profile(), target).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toBe('Gemini trả về chuỗi không phải JSON hợp lệ');
  });
});
