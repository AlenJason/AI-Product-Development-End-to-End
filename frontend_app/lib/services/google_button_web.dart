import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

// Web: Google bắt buộc đăng nhập bằng nút của Google Identity Services (google_sign_in 7.x không có authenticate()
// trên web). File này dùng dart:js_interop nên chỉ biên dịch cho web.
Widget renderGoogleButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    text: web.GSIButtonText.signinWith,
    shape: web.GSIButtonShape.pill,
    locale: 'vi',
  ),
);
