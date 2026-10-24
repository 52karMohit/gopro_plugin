package com.example.gopro_plugin

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var previewChannel: GoproPreviewChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.gopro_plugin/preview"
        )
        val eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.gopro_plugin/preview_events"
        )

        previewChannel = GoproPreviewChannel(methodChannel, eventChannel)
        previewChannel.setup()
    }

    override fun onDestroy() {
        previewChannel.dispose()
        super.onDestroy()
    }
}
