import 'floor_node.dart';

/// An item in the pick-list cart, optionally linked to a floor node.
class CartItem {
  final String id;
  final String name;
  final String? rfidEpc;

  /// The floor node where this item is located (null = unassigned).
  final FloorNode? node;

  const CartItem({
    required this.id,
    required this.name,
    this.rfidEpc,
    this.node,
  });

  CartItem copyWith({
    String? id,
    String? name,
    String? rfidEpc,
    FloorNode? node,
    bool clearNode = false,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      rfidEpc: rfidEpc ?? this.rfidEpc,
      node: clearNode ? null : (node ?? this.node),
    );
  }

  bool get isAssigned => node != null;

  @override
  bool operator ==(Object other) => other is CartItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
