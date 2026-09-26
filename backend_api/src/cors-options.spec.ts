import { resolveCorsOptions } from './cors-options.js';

const resolve = (env: Record<string, string>) => resolveCorsOptions((key) => env[key]);
const allows = (origins: unknown, origin: string) =>
  (origins as (string | RegExp)[]).some((allowed) => (typeof allowed === 'string' ? allowed === origin : allowed.test(origin)));

describe('resolveCorsOptions', () => {
  it('allows localhost and 127.0.0.1 on any port during development', () => {
    const options = resolve({});
    for (const origin of ['http://localhost', 'http://localhost:5000', 'http://127.0.0.1:61234']) {
      expect(allows(options?.origin, origin)).toBe(true);
    }
    for (const origin of ['http://localhost.evil.com', 'https://evil.example', 'http://192.168.1.10:5000']) {
      expect(allows(options?.origin, origin)).toBe(false);
    }
  });

  it('only allows the listed origins when CORS_ORIGINS is set', () => {
    const options = resolve({ CORS_ORIGINS: ' https://smartfit.example/ , http://192.168.1.10:5000 ' });
    expect(options?.origin).toEqual(['https://smartfit.example', 'http://192.168.1.10:5000']);
  });

  it('turns CORS off in production when no origin is listed (mobile apps send no Origin)', () => {
    expect(resolve({ NODE_ENV: 'production' })).toBeNull();
    expect(resolve({ NODE_ENV: 'production', CORS_ORIGINS: 'https://smartfit.example' })?.origin).toEqual([
      'https://smartfit.example',
    ]);
  });

  it('allows the Authorization header without cookies', () => {
    expect(resolve({})).toMatchObject({ allowedHeaders: ['Content-Type', 'Authorization'], credentials: false });
  });

  it.each(['*', 'smartfit.example', 'https://smartfit.example/app'])('refuses to start with CORS_ORIGINS=%s', (value) => {
    expect(() => resolve({ CORS_ORIGINS: value })).toThrow(/CORS_ORIGINS/);
  });
});
