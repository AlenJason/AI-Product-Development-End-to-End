import type { IncomingMessage, ServerResponse } from 'node:http';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';
import { configureApp } from './app.setup.js';

type RequestHandler = (req: IncomingMessage, res: ServerResponse) => void;

async function createApp() {
  const app = await NestFactory.create(AppModule);
  configureApp(app);
  return app;
}

let handler: Promise<RequestHandler> | undefined;

// Vercel nạp file này như một module rồi gọi export default cho mỗi request; app khởi tạo một lần mỗi instance
// (request đầu tiên chờ). Không listen khi bị import: runtime của Vercel thay listen() bằng hàm không bao giờ gọi
// callback, `await app.listen()` lúc nạp module làm function treo tới hết giờ (deploy thử, giai đoạn 9).
export default async function vercelHandler(req: IncomingMessage, res: ServerResponse): Promise<void> {
  handler ??= createApp().then(async (app) => {
    await app.init();
    return app.getHttpAdapter().getInstance() as RequestHandler;
  });
  (await handler)(req, res);
}

// Chạy trực tiếp (`node dist/main.js`, `npm run start:dev`) → server thường.
if (import.meta.main) {
  const app = await createApp();
  await app.listen(process.env.PORT ?? 3000);
}
