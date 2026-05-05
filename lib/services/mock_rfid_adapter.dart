import '../models/rfid_frequency.dart';
import '../models/rfid_tag.dart';
import 'rfid_hardware_adapter.dart';

/// Mock hardware adapter for testing without real hardware.
class MockRfidAdapter implements RfidHardwareAdapter {
  bool _isConnected = false;
  RfidFrequency _activeFrequency = RfidFrequency.lf125kHz;

  @override
  String get adapterName => 'Mock RFID Adapter';

  @override
  List<RfidFrequency> get supportedFrequencies => RfidFrequency.values;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  Future<void> setFrequency(RfidFrequency frequency) async {
    if (!isConnected) {
      throw RfidAdapterException('Not connected');
    }
    _activeFrequency = frequency;
  }

  @override
  Stream<RfidTag> startScanning() async* {
    if (!isConnected) {
      throw RfidAdapterException('Not connected');
    }

    // Yield a few mock tags
    yield RfidTag(
      id: 'mock_tag_1',
      epc: 'MOCK0001',
      frequency: _activeFrequency,
      rssi: -50,
      scannedAt: DateTime.now(),
    );

    await Future.delayed(const Duration(milliseconds: 100));

    yield RfidTag(
      id: 'mock_tag_2',
      epc: 'MOCK0002',
      frequency: _activeFrequency,
      rssi: -65,
      scannedAt: DateTime.now(),
    );
  }
}
