// Run after build: node --env-file=.env scripts/test-groq-plan.mjs
// Synthetic profile only. Never prints keys, prompts or generated health data.
import 'reflect-metadata';
import { ConfigService } from '@nestjs/config';
import { GroqPlanService } from '../dist/plan/groq-plan.service.js';
import { PlanService } from '../dist/plan/plan.service.js';

if (!process.env.GROQ_API_KEY?.trim()) {
  console.error('Thiếu GROQ_API_KEY trong backend_api/.env. Chưa gọi API.');
  process.exit(1);
}
const groq = new GroqPlanService(new ConfigService({ ...process.env, PLAN_AI_PROVIDER: 'groq' }));
const started = Date.now();
const plan = await new PlanService({ isConfigured: false }, groq).generatePlan({
  age: 22, gender: 'female', height_cm: 168, weight_kg: 62,
  activity_level: 'light', goal: 'cut', pregnant_or_breastfeeding: false,
  restrictions: { allergies: '', injuries: '', health_conditions: '' },
});
console.log(JSON.stringify({ passed: plan.source === 'groq', source: plan.source, elapsedMs: Date.now() - started,
  days: plan.days.length, mealsPerDay: plan.days.map(day => day.meals.length),
  targetCalories: plan.daily_target.target_calories,
  caloriesPerDay: plan.days.map(day => day.meals.reduce((sum, meal) => sum + meal.calories, 0)),
  groceryItems: plan.grocery_list.length }, null, 2));
if (plan.source !== 'groq') process.exitCode = 1;
