import { Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity.js';
import { AUTH_CONFIG, type AuthConfig, AuthMode, resolveAuthConfig } from './auth-config.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { GoogleIdTokenVerifier, IdTokenVerifier, MockIdTokenVerifier } from './id-token-verifier.js';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [AuthController],
  providers: [
    {
      provide: AUTH_CONFIG,
      inject: [ConfigService],
      useFactory: (config: ConfigService): AuthConfig => {
        const { config: authConfig, warnings } = resolveAuthConfig((key) => config.get<string>(key));
        const logger = new Logger('AuthConfig');
        for (const warning of warnings) logger.warn(warning);
        return authConfig;
      },
    },
    {
      provide: JwtService,
      inject: [AUTH_CONFIG],
      useFactory: (config: AuthConfig) =>
        new JwtService({
          secret: config.jwtSecret,
          signOptions: { algorithm: 'HS256', expiresIn: config.jwtExpiresInSeconds },
          verifyOptions: { algorithms: ['HS256'] },
        }),
    },
    {
      provide: IdTokenVerifier,
      inject: [AUTH_CONFIG],
      useFactory: (config: AuthConfig): IdTokenVerifier =>
        config.mode === AuthMode.GOOGLE
          ? new GoogleIdTokenVerifier(config.googleClientIds)
          : new MockIdTokenVerifier(),
    },
    AuthService,
  ],
  exports: [AUTH_CONFIG, AuthService],
})
export class AuthModule {}
