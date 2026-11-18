import { ConfigService } from '@nestjs/config';
import { GroqPlanService } from './groq-plan.service.js';
import { PlanService } from './plan.service.js';
import { makeProfile, geminiOff } from '../../test/plan-fixtures.js';
import { computeDailyTarget } from './daily-target.js';

const config = (extra = {}) => new ConfigService({ PLAN_AI_PROVIDER: 'groq', GROQ_API_KEY: 'synthetic-key', ...extra });

describe('Groq plan integration', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('sends JSON mode to Groq and returns a validated plan with truthful source', async () => {
    const profile = makeProfile();
    const sample = await new PlanService(geminiOff).generatePlan(profile);
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ choices: [{ finish_reason: 'stop', message: { content: JSON.stringify({ days: sample.days }) } }] })));
    vi.stubGlobal('fetch', fetchMock);
    const result = await new PlanService(geminiOff, new GroqPlanService(config())).generatePlan(profile);
    expect(result.source).toBe('groq');
    expect(result.days).toHaveLength(3);
    expect(result.grocery_list.length).toBeGreaterThan(0);
    const [url, request] = fetchMock.mock.calls[0];
    expect(url).toBe('https://api.groq.com/openai/v1/chat/completions');
    expect(JSON.parse(request.body).response_format).toEqual({ type: 'json_object' });
  });

  it.each([401, 403, 429])('does not retry HTTP %s and falls back safely', async (status) => {
    const fetchMock = vi.fn().mockImplementation(() => Promise.resolve(new Response('private response', { status })));
    vi.stubGlobal('fetch', fetchMock);
    const result = await new PlanService(geminiOff, new GroqPlanService(config())).generatePlan(makeProfile());
    expect(result.source).toBe('sample');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('rejects invalid model content rather than marking fallback as Groq', async () => {
    vi.stubGlobal('fetch', vi.fn().mockImplementation(() => Promise.resolve(new Response(JSON.stringify({ choices: [{ finish_reason: 'stop', message: { content: '{"days":[]}' } }] })))));
    const result = await new PlanService(geminiOff, new GroqPlanService(config())).generatePlan(makeProfile());
    expect(result.source).toBe('sample');
  });

  it('does not retry timeout', async () => {
    const fetchMock = vi.fn().mockRejectedValue(new DOMException('timeout', 'TimeoutError'));
    vi.stubGlobal('fetch', fetchMock);
    expect((await new PlanService(geminiOff, new GroqPlanService(config())).generatePlan(makeProfile())).source).toBe('sample');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('rejects truncated output and missing key', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ choices: [{ finish_reason: 'length', message: { content: '{}' } }] }))));
    const profile = makeProfile();
    const { target } = computeDailyTarget(profile);
    await expect(new GroqPlanService(config()).generatePlanContent(profile, target, undefined, 1000)).rejects.toThrow('chưa hoàn tất');
    await expect(new GroqPlanService(config({ GROQ_API_KEY: '' })).generatePlanContent(profile, target, undefined, 1000)).rejects.toThrow('GROQ_API_KEY');
  });
});
