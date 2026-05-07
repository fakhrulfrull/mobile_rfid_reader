import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/shopping_item.dart';
import '../services/aisle_path_service.dart';
import '../services/route_planner.dart';
import '../services/shopping_list_import_service.dart';

class ShelfNavigationScreen extends StatefulWidget {
  const ShelfNavigationScreen({super.key});

  @override
  State<ShelfNavigationScreen> createState() => _ShelfNavigationScreenState();
}

class _ShelfNavigationScreenState extends State<ShelfNavigationScreen> {
  // Spawn just inside the ENTRANCE gate (bottom-centre-left of new map).
  Offset _position = const Offset(0.28, 0.90);
  double _heading = 0.0;
  bool _tracking = false;

  final _itemController = TextEditingController();
  final _apiController = TextEditingController();

  List<ShoppingItem> _items = [];
  List<String> _stops = [];
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;

  DateTime _lastStepAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Target = walkable access point calibrated to new 1536×1024 (3:2) map.
  final Map<String, Offset> _targets = const {
    // ── Back-wall counters: stand in the top corridor (y ≈ 0.19) ──────
    'Dairy': Offset(0.17, 0.19),
    'Frozen Foods': Offset(0.34, 0.19),
    'Meat & Seafood': Offset(0.52, 0.19),
    'Deli': Offset(0.70, 0.19),
    'Bakery': Offset(0.86, 0.19),
    // ── Left-wall units: stand in the right-side aisle of each unit ───
    'Baby Care': Offset(0.16, 0.23),
    'Household': Offset(0.16, 0.34),
    'Cleaning': Offset(0.16, 0.46),
    'Pet Care': Offset(0.16, 0.59),
    // ── Centre shelves: stand in the aisle gap next to each column ────
    // Left corridor  → Beverages (left side of col-1)
    'Beverages': Offset(0.14, 0.44),
    // Aisle col-1/col-2 → Snacks
    'Snacks': Offset(0.265, 0.44),
    // Aisle col-2/col-3 → Cereal
    'Cereal': Offset(0.37, 0.44),
    // Aisle col-3/col-4 → Pasta & Sauces
    'Pasta & Sauces': Offset(0.47, 0.44),
    // Aisle col-4/col-5 → Canned Goods
    'Canned Goods': Offset(0.57, 0.44),
    // Aisle col-5/col-6 → Condiments
    'Condiments': Offset(0.67, 0.44),
    // Right aisle before right-wall units → Oil & Spices
    'Oil & Spices': Offset(0.845, 0.44),
    // ── Right-wall units: stand in the corridor to the left ───────────
    'Fresh Produce': Offset(0.84, 0.28),
    'Organic': Offset(0.84, 0.50),
    'Flowers & Plants': Offset(0.84, 0.67),
    // ── Self Checkout & EXIT: stand in front of gates ─────────────────
    'Checkout': Offset(0.50, 0.88),
  };

  final Map<String, String> _catalog = const {
    // Dairy
    'milk': 'Dairy', 'cheese': 'Dairy', 'yogurt': 'Dairy', 'butter': 'Dairy',
    // Frozen Foods
    'ice cream': 'Frozen Foods', 'pizza': 'Frozen Foods',
    'frozen meal': 'Frozen Foods',
    // Meat & Seafood
    'chicken': 'Meat & Seafood', 'beef': 'Meat & Seafood',
    'fish': 'Meat & Seafood', 'salmon': 'Meat & Seafood',
    'prawn': 'Meat & Seafood',
    // Bakery
    'bread': 'Bakery', 'bun': 'Bakery', 'croissant': 'Bakery', 'cake': 'Bakery',
    // Beverages
    'juice': 'Beverages', 'soda': 'Beverages', 'water': 'Beverages',
    'coffee': 'Beverages', 'tea': 'Beverages',
    // Snacks
    'chips': 'Snacks', 'biscuit': 'Snacks', 'chocolate': 'Snacks',
    'nuts': 'Snacks', 'popcorn': 'Snacks',
    // Cereal
    'cereal': 'Cereal', 'oats': 'Cereal', 'granola': 'Cereal',
    // Pasta & Sauces
    'pasta': 'Pasta & Sauces', 'noodle': 'Pasta & Sauces',
    'tomato sauce': 'Pasta & Sauces', 'pesto': 'Pasta & Sauces',
    // Canned Goods
    'beans': 'Canned Goods', 'tuna can': 'Canned Goods',
    'canned tomato': 'Canned Goods', 'soup': 'Canned Goods',
    // Condiments
    'ketchup': 'Condiments', 'mustard': 'Condiments',
    'mayonnaise': 'Condiments', 'soy sauce': 'Condiments',
    // Oil & Spices
    'olive oil': 'Oil & Spices', 'salt': 'Oil & Spices',
    'pepper': 'Oil & Spices', 'vinegar': 'Oil & Spices',
    // Fresh Produce
    'apple': 'Fresh Produce', 'banana': 'Fresh Produce',
    'lettuce': 'Fresh Produce', 'tomato': 'Fresh Produce',
    'carrot': 'Fresh Produce', 'onion': 'Fresh Produce',
    // Organic
    'organic oats': 'Organic', 'organic milk': 'Organic',
    'organic eggs': 'Organic', 'organic juice': 'Organic',
    // Flowers & Plants
    'flower': 'Flowers & Plants', 'plant': 'Flowers & Plants',
    'rose': 'Flowers & Plants', 'pot plant': 'Flowers & Plants',
    // Left-wall sections
    'diapers': 'Baby Care', 'baby food': 'Baby Care', 'wipes': 'Baby Care',
    'detergent': 'Household', 'tissue': 'Household', 'trash bag': 'Household',
    'bleach': 'Cleaning', 'mop': 'Cleaning', 'sponge': 'Cleaning',
    'dog food': 'Pet Care', 'cat food': 'Pet Care', 'pet toy': 'Pet Care',
  };

  // Non-walkable zones calibrated to new 1536×1024 (3:2) store map.
  // Each rect: fromLTWH(left, top, width, height) in 0.0–1.0 normalised coords.
  final List<Rect> _blocked = const [
    // ── Back-wall counter units ───────────────────────────────────────
    Rect.fromLTWH(0.09, 0.02, 0.16, 0.15), // Dairy
    Rect.fromLTWH(0.27, 0.02, 0.14, 0.15), // Frozen Foods
    Rect.fromLTWH(0.42, 0.02, 0.21, 0.15), // Meat & Seafood
    Rect.fromLTWH(0.64, 0.02, 0.13, 0.15), // Deli
    Rect.fromLTWH(0.78, 0.02, 0.17, 0.15), // Bakery

    // ── Left-wall shelf units ─────────────────────────────────────────
    Rect.fromLTWH(0.01, 0.17, 0.13, 0.12), // Baby Care
    Rect.fromLTWH(0.01, 0.29, 0.13, 0.12), // Household
    Rect.fromLTWH(0.01, 0.41, 0.13, 0.12), // Cleaning
    Rect.fromLTWH(0.01, 0.53, 0.13, 0.13), // Pet Care

    // ── 7 centre shelf columns ────────────────────────────────────────
    // Column width ≈ 0.08; aisle gap ≈ 0.025 between each pair.
    Rect.fromLTWH(0.17, 0.18, 0.08, 0.52), // col-1  Beverages
    Rect.fromLTWH(0.28, 0.18, 0.08, 0.52), // col-2  Snacks
    Rect.fromLTWH(0.38, 0.18, 0.08, 0.52), // col-3  Cereal
    Rect.fromLTWH(0.48, 0.18, 0.08, 0.52), // col-4  Pasta & Sauces
    Rect.fromLTWH(0.58, 0.18, 0.08, 0.52), // col-5  Canned Goods
    Rect.fromLTWH(0.68, 0.18, 0.08, 0.52), // col-6  Condiments
    Rect.fromLTWH(0.77, 0.18, 0.07, 0.52), // col-7  Oil & Spices

    // ── Right-wall display units ──────────────────────────────────────
    Rect.fromLTWH(0.86, 0.13, 0.13, 0.31), // Fresh Produce
    Rect.fromLTWH(0.86, 0.44, 0.13, 0.15), // Organic
    Rect.fromLTWH(0.86, 0.59, 0.13, 0.19), // Flowers & Plants
    Rect.fromLTWH(0.87, 0.78, 0.12, 0.15), // Cart rack

    // ── Bottom-left: Smart Trolley display ───────────────────────────
    Rect.fromLTWH(0.01, 0.68, 0.23, 0.30),

    // ── Self-Checkout gate structure (non-walkable kiosk body) ────────
    Rect.fromLTWH(0.43, 0.72, 0.16, 0.09),

    // ── Info panels: "How It Works" + "Need Help" ─────────────────────
    Rect.fromLTWH(0.68, 0.73, 0.17, 0.17),
    Rect.fromLTWH(0.84, 0.80, 0.15, 0.12),
  ];

  // Fixed landmark positions for overlay rendering.
  static const Offset _entrance = Offset(0.28, 0.90);
  static const Offset _exit1 = Offset(0.47, 0.77);
  static const Offset _exit2 = Offset(0.52, 0.77);

  @override
  void initState() {
    super.initState();
    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null) return;
      setState(() => _heading = (heading + 360) % 360);
    });
  }

  @override
  void dispose() {
    _itemController.dispose();
    _apiController.dispose();
    _compassSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  void _rebuildStops() {
    final pendingSections = _items
        .where((item) => !item.picked)
        .map((item) => item.section)
        .toList();

    _stops = RoutePlanner.optimizeStops(
      start: _position,
      sections: pendingSections,
      sectionPoints: _targets,
    );
  }

  String? get _currentSection => _stops.isEmpty ? null : _stops.first;

  Offset? get _currentTarget {
    final section = _currentSection;
    return section == null ? null : _targets[section];
  }

  void _addManualItem() {
    final raw = _itemController.text.trim();
    if (raw.isEmpty) return;

    final section = _catalog[raw.toLowerCase()];
    if (section == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No section mapping for "$raw".')),
      );
      return;
    }

    setState(() {
      _items = [..._items, ShoppingItem(name: raw, section: section)];
      _itemController.clear();
      _rebuildStops();
    });
  }

  Future<void> _importFromAsset() async {
    try {
      final imported = await ShoppingListImportService.fromAsset(
        'assets/data/sample_shopping_list.json',
      );
      setState(() {
        _items = [..._items, ...imported];
        _rebuildStops();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import from asset failed: $error')),
      );
    }
  }

  Future<void> _importFromApi() async {
    final url = _apiController.text.trim();
    if (url.isEmpty) return;

    try {
      final imported = await ShoppingListImportService.fromApi(url);
      setState(() {
        _items = [..._items, ...imported];
        _rebuildStops();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import from API failed: $error')),
      );
    }
  }

  void _toggleTracking() {
    if (_tracking) {
      _accelSub?.cancel();
      _accelSub = null;
      setState(() => _tracking = false);
      return;
    }

    _accelSub = userAccelerometerEventStream().listen((event) {
      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      final now = DateTime.now();
      if (magnitude > 1.25 &&
          now.difference(_lastStepAt).inMilliseconds > 320) {
        _lastStepAt = now;
        _applyStep();
      }
    });

    setState(() => _tracking = true);
  }

  void _applyStep() {
    const step = 0.012;
    final radians = _heading * math.pi / 180.0;

    setState(() {
      _position = Offset(
        (_position.dx + math.sin(radians) * step).clamp(0.02, 0.98),
        (_position.dy - math.cos(radians) * step).clamp(0.02, 0.98),
      );
    });

    _checkArrival();
  }

  void _checkArrival() {
    final section = _currentSection;
    final target = _currentTarget;
    if (section == null || target == null) return;

    if ((_position - target).distance < 0.03) {
      final itemIndex =
          _items.indexWhere((item) => item.section == section && !item.picked);
      if (itemIndex >= 0) {
        setState(() {
          _items[itemIndex] = _items[itemIndex].copyWith(picked: true);
          _rebuildStops();
        });
      }
    }
  }

  void _markPicked(int index, bool picked) {
    setState(() {
      _items[index] = _items[index].copyWith(picked: picked);
      _rebuildStops();
    });
  }

  String _turnInstruction() {
    final target = _currentTarget;
    if (target == null) return 'No pending target';

    final desired = _bearingTo(_position, target);
    final diff = _shortestAngle(desired - _heading);

    if (diff.abs() < 15) return 'Go straight';
    return diff > 0 ? 'Turn right' : 'Turn left';
  }

  double _bearingTo(Offset from, Offset to) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    return (math.atan2(dx, -dy) * 180 / math.pi + 360) % 360;
  }

  double _shortestAngle(double angle) {
    var normalized = angle % 360;
    if (normalized > 180) normalized -= 360;
    if (normalized < -180) normalized += 360;
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final target = _currentTarget;
    final path = target == null
        ? <Offset>[]
        : AislePathService.findPath(
            start: _position,
            goal: target,
            blocked: _blocked,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Shelf Navigation')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: const InputDecoration(
                      labelText: 'Add item',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addManualItem(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addManualItem,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: _importFromAsset,
                  child: const Text('Import JSON'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _apiController,
                    decoration: const InputDecoration(
                      hintText: 'https://api.example.com/shopping-list',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _importFromApi,
                  child: const Text('Import API'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _toggleTracking,
                  icon: Icon(_tracking ? Icons.stop : Icons.play_arrow),
                  label: Text(_tracking ? 'Stop' : 'Start'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Heading ${_heading.toStringAsFixed(0)}° • ${_turnInstruction()}'
                '${_currentSection != null ? ' • Next: $_currentSection' : ''}',
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _stops.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('${index + 1}. ${_stops[index]}'),
                  backgroundColor: index == 0 ? Colors.blue.shade50 : null,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 3 / 2, // new map is 1536×1024
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset('assets/images/store_map.png',
                              fit: BoxFit.cover),
                          CustomPaint(
                            painter: _MapPainter(
                              user: _position,
                              target: target,
                              path: path,
                              heading: _heading,
                              mapSize: size,
                              entrance: _ShelfNavigationScreenState._entrance,
                              exit1: _ShelfNavigationScreenState._exit1,
                              exit2: _ShelfNavigationScreenState._exit2,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return CheckboxListTile(
                  dense: true,
                  value: item.picked,
                  onChanged: (value) => _markPicked(index, value ?? false),
                  title: Text(item.name),
                  subtitle: Text(item.section),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final Offset user;
  final Offset? target;
  final List<Offset> path;
  final double heading;
  final Size mapSize;
  final Offset entrance;
  final Offset exit1;
  final Offset exit2;

  _MapPainter({
    required this.user,
    required this.target,
    required this.path,
    required this.heading,
    required this.mapSize,
    required this.entrance,
    required this.exit1,
    required this.exit2,
  });

  Offset _pixel(Offset normalized) {
    return Offset(
        normalized.dx * mapSize.width, normalized.dy * mapSize.height);
  }

  void _drawLandmarkPin(
    Canvas canvas,
    Offset normalized,
    Color color,
    String label,
  ) {
    final p = _pixel(normalized);
    final paint = Paint()..color = color;
    // Circle base
    canvas.drawCircle(p, 9, paint);
    canvas.drawCircle(
        p,
        9,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(p.dx - tp.width / 2, p.dy - tp.height / 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── Entrance & Exit landmarks ──────────────────────────────────────
    _drawLandmarkPin(canvas, entrance, Colors.green.shade700, 'IN');
    _drawLandmarkPin(canvas, exit1, Colors.red.shade700, 'OUT');
    _drawLandmarkPin(canvas, exit2, Colors.red.shade700, 'OUT');

    if (path.length > 1) {
      final route = Path();
      final first = _pixel(path.first);
      route.moveTo(first.dx, first.dy);
      for (var i = 1; i < path.length; i++) {
        final point = _pixel(path[i]);
        route.lineTo(point.dx, point.dy);
      }

      canvas.drawPath(
        route,
        Paint()
          ..color = Colors.cyanAccent.withOpacity(0.9)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }

    if (target != null) {
      canvas.drawCircle(_pixel(target!), 7, Paint()..color = Colors.redAccent);
    }

    final userPoint = _pixel(user);
    canvas.drawCircle(userPoint, 7, Paint()..color = Colors.blueAccent);

    final radians = heading * math.pi / 180.0;
    final tip = Offset(
      userPoint.dx + math.sin(radians) * 22,
      userPoint.dy - math.cos(radians) * 22,
    );

    canvas.drawLine(
      userPoint,
      tip,
      Paint()
        ..color = Colors.blueAccent
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) {
    return oldDelegate.user != user ||
        oldDelegate.target != target ||
        oldDelegate.heading != heading ||
        oldDelegate.path != path ||
        oldDelegate.entrance != entrance ||
        oldDelegate.exit1 != exit1 ||
        oldDelegate.exit2 != exit2;
  }
}
