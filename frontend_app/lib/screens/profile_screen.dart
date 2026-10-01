import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/codes.dart';
import '../models/api/profile.dart';
import '../providers/auth_provider.dart';
import '../providers/plan_provider.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart' show formatNumber;
import '../widgets/login_panel.dart';
import '../widgets/profile_form.dart';

// Tab "Cá nhân" (BRD FR-1.6): xem và sửa hồ sơ bất cứ lúc nào. Sửa xong lưu thành bản nháp — plan đang có vẫn dùng
// hồ sơ cũ (đổi món/feedback không bị 409) — và gợi ý tạo lại plan. Mục "Tài khoản" (FR-6, giai đoạn 8): đăng xuất,
// xoá tài khoản; chưa đăng nhập → dải nhắc (quyết định Q6).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onCreatePlan, required this.onSignIn});

  final ValueChanged<Profile> onCreatePlan;
  final VoidCallback onSignIn;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with RestorationMixin {
  // Chỉ có khi đang sửa — tạo lúc bấm "Sửa hồ sơ" để luôn điền đúng hồ sơ mới nhất.
  ProfileFormController? _form;
  // Phần đang sửa dở, lưu tạm như Onboarding (PLAN D8); null = không sửa.
  final _typed = RestorableStringN(null);
  // Đang chờ server xoá tài khoản.
  bool _deleting = false;

  bool get _editing => _form != null;

  @override
  String get restorationId => 'profile';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_typed, 'editing');
    final saved = _typed.value;
    if (saved != null && _form == null) _form = _newForm()..restoreSnapshot(jsonDecode(saved) as Map<String, Object?>);
  }

  ProfileFormController _newForm() =>
      ProfileFormController(context.read<PlanProvider>().editableProfile)..addListener(_remember);

  void _remember() {
    final form = _form;
    if (form != null) _typed.value = jsonEncode(form.toSnapshot());
  }

  @override
  void dispose() {
    _form?.dispose();
    _typed.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _form = _newForm());
    _remember();
  }

  // Widget của form còn dùng controller tới hết frame này — huỷ sau frame.
  void _stopEditing() {
    final form = _form;
    setState(() => _form = null);
    _typed.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => form?.dispose());
  }

  Future<void> _save(ProfileFormController form) async {
    FocusScope.of(context).unfocus();
    await context.read<PlanProvider>().saveDraft(form.toProfile());
    if (mounted) _stopEditing();
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<AuthProvider>().signOut();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Đã đăng xuất. Kế hoạch trên máy này vẫn giữ.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // FR-6.4: hỏi lại, nói rõ mất gì và giữ gì.
  Future<void> _deleteAccount() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá tài khoản?'),
        content: const Text(
          'Tài khoản và toàn bộ lịch sử kế hoạch trên máy chủ sẽ bị xoá vĩnh viễn. '
          'Kế hoạch đang dùng trên máy này vẫn giữ, bạn dùng tiếp như khách.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xoá vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    String message;
    try {
      await auth.deleteAccount();
      message = 'Đã xoá tài khoản và lịch sử kế hoạch.';
    } on ApiException catch (error) {
      message = error.message;
    }
    if (mounted) setState(() => _deleting = false);
    messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = plans.editableProfile;
    if (profile == null) return const SizedBox.shrink();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'Hồ sơ của bạn',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chỉ lưu trên máy này, không gửi lưu ở máy chủ.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (!auth.isSignedIn && !_editing) GuestBanner(onSignIn: widget.onSignIn),
          if (plans.hasPendingProfile && !_editing)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryBright),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Hồ sơ đã thay đổi. Tạo kế hoạch mới để áp dụng.',
                      style: TextStyle(fontSize: 13, color: AppColors.primaryDark),
                    ),
                  ),
                  TextButton(
                    onPressed: plans.busy ? null : () => widget.onCreatePlan(plans.draft!),
                    child: const Text('Tạo kế hoạch mới'),
                  ),
                ],
              ),
            ),
          if (_form case final form?) ..._editor(form) else ..._summary(plans, profile),
          if (auth.user case final user? when !_editing) _account(user.name, user.email),
        ],
      ),
    );
  }

  List<Widget> _summary(PlanProvider plans, Profile profile) {
    final target = plans.plan?.dailyTarget;
    final restrictions = profile.restrictions;
    String orNone(String text) => text.isEmpty ? 'Không có' : text;
    return [
      const SizedBox(height: 12),
      _SummaryCard(
        rows: [
          ('Tuổi', '${profile.age}'),
          ('Giới tính', profile.gender == Gender.female ? 'Nữ' : 'Nam'),
          if (profile.pregnantOrBreastfeeding) ('Mang thai / cho con bú', 'Có'),
          ('Chiều cao', '${formatNumber(profile.heightCm)} cm'),
          ('Cân nặng', '${formatNumber(profile.weightKg)} kg'),
          ('Vận động', activityLabel(profile.activityLevel)),
          ('Mục tiêu', goalLabel(profile.goal)),
          if (target != null && !plans.hasPendingProfile) ...[
            ('BMI', formatNumber(target.bmi)),
            ('Calo mục tiêu', '${target.targetCalories} kcal/ngày'),
          ],
          ('Dị ứng', orNone(restrictions.allergies)),
          ('Chấn thương', orNone(restrictions.injuries)),
          ('Bệnh nền', orNone(restrictions.healthConditions)),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _startEditing,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Sửa hồ sơ'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ];
  }

  Widget _account(String name, String email) => Container(
    margin: const EdgeInsets.only(top: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TÀI KHOẢN',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        Text(email, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _deleting ? null : _signOut,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Đăng xuất'),
            ),
            TextButton(
              onPressed: _deleting ? null : _deleteAccount,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: _deleting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Xoá tài khoản'),
            ),
          ],
        ),
      ],
    ),
  );

  List<Widget> _editor(ProfileFormController form) => [
    BodySection(form: form),
    GoalSection(form: form),
    const SectionTitle('Hạn chế & sức khoẻ'),
    RestrictionsSection(form: form),
    const SizedBox(height: 16),
    ListenableBuilder(
      listenable: form,
      builder: (context, _) => Row(
        children: [
          TextButton(onPressed: _stopEditing, child: const Text('Huỷ')),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: form.valid ? () => _save(form) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Lưu hồ sơ', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
  ];
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
