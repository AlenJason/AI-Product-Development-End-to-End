import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';

// Server Gemini giả cho test: SDK @google/genai thật gửi request tới đây qua GEMINI_BASE_URL.
export type FakeGeminiReply =
  | { kind: 'json'; body: unknown }
  | { kind: 'text'; text: string }
  | { kind: 'error'; status: number; message: string }
  | { kind: 'hang' };

export interface FakeGemini {
  url: string;
  requests: string[];
  // Đường dẫn từng request, ví dụ /v1beta/models/gemini-3.5-flash:generateContent — cho biết model nào được gọi.
  paths: string[];
  // Đặt hàng đợi phản hồi và xoá lịch sử request. Hết hàng đợi thì lặp lại phản hồi cuối.
  reply(...replies: FakeGeminiReply[]): void;
  close(): Promise<void>;
}

export async function startFakeGemini(): Promise<FakeGemini> {
  let queue: FakeGeminiReply[] = [{ kind: 'error', status: 500, message: 'Chưa đặt phản hồi cho server giả' }];
  const requests: string[] = [];
  const paths: string[] = [];

  const server = createServer((req, res) => {
    let body = '';
    req.on('data', (chunk: Buffer) => (body += chunk.toString()));
    req.on('end', () => {
      requests.push(body);
      paths.push(req.url ?? '');
      const next = queue.length > 1 ? (queue.shift() as FakeGeminiReply) : queue[0];
      if (next.kind === 'hang') return;
      if (next.kind === 'error') {
        res.writeHead(next.status, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ error: { code: next.status, message: next.message, status: 'ERROR' } }));
        return;
      }
      const text = next.kind === 'json' ? JSON.stringify(next.body) : next.text;
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ candidates: [{ content: { role: 'model', parts: [{ text }] }, finishReason: 'STOP' }] }));
    });
  });

  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address() as AddressInfo;

  return {
    url: `http://127.0.0.1:${port}`,
    requests,
    paths,
    reply: (...replies) => {
      queue = replies;
      requests.length = 0;
      paths.length = 0;
    },
    close: () =>
      new Promise<void>((resolve) => {
        server.closeAllConnections();
        server.close(() => resolve());
      }),
  };
}
