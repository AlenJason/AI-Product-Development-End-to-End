import { Logger, UnauthorizedException } from '@nestjs/common';
import { OAuth2Client } from 'google-auth-library';
import { createSign, generateKeyPairSync } from 'node:crypto';
import { GoogleIdTokenVerifier, MockIdTokenVerifier } from './id-token-verifier.js';

describe('MockIdTokenVerifier', () => {
  const verifier = new MockIdTokenVerifier();

  it('turns "mock:<email>" into a stable identity', async () => {
    await expect(verifier.verify(' mock:An.Nguyen@VKU.edu.vn ')).resolves.toEqual({
      sub: 'mock:an.nguyen@vku.edu.vn',
      email: 'an.nguyen@vku.edu.vn',
      name: 'an.nguyen',
    });
  });

  it.each(['an@vku.edu.vn', 'mock:', 'mock:khong-phai-email', 'mock:a b@vku.edu.vn', 'eyJhbGciOi.x.y'])(
    'rejects %j',
    async (token) => {
      await expect(verifier.verify(token)).rejects.toBeInstanceOf(UnauthorizedException);
    },
  );
});

// Ký token bằng khoá RSA tự tạo và thay chỗ tải chứng chỉ của Google — không gọi mạng (#17),
// nhưng phần kiểm chữ ký, hạn dùng, issuer, audience vẫn là code thật của google-auth-library.
describe('GoogleIdTokenVerifier', () => {
  const CLIENT_IDS = ['web-client.apps.googleusercontent.com', 'android-client.apps.googleusercontent.com'];
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const now = () => Math.floor(Date.now() / 1000);
  const claims = (overrides: Record<string, unknown> = {}) => ({
    iss: 'https://accounts.google.com',
    aud: CLIENT_IDS[0],
    sub: '110248495921238986420',
    email: 'An.Nguyen@gmail.com',
    email_verified: true,
    name: 'Nguyễn Văn An',
    iat: now(),
    exp: now() + 3600,
    ...overrides,
  });
  const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const sign = (payload: object, kid = 'test-key') => {
    const unsigned = `${encode({ alg: 'RS256', kid, typ: 'JWT' })}.${encode(payload)}`;
    return `${unsigned}.${createSign('RSA-SHA256').update(unsigned).sign(privateKey).toString('base64url')}`;
  };

  let verifier: GoogleIdTokenVerifier;

  beforeEach(() => {
    const client = new OAuth2Client();
    // `format` có kiểu enum CertificateFormat mà google-auth-library không export, nên phải ép kiểu qua unknown.
    vi.spyOn(client, 'getFederatedSignonCertsAsync').mockResolvedValue({
      certs: { 'test-key': publicKey.export({ type: 'spki', format: 'pem' }).toString() },
      format: 'PEM',
    } as unknown as Awaited<ReturnType<OAuth2Client['getFederatedSignonCertsAsync']>>);
    verifier = new GoogleIdTokenVerifier(CLIENT_IDS, client);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('accepts a valid token and lowercases the email', async () => {
    await expect(verifier.verify(sign(claims()))).resolves.toEqual({
      sub: '110248495921238986420',
      email: 'an.nguyen@gmail.com',
      name: 'Nguyễn Văn An',
    });
  });

  it('accepts a token issued to any configured client id', async () => {
    await expect(verifier.verify(sign(claims({ aud: CLIENT_IDS[1] })))).resolves.toMatchObject({
      sub: '110248495921238986420',
    });
  });

  it('falls back to the email name when Google sends no name', async () => {
    await expect(verifier.verify(sign(claims({ name: undefined })))).resolves.toMatchObject({ name: 'an.nguyen' });
  });

  it.each([
    ['issued to another app', claims({ aud: 'other-app.apps.googleusercontent.com' })],
    ['expired', claims({ iat: now() - 7200, exp: now() - 3600 })],
    ['from another issuer', claims({ iss: 'https://evil.example' })],
    ['with an unverified email', claims({ email_verified: false })],
    ['without email', claims({ email: undefined })],
  ])('rejects a token %s', async (_label, payload) => {
    await expect(verifier.verify(sign(payload))).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects a token signed with an unknown key', async () => {
    await expect(verifier.verify(sign(claims(), 'other-key'))).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects a token with a tampered payload', async () => {
    const [header, , signature] = sign(claims()).split('.');
    const forged = `${header}.${encode(claims({ sub: 'someone-else' }))}.${signature}`;
    await expect(verifier.verify(forged)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('never logs the token or the email (NFR-7)', async () => {
    const warn = vi.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    const token = sign(claims({ exp: now() - 3600, iat: now() - 7200 }));
    await verifier.verify(token).catch(() => undefined);
    expect(warn).toHaveBeenCalledTimes(1);
    const logged = String(warn.mock.calls[0][0]);
    expect(logged).toContain('Token used too late');
    expect(logged).not.toContain('gmail.com');
    expect(logged).not.toContain(token.split('.')[1]);
  });

  it('refuses to be built without a client id, so the audience check can never be skipped', () => {
    expect(() => new GoogleIdTokenVerifier([])).toThrow(/Client ID/);
  });
});
