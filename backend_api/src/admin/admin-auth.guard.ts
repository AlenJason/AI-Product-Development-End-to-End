import { type CanActivate, type ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import type { Request } from 'express';
import { extractBearerToken } from '../auth/jwt-auth.guard.js';
import { AdminAuthService } from './admin-auth.service.js';

export type AdminRequest = Request & { adminUsername?: string };

// API của trang quản trị: chỉ nhận token Admin (khoá ký riêng — token người dùng bị 401).
@Injectable()
export class AdminAuthGuard implements CanActivate {
  constructor(private readonly adminAuth: AdminAuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AdminRequest>();
    const token = extractBearerToken(request.headers.authorization);
    if (!token) throw new UnauthorizedException('Cần đăng nhập trang quản trị.');
    request.adminUsername = await this.adminAuth.authenticate(token);
    return true;
  }
}
