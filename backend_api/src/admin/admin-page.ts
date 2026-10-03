// Trang thống kê cho Admin (giai đoạn 10, quyết định Q3): HTML/CSS/JS thuần nằm trong code TS — không có file asset
// để Vercel phải đóng gói (#5, #40). JS dựng DOM bằng textContent, không bao giờ innerHTML với dữ liệu (thông báo lỗi
// của Google được hiện nguyên văn). CSP chỉ cho script/style từ chính trang này.

export const ADMIN_PAGE_HEADERS: Record<string, string> = {
  'Content-Security-Policy':
    "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; " +
    "form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Cache-Control': 'no-store',
  'X-Robots-Tag': 'noindex, nofollow',
};

export const ADMIN_PAGE_HTML = `<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, nofollow">
  <title>SmartFit AI — Thống kê</title>
  <link rel="stylesheet" href="/admin/app.css">
  <script src="/admin/app.js" defer></script>
</head>
<body>
  <main>
    <section id="login" hidden>
      <h1>SmartFit AI — Thống kê</h1>
      <p class="muted">Trang dành cho nhóm phát triển. Chỉ có số liệu ẩn danh, không có dữ liệu của người dùng nào.</p>
      <form id="login-form" autocomplete="on">
        <label>Tên đăng nhập <input id="username" name="username" autocomplete="username" required maxlength="64"></label>
        <label>Mật khẩu <input id="password" name="password" type="password" autocomplete="current-password" required maxlength="200"></label>
        <button type="submit">Đăng nhập</button>
        <p id="login-error" class="error" role="alert"></p>
      </form>
    </section>
    <section id="dashboard" hidden>
      <header>
        <h1>SmartFit AI — Thống kê</h1>
        <span id="who" class="muted"></span>
        <button id="logout" type="button" class="secondary">Đăng xuất</button>
      </header>
      <p id="error" class="error" role="alert"></p>
      <div id="overview" class="cards"></div>
      <h2>Theo tháng</h2>
      <p class="muted">Bấm vào một tháng để xem từng ngày và nhật ký Gemini của tháng đó. Ngày tính theo giờ Việt Nam.</p>
      <div class="scroll"><table id="months"></table></div>
      <div id="month-detail" hidden>
        <h2 id="month-title"></h2>
        <div class="scroll"><table id="days"></table></div>
        <h3>Gemini theo model và kết quả</h3>
        <div class="scroll"><table id="gemini-summary"></table></div>
        <h3>Nhật ký Gemini</h3>
        <div class="toolbar">
          <label>Kết quả <select id="outcome"></select></label>
          <button id="prev" type="button" class="secondary">← Mới hơn</button>
          <span id="page-info" class="muted"></span>
          <button id="next" type="button" class="secondary">Cũ hơn →</button>
        </div>
        <div class="scroll"><table id="calls"></table></div>
      </div>
    </section>
  </main>
</body>
</html>
`;

export const ADMIN_PAGE_CSS = `:root {
  --page: #FDFBF7; --panel: #FFFFFF; --ink: #0F172A; --muted: #64748B; --border: #E2E8F0;
  --primary: #059669; --error: #B91C1C; --row-hover: #ECFDF5;
}
@media (prefers-color-scheme: dark) {
  :root { --page: #0B1120; --panel: #111827; --ink: #E2E8F0; --muted: #94A3B8; --border: #1F2937;
    --primary: #10B981; --error: #F87171; --row-hover: #064E3B; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--page); color: var(--ink); font: 15px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
main { max-width: 1200px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font-size: 1.4rem; margin: 0; }
h2 { font-size: 1.15rem; margin: 32px 0 4px; }
h3 { font-size: 1rem; margin: 24px 0 8px; }
.muted { color: var(--muted); }
.error { color: var(--error); min-height: 1.5em; }
header { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
header h1 { flex: 1; }
#login { max-width: 360px; margin: 10vh auto; }
#login form { display: grid; gap: 12px; margin-top: 16px; }
label { display: grid; gap: 4px; font-weight: 600; }
input, select { font: inherit; padding: 8px 10px; border: 1px solid var(--border); border-radius: 8px; background: var(--panel); color: var(--ink); }
button { font: inherit; font-weight: 600; padding: 8px 14px; border-radius: 8px; border: 1px solid var(--primary); background: var(--primary); color: #fff; cursor: pointer; }
button.secondary { background: transparent; color: var(--primary); }
button:disabled { opacity: 0.5; cursor: default; }
.cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; margin-top: 16px; }
.card { background: var(--panel); border: 1px solid var(--border); border-radius: 12px; padding: 12px 16px; }
.card .label { color: var(--muted); font-size: 0.85rem; }
.card .value { font-size: 1.4rem; font-weight: 700; }
.card .note { color: var(--muted); font-size: 0.85rem; }
.bar { height: 6px; background: var(--border); border-radius: 3px; margin-top: 6px; overflow: hidden; }
.bar > span { display: block; height: 100%; background: var(--primary); }
.scroll { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; background: var(--panel); border: 1px solid var(--border); border-radius: 12px; }
th, td { padding: 8px 10px; border-bottom: 1px solid var(--border); text-align: right; white-space: nowrap; }
th:first-child, td:first-child { text-align: left; }
th { font-size: 0.8rem; color: var(--muted); font-weight: 600; }
tr.clickable { cursor: pointer; }
tr.clickable:hover, tr.selected { background: var(--row-hover); }
td.message { white-space: normal; text-align: left; max-width: 420px; color: var(--muted); }
#calls th:last-child { text-align: left; }
.toolbar { display: flex; gap: 12px; align-items: end; flex-wrap: wrap; margin-bottom: 8px; }
`;

export const ADMIN_PAGE_JS = `'use strict';
(() => {
  const TOKEN_KEY = 'smartfit.admin.token';
  const OUTCOME = { ok: 'Thành công', timeout: 'Hết giờ', overloaded: 'Quá tải (503)', quota: 'Hết lượt (429)', invalid: 'Kết quả hỏng', error: 'Lỗi khác' };
  const TASK = { plan: 'Tạo kế hoạch', meal_swap: 'Đổi món', exercise_swap: 'Đổi bài tập', feedback: 'Cân đối món' };
  const $ = (id) => document.getElementById(id);
  let token = null;
  let month = null;
  let page = 1;
  try { token = sessionStorage.getItem(TOKEN_KEY); } catch { token = null; }

  function el(tag, props, ...children) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(props || {})) {
      if (key === 'class') node.className = value;
      else if (key === 'onclick') node.addEventListener('click', value);
      else node.setAttribute(key, value);
    }
    for (const child of children) node.append(child instanceof Node ? child : document.createTextNode(String(child)));
    return node;
  }

  async function api(path, options) {
    const headers = { 'content-type': 'application/json' };
    if (token) headers.authorization = 'Bearer ' + token;
    const res = await fetch(path, { ...options, headers });
    const body = await res.json().catch(() => ({}));
    if (res.status === 401 && path !== '/api/v1/admin/login') {
      showLogin('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.');
      throw new Error('');
    }
    if (!res.ok) throw new Error(Array.isArray(body.message) ? body.message.join('; ') : body.message || 'Lỗi ' + res.status);
    return body;
  }

  function showLogin(message) {
    token = null;
    try { sessionStorage.removeItem(TOKEN_KEY); } catch { /* bỏ qua */ }
    $('dashboard').hidden = true;
    $('login').hidden = false;
    $('login-error').textContent = message || '';
    $('password').value = '';
  }

  const n = (usage, metric) => (usage[metric] ? usage[metric].count : 0);
  const avgSeconds = (usage, metric) =>
    usage[metric] && usage[metric].count ? (usage[metric].total_ms / usage[metric].count / 1000).toFixed(1) + ' s' : '—';
  const pct = (part, total) => (total ? Math.round((100 * part) / total) + '%' : '—');

  function usageCells(usage, gemini) {
    const plans = n(usage, 'plan.gemini') + n(usage, 'plan.sample');
    const calls = gemini.reduce((sum, row) => sum + row.calls, 0);
    const ok = gemini.filter((row) => row.outcome === 'ok').reduce((sum, row) => sum + row.calls, 0);
    const limited = Object.keys(usage).filter((key) => key.startsWith('rate_limited.')).reduce((sum, key) => sum + usage[key].count, 0);
    return [
      plans,
      pct(n(usage, 'plan.gemini'), plans),
      n(usage, 'plan.guest') + ' / ' + n(usage, 'plan.signed_in'),
      avgSeconds(usage, 'plan.gemini'),
      n(usage, 'meal_swap.gemini') + ' / ' + n(usage, 'meal_swap.pool') + ' / ' + n(usage, 'meal_swap.none'),
      n(usage, 'exercise_swap.gemini') + ' / ' + n(usage, 'exercise_swap.pool') + ' / ' + n(usage, 'exercise_swap.none'),
      n(usage, 'feedback.total'),
      calls,
      pct(ok, calls),
      limited,
      n(usage, 'admin.login.failed'),
    ];
  }
  const USAGE_HEADERS = ['Kế hoạch', 'Gemini thật', 'Khách / Đăng nhập', 'Chờ TB (Gemini)', 'Đổi món G / Kho / ✗',
    'Đổi bài G / Kho / ✗', 'Đánh giá', 'Lượt gọi Gemini', 'Gemini thành công', 'Bị chặn (429)', 'Admin nhập sai'];

  function renderTable(table, headers, rows) {
    table.replaceChildren(el('thead', {}, el('tr', {}, ...headers.map((h) => el('th', {}, h)))), el('tbody', {}, ...rows));
  }

  function renderOverview(o) {
    const cards = [];
    const geminiNote = o.gemini.configured
      ? 'Chính ' + o.gemini.primary_model + (o.gemini.fallback_model ? ', dự phòng ' + o.gemini.fallback_model : ', không dự phòng')
      : 'Chưa có GEMINI_API_KEY — luôn dùng thực đơn mẫu';
    cards.push(el('div', { class: 'card' }, el('div', { class: 'label' }, 'Gemini'),
      el('div', { class: 'value' }, o.gemini.configured ? 'Đang bật' : 'Tắt'), el('div', { class: 'note' }, geminiNote),
      el('div', { class: 'note' }, 'Chờ tối đa ' + o.gemini.per_call_timeout_ms / 1000 + ' s mỗi lần, ' + o.gemini.total_timeout_ms / 1000 + ' s tổng')));
    const models = [o.gemini.primary_model].concat(o.gemini.fallback_model ? [o.gemini.fallback_model] : []);
    for (const model of models) {
      const today = o.gemini_today.find((row) => row.model === model) || { calls: 0, ok: 0 };
      const bar = el('span');
      bar.style.width = Math.min(100, (100 * today.calls) / o.gemini.daily_limit_per_model) + '%';
      cards.push(el('div', { class: 'card' }, el('div', { class: 'label' }, 'Lượt hôm nay — ' + model),
        el('div', { class: 'value' }, today.calls + ' / ' + o.gemini.daily_limit_per_model),
        el('div', { class: 'note' }, today.ok + ' lần thành công (gói miễn phí: 20 lần/ngày mỗi model)'), el('div', { class: 'bar' }, bar)));
    }
    cards.push(el('div', { class: 'card' }, el('div', { class: 'label' }, 'Tài khoản'), el('div', { class: 'value' }, o.accounts),
      el('div', { class: 'note' }, o.saved_plans + ' kế hoạch đã lưu trong lịch sử')));
    cards.push(el('div', { class: 'card' }, el('div', { class: 'label' }, 'Giới hạn tần suất'),
      el('div', { class: 'note' }, 'Tạo kế hoạch: ' + o.rate_limits.plan), el('div', { class: 'note' }, 'Đổi món/bài, đánh giá: ' + o.rate_limits.adjust),
      el('div', { class: 'note' }, 'Đăng nhập Admin: ' + o.rate_limits.admin)));
    $('overview').replaceChildren(...cards);
  }

  function renderMonths(months) {
    if (months.length === 0) {
      renderTable($('months'), ['Tháng'], [el('tr', {}, el('td', {}, 'Chưa có số liệu.'))]);
      return;
    }
    renderTable($('months'), ['Tháng'].concat(USAGE_HEADERS), months.map((m) => {
      const row = el('tr', { class: 'clickable' + (m.month === month ? ' selected' : ''), onclick: () => openMonth(m.month) },
        el('td', {}, m.month), ...usageCells(m.usage, m.gemini).map((cell) => el('td', {}, cell)));
      return row;
    }));
  }

  async function openMonth(selected) {
    month = selected;
    page = 1;
    $('month-detail').hidden = false;
    $('month-title').textContent = 'Tháng ' + selected;
    for (const row of $('months').querySelectorAll('tbody tr')) row.classList.toggle('selected', row.firstChild.textContent === selected);
    try {
      const detail = await api('/api/v1/admin/stats/months/' + selected);
      renderTable($('days'), ['Ngày'].concat(USAGE_HEADERS),
        detail.days.map((d) => el('tr', {}, el('td', {}, d.day), ...usageCells(d.usage, d.gemini).map((cell) => el('td', {}, cell)))));
      const summary = {};
      for (const d of detail.days) for (const g of d.gemini) {
        const key = g.model + '|' + g.outcome;
        summary[key] = summary[key] || { model: g.model, outcome: g.outcome, calls: 0, total: 0 };
        summary[key].calls += g.calls;
        summary[key].total += g.avg_ms * g.calls;
      }
      const rows = Object.values(summary).sort((a, b) => a.model.localeCompare(b.model) || b.calls - a.calls);
      renderTable($('gemini-summary'), ['Model', 'Kết quả', 'Số lần', 'Thời gian TB'], rows.length
        ? rows.map((r) => el('tr', {}, el('td', {}, r.model), el('td', {}, OUTCOME[r.outcome] || r.outcome), el('td', {}, r.calls),
          el('td', {}, (r.total / r.calls / 1000).toFixed(1) + ' s')))
        : [el('tr', {}, el('td', {}, 'Không có lần gọi Gemini nào.'))]);
      await loadCalls();
    } catch (error) {
      $('error').textContent = error.message;
    }
  }

  async function loadCalls() {
    const outcome = $('outcome').value;
    const query = '?month=' + encodeURIComponent(month) + '&page=' + page + (outcome ? '&outcome=' + encodeURIComponent(outcome) : '');
    const data = await api('/api/v1/admin/stats/gemini-calls' + query);
    const pages = Math.max(1, Math.ceil(data.total / data.page_size));
    $('page-info').textContent = 'Trang ' + data.page + ' / ' + pages + ' — ' + data.total + ' lần gọi';
    $('prev').disabled = page <= 1;
    $('next').disabled = page >= pages;
    renderTable($('calls'), ['Thời điểm', 'Tính năng', 'Model', 'Lần', 'Kết quả', 'Mã', 'Thời gian', 'Thông báo'], data.calls.length
      ? data.calls.map((c) => el('tr', {},
        el('td', {}, new Date(c.created_at).toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })),
        el('td', {}, TASK[c.task] || c.task), el('td', {}, c.model), el('td', {}, c.attempt), el('td', {}, OUTCOME[c.outcome] || c.outcome),
        el('td', {}, c.http_status === null ? '—' : c.http_status), el('td', {}, (c.duration_ms / 1000).toFixed(1) + ' s'),
        el('td', { class: 'message' }, c.message || '')))
      : [el('tr', {}, el('td', {}, 'Không có lần gọi nào.'))]);
  }

  async function loadDashboard() {
    $('error').textContent = '';
    try {
      const session = await api('/api/v1/admin/session');
      $('login').hidden = true;
      $('dashboard').hidden = false;
      $('who').textContent = 'Đăng nhập: ' + session.username;
      renderOverview(await api('/api/v1/admin/stats/overview'));
      renderMonths(await api('/api/v1/admin/stats/months'));
    } catch (error) {
      if (error.message) $('error').textContent = error.message;
    }
  }

  document.addEventListener('DOMContentLoaded', () => {
    const select = $('outcome');
    select.append(el('option', { value: '' }, 'Tất cả'));
    for (const [value, label] of Object.entries(OUTCOME)) select.append(el('option', { value }, label));
    select.addEventListener('change', () => { page = 1; loadCalls().catch((e) => { $('error').textContent = e.message; }); });
    $('prev').addEventListener('click', () => { page -= 1; loadCalls().catch((e) => { $('error').textContent = e.message; }); });
    $('next').addEventListener('click', () => { page += 1; loadCalls().catch((e) => { $('error').textContent = e.message; }); });
    $('logout').addEventListener('click', () => showLogin(''));
    $('login-form').addEventListener('submit', async (event) => {
      event.preventDefault();
      $('login-error').textContent = '';
      try {
        const body = await api('/api/v1/admin/login', {
          method: 'POST',
          body: JSON.stringify({ username: $('username').value, password: $('password').value }),
        });
        token = body.access_token;
        try { sessionStorage.setItem(TOKEN_KEY, token); } catch { /* chỉ giữ trong bộ nhớ */ }
        $('password').value = '';
        await loadDashboard();
      } catch (error) {
        $('login-error').textContent = error.message;
      }
    });
    if (token) loadDashboard();
    else showLogin('');
  });
})();
`;
