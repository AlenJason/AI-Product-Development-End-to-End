import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/common/primary_button.dart';
import '../../providers/mock_data_provider.dart';
import 'adaptive_result_screen.dart';

class DailyFeedbackScreen extends StatefulWidget {
  const DailyFeedbackScreen({super.key});

  @override
  State<DailyFeedbackScreen> createState() => _DailyFeedbackScreenState();
}

class _DailyFeedbackScreenState extends State<DailyFeedbackScreen> {
  String _workoutIntensity = 'Vừa sức'; // Default selected
  final Set<String> _bodyStatus = {'Bình thường'};
  String _mealStatus = 'Đúng thực đơn';

  final List<Map<String, String>> _intensityOptions = [
    {'title': 'Nhẹ nhàng', 'sub': 'Có thể tập thêm'},
    {'title': 'Vừa sức', 'sub': 'Đúng khả năng'},
    {'title': 'Rất mệt', 'sub': 'Cần giảm nhẹ'},
  ];

  final List<Map<String, dynamic>> _statusOptions = [
    {'label': 'Bình thường', 'type': 'normal'},
    {'label': 'Căng mỏi cơ', 'type': 'warning'},
    {'label': 'Đau khớp', 'type': 'warning'},
    {'label': 'Uể oải / thiếu ngủ', 'type': 'warning'},
    {'label': 'Chóng mặt', 'type': 'danger'},
    {'label': 'Khó thở bất thường', 'type': 'danger'},
    {'label': 'Đau ngực', 'type': 'danger'},
  ];

  final List<String> _mealOptions = [
    'Đúng thực đơn',
    'Ăn nhiều hơn',
    'Ăn ít hơn / bỏ bữa',
  ];

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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text('Bạn cảm thấy hôm nay thế nào?', style: AppTextStyles.h1.copyWith(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(
                      'Phản hồi giúp SmartFit điều chỉnh kế hoạch ngày mai.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 32),
                    
                    _buildSectionHeader('1', 'Cường độ buổi tập'),
                    const SizedBox(height: 16),
                    _buildIntensityCards(),
                    const SizedBox(height: 32),

                    _buildSectionHeader('2', 'Tình trạng cơ thể'),
                    const SizedBox(height: 16),
                    _buildBodyStatusChips(),
                    const SizedBox(height: 32),

                    _buildSectionHeader('3', 'Ăn uống hôm nay'),
                    const SizedBox(height: 16),
                    _buildMealRadioGroup(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
            _buildBottomBar(context),
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
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String number, String title) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(number, style: AppTextStyles.label.copyWith(color: const Color(0xFF16A34A))),
        ),
        const SizedBox(width: 12),
        Text(title, style: AppTextStyles.h3),
      ],
    );
  }

  Widget _buildIntensityCards() {
    return Row(
      children: _intensityOptions.map((opt) {
        final isSelected = _workoutIntensity == opt['title'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _workoutIntensity = opt['title']!),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF22C55E) : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isSelected ? Icons.sentiment_satisfied_alt : Icons.remove,
                    color: isSelected ? AppColors.ink : AppColors.muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    opt['title']!,
                    style: AppTextStyles.h3.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opt['sub']!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBodyStatusChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: _statusOptions.map((opt) {
        final label = opt['label'] as String;
        final type = opt['type'] as String;
        final isSelected = _bodyStatus.contains(label);
        
        Color borderColor = AppColors.border;
        Color textColor = AppColors.ink;
        
        if (isSelected) {
          borderColor = const Color(0xFF22C55E);
          textColor = const Color(0xFF16A34A);
        } else if (type == 'danger') {
          borderColor = const Color(0xFFFDE68A); // Yellow/Orange warning
          textColor = const Color(0xFFB45309);
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              if (label == 'Bình thường') {
                _bodyStatus.clear();
                _bodyStatus.add(label);
              } else {
                _bodyStatus.remove('Bình thường');
                if (isSelected) {
                  _bodyStatus.remove(label);
                  if (_bodyStatus.isEmpty) _bodyStatus.add('Bình thường');
                } else {
                  _bodyStatus.add(label);
                }
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check, color: Color(0xFF16A34A), size: 16),
                  const SizedBox(width: 8),
                ],
                Text(label, style: AppTextStyles.bodyMedium.copyWith(color: textColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMealRadioGroup() {
    return Column(
      children: _mealOptions.map((opt) {
        final isSelected = _mealStatus == opt;
        return GestureDetector(
          onTap: () => setState(() => _mealStatus = opt),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF22C55E) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF22C55E) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF22C55E) : AppColors.border,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                      : null,
                ),
                const SizedBox(width: 16),
                Text(opt, style: AppTextStyles.h3.copyWith(fontSize: 16)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
      child: Column(
        children: [
          PrimaryButton(
            text: 'Điều chỉnh kế hoạch',
            icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            onPressed: () {
              // Mock adaptive logic based on feedback
              final mockData = context.read<MockDataProvider>();
              bool intensityChanged = false;
              
              if (_workoutIntensity == 'Rất mệt' || _bodyStatus.contains('Căng mỏi cơ')) {
                // Adaptive logic: drop workout difficulty
                mockData.applyAdaptiveWorkoutReduction();
                intensityChanged = true;
              }
              
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(
                  builder: (_) => AdaptiveResultScreen(
                    intensityChanged: intensityChanged,
                    bodyStatus: _bodyStatus.toList(),
                  )
                )
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'SmartFit chỉ điều chỉnh sau khi bạn xác nhận.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

