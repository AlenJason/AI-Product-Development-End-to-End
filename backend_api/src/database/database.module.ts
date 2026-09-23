import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DEFAULT_DATABASE_PATH, dataSourceOptions } from './data-source-options.js';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        ...dataSourceOptions(config.get<string>('DATABASE_PATH')?.trim() || DEFAULT_DATABASE_PATH),
        // Mặc định thử lại 9 lần × 3 giây; với file SQLite, lỗi mở file không tự hết khi thử lại.
        retryAttempts: 0,
      }),
    }),
  ],
})
export class DatabaseModule {}
