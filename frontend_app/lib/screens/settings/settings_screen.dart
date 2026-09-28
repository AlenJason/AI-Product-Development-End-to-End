import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cài đặt', style: AppTextStyles.h1.copyWith(fontSize: 28)),
              Text('Quản lý trải nghiệm SmartFit', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted)),
            ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.g_mobiledata,
            iconColor: const Color(0xFF22C55E),
            title: 'Tài khoản Google',
            subtitle: 'minh.nguyen@gmail.com',
            trailing: Text('Đã kết nối', style: AppTextStyles.label.copyWith(color: const Color(0xFF22C55E))),
          ),
          const Divider(height: 1, color: AppColors.border, indent: 64),
          _buildListTile(
            icon: Icons.logout,
            iconColor: AppColors.primary,
            title: 'Đăng xuất',
            subtitle: 'Đăng xuất khỏi thiết bị này',
            trailing: const Icon(Icons.arrow_forward, color: AppColors.faint, size: 20),
            onTap: () {
              // Reset app flow to welcome
              Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
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
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => const DeleteAccountSheet(),
              );
            },
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            label: Text('Xóa tài khoản', style: AppTextStyles.h3.copyWith(color: AppColors.danger, fontSize: 18)),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFFFECACA)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Toàn bộ hồ sơ và lịch sử kế hoạch sẽ bị xóa vĩnh viễn.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
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


