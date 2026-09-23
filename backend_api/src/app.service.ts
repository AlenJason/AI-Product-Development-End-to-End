import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AUTH_CONFIG, type AuthConfig, type AuthMode } from './auth/auth-config.js';

export interface HealthStatus {
  status: 'ok';
  gemini: 'configured' | 'fallback';
  auth_mode: AuthMode;
}

@Injectable()
export class AppService {
  constructor(
    private readonly config: ConfigService,
    @Inject(AUTH_CONFIG) private readonly auth: AuthConfig,
  ) {}

  getHealth(): HealthStatus {
    return {
      status: 'ok',
      gemini: this.config.get<string>('GEMINI_API_KEY') ? 'configured' : 'fallback',
      auth_mode: this.auth.mode,
    };
  }
}
