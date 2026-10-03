import { Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';
import { AUTH_CONFIG, type AuthConfig, DEV_JWT_SECRET } from '../auth/auth-config.js';
import { AuthModule } from '../auth/auth.module.js';
import { GeminiService } from '../plan/gemini.service.js';
import { PlanModule } from '../plan/plan.module.js';
import { RATE_LIMIT_CONFIG, type RateLimitConfig } from '../rate-limit/rate-limit-config.js';
import { ADMIN_CONFIG, type AdminConfig, resolveAdminConfig } from './admin-config.js';
import { AdminAuthController } from './admin-auth.controller.js';
import { AdminAuthGuard } from './admin-auth.guard.js';
import { AdminAuthService } from './admin-auth.service.js';
import { AdminPageController } from './admin-page.controller.js';
import { AdminStatsController } from './admin-stats.controller.js';
import { AdminStatsService } from './admin-stats.service.js';

// Trang thống kê cho Admin (giai đoạn 10). Cấu hình sai → backend không khởi động; không cấu hình → trang tắt (404).
@Module({
  imports: [AuthModule, PlanModule],
  controllers: [AdminAuthController, AdminStatsController, AdminPageController],
  providers: [
    {
      provide: ADMIN_CONFIG,
      inject: [ConfigService, AUTH_CONFIG],
      useFactory: (config: ConfigService, auth: AuthConfig): AdminConfig | null => {
        const adminConfig = resolveAdminConfig((key) => config.get<string>(key));
        if (adminConfig && auth.jwtSecret === DEV_JWT_SECRET) {
          new Logger('AdminConfig').warn(
            'Trang Admin đang ký token bằng JWT_SECRET mặc định của chế độ mock — chỉ dùng khi phát triển; đặt JWT_SECRET riêng khi deploy.',
          );
        }
        return adminConfig;
      },
    },
    AdminAuthService,
    AdminAuthGuard,
    {
      provide: AdminStatsService,
      inject: [DataSource, GeminiService, RATE_LIMIT_CONFIG],
      useFactory: (dataSource: DataSource, gemini: GeminiService, rateLimits: RateLimitConfig) =>
        new AdminStatsService(dataSource, gemini, rateLimits),
    },
  ],
  exports: [AdminAuthService, AdminAuthGuard],
})
export class AdminModule {}
