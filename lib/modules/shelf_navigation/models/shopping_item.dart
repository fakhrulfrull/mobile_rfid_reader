class ShoppingItem {
  final String name;
  final String section;
  final bool picked;

  const ShoppingItem({
    required this.name,
    required this.section,
    this.picked = false,
  });

  ShoppingItem copyWith({
    String? name,
    String? section,
    bool? picked,
  }) {
    return ShoppingItem(
      name: name ?? this.name,
      section: section ?? this.section,
      picked: picked ?? this.picked,
    );
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      name: (json['name'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
      picked: (json['picked'] ?? false) == true,
    );
  }
}
