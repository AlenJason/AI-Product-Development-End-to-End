# F05 — GitHub Actions: build + test backend, kiểm kiểu `ai_workspace`

## Feature

Mỗi lần push hoặc mở pull request có đụng tới `backend_api/`, `ai_workspace/` hay chính file workflow, GitHub tự chạy:

- **`backend_api`** trên Node 24 (LTS hiện tại) và Node 26 (bản máy dev đang dùng; lên LTS ngày 28/10/2026): `npm ci` → `npm run build` → `npm test` → `npm run test:e2e`.
- **`ai_workspace`** trên Node 24: `npm ci` → `npx tsc --noEmit`.

Không cần khoá nào: unit test không gọi Gemini, e2e dùng server Gemini giả (F02, F04). Flutter chưa đưa vào CI vì widget test Flutter đang fail sẵn (PLAN 5.6 sẽ sửa).

Phiên bản action đã kiểm qua GitHub API ngày 2026-09-24: `actions/checkout` v7.0.1, `actions/setup-node` v7.0.0 → ghim theo major `@v7`. Lịch Node lấy từ `nodejs/Release/schedule.json`.

## Scope

CI — `.github/workflows/backend.yml` (mới)

## Implementation

### API Routes

Không đổi route. Workflow chạy e2e của `POST /api/v1/generate-plan` trên máy chủ GitHub; thời gian mỗi job ước khoảng 1–3 phút (cài package chiếm phần lớn; có cache npm).

**Khoá API bên ngoài:** workflow không khai báo secret nào. Nếu sau này thêm test cần khoá thật, phải dùng GitHub Secrets và không chạy cho pull request từ fork.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#3** không có khoá nào trong workflow; `.env` không có trên máy CI (đã gitignore) → mọi test chạy ở chế độ giả lập.
- Quyền tối thiểu: `permissions: contents: read`.

## Definition of Done

- [ ] Sau khi push, run "Backend CI" của commit đó kết thúc `success` cho cả 3 job (Node 24, Node 26, ai_workspace)
- [ ] Commit chỉ sửa tài liệu (không đụng 3 đường dẫn trên) không kích hoạt workflow
- [x] All API routes complete within deployment timeout — không đổi route
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: push lên `Thien-Source` → 3 job xanh
2. **@auth**: không áp dụng
3. **@timeout**: mỗi job có `timeout-minutes: 10` để job treo không ăn hết phút miễn phí
4. **@partial-fail**: `fail-fast: false` — Node 24 đỏ vẫn cho Node 26 chạy xong, để biết lỗi chỉ ở một phiên bản hay ở cả hai
5. **@token**: không có secret nào được dùng
6. **@db**: không áp dụng

## Tasks

### Task 1 — Workflow

`.github/workflows/backend.yml`:

```yaml
name: Backend CI

on:
  push:
    paths:
      - 'backend_api/**'
      - 'ai_workspace/**'
      - '.github/workflows/backend.yml'
  pull_request:
    paths:
      - 'backend_api/**'
      - 'ai_workspace/**'
      - '.github/workflows/backend.yml'

permissions:
  contents: read

jobs:
  backend:
    name: backend_api (Node ${{ matrix.node }})
    runs-on: ubuntu-latest
    timeout-minutes: 10
    strategy:
      fail-fast: false
      matrix:
        node: [24, 26]
    defaults:
      run:
        working-directory: backend_api
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: ${{ matrix.node }}
          cache: npm
          cache-dependency-path: backend_api/package-lock.json
      - run: npm ci
      - run: npm run build
      - run: npm test
      - run: npm run test:e2e

  ai_workspace:
    name: ai_workspace (type-check)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    defaults:
      run:
        working-directory: ai_workspace
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: 24
          cache: npm
          cache-dependency-path: ai_workspace/package-lock.json
      - run: npm ci
      - run: npx tsc --noEmit
```

### Task 2 — Kiểm cú pháp trước khi push

```bash
ruby -ryaml -e 'y = YAML.load_file(".github/workflows/backend.yml"); puts y["jobs"].keys.inspect'
```

Mong đợi: `["backend", "ai_workspace"]`. (macOS có sẵn Ruby; dùng để parse YAML vì Python trên máy chưa có PyYAML.)

### Task 3 — Kiểm sau khi push

Push xong, chờ 2–4 phút rồi chạy:

```bash
curl -s 'https://api.github.com/repos/AlenJason/AI-Product-Development-End-to-End/actions/runs?branch=Thien-Source&per_page=1' \
  | python3 -c "import json,sys; r=json.load(sys.stdin)['workflow_runs'][0]; print(r['name'], r['status'], r['conclusion'], r['head_sha'][:7])"
```

Mong đợi: `Backend CI completed success <7 ký tự đầu SHA của commit vừa push>`. Nếu `failure`: mở tab Actions trên GitHub, xem job nào đỏ, sửa, commit + push lại.
