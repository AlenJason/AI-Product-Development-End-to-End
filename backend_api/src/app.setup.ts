import { type INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { resolveCorsOptions } from './cors-options.js';
import { resolveRateLimitConfig } from './rate-limit/rate-limit-config.js';

// Vercel chỉ đóng gói những file mà code tham chiếu tĩnh. Swagger UI phục vụ cả thư mục swagger-ui-dist bằng
// express.static, nên không file nào trong đó được đóng gói và /docs trắng trang trên production (deploy thử, giai đoạn
// 9). Viết dạng `new URL(…, import.meta.url)` để công cụ dò file của Vercel (nft) thấy; app.setup.spec.ts kiểm file có thật.
export const SWAGGER_UI_ASSETS = [
  new URL('../node_modules/swagger-ui-dist/swagger-ui.css', import.meta.url),
  new URL('../node_modules/swagger-ui-dist/swagger-ui-bundle.js', import.meta.url),
  new URL('../node_modules/swagger-ui-dist/swagger-ui-standalone-preset.js', import.meta.url),
  new URL('../node_modules/swagger-ui-dist/favicon-16x16.png', import.meta.url),
  new URL('../node_modules/swagger-ui-dist/favicon-32x32.png', import.meta.url),
];

// Dùng chung cho main.ts và test e2e, để test chạy đúng cấu hình của server thật.
export function configureApp(app: INestApplication): void {
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const config = app.get(ConfigService);
  const cors = resolveCorsOptions((key) => config.get<string>(key));
  if (cors) app.enableCors(cors);

  // Sau proxy của host (Vercel), IP thật nằm trong X-Forwarded-For — giới hạn tần suất của khách đếm theo IP (PLAN 9.7).
  const { trustProxyHops } = resolveRateLimitConfig((key) => config.get<string>(key));
  if (trustProxyHops > 0) app.getHttpAdapter().getInstance().set('trust proxy', trustProxyHops);

  const document = new DocumentBuilder()
    .setTitle('SmartFit AI API')
    .setDescription('Backend API cho SmartFit AI — xem BRD.md ở repo gốc')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, document));
}
