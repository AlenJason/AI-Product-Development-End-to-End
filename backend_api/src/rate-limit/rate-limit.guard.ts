import { createHash } from 'node:crypto';
import { isIPv6 } from 'node:net';
import {
  type CanActivate,
  type ExecutionContext,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request, Response } from 'express';
import type { User } from '../database/entities/user.entity.js';
import { StatsService } from '../stats/stats.service.js';
import { RATE_LIMIT_CONFIG, type RateLimitConfig } from './rate-limit-config.js';
import { RateLimitStore } from './rate-limit-store.js';

// Tự viết thay cho @nestjs/throttler: gói đó là CommonJS và require('@nestjs/common') — NestJS 12 chỉ có bản ESM, bộ
// nạp module của Vercel không cho require() ESM nên app không khởi động (thử deploy thật, giai đoạn 9).

export type RateLimitBucket = 'plan' | 'adjust' | 'admin';
const RATE_LIMIT_BUCKET = 'smartfit:rate-limit-bucket';

// Hạn mức áp cho route/controller: `plan` (generate-plan), `adjust` (đổi món, đổi bài, feedback — dùng chung),
// `admin` (đăng nhập trang quản trị, giai đoạn 10).
export const RateLimit = (bucket: RateLimitBucket) => SetMetadata(RATE_LIMIT_BUCKET, bucket);

// "Bạn thao tác quá nhanh…" — câu tiếng Việt app hiện thẳng cho người dùng (#28).
export function tooManyRequestsMessage(seconds: number): string {
  const wait = seconds < 60 ? `${seconds} giây` : `${Math.ceil(seconds / 60)} phút`;
  return `Bạn thao tác quá nhanh. Vui lòng thử lại sau ${wait}.`;
}

// IPv4 viết dạng IPv6 (::ffff:1.2.3.4) → IPv4; IPv6 → cả mạng /64 (một máy có thể đổi địa chỉ trong /64 của nó).
export function normalizeIp(ip: string): string {
  const mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/i.exec(ip);
  if (mapped) return mapped[1];
  if (!isIPv6(ip)) return ip;
  const [head, tail = ''] = ip.toLowerCase().split('::');
  const left = head ? head.split(':') : [];
  const right = tail ? tail.split(':') : [];
  const groups = [...left, ...Array<string>(8 - left.length - right.length).fill('0'), ...right];
  return `${groups.slice(0, 4).map((group) => group.replace(/^0+(?=.)/, '')).join(':')}::/64`;
}

// Đặt SAU OptionalJwtAuthGuard trong @UseGuards để biết người gọi đã đăng nhập chưa (token sai thì guard kia trả 401
// trước, không tốn lượt).
@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    @Inject(RATE_LIMIT_CONFIG) private readonly config: RateLimitConfig,
    private readonly store: RateLimitStore,
    private readonly stats: StatsService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const bucket = this.reflector.getAllAndOverride<RateLimitBucket | undefined>(RATE_LIMIT_BUCKET, [
      context.getHandler(),
      context.getClass(),
    ]);
    const limit = bucket && this.config[bucket];
    if (!limit) return true;

    const http = context.switchToHttp();
    const req = http.getRequest<Request & { user?: User }>();
    const res = http.getResponse<Response>();
    // Đã đăng nhập → theo tài khoản: cả lớp chung một IP Wi-Fi vẫn dùng được (P5 giai đoạn 9). Khách → theo IP; sau
    // proxy, `req.ip` lấy từ X-Forwarded-For khi TRUST_PROXY_HOPS > 0 (configureApp).
    const tracker = req.user ? `user:${req.user.id}` : `ip:${normalizeIp(req.ip ?? '')}`;
    // Băm SHA-256 — bảng rate_limits không lưu IP hay id dạng chữ.
    const key = createHash('sha256').update(`${bucket}:${tracker}`).digest('hex');
    const { totalHits, timeToExpire, isBlocked } = await this.store.increment(key, limit.ttlMs, limit.limit);

    res.setHeader('X-RateLimit-Limit', limit.limit);
    res.setHeader('X-RateLimit-Remaining', Math.max(0, limit.limit - totalHits));
    res.setHeader('X-RateLimit-Reset', timeToExpire);
    if (isBlocked) {
      await this.stats.count(`rate_limited.${bucket}`);
      res.setHeader('Retry-After', timeToExpire);
      throw new HttpException(
        { statusCode: 429, error: 'Too Many Requests', message: tooManyRequestsMessage(timeToExpire) },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    return true;
  }
}
