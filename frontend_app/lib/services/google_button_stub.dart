import 'package:flutter/widgets.dart';

// Android, macOS, Windows: không có nút do Google vẽ — Android, macOS dùng GoogleAuth.signIn(). Bản web ở
// google_button_web.dart (import có điều kiện trong google_auth.dart).
Widget renderGoogleButton() => const SizedBox.shrink();
