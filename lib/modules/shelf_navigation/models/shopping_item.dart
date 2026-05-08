import 'dart:ui';

class ShoppingItemLocation {
  final String aisle;
  final String rack;
  final String shelf;
  final String bin;
  final double? x;
  final double? y;

  const ShoppingItemLocation({
    this.aisle = '',
    this.rack = '',
    this.shelf = '',
    this.bin = '',
    this.x,
    this.y,
  });

  Offset? get point {
    if (x == null || y == null) {
      return null;
    }

    return Offset(x!, y!);
  }

  String get summary {
    final parts = <String>[
      if (aisle.isNotEmpty) aisle,
      if (rack.isNotEmpty) rack,
      if (shelf.isNotEmpty) shelf,
      if (bin.isNotEmpty) bin,
    ];

    return parts.join(' / ');
  }

  factory ShoppingItemLocation.fromJson(Map<String, dynamic> json) {
    double? parseCoordinate(Object? value) {
      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse((value ?? '').toString());
    }

    Offset? parseCoordinateString(Object? value) {
      final raw = (value ?? '').toString().trim();
      if (raw.isEmpty) {
        return null;
      }

      final parts = raw.split(',');
      if (parts.length < 2) {
        return null;
      }

      final pointX = parseCoordinate(parts[0].trim());
      final pointY = parseCoordinate(parts[1].trim());
      if (pointX == null || pointY == null) {
        return null;
      }

      return Offset(pointX, pointY);
    }

    Offset? parseCombinedPoint(Object? value) {
      if (value is Map<String, dynamic>) {
        final pointX = parseCoordinate(value['x']);
        final pointY = parseCoordinate(value['y']);
        if (pointX != null && pointY != null) {
          return Offset(pointX, pointY);
        }
      }

      if (value is List && value.length >= 2) {
        final pointX = parseCoordinate(value[0]);
        final pointY = parseCoordinate(value[1]);
        if (pointX != null && pointY != null) {
          return Offset(pointX, pointY);
        }
      }

      return null;
    }

    final combinedPoint = parseCoordinateString(json['coordinate']) ??
        parseCombinedPoint(json['coordinates']);

    return ShoppingItemLocation(
      aisle: (json['aisle'] ?? '').toString(),
      rack: (json['rack'] ?? '').toString(),
      shelf: (json['shelf'] ?? '').toString(),
      bin: (json['bin'] ?? '').toString(),
      x: combinedPoint?.dx ?? parseCoordinate(json['x']),
      y: combinedPoint?.dy ?? parseCoordinate(json['y']),
    );
  }
}

class ShoppingItem {
  final String name;
  final String section;
  final bool picked;
  final ShoppingItemLocation? location;

  const ShoppingItem({
    required this.name,
    required this.section,
    this.picked = false,
    this.location,
  });

  ShoppingItem copyWith({
    String? name,
    String? section,
    bool? picked,
    ShoppingItemLocation? location,
  }) {
    return ShoppingItem(
      name: name ?? this.name,
      section: section ?? this.section,
      picked: picked ?? this.picked,
      location: location ?? this.location,
    );
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final locationJson = json['location'];

    return ShoppingItem(
      name: (json['name'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
      picked: (json['picked'] ?? false) == true,
      location: locationJson is Map<String, dynamic>
          ? ShoppingItemLocation.fromJson(locationJson)
          : null,
    );
  }
}
