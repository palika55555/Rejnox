package com.rejnox.rejnox

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// Health Connect (balík health) potrebuje FlutterFragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    private var watchBridge: WatchBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Hodinky s Wear OS: tep naživo a ovládanie tréningu.
        watchBridge = WatchBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
