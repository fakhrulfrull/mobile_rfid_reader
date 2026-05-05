import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rfid_frequency.dart';
import '../services/rfid_service.dart';
import 'scan_screen.dart';

/// A simple settings / info screen that shows details about each frequency.
class FrequencyInfoScreen extends StatelessWidget {
  const FrequencyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Frequency Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: RfidFrequency.values
            .map((f) => _FrequencyInfoCard(frequency: f))
            .toList(),
      ),
    );
  }
}

class _FrequencyInfoCard extends StatelessWidget {
  final RfidFrequency frequency;
  const _FrequencyInfoCard({required this.frequency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final service = context.read<RfidService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await service.setFrequency(frequency);
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ScanScreen(),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      frequency.band,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    frequency.label,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(frequency.description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.straighten,
                      size: 14, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text('Read range: ${frequency.readRange}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colorScheme.outline)),
                  const Spacer(),
                  Text('Tap to select →',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colorScheme.primary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
