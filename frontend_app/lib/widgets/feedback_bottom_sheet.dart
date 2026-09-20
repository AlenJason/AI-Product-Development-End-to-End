import 'package:flutter/material.dart';

class FeedbackBottomSheet extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onSubmitted;

  const FeedbackBottomSheet({
    super.key,
    required this.onClose,
    required this.onSubmitted,
  });

  @override
  State<FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends State<FeedbackBottomSheet> {
  int _eatingOption = 0; // 0: Đúng lịch, 1: Ăn nhiều hơn, 2: Ăn ít hơn
  int _energyOption = 0; // 0: Khỏe, 1: Hơi mệt, 2: Đau cơ

  final List<String> _eatingLabels = [
    'Ăn đúng theo thực đơn',
    'Lỡ ăn nhiều hơn (+200-300 kcal)',
    'Ăn không hết suất / Bỏ bữa',
  ];

  final List<String> _energyLabels = [
    'Khỏe khoắn, bình thường',
    'Hơi mệt, cần món nhẹ bụng',
    'Căng mỏi cơ sau khi tập',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Phản hồi thích nghi (Ngày 1)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Hôm nay bạn ăn uống thế nào?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_eatingLabels.length, (index) {
            final isSelected = _eatingOption == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: InkWell(
                onTap: () => setState(() => _eatingOption = index),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 16,
                        color: isSelected ? const Color(0xFF059669) : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _eatingLabels[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? const Color(0xFF047857) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text(
            'Tình trạng cơ thể:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_energyLabels.length, (index) {
            final isSelected = _energyOption == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: InkWell(
                onTap: () => setState(() => _energyOption = index),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 16,
                        color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _energyLabels[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onSubmitted,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Lưu phản hồi & Cập nhật Ngày 2',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
