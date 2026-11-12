import { Body, Controller, Delete, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import type { User } from '../database/entities/user.entity.js';
import { AuthService } from './auth.service.js';
import { AuthResponseDto } from './dto/auth-response.dto.js';
import { ChangePasswordDto } from './dto/change-password.dto.js';
import { GoogleLoginDto } from './dto/google-login.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { RegisterDto } from './dto/register.dto.js';
import { CurrentUser, JwtAuthGuard } from './jwt-auth.guard.js';

@ApiTags('auth')
@Controller('api/v1')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('auth/register')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đăng ký tài khoản mới bằng email và mật khẩu' })
  @ApiOkResponse({ type: AuthResponseDto })
  register(@Body() dto: RegisterDto): Promise<AuthResponseDto> {
    return this.auth.register(dto);
  }

  @Post('auth/login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đăng nhập bằng email và mật khẩu' })
  @ApiOkResponse({ type: AuthResponseDto })
  @ApiUnauthorizedResponse({ description: 'Email hoặc mật khẩu không đúng' })
  loginWithPassword(@Body() dto: LoginDto): Promise<AuthResponseDto> {
    return this.auth.login(dto);
  }

  @Post('auth/change-password')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Đổi mật khẩu cho tài khoản đang đăng nhập' })
  @ApiUnauthorizedResponse({ description: 'Chưa đăng nhập hoặc mật khẩu hiện tại không đúng' })
  changePassword(
    @CurrentUser() user: User,
    @Body() dto: ChangePasswordDto,
  ): Promise<{ message: string }> {
    return this.auth.changePassword(user.id, dto);
  }

  @Post('auth/google')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đổi Google ID Token lấy JWT của SmartFit (BRD FR-6)' })
  @ApiOkResponse({ type: AuthResponseDto })
  @ApiUnauthorizedResponse({ description: 'ID Token không xác minh được' })
  login(@Body() dto: GoogleLoginDto): Promise<AuthResponseDto> {
    return this.auth.loginWithGoogle(dto.id_token);
  }

  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Xoá tài khoản và toàn bộ lịch sử kế hoạch (BRD FR-6.4)' })
  @ApiNoContentResponse({ description: 'Đã xoá' })
  @ApiUnauthorizedResponse({ description: 'Chưa đăng nhập hoặc token sai' })
  async deleteAccount(@CurrentUser() user: User): Promise<void> {
    await this.auth.deleteAccount(user.id);
  }
}
