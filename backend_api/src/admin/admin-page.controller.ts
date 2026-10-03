import { Controller, Get, Res } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import type { Response } from 'express';
import { ADMIN_PAGE_CSS, ADMIN_PAGE_HEADERS, ADMIN_PAGE_HTML, ADMIN_PAGE_JS } from './admin-page.js';

// https://<backend>/admin — trang thống kê, tách khỏi app người dùng (quyết định Q3). Không có trong Swagger.
@ApiExcludeController()
@Controller('admin')
export class AdminPageController {
  @Get()
  page(@Res() res: Response): void {
    send(res, 'text/html; charset=utf-8', ADMIN_PAGE_HTML);
  }

  @Get('app.js')
  script(@Res() res: Response): void {
    send(res, 'text/javascript; charset=utf-8', ADMIN_PAGE_JS);
  }

  @Get('app.css')
  style(@Res() res: Response): void {
    send(res, 'text/css; charset=utf-8', ADMIN_PAGE_CSS);
  }
}

function send(res: Response, contentType: string, body: string): void {
  res.set({ ...ADMIN_PAGE_HEADERS, 'Content-Type': contentType }).send(body);
}
