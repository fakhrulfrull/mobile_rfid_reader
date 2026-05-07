import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../web/models/floor_node.dart';
import '../../web/services/floor_plan_service.dart';
import '../../web/services/route_optimizer_service.dart';

/// Interactive SVG canvas that renders the floor plan, node markers,
/// and the optimised route overlay.
///
/// The canvas is wrapped in [InteractiveViewer] for pan/zoom.
/// When [editingNodes] is true, tapping an empty area creates a new node.
class FloorPlanCanvas extends StatefulWidget {
  final FloorPlanService service;

  const FloorPlanCanvas({super.key, required this.service});

  @override
  State<FloorPlanCanvas> createState() => _FloorPlanCanvasState();
}

class _FloorPlanCanvasState extends State<FloorPlanCanvas>
    with SingleTickerProviderStateMixin {
  final _transformController = TransformationController();

  // Animation for the route marker travelling between waypoints.
  late AnimationController _markerAnim;
  late Animation<double> _markerT;

  final _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _markerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _markerT = CurvedAnimation(parent: _markerAnim, curve: Curves.easeInOut);
    widget.service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    _markerAnim.dispose();
    _transformController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      _markerAnim.forward(from: 0);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    if (svc.svgBytes == null) {
      return _NoFloorPlan(onTap: () {});
    }

    return LayoutBuilder(builder: (context, constraints) {
      return InteractiveViewer(
        transformationController: _transformController,
        boundaryMargin: const EdgeInsets.all(200),
        minScale: 0.3,
        maxScale: 6,
        child: GestureDetector(
          onTapUp: svc.editingNodes
              ? (details) => _handleTapForNode(details, constraints)
              : null,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // ── SVG floor plan ────────────────────────────────────────
                Positioned.fill(
                  child: SvgPicture.memory(
                    svc.svgBytes!,
                    fit: BoxFit.contain,
                    alignment: Alignment.topLeft,
                  ),
                ),

                // ── Route path lines ──────────────────────────────────────
                if (svc.route != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoutePainter(
                        route: svc.route!,
                        currentStep: svc.currentStep,
                        canvasSize:
                            Size(constraints.maxWidth, constraints.maxHeight),
                        markerProgress: _markerT.value,
                      ),
                    ),
                  ),

                // ── Node markers ──────────────────────────────────────────
                for (final node in svc.nodes)
                  _NodeMarker(
                    node: node,
                    canvasSize:
                        Size(constraints.maxWidth, constraints.maxHeight),
                    isStart: svc.startNode?.id == node.id,
                    isInRoute:
                        svc.route?.waypoints.any((w) => w.id == node.id) ??
                            false,
                    routeIndex: svc.route?.waypoints
                            .indexWhere((w) => w.id == node.id) ??
                        -1,
                    currentStep: svc.currentStep,
                    onTap: () => _showNodeMenu(context, node),
                  ),

                // ── Edit mode hint ────────────────────────────────────────
                if (svc.editingNodes)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Material(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Text('Tap to place a location node',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Node placement ────────────────────────────────────────────────────────

  Future<void> _handleTapForNode(
      TapUpDetails details, BoxConstraints constraints) async {
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    final pos = details.localPosition;
    final norm = Offset(pos.dx / size.width, pos.dy / size.height);

    _labelController.clear();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Location'),
        content: TextField(
          controller: _labelController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Location name',
            hintText: 'e.g.  Shelf A3',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_labelController.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );

    if (label != null && label.isNotEmpty) {
      final id = 'node_${DateTime.now().millisecondsSinceEpoch}';
      widget.service.addNode(FloorNode(id: id, label: label, position: norm));
    }
  }

  // ── Node context menu ─────────────────────────────────────────────────────

  Future<void> _showNodeMenu(BuildContext context, FloorNode node) async {
    final svc = widget.service;
    final result = await showModalBottomSheet<_NodeAction>(
      context: context,
      builder: (ctx) => _NodeBottomSheet(
        node: node,
        isStart: svc.startNode?.id == node.id,
      ),
    );
    if (result == null) return;
    switch (result) {
      case _NodeAction.setStart:
        svc.setStartNode(node);
        break;
      case _NodeAction.delete:
        svc.removeNode(node.id);
        break;
      case _NodeAction.rename:
        _labelController.text = node.label;
        final newLabel = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rename Location'),
            content: TextField(
              controller: _labelController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(_labelController.text.trim()),
                  child: const Text('Save')),
            ],
          ),
        );
        if (newLabel != null && newLabel.isNotEmpty) {
          svc.renameNode(node.id, newLabel);
        }
        break;
    }
  }
}

// ── No floor plan placeholder ─────────────────────────────────────────────────

class _NoFloorPlan extends StatelessWidget {
  final VoidCallback onTap;
  const _NoFloorPlan({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.map_outlined,
            size: 72, color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 16),
        Text('No floor plan loaded',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Upload an SVG file to get started'),
      ]),
    );
  }
}

// ── Node marker widget ────────────────────────────────────────────────────────

class _NodeMarker extends StatelessWidget {
  final FloorNode node;
  final Size canvasSize;
  final bool isStart;
  final bool isInRoute;
  final int routeIndex;
  final int currentStep;
  final VoidCallback onTap;

  const _NodeMarker({
    required this.node,
    required this.canvasSize,
    required this.isStart,
    required this.isInRoute,
    required this.routeIndex,
    required this.currentStep,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final x = node.position.dx * canvasSize.width;
    final y = node.position.dy * canvasSize.height;

    Color bg;
    if (isStart) {
      bg = Colors.green.shade600;
    } else if (routeIndex >= 0 && routeIndex <= currentStep) {
      bg = cs.primary;
    } else {
      bg = cs.secondaryContainer;
    }

    return Positioned(
      left: x - 16,
      top: y - 16,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: bg,
              child: isStart
                  ? const Icon(Icons.flag, size: 16, color: Colors.white)
                  : Text(
                      isInRoute ? '${routeIndex + 1}' : '',
                      style: TextStyle(
                        color: bg.computeLuminance() > 0.4
                            ? Colors.black87
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
            ),
            Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  node.label,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ── Route painter ─────────────────────────────────────────────────────────────

class _RoutePainter extends CustomPainter {
  final OptimizedRoute route;
  final int currentStep;
  final Size canvasSize;
  final double markerProgress;

  const _RoutePainter({
    required this.route,
    required this.currentStep,
    required this.canvasSize,
    required this.markerProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (route.waypoints.length < 2) return;

    final visited = Paint()
      ..color = Colors.green.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final upcoming = Paint()
      ..color = Colors.blueAccent.withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Offset toCanvas(FloorNode n) => Offset(
          n.position.dx * canvasSize.width,
          n.position.dy * canvasSize.height,
        );

    // Draw all segments.
    for (var i = 0; i < route.waypoints.length - 1; i++) {
      final from = toCanvas(route.waypoints[i]);
      final to = toCanvas(route.waypoints[i + 1]);
      if (i < currentStep) {
        canvas.drawLine(from, to, visited);
      } else if (i == currentStep) {
        // Animate the current segment.
        final animTo = Offset.lerp(from, to, markerProgress)!;
        canvas.drawLine(from, animTo, visited);
        canvas.drawLine(animTo, to, upcoming);
        // Draw travelling dot.
        canvas.drawCircle(
          animTo,
          8,
          Paint()..color = Colors.orange,
        );
      } else {
        canvas.drawLine(from, to, upcoming);
      }
    }

    // Arrow at completed segments.
    for (var i = 0; i < min(currentStep, route.waypoints.length - 1); i++) {
      _drawArrow(canvas, toCanvas(route.waypoints[i]),
          toCanvas(route.waypoints[i + 1]), visited);
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dir = (to - from);
    if (dir.distance < 1) return;
    final norm = dir / dir.distance;
    final mid = from + dir * 0.5;
    final left = Offset(-norm.dy, norm.dx) * 6;
    final path = Path()
      ..moveTo(mid.dx + norm.dx * 8, mid.dy + norm.dy * 8)
      ..lineTo((mid + left).dx, (mid + left).dy)
      ..lineTo((mid - left).dx, (mid - left).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = paint.color);
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.currentStep != currentStep ||
      old.markerProgress != markerProgress ||
      old.route != route;
}

// ── Node bottom sheet ─────────────────────────────────────────────────────────

enum _NodeAction { setStart, rename, delete }

class _NodeBottomSheet extends StatelessWidget {
  final FloorNode node;
  final bool isStart;
  const _NodeBottomSheet({required this.node, required this.isStart});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(node.label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Node options'),
          ),
          const Divider(height: 1),
          if (!isStart)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Set as Start'),
              onTap: () => Navigator.of(context).pop(_NodeAction.setStart),
            ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            onTap: () => Navigator.of(context).pop(_NodeAction.rename),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.of(context).pop(_NodeAction.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
