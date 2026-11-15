#!/usr/bin/env node

import { execSync } from 'node:child_process';

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const PR_NUMBER = process.env.PR_NUMBER;
const REPO_NAME = process.env.REPO_NAME;
const BASE_REF = process.env.BASE_REF || 'main';

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const GROQ_API_KEY = process.env.GROQ_API_KEY;

const BOT_MARKER = '<!-- SMARTFIT_AI_PR_REVIEW -->';

async function main() {
  console.log(`[AI PR Reviewer] Khởi động review cho PR #${PR_NUMBER} trên repo ${REPO_NAME}`);

  // 1. Kiểm tra API Key
  const activeProvider = resolveProvider();
  if (!activeProvider) {
    const warningMsg =
      `⚠️ **[SmartFit AI PR Reviewer] Chưa cấu hình API Key**\n\n` +
      `Để kích hoạt tính năng tự động review PR bằng AI, vui lòng thêm một trong các Secret sau vào GitHub:\n` +
      `- \`GEMINI_API_KEY\` (Khuyên dùng - Google AI Studio)\n` +
      `- \`GROQ_API_KEY\` (Model Llama / Groq)\n` +
      `- \`OPENAI_API_KEY\` (OpenAI GPT-4o)\n\n` +
      `*Đường dẫn cài đặt: Settings -> Secrets and variables -> Actions -> New repository secret.*`;

    console.warn('Không tìm thấy GEMINI_API_KEY, GROQ_API_KEY hoặc OPENAI_API_KEY.');
    if (GITHUB_TOKEN && REPO_NAME && PR_NUMBER) {
      await postOrUpdateComment(warningMsg);
    }
    process.exit(0);
  }

  console.log(`[AI PR Reviewer] Đang dùng AI Provider: ${activeProvider.name}`);

  // 2. Lấy git diff giữa PR và nhánh base
  let diff = '';
  try {
    diff = execSync(
      `git diff origin/${BASE_REF}...HEAD -- . ':(exclude)*package-lock.json' ':(exclude)*pubspec.lock' ':(exclude)*.png' ':(exclude)*.jpg' ':(exclude)*.ico' ':(exclude)*dist/*' ':(exclude)*.map'`,
      { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024 },
    ).trim();
  } catch (err) {
    console.warn(`Lỗi khi lấy git diff: ${err.message}. Thử git diff HEAD~1...HEAD`);
    try {
      diff = execSync(`git diff HEAD~1...HEAD`, { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024 }).trim();
    } catch {
      diff = '';
    }
  }

  if (!diff) {
    console.log('[AI PR Reviewer] Không có thay đổi code đáng kể để review.');
    return;
  }

  // Cắt ngắn nếu diff quá lớn để tránh vượt context limit
  const MAX_DIFF_CHARS = 25000;
  let truncatedDiff = diff;
  if (diff.length > MAX_DIFF_CHARS) {
    truncatedDiff = diff.slice(0, MAX_DIFF_CHARS) + '\n\n... [Diff đã được cắt ngắn do dung lượng lớn] ...';
  }

  // 3. Gửi prompt đến LLM
  console.log(`[AI PR Reviewer] Đang gửi diff (${truncatedDiff.length} ký tự) đến ${activeProvider.name}...`);
  const reviewMarkdown = await callLLM(activeProvider, truncatedDiff);

  // 4. Đăng nhận xét lên PR GitHub
  if (GITHUB_TOKEN && REPO_NAME && PR_NUMBER) {
    console.log('[AI PR Reviewer] Đang gửi nhận xét lên GitHub PR...');
    await postOrUpdateComment(reviewMarkdown);
    console.log('[AI PR Reviewer] Hoàn tất nhận xét PR!');
  } else {
    console.log('[AI PR Reviewer] (Dry Run / Local) Kết quả review:\n\n' + reviewMarkdown);
  }
}

function resolveProvider() {
  if (GEMINI_API_KEY) {
    return { name: 'Gemini', type: 'gemini', key: GEMINI_API_KEY };
  }
  if (GROQ_API_KEY) {
    return { name: 'Groq', type: 'groq', key: GROQ_API_KEY };
  }
  if (OPENAI_API_KEY) {
    return { name: 'OpenAI', type: 'openai', key: OPENAI_API_KEY };
  }
  return null;
}

async function callLLM(provider, diffContent) {
  const systemPrompt = `Bạn là Senior AI Code Reviewer cho dự án SmartFit AI (Monorepo: Flutter Mobile + NestJS 12 TypeScript).
Nhiệm vụ của bạn là rà soát kỹ lưỡng Pull Request này theo khung 5 trục (5-Axis Review) và tuân thủ các quy tắc trong AGENTS.md:

Quy tắc bắt buộc của dự án:
1. Backend (NestJS ESM): Các import file tương đối bắt buộc phải có đuôi '.js' (ví dụ: './plan.service.js'). Quan hệ TypeORM bọc trong Relation<T>.
2. Frontend (Flutter): Tuân thủ Provider architecture. Tuyệt đối không gọi ApiClient/http trực tiếp từ Widget.
3. Bảo mật sức khoẻ (D4/D5): Thông tin nhạy cảm (dị ứng, chấn thương, bệnh nền) KHÔNG ĐƯỢC lưu vào database hoặc log server.
4. An toàn y tế (D6): BMI < 18.5 không được cho chọn 'Giảm mỡ' (cut). Tuổi tối thiểu 18.

Hãy định dạng kết quả review bằng Tiếng Việt rõ ràng với Markdown theo cấu trúc sau:
## 🤖 SmartFit AI — Báo cáo Review Pull Request

### 📋 1. Tóm tắt thay đổi (Summary)
[Mô tả ngắn gọn PR này thay đổi những gì]

### 🔍 2. Đánh giá 5 trục chất lượng (5-Axis Evaluation)
- **Đúng đắn (Correctness):** [Logic nghiệp vụ, xử lý edge cases, null-safety, try-catch]
- **Dễ đọc & Tối ưu (Readability):** [Đặt tên biến/hàm, code thừa, độ phức tạp]
- **Kiến trúc (Architecture):** [Tuân thủ Provider / ESM .js / TypeORM / API contract]
- **Bảo mật & Quyền riêng tư (Security & Privacy):** [Rào cản D4/D5 dữ liệu sức khỏe, SQL injection, secrets]
- **Hiệu năng (Performance):** [Re-render Flutter, rò rỉ bộ nhớ, N+1 query]

### ⚠️ 3. Danh sách phát hiện (Actionable Findings)
*(Nếu không có vấn đề, ghi rõ: "Không phát hiện lỗi nghiêm trọng")*
Phân loại theo nhãn:
- \`[CRITICAL]\`: Lỗi logic, crash app, vi phạm bảo mật (Bắt buộc sửa trước khi merge)
- \`[REQUIRED]\`: Lỗi cấu trúc, thiếu validate, import sai
- \`[OPTIONAL]\`: Đề xuất cải thiện hiệu năng hoặc clean code
- \`[NIT]\`: Góp ý nhỏ về format / đặt tên

### 🏁 4. Kết luận
- Đánh giá: **[APPROVED / SẴN SÀNG MERGE]** hoặc **[CHANGES REQUESTED / CẦN SỬA LỖI]**`;

  if (provider.type === 'gemini') {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${provider.key}`;
    const payload = {
      contents: [
        {
          role: 'user',
          parts: [
            { text: systemPrompt },
            { text: `Dưới đây là git diff của Pull Request cần review:\n\`\`\`diff\n${diffContent}\n\`\`\`` },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.2,
      },
    };

    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Gemini API error (${res.status}): ${errText}`);
    }

    const data = await res.json();
    return data.candidates?.[0]?.content?.parts?.[0]?.text || 'Không có phản hồi từ Gemini.';
  }

  if (provider.type === 'groq' || provider.type === 'openai') {
    const endpoint =
      provider.type === 'groq'
        ? 'https://api.groq.com/openai/v1/chat/completions'
        : 'https://api.openai.com/v1/chat/completions';
    const model = provider.type === 'groq' ? 'llama-3.3-70b-versatile' : 'gpt-4o-mini';

    const payload = {
      model,
      temperature: 0.2,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: `Dưới đây là git diff của Pull Request cần review:\n\`\`\`diff\n${diffContent}\n\`\`\`` },
      ],
    };

    const res = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${provider.key}`,
      },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`${provider.name} API error (${res.status}): ${errText}`);
    }

    const data = await res.json();
    return data.choices?.[0]?.message?.content || `Không có phản hồi từ ${provider.name}.`;
  }

  throw new Error(`Provider không được hỗ trợ: ${provider.type}`);
}

async function postOrUpdateComment(content) {
  const fullBody = `${BOT_MARKER}\n\n${content}\n\n---\n*Được tự động rà soát bởi SmartFit AI PR Reviewer*`;

  // Kiểm tra comment cũ của bot để cập nhật thay vì spam nhiều comment
  try {
    const commentsUrl = `https://api.github.com/repos/${REPO_NAME}/issues/${PR_NUMBER}/comments`;
    const res = await fetch(commentsUrl, {
      headers: {
        Authorization: `Bearer ${GITHUB_TOKEN}`,
        Accept: 'application/vnd.github.v3+json',
      },
    });

    if (res.ok) {
      const comments = await res.json();
      const existing = comments.find((c) => c.body && c.body.includes(BOT_MARKER));

      if (existing) {
        console.log(`[AI PR Reviewer] Cập nhật comment cũ #${existing.id}`);
        await fetch(`https://api.github.com/repos/${REPO_NAME}/issues/comments/${existing.id}`, {
          method: 'PATCH',
          headers: {
            Authorization: `Bearer ${GITHUB_TOKEN}`,
            'Content-Type': 'application/json',
            Accept: 'application/vnd.github.v3+json',
          },
          body: JSON.stringify({ body: fullBody }),
        });
        return;
      }
    }
  } catch (err) {
    console.warn(`Không thể lấy danh sách comment cũ: ${err.message}`);
  }

  // Tạo comment mới
  const createUrl = `https://api.github.com/repos/${REPO_NAME}/issues/${PR_NUMBER}/comments`;
  const postRes = await fetch(createUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      'Content-Type': 'application/json',
      Accept: 'application/vnd.github.v3+json',
    },
    body: JSON.stringify({ body: fullBody }),
  });

  if (!postRes.ok) {
    const errText = await postRes.text();
    console.error(`Lỗi khi tạo comment: ${errText}`);
  }
}

main().catch((err) => {
  console.error(`[AI PR Reviewer Error]:`, err);
  // Không cho CI fail hoàn toàn nếu lỗi LLM, chỉ ghi log
  process.exit(0);
});
