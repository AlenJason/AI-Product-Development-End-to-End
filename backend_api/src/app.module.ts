import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { PlanModule } from './plan/plan.module.js';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), PlanModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
