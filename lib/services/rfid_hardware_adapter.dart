import '../models/rfid_frequency.dart';
import '../models/rfid_tag.dart';

/// Abstract interface for RFID hardware implementations.
/// Implement this to support different reader types (BLE, USB, TCP/IP, etc).
abstract class RfidHardwareAdapter {
  /// Connect to the RFID reader.
  /// Throw [RfidAdapterException] on failure.
  Future<void> connect();

  /// Disconnect from the RFID reader.
  Future<void> disconnect();

  /// Check if currently connected.
  bool get isConnected;

  /// Set the active frequency band.
  /// Throw [RfidAdapterException] if frequency is not supported.
  Future<void> setFrequency(RfidFrequency frequency);

  /// Begin scanning at the active frequency.
  /// Returns a stream of detected tags; close to stop scanning.
  /// Throw [RfidAdapterException] if not connected.
  Stream<RfidTag> startScanning();

  /// Get human-readable adapter name/type (e.g., "BLE Adapter", "USB Adapter").
  String get adapterName;

  /// Get list of supported frequencies for this adapter.
  List<RfidFrequency> get supportedFrequencies;
}

/// Exception thrown by hardware adapters.
class RfidAdapterException implements Exception {
  final String message;
  final Object? cause;

  RfidAdapterException(this.message, [this.cause]);

  @override
  String toString() =>
      'RfidAdapterException: $message${cause != null ? '\nCause: $cause' : ''}';
}
