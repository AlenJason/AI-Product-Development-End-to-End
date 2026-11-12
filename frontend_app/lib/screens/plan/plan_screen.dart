import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/plan_content.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/plan_status.dart';
import '../../models/plan_schedule.dart';
import '../../models/feedback_state.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, this.archivedCycle});
  final PlanCycle? archivedCycle;
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int? _selected;
  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>(),
        plan = widget.archivedCycle?.plan ?? plans.plan;
    final schedule = widget.archivedCycle?.schedule ?? plans.schedule;
    if (plan == null || plan.days.isEmpty) {
      return const SafeArea(child: PlanEmpty());
    }
    final matches = plan.days.where(
      (d) => d.dayNumber == (_selected ?? plans.todayNumber),
    );
    final day = matches.isEmpty ? plan.days.first : matches.first;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        children: [
          ScreenHeading(
            title: 'Kế hoạch ${plan.days.length} ngày',
            subtitle: 'Dinh dưỡng và vận động dành cho bạn',
          ),
          const SizedBox(height: 22),
          if (widget.archivedCycle == null)
            PlanStatus(dayNumber: day.dayNumber)
          else ...[
            const NoticePanel(
              message: 'Lịch sử chu kỳ · Chỉ xem dữ liệu đã lưu.',
            ),
            FeedbackEntry(dayNumber: day.dayNumber, planId: plan.planId),
          ],
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EFEB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                for (final entry in plan.days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Ngày ${entry.dayNumber}'),
                              if (schedule != null)
                                Text(
                                  vietnameseDate(
                                    schedule.dateOfDay(entry.dayNumber),
                                  ),
                                  style: const TextStyle(fontSize: 9),
                                ),
                            ],
                          ),
                        ),
                        selected: entry.dayNumber == day.dayNumber,
                        selectedColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: entry.dayNumber == day.dayNumber
                              ? AppColors.primaryDark
                              : AppColors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                        onSelected: (_) =>
                            setState(() => _selected = entry.dayNumber),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IgnorePointer(
            ignoring: widget.archivedCycle != null,
            child: DayContent(day: day, target: plan.dailyTarget),
          ),
          const SizedBox(height: 18),
          PlanNotice(plan: plan),
          if (widget.archivedCycle == null && plans.history.isNotEmpty)
            SurfacePanel(
              child: ExpansionTile(
                title: const Text('Lịch sử chu kỳ'),
                children: [
                  for (final cycle in plans.history)
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Kế hoạch đã lưu'),
                            ),
                            body: PlanScreen(archivedCycle: cycle),
                          ),
                        ),
                      ),
                      child: Text(
                        'Chu kỳ ${vietnameseDate(cycle.schedule.dateOfDay(1))} – ${vietnameseDate(cycle.schedule.dateOfDay(3))}',
                      ),
                    ),
                ],
              ),
            ),
          if (widget.archivedCycle == null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('plan-history-button'),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.history),
              icon: const Icon(Icons.history_outlined),
              label: const Text('Xem lịch sử kế hoạch đã lưu'),
            ),
          ],
        ],
      ),
    );
  }
}
