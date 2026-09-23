import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface HealthStatus {
  status: 'ok';
  gemini: 'configured' | 'fallback';
}

@Injectable()
export class AppService {
  constructor(private readonly config: ConfigService) {}

  getHealth(): HealthStatus {
    return {
      status: 'ok',
      gemini: this.config.get<string>('GEMINI_API_KEY') ? 'configured' : 'fallback',
    };
  }
}
