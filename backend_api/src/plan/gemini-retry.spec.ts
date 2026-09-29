import { GeminiTimeoutError } from './gemini.service.js';
import { generateWithRetry, MIN_RETRY_MS } from './gemini-retry.js';

const logger = () => ({ warn: vi.fn(), error: vi.fn() });
const invalid = () => ({ value: null, errors: ['sai hợp đồng'] });

describe('generateWithRetry', () => {
  afterEach(() => vi.restoreAllMocks());

  it('retries once after a contract violation, giving the retry at most the time left', async () => {
    const now = vi.spyOn(Date, 'now');
    now.mockReturnValueOnce(0).mockReturnValueOnce(0).mockReturnValue(28_000);
    const call = vi.fn().mockResolvedValue({});
    await generateWithRetry(logger() as never, 'thử', { perCallMs: 25_000, totalMs: 40_000 }, call, invalid);
    expect(call.mock.calls.map(([timeoutMs]) => timeoutMs)).toEqual([25_000, 12_000]);
  });

  it(`skips the retry when less than ${MIN_RETRY_MS} ms are left, and says why`, async () => {
    const now = vi.spyOn(Date, 'now');
    now.mockReturnValueOnce(0).mockReturnValueOnce(0).mockReturnValue(37_000);
    const call = vi.fn().mockResolvedValue({});
    const log = logger();
    await generateWithRetry(log as never, 'thử', { perCallMs: 25_000, totalMs: 40_000 }, call, invalid);
    expect(call).toHaveBeenCalledTimes(1);
    expect(String(log.warn.mock.calls.at(-1)?.[0])).toContain('không gọi lại');
  });

  it('never retries after a timeout (#15)', async () => {
    const call = vi.fn().mockRejectedValue(new GeminiTimeoutError(25_000));
    await generateWithRetry(logger() as never, 'thử', { perCallMs: 25_000, totalMs: 60_000 }, call, invalid);
    expect(call).toHaveBeenCalledTimes(1);
  });

  it('returns the first valid value', async () => {
    const call = vi.fn().mockResolvedValue({ ok: true });
    const result = await generateWithRetry(logger() as never, 'thử', { perCallMs: 1000, totalMs: 2000 }, call, (raw) => ({
      value: raw,
      errors: [],
    }));
    expect(result).toEqual({ ok: true });
  });

  it('logs a short line for Gemini API errors instead of the whole JSON body', async () => {
    const body = {
      error: {
        code: 429,
        message:
          'You exceeded your current quota, please check your plan and billing details.\n* Quota exceeded for metric: generate_content_free_tier_requests, limit: 20, model: gemini-3.5-flash\nPlease retry in 39s.',
        status: 'RESOURCE_EXHAUSTED',
        details: [{ '@type': 'type.googleapis.com/google.rpc.QuotaFailure' }],
      },
    };
    const apiError = Object.assign(new Error(JSON.stringify(body)), { name: 'ApiError', status: 429 });
    const log = logger();
    await generateWithRetry(log as never, 'thử', { perCallMs: 1000, totalMs: 60_000 }, vi.fn().mockRejectedValue(apiError), invalid);
    const line = String(log.error.mock.calls[0][0]);
    expect(line).toBe(
      'Lỗi khi gọi Gemini (lần 1, thử): 429 RESOURCE_EXHAUSTED — You exceeded your current quota, please check your plan and billing details. * Quota exceeded for metric: generate_content_free_tier_requests, limit: 20, model: gemini-3.5-flash Please retry in 39s.',
    );
    expect(line).not.toContain('@type'); // mảng details của JSON không lọt vào log
  });
});

