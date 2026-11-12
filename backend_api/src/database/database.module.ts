import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { resolveDataSourceOptions } from './data-source-options.js';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        ...resolveDataSourceOptions(config),
        // Thất bại nhanh nếu DB chưa khởi động hoặc sai cấu hình kết nối.
        retryAttempts: 0,
      }),
    }),
  ],
})
export class DatabaseModule {}
