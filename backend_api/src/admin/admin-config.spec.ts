import { resolveAdminConfig } from './admin-config.js';
import { hashAdminPassword } from './admin-password.js';

const env = (values: Record<string, string>) => (key: string) => values[key];

describe('resolveAdminConfig', () => {
  let hash: string;

  beforeAll(async () => {
    hash = await hashAdminPassword('mat-khau-quan-tri-123');
  });

  it('turns the admin page off when neither variable is set', () => {
    expect(resolveAdminConfig(env({}))).toBeNull();
    expect(resolveAdminConfig(env({ ADMIN_USERNAME: ' ', ADMIN_PASSWORD_HASH: '' }))).toBeNull();
  });

  it('reads one account with an 8-hour session by default', () => {
    const config = resolveAdminConfig(env({ ADMIN_USERNAME: ' admin ', ADMIN_PASSWORD_HASH: ` ${hash} ` }));
    expect(config).toMatchObject({ username: 'admin', passwordHashText: hash, tokenTtlSeconds: 8 * 3600 });
    expect(resolveAdminConfig(env({ ADMIN_USERNAME: 'admin', ADMIN_PASSWORD_HASH: hash, ADMIN_TOKEN_TTL: '30m' }))?.tokenTtlSeconds).toBe(1800);
  });

  it('refuses to start when only half of the account is set', () => {
    expect(() => resolveAdminConfig(env({ ADMIN_USERNAME: 'admin' }))).toThrow(/cả ADMIN_USERNAME lẫn ADMIN_PASSWORD_HASH/);
    expect(() => resolveAdminConfig(env({ ADMIN_PASSWORD_HASH: hash }))).toThrow(/cả ADMIN_USERNAME lẫn ADMIN_PASSWORD_HASH/);
  });

  it('refuses a malformed hash — and never echoes the value', () => {
    const bad = 'mat-khau-de-nham-vao-day';
    expect(() => resolveAdminConfig(env({ ADMIN_USERNAME: 'admin', ADMIN_PASSWORD_HASH: bad }))).toThrow(/ADMIN_PASSWORD_HASH sai định dạng/);
    try {
      resolveAdminConfig(env({ ADMIN_USERNAME: 'admin', ADMIN_PASSWORD_HASH: bad }));
    } catch (error) {
      expect((error as Error).message).not.toContain(bad);
    }
  });

  it.each(['ad', 'quản-trị', 'admin user', 'a'.repeat(65)])('refuses the username %j', (username) => {
    expect(() => resolveAdminConfig(env({ ADMIN_USERNAME: username, ADMIN_PASSWORD_HASH: hash }))).toThrow(/ADMIN_USERNAME/);
  });

  it.each(['8', '2w', '25h', '0h'])('refuses ADMIN_TOKEN_TTL=%s (at most one day)', (ttl) => {
    expect(() => resolveAdminConfig(env({ ADMIN_USERNAME: 'admin', ADMIN_PASSWORD_HASH: hash, ADMIN_TOKEN_TTL: ttl }))).toThrow(
      /ADMIN_TOKEN_TTL/,
    );
  });
});
