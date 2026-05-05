/// Represents the RFID frequency band used for scanning.
enum RfidFrequency {
  lf125kHz,
  lf134kHz,
  hf13_56MHz,
  uhf433MHz,
  uhf860_960MHz,
}

/// Human-readable labels and technical details for each frequency.
extension RfidFrequencyExtension on RfidFrequency {
  String get label {
    switch (this) {
      case RfidFrequency.lf125kHz:
        return 'LF 125 kHz';
      case RfidFrequency.lf134kHz:
        return 'LF 134.2 kHz';
      case RfidFrequency.hf13_56MHz:
        return 'HF 13.56 MHz';
      case RfidFrequency.uhf433MHz:
        return 'UHF 433 MHz';
      case RfidFrequency.uhf860_960MHz:
        return 'UHF 860–960 MHz';
    }
  }

  String get description {
    switch (this) {
      case RfidFrequency.lf125kHz:
        return 'Low Frequency – EM4100, HID Prox, animal tags';
      case RfidFrequency.lf134kHz:
        return 'Low Frequency – ISO 11784/11785, FDX-B animal tags';
      case RfidFrequency.hf13_56MHz:
        return 'High Frequency – ISO 14443, ISO 15693, MIFARE, NFC';
      case RfidFrequency.uhf433MHz:
        return 'UHF – Active tags, long-range asset tracking';
      case RfidFrequency.uhf860_960MHz:
        return 'UHF – ISO 18000-6C (EPC Gen2), supply chain, retail';
    }
  }

  String get band {
    switch (this) {
      case RfidFrequency.lf125kHz:
      case RfidFrequency.lf134kHz:
        return 'LF';
      case RfidFrequency.hf13_56MHz:
        return 'HF';
      case RfidFrequency.uhf433MHz:
      case RfidFrequency.uhf860_960MHz:
        return 'UHF';
    }
  }

  /// Typical read range for this frequency.
  String get readRange {
    switch (this) {
      case RfidFrequency.lf125kHz:
      case RfidFrequency.lf134kHz:
        return '≤ 10 cm';
      case RfidFrequency.hf13_56MHz:
        return '≤ 1 m';
      case RfidFrequency.uhf433MHz:
        return '1–100 m (active)';
      case RfidFrequency.uhf860_960MHz:
        return '1–12 m (passive)';
    }
  }
}
