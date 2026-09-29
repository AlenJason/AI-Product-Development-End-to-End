import {
  type CanActivate,
  createParamDecorator,
  type ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import type { User } from '../database/entities/user.entity.js';
import { AuthService } from './auth.service.js';

type AuthenticatedRequest = Request & { user?: User };

const BEARER_PATTERN = /^Bearer\s+(\S+)\s*$/i;

export function extractBearerToken(header: string | undefined): string | null {
  return BEARER_PATTERN.exec(header ?? '')?.[1] ?? null;
}

// Bắt buộc đăng nhập (API lịch sử, xoá tài khoản).
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = extractBearerToken(request.headers.authorization);
    if (!token) throw new UnauthorizedException('Cần đăng nhập (header Authorization: Bearer <access_token>).');
    request.user = await this.auth.authenticate(token);
    return true;
  }
}

// Đăng nhập tuỳ chọn (generate-plan, BRD FR-7): không gửi header → chạy như khách;
// có gửi mà sai → 401, để app biết phải đăng nhập lại thay vì âm thầm không lưu lịch sử.
@Injectable()
export class OptionalJwtAuthGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header = request.headers.authorization;
    if (header === undefined) return true;
    const token = extractBearerToken(header);
    if (!token) throw new UnauthorizedException('Header Authorization phải có dạng "Bearer <access_token>".');
    request.user = await this.auth.authenticate(token);
    return true;
  }
}

export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): User | undefined =>
    context.switchToHttp().getRequest<AuthenticatedRequest>().user,
);
