import { mkdtemp, readFile, rm, access } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { GroqDebugFile } from './groq-debug.js';
import { GroqPlanService } from './groq-plan.service.js';
import { ConfigService } from '@nestjs/config';

describe('Groq local response diagnostics', () => {
  it('production disables response persistence even when the debug flag is true', async () => {
    const spy = vi
      .spyOn(GroqDebugFile.prototype, 'write')
      .mockImplementation(async function (this: GroqDebugFile) {
        expect((this as unknown as { enabled: boolean }).enabled).toBe(false);
      });
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValue(
          new Response(
            JSON.stringify({
              choices: [
                { finish_reason: 'stop', message: { content: '{"days":[]}' } },
              ],
            }),
          ),
        ),
    );
    const groq = new GroqPlanService(
      new ConfigService({
        NODE_ENV: 'production',
        GROQ_DEBUG_RESPONSES: 'true',
        PLAN_AI_PROVIDER: 'groq',
        GROQ_API_KEY: 'synthetic-key',
      }),
    );
    await groq.generateJson('private');
    expect(spy).toHaveBeenCalledTimes(2);
  });
  let folder: string, file: string;
  beforeEach(async () => {
    folder = await mkdtemp(join(tmpdir(), 'smartfit-groq-debug-'));
    file = join(folder, 'responses.txt');
  });
  afterEach(async () => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    if (!resolve(folder).startsWith(resolve(tmpdir())))
      throw new Error('Unsafe test temp path');
    await rm(folder, { recursive: true, force: true });
  });
  it('disabled by default does not create a file', async () => {
    await new GroqDebugFile(false, 'synthetic-key', file).write({
      content: 'private',
    });
    await expect(access(file)).rejects.toThrow();
  });
  it('records complete output and validation in order, redacting the actual key', async () => {
    const writer = new GroqDebugFile(true, 'synthetic-key', file);
    await Promise.all([
      writer.write({ trace: 'one', content: 'AI text synthetic-key' }),
      writer.write({ trace: 'one', error: 'AI_EXERCISE_METADATA_CONFLICT' }),
    ]);
    const text = await readFile(file, 'utf8');
    expect(text).toContain('AI text');
    expect(text).toContain('AI_EXERCISE_METADATA_CONFLICT');
    expect(text).toContain('[REDACTED_API_KEY]');
    expect(text).not.toContain('synthetic-key');
    expect(text.indexOf('AI text')).toBeLessThan(
      text.indexOf('AI_EXERCISE_METADATA_CONFLICT'),
    );
  });
  it('debug filesystem failure does not fail the API path', async () => {
    await expect(
      new GroqDebugFile(true, 'key', folder).write({ content: 'ok' }),
    ).resolves.toBeUndefined();
  });
  it('captures HTTP body and decoded AI content without request prompt or headers', async () => {
    const entries: Record<string, unknown>[] = [];
    vi.spyOn(GroqDebugFile.prototype, 'write').mockImplementation(
      async (entry) => {
        entries.push(entry);
      },
    );
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            choices: [
              { finish_reason: 'stop', message: { content: '{"days":[]}' } },
            ],
          }),
        ),
      ),
    );
    const groq = new GroqPlanService(
      new ConfigService({
        PLAN_AI_PROVIDER: 'groq',
        GROQ_API_KEY: 'synthetic-key',
      }),
    );
    const result = await groq.generateJson('private request prompt');
    await groq.debugValidation(result, {
      valid: false,
      error: 'AI_EXERCISE_ASSESSMENT_INVALID',
    });
    expect(entries.map((e) => e.event)).toEqual([
      'groq_response',
      'ai_content',
      'validation',
    ]);
    expect(entries[0].trace).toBe(entries[2].trace);
    expect(JSON.stringify(entries)).not.toContain('private request prompt');
    expect(JSON.stringify(entries)).not.toContain('Authorization');
  });
});
