// Synthetic-profile live acceptance. Uses real Groq and normal business validators.
// Never counts a successful pool fallback as successful Groq inference.
import 'reflect-metadata';
import { ConfigService } from '@nestjs/config';
import { Logger } from '@nestjs/common';
import { GroqPlanService } from '../dist/plan/groq-plan.service.js';
import { PlanService } from '../dist/plan/plan.service.js';
import { MealSwapService } from '../dist/plan/adjust/meal-swap.service.js';
import { ExerciseSwapService } from '../dist/plan/adjust/exercise-swap.service.js';
import { FeedbackService } from '../dist/plan/adjust/feedback.service.js';
import { RandomSource } from '../dist/plan/adjust/random-source.js';

if (!process.env.GROQ_API_KEY?.trim()) {
  console.error('Thiếu GROQ_API_KEY; chưa gọi mạng.');
  process.exit(1);
}
Logger.overrideLogger(false);
const profile = {
  age: 22, gender: 'female', height_cm: 168, weight_kg: 62,
  activity_level: 'light', goal: 'cut', pregnant_or_breastfeeding: false,
  restrictions: { allergies: '', injuries: '', health_conditions: '' },
};
const groq = new GroqPlanService(new ConfigService({ ...process.env, PLAN_AI_PROVIDER: 'groq' }));
const plan = await new PlanService({ isConfigured: false }).generatePlan(profile);
const generateJson = groq.generateJson.bind(groq);
let outputs = [];
let statuses = [];
groq.generateJson = async (...args) => {
  try {
    const raw = await generateJson(...args);
    outputs.push(raw);
    statuses.push(200);
    return raw;
  } catch (error) {
    statuses.push(error.status || error.name);
    throw error;
  }
};
const random = new RandomSource();
const cases = [
  ['meal_swap', async () => {
    const result = await new MealSwapService(groq, random).swap({ profile, plan, meal_id: 'm1_2' });
    return outputs.some(raw => raw.name === result.days[0].meals[1].name);
  }],
  ['exercise_swap', async () => {
    const result = await new ExerciseSwapService(groq, random).swap({ profile, plan, exercise_id: 'e1_2' });
    return outputs.some(raw => raw.name === result.days[0].workout.exercises[1].name);
  }],
  ['feedback_meals', async () => {
    const result = await new FeedbackService(groq, new PlanService(groq, groq)).apply({
      profile, plan, day_number: 1, intensity: 'moderate', body_states: ['normal'], eating: 'under',
    });
    return outputs.some(raw => raw.meals?.length === 3 && raw.meals.every(meal =>
      result.response.plan.days[1].meals.some(accepted => accepted.name === meal.name)));
  }],
];
const results = [];
for (const [task, run] of cases) {
  outputs = [];
  statuses = [];
  const started = Date.now();
  try { results.push({ task, passed: await run(), elapsedMs: Date.now() - started, statuses }); }
  catch { results.push({ task, passed: false, elapsedMs: Date.now() - started, statuses }); }
  // Do not keep consuming quota if the provider rejects permission or rate limit.
  if (statuses.some(status => [401, 403, 429].includes(status))) break;
}
console.log(JSON.stringify(results, null, 2));
if (results.length !== cases.length || results.some(result => !result.passed)) process.exitCode = 1;
