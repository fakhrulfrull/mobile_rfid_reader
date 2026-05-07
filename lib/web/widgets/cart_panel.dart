import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_item.dart';
import '../models/floor_node.dart';
import '../services/floor_plan_service.dart';

/// Sidebar panel displaying the cart item list with node assignment controls
/// and the route optimisation / navigation controls.
class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FloorPlanService>(
      builder: (context, svc, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            _PanelHeader(
              cartCount: svc.cart.length,
              onClear: svc.cart.isEmpty ? null : svc.clearCart,
            ),

            const Divider(height: 1),

            // ── Cart list ────────────────────────────────────────────────
            Expanded(
              child: svc.cart.isEmpty
                  ? _EmptyCart(hasSvg: svc.svgBytes != null)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: svc.cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (ctx, i) {
                        final item = svc.cart[i];
                        final routeIdx = svc.route?.waypoints
                                .indexWhere((w) => w.id == item.node?.id) ??
                            -1;
                        return _CartItemTile(
                          item: item,
                          nodes: svc.nodes,
                          routeIndex: routeIdx,
                          currentStep: svc.currentStep,
                          onRemove: () => svc.removeCartItem(item.id),
                          onNodeAssigned: (node) =>
                              svc.assignNodeToCartItem(item.id, node),
                        );
                      },
                    ),
            ),

            const Divider(height: 1),

            // ── Route controls ────────────────────────────────────────────
            _RouteControls(svc: svc),
          ],
        );
      },
    );
  }
}

// ── Panel header ──────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final int cartCount;
  final VoidCallback? onClear;
  const _PanelHeader({required this.cartCount, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cart  ($cartCount item${cartCount == 1 ? '' : 's'})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (onClear != null)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty cart ────────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  final bool hasSvg;
  const _EmptyCart({required this.hasSvg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 48, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            hasSvg
                ? 'No items in cart.\nScan RFID tags or add items manually.'
                : 'Load a floor plan SVG first, then add cart items.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── Cart item tile ────────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final List<FloorNode> nodes;
  final int routeIndex;
  final int currentStep;
  final VoidCallback onRemove;
  final ValueChanged<FloorNode> onNodeAssigned;

  const _CartItemTile({
    required this.item,
    required this.nodes,
    required this.routeIndex,
    required this.currentStep,
    required this.onRemove,
    required this.onNodeAssigned,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isVisited = routeIndex >= 0 && routeIndex <= currentStep;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: routeIndex >= 0
            ? (isVisited ? cs.primary : cs.primaryContainer)
            : cs.surfaceVariant,
        child: routeIndex >= 0
            ? Text(
                '${routeIndex + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isVisited ? cs.onPrimary : cs.onPrimaryContainer,
                ),
              )
            : Icon(Icons.help_outline, size: 14, color: cs.onSurfaceVariant),
      ),
      title: Text(item.name,
          style: TextStyle(
            fontSize: 13,
            decoration: isVisited ? TextDecoration.lineThrough : null,
            color: isVisited ? cs.onSurfaceVariant : null,
          )),
      subtitle: Text(
        item.node?.label ?? 'Unassigned – tap to set location',
        style: TextStyle(
          fontSize: 11,
          color: item.node == null ? cs.error : cs.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Node assignment dropdown.
          if (nodes.isNotEmpty)
            SizedBox(
              width: 110,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<FloorNode>(
                  value: nodes.any((n) => n.id == item.node?.id)
                      ? item.node
                      : null,
                  hint: const Text('Location', style: TextStyle(fontSize: 11)),
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11),
                  items: nodes
                      .map((n) => DropdownMenuItem(
                            value: n,
                            child:
                                Text(n.label, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (node) {
                    if (node != null) onNodeAssigned(node);
                  },
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Remove from cart',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ── Route controls ────────────────────────────────────────────────────────────

class _RouteControls extends StatelessWidget {
  final FloorPlanService svc;
  const _RouteControls({required this.svc});

  @override
  Widget build(BuildContext context) {
    final hasRoute = svc.route != null;
    final waypoints = svc.route?.waypoints ?? [];
    final unassigned = svc.cart.where((c) => c.node == null).length;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (unassigned > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$unassigned item(s) without a location – assign before optimising.',
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).colorScheme.error),
              ),
            ),

          // Optimize button.
          FilledButton.icon(
            onPressed:
                svc.cart.any((c) => c.node != null) ? svc.optimizeRoute : null,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Auto-Optimize Route'),
          ),

          if (hasRoute) ...[
            const SizedBox(height: 8),

            // Step info.
            Text(
              'Step ${svc.currentStep + 1} / ${waypoints.length}  →  '
              '${waypoints[svc.currentStep].label}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 4),

            // Prev / Next controls.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: svc.currentStep > 0 ? svc.prevStep : null,
                    icon: const Icon(Icons.chevron_left, size: 16),
                    label: const Text('Prev'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: svc.currentStep < waypoints.length - 1
                        ? svc.nextStep
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 16),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            TextButton(
              onPressed: svc.clearRoute,
              child: const Text('Clear Route'),
            ),
          ],
        ],
      ),
    );
  }
}
