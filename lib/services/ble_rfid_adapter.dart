import 'package:flutter/services.dart';

import '../models/rfid_frequency.dart';
import '../models/rfid_tag.dart';
import 'rfid_hardware_adapter.dart';

/// BLE-based RFID hardware adapter using native Android platform integration.
/// Communicates via MethodChannel with Kotlin code for Bluetooth operations.
class BleRfidAdapter implements RfidHardwareAdapter {
  static const platform =
      MethodChannel('com.example.mobile_rfid_reader/rfid_hardware');

  bool _isConnected = false;
  RfidFrequency _activeFrequency = RfidFrequency.lf125kHz;

  @override
  String get adapterName => 'BLE RFID Reader';

  @override
  List<RfidFrequency> get supportedFrequencies => const [
        RfidFrequency.lf125kHz,
        RfidFrequency.lf134kHz,
      ];

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    try {
      final result = await platform.invokeMethod<bool>('connect');
      _isConnected = result ?? false;
      if (!_isConnected) {
        throw RfidAdapterException('Failed to connect to BLE reader');
      }
    } on PlatformException catch (e) {
      throw RfidAdapterException(
        'BLE connection failed: ${e.message}',
        e,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await platform.invokeMethod<void>('disconnect');
      _isConnected = false;
    } on PlatformException catch (e) {
      throw RfidAdapterException(
        'BLE disconnect failed: ${e.message}',
        e,
      );
    }
  }

  @override
  Future<void> setFrequency(RfidFrequency frequency) async {
    if (!isConnected) {
      throw RfidAdapterException('Not connected to reader');
    }

    try {
      await platform.invokeMethod<void>('setFrequency', {
        'frequency': frequency.name,
      });
      _activeFrequency = frequency;
    } on PlatformException catch (e) {
      throw RfidAdapterException(
        'Failed to set frequency: ${e.message}',
        e,
      );
    }
  }

  @override
  Stream<RfidTag> startScanning() async* {
    if (!isConnected) {
      throw RfidAdapterException('Not connected to reader');
    }

    try {
      final eventChannel = EventChannel(
        'com.example.mobile_rfid_reader/rfid_scan_stream',
      );

      await platform.invokeMethod<void>('startScanning', {
        'frequency': _activeFrequency.name,
      });

      yield* eventChannel
          .receiveBroadcastStream()
          .map((event) => _parseTagFromMap(event))
          .handleError(
        (e) {
          throw RfidAdapterException(
            'Scanning error: ${e.toString()}',
            e,
          );
        },
      );
    } on PlatformException catch (e) {
      throw RfidAdapterException(
        'Failed to start scanning: ${e.message}',
        e,
      );
    }
  }

  /// Parse native event map into RfidTag model.
  RfidTag _parseTagFromMap(dynamic map) {
    if (map is! Map) {
      throw RfidAdapterException('Invalid tag event format');
    }

    return RfidTag(
      id: map['id']?.toString() ?? '',
      epc: map['epc']?.toString() ?? '',
      frequency: _activeFrequency,
      rssi: (map['rssi'] as num?)?.toInt() ?? -100,
      scannedAt: DateTime.now(),
    );
  }
}
