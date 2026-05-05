import 'rfid_frequency.dart';

/// Represents a single scanned RFID tag.
class RfidTag {
  final String id;
  final String epc;
  final RfidFrequency frequency;
  final int rssi;
  final DateTime scannedAt;
  final String? additionalData;

  const RfidTag({
    required this.id,
    required this.epc,
    required this.frequency,
    required this.rssi,
    required this.scannedAt,
    this.additionalData,
  });

  /// Signal strength as a human-readable label.
  String get signalStrength {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -65) return 'Good';
    if (rssi >= -80) return 'Fair';
    return 'Weak';
  }

  @override
  String toString() =>
      'RfidTag(epc: $epc, frequency: ${frequency.label}, rssi: $rssi dBm)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RfidTag && runtimeType == other.runtimeType && epc == other.epc;

  @override
  int get hashCode => epc.hashCode;
}
