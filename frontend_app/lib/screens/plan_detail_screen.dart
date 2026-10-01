import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/meal_plan.dart';
import '../providers/history_provider.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart' show PlanDayView, PlanWarnings;
import 'history_screen.dart' show historyTime;

// Route khôi phục được (#35): tham số là {id, created_at} (chuỗi) — plan tải lại từ server khi mở lại.
@pragma('vm:entry-point')
Route<void> planDetailRoute(BuildContext context, Object? arguments) {
  final args = (arguments! as Map).cast<String, Object?>();
  return MaterialPageRoute<void>(
    builder: (context) =>
        PlanDetailScreen(id: args['id']! as String, createdAt: DateTime.parse(args['created_at']! as String)),
  );
}

// Xem lại một plan cũ (FR-7.2): chỉ xem. Không "dùng lại" làm plan hiện tại — lịch sử không lưu hồ sơ đã tạo ra plan
// (#12), đổi món/feedback sẽ bị 409 (P10 giai đoạn 8).
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({super.key, required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> with RestorationMixin {
  late Future<MealPlan> _plan;
  final _day = RestorableInt(1);

  @override
  String get restorationId => 'plan_detail';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) => registerForRestoration(_day, 'day');

  @override
  void initState() {
    super.initState();
    _plan = context.read<HistoryProvider>().plan(widget.id);
  }

  @override
  void dispose() {
    _day.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FA),
    appBar: AppBar(
      title: Text(historyTime(widget.createdAt), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: SafeArea(
      child: FutureBuilder<MealPlan>(
        future: _plan,
        builder: (context, snapshot) {
          final plan = snapshot.data;
          if (snapshot.hasError) return _failed(snapshot.error);
          if (plan == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryBright));
          }
          final day = plan.days[_day.value - 1];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const Text(
                'Chỉ xem lại — kế hoạch cũ không đổi món, đổi bài hay gửi đánh giá được.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (plan.warnings.isNotEmpty) PlanWarnings(warnings: plan.warnings),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (var number = 1; number <= 3; number++) ButtonSegment(value: number, label: Text('Ngày $number')),
                ],
                selected: {_day.value},
                onSelectionChanged: (value) => setState(() => _day.value = value.first),
              ),
              PlanDayView(day: day, target: plan.dailyTarget),
            ],
          );
        },
      ),
    ),
  );

  Widget _failed(Object? error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.warning),
          const SizedBox(height: 12),
          Text(
            error is NotFoundException
                ? 'Kế hoạch này không còn trong lịch sử.'
                : error is ApiException
                ? error.message
                : const ServerException().message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.heading),
          ),
          const SizedBox(height: 12),
          if (error is NotFoundException || error is UnauthorizedException)
            TextButton(
              onPressed: () {
                // Plan đã bị xoá trên server → danh sách đang hiện cũng đã cũ.
                if (error is NotFoundException) context.read<HistoryProvider>().load();
                Navigator.pop(context);
              },
              child: const Text('Về danh sách'),
            )
          else
            TextButton(
              onPressed: () => setState(() {
                _plan = context.read<HistoryProvider>().plan(widget.id);
              }),
              child: const Text('Thử lại'),
            ),
        ],
      ),
    ),
  );
}
