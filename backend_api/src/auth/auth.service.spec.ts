import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { DataSource, Repository } from 'typeorm';
import { createMemoryDataSource } from '../../test/memory-data-source.js';
import { PlanRecord } from '../database/entities/plan-record.entity.js';
import { User } from '../database/entities/user.entity.js';
import { AuthService } from './auth.service.js';
import { MockIdTokenVerifier } from './id-token-verifier.js';

const SECRET = 'test-secret-that-is-at-least-32-chars';

describe('AuthService', () => {
  let dataSource: DataSource;
  let users: Repository<User>;
  let jwt: JwtService;
  let service: AuthService;

  beforeEach(async () => {
    dataSource = await createMemoryDataSource();
    users = dataSource.getRepository(User);
    jwt = new JwtService({
      secret: SECRET,
      signOptions: { algorithm: 'HS256', expiresIn: 3600 },
      verifyOptions: { algorithms: ['HS256'] },
    });
    service = new AuthService(new MockIdTokenVerifier(), jwt, users);
  });

  afterEach(async () => {
    vi.restoreAllMocks();
    await dataSource.destroy();
  });

  describe('loginWithGoogle', () => {
    it('creates the user on first login and reuses it afterwards', async () => {
      const first = await service.loginWithGoogle('mock:an@vku.edu.vn');
      const second = await service.loginWithGoogle('mock:An@VKU.edu.vn');
      expect(first.user).toEqual({ id: expect.any(String), email: 'an@vku.edu.vn', name: 'an' });
      expect(second.user.id).toBe(first.user.id);
      expect(await users.count()).toBe(1);
    });

    it('puts only the user id in the token', async () => {
      const { access_token, user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      const payload = jwt.decode<Record<string, unknown>>(access_token);
      expect(Object.keys(payload).sort()).toEqual(['exp', 'iat', 'sub']);
      expect(payload.sub).toBe(user.id);
    });

    it('survives two first logins racing on the same account', async () => {
      const existing = await users.save(users.create({ google_sub: 'mock:an@vku.edu.vn', email: 'an@vku.edu.vn', name: 'an' }));
      // Lần tra đầu không thấy (request kia chưa ghi xong) → insert đụng khoá duy nhất → đọc lại.
      vi.spyOn(users, 'findOneBy').mockResolvedValueOnce(null);
      const { user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      expect(user.id).toBe(existing.id);
      expect(await users.count()).toBe(1);
    });

    it('rejects a token the verifier does not accept', async () => {
      await expect(service.loginWithGoogle('an@vku.edu.vn')).rejects.toBeInstanceOf(UnauthorizedException);
      expect(await users.count()).toBe(0);
    });
  });

  describe('authenticate', () => {
    it('returns the user behind a valid token', async () => {
      const { access_token, user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      await expect(service.authenticate(access_token)).resolves.toMatchObject({ id: user.id, email: 'an@vku.edu.vn' });
    });

    it.each([
      ['an expired token', async (userId: string) => jwt.signAsync({ sub: userId }, { expiresIn: -60 })],
      ['a token signed with another secret', async (userId: string) =>
        new JwtService({ secret: 'another-secret-another-secret-123' }).signAsync({ sub: userId })],
      ['an unsigned token (alg none)', async (userId: string) =>
        `${Buffer.from('{"alg":"none","typ":"JWT"}').toString('base64url')}.${Buffer.from(JSON.stringify({ sub: userId })).toString('base64url')}.`],
      ['a token without sub', async () => jwt.signAsync({ uid: 'x' })],
      ['garbage', async () => 'not-a-jwt'],
    ])('rejects %s', async (_label, makeToken) => {
      const { user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      await expect(service.authenticate(await makeToken(user.id))).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('rejects a valid token whose user no longer exists', async () => {
      const { access_token, user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      await users.delete({ id: user.id });
      await expect(service.authenticate(access_token)).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });

  describe('deleteAccount', () => {
    it('deletes the user and every plan they saved', async () => {
      const { user } = await service.loginWithGoogle('mock:an@vku.edu.vn');
      const { user: other } = await service.loginWithGoogle('mock:binh@vku.edu.vn');
      const plans = dataSource.getRepository(PlanRecord);
      const record = (id: string, userId: string) => ({
        id, user_id: userId, target_calories: 1800, plan_json: {} as PlanRecord['plan_json'], created_at: new Date(),
      });
      await plans.insert([
        record('11111111-1111-4111-8111-111111111111', user.id),
        record('22222222-2222-4222-8222-222222222222', other.id),
      ]);

      await service.deleteAccount(user.id);

      expect(await users.findOneBy({ id: user.id })).toBeNull();
      expect((await plans.find()).map((plan) => plan.user_id)).toEqual([other.id]);
    });
  });
});
