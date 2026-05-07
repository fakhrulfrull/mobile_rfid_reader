import 'dart:ui';

/// Represents a named location node on the floor plan SVG canvas.
class FloorNode {
  final String id;
  final String label;

  /// Normalized position [0.0–1.0] relative to SVG viewport width/height.
  final Offset position;

  const FloorNode({
    required this.id,
    required this.label,
    required this.position,
  });

  FloorNode copyWith({String? id, String? label, Offset? position}) {
    return FloorNode(
      id: id ?? this.id,
      label: label ?? this.label,
      position: position ?? this.position,
    );
  }

  @override
  bool operator ==(Object other) => other is FloorNode && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
