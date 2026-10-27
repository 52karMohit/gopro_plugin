package com.aiunika.gopro_plugin

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/// GoProPlugin - Main plugin class for GoPro camera control
class GoProPlugin : FlutterPlugin {
    private lateinit var channel: MethodChannel
    private lateinit var previewChannel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "gopro_plugin")
        previewChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "gopro_preview")
        
        // Initialize any native platform code here
        // For now, most functionality is implemented in Dart using Flutter packages
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        previewChannel.setMethodCallHandler(null)
    }
}
