// Chạy dist/main.js như runtime Node của Vercel (smoke test dùng): import module chứ không chạy trực tiếp, rồi gọi
// export default cho mỗi request. Vercel thay http.Server.prototype.listen bằng hàm không bao giờ gọi callback —
// app tự listen lúc được import là function treo tới hết giờ (deploy thử, giai đoạn 9) — nên ở đây báo lỗi ngay.
import http from 'node:http';

const originalListen = http.Server.prototype.listen;
http.Server.prototype.listen = function () {
  throw new Error('dist/main.js tự gọi listen() khi được import — trên Vercel function sẽ treo tới hết giờ');
};
const { default: handler } = await import('../dist/main.js');
http.Server.prototype.listen = originalListen;
if (typeof handler !== 'function') throw new Error('dist/main.js phải export default một handler (req, res)');

http.createServer(handler).listen(Number(process.env.PORT), '127.0.0.1');
