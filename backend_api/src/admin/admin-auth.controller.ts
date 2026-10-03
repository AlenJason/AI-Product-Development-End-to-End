import { Body, Controller, Get, HttpCode, HttpStatus, Post, Req, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiTooManyRequestsResponse,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { RateLimit, RateLimitGuard } from '../rate-limit/rate-limit.guard.js';
import { AdminAuthGuard, type AdminRequest } from './admin-auth.guard.js';
import { AdminAuthService } from './admin-auth.service.js';
import { AdminLoginDto, AdminLoginResponseDto, AdminSessionDto } from './dto/admin-login.dto.js';

@ApiTags('admin')
@ApiNotFoundResponse({ description: 'Máy chủ chưa đặt ADMIN_USERNAME / ADMIN_PASSWORD_HASH' })
@Controller('api/v1/admin')
export class AdminAuthController {
  constructor(private readonly adminAuth: AdminAuthService) {}

  @Post('login')
  @HttpCode(HttpStatus.OK)
  // Chống dò mật khẩu: đếm mọi lần thử theo IP (RATE_LIMIT_ADMIN, mặc định 5 lần / 15 phút).
  @UseGuards(RateLimitGuard)
  @RateLimit('admin')
  @ApiOperation({ summary: 'Đăng nhập trang thống kê bằng tài khoản Admin cấp sẵn (không phải Google)' })
  @ApiOkResponse({ type: AdminLoginResponseDto })
  @ApiUnauthorizedResponse({ description: 'Sai tên đăng nhập hoặc mật khẩu (một câu chung cho cả hai)' })
  @ApiTooManyRequestsResponse({ description: 'Quá số lần thử cho phép — header Retry-After là số giây phải chờ' })
  login(@Body() dto: AdminLoginDto): Promise<AdminLoginResponseDto> {
    return this.adminAuth.login(dto.username, dto.password);
  }

  @Get('session')
  @UseGuards(AdminAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Kiểm phiên quản trị còn hiệu lực' })
  @ApiOkResponse({ type: AdminSessionDto })
  @ApiUnauthorizedResponse({ description: 'Thiếu token, token hết hạn, hoặc không phải token Admin' })
  session(@Req() request: AdminRequest): AdminSessionDto {
    return { username: request.adminUsername as string };
  }
}
