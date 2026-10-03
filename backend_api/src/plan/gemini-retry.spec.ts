import { GeminiInvalidJsonError, GeminiTimeoutError } from './gemini.service.js';
import { generateWithRetry, MAX_GEMINI_ATTEMPTS, MIN_RETRY_MS } from './gemini-retry.js';

const logger = () => ({ warn: vi.fn(), error: vi.fn() });
const invalid = () => ({ value: null, errors: ['sai hợp đồng'] });
const accept = (raw: unknown) => ({ value: raw, errors: [] });
const apiError = (status: number) => Object.assign(new Error(`HTTP ${status}`), { name: 'ApiError', status });

const PRIMARY = 'gemini-3.5-flash';
const FALLBACK = 'gemini-3.6-flash';
const withFallback = (budget = { perCallMs: 25_000, totalMs: 60_000 }) => ({ budget, models: { primary: PRIMARY, fallback: FALLBACK } });
const withoutFallback = (budget = { perCallMs: 25_000, totalMs: 60_000 }) => ({ budget, models: { primary: PRIMARY, fallback: null } });
const modelsCalled = (call: ReturnType<typeof vi.fn>) => call.mock.calls.map(([, model]) => model as string);

describe('generateWithRetry', () => {
  afterEach(() => vi.restoreAllMocks());

  it('gives every retry at most the time left in the total budget', async () => {
    const now = vi.spyOn(Date, 'now');
    now.mockReturnValueOnce(0).mockReturnValueOnce(0).mockReturnValue(28_000);
    const call = vi.fn().mockResolvedValue({});
    await generateWithRetry(logger() as never, 'plan', withoutFallback({ perCallMs: 25_000, totalMs: 40_000 }), call, invalid);
    expect(call.mock.calls.map(([timeoutMs]) => timeoutMs)).toEqual([25_000, 12_000]);
  });

  it(`skips the retry when less than ${MIN_RETRY_MS} ms are left, and says why`, async () => {
    const now = vi.spyOn(Date, 'now');
    now.mockReturnValueOnce(0).mockReturnValueOnce(0).mockReturnValue(37_000);
    const call = vi.fn().mockResolvedValue({});
    const log = logger();
    await generateWithRetry(log as never, 'plan', withFallback({ perCallMs: 25_000, totalMs: 40_000 }), call, invalid);
    expect(call).toHaveBeenCalledTimes(1);
    expect(String(log.warn.mock.calls.at(-1)?.[0])).toContain('không gọi lại');
  });

  it('never retries after a timeout, even with a fallback model (#15)', async () => {
    const call = vi.fn().mockRejectedValue(new GeminiTimeoutError(25_000));
    await generateWithRetry(logger() as never, 'plan', withFallback(), call, invalid);
    expect(call).toHaveBeenCalledTimes(1);
  });

  it('returns the first valid value', async () => {
    const call = vi.fn().mockResolvedValue({ ok: true });
    expect(await generateWithRetry(logger() as never, 'plan', withFallback(), call, accept)).toEqual({ ok: true });
    expect(modelsCalled(call)).toEqual([PRIMARY]);
  });

  // Quyết định Q4 giai đoạn 10: 503 tới sau ~20 s — gọi lại đúng model đang quá tải thì model dự phòng hết thời gian.
  it.each([
    ['overloaded (503)', apiError(503)],
    ['out of daily quota (429)', apiError(429)],
    ['another API error (500)', apiError(500)],
  ])('moves straight to the fallback model when the main model is %s', async (_name, error) => {
    const call = vi.fn().mockRejectedValueOnce(error).mockResolvedValue({ ok: true });
    expect(await generateWithRetry(logger() as never, 'plan', withFallback(), call, accept)).toEqual({ ok: true });
    expect(modelsCalled(call)).toEqual([PRIMARY, FALLBACK]);
  });

  it('retries the main model once after a broken result, then moves to the fallback model', async () => {
    const call = vi
      .fn()
      .mockRejectedValueOnce(new GeminiInvalidJsonError('Gemini trả về chuỗi không phải JSON hợp lệ'))
      .mockResolvedValueOnce({ bad: true })
      .mockResolvedValue({ ok: true });
    const parse = (raw: unknown) => ((raw as { ok?: boolean }).ok ? accept(raw) : invalid());
    expect(await generateWithRetry(logger() as never, 'plan', withFallback(), call, parse)).toEqual({ ok: true });
    expect(modelsCalled(call)).toEqual([PRIMARY, PRIMARY, FALLBACK]);
  });

  it(`stays on the fallback model and stops after ${MAX_GEMINI_ATTEMPTS} calls (3 retries)`, async () => {
    const call = vi.fn().mockRejectedValue(apiError(503));
    expect(await generateWithRetry(logger() as never, 'plan', withFallback(), call, accept)).toBeNull();
    expect(modelsCalled(call)).toEqual([PRIMARY, FALLBACK, FALLBACK, FALLBACK]);
  });

  it('without a fallback model, behaves as before phase 10: one retry on the main model', async () => {
    const call = vi.fn().mockRejectedValue(apiError(503));
    expect(await generateWithRetry(logger() as never, 'plan', withoutFallback(), call, accept)).toBeNull();
    expect(modelsCalled(call)).toEqual([PRIMARY, PRIMARY]);
  });

  // Nhật ký Gemini cho trang thống kê (giai đoạn 10): mỗi lần gọi một dòng, kể cả lần thành công.
  it('records every call with its model and outcome — never the contract details, which may quote content (#12)', async () => {
    const recordAttempt = vi.fn().mockResolvedValue(undefined);
    const call = vi
      .fn()
      .mockRejectedValueOnce(apiError(503))
      .mockResolvedValueOnce({ bad: 'Phở bò tái' })
      .mockResolvedValue({ ok: true });
    const parse = (raw: unknown) =>
      (raw as { ok?: boolean }).ok ? accept(raw) : { value: null, errors: ['món "Phở bò tái" đã có trong kế hoạch'] };
    await generateWithRetry(logger() as never, 'meal_swap', { ...withFallback(), recordAttempt }, call, parse);
    const entries = recordAttempt.mock.calls.map(([entry]) => entry as Record<string, unknown>);
    expect(entries.map(({ durationMs: _durationMs, ...rest }) => rest)).toEqual([
      { task: 'meal_swap', model: PRIMARY, attempt: 1, outcome: 'overloaded', httpStatus: 503, message: 'HTTP 503' },
      { task: 'meal_swap', model: FALLBACK, attempt: 2, outcome: 'invalid', message: 'Sai hợp đồng (1 lỗi)' },
      { task: 'meal_swap', model: FALLBACK, attempt: 3, outcome: 'ok' },
    ]);
    expect(entries.every((entry) => typeof entry.durationMs === 'number' && entry.durationMs >= 0)).toBe(true);
    expect(JSON.stringify(entries)).not.toContain('Phở bò tái');
  });

  it('logs a short line naming the attempt, the task and the model, instead of the whole JSON body', async () => {
    const body = {
      error: {
        code: 429,
        message:
          'You exceeded your current quota, please check your plan and billing details.\n* Quota exceeded for metric: generate_content_free_tier_requests, limit: 20, model: gemini-3.5-flash\nPlease retry in 39s.',
        status: 'RESOURCE_EXHAUSTED',
        details: [{ '@type': 'type.googleapis.com/google.rpc.QuotaFailure' }],
      },
    };
    const quotaError = Object.assign(new Error(JSON.stringify(body)), { name: 'ApiError', status: 429 });
    const log = logger();
    await generateWithRetry(log as never, 'meal_swap', withoutFallback(), vi.fn().mockRejectedValue(quotaError), invalid);
    const line = String(log.error.mock.calls[0][0]);
    expect(line).toBe(
      'Lỗi khi gọi Gemini (lần 1, đổi món, gemini-3.5-flash): 429 RESOURCE_EXHAUSTED — You exceeded your current quota, please check your plan and billing details. * Quota exceeded for metric: generate_content_free_tier_requests, limit: 20, model: gemini-3.5-flash Please retry in 39s.',
    );
    expect(line).not.toContain('@type'); // mảng details của JSON không lọt vào log
  });
});
