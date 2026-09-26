import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/codes.dart';
import '../models/api/meal_plan.dart';
import '../models/plan_schedule.dart';
import '../providers/plan_provider.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import '../widgets/macro_ring.dart';

// Kế hoạch 3 ngày (BRD FR-2): mở đúng ngày hôm nay (D6-B1), đủ 3 bữa, tổng calo + macro mỗi ngày (FR-2.3),
// buổi tập, `warnings` (NFR-9). Đổi món / đổi bài gọi API (FR-4.1, FR-4.2 — chuyển lên giai đoạn 6).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onCreatePlan});

  // Tạo plan mới từ hồ sơ hiện tại (bản nháp nếu có) — plan hết hạn, hồ sơ đã đổi, hoặc server báo 409.
  final VoidCallback onCreatePlan;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

const mealTypeLabels = {MealType.breakfast: 'Bữa sáng', MealType.lunch: 'Bữa trưa', MealType.dinner: 'Bữa tối'};

const muscleGroupLabels = {
  MuscleGroup.legs: 'Chân',
  MuscleGroup.chest: 'Ngực',
  MuscleGroup.back: 'Lưng',
  MuscleGroup.core: 'Cơ lõi',
  MuscleGroup.shoulders: 'Vai',
  MuscleGroup.arms: 'Tay',
  MuscleGroup.fullBody: 'Toàn thân',
  MuscleGroup.cardio: 'Tim mạch',
};

// Đơn vị theo BRD 6.2: piece hiển thị ×n, tbsp muỗng canh, tsp muỗng cà phê.
String ingredientAmount(Ingredient ingredient) {
  final amount = formatNumber(ingredient.amount);
  return switch (ingredient.unit) {
    IngredientUnit.g => '${amount}g',
    IngredientUnit.ml => '${amount}ml',
    IngredientUnit.piece => '×$amount',
    IngredientUnit.tbsp => '$amount muỗng canh',
    IngredientUnit.tsp => '$amount muỗng cà phê',
  };
}

// Số thập phân kiểu Việt: 24,8 — giống câu thông báo "BMI dưới 18,5".
String formatNumber(num value) =>
    value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1).replaceAll('.', ',');

class _DashboardScreenState extends State<DashboardScreen> {
  int? _selectedDay;
  // Món / động tác đang chờ server đổi — hiện vòng xoay đúng nút đó.
  String? _pendingId;

  Future<void> _swap(String id, Future<void> Function() action, String Function() done) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pendingId = id);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done()), behavior: SnackBarBehavior.floating));
    } on PlanOutdatedException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Tạo mới', onPressed: widget.onCreatePlan),
        ),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _pendingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final plan = plans.plan;
    final schedule = plans.schedule;
    if (plan == null || schedule == null) return const SizedBox.shrink();

    final today = plans.todayNumber ?? 1;
    final dayNumber = _selectedDay ?? today.clamp(1, 3);
    final day = plan.days[dayNumber - 1];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _header(plan, schedule, dayNumber, today),
          if (plans.hasPendingProfile)
            _Banner(
              icon: Icons.person_outline,
              text: 'Hồ sơ đã thay đổi. Tạo kế hoạch mới để áp dụng.',
              action: 'Tạo kế hoạch mới',
              onAction: plans.busy ? null : widget.onCreatePlan,
            )
          else if (today > 3)
            _Banner(
              icon: Icons.event_available,
              text: 'Kế hoạch 3 ngày đã hết. Tạo kế hoạch mới cho 3 ngày tới.',
              action: 'Tạo kế hoạch mới',
              onAction: plans.busy ? null : widget.onCreatePlan,
            )
          else if (today < 1)
            _Banner(icon: Icons.schedule, text: 'Kế hoạch bắt đầu từ ${vietnameseDate(schedule.startDate)}.'),
          if (plan.warnings.isNotEmpty) _Warnings(warnings: plan.warnings),
          const SizedBox(height: 12),
          _daySelector(schedule, dayNumber, today),
          const SizedBox(height: 12),
          _NutritionSummary(day: day, target: plan.dailyTarget),
          for (final meal in day.meals) _mealCard(plans, meal),
          _workoutCard(plans, day.workout),
        ],
      ),
    );
  }

  Widget _header(MealPlan plan, PlanSchedule schedule, int dayNumber, int today) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vietnameseDate(schedule.dateOfDay(dayNumber)),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              dayNumber == today ? 'Hôm nay là Ngày $dayNumber' : 'Ngày $dayNumber của kế hoạch',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ],
        ),
      ),
      if (plan.source == PlanSource.sample)
        const Tooltip(
          message: 'Máy chủ chưa dùng Gemini: thực đơn mẫu, lọc theo hạn chế phổ biến',
          child: Chip(
            label: Text('Thực đơn mẫu', style: TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
          ),
        ),
    ],
  );

  Widget _daySelector(PlanSchedule schedule, int dayNumber, int today) => SegmentedButton<int>(
    showSelectedIcon: false,
    segments: [
      for (var number = 1; number <= 3; number++)
        ButtonSegment(
          value: number,
          label: Text(
            number == today ? 'Ngày $number · hôm nay' : 'Ngày $number',
            style: const TextStyle(fontSize: 12),
          ),
        ),
    ],
    selected: {dayNumber},
    onSelectionChanged: (value) => setState(() => _selectedDay = value.first),
  );

  Widget _mealCard(PlanProvider plans, Meal meal) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                mealTypeLabels[meal.mealType]!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _SwapButton(
              label: 'Đổi món',
              pending: _pendingId == meal.mealId,
              onPressed: plans.busy
                  ? null
                  : () => _swap(meal.mealId, () => plans.swapMeal(meal.mealId), () {
                      final swapped = _findMeal(plans.plan, meal.mealId);
                      return 'Đã đổi ${mealTypeLabels[meal.mealType]!.toLowerCase()} sang: ${swapped?.name ?? ''}';
                    }),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          meal.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 2),
        Text(meal.portion, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Pill('${formatNumber(meal.calories)} kcal', AppColors.accent, AppColors.accentSoft),
            _Pill('Đạm ${formatNumber(meal.proteinG)}g', AppColors.primary, AppColors.primarySoft),
            _Pill('Tinh bột ${formatNumber(meal.carbsG)}g', AppColors.muted, AppColors.panel),
            _Pill('Béo ${formatNumber(meal.fatG)}g', AppColors.muted, AppColors.panel),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final ingredient in meal.ingredients)
              _Pill(
                '${ingredient.name} ${ingredientAmount(ingredient)}',
                AppColors.heading,
                Colors.white,
                bordered: true,
              ),
          ],
        ),
      ],
    ),
  );

  Widget _workoutCard(PlanProvider plans, Workout workout) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BÀI TẬP TẠI NHÀ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Text(
          workout.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            _Pill('${workout.durationMinutes} phút', AppColors.primary, AppColors.primarySoft),
            const _Pill('Không dụng cụ', AppColors.muted, AppColors.panel),
          ],
        ),
        const Divider(height: 20),
        for (final exercise in workout.exercises)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      Text(
                        '${exercise.sets} hiệp × ${exercise.repsOrDuration} · ${muscleGroupLabels[exercise.muscleGroup]}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _SwapButton(
                  label: 'Đổi bài',
                  pending: _pendingId == exercise.exerciseId,
                  onPressed: plans.busy
                      ? null
                      : () => _swap(exercise.exerciseId, () => plans.swapExercise(exercise.exerciseId), () {
                          final swapped = _findExercise(plans.plan, exercise.exerciseId);
                          return 'Đã đổi bài sang: ${swapped?.name ?? ''}';
                        }),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  static Meal? _findMeal(MealPlan? plan, String id) =>
      plan?.days.expand((day) => day.meals).where((meal) => meal.mealId == id).firstOrNull;

  static Exercise? _findExercise(MealPlan? plan, String id) =>
      plan?.days.expand((day) => day.workout.exercises).where((exercise) => exercise.exerciseId == id).firstOrNull;
}

class _NutritionSummary extends StatelessWidget {
  const _NutritionSummary({required this.day, required this.target});

  final PlanDay day;
  final DailyTarget target;

  @override
  Widget build(BuildContext context) {
    num total(num Function(Meal meal) pick) => day.meals.fold<num>(0, (sum, meal) => sum + pick(meal));
    final calories = total((meal) => meal.calories);
    // Tỉ lệ thật (có thể > 100%): MacroRing tự giới hạn cung vẽ, chữ phần trăm cho thấy phần vượt.
    double progress(num value, num goal) => goal <= 0 ? 0 : (value / goal).toDouble();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TỔNG TRONG NGÀY',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatNumber(calories),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                TextSpan(
                  text: ' / ${formatNumber(target.targetCalories)} kcal mục tiêu',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MacroRing(
                label: 'Đạm',
                value: '${formatNumber(total((meal) => meal.proteinG))}/${formatNumber(target.proteinG)}g',
                progress: progress(total((meal) => meal.proteinG), target.proteinG),
                ringColor: AppColors.primaryBright,
              ),
              MacroRing(
                label: 'Tinh bột',
                value: '${formatNumber(total((meal) => meal.carbsG))}/${formatNumber(target.carbsG)}g',
                progress: progress(total((meal) => meal.carbsG), target.carbsG),
                ringColor: const Color(0xFF3B82F6),
              ),
              MacroRing(
                label: 'Chất béo',
                value: '${formatNumber(total((meal) => meal.fatG))}/${formatNumber(target.fatG)}g',
                progress: progress(total((meal) => meal.fatG), target.fatG),
                ringColor: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings({required this.warnings});

  final List<String> warnings;

  @override
  // Material (không phải Container có màu nền) để ExpansionTile vẽ được hiệu ứng bấm.
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Material(
      color: AppColors.warningSoft,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.warningBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.info_outline, color: AppColors.warning),
          title: Text(
            'Lưu ý cho kế hoạch này (${warnings.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warning),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $warning', style: const TextStyle(fontSize: 12, color: AppColors.heading)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.primaryBright),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primaryDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.primaryDark)),
        ),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.label, required this.pending, required this.onPressed});

  final String label;
  final bool pending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: pending
        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.refresh, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.accent,
      side: const BorderSide(color: AppColors.accent),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color, this.background, {this.bordered = false});

  final String text;
  final Color color;
  final Color background;
  final bool bordered;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
      border: bordered ? Border.all(color: AppColors.border) : null,
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  );
}
