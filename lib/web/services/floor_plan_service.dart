import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/floor_node.dart';
import '../models/cart_item.dart';
import 'svg_parser_service.dart';
import 'route_optimizer_service.dart';

/// Central state for the floor plan, cart, and optimised route.
///
/// Consumed via [ChangeNotifierProvider] on the web shell.
class FloorPlanService extends ChangeNotifier {
  // ── SVG floor plan ────────────────────────────────────────────────────────
  Uint8List? _svgBytes;
  Uint8List? get svgBytes => _svgBytes;

  String? _svgFileName;
  String? get svgFileName => _svgFileName;

  // ── Nodes ─────────────────────────────────────────────────────────────────
  final List<FloorNode> _nodes = [];
  List<FloorNode> get nodes => List.unmodifiable(_nodes);

  FloorNode? _startNode;
  FloorNode? get startNode => _startNode;

  // ── Cart ──────────────────────────────────────────────────────────────────
  final List<CartItem> _cart = [];
  List<CartItem> get cart => List.unmodifiable(_cart);

  // ── Route ─────────────────────────────────────────────────────────────────
  OptimizedRoute? _route;
  OptimizedRoute? get route => _route;

  int _currentStep = 0;
  int get currentStep => _currentStep;

  bool get isNavigating => _route != null && _route!.waypoints.isNotEmpty;

  // ── Edit mode ─────────────────────────────────────────────────────────────
  bool _editingNodes = false;
  bool get editingNodes => _editingNodes;

  // ── Services ──────────────────────────────────────────────────────────────
  final _parser = SvgParserService();
  final _optimizer = RouteOptimizerService();

  // ── SVG loading ───────────────────────────────────────────────────────────

  /// Load a new SVG floor plan from raw bytes.  Auto-parses nodes from it.
  void loadSvg(Uint8List bytes, String fileName) {
    _svgBytes = bytes;
    _svgFileName = fileName;
    _route = null;
    _currentStep = 0;

    // Auto-detect nodes from SVG elements that have id attributes.
    final parsed = _parser.parse(bytes);
    _nodes
      ..clear()
      ..addAll(parsed);

    // Reset start node if it no longer exists.
    if (_startNode != null && !_nodes.any((n) => n.id == _startNode!.id)) {
      _startNode = _nodes.isNotEmpty ? _nodes.first : null;
    }

    notifyListeners();
  }

  // ── Node management ───────────────────────────────────────────────────────

  void setEditingNodes(bool value) {
    _editingNodes = value;
    notifyListeners();
  }

  /// Add a manually placed node at a normalised [position].
  void addNode(FloorNode node) {
    if (!_nodes.any((n) => n.id == node.id)) {
      _nodes.add(node);
    }
    notifyListeners();
  }

  void removeNode(String nodeId) {
    _nodes.removeWhere((n) => n.id == nodeId);
    if (_startNode?.id == nodeId) _startNode = null;
    // Unassign from cart items.
    for (var i = 0; i < _cart.length; i++) {
      if (_cart[i].node?.id == nodeId) {
        _cart[i] = _cart[i].copyWith(clearNode: true);
      }
    }
    _route = null;
    notifyListeners();
  }

  void setStartNode(FloorNode node) {
    _startNode = node;
    _route = null;
    notifyListeners();
  }

  void renameNode(String nodeId, String newLabel) {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx >= 0) {
      _nodes[idx] = _nodes[idx].copyWith(label: newLabel);
      notifyListeners();
    }
  }

  // ── Cart management ───────────────────────────────────────────────────────

  void addCartItem(CartItem item) {
    if (!_cart.any((c) => c.id == item.id)) {
      _cart.add(item);
      _route = null;
      notifyListeners();
    }
  }

  void removeCartItem(String itemId) {
    _cart.removeWhere((c) => c.id == itemId);
    _route = null;
    notifyListeners();
  }

  void assignNodeToCartItem(String itemId, FloorNode node) {
    final idx = _cart.indexWhere((c) => c.id == itemId);
    if (idx >= 0) {
      _cart[idx] = _cart[idx].copyWith(node: node);
      _route = null;
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    _route = null;
    _currentStep = 0;
    notifyListeners();
  }

  // ── Route optimisation ────────────────────────────────────────────────────

  /// Run the nearest-neighbour TSP optimiser and cache the result.
  void optimizeRoute() {
    if (_cart.isEmpty) return;
    _route = _optimizer.optimize(
      cartItems: _cart,
      startNode: _startNode,
    );
    _currentStep = 0;
    notifyListeners();
  }

  void nextStep() {
    if (_route == null) return;
    if (_currentStep < _route!.waypoints.length - 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  void prevStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  void resetNavigation() {
    _currentStep = 0;
    notifyListeners();
  }

  void clearRoute() {
    _route = null;
    _currentStep = 0;
    notifyListeners();
  }
}
