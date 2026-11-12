import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_sheet.dart';
import '../../widgets/ui_kit.dart';
import 'delete_account_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dailyReminder = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('TÀI KHOẢN'),
                    const SizedBox(height: 12),
                    _buildAccountSection(context),
                    const SizedBox(height: 32),
                    
                    _buildSectionTitle('TÙY CHỌN'),
                    const SizedBox(height: 12),
                    _buildOptionsSection(),
                    const SizedBox(height: 32),

                    _buildSectionTitle('DỮ LIỆU & QUYỀN RIÊNG TƯ'),
                    const SizedBox(height: 12),
                    _buildPrivacySection(),
                    const SizedBox(height: 32),

                    _buildSectionTitle('VÙNG NGUY HIỂM'),
                    const SizedBox(height: 12),
                    _buildDangerSection(context),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.ink, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cài đặt', style: AppTextStyles.h1.copyWith(fontSize: 28)),
                Text(
                  'Quản lý trải nghiệm SmartFit',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.label.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    final user = auth?.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SessionExpiredBanner(),
        if (auth?.error case final String err)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NoticePanel(message: err, error: true),
          ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (user != null) ...[
                _buildListTile(
                  icon: Icons.person_outline,
                  iconColor: const Color(0xFF22C55E),
                  title: user.name,
                  subtitle: user.email,
                  trailing: Text(
                    'Đã kết nối',
                    style: AppTextStyles.label.copyWith(
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border, indent: 64),
                _buildListTile(
                  key: const Key('settings-history-tile'),
                  icon: Icons.history_outlined,
                  iconColor: AppColors.primary,
                  title: 'Lịch sử kế hoạch',
                  subtitle: 'Xem lại các kế hoạch đã tạo trước đây',
                  trailing: const Icon(
                    Icons.arrow_forward,
                    color: AppColors.faint,
                    size: 20,
                  ),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.history),
                ),
                const Divider(height: 1, color: AppColors.border, indent: 64),
                _buildListTile(
                  key: const Key('settings-change-password-tile'),
                  icon: Icons.lock_reset_outlined,
                  iconColor: AppColors.primary,
                  title: 'Đổi mật khẩu',
                  subtitle: 'Cập nhật mật khẩu tài khoản của bạn',
                  trailing: const Icon(
                    Icons.arrow_forward,
                    color: AppColors.faint,
                    size: 20,
                  ),
                  onTap: auth?.busy == true
                      ? null
                      : () async {
                          final changed = await showChangePasswordSheet(context);
                          if (!changed || !context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đổi mật khẩu thành công!'),
                            ),
                          );
                        },
                ),
                const Divider(height: 1, color: AppColors.border, indent: 64),
                _buildListTile(
                  key: const Key('settings-signout-tile'),
                  icon: Icons.logout,
                  iconColor: AppColors.primary,
                  title: 'Đăng xuất',
                  subtitle: 'Đăng xuất khỏi thiết bị này',
                  trailing: const Icon(
                    Icons.arrow_forward,
                    color: AppColors.faint,
                    size: 20,
                  ),
                  onTap: auth?.busy == true
                      ? null
                      : () async {
                          await auth?.signOut();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã đăng xuất. Kế hoạch trên máy vẫn được giữ nguyên.',
                              ),
                            ),
                          );
                        },
                ),
              ] else ...[
                _buildListTile(
                  key: const Key('settings-signin-tile'),
                  icon: Icons.login,
                  iconColor: AppColors.primary,
                  title: 'Đăng nhập tài khoản',
                  subtitle: 'Đang dùng chế độ khách — nhấn để đăng nhập',
                  trailing: auth?.busy == true
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Đăng nhập',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                  onTap: auth?.busy == true
                      ? null
                      : () => startAuthSignIn(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.notifications_none,
            iconColor: AppColors.primary,
            title: 'Nhắc nhở hằng ngày',
            subtitle: 'Bữa ăn, tập luyện và phản hồi',
            trailing: Switch(
              value: _dailyReminder,
              onChanged: (val) => setState(() => _dailyReminder = val),
              activeTrackColor: const Color(0xFF22C55E),
            ),
          ),
          const Divider(height: 1, color: AppColors.border, indent: 64),
          _buildListTile(
            icon: Icons.scale,
            iconColor: AppColors.primary,
            title: 'Đơn vị',
            subtitle: 'kg, cm, kcal',
            trailing: Text('Hệ mét', style: AppTextStyles.label.copyWith(color: const Color(0xFF22C55E))),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.info_outline,
            iconColor: AppColors.primary,
            title: 'Trạng thái giao diện',
            subtitle: 'Loading, lỗi và dữ liệu trống',
            trailing: const Icon(Icons.arrow_forward, color: AppColors.faint, size: 20),
          ),
          const Divider(height: 1, color: AppColors.border, indent: 64),
          _buildListTile(
            icon: Icons.security,
            iconColor: AppColors.primary,
            title: 'Thông tin quyền riêng tư',
            subtitle: 'Cách SmartFit bảo vệ dữ liệu',
            trailing: const Icon(Icons.arrow_forward, color: AppColors.faint, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerSection(BuildContext context) {
    final isSignedIn = context.watch<AuthProvider?>()?.isSignedIn ?? false;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('settings-delete-account-button'),
            onPressed: !isSignedIn
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      constraints: const BoxConstraints(maxWidth: 430),
                      builder: (context) => const DeleteAccountSheet(),
                    );
                  },
            icon: Icon(
              Icons.delete_outline,
              color: isSignedIn ? AppColors.danger : AppColors.muted,
            ),
            label: Text(
              'Xóa tài khoản',
              style: AppTextStyles.h3.copyWith(
                color: isSignedIn ? AppColors.danger : AppColors.muted,
                fontSize: 18,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: isSignedIn
                  ? const Color(0xFFFEF2F2)
                  : AppColors.panel,
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: isSignedIn
                    ? const Color(0xFFFECACA)
                    : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isSignedIn
              ? 'Toàn bộ hồ sơ và lịch sử kế hoạch trên máy chủ sẽ bị xóa vĩnh viễn.'
              : 'Bạn đang ở chế độ khách; cần đăng nhập để quản lý tài khoản máy chủ.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildListTile({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title, style: AppTextStyles.h3.copyWith(fontSize: 16)),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
      trailing: trailing,
    );
  }
}


