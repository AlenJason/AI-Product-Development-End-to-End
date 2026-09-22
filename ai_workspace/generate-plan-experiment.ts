// Script thử nghiệm độc lập: gọi Gemini với Structured Output JSON Mode và
// in kết quả để kiểm tra prompt trước khi đưa vào backend_api/src/plan/gemini.service.ts.
//
// Chạy: npm run experiment

import 'dotenv/config';
import { GoogleGenAI } from '@google/genai';

const CALORIE_BOUNDS: Record<string, { min: number; max: number }> = {
  'Bữa sáng': { min: 250, max: 600 },
  'Bữa trưa': { min: 400, max: 800 },
  'Bữa tối': { min: 400, max: 800 },
};

const SAMPLE_INPUT = {
  goal: 'cut',
  target_calories: 1850,
  protein_g: 110,
  carbs_g: 200,
  fat_g: 50,
  allergies: ['Hải sản'],
  injuries: ['Đau gối'],
};

function buildPrompt(input: typeof SAMPLE_INPUT): string {
  return [
    'Bạn là chuyên gia dinh dưỡng & thể hình người Việt.',
    'Hãy tạo kế hoạch ăn uống 3 ngày (mỗi ngày 3 bữa: sáng/trưa/tối) và bài tập bodyweight tại nhà cho người dùng có:',
    `- Mục tiêu: ${input.goal}`,
    `- Calo mục tiêu mỗi ngày: ${input.target_calories} kcal (protein ${input.protein_g}g, carbs ${input.carbs_g}g, fat ${input.fat_g}g)`,
    `- Dị ứng cần tránh: ${input.allergies.join(', ') || 'không có'}`,
    `- Chấn thương cần tránh động tác ảnh hưởng: ${input.injuries.join(', ') || 'không có'}`,
    'Yêu cầu bắt buộc: chỉ dùng món ăn gia đình Việt Nam bình dân, không lặp lại tên món giữa 3 ngày, bài tập không cần dụng cụ.',
    'Trả về đúng cấu trúc JSON theo schema: { plan_id, daily_target, days: [{ day_number, day_name, meals: [{ meal_id, meal_type, name, portion, calories, protein_g, ingredients }], workout: { title, duration_minutes, exercises: [{ exercise_id, name, sets, reps_or_duration, target_muscle }] } }], grocery_list: [{ category, items: [{ name, source_meal_ids }] }] }.',
    'Không thêm giải thích, chỉ trả về JSON thuần.',
  ].join('\n');
}

function checkNutritionBounds(plan: any): string[] {
  const problems: string[] = [];
  for (const day of plan.days ?? []) {
    for (const meal of day.meals ?? []) {
      const bounds = CALORIE_BOUNDS[meal.meal_type];
      if (bounds && (meal.calories < bounds.min || meal.calories > bounds.max)) {
        problems.push(
          `${day.day_name} - ${meal.meal_type} (${meal.name}): ${meal.calories} kcal ngoài khoảng [${bounds.min}, ${bounds.max}]`,
        );
      }
    }
  }
  return problems;
}

async function main() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error('Thiếu GEMINI_API_KEY. Copy .env.example thành .env và điền key.');
    process.exit(1);
  }

  const client = new GoogleGenAI({ apiKey });

  const prompt = buildPrompt(SAMPLE_INPUT);
  console.log('--- PROMPT ---\n' + prompt + '\n');

  const response = await client.models.generateContent({
    model: process.env.GEMINI_MODEL ?? 'gemini-3.8-flash',
    contents: prompt,
    config: { responseMimeType: 'application/json' },
  });
  const text = response.text;
  if (!text) {
    throw new Error('Gemini trả về response rỗng');
  }

  const plan = JSON.parse(text);
  console.log('--- RESPONSE JSON ---');
  console.log(JSON.stringify(plan, null, 2));

  const problems = checkNutritionBounds(plan);
  console.log('\n--- NUTRITION SANITY CHECK (NFR-4) ---');
  console.log(problems.length === 0 ? 'OK: mọi bữa ăn nằm trong khoảng calo hợp lý.' : problems.join('\n'));
}

main().catch((error) => {
  console.error('Lỗi khi gọi Gemini:', error);
  process.exit(1);
});
