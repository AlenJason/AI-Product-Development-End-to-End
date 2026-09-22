# AI Workspace — thử nghiệm prompt Gemini

Nơi thử nghiệm prompt & schema Structured Output JSON với Gemini API, độc lập với `backend_api/`, trước khi đưa prompt đã chốt vào `backend_api/src/plan/gemini.service.ts` (theo roadmap BRD.md tuần 1).

## Cài đặt & chạy

```bash
npm install
cp .env.example .env   # điền GEMINI_API_KEY
npm run experiment
```

Script `generate-plan-experiment.ts` gọi Gemini với một prompt mẫu, in JSON trả về, và tự kiểm tra calo từng bữa có nằm trong khoảng hợp lý hay không (NFR-4 trong BRD.md).

## Nội dung

- `generate-plan-experiment.ts` — script thử nghiệm chính.
- `prompts/system-prompt.md` — prompt template tham khảo, đồng bộ với bản dùng trong backend.

Khi đã hài lòng với prompt, copy phần logic sang `backend_api/src/plan/gemini.service.ts`.
