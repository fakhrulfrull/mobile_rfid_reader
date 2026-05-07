import 'dart:ui';

class AislePathService {
  static List<Offset> findPath({
    required Offset start,
    required Offset goal,
    required List<Rect> blocked,
    // Grid resolution: each aisle gap (≈0.02 wide) maps to ≥1 passable cell.
    // cols=60 → cell width ≈0.017 (fits one cell per 0.02 aisle gap).
    // rows=40 → cell height ≈0.025 (adequate vertical resolution).
    int cols = 60,
    int rows = 40,
  }) {
    final startX = (start.dx * (cols - 1)).round().clamp(0, cols - 1);
    final startY = (start.dy * (rows - 1)).round().clamp(0, rows - 1);
    final goalX = (goal.dx * (cols - 1)).round().clamp(0, cols - 1);
    final goalY = (goal.dy * (rows - 1)).round().clamp(0, rows - 1);

    final blockedCells = <int>{};
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final point = Offset(x / (cols - 1), y / (rows - 1));
        if (blocked.any((rect) => rect.contains(point))) {
          blockedCells.add(_key(x, y, cols));
        }
      }
    }

    blockedCells.remove(_key(startX, startY, cols));
    blockedCells.remove(_key(goalX, goalY, cols));

    final open = <_Node>[];
    final byKey = <int, _Node>{};
    final closed = <int>{};

    final startNode = _Node(startX, startY,
        g: 0, h: _heuristic(startX, startY, goalX, goalY));
    open.add(startNode);
    byKey[_key(startX, startY, cols)] = startNode;

    while (open.isNotEmpty) {
      open.sort((a, b) => a.f.compareTo(b.f));
      final current = open.removeAt(0);
      final currentKey = _key(current.x, current.y, cols);

      if (current.x == goalX && current.y == goalY) {
        return _reconstruct(current, cols, rows);
      }

      closed.add(currentKey);

      for (final direction in const [
        Offset(1, 0),
        Offset(-1, 0),
        Offset(0, 1),
        Offset(0, -1),
      ]) {
        final nextX = current.x + direction.dx.toInt();
        final nextY = current.y + direction.dy.toInt();

        if (nextX < 0 || nextY < 0 || nextX >= cols || nextY >= rows) {
          continue;
        }

        final nextKey = _key(nextX, nextY, cols);
        if (blockedCells.contains(nextKey) || closed.contains(nextKey)) {
          continue;
        }

        final nextCost = current.g + 1.0;
        final existing = byKey[nextKey];

        if (existing == null || nextCost < existing.g) {
          final node = existing ??
              _Node(
                nextX,
                nextY,
                g: nextCost,
                h: _heuristic(nextX, nextY, goalX, goalY),
                parent: current,
              );
          node.g = nextCost;
          node.parent = current;
          byKey[nextKey] = node;
          if (!open.contains(node)) {
            open.add(node);
          }
        }
      }
    }

    return [start, goal];
  }

  static List<Offset> _reconstruct(_Node end, int cols, int rows) {
    final points = <Offset>[];
    _Node? node = end;
    while (node != null) {
      points.add(Offset(node.x / (cols - 1), node.y / (rows - 1)));
      node = node.parent;
    }
    return points.reversed.toList();
  }

  static double _heuristic(int x, int y, int goalX, int goalY) {
    return (x - goalX).abs() + (y - goalY).abs().toDouble();
  }

  static int _key(int x, int y, int cols) => y * cols + x;
}

class _Node {
  final int x;
  final int y;
  double g;
  final double h;
  _Node? parent;

  _Node(
    this.x,
    this.y, {
    required this.g,
    required this.h,
    this.parent,
  });

  double get f => g + h;
}
