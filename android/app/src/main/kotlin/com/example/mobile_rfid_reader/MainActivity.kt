package com.example.mobile_rfid_reader

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.util.Random

class MainActivity: FlutterActivity() {
  private val methodChannelName = "com.example.mobile_rfid_reader/rfid_hardware"
  private val eventChannelName = "com.example.mobile_rfid_reader/rfid_scan_stream"

  private var isConnected = false
  private var isScanning = false
  private var scanEventSink: EventChannel.EventSink? = null
  private var scanThread: Thread? = null
  private var currentFrequency: String = "lf125kHz"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Method channel for hardware control
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "connect" -> handleConnect(result)
          "disconnect" -> handleDisconnect(result)
          "setFrequency" -> handleSetFrequency(call.argument("frequency"), result)
          "startScanning" -> handleStartScanning(call.argument("frequency"), result)
          "stopScanning" -> handleStopScanning(result)
          else -> result.notImplemented()
        }
      }

    // Event channel for scan stream
    EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
      .setStreamHandler(object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          scanEventSink = events
        }

        override fun onCancel(arguments: Any?) {
          scanEventSink = null
          stopScanning()
        }
      })
  }

  private fun handleConnect(result: MethodChannel.Result) {
    try {
      // In production, initialize BLE connection to actual reader
      // For now, simulate successful connection
      isConnected = true
      result.success(true)
    } catch (e: Exception) {
      isConnected = false
      result.error("CONNECTION_ERROR", e.message, null)
    }
  }

  private fun handleDisconnect(result: MethodChannel.Result) {
    try {
      stopScanning()
      // In production, close BLE connection
      isConnected = false
      result.success(null)
    } catch (e: Exception) {
      result.error("DISCONNECT_ERROR", e.message, null)
    }
  }

  private fun handleSetFrequency(frequency: String?, result: MethodChannel.Result) {
    try {
      if (!isConnected) {
        result.error("NOT_CONNECTED", "Reader not connected", null)
        return
      }

      currentFrequency = frequency ?: "lf125kHz"

      // In production, send frequency configuration to reader via BLE:
      // Example pseudo-code:
      // when (frequency) {
      //   "lf125kHz" -> reader.setFrequency(125000)
      //   "lf134kHz" -> reader.setFrequency(134200)
      //   "hf13_56MHz" -> reader.setFrequency(13560000)
      //   "uhf433MHz" -> reader.setFrequency(433000000)
      //   "uhf860_960MHz" -> reader.setFrequency(860000000 to 960000000)
      // }

      result.success(null)
    } catch (e: Exception) {
      result.error("SET_FREQUENCY_ERROR", e.message, null)
    }
  }

  private fun handleStartScanning(frequency: String?, result: MethodChannel.Result) {
    try {
      if (!isConnected) {
        result.error("NOT_CONNECTED", "Reader not connected", null)
        return
      }

      frequency?.let { currentFrequency = it }
      isScanning = true

      // Start background scanning thread
      scanThread = Thread {
        simulateScanning()
      }
      scanThread?.start()

      result.success(null)
    } catch (e: Exception) {
      result.error("START_SCANNING_ERROR", e.message, null)
    }
  }

  private fun handleStopScanning(result: MethodChannel.Result) {
    try {
      stopScanning()
      result.success(null)
    } catch (e: Exception) {
      result.error("STOP_SCANNING_ERROR", e.message, null)
    }
  }

  private fun stopScanning() {
    isScanning = false
    scanThread?.interrupt()
    scanThread = null
  }

  /// Simulate scanning for demonstration.
  /// Replace with actual reader SDK calls.
  private fun simulateScanning() {
    val rng = Random()
    val epcPool = getEpcPoolForFrequency(currentFrequency)

    while (isScanning && scanEventSink != null) {
      try {
        // Random delay: 0.5-1.5 seconds
        Thread.sleep((500 + rng.nextInt(1000)).toLong())

        val epc = epcPool[rng.nextInt(epcPool.size)]
        val rssi = -90 + rng.nextInt(45) // -90 to -45 dBm

        val tagEvent = mapOf(
          "id" to "${currentFrequency}_$epc",
          "epc" to epc,
          "rssi" to rssi
        )

        Handler(Looper.getMainLooper()).post {
          scanEventSink?.success(tagEvent)
        }
      } catch (e: InterruptedException) {
        break
      } catch (e: Exception) {
        Handler(Looper.getMainLooper()).post {
          scanEventSink?.error("SCAN_ERROR", e.message, null)
        }
        break
      }
    }
  }

  private fun getEpcPoolForFrequency(frequency: String): List<String> {
    return when (frequency) {
      "lf125kHz" -> listOf(
        "0064 3A 2B 1C",
        "0064 7F 8E 9D",
        "0064 A1 B2 C3",
        "0064 D4 E5 F6"
      )
      "lf134kHz" -> listOf(
        "FDX-B 982 000 123456789",
        "FDX-B 999 000 987654321",
        "FDX-B 840 000 112233445"
      )
      "hf13_56MHz" -> listOf(
        "04:A3:2B:1C:5E:6F:80",
        "04:B7:8E:9D:AA:BB:CC",
        "04:C1:D2:E3:F4:05:16",
        "04:27:38:49:5A:6B:7C"
      )
      "uhf433MHz" -> listOf(
        "ACT-433-0001",
        "ACT-433-0002",
        "ACT-433-0003"
      )
      "uhf860_960MHz" -> listOf(
        "E2 00 34 12 01 23 45 67 89 AB CD EF",
        "E2 00 34 12 98 76 54 32 10 FE DC BA",
        "E2 00 00 00 00 00 00 00 00 00 00 01",
        "E2 80 11 07 20 00 60 00 70 00 80 01",
        "30 07 5C B8 97 90 04 00 00 00 00 00"
      )
      else -> emptyList()
    }
  }
}

