import 'package:flutter/material.dart';
import '../models/meal_plan.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onOpenFeedback;

  const DashboardScreen({
    super.key,
    required this.onOpenFeedback,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedDay = 0; // 0: S1, 1: S2, 2: S3, 3: S4, 4: S5

  // Danh sách các lựa chọn thay thế món Việt tương đương macro (Interactive Swap)
  final Map<String, List<MealItem>> _alternativeDishes = {
    'BỮA TRƯA': [
      const MealItem(
        period: 'BỮA TRƯA',
        name: 'Cơm trắng + Ức gà xào nấm',
        calories: 490,
        protein: 35,
        ingredients: ['Cơm trắng', 'Ức gà 150g', 'Nấm rơm', 'Tỏi'],
      ),
      const MealItem(
        period: 'BỮA TRƯA',
        name: 'Cơm gạo lứt + Bò xào đậu cô ve',
        calories: 480,
        protein: 32,
        ingredients: ['Cơm gạo lứt 140g', 'Thịt bò 120g', 'Đậu cô ve', 'Dầu mè'],
      ),
      const MealItem(
        period: 'BỮA TRƯA',
        name: 'Cơm + Thịt nạc ram cháy cạnh',
        calories: 510,
        protein: 30,
        ingredients: ['Cơm trắng', 'Thịt nạc heo 140g', 'Dưa cải chua', 'Rau luộc'],
      ),
    ],
    'BỮA TỐI': [
      const MealItem(
        period: 'BỮA TỐI',
        name: 'Cá hấp hành gừng',
        calories: 320,
        protein: 28,
        ingredients: ['Cá trắm 200g', 'Hành lá', 'Gừng tươi', 'Nước tương'],
      ),
      const MealItem(
        period: 'BỮA TỐI',
        name: 'Canh chua cá lóc + Rau muống',
        calories: 310,
        protein: 26,
        ingredients: ['Cá lóc 160g', 'Cà chua', 'Dứa', 'Bạc hà', 'Rau muống'],
      ),
      const MealItem(
        period: 'BỮA TỐI',
        name: 'Tôm rim tỏi + Bông cải xanh luộc',
        calories: 330,
        protein: 29,
        ingredients: ['Tôm sú 150g', 'Bông cải xanh 120g', 'Cà rốt', 'Tỏi'],
      ),
    ],
  };

  late List<MealItem> _currentMeals;

  // Danh sách bài tập tại nhà
  final List<WorkoutExercise> _workoutExercises = [
    const WorkoutExercise(
      icon: '🦵',
      name: 'Squat tay không',
      detail: '3 sets × 15 reps',
    ),
    const WorkoutExercise(
      icon: '💪',
      name: 'Chống đẩy khuỷu gối',
      detail: '3 sets × 12 reps',
    ),
    const WorkoutExercise(
      icon: '🧘',
      name: 'Plank',
      detail: '3 sets × 30 giây',
    ),
  ];

  final List<List<WorkoutExercise>> _alternativeExercises = [
    [
      const WorkoutExercise(icon: '🦵', name: 'Squat tay không', detail: '3 sets × 15 reps'),
      const WorkoutExercise(icon: '🚶', name: 'Lunge bước tấn', detail: '3 sets × 12 reps/chân'),
      const WorkoutExercise(icon: '🪑', name: 'Wall Sit tựa tường', detail: '3 sets × 45 giây'),
    ],
    [
      const WorkoutExercise(icon: '💪', name: 'Chống đẩy khuỷu gối', detail: '3 sets × 12 reps'),
      const WorkoutExercise(icon: '🧱', name: 'Chống đẩy vào tường', detail: '3 sets × 15 reps'),
      const WorkoutExercise(icon: '🪑', name: 'Dips bắp tay sau ghế', detail: '3 sets × 10 reps'),
    ],
    [
      const WorkoutExercise(icon: '🧘', name: 'Plank', detail: '3 sets × 30 giây'),
      const WorkoutExercise(icon: '🧗', name: 'Mountain Climber', detail: '3 sets × 20 reps'),
      const WorkoutExercise(icon: '🚴', name: 'Gập bụng đạp xe', detail: '3 sets × 15 reps'),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _currentMeals = [
      _alternativeDishes['BỮA TRƯA']![0],
      _alternativeDishes['BỮA TỐI']![0],
    ];
  }

  void _swapMeal(int index) {
    final current = _currentMeals[index];
    final alternatives = _alternativeDishes[current.period] ?? [];
    if (alternatives.isEmpty) return;

    final currentIndex = alternatives.indexWhere((m) => m.name == current.name);
    final nextIndex = (currentIndex + 1) % alternatives.length;

    setState(() {
      _currentMeals[index] = alternatives[nextIndex];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã đổi ${current.period.toLowerCase()} sang: ${_currentMeals[index].name}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _swapExercise(int index) {
    final alternatives = _alternativeExercises[index];
    final current = _workoutExercises[index];
    final currentIndex = alternatives.indexWhere((e) => e.name == current.name);
    final nextIndex = (currentIndex + 1) % alternatives.length;

    setState(() {
      _workoutExercises[index] = alternatives[nextIndex];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã đổi bài sang: ${_workoutExercises[index].name}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16, right: 36, top: 12, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  ..._currentMeals.asMap().entries.map((entry) {
                    return _buildMealCard(entry.value, entry.key);
                  }),
                  const SizedBox(height: 12),
                  _buildWorkoutSection(),
                  const SizedBox(height: 16),
                  _buildFeedbackButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Vertical day indicator rail on the right edge (like in Figma)
            Positioned(
              right: 8,
              top: 52,
              child: _buildVerticalDayStepper(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thứ Ba, 15/9/2026',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Chào bạn, hôm nay là\nNgày 1! 👋',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('💧', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text(
                '3 ngày',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFF00875A),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'T',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDayStepper() {
    final days = ['S1', 'S2', 'S3', 'S4', 'S5'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(days.length, (i) {
          final isSelected = _selectedDay == i;
          return InkWell(
            onTap: () {
              setState(() {
                _selectedDay = i;
              });
            },
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00875A) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF00875A) : const Color(0xFFCBD5E1),
                  width: 0.8,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                days[i],
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMealCard(MealItem meal, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                meal.period,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              InkWell(
                onTap: () => _swapMeal(index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF97316), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 12, color: Color(0xFFEA580C)),
                      SizedBox(width: 3),
                      Text(
                        'Đổi món',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            meal.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildNutrientChip('${meal.calories} kcal', const Color(0xFFFFF7ED), const Color(0xFFEA580C)),
              const SizedBox(width: 6),
              _buildNutrientChip('${meal.protein}g Protein', const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: meal.ingredients.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientChip(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textCol,
        ),
      ),
    );
  }

  Widget _buildWorkoutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        const Row(
          children: [
            Text('🏃', style: TextStyle(fontSize: 15)),
            SizedBox(width: 6),
            Text(
              'Bài tập tại nhà',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Workout container matching Figma: Green header + white body
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Top green banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                color: const Color(0xFF00875A), // Figma primary green
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Vận động toàn thân (20 phút)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _buildTag('Dễ'),
                    const SizedBox(width: 6),
                    _buildTag('Không tạ'),
                  ],
                ),
              ),
              // List of 3 exercises
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _workoutExercises.length,
                separatorBuilder: (context, i) => const Divider(
                  height: 1,
                  thickness: 0.6,
                  indent: 14,
                  endIndent: 14,
                  color: Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, index) {
                  final ex = _workoutExercises[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Text(ex.icon, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ex.detail,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _swapExercise(index),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                            ),
                            child: const Text(
                              'Đổi bài',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFeedbackButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: widget.onOpenFeedback,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEA580C), // Figma Orange button
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📝', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Text(
              'Đánh giá cuối ngày',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
