import { appendFile, mkdir } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';

// Explicit local opt-in. Never persist prompts or HTTP Authorization headers.
export class GroqDebugFile {
  private pending: Promise<void> = Promise.resolve();
  constructor(
    private readonly enabled: boolean,
    private readonly key: string,
    readonly path = resolve('debug/groq-responses.txt'),
  ) {}

  async write(entry: Record<string, unknown>): Promise<void> {
    if (!this.enabled) return;
    const text = JSON.stringify(
      { time: new Date().toISOString(), ...entry },
      null,
      2,
    );
    const redacted = this.key
      ? text.replaceAll(this.key, '[REDACTED_API_KEY]')
      : text;
    const next = this.pending.then(async () => {
      await mkdir(dirname(this.path), { recursive: true });
      await appendFile(this.path, `${redacted}\n\n`, {
        encoding: 'utf8',
        mode: 0o600,
      });
    });
    // Debug disk failure must not turn a valid AI response into fallback.
    this.pending = next.catch(() => {});
    await this.pending;
  }
}
