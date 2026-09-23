# Giai đoạn 2 — Backend: kiểm thử nền — Plan

**Status:** ready
**Brainstorm:** `docs/superpowers/brainstorms/phase-2-backend-tests.md` (hướng C, quyết định Q1–Q2 ở mục 9)
**Executor:** thực thi trực tiếp theo spec (`/feature-build` bản hiện tại chỉ nhận cấu trúc Next.js).
**Commit:** một commit + push cho cả giai đoạn sau F06, lên nhánh đang làm việc (hiện là `Thien-Source`). Cổng kiểm tra của F05 (CI) chỉ chạy được sau khi push.

## Features

| ID | Tên | Phạm vi | Bước PLAN |
|---|---|---|---|
| F01 | Ma trận BMR/TDEE 18 trường hợp | API (test) | 2.1 |
| F02 | `GEMINI_BASE_URL`, server Gemini giả, test `GeminiService` với SDK thật | API | 2.5 (mới, Q1) |
| F03 | Test `PlanService` với Gemini giả: gọi lại, hết giờ, khoá sai, log | API (test) | 2.3 |
| F04 | `configureApp()` dùng chung + e2e `POST /api/v1/generate-plan` | API | 2.4 |
| F05 | GitHub Actions: build + test backend, kiểm kiểu `ai_workspace` | CI | 2.6 (mới, Q2) |
| F06 | Wiki, CLAUDE.md, hướng dẫn, Changelog, tiến độ | Docs | — |

## Thứ tự thực hiện

F01, F02, F03 (độc lập với nhau) → F04 (cần server giả của F02) → F05 → F06

## Ràng buộc từ wiki

Không có ràng buộc nào mâu thuẫn với hướng C. Các ràng buộc được test khoá lại trong giai đoạn này:

| Ràng buộc | Test |
|---|---|
| #12 không ghi log / trả về dữ liệu sức khoẻ | F03 (log của `PlanService`), F02 (lỗi JSON không trích nội dung), F04 (response không chứa văn bản sức khoẻ) |
| #13 sàn BMR | F01 (trường hợp nữ, ít vận động, giảm mỡ) |
| #15 timeout, không để SDK tự gọi lại | F02 (đếm request thật khi server trả 500), F03 + F04 (hết giờ → không gọi lại) |
| #16 ID do server gán | F04 (`plan_id` là UUID dù Gemini không gửi) |

Ràng buộc mới sẽ ghi vào wiki ở F06: test không bao giờ gọi Gemini thật; cấu hình app nằm ở `configureApp()` để e2e chạy giống server thật.

## Danh sách file

- `specs/F01-daily-target-matrix.md`
- `specs/F02-gemini-service-real-sdk.md`
- `specs/F03-plan-service-retry.md`
- `specs/F04-e2e-generate-plan.md`
- `specs/F05-github-actions.md`
- `specs/F06-docs-wiki.md`
- `project.json`
- `README.md`

## Kết quả khi xong giai đoạn

- Unit test: 9 file, 61 test (hiện 8 file, 31 test). E2E: 2 file, 12 test (hiện 1 file, 1 test).
- Mỗi lần push, GitHub chạy build + toàn bộ test trên Node 24 (LTS) và Node 26, không cần khoá nào.
