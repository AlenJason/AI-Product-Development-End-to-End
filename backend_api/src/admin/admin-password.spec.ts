import { hashAdminPassword, parseAdminPasswordHash, verifyAdminPassword } from './admin-password.js';

const PASSWORD = 'mật-khẩu-quản-trị-123';
// Tính trước khi khai báo test: bảng it.each bên dưới dựng từ mã băm này.
const hash = await hashAdminPassword(PASSWORD);

describe('admin password hashing (scrypt)', () => {
  it('stores scrypt parameters, salt and key — never the password itself', () => {
    expect(hash).toMatch(/^scrypt\$32768\$8\$1\$[A-Za-z0-9_-]{22}\$[A-Za-z0-9_-]{43}$/);
    expect(hash).not.toContain(PASSWORD);
  });

  it('accepts the right password and rejects any other', async () => {
    const parsed = parseAdminPasswordHash(hash);
    expect(parsed).not.toBeNull();
    expect(await verifyAdminPassword(PASSWORD, parsed!)).toBe(true);
    expect(await verifyAdminPassword('mật-khẩu-quản-trị-124', parsed!)).toBe(false);
    expect(await verifyAdminPassword('', parsed!)).toBe(false);
  });

  it('treats the same Vietnamese text typed in another Unicode form as the same password', async () => {
    const decomposed = PASSWORD.normalize('NFD');
    expect(decomposed).not.toBe(PASSWORD);
    expect(await verifyAdminPassword(decomposed, parseAdminPasswordHash(hash)!)).toBe(true);
  });

  it('uses a new random salt every time', async () => {
    expect(await hashAdminPassword(PASSWORD)).not.toBe(hash);
  });

  it.each([
    ['empty', ''],
    ['another algorithm', hash.replace('scrypt$', 'bcrypt$')],
    ['N not a power of two', hash.replace('$32768$', '$30000$')],
    ['N weaker than 2^14', hash.replace('$32768$', '$1024$')],
    ['r below 8', hash.replace('$32768$8$', '$32768$4$')],
    ['salt too short', hash.replace(/\$[A-Za-z0-9_-]{22}\$/, '$c2FsdA$')],
    ['key cut short', hash.slice(0, -3)],
  ])('refuses a %s hash', (_name, value) => {
    expect(parseAdminPasswordHash(value)).toBeNull();
  });
});
