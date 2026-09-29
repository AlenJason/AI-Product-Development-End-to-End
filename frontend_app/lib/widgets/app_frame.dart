import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// App được thiết kế cho điện thoại. Trên web, Windows, macOS cửa sổ rộng hơn nhiều, nên cả app — kể cả thanh tab,
// bảng trượt từ dưới lên, hộp thoại, SnackBar — nằm trong một cột giữa cửa sổ, rộng tối đa [maxWidth]; hai bên để
// trống. Dùng ở `MaterialApp.builder`, bọc ngoài Navigator.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child, this.maxWidth = maxContentWidth});

  static const double maxContentWidth = 640;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width, maxWidth);
    return ColoredBox(
      color: AppColors.border,
      child: Center(
        child: SizedBox(
          width: width,
          // Các widget bên trong đọc cỡ màn hình qua MediaQuery thì thấy đúng bề rộng của cột.
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
