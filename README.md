# mobile_rfid_reader

A Flutter mobile application for scanning RFID tags with **selectable frequency bands** (LF / HF / UHF).

---

## Features

| Feature | Details |
|---|---|
| **Frequency selection** | LF 125 kHz, LF 134.2 kHz, HF 13.56 MHz, UHF 433 MHz, UHF 860–960 MHz |
| **Live tag scanning** | Displays scanned tags with EPC, RSSI, signal strength & timestamp |
| **Frequency guide** | Info screen describing each band (protocols, read range) |
| **BLE connectivity** | Bluetooth-based reader connection (simulatable; swap in real SDK) |
| **Material You UI** | Dynamic colour scheme, dark-mode support |

---

## Project Structure

```
lib/
  main.dart                      # App entry point & navigation shell
  models/
    rfid_frequency.dart          # RfidFrequency enum + extension
    rfid_tag.dart                # RfidTag data class
  services/
    rfid_service.dart            # ChangeNotifier managing connection & scan
  screens/
    scan_screen.dart             # Frequency picker + live tag list
    frequency_info_screen.dart   # Per-frequency info cards
  widgets/
    frequency_selector.dart      # Reusable frequency chip widget
test/
  widget_test.dart               # Unit & widget tests
```

---

## Getting Started

### Prerequisites

- Flutter SDK >= 3.0 — https://docs.flutter.dev/get-started/install
- Android SDK >= 21 (or iOS 12+)

### Run the app

```bash
flutter pub get
flutter run
```

### Run tests

```bash
flutter test
```

---

## Connecting a Real RFID Reader

The `RfidService` class contains clearly marked `TODO(hardware):` comments.
Replace each stub with the appropriate SDK call for your hardware:

| Reader type | Approach |
|---|---|
| BLE handheld (e.g. Zebra RFD8500, Chainway C72) | Use `flutter_blue_plus` to discover & connect; pipe tag notifications to `_onTagReceived` |
| USB / Serial | Use `usb_serial` package; open the COM port and parse the vendor protocol |
| NFC (HF 13.56 MHz only) | Use the `nfc_manager` package for host-card-emulation readers |

### Required Android permissions (already in `AndroidManifest.xml`)

- `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (API 31+)
- `ACCESS_FINE_LOCATION` (required by Android for BLE scan on API < 31)
- `android.hardware.usb.host` (optional – wired readers)

---

## Frequency Reference

| Band | Frequency | Protocols | Typical Range |
|---|---|---|---|
| LF | 125 kHz | EM4100, HID Prox, animal tags | <= 10 cm |
| LF | 134.2 kHz | ISO 11784/11785, FDX-B | <= 10 cm |
| HF | 13.56 MHz | ISO 14443, ISO 15693, MIFARE, NFC | <= 1 m |
| UHF | 433 MHz | Active tags, asset tracking | 1–100 m |
| UHF | 860–960 MHz | EPC Gen2 (ISO 18000-6C) | 1–12 m |
