import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { DatabaseModule } from './database/database.module.js';
import { HistoryModule } from './history/history.module.js';
import { PlanModule } from './plan/plan.module.js';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), DatabaseModule, AuthModule, HistoryModule, PlanModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
