// Mã cố định của hợp đồng API (BRD mục 6.1, 6.2, 6.4). `code` là giá trị đúng như trong JSON.

enum Gender {
  male('male'),
  female('female');

  const Gender(this.code);
  final String code;
}

enum ActivityLevel {
  sedentary('sedentary'),
  light('light'),
  active('active');

  const ActivityLevel(this.code);
  final String code;
}

enum Goal {
  cut('cut'),
  bulk('bulk'),
  maintain('maintain');

  const Goal(this.code);
  final String code;
}

enum PlanSource {
  gemini('gemini'),
  sample('sample');

  const PlanSource(this.code);
  final String code;
}

enum MealType {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner');

  const MealType(this.code);
  final String code;
}

enum IngredientUnit {
  g('g'),
  ml('ml'),
  piece('piece'),
  tbsp('tbsp'),
  tsp('tsp');

  const IngredientUnit(this.code);
  final String code;
}

enum IngredientCategory {
  protein('protein'),
  produce('produce'),
  pantry('pantry');

  const IngredientCategory(this.code);
  final String code;
}

enum MuscleGroup {
  legs('legs'),
  chest('chest'),
  back('back'),
  core('core'),
  shoulders('shoulders'),
  arms('arms'),
  fullBody('full_body'),
  cardio('cardio');

  const MuscleGroup(this.code);
  final String code;
}

enum ExerciseTag {
  jumping('jumping'),
  kneeling('kneeling'),
  wristLoad('wrist_load'),
  backLoad('back_load'),
  overhead('overhead');

  const ExerciseTag(this.code);
  final String code;
}

enum Intensity {
  easy('easy'),
  moderate('moderate'),
  hard('hard');

  const Intensity(this.code);
  final String code;
}

enum BodyState {
  normal('normal'),
  sore('sore'),
  jointPain('joint_pain'),
  fatigued('fatigued'),
  dangerSign('danger_sign');

  const BodyState(this.code);
  final String code;
}

enum Eating {
  onPlan('on_plan'),
  over('over'),
  under('under');

  const Eating(this.code);
  final String code;
}
