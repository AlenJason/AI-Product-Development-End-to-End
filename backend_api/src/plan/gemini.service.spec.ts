import type { ConfigService } from '@nestjs/config';
import { startFakeGemini, type FakeGemini } from '../../test/fake-gemini-server.js';
import { CreatePlanDto } from './dto/create-plan.dto.js';
import { RestrictionsDto } from './dto/restrictions.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { Gender } from './enums/gender.enum.js';
import { Goal } from './enums/goal.enum.js';
import { GeminiService, GeminiTimeoutError } from './gemini.service.js';
import { generateWithRetry } from './gemini-retry.js';

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

  it('turns thinking off by default — measured: 8–13 s instead of 37–42 s for a plan', async () => {
    fake.reply({ kind: 'json', body: { days: [] } });
    await gemini.generateJson('prompt');
    expect(fake.requests[0]).toContain('"thinkingConfig":{"thinkingBudget":0}');
  });

  it('sends no thinking config with GEMINI_THINKING=default, so the model decides', async () => {
    const tuned = service({ GEMINI_API_KEY: 'test-key', GEMINI_BASE_URL: fake.url, GEMINI_THINKING: 'default' });
    fake.reply({ kind: 'json', body: { days: [] } });
    await tuned.generateJson('prompt');
    expect(fake.requests[0]).not.toContain('thinkingConfig');
  });

  it('uses gemini-3.5-flash unless GEMINI_MODEL says otherwise', async () => {
    fake.reply({ kind: 'json', body: { days: [] } });
    await gemini.generateJson('prompt');
    const tuned = service({ GEMINI_API_KEY: 'test-key', GEMINI_BASE_URL: fake.url, GEMINI_MODEL: 'gemini-3.8-flash' });
    await tuned.generateJson('prompt');
    expect(fake.paths).toEqual(['/v1beta/models/gemini-3.5-flash:generateContent', '/v1beta/models/gemini-3.8-flash:generateContent']);
  });

  it.each([
    ['low', '"thinkingConfig":{"thinkingLevel":"LOW"}'],
    ['off', '"thinkingConfig":{"thinkingBudget":0}'],
  ])('sends GEMINI_THINKING=%s to the API', async (level, expected) => {
    const tuned = service({ GEMINI_API_KEY: 'test-key', GEMINI_BASE_URL: fake.url, GEMINI_THINKING: level });
    fake.reply({ kind: 'json', body: { days: [] } });
    await tuned.generateJson('prompt');
    expect(fake.requests[0]).toContain(expected);
  });

  it('refuses to start with an unknown GEMINI_THINKING', () => {
    expect(() => service({ GEMINI_THINKING: 'fast' })).toThrow(/GEMINI_THINKING/);
  });

  it('reads the per-call and total time limits, never letting the total be shorter than one call', () => {
    expect(service({}).budget).toEqual({ perCallMs: 20_000, totalMs: 40_000 });
    expect(service({ GEMINI_TIMEOUT_MS: '30000', GEMINI_TOTAL_TIMEOUT_MS: '20000' }).budget).toEqual({
      perCallMs: 30_000,
      totalMs: 30_000,
    });
  });

  it('uses the timeout it is given for one call', async () => {
    fake.reply({ kind: 'hang' });
    await expect(gemini.generateJson('prompt', 100)).rejects.toThrow('Gemini không phản hồi sau 100 ms');
  });

  it('gives a retry only the time left in the total budget (NFR-1)', async () => {
    fake.reply({ kind: 'hang' });
    const timeouts: number[] = [];
    const logger = { warn: vi.fn(), error: vi.fn() };
    const started = Date.now();
    await generateWithRetry(
      logger as never,
      'thử',
      { perCallMs: 300, totalMs: 450 },
      (timeoutMs) => {
        timeouts.push(timeoutMs);
        return gemini.generateJson('prompt', timeoutMs);
      },
      () => ({ value: null, errors: ['sai'] }),
    );
    expect(timeouts).toEqual([300]); // hết giờ → không gọi lại (#15)
    expect(Date.now() - started).toBeLessThan(450);
  });
});

