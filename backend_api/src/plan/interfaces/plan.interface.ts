// Kiểu dữ liệu khớp với response JSON schema ở BRD.md mục 6.2.

export interface MealItem {
  meal_id: string;
  meal_type: string;
  name: string;
  portion: string;
  calories: number;
  protein_g: number;
  ingredients: string[];
}

export interface WorkoutExercise {
  exercise_id: string;
  name: string;
  sets: number;
  reps_or_duration: string;
  target_muscle: string;
}

export interface Workout {
  title: string;
  duration_minutes: number;
  exercises: WorkoutExercise[];
}

export interface DayPlan {
  day_number: number;
  day_name: string;
  meals: MealItem[];
  workout: Workout;
}

export interface GroceryItem {
  name: string;
  source_meal_ids: string[];
}

export interface GroceryCategory {
  category: string;
  items: GroceryItem[];
}

export interface DailyTarget {
  target_calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
}

export interface MealPlanResponse {
  plan_id: string;
  daily_target: DailyTarget;
  days: DayPlan[];
  grocery_list: GroceryCategory[];
}
