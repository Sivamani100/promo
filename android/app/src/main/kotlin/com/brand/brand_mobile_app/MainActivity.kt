package com.brand.brand_mobile_app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Secure flag: prevents screenshots and screen recording app-wide on Android
        // window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
