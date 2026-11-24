import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface.js';

// Khi phát triển, Flutter web chạy ở cổng ngẫu nhiên trên localhost (`flutter run -d chrome`).
const DEV_ORIGINS = [/^http:\/\/localhost(:\d+)?$/, /^http:\/\/127\.0\.0\.1(:\d+)?$/];

// CORS chỉ cần cho bản web của app — trình duyệt chặn request khác origin nếu backend không cho phép.
// App mobile không gửi Origin nên không bị ảnh hưởng. Không dùng cookie (đăng nhập bằng header Authorization),
// nên credentials: false. Sai cấu hình → ném lỗi, backend không khởi động.
export function resolveCorsOptions(env: (key: string) => string | undefined): CorsOptions | null {
  const listed = (env('CORS_ORIGINS') ?? '')
    .split(',')
    .map((origin) => origin.trim().replace(/\/+$/, ''))
    .filter(Boolean);
  for (const origin of listed) {
    if (!/^https?:\/\/[^/\s]+$/.test(origin)) {
      throw new Error(`CORS_ORIGINS: "${origin}" phải có dạng http(s)://host[:port], không có đường dẫn.`);
    }
  }
  // Deploy mà không khai báo origin → tắt CORS, chỉ app mobile gọi được.
  if (listed.length === 0 && env('NODE_ENV')?.trim() === 'production') return null;
  return {
    origin: (requestOrigin, callback) => {
      if (!requestOrigin) return callback(null, true);
      if (listed.length === 0) {
        const allowed = DEV_ORIGINS.some((rx) => rx.test(requestOrigin));
        return callback(null, allowed);
      }
      const allowed = listed.some((item) => {
        if (item === requestOrigin) return true;
        if (item.startsWith('http://localhost') && /^http:\/\/localhost(:\d+)?$/.test(requestOrigin)) return true;
        if (item.startsWith('http://127.0.0.1') && /^http:\/\/127\.0\.0\.1(:\d+)?$/.test(requestOrigin)) return true;
        return false;
      });
      return callback(null, allowed);
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: false,
    maxAge: 600,
  };
}
