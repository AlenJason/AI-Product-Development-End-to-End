import 'dart:async';
import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const LoadingScreen({super.key, required this.onDone});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  int _step = 0;
  Timer? _timer;

  final List<String> _loadingSteps = [
    'Tính toán chỉ số TDEE và thâm hụt calo...',
    'Lựa chọn món ăn Việt phù hợp ngân sách...',
    'Cân đối Macro: 140g Carbs, 65g Protein, 32g Fat...',
    'Tự động bóc tách danh sách nguyên liệu đi chợ...',
  ];

  @override
  void initState() {
    super.initState();
    _startSteps();
  }

  void _startSteps() {
    _timer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_step < _loadingSteps.length - 1) {
        setState(() {
          _step++;
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            widget.onDone();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'SmartFit AI đang tối ưu kế hoạch',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _loadingSteps[_step],
                  key: ValueKey<int>(_step),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: widget.onDone,
                child: const Text(
                  'Xem trước kế hoạch ngay',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
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
