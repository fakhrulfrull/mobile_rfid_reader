# RFID Hardware Integration Guide

This app now uses a **modular hardware abstraction layer** to support real RFID readers. The simulation has been replaced with a framework you can adapt to your specific hardware.

## Architecture

### Layer 1: Hardware Adapter Interface
`lib/services/rfid_hardware_adapter.dart` — Defines the abstract `RfidHardwareAdapter` interface:
- `connect()` / `disconnect()` — connection lifecycle
- `setFrequency()` — select 125 kHz, 134.2 kHz, 13.56 MHz, etc.
- `startScanning()` — returns a stream of detected `RfidTag` objects
- `supportedFrequencies` — list of reader capabilities

### Layer 2: BLE Adapter (Reference Implementation)
`lib/services/ble_rfid_adapter.dart` — Communicates with native Kotlin code via Platform Channels (MethodChannel + EventChannel).

### Layer 3: Native Integration
`android/app/src/main/kotlin/.../MainActivity.kt` — Handles actual hardware I/O:
- Initializes BLE / USB connections
- Sets frequency on the reader
- Streams detected tags back to Flutter

### Layer 4: Service Layer
`lib/services/rfid_service.dart` — Injects the adapter and provides the UI layer with connection & scanning APIs.

---

## How to Add Support for Your Hardware

### Step 1: Identify Your Reader
- **Model**: (e.g., Zebra RFD8500, Chainway C72, Impinj, etc.)
- **Connection**: Bluetooth, USB Serial, TCP/IP?
- **SDK Available**: Proprietary or generic protocol?
- **Frequency Support**: Which frequencies does it support?

### Step 2: Create a New Adapter (Option A: For New Connection Types)

If your reader uses a different connection method (not BLE), create a new adapter:

```dart
// lib/services/my_reader_adapter.dart
import 'rfid_hardware_adapter.dart';

class MyReaderAdapter implements RfidHardwareAdapter {
  @override
  String get adapterName => 'My Custom RFID Reader';
  
  @override
  List<RfidFrequency> get supportedFrequencies => [
    RfidFrequency.lf125kHz,
    RfidFrequency.lf134kHz,
    RfidFrequency.uhf860_960MHz,
  ];
  
  bool _isConnected = false;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  Future<void> connect() async {
    // TODO: Initialize connection to your reader
    // Example: open USB serial port, establish TCP connection, etc.
    _isConnected = true;
  }
  
  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }
  
  @override
  Future<void> setFrequency(RfidFrequency frequency) async {
    // TODO: Send frequency configuration command to your reader
    // Example: send proprietary command over USB/TCP/BLE
  }
  
  @override
  Stream<RfidTag> startScanning() async* {
    // TODO: Read/listen for tags from your reader
    // Convert reader's native format into RfidTag objects
    // Example: parse USB serial messages, TCP packets, etc.
    yield RfidTag(
      id: 'tag1',
      epc: '0000000000000001',
      frequency: /* current frequency */,
      rssi: -50,
      scannedAt: DateTime.now(),
    );
  }
}
```

Then update `lib/main.dart`:
```dart
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => RfidService(hardware: MyReaderAdapter()),
      child: const MobileRfidReaderApp(),
    ),
  );
}
```

### Step 3: Update Native Android Code (Kotlin)

Modify `android/app/src/main/kotlin/.../MainActivity.kt` to integrate your reader SDK:

```kotlin
private fun handleConnect(result: MethodChannel.Result) {
  try {
    // Initialize via your reader's SDK
    // Example for USB:
    // val deviceManager = UsbManager.getInstance(context)
    // val reader = deviceManager.openReader(...)
    
    // Example for BLE:
    // val bleReader = BleRfidReader(context)
    // bleReader.connect()
    
    isConnected = true
    result.success(true)
  } catch (e: Exception) {
    result.error("CONNECTION_ERROR", e.message, null)
  }
}

private fun handleSetFrequency(frequency: String?, result: MethodChannel.Result) {
  try {
    // Send frequency command to your reader
    when (frequency) {
      "lf125kHz" -> reader.setFrequency(125000)     // 125 kHz for EM4100, HID Prox
      "lf134kHz" -> reader.setFrequency(134200)     // 134.2 kHz for FDX-B
      "hf13_56MHz" -> reader.setFrequency(13560)    // 13.56 MHz for NFC, MIFARE
      "uhf433MHz" -> reader.setFrequency(433000)    // UHF 433 MHz
      "uhf860_960MHz" -> reader.setFrequency(860000 to 960000) // UHF Global
    }
    result.success(null)
  } catch (e: Exception) {
    result.error("SET_FREQUENCY_ERROR", e.message, null)
  }
}

private fun simulateScanning() {
  // Replace with real reader stream
  // Example: listen to hardware for tags
  // reader.onTagDetected { tag ->
  //   val tagEvent = mapOf(
  //     "id" to tag.id,
  //     "epc" to tag.epc,
  //     "rssi" to tag.rssi
  //   )
  //   Handler(Looper.getMainLooper()).post {
  //     scanEventSink?.success(tagEvent)
  //   }
  // }
}
```

---

## Supported Frequencies

The app currently supports:
- **LF 125 kHz**: EM4100, HID Prox, animal tags (~10 cm range)
- **LF 134.2 kHz**: ISO 11784/11785 FDX-B animal tags (~10 cm range)
- **HF 13.56 MHz**: ISO 14443, ISO 15693, MIFARE, NFC (~1 m range)
- **UHF 433 MHz**: Active tags, long-range asset tracking (1–100 m)
- **UHF 860–960 MHz**: ISO 18000-6C (EPC Gen2), supply chain, retail (1–12 m)

Each adapter can selectively support any of these frequencies via `supportedFrequencies`.

---

## Testing

Once you've integrated your hardware, test with:

```bash
flutter run
```

The UI will allow you to:
1. Select a frequency (e.g., 125 kHz for EM4100 tags)
2. Connect to the reader
3. Start scanning
4. View detected tags in real-time

---

## Example Integrations

### Zebra RFD8500 (Bluetooth)
Use the existing `BleRfidAdapter` and integrate the Zebra SDK:
```kotlin
import com.zebra.rfid.api3.*

private val readerManager = RFIDReader.getInstance()

private fun handleConnect(result: MethodChannel.Result) {
  try {
    readerManager.connect()
    isConnected = true
    result.success(true)
  } catch (e: Exception) {
    result.error("CONNECTION_ERROR", e.message, null)
  }
}
```

### USB Serial Reader (Generic)
Create a new adapter using USB serial:
```kotlin
import android.hardware.usb.UsbManager

private fun handleConnect(result: MethodChannel.Result) {
  try {
    val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    val devices = usbManager.deviceList.values
    // Find and open RFID reader device
    isConnected = true
    result.success(true)
  } catch (e: Exception) {
    result.error("CONNECTION_ERROR", e.message, null)
  }
}
```

---

## Troubleshooting

**"Not connected to reader"** → Check `connect()` is called and succeeds.
**No tags detected** → Verify frequency matches your tags; check reader range/antenna.
**"Unsupported frequency"** → Not all readers support all frequencies; check `supportedFrequencies`.

---

## Next Steps

1. Obtain your reader's documentation / SDK
2. Implement a new adapter or enhance `BleRfidAdapter`
3. Update `MainActivity.kt` with real hardware calls
4. Test with physical tags
5. Update `supportedFrequencies` list based on your reader's capabilities

Questions? Check your reader's API documentation or contact support.
