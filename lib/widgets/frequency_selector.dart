import 'package:flutter/material.dart';

import '../models/rfid_frequency.dart';

/// A card-based frequency selector.
///
/// Displays each [RfidFrequency] as a tappable chip.  The currently
/// selected frequency is highlighted with the theme's primary colour.
class FrequencySelector extends StatelessWidget {
  final RfidFrequency selectedFrequency;
  final ValueChanged<RfidFrequency> onFrequencyChanged;
  final bool enabled;

  const FrequencySelector({
    super.key,
    required this.selectedFrequency,
    required this.onFrequencyChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Group frequencies by band so we can add section headers.
    final bands = <String, List<RfidFrequency>>{};
    for (final freq in RfidFrequency.values) {
      bands.putIfAbsent(freq.band, () => []).add(freq);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wifi_tethering,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Frequency',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...bands.entries.map((entry) => _BandSection(
                  bandName: entry.key,
                  frequencies: entry.value,
                  selectedFrequency: selectedFrequency,
                  onFrequencyChanged: enabled ? onFrequencyChanged : (_) {},
                  enabled: enabled,
                )),
          ],
        ),
      ),
    );
  }
}

class _BandSection extends StatelessWidget {
  final String bandName;
  final List<RfidFrequency> frequencies;
  final RfidFrequency selectedFrequency;
  final ValueChanged<RfidFrequency> onFrequencyChanged;
  final bool enabled;

  const _BandSection({
    required this.bandName,
    required this.frequencies,
    required this.selectedFrequency,
    required this.onFrequencyChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Band header chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              bandName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: frequencies
                .map((freq) => _FrequencyChip(
                      frequency: freq,
                      isSelected: freq == selectedFrequency,
                      onTap: () => onFrequencyChanged(freq),
                      enabled: enabled,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  final RfidFrequency frequency;
  final bool isSelected;
  final VoidCallback onTap;
  final bool enabled;

  const _FrequencyChip({
    required this.frequency,
    required this.isSelected,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: '${frequency.description}\nRange: ${frequency.readRange}',
      child: ChoiceChip(
        label: Text(frequency.label),
        selected: isSelected,
        onSelected: enabled ? (_) => onTap() : null,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : enabled
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withOpacity(0.4),
          fontWeight:
              isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        avatar: isSelected
            ? Icon(Icons.check, size: 16, color: colorScheme.onPrimaryContainer)
            : null,
      ),
    );
  }
}
