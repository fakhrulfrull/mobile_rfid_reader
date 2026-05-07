import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rfid_frequency.dart';
import '../models/rfid_tag.dart';
import '../services/rfid_service.dart';
import '../widgets/frequency_selector.dart';
import '../modules/shelf_navigation/screens/shelf_navigation_screen.dart';

/// Main screen that shows the frequency picker, connection controls, and
/// the live list of scanned RFID tags.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RfidService>(
      builder: (context, service, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('RFID Reader'),
            actions: [
              IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Shelf Navigation',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ShelfNavigationScreen(),
                    ),
                  );
                },
              ),
              _ConnectionButton(service: service),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // ── Frequency selector ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: FrequencySelector(
                  selectedFrequency: service.selectedFrequency,
                  onFrequencyChanged: (freq) =>
                      context.read<RfidService>().setFrequency(freq),
                  supportedFrequencies: service.supportedFrequencies.toSet(),
                  enabled: !service.isScanning,
                ),
              ),

              // ── Status bar ──────────────────────────────────────────────
              _StatusBar(service: service),

              // ── Tag list ────────────────────────────────────────────────
              Expanded(
                child: service.scannedTags.isEmpty
                    ? _EmptyState(isScanning: service.isScanning)
                    : _TagList(tags: service.scannedTags),
              ),
            ],
          ),

          // ── FAB: start / stop scan ──────────────────────────────────────
          floatingActionButton: service.isConnected || !service.isScanning
              ? FloatingActionButton.extended(
                  onPressed: () => _toggleScan(context, service),
                  icon: Icon(
                    service.isScanning
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(service.isScanning ? 'Stop' : 'Scan'),
                  backgroundColor: service.isScanning
                      ? Theme.of(context).colorScheme.errorContainer
                      : null,
                  foregroundColor: service.isScanning
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : null,
                )
              : null,
        );
      },
    );
  }

  Future<void> _toggleScan(BuildContext context, RfidService service) async {
    if (service.isScanning) {
      await service.stopScan();
    } else {
      await service.startScan();
    }
  }
}

// ── Connection button ────────────────────────────────────────────────────────

class _ConnectionButton extends StatelessWidget {
  final RfidService service;
  const _ConnectionButton({required this.service});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (service.connectionState) {
      case ReaderConnectionState.connected:
        return IconButton(
          icon: const Icon(Icons.bluetooth_connected),
          color: colorScheme.primary,
          tooltip: 'Connected – tap to disconnect',
          onPressed: () => service.disconnect(),
        );
      case ReaderConnectionState.connecting:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case ReaderConnectionState.error:
        return IconButton(
          icon: const Icon(Icons.bluetooth_disabled),
          color: colorScheme.error,
          tooltip: 'Error – tap to reconnect',
          onPressed: () => service.connect(),
        );
      case ReaderConnectionState.disconnected:
        return IconButton(
          icon: const Icon(Icons.bluetooth),
          tooltip: 'Connect reader',
          onPressed: () => service.connect(),
        );
    }
  }
}

// ── Status bar ───────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final RfidService service;
  const _StatusBar({required this.service});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final error = service.errorMessage;
    if (error != null) {
      return Container(
        width: double.infinity,
        color: colorScheme.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                size: 16, color: colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(error,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onErrorContainer)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Scanning indicator
          if (service.isScanning) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text('Scanning on ${service.selectedFrequency.label}…',
                style: theme.textTheme.bodySmall),
          ] else ...[
            Icon(Icons.info_outline, size: 14, color: colorScheme.outline),
            const SizedBox(width: 8),
            Text(
              service.isConnected
                  ? 'Ready – press Scan to start'
                  : 'Not connected',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.outline),
            ),
          ],
          const Spacer(),
          // Tag count + clear button
          if (service.scannedTags.isNotEmpty) ...[
            Text(
              '${service.scannedTags.length} tag(s)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => context.read<RfidService>().clearTags(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.delete_outline,
                    size: 16, color: colorScheme.outline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isScanning;
  const _EmptyState({required this.isScanning});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isScanning ? Icons.radar : Icons.wifi_tethering_off,
            size: 72,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            isScanning
                ? 'Waiting for tags…'
                : 'No tags scanned yet.\nSelect a frequency and press Scan.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

// ── Tag list ──────────────────────────────────────────────────────────────────

class _TagList extends StatelessWidget {
  final List<RfidTag> tags;
  const _TagList({required this.tags});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: tags.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _TagCard(tag: tags[index]),
    );
  }
}

class _TagCard extends StatelessWidget {
  final RfidTag tag;
  const _TagCard({required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final signalColor = switch (tag.signalStrength) {
      'Excellent' => Colors.green,
      'Good' => Colors.lightGreen,
      'Fair' => Colors.orange,
      _ => Colors.red,
    };

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Signal icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: signalColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.nfc, color: signalColor, size: 22),
            ),
            const SizedBox(width: 12),
            // Tag details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.epc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Pill(
                        label: tag.frequency.label,
                        color: colorScheme.primaryContainer,
                        textColor: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      _Pill(
                        label: '${tag.rssi} dBm',
                        color: signalColor.withOpacity(0.15),
                        textColor: signalColor,
                      ),
                      const SizedBox(width: 6),
                      _Pill(
                        label: tag.signalStrength,
                        color: signalColor.withOpacity(0.15),
                        textColor: signalColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(tag.scannedAt),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
