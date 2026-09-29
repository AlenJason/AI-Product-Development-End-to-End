import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/api/profile.dart';
import '../theme/app_colors.dart';
import '../widgets/profile_form.dart';

// Onboarding 3 bước (D6-B2): cơ thể → mục tiêu & vận động → hạn chế. Nút luôn ở đáy (màn hình nhỏ không đẩy nút
// xuống dưới mép), nút Back của hệ thống quay lại bước trước. [initial] điền sẵn khi quay lại sửa hồ sơ.
// Bước và dữ liệu đang nhập được lưu tạm (state restoration, PLAN D8): Back ở bước 1 chỉ đưa app xuống nền
// (MainActivity), hệ thống tắt app ở nền thì mở lại còn nguyên; force-quit mới mất.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.initial, required this.onSubmit});

  final Profile? initial;
  final ValueChanged<Profile> onSubmit;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with RestorationMixin {
  static const _titles = ['Thông tin cơ thể', 'Mục tiêu & vận động', 'Hạn chế & sức khoẻ'];

  late final ProfileFormController _form = ProfileFormController(widget.initial)..addListener(_remember);
  final _step = RestorableInt(0);
  final _typed = RestorableStringN(null);

  @override
  String get restorationId => 'onboarding';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_step, 'step');
    registerForRestoration(_typed, 'form');
    final saved = _typed.value;
    if (saved != null) _form.restoreSnapshot(jsonDecode(saved) as Map<String, Object?>);
  }

  void _remember() => _typed.value = jsonEncode(_form.toSnapshot());

  @override
  void dispose() {
    _form.dispose();
    _step.dispose();
    _typed.dispose();
    super.dispose();
  }

  bool get _stepValid => switch (_step.value) {
    0 => _form.bodyValid,
    1 => _form.goalValid,
    _ => _form.restrictionsValid,
  };

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step.value < 2) {
      setState(() => _step.value++);
    } else {
      widget.onSubmit(_form.toProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step.value == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step.value--);
      },
      child: Scaffold(
        backgroundColor: AppColors.page,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SmartFit AI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Thiết lập mục tiêu 3 ngày',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Bước ${_step.value + 1}/3 · ${_titles[_step.value]}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_step.value + 1) / 3,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        color: AppColors.primaryBright,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: switch (_step.value) {
                    0 => BodySection(form: _form),
                    1 => GoalSection(form: _form),
                    _ => RestrictionsSection(form: _form),
                  },
                ),
              ),
              ListenableBuilder(
                listenable: _form,
                builder: (context, _) => Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      if (_step.value > 0) ...[
                        OutlinedButton(
                          onPressed: () => setState(() => _step.value--),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Quay lại'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _stepValid ? _next : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBright,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text(
                            _step.value < 2 ? 'Tiếp tục' : 'Tạo kế hoạch 3 ngày',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
