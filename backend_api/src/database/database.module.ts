import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { dataSourceOptions, resolveDatabaseTarget } from './data-source-options.js';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        ...dataSourceOptions(
          resolveDatabaseTarget({
            DATABASE_URL: config.get<string>('DATABASE_URL'),
            DATABASE_PATH: config.get<string>('DATABASE_PATH'),
            VERCEL: config.get<string>('VERCEL'),
          }),
          // Vercel chạy migration ở bước build (`npm run db:migrate`): nhiều instance cùng khởi động thì không
          // chạy chồng migration lên nhau.
          { migrationsRun: config.get<string>('DATABASE_RUN_MIGRATIONS')?.trim() !== 'false' },
        ),
        // Mặc định thử lại 9 lần × 3 giây; lỗi mở file SQLite hay sai chuỗi kết nối không tự hết khi thử lại.
        retryAttempts: 0,
      }),
    }),
  ],
})
export class DatabaseModule {}
