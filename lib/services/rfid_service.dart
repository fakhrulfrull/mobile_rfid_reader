import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/rfid_frequency.dart';
import '../models/rfid_tag.dart';

/// Possible connection states of the RFID reader.
enum ReaderConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Service that manages RFID reader communication.
///
/// In production, replace [_simulateScan] with actual BLE / USB-serial
/// protocol calls to your hardware reader (e.g. Zebra RFD8500, Chainway
/// C72, or any reader that supports the LLRP / proprietary SDK).
class RfidService extends ChangeNotifier {
  RfidFrequency _selectedFrequency = RfidFrequency.uhf860_960MHz;
  ReaderConnectionState _connectionState = ReaderConnectionState.disconnected;
  bool _isScanning = false;
  final List<RfidTag> _scannedTags = [];
  String? _errorMessage;

  StreamSubscription<RfidTag>? _scanSubscription;
  StreamController<RfidTag>? _scanController;

  // ── Public getters ────────────────────────────────────────────────────────

  RfidFrequency get selectedFrequency => _selectedFrequency;
  ReaderConnectionState get connectionState => _connectionState;
  bool get isScanning => _isScanning;
  List<RfidTag> get scannedTags => List.unmodifiable(_scannedTags);
  String? get errorMessage => _errorMessage;
  bool get isConnected =>
      _connectionState == ReaderConnectionState.connected;

  // ── Frequency selection ───────────────────────────────────────────────────

  /// Change the active frequency band.  Stops any ongoing scan first.
  Future<void> setFrequency(RfidFrequency frequency) async {
    if (_selectedFrequency == frequency) return;
    if (_isScanning) await stopScan();

    _selectedFrequency = frequency;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Connection management ─────────────────────────────────────────────────

  /// Connect to the RFID reader hardware.
  ///
  /// Currently uses a simulated connection; swap the body of this method
  /// with actual BLE / USB discovery logic for real hardware.
  Future<void> connect() async {
    if (_connectionState == ReaderConnectionState.connected) return;

    _connectionState = ReaderConnectionState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      // TODO(hardware): Replace with actual BLE scan / USB open call.
      await Future<void>.delayed(const Duration(seconds: 1));
      _connectionState = ReaderConnectionState.connected;
    } catch (e) {
      _connectionState = ReaderConnectionState.error;
      _errorMessage = 'Connection failed: $e';
    }
    notifyListeners();
  }

  /// Disconnect from the RFID reader hardware.
  Future<void> disconnect() async {
    if (_isScanning) await stopScan();

    // TODO(hardware): Replace with actual BLE / USB close call.
    _connectionState = ReaderConnectionState.disconnected;
    notifyListeners();
  }

  // ── Scanning ──────────────────────────────────────────────────────────────

  /// Start scanning for RFID tags at the selected frequency.
  Future<void> startScan() async {
    if (_isScanning) return;
    if (!isConnected) {
      await connect();
      if (!isConnected) return;
    }

    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    _scanController = StreamController<RfidTag>.broadcast();

    // TODO(hardware): Replace _simulateScan with the actual reader SDK call
    // that yields RfidTag objects from the hardware stream.
    _scanSubscription = _simulateScan(_selectedFrequency)
        .listen(_onTagReceived, onError: _onScanError);
  }

  /// Stop an ongoing scan.
  Future<void> stopScan() async {
    if (!_isScanning) return;

    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _scanController?.close();
    _scanController = null;

    _isScanning = false;
    notifyListeners();
  }

  /// Clear the list of previously scanned tags.
  void clearTags() {
    _scannedTags.clear();
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _onTagReceived(RfidTag tag) {
    // Avoid duplicates; update RSSI if the tag is seen again.
    final existing = _scannedTags.indexWhere((t) => t.epc == tag.epc);
    if (existing >= 0) {
      _scannedTags[existing] = tag;
    } else {
      _scannedTags.add(tag);
    }
    notifyListeners();
  }

  void _onScanError(Object error) {
    _errorMessage = error.toString();
    _isScanning = false;
    notifyListeners();
  }

  /// Simulates an RFID scan stream; emits random tags every 0.5–1.5 seconds.
  ///
  /// Replace this method with real hardware callbacks in production.
  Stream<RfidTag> _simulateScan(RfidFrequency frequency) async* {
    final rng = Random();

    // Pre-defined simulated EPC / ID pools per frequency band.
    final epcs = _epcPool(frequency);

    while (true) {
      await Future<void>.delayed(
        Duration(milliseconds: 500 + rng.nextInt(1000)),
      );

      final epc = epcs[rng.nextInt(epcs.length)];
      final rssi = -90 + rng.nextInt(45); // -90 dBm … -45 dBm
      yield RfidTag(
        id: '${frequency.name}_$epc',
        epc: epc,
        frequency: frequency,
        rssi: rssi,
        scannedAt: DateTime.now(),
      );
    }
  }

  List<String> _epcPool(RfidFrequency frequency) {
    switch (frequency) {
      case RfidFrequency.lf125kHz:
        return [
          '0064 3A 2B 1C',
          '0064 7F 8E 9D',
          '0064 A1 B2 C3',
          '0064 D4 E5 F6',
        ];
      case RfidFrequency.lf134kHz:
        return [
          'FDX-B 982 000 123456789',
          'FDX-B 999 000 987654321',
          'FDX-B 840 000 112233445',
        ];
      case RfidFrequency.hf13_56MHz:
        return [
          '04:A3:2B:1C:5E:6F:80',
          '04:B7:8E:9D:AA:BB:CC',
          '04:C1:D2:E3:F4:05:16',
          '04:27:38:49:5A:6B:7C',
        ];
      case RfidFrequency.uhf433MHz:
        return [
          'ACT-433-0001',
          'ACT-433-0002',
          'ACT-433-0003',
        ];
      case RfidFrequency.uhf860_960MHz:
        return [
          'E2 00 34 12 01 23 45 67 89 AB CD EF',
          'E2 00 34 12 98 76 54 32 10 FE DC BA',
          'E2 00 00 00 00 00 00 00 00 00 00 01',
          'E2 80 11 07 20 00 60 00 70 00 80 01',
          '30 07 5C B8 97 90 04 00 00 00 00 00',
        ];
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanController?.close();
    super.dispose();
  }
}
