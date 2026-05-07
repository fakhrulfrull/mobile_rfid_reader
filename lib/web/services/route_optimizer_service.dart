import 'dart:math';
import 'dart:ui';
import '../models/floor_node.dart';
import '../models/cart_item.dart';

/// Result of a route optimisation run.
class OptimizedRoute {
  /// Ordered list of nodes to visit (includes start node at index 0).
  final List<FloorNode> waypoints;

  /// Total Euclidean distance of the route (normalised units).
  final double totalDistance;

  const OptimizedRoute({
    required this.waypoints,
    required this.totalDistance,
  });
}

/// Nearest-neighbour TSP heuristic that finds an efficient picking route
/// through the floor-plan nodes required by the cart.
///
/// This approach is O(n²) and gives good practical results for warehouse-
/// scale floor plans (typically < 200 locations).
class RouteOptimizerService {
  /// Build an optimised route.
  ///
  /// [cartItems] – items to pick (only those with an assigned node are used).
  /// [startNode] – the entrance / start position.  If null the first cart
  ///               item's node is used as the starting point.
  OptimizedRoute optimize({
    required List<CartItem> cartItems,
    FloorNode? startNode,
  }) {
    // Collect nodes that need to be visited (deduped by node id).
    final seen = <String>{};
    final targets = <FloorNode>[];
    for (final item in cartItems) {
      if (item.node != null && seen.add(item.node!.id)) {
        targets.add(item.node!);
      }
    }

    if (targets.isEmpty) {
      return OptimizedRoute(
        waypoints: startNode != null ? [startNode] : [],
        totalDistance: 0,
      );
    }

    final start = startNode ?? targets.first;
    final remaining = targets.where((n) => n.id != start.id).toList();

    final route = <FloorNode>[start];
    double total = 0;

    // Nearest-neighbour greedy traversal.
    while (remaining.isNotEmpty) {
      final current = route.last;
      remaining.sort((a, b) => _dist(current.position, a.position)
          .compareTo(_dist(current.position, b.position)));
      final next = remaining.removeAt(0);
      total += _dist(current.position, next.position);
      route.add(next);
    }

    return OptimizedRoute(waypoints: route, totalDistance: total);
  }

  double _dist(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return sqrt(dx * dx + dy * dy);
  }
}
