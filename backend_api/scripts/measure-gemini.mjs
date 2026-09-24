// Đo Gemini THẬT với đúng prompt và bước kiểm của backend (bản build trong dist/), để chọn model,
// mức suy nghĩ (GEMINI_THINKING) và giới hạn thời gian (GEMINI_TIMEOUT_MS / GEMINI_TOTAL_TIMEOUT_MS).
// Tốn hạn mức và gửi dữ liệu mẫu (không phải dữ liệu người dùng) tới Google — không bao giờ chạy trong test hay CI (#17).
//
//   npm run build && npm run measure:gemini
//   MEASURE_MODELS=gemini-3.5-flash MEASURE_THINKING=off,low npm run measure:gemini
import { GoogleGenAI } from '@google/genai';
import { writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildMealSwapPrompt } from '../dist/plan/adjust/adjust-prompts.js';
import { computeDailyTarget } from '../dist/plan/daily-target.js';
import { CreatePlanDto } from '../dist/plan/dto/create-plan.dto.js';
import { MealContentDto } from '../dist/plan/dto/plan-content.dto.js';
import { RestrictionsDto } from '../dist/plan/dto/restrictions.dto.js';
import { buildPlanPrompt } from '../dist/plan/gemini.service.js';
import { mealCalorieBounds, parseContent, parsePlanContent } from '../dist/plan/plan-validation.js';
import { findRestrictionViolations } from '../dist/plan/restriction-filter.js';
import { findAvoidedIngredient, matchRestrictions } from '../dist/plan/restriction-matcher.js';

const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  console.error('Thiếu GEMINI_API_KEY trong backend_api/.env');
  process.exit(1);
}
const MODELS = (process.env.MEASURE_MODELS ?? 'gemini-3.5-flash').split(',').map((m) => m.trim());
const THINKING = (process.env.MEASURE_THINKING ?? 'default,low,off').split(',').map((t) => t.trim());
const PACE_MS = Number(process.env.MEASURE_PACE_MS ?? 12_000); // gói miễn phí giới hạn số lần gọi mỗi phút
const CALL_TIMEOUT_MS = 90_000; // đo thời gian thật, không cắt ở giới hạn của backend
const OUT = process.env.MEASURE_OUT ?? join(tmpdir(), `measure-gemini-${Date.now()}.json`);
const THINKING_CONFIG = { default: undefined, low: { thinkingLevel: 'LOW' }, off: { thinkingBudget: 0 } };

const profile = (values, restrictions) =>
  Object.assign(new CreatePlanDto(), values, { restrictions: Object.assign(new RestrictionsDto(), restrictions) });
const PROFILES = {
  'nữ 1624 kcal, dị ứng hải sản, đau gối': profile(
    { age: 22, gender: 'female', height_cm: 168, weight_kg: 62, activity_level: 'light', goal: 'cut' },
    { allergies: 'Hải sản', injuries: 'Đau gối' },
  ),
  'nam 2806 kcal, không hạn chế': profile(
    { age: 30, gender: 'male', height_cm: 175, weight_kg: 70, activity_level: 'active', goal: 'bulk' },
    {},
  ),
  'nữ 45t, đậu phộng + sữa, đau lưng, tiểu đường': profile(
    { age: 45, gender: 'female', height_cm: 155, weight_kg: 58, activity_level: 'sedentary', goal: 'maintain' },
    { allergies: 'đậu phộng, sữa', injuries: 'đau lưng', health_conditions: 'tiểu đường' },
  ),
};
const SWAP_MEAL = {
  meal_type: 'lunch', name: 'Cơm trắng, ức gà xào nấm, canh cải ngọt', portion: '1 chén cơm + 1 đĩa + 1 bát canh',
  calories: 641, protein_g: 45.7, carbs_g: 86.3, fat_g: 12.2,
  ingredients: [{ name: 'Gạo tẻ', amount: 100, unit: 'g', category: 'pantry' }],
};

const client = new GoogleGenAI({ apiKey });
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function call(model, thinking, prompt) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    const started = Date.now();
    try {
      const response = await client.models.generateContent({
        model,
        contents: prompt,
        config: {
          responseMimeType: 'application/json',
          httpOptions: { timeout: CALL_TIMEOUT_MS },
          ...(THINKING_CONFIG[thinking] ? { thinkingConfig: THINKING_CONFIG[thinking] } : {}),
        },
      });
      const usage = response.usageMetadata ?? {};
      return { ms: Date.now() - started, thoughts: usage.thoughtsTokenCount ?? 0, output: usage.candidatesTokenCount, text: response.text };
    } catch (error) {
      if ((error.status === 503 || error.status === 429) && attempt < 3) {
        await sleep(20_000);
        continue;
      }
      return { error: `${error.status ?? ''} ${String(error.message).match(/"message":"([^"]{0,90})/)?.[1] ?? String(error.message).slice(0, 90)}` };
    }
  }
}

function checkPlan(text, p) {
  let raw;
  try { raw = JSON.parse(text); } catch { return 'JSON hỏng'; }
  const { target } = computeDailyTarget(p);
  const { plan, errors } = parsePlanContent(raw, target);
  if (!plan) return `sai hợp đồng: ${errors[0]}`;
  const violations = findRestrictionViolations(plan.days, matchRestrictions(p.restrictions));
  return violations.length > 0 ? `vướng hạn chế: ${violations[0]}` : 'ĐẠT';
}

function checkSwap(text, p, range) {
  let raw;
  try { raw = JSON.parse(text); } catch { return 'JSON hỏng'; }
  const { value, errors } = parseContent(MealContentDto, raw);
  if (!value) return `sai hợp đồng: ${errors[0]}`;
  if (value.calories < range.min || value.calories > range.max) return `calo ${value.calories} ngoài ${range.min}–${range.max}`;
  return findAvoidedIngredient(value, matchRestrictions(p.restrictions).avoidIngredients) ? 'vướng dị ứng' : 'ĐẠT';
}

const results = [];
const [swapLabel, swapProfile] = Object.entries(PROFILES)[0];
const lunchBounds = mealCalorieBounds(computeDailyTarget(swapProfile).target.target_calories).lunch;
const swapRange = { min: Math.max(Math.round(SWAP_MEAL.calories * 0.9), lunchBounds.min), max: Math.min(Math.round(SWAP_MEAL.calories * 1.1), lunchBounds.max) };

for (const model of MODELS) {
  for (const thinking of THINKING) {
    const jobs = [
      ...Object.entries(PROFILES).map(([label, p]) => ({ task: 'tạo plan', label, prompt: buildPlanPrompt(p, computeDailyTarget(p).target), check: (t) => checkPlan(t, p) })),
      { task: 'đổi món', label: swapLabel, prompt: buildMealSwapPrompt(swapProfile, SWAP_MEAL, swapRange, [SWAP_MEAL.name]), check: (t) => checkSwap(t, swapProfile, swapRange) },
    ];
    for (const job of jobs) {
      const r = await call(model, thinking, job.prompt);
      const verdict = r.error ? `LỖI ${r.error}` : job.check(r.text);
      const row = { model, thinking, task: job.task, profile: job.label, ms: r.ms, thoughts: r.thoughts, output: r.output, verdict };
      results.push(row);
      console.log(`${model} | ${thinking} | ${job.task} | ${job.label} | ${r.ms ?? '-'} ms | suy nghĩ ${r.thoughts ?? '-'} tok | ${verdict}`);
      writeFileSync(OUT, JSON.stringify(results, null, 2));
      await sleep(PACE_MS);
      if (r.error && /không hỗ trợ|not supported/i.test(r.error)) break; // cấu hình không hợp model → bỏ qua phần còn lại
    }
  }
}

console.log('\nTóm tắt (chỉ tính lần gọi có kết quả):');
for (const model of MODELS) {
  for (const thinking of THINKING) {
    for (const task of ['tạo plan', 'đổi món']) {
      const rows = results.filter((r) => r.model === model && r.thinking === thinking && r.task === task);
      const done = rows.filter((r) => r.ms !== undefined);
      if (rows.length === 0) continue;
      const ms = done.map((r) => r.ms).sort((a, b) => a - b);
      const passed = done.filter((r) => r.verdict === 'ĐẠT').length;
      console.log(`${model} | ${thinking} | ${task}: đạt ${passed}/${done.length} (lỗi API ${rows.length - done.length}) | ${ms.length ? `${ms[0]}–${ms.at(-1)} ms` : '-'}`);
    }
  }
}
console.log(`\nChi tiết: ${OUT}`);
