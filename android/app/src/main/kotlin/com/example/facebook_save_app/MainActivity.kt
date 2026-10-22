package com.example.facebook_save_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.facebook_save/share"
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        methodChannel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger, CHANNEL)
        // If the app was launched via a share intent, handle it now
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Called when the app is already running and receives a new share intent
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (Intent.ACTION_SEND == intent.action) {
            val data = mutableMapOf<String, Any>()
            // Text
            intent.getStringExtra(Intent.EXTRA_TEXT)?.let { data["text"] = it }
            // URL (some apps put it in EXTRA_TEXT as well, but we also capture explicitly)
            intent.getStringExtra(Intent.EXTRA_SUBJECT)?.let { data["url"] = it }
            // Media (image/video)
            intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)?.let { uri ->
                // Determine MIME type
                val mime = contentResolver.getType(uri) ?: "application/octet-stream"
                if (mime.startsWith("image")) {
                    data["imageUri"] = uri.toString()
                } else if (mime.startsWith("video")) {
                    data["videoUri"] = uri.toString()
                }
            }
            // Send to Dart side
            methodChannel?.invokeMethod("onShare", data)
        }
    }
}
