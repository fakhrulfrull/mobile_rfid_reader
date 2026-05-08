import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/shopping_item.dart';
import '../models/store_layout.dart';
import '../services/aisle_path_service.dart';
import '../services/route_planner.dart';
import '../services/shopping_list_import_service.dart';
import '../widgets/pane_header.dart';
import '../widgets/store_map_panel.dart';

class ShelfNavigationScreen extends StatefulWidget {
  const ShelfNavigationScreen({super.key});

  @override
  State<ShelfNavigationScreen> createState() => _ShelfNavigationScreenState();
}

class _ShelfNavigationScreenState extends State<ShelfNavigationScreen> {
  static const double _minPaneFraction = 0.18;

  Offset _position = StoreLayout.entrance;
  double _heading = 0.0;
  bool _tracking = false;

  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _apiController = TextEditingController();
  final TextEditingController _webUrlController =
      TextEditingController(text: 'https://www.copperandbrass.net/notebooks');

  WebViewController? _webViewController;
  String? _webLoadError;

  double _leftPaneFraction = 0.42;
  PaneViewState _leftPaneState = PaneViewState.normal;
  PaneViewState _rightPaneState = PaneViewState.normal;

  List<ShoppingItem> _items = <ShoppingItem>[];
  List<String> _stops = <String>[];

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  DateTime _lastStepAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _supportsWebView {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  String? get _currentSection => _stops.isEmpty ? null : _stops.first;

  Offset? get _currentTarget {
    final section = _currentSection;
    if (section == null) {
      return null;
    }

    return StoreLayout.targets[section];
  }

  @override
  void initState() {
    super.initState();
    _setupCompass();
    _setupWebView();
  }

  void _setupCompass() {
    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) {
        return;
      }

      setState(() {
        _heading = (heading + 360) % 360;
      });
    });
  }

  void _setupWebView() {
    if (!_supportsWebView) {
      return;
    }

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (!mounted) {
              return;
            }
            setState(() {
              _webLoadError = error.description;
            });
          },
        ),
      );

    _loadWebUrl(_webUrlController.text, clearErrorOnly: true);
  }

  @override
  void dispose() {
    _itemController.dispose();
    _apiController.dispose();
    _webUrlController.dispose();
    _compassSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  Future<void> _loadWebUrl(
    String rawUrl, {
    bool clearErrorOnly = false,
  }) async {
    if (!_supportsWebView || _webViewController == null) {
      return;
    }

    var normalized = rawUrl.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) {
      setState(() {
        _webLoadError = 'Invalid URL: $rawUrl';
      });
      return;
    }

    setState(() {
      _webLoadError = null;
      _webUrlController.text = normalized;
    });

    try {
      await _webViewController!.loadRequest(uri);
    } catch (_) {
      if (!mounted || clearErrorOnly) {
        return;
      }
      setState(() {
        _webLoadError = 'Unable to open $normalized';
      });
    }
  }

  void _toggleFullscreen({required bool isLeftPane}) {
    setState(() {
      if (isLeftPane) {
        _leftPaneState = _leftPaneState == PaneViewState.fullscreen
            ? PaneViewState.normal
            : PaneViewState.fullscreen;
        if (_leftPaneState == PaneViewState.fullscreen) {
          _rightPaneState = PaneViewState.normal;
        }
      } else {
        _rightPaneState = _rightPaneState == PaneViewState.fullscreen
            ? PaneViewState.normal
            : PaneViewState.fullscreen;
        if (_rightPaneState == PaneViewState.fullscreen) {
          _leftPaneState = PaneViewState.normal;
        }
      }
    });
  }

  void _toggleMinimize({required bool isLeftPane}) {
    setState(() {
      if (isLeftPane) {
        _leftPaneState = _leftPaneState == PaneViewState.minimized
            ? PaneViewState.normal
            : PaneViewState.minimized;
        if (_rightPaneState == PaneViewState.fullscreen) {
          _rightPaneState = PaneViewState.normal;
        }
      } else {
        _rightPaneState = _rightPaneState == PaneViewState.minimized
            ? PaneViewState.normal
            : PaneViewState.minimized;
        if (_leftPaneState == PaneViewState.fullscreen) {
          _leftPaneState = PaneViewState.normal;
        }
      }

      if (_leftPaneState == PaneViewState.minimized &&
          _rightPaneState == PaneViewState.minimized) {
        _rightPaneState = PaneViewState.normal;
      }
    });
  }

  void _extendPane({required bool isLeftPane}) {
    setState(() {
      _leftPaneState = PaneViewState.normal;
      _rightPaneState = PaneViewState.normal;

      final delta = isLeftPane ? 0.08 : -0.08;
      _leftPaneFraction = (_leftPaneFraction + delta)
          .clamp(_minPaneFraction, 1 - _minPaneFraction);
    });
  }

  void _dragDivider(double localDx, double width) {
    if (_leftPaneState == PaneViewState.fullscreen ||
        _rightPaneState == PaneViewState.fullscreen) {
      return;
    }

    final fraction =
        (localDx / width).clamp(_minPaneFraction, 1 - _minPaneFraction);

    setState(() {
      _leftPaneState = PaneViewState.normal;
      _rightPaneState = PaneViewState.normal;
      _leftPaneFraction = fraction;
    });
  }

  double _effectiveLeftFraction() {
    if (_leftPaneState == PaneViewState.minimized) {
      return _minPaneFraction;
    }

    if (_rightPaneState == PaneViewState.minimized) {
      return 1 - _minPaneFraction;
    }

    return _leftPaneFraction;
  }

  void _addManualItem() {
    final rawName = _itemController.text.trim();
    if (rawName.isEmpty) {
      return;
    }

    final section = _resolveSection(rawName);
    if (section == null) {
      _showSnack('Could not map "$rawName" to a shelf section.');
      return;
    }

    setState(() {
      _items = <ShoppingItem>[
        ..._items,
        ShoppingItem(name: rawName, section: section),
      ];
      _itemController.clear();
      _rebuildStops();
    });
  }

  String? _resolveSection(String itemName) {
    final normalized = itemName.toLowerCase();
    final exact = StoreLayout.catalog[normalized];
    if (exact != null) {
      return exact;
    }

    for (final entry in StoreLayout.catalog.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry.value;
      }
    }

    return null;
  }

  void _markPicked(int index, bool picked) {
    setState(() {
      _items[index] = _items[index].copyWith(picked: picked);
      _rebuildStops();
    });
  }

  Future<void> _importFromAsset() async {
    try {
      final imported = await ShoppingListImportService.fromAsset(
          'assets/data/sample_shopping_list.json');

      if (!mounted) {
        return;
      }

      setState(() {
        _items = <ShoppingItem>[..._items, ...imported];
        _rebuildStops();
      });

      _showSnack('Imported ${imported.length} item(s) from JSON asset.');
    } catch (error) {
      _showSnack('Import failed: $error');
    }
  }

  Future<void> _importFromApi() async {
    final url = _apiController.text.trim();
    if (url.isEmpty) {
      _showSnack('Please enter an API URL.');
      return;
    }

    try {
      final imported = await ShoppingListImportService.fromApi(url);
      if (!mounted) {
        return;
      }

      setState(() {
        _items = <ShoppingItem>[..._items, ...imported];
        _rebuildStops();
      });

      _showSnack('Imported ${imported.length} item(s) from API.');
    } catch (error) {
      _showSnack('API import failed: $error');
    }
  }

  void _toggleTracking() {
    if (_tracking) {
      _accelSub?.cancel();
      _accelSub = null;

      setState(() {
        _tracking = false;
      });
      return;
    }

    _accelSub = userAccelerometerEventStream().listen((event) {
      if (!_tracking) {
        return;
      }

      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      final now = DateTime.now();
      final enoughTimePassed = now.difference(_lastStepAt).inMilliseconds > 450;

      if (magnitude > 1.2 && enoughTimePassed) {
        _lastStepAt = now;
        _stepForward();
      }
    });

    setState(() {
      _tracking = true;
      _lastStepAt = DateTime.now();
    });
  }

  void _stepForward() {
    const stepDistance = 0.016;

    final radians = _heading * math.pi / 180.0;
    final candidate = Offset(
      _position.dx + math.sin(radians) * stepDistance,
      _position.dy - math.cos(radians) * stepDistance,
    );

    if (!_isWalkable(candidate)) {
      return;
    }

    setState(() {
      _position = candidate;
      _rebuildStops();
    });
  }

  bool _isWalkable(Offset point) {
    if (point.dx < 0 || point.dx > 1 || point.dy < 0 || point.dy > 1) {
      return false;
    }

    return !StoreLayout.blocked.any((rect) => rect.contains(point));
  }

  void _rebuildStops() {
    final pendingSections = _items
        .where((item) => !item.picked)
        .map((item) => item.section)
        .toList(growable: false);

    _stops = RoutePlanner.optimizeStops(
      start: _position,
      sections: pendingSections,
      sectionPoints: StoreLayout.targets,
    );
  }

  String _turnInstruction() {
    final target = _currentTarget;
    if (target == null) {
      return 'No active target';
    }

    final distance = (target - _position).distance;
    if (distance < 0.03) {
      return 'Arrived';
    }

    final bearing = _bearingTo(_position, target);
    final delta = _shortestAngle(bearing - _heading);

    if (delta.abs() <= 15) {
      return 'Go straight';
    }

    if (delta > 0) {
      return 'Turn right ${delta.abs().round()} deg';
    }

    return 'Turn left ${delta.abs().round()} deg';
  }

  double _bearingTo(Offset from, Offset to) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    return (math.atan2(dx, -dy) * 180 / math.pi + 360) % 360;
  }

  double _shortestAngle(double angle) {
    var normalized = angle % 360;
    if (normalized > 180) {
      normalized -= 360;
    }
    if (normalized < -180) {
      normalized += 360;
    }
    return normalized;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildWebPane() {
    return Column(
      children: [
        PaneHeader(
          title: 'Web View',
          isLeftPane: true,
          paneState: _leftPaneState,
          onToggleMinimize: () => _toggleMinimize(isLeftPane: true),
          onExtend: () => _extendPane(isLeftPane: true),
          onToggleFullscreen: () => _toggleFullscreen(isLeftPane: true),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _webUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Web URL',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: _loadWebUrl,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _loadWebUrl(_webUrlController.text),
                child: const Text('Go'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildWebContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebContent() {
    if (!_supportsWebView) {
      return const ColoredBox(
        color: Color(0xFFF2F3F6),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'WebView is available on Android, iOS, and macOS in this app.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_webLoadError != null) {
      return ColoredBox(
        color: const Color(0xFFF2F3F6),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _webLoadError!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_webViewController == null) {
      return const ColoredBox(
        color: Color(0xFFF2F3F6),
        child: SizedBox.expand(),
      );
    }

    return WebViewWidget(controller: _webViewController!);
  }

  Widget _buildNavigationPane() {
    final target = _currentTarget;
    final path = target == null
        ? <Offset>[]
        : AislePathService.findPath(
            start: _position,
            goal: target,
            blocked: StoreLayout.blocked,
          );

    return Column(
      children: [
        PaneHeader(
          title: 'Shelf Navigation',
          isLeftPane: false,
          paneState: _rightPaneState,
          onToggleMinimize: () => _toggleMinimize(isLeftPane: false),
          onExtend: () => _extendPane(isLeftPane: false),
          onToggleFullscreen: () => _toggleFullscreen(isLeftPane: false),
        ),
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
              'Heading ${_heading.toStringAsFixed(0)} deg | ${_turnInstruction()}'
              '${_currentSection != null ? ' | Next: $_currentSection' : ''}',
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
            child: StoreMapPanel(
              user: _position,
              target: target,
              path: path,
              heading: _heading,
              entrance: StoreLayout.entrance,
              exit1: StoreLayout.exit1,
              exit2: StoreLayout.exit2,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shelf Navigation')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final leftFullscreen = _leftPaneState == PaneViewState.fullscreen;
          final rightFullscreen = _rightPaneState == PaneViewState.fullscreen;

          if (leftFullscreen) {
            return _buildWebPane();
          }

          if (rightFullscreen) {
            return _buildNavigationPane();
          }

          final leftFraction = _effectiveLeftFraction();
          final rightFraction = 1 - leftFraction;

          return Row(
            children: [
              SizedBox(
                width: constraints.maxWidth * leftFraction,
                child: _buildWebPane(),
              ),
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  _dragDivider(
                    details.globalPosition.dx,
                    constraints.maxWidth,
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: Container(
                    width: 10,
                    color: Colors.black.withOpacity(0.08),
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: constraints.maxWidth * rightFraction - 10,
                child: _buildNavigationPane(),
              ),
            ],
          );
        },
      ),
    );
  }
}
