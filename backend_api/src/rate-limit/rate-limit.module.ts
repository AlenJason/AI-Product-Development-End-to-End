import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';
import { RATE_LIMIT_CONFIG, resolveRateLimitConfig } from './rate-limit-config.js';
import { RateLimitStore } from './rate-limit-store.js';
import { RateLimitGuard } from './rate-limit.guard.js';

// Global: controller ở module khác (PlanModule) dùng @UseGuards(RateLimitGuard) thì guard vẫn lấy được cấu hình và
// bộ đếm. Sai cấu hình → ném lỗi lúc khởi động (resolveRateLimitConfig).
@Global()
@Module({
  providers: [
    {
      provide: RATE_LIMIT_CONFIG,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => resolveRateLimitConfig((key) => config.get<string>(key)),
    },
    { provide: RateLimitStore, inject: [DataSource], useFactory: (dataSource: DataSource) => new RateLimitStore(dataSource) },
    RateLimitGuard,
  ],
  exports: [RATE_LIMIT_CONFIG, RateLimitStore, RateLimitGuard],
})
export class RateLimitModule {}
