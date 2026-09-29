package com.example.my_ai_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Back ở màn gốc (Onboarding bước 1, các tab chính): đưa app xuống nền như nút Home, không đóng activity —
    // dữ liệu đang nhập còn nguyên khi mở lại (PLAN D8). Mặc định Flutter gọi finish() và mất hết phần đang nhập.
    // Hệ thống tắt app ở nền thì state restoration của Flutter khôi phục; force-quit mới xoá.
    override fun popSystemNavigator(): Boolean {
        moveTaskToBack(true)
        return true
    }
}
