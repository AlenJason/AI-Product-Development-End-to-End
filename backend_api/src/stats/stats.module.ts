import { Global, Module } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { StatsService } from './stats.service.js';

// Global: GeminiService, các service đổi món/bài/feedback và RateLimitGuard ở module khác đều ghi số liệu.
@Global()
@Module({
  providers: [{ provide: StatsService, inject: [DataSource], useFactory: (dataSource: DataSource) => new StatsService(dataSource) }],
  exports: [StatsService],
})
export class StatsModule {}
