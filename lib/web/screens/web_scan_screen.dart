import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/rfid_service.dart';
import '../../widgets/frequency_selector.dart';
import '../services/floor_plan_service.dart';
import '../models/cart_item.dart';

/// Scanner screen adapted for web – adds a "Add to floor plan cart" action
/// for each scanned tag so items flow directly into the route planner.
class WebScanScreen extends StatelessWidget {
  const WebScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RfidService>(
      builder: (context, service, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('RFID Scanner'),
            actions: [
              _ConnectionButton(service: service),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
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
              _StatusBar(service: service),
              if (service.scannedTags.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Tap a tag to add it to the floor plan cart',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: service.scannedTags.isEmpty
                    ? _EmptyState(isScanning: service.isScanning)
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: service.scannedTags.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final tag = service.scannedTags[i];
                          return _WebTagCard(tag: tag);
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: service.isConnected || !service.isScanning
              ? FloatingActionButton.extended(
                  onPressed: () => _toggleScan(context, service),
                  icon: Icon(service.isScanning
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded),
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

// ── Web tag card with "Add to cart" ─────────────────────────────────────────

class _WebTagCard extends StatelessWidget {
  final dynamic tag; // RfidTag
  const _WebTagCard({required this.tag});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final floorPlan = context.read<FloorPlanService>();

    final alreadyInCart = floorPlan.cart.any((c) => c.rfidEpc == tag.epc);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(Icons.nfc, color: colorScheme.onPrimaryContainer),
        ),
        title: Text(tag.epc),
        subtitle: Text(
            '${tag.frequency.label}  ·  RSSI ${tag.rssi} dBm  ·  ${tag.signalStrength}'),
        trailing: alreadyInCart
            ? Chip(
                label: const Text('In cart'),
                avatar: Icon(Icons.check_circle_outline,
                    size: 16, color: colorScheme.primary),
              )
            : IconButton(
                icon: const Icon(Icons.add_shopping_cart_outlined),
                tooltip: 'Add to floor plan cart',
                onPressed: () {
                  floorPlan.addCartItem(CartItem(
                    id: tag.id,
                    name: tag.epc,
                    rfidEpc: tag.epc,
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${tag.epc} added to cart'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ── Reused sub-widgets ───────────────────────────────────────────────────────

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
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case ReaderConnectionState.error:
        return IconButton(
          icon: const Icon(Icons.error_outline),
          color: colorScheme.error,
          tooltip: service.errorMessage ?? 'Error',
          onPressed: null,
        );
      case ReaderConnectionState.disconnected:
        return IconButton(
          icon: const Icon(Icons.bluetooth_outlined),
          tooltip: 'Connect reader',
          onPressed: () => service.connect(),
        );
    }
  }
}

class _StatusBar extends StatelessWidget {
  final RfidService service;
  const _StatusBar({required this.service});

  @override
  Widget build(BuildContext context) {
    String msg;
    Color color;
    final cs = Theme.of(context).colorScheme;

    switch (service.connectionState) {
      case ReaderConnectionState.connected:
        msg = service.isScanning
            ? 'Scanning…  ${service.scannedTags.length} tag(s) found'
            : 'Connected – ready to scan';
        color = cs.primary;
        break;
      case ReaderConnectionState.connecting:
        msg = 'Connecting…';
        color = cs.secondary;
        break;
      case ReaderConnectionState.error:
        msg = service.errorMessage ?? 'Error';
        color = cs.error;
        break;
      case ReaderConnectionState.disconnected:
        msg = 'Disconnected';
        color = cs.onSurfaceVariant;
    }

    return Container(
      width: double.infinity,
      color: color.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(msg,
          style: TextStyle(color: color, fontWeight: FontWeight.w500)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isScanning;
  const _EmptyState({required this.isScanning});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.nfc,
              size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            isScanning ? 'Waiting for tags…' : 'Press Scan to start',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
