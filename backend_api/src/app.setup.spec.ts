import { existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { SWAGGER_UI_ASSETS } from './app.setup.js';

describe('SWAGGER_UI_ASSETS', () => {
  it('trỏ vào đúng thư mục swagger-ui-dist mà @nestjs/swagger phục vụ', () => {
    // swagger-ui-dist là phụ thuộc của @nestjs/swagger: npm có thể đặt nó dưới node_modules/@nestjs/swagger thay vì
    // node_modules gốc — khi đó đường dẫn trong app.setup.ts sai và /docs trên Vercel lại trắng trang.
    const fromNestSwagger = createRequire(createRequire(import.meta.url).resolve('@nestjs/swagger'));
    const servedDir = dirname(fromNestSwagger.resolve('swagger-ui-dist/package.json'));
    for (const asset of SWAGGER_UI_ASSETS) {
      const path = fileURLToPath(asset);
      expect(existsSync(path), path).toBe(true);
      expect(dirname(path)).toBe(servedDir);
    }
  });
});
