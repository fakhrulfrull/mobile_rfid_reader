import 'dart:ui';

class RoutePlanner {
  static List<String> optimizeStops({
    required Offset start,
    required List<String> sections,
    required Map<String, Offset> sectionPoints,
  }) {
    final unique = <String>[];
    final seen = <String>{};

    for (final section in sections) {
      if (seen.add(section) && sectionPoints.containsKey(section)) {
        unique.add(section);
      }
    }

    if (unique.isEmpty) return [];

    final remaining = List<String>.from(unique);
    final ordered = <String>[];
    var current = start;

    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final distanceA = _manhattan(current, sectionPoints[a]!);
        final distanceB = _manhattan(current, sectionPoints[b]!);
        return distanceA.compareTo(distanceB);
      });

      final next = remaining.removeAt(0);
      ordered.add(next);
      current = sectionPoints[next]!;
    }

    return ordered;
  }

  static double _manhattan(Offset a, Offset b) {
    return (a.dx - b.dx).abs() + (a.dy - b.dy).abs();
  }
}
