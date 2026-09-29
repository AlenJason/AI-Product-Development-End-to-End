import { AuthMode, DEV_JWT_SECRET, resolveAuthConfig } from './auth-config.js';

const STRONG_SECRET = 'x'.repeat(32);
const resolve = (env: Record<string, string>) => resolveAuthConfig((key) => env[key]);

describe('resolveAuthConfig', () => {
  it('defaults to mock mode, the dev secret and a 7-day token', () => {
    const { config, warnings } = resolve({});
    expect(config).toEqual({
      mode: AuthMode.MOCK,
      jwtSecret: DEV_JWT_SECRET,
      jwtExpiresInSeconds: 7 * 86_400,
      googleClientIds: [],
    });
    expect(warnings).toHaveLength(1);
  });

  it('treats blank values as unset', () => {
    expect(resolve({ AUTH_MODE: ' ', JWT_SECRET: '', JWT_EXPIRES_IN: '' }).config.mode).toBe(AuthMode.MOCK);
  });

  it('accepts google mode with client ids and a long secret', () => {
    const { config, warnings } = resolve({
      AUTH_MODE: 'google',
      GOOGLE_CLIENT_ID: ' web.apps.googleusercontent.com , android.apps.googleusercontent.com ,',
      JWT_SECRET: STRONG_SECRET,
    });
    expect(config.googleClientIds).toEqual([
      'web.apps.googleusercontent.com',
      'android.apps.googleusercontent.com',
    ]);
    expect(config.jwtSecret).toBe(STRONG_SECRET);
    expect(warnings).toEqual([]);
  });

  it.each([
    ['an unknown mode', { AUTH_MODE: 'facebook' }, /AUTH_MODE/],
    ['google without client id', { AUTH_MODE: 'google', JWT_SECRET: STRONG_SECRET }, /GOOGLE_CLIENT_ID/],
    ['google without secret', { AUTH_MODE: 'google', GOOGLE_CLIENT_ID: 'id' }, /JWT_SECRET/],
    ['google with a short secret', { AUTH_MODE: 'google', GOOGLE_CLIENT_ID: 'id', JWT_SECRET: 'short' }, /32/],
    ['mock in production', { NODE_ENV: 'production' }, /ALLOW_MOCK_AUTH/],
    ['mock in production with a non-"true" flag', { NODE_ENV: 'production', ALLOW_MOCK_AUTH: '1' }, /ALLOW_MOCK_AUTH/],
    ['a zero duration', { JWT_EXPIRES_IN: '0d' }, /JWT_EXPIRES_IN/],
    ['a duration without unit', { JWT_EXPIRES_IN: '3600' }, /JWT_EXPIRES_IN/],
  ])('refuses to start with %s', (_label, env, message) => {
    expect(() => resolve(env)).toThrow(message);
  });

  it('allows mock mode in production only with ALLOW_MOCK_AUTH=true', () => {
    const { config, warnings } = resolve({ NODE_ENV: 'production', ALLOW_MOCK_AUTH: 'true' });
    expect(config.mode).toBe(AuthMode.MOCK);
    expect(warnings[0]).toMatch(/mock/);
  });

  it.each([
    ['30s', 30],
    ['15m', 900],
    ['12h', 43_200],
    ['7d', 604_800],
  ])('parses JWT_EXPIRES_IN=%s', (value, seconds) => {
    expect(resolve({ JWT_EXPIRES_IN: value }).config.jwtExpiresInSeconds).toBe(seconds);
  });
});
