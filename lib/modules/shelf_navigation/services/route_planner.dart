import 'dart:ui';

import '../models/shopping_item.dart';

class RoutePlanner {
  static List<ShoppingItem> optimizeStops({
    required Offset start,
    required List<ShoppingItem> items,
    required Offset? Function(ShoppingItem item) targetOf,
  }) {
    final remaining = items.where((item) => targetOf(item) != null).toList();
    final ordered = <ShoppingItem>[];
    var current = start;

    if (remaining.isEmpty) {
      return ordered;
    }

    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final distanceA = _manhattan(current, targetOf(a)!);
        final distanceB = _manhattan(current, targetOf(b)!);
        return distanceA.compareTo(distanceB);
      });

      final next = remaining.removeAt(0);
      ordered.add(next);
      current = targetOf(next)!;
    }

    return ordered;
  }

  static double _manhattan(Offset a, Offset b) {
    return (a.dx - b.dx).abs() + (a.dy - b.dy).abs();
  }
}
