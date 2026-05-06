import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/rfid_frequency.dart';
import '../models/rfid_tag.dart';
import 'rfid_hardware_adapter.dart';

/// Possible connection states of the RFID reader.
enum ReaderConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Service that manages RFID reader communication via hardware adapters.
///
/// Delegates actual hardware operations to the injected [RfidHardwareAdapter].
/// Swap adapters to support different reader types (BLE, USB, TCP/IP, etc).
class RfidService extends ChangeNotifier {
  final RfidHardwareAdapter hardware;

  RfidFrequency _selectedFrequency = RfidFrequency.lf125kHz;
  ReaderConnectionState _connectionState = ReaderConnectionState.disconnected;
  bool _isScanning = false;
  final List<RfidTag> _scannedTags = [];
  String? _errorMessage;

  StreamSubscription<RfidTag>? _scanSubscription;

  RfidFrequency get _fallbackFrequency =>
      hardware.supportedFrequencies.isNotEmpty
          ? hardware.supportedFrequencies.first
          : RfidFrequency.lf125kHz;

  // ── Public getters ────────────────────────────────────────────────────────

  RfidFrequency get selectedFrequency => _selectedFrequency;
  ReaderConnectionState get connectionState => _connectionState;
  bool get isScanning => _isScanning;
  List<RfidTag> get scannedTags => List.unmodifiable(_scannedTags);
  String? get errorMessage => _errorMessage;
  bool get isConnected => _connectionState == ReaderConnectionState.connected;
  List<RfidFrequency> get supportedFrequencies =>
      List.unmodifiable(hardware.supportedFrequencies);

  /// Constructor: inject the hardware adapter to use.
  RfidService({required this.hardware}) {
    if (!hardware.supportedFrequencies.contains(_selectedFrequency)) {
      _selectedFrequency = _fallbackFrequency;
    }
  }

  // ── Frequency selection ───────────────────────────────────────────────────

  /// Change the active frequency band.  Stops any ongoing scan first.
  Future<void> setFrequency(RfidFrequency frequency) async {
    if (_selectedFrequency == frequency) return;
    if (_isScanning) await stopScan();

    if (!supportedFrequencies.contains(frequency)) {
      _errorMessage =
          '${frequency.label} is not supported by ${hardware.adapterName}.';
      notifyListeners();
      return;
    }

    _selectedFrequency = frequency;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Connection management ─────────────────────────────────────────────────

  /// Connect to the RFID reader hardware via the active adapter.
  Future<void> connect() async {
    if (_connectionState == ReaderConnectionState.connected) return;

    if (!supportedFrequencies.contains(_selectedFrequency)) {
      _selectedFrequency = _fallbackFrequency;
    }

    _connectionState = ReaderConnectionState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      await hardware.connect();
      // Ensure selected frequency is set on the hardware
      await hardware.setFrequency(_selectedFrequency);
      _connectionState = ReaderConnectionState.connected;
    } on RfidAdapterException catch (e) {
      _connectionState = ReaderConnectionState.error;
      _errorMessage = e.message;
    } catch (e) {
      _connectionState = ReaderConnectionState.error;
      _errorMessage = 'Connection failed: $e';
    }
    notifyListeners();
  }

  /// Disconnect from the RFID reader hardware.
  Future<void> disconnect() async {
    if (_isScanning) await stopScan();

    try {
      await hardware.disconnect();
    } catch (e) {
      _errorMessage = 'Disconnect error: $e';
    }
    _connectionState = ReaderConnectionState.disconnected;
    notifyListeners();
  }

  // ── Scanning ──────────────────────────────────────────────────────────────

  /// Start scanning for RFID tags at the selected frequency.
  Future<void> startScan() async {
    if (_isScanning) return;
    if (!supportedFrequencies.contains(_selectedFrequency)) {
      _errorMessage =
          '${_selectedFrequency.label} is not supported by ${hardware.adapterName}.';
      notifyListeners();
      return;
    }

    if (!isConnected) {
      await connect();
      if (!isConnected) return;
    }

    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Ensure frequency is set before starting scan
      await hardware.setFrequency(_selectedFrequency);

      // Start real hardware scanning
      _scanSubscription = hardware.startScanning().listen(
            _onTagReceived,
            onError: _onScanError,
            cancelOnError: false,
          );
    } on RfidAdapterException catch (e) {
      _errorMessage = e.message;
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Scan failed: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop an ongoing scan.
  Future<void> stopScan() async {
    if (!_isScanning) return;

    await _scanSubscription?.cancel();
    _scanSubscription = null;

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

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}
