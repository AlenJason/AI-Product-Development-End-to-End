import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/api/account.dart';
import '../../models/api/codes.dart';
import '../../models/api/meal_plan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../../services/api_exception.dart';
import '../../widgets/auth_sheet.dart';
import '../../widgets/plan_content.dart';
import '../../widgets/ui_kit.dart';

String formatHistoryDateTime(DateTime utc) {
  final local = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<PlanSummary> _plans = const [];
  bool _loading = false;
  String? _error;
  String? _loadedForUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider?>();
    final userId = auth?.user?.id;
    if (userId != _loadedForUserId) {
      _loadedForUserId = userId;
      if (userId != null) {
        unawaited(_loadHistory());
      } else {
        setState(() {
          _plans = const [];
          _loading = false;
          _error = null;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    final auth = context.read<AuthProvider?>();
    if (auth == null || !auth.isSignedIn || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await auth.fetchHistory();
      if (!mounted) return;
      setState(() {
        _plans = items;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được lịch sử kế hoạch. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    final currentPlanId = context.watch<PlanProvider?>()?.plan?.planId;
    final user = auth?.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch sử kế hoạch'),
        actions: [
          if (user != null)
            IconButton(
              key: const Key('history-refresh-button'),
              onPressed: _loading ? null : _loadHistory,
              icon: const Icon(Icons.refresh),
              tooltip: 'Tải lại',
            ),
        ],
      ),
      body: SafeArea(
        child: user == null
            ? ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const SessionExpiredBanner(),
                  SurfacePanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ToneIcon(icon: Icons.history_outlined, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          'Đăng nhập để xem lịch sử',
                          style: AppTextStyles.h3,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Các kế hoạch đã tạo khi đăng nhập sẽ được lưu trên máy chủ để bạn xem lại bất cứ lúc nào, kể cả trên thiết bị khác.',
                          style: AppTextStyles.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        GradientButton(
                          key: const Key('history-signin-button'),
                          label: 'Đăng nhập / Đăng ký',
                          icon: Icons.login,
                          onPressed: () => startAuthSignIn(context),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : _loading && _plans.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Đang tải lịch sử kế hoạch…'),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadHistory,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    if (_error case final String err) ...[
                      NoticePanel(message: err, error: true),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('history-retry-button'),
                        onPressed: _loading ? null : _loadHistory,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ] else if (_plans.isEmpty) ...[
                      SurfacePanel(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ToneIcon(
                              icon: Icons.calendar_today_outlined,
                              size: 56,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có kế hoạch nào được lưu',
                              style: AppTextStyles.h3,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Hãy tạo một kế hoạch mới sau khi đăng nhập — hệ thống sẽ tự động lưu lại vào lịch sử tài khoản của bạn.',
                              style: AppTextStyles.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            GradientButton(
                              key: const Key('history-create-plan-button'),
                              label: 'Tạo kế hoạch mới',
                              icon: Icons.auto_awesome,
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.onboardingBasicInfo,
                                arguments: context
                                    .read<PlanProvider?>()
                                    ?.editableProfile,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        '${_plans.length} kế hoạch đã lưu cho ${user.email}',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      for (final summary in _plans) ...[
                        _HistorySummaryCard(
                          summary: summary,
                          isCurrent: summary.id == currentPlanId,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  HistoryDetailScreen(summary: summary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _HistorySummaryCard extends StatelessWidget {
  const _HistorySummaryCard({
    required this.summary,
    required this.isCurrent,
    required this.onTap,
  });

  final PlanSummary summary;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrent ? AppColors.primary : AppColors.border,
          width: isCurrent ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('history-item-${summary.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const ToneIcon(icon: Icons.restaurant_menu_outlined, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${number(summary.targetCalories)} kcal/ngày',
                            style: AppTextStyles.h4,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Đang mở',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatHistoryDateTime(summary.createdAt),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({super.key, required this.summary});

  final PlanSummary summary;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  MealPlan? _plan;
  bool _loading = true;
  String? _error;
  int _selectedDay = 1;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDetail());
  }

  Future<void> _loadDetail() async {
    final auth = context.read<AuthProvider?>();
    if (auth == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await auth.fetchHistoryPlan(widget.summary.id);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        if (plan.days.isNotEmpty) _selectedDay = plan.days.first.dayNumber;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được chi tiết kế hoạch. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${number(widget.summary.targetCalories)} kcal/ngày'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Đang tải chi tiết kế hoạch…'),
                  ],
                ),
              )
            : _error != null || plan == null
            ? Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NoticePanel(
                      message: _error ?? 'Không tìm thấy kế hoạch.',
                      error: true,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('history-detail-retry-button'),
                      onPressed: _loadDetail,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            : _buildPlanBody(plan),
      ),
    );
  }

  Widget _buildPlanBody(MealPlan plan) {
    final matches = plan.days.where((d) => d.dayNumber == _selectedDay);
    final day = matches.isEmpty ? plan.days.first : matches.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        NoticePanel(
          message:
              'Lịch sử đã lưu (${formatHistoryDateTime(widget.summary.createdAt)}) · Chỉ xem.',
        ),
        const SizedBox(height: 14),
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
                        child: Text('Ngày ${entry.dayNumber}'),
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
                          setState(() => _selectedDay = entry.dayNumber),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IgnorePointer(child: DayContent(day: day, target: plan.dailyTarget)),
        const SizedBox(height: 16),
        PlanNotice(plan: plan),
        if (plan.groceryList.isNotEmpty) ...[
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: const Text('Danh sách đi chợ của kế hoạch này'),
              children: [
                for (final group in plan.groceryList) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        switch (group.category) {
                          IngredientCategory.protein => 'Đạm',
                          IngredientCategory.produce => 'Rau củ quả',
                          IngredientCategory.pantry => 'Gạo, bún & gia vị',
                        },
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  for (final item in group.items)
                    ListTile(
                      dense: true,
                      title: Text(item.name),
                      trailing: Text(
                        item.quantity,
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
