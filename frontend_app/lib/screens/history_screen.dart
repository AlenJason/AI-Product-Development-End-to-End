import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/account.dart';
import '../models/plan_schedule.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/plan_provider.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import '../widgets/login_panel.dart';
import 'dashboard_screen.dart' show formatNumber;
import 'plan_detail_screen.dart';

// Tab "Lịch sử" (BRD FR-7.2, PLAN 8.3): các plan đã tạo khi đăng nhập, mới nhất trước; bấm để xem lại (chỉ xem).
// Tải lại mỗi lần mở tab và khi kéo xuống. Chưa đăng nhập → lời mời đăng nhập (quyết định Q6).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

// "Thứ Tư, 30/9/2026 · 14:05" theo giờ trên máy (server trả UTC).
String historyTime(DateTime createdAt) {
  final local = createdAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${vietnameseDate(local)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Lần tải đã hẹn sau frame này — tránh gọi load() (notifyListeners) giữa lúc đang dựng.
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  void _scheduleLoad() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted) context.read<HistoryProvider>().load();
    });
  }

  void _open(PlanSummary summary) => Navigator.of(
    context,
  ).restorablePush(planDetailRoute, arguments: {'id': summary.id, 'created_at': summary.createdAt.toIso8601String()});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final history = context.watch<HistoryProvider>();
    // Vừa đăng nhập khi đang mở tab → tải danh sách của tài khoản đó.
    if (auth.isSignedIn && history.items == null && history.error == null && !history.loading) _scheduleLoad();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: history.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Text(
              'Lịch sử kế hoạch',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kế hoạch tạo khi đã đăng nhập được lưu trên máy chủ, xem lại trên mọi thiết bị.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (!auth.isSignedIn)
              GuestBanner(onSignIn: widget.onSignIn, expired: history.error is UnauthorizedException)
            else
              ..._signedIn(context, history),
          ],
        ),
      ),
    );
  }

  List<Widget> _signedIn(BuildContext context, HistoryProvider history) {
    final items = history.items;
    final error = history.error;
    final currentId = context.watch<PlanProvider>().plan?.planId;
    return [
      // Plan đang dùng tạo lúc chưa đăng nhập (hoặc bằng tài khoản khác) không bao giờ vào lịch sử (quyết định Q4).
      if (items != null && currentId != null && !items.any((item) => item.id == currentId))
        const _Note(
          icon: Icons.info_outline,
          text:
              'Kế hoạch đang dùng chưa có trong lịch sử của tài khoản này (được tạo lúc chưa đăng nhập). '
              'Tạo kế hoạch mới để lưu vào lịch sử.',
        ),
      if (error != null) ...[
        _Note(icon: Icons.cloud_off_rounded, text: error.message),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: history.load, child: const Text('Thử lại')),
        ),
      ],
      if (items == null && error == null)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: AppColors.primaryBright)),
        )
      else if (items != null && items.isEmpty)
        const _Note(icon: Icons.history, text: 'Chưa có kế hoạch nào. Kế hoạch bạn tạo từ giờ sẽ được lưu ở đây.')
      else if (items != null)
        for (final item in items) _item(item, current: item.id == currentId),
    ];
  }

  Widget _item(PlanSummary item, {required bool current}) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: current ? AppColors.primaryBright : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _open(item),
        leading: const Icon(Icons.event_note, color: AppColors.primary),
        title: Text(
          historyTime(item.createdAt),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        subtitle: Text(
          'Mục tiêu ${formatNumber(item.targetCalories)} kcal/ngày',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  'Đang dùng',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                ),
              ),
            const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.heading)),
        ),
      ],
    ),
  );
}
