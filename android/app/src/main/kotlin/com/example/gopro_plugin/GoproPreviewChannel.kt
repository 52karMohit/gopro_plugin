package com.example.gopro_plugin

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

class GoproPreviewChannel(
    private val methodChannel: MethodChannel,
    private val eventChannel: EventChannel
) {
    private var socket: DatagramSocket? = null
    private var isStreaming = false
    private val handler = Handler(Looper.getMainLooper())
    private val TAG = "GoProPreview"
    private var eventSink: EventChannel.EventSink? = null

    fun setup() {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startPreview" -> {
                    val host = call.argument<String>("host") ?: "10.5.5.9"
                    val port = call.argument<Int>("port") ?: 8554
                    startPreview(host, port, result)
                }
                "stopPreview" -> {
                    stopPreview(result)
                }
                else -> result.notImplemented()
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun startPreview(host: String, port: Int, result: MethodChannel.Result) {
        try {
            if (isStreaming) {
                result.success(true)
                return
            }

            Thread {
                try {
                    val address = InetAddress.getByName(host)
                    socket = DatagramSocket(port)
                    socket?.broadcast = true
                    isStreaming = true

                    val buffer = ByteArray(65536)
                    val packet = DatagramPacket(buffer, buffer.size)

                    Log.d(TAG, "Starting UDP preview on $host:$port")

                    while (isStreaming) {
                        socket?.receive(packet)
                        
                        // Send frame data to Flutter
                        handler.post {
                            val data = packet.data.copyOfRange(0, packet.length)
                            eventSink?.success(mapOf("data" to data.toList()))
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in preview thread", e)
                    handler.post {
                        eventSink?.error("STREAM_ERROR", e.message, null)
                    }
                }
            }.start()

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start preview", e)
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun stopPreview(result: MethodChannel.Result) {
        try {
            isStreaming = false
            socket?.close()
            socket = null
            Log.d(TAG, "Preview stopped")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop preview", e)
            result.error("STOP_ERROR", e.message, null)
        }
    }

    fun dispose() {
        isStreaming = false
        socket?.close()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
