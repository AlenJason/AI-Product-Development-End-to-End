# AI Workspace — thử nghiệm Groq

Lệnh mặc định chạy Groq qua đúng prompt và validation backend; không duy trì một bản prompt sao chép. Khóa được đọc từ backend_api/.env. Các mô tả script Gemini bên dưới chỉ phục vụ lịch sử và lệnh `experiment:gemini:legacy`.

## Cài đặt & chạy

```bash
cd ../backend_api
npm run build
cd ../ai_workspace
npm run experiment
```

Script `generate-plan-experiment.ts` gọi Gemini với một prompt mẫu, in JSON trả về, và tự kiểm tra calo từng bữa có nằm trong khoảng hợp lý hay không (NFR-4 trong BRD.md).

## Nội dung

- `generate-plan-experiment.ts` — script thử nghiệm chính.
- `prompts/system-prompt.md` — prompt template tham khảo, đồng bộ với bản dùng trong backend.

Khi đã hài lòng với prompt, copy phần logic sang `backend_api/src/plan/gemini.service.ts`.
