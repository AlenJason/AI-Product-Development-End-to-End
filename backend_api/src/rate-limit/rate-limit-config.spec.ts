import { resolveRateLimitConfig } from './rate-limit-config.js';
import { normalizeIp, tooManyRequestsMessage } from './rate-limit.guard.js';

const env = (values: Record<string, string>) => (key: string) => values[key];

describe('resolveRateLimitConfig', () => {
  it('mặc định: tạo plan 5 lần / 10 phút, đổi món·bài·feedback 30 lần / 10 phút, không tin proxy', () => {
    expect(resolveRateLimitConfig(env({}))).toEqual({
      plan: { limit: 5, ttlMs: 600_000 },
      adjust: { limit: 30, ttlMs: 600_000 },
      trustProxyHops: 0,
    });
  });

  it('đọc <số lần>/<số><s|m|h|d>, "off" tắt hạn mức đó', () => {
    const config = resolveRateLimitConfig(
      env({ RATE_LIMIT_PLAN: ' 20/1d ', RATE_LIMIT_ADJUST: 'off', TRUST_PROXY_HOPS: '1' }),
    );
    expect(config).toEqual({ plan: { limit: 20, ttlMs: 86_400_000 }, adjust: null, trustProxyHops: 1 });
    expect(resolveRateLimitConfig(env({ RATE_LIMIT_PLAN: '3/45s' })).plan).toEqual({ limit: 3, ttlMs: 45_000 });
  });

  it('sai dạng → không khởi động', () => {
    for (const bad of ['5', '5/10', '0/10m', '5/0m', '5 per 10m', '-1/1m']) {
      expect(() => resolveRateLimitConfig(env({ RATE_LIMIT_PLAN: bad })), bad).toThrow(/RATE_LIMIT_PLAN/);
    }
    expect(() => resolveRateLimitConfig(env({ RATE_LIMIT_ADJUST: '1/1w' }))).toThrow(/RATE_LIMIT_ADJUST/);
    for (const bad of ['-1', '10', 'true', '1.5']) {
      expect(() => resolveRateLimitConfig(env({ TRUST_PROXY_HOPS: bad })), bad).toThrow(/TRUST_PROXY_HOPS/);
    }
  });
});

describe('tooManyRequestsMessage', () => {
  it('dưới 1 phút nói giây, từ 1 phút trở lên làm tròn lên phút', () => {
    expect(tooManyRequestsMessage(42)).toBe('Bạn thao tác quá nhanh. Vui lòng thử lại sau 42 giây.');
    expect(tooManyRequestsMessage(60)).toBe('Bạn thao tác quá nhanh. Vui lòng thử lại sau 1 phút.');
    expect(tooManyRequestsMessage(61)).toBe('Bạn thao tác quá nhanh. Vui lòng thử lại sau 2 phút.');
  });
});

describe('normalizeIp', () => {
  it('IPv4 giữ nguyên, IPv4 dạng IPv6 (::ffff:) → IPv4', () => {
    expect(normalizeIp('203.0.113.7')).toBe('203.0.113.7');
    expect(normalizeIp('::ffff:203.0.113.7')).toBe('203.0.113.7');
  });

  it('IPv6 → cả mạng /64: đổi địa chỉ trong mạng của mình không lấy thêm được lượt', () => {
    expect(normalizeIp('2001:db8:85a3:12::1')).toBe('2001:db8:85a3:12::/64');
    expect(normalizeIp('2001:0DB8:85A3:0012:ffff:1:2:3')).toBe('2001:db8:85a3:12::/64');
    expect(normalizeIp('2001:db8::7')).toBe('2001:db8:0:0::/64');
    expect(normalizeIp('::1')).toBe('0:0:0:0::/64');
  });
});
