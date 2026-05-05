import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile_rfid_reader/models/rfid_frequency.dart';
import 'package:mobile_rfid_reader/models/rfid_tag.dart';
import 'package:mobile_rfid_reader/services/rfid_service.dart';
import 'package:mobile_rfid_reader/widgets/frequency_selector.dart';

// ── Model tests ──────────────────────────────────────────────────────────────

void main() {
  group('RfidFrequency model', () {
    test('every frequency has a non-empty label', () {
      for (final freq in RfidFrequency.values) {
        expect(freq.label.isNotEmpty, isTrue,
            reason: '${freq.name} has empty label');
      }
    });

    test('every frequency has a non-empty description', () {
      for (final freq in RfidFrequency.values) {
        expect(freq.description.isNotEmpty, isTrue);
      }
    });

    test('band grouping is correct', () {
      expect(RfidFrequency.lf125kHz.band, 'LF');
      expect(RfidFrequency.lf134kHz.band, 'LF');
      expect(RfidFrequency.hf13_56MHz.band, 'HF');
      expect(RfidFrequency.uhf433MHz.band, 'UHF');
      expect(RfidFrequency.uhf860_960MHz.band, 'UHF');
    });

    test('read ranges are non-empty', () {
      for (final freq in RfidFrequency.values) {
        expect(freq.readRange.isNotEmpty, isTrue);
      }
    });
  });

  group('RfidTag model', () {
    RfidTag makeTag({int rssi = -55}) => RfidTag(
          id: 'test_id',
          epc: 'AABB1122',
          frequency: RfidFrequency.uhf860_960MHz,
          rssi: rssi,
          scannedAt: DateTime.now(),
        );

    test('signalStrength returns Excellent for rssi >= -50', () {
      expect(makeTag(rssi: -45).signalStrength, 'Excellent');
      expect(makeTag(rssi: -50).signalStrength, 'Excellent');
    });

    test('signalStrength returns Good for rssi in [-65, -50]', () {
      expect(makeTag(rssi: -60).signalStrength, 'Good');
      expect(makeTag(rssi: -65).signalStrength, 'Good');
    });

    test('signalStrength returns Fair for rssi in [-80, -65]', () {
      expect(makeTag(rssi: -70).signalStrength, 'Fair');
      expect(makeTag(rssi: -80).signalStrength, 'Fair');
    });

    test('signalStrength returns Weak for rssi < -80', () {
      expect(makeTag(rssi: -85).signalStrength, 'Weak');
    });

    test('equality is based on EPC', () {
      final t1 = makeTag();
      final t2 = RfidTag(
        id: 'other_id',
        epc: 'AABB1122',
        frequency: RfidFrequency.hf13_56MHz,
        rssi: -70,
        scannedAt: DateTime.now(),
      );
      expect(t1, equals(t2));
    });
  });

  group('RfidService', () {
    late RfidService service;

    setUp(() {
      service = RfidService();
    });

    tearDown(() {
      service.dispose();
    });

    test('default frequency is UHF 860–960 MHz', () {
      expect(service.selectedFrequency, RfidFrequency.uhf860_960MHz);
    });

    test('default connection state is disconnected', () {
      expect(service.connectionState,
          ReaderConnectionState.disconnected);
    });

    test('setFrequency changes the selected frequency', () async {
      await service.setFrequency(RfidFrequency.hf13_56MHz);
      expect(service.selectedFrequency, RfidFrequency.hf13_56MHz);
    });

    test('setFrequency is a no-op when frequency unchanged', () async {
      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.setFrequency(RfidFrequency.uhf860_960MHz);
      expect(notifyCount, 0);
    });

    test('connect transitions to connected state', () async {
      await service.connect();
      expect(service.connectionState, ReaderConnectionState.connected);
      expect(service.isConnected, isTrue);
    });

    test('clearTags empties the scanned list', () async {
      // Patch internal list via reflection isn't easy; instead start a
      // very brief scan so we can test clearTags behaviour.
      await service.connect();
      await service.startScan();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await service.stopScan();

      service.clearTags();
      expect(service.scannedTags, isEmpty);
    });

    test('disconnect transitions back to disconnected', () async {
      await service.connect();
      await service.disconnect();
      expect(service.connectionState,
          ReaderConnectionState.disconnected);
    });
  });

  // ── Widget tests ────────────────────────────────────────────────────────────

  group('FrequencySelector widget', () {
    Widget buildWidget({
      RfidFrequency selected = RfidFrequency.uhf860_960MHz,
      bool enabled = true,
      ValueChanged<RfidFrequency>? onChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider(
            create: (_) => RfidService(),
            child: FrequencySelector(
              selectedFrequency: selected,
              onFrequencyChanged: onChanged ?? (_) {},
              enabled: enabled,
            ),
          ),
        ),
      );
    }

    testWidgets('renders all frequency labels', (tester) async {
      await tester.pumpWidget(buildWidget());

      for (final freq in RfidFrequency.values) {
        expect(find.text(freq.label), findsOneWidget);
      }
    });

    testWidgets('renders band section headers', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.text('LF'), findsOneWidget);
      expect(find.text('HF'), findsOneWidget);
      expect(find.text('UHF'), findsOneWidget);
    });

    testWidgets('tapping a chip calls onFrequencyChanged', (tester) async {
      RfidFrequency? selected;
      await tester.pumpWidget(buildWidget(
        selected: RfidFrequency.uhf860_960MHz,
        onChanged: (f) => selected = f,
      ));

      await tester.tap(find.text(RfidFrequency.hf13_56MHz.label));
      await tester.pump();

      expect(selected, RfidFrequency.hf13_56MHz);
    });

    testWidgets('disabled selector does not call onFrequencyChanged',
        (tester) async {
      var called = false;
      await tester.pumpWidget(buildWidget(
        enabled: false,
        onChanged: (_) => called = true,
      ));

      await tester.tap(find.text(RfidFrequency.hf13_56MHz.label));
      await tester.pump();

      expect(called, isFalse);
    });
  });
}
