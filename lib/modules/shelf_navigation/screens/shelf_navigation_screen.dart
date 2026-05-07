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
  Offset _position = const Offset(0.38, 0.92);
  double _heading = 0.0;
  bool _tracking = false;

  final _itemController = TextEditingController();
  final _apiController = TextEditingController();

  List<ShoppingItem> _items = [];
  List<String> _stops = [];
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;

  DateTime _lastStepAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Target = walkable access point in front of / beside each section.
  // Calibrated from store_map.png (1152×765 px, 16:10 ratio).
  final Map<String, Offset> _targets = const {
    // Back-wall counters – stand in the top corridor (y ≈ 0.20)
    'Dairy': Offset(0.12, 0.20),
    'Frozen Foods': Offset(0.32, 0.20),
    'Meat & Seafood': Offset(0.53, 0.20),
    'Deli': Offset(0.73, 0.20),
    'Bakery': Offset(0.92, 0.20),
    // Centre aisles – stand in the inter-shelf aisle at mid height (y ≈ 0.47)
    // Aisle centre-lines (between columns): 0.23, 0.33, 0.43, 0.53, 0.63, 0.73
    'Beverages': Offset(0.13, 0.47), // main left corridor beside col-1
    'Snacks': Offset(0.23, 0.47), // aisle between col-1 and col-2
    'Cereal': Offset(0.33, 0.47), // aisle between col-2 and col-3
    'Pasta & Sauces': Offset(0.43, 0.47), // aisle between col-3 and col-4
    'Canned Goods': Offset(0.53, 0.47), // aisle between col-4 and col-5
    'Condiments': Offset(0.63, 0.47), // aisle between col-5 and col-6
    'Oil & Spices': Offset(0.73, 0.47), // aisle between col-6 and col-7
    // Right-wall sections – stand in corridor left of the right-wall units
    'Fresh Produce': Offset(0.83, 0.30),
    'Organic': Offset(0.83, 0.57),
    'Flowers & Plants': Offset(0.83, 0.77),
    // Checkout – central area in front of the checkout counters
    'Checkout': Offset(0.38, 0.86),
  };

  final Map<String, String> _catalog = const {
    'milk': 'Dairy',
    'cheese': 'Dairy',
    'yogurt': 'Dairy',
    'ice cream': 'Frozen Foods',
    'pizza': 'Frozen Foods',
    'chicken': 'Meat & Seafood',
    'beef': 'Meat & Seafood',
    'bread': 'Bakery',
    'bun': 'Bakery',
    'juice': 'Beverages',
    'soda': 'Beverages',
    'chips': 'Snacks',
    'biscuit': 'Snacks',
    'cereal': 'Cereal',
    'pasta': 'Pasta & Sauces',
    'beans': 'Canned Goods',
    'ketchup': 'Condiments',
    'olive oil': 'Oil & Spices',
    'apple': 'Fresh Produce',
    'banana': 'Fresh Produce',
    'organic oats': 'Organic',
    'flower': 'Flowers & Plants',
  };

  // Non-walkable zones calibrated to store_map.png.
  // Coordinate system: left=0.0, right=1.0 / top=0.0, bottom=1.0.
  // Walkable corridors are the gaps left between these rects.
  final List<Rect> _blocked = const [
    // ── Back-wall counter units (y 0.02 – 0.19) ──────────────────────
    Rect.fromLTWH(0.02, 0.02, 0.21, 0.17), // Dairy counter
    Rect.fromLTWH(0.23, 0.02, 0.17, 0.17), // Frozen Foods counter
    Rect.fromLTWH(0.40, 0.02, 0.21, 0.17), // Meat & Seafood counter
    Rect.fromLTWH(0.61, 0.02, 0.14, 0.17), // Deli counter
    Rect.fromLTWH(0.78, 0.02, 0.20, 0.17), // Bakery counter

    // ── Left-wall shelf units (x 0.01 – 0.13) ────────────────────────
    Rect.fromLTWH(0.01, 0.20, 0.12, 0.13), // Baby Care
    Rect.fromLTWH(0.01, 0.33, 0.12, 0.14), // Household
    Rect.fromLTWH(0.01, 0.47, 0.12, 0.13), // Cleaning
    Rect.fromLTWH(0.01, 0.60, 0.12, 0.15), // Pet Care

    // ── 7 centre shelf columns (x 0.14 – 0.82, y 0.22 – 0.72) ───────
    // Each column 0.08 wide; aisles ≈ 0.02 between each pair.
    Rect.fromLTWH(0.14, 0.22, 0.08, 0.50), // col-1  Beverages
    Rect.fromLTWH(0.24, 0.22, 0.08, 0.50), // col-2  Snacks
    Rect.fromLTWH(0.34, 0.22, 0.08, 0.50), // col-3  Cereal
    Rect.fromLTWH(0.44, 0.22, 0.08, 0.50), // col-4  Pasta & Sauces
    Rect.fromLTWH(0.54, 0.22, 0.08, 0.50), // col-5  Canned Goods
    Rect.fromLTWH(0.64, 0.22, 0.08, 0.50), // col-6  Condiments
    Rect.fromLTWH(0.74, 0.22, 0.08, 0.50), // col-7  Oil & Spices

    // ── Right-wall display units ──────────────────────────────────────
    Rect.fromLTWH(0.84, 0.22, 0.15, 0.31), // Fresh Produce
    Rect.fromLTWH(0.84, 0.55, 0.15, 0.13), // Organic
    Rect.fromLTWH(0.84, 0.70, 0.15, 0.18), // Flowers & Plants + cart bay

    // ── Bottom zone ───────────────────────────────────────────────────
    Rect.fromLTWH(0.01, 0.78, 0.12, 0.20), // Storage room
    // Checkout lanes are walkable – not blocked.
  ];

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
                  aspectRatio: 16 / 10,
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

  _MapPainter({
    required this.user,
    required this.target,
    required this.path,
    required this.heading,
    required this.mapSize,
  });

  Offset _pixel(Offset normalized) {
    return Offset(
        normalized.dx * mapSize.width, normalized.dy * mapSize.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
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
        oldDelegate.path != path;
  }
}
