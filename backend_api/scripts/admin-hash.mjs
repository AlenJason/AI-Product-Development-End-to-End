// Tạo ADMIN_PASSWORD_HASH cho trang thống kê (giai đoạn 10). Chạy trên máy của Admin: mật khẩu không được in ra
// (trừ khi dùng --generate), không ghi vào file, không gửi đi đâu — chỉ dán dòng mã băm vào biến môi trường Vercel.
//
//   npm run build && npm run admin:hash                  # hỏi mật khẩu 2 lần, không hiện chữ khi gõ
//   npm run build && npm run admin:hash -- --generate    # tự tạo mật khẩu ngẫu nhiên, in ra đúng một lần
//   printf '%s' "$MAT_KHAU" | npm run admin:hash         # đọc mật khẩu từ stdin
import { randomBytes } from 'node:crypto';
import { hashAdminPassword, MIN_ADMIN_PASSWORD_LENGTH } from '../dist/admin/admin-password.js';

function readHidden(prompt) {
  process.stdout.write(prompt);
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding('utf8');
  let value = '';
  return new Promise((resolve) => {
    const cleanup = () => {
      process.stdin.setRawMode(false);
      process.stdin.pause();
      process.stdin.off('data', onData);
      process.stdout.write('\n');
    };
    const onData = (chunk) => {
      for (const ch of chunk) {
        if (ch === '\r' || ch === '\n') {
          cleanup();
          resolve(value);
          return;
        }
        if (ch === '\u0003') {
          cleanup();
          process.exit(130);
        }
        value = ch === '\u007f' || ch === '\b' ? value.slice(0, -1) : value + ch;
      }
    };
    process.stdin.on('data', onData);
  });
}

async function readStdin() {
  let data = '';
  for await (const chunk of process.stdin) data += chunk;
  return data.replace(/\r?\n$/, '');
}

let password;
const generate = process.argv.includes('--generate');
if (generate) {
  password = randomBytes(18).toString('base64url');
} else if (!process.stdin.isTTY) {
  password = await readStdin();
} else {
  password = await readHidden('Mật khẩu Admin: ');
  if ((await readHidden('Nhập lại: ')) !== password) {
    console.error('Hai lần nhập không khớp.');
    process.exit(1);
  }
}
if ([...password].length < MIN_ADMIN_PASSWORD_LENGTH) {
  console.error(`Mật khẩu cần ít nhất ${MIN_ADMIN_PASSWORD_LENGTH} ký tự (nên dùng --generate).`);
  process.exit(1);
}
const hash = await hashAdminPassword(password);
if (generate) console.log(`Mật khẩu (chỉ in lần này — lưu vào trình quản lý mật khẩu): ${password}`);
console.log(`ADMIN_PASSWORD_HASH=${hash}`);
