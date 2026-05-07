import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_item.dart';
import '../services/floor_plan_service.dart';
import '../widgets/floor_plan_canvas.dart';
import '../widgets/cart_panel.dart';

/// The main floor plan screen with:
///  - SVG upload toolbar
///  - Interactive floor plan canvas (centre)
///  - Cart & route panel (right sidebar on wide screens)
class FloorPlanScreen extends StatelessWidget {
  const FloorPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FloorPlanService>(
      builder: (context, svc, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(svc.svgFileName != null
                ? 'Floor Plan  ·  ${svc.svgFileName}'
                : 'Floor Plan'),
            actions: [
              // Upload SVG.
              IconButton(
                icon: const Icon(Icons.upload_file_outlined),
                tooltip: 'Upload SVG floor plan',
                onPressed: () => _pickSvg(context, svc),
              ),
              // Toggle node editing.
              IconButton(
                icon: Icon(svc.editingNodes
                    ? Icons.edit_off_outlined
                    : Icons.edit_location_alt_outlined),
                tooltip: svc.editingNodes
                    ? 'Stop editing nodes'
                    : 'Add location nodes',
                color: svc.editingNodes
                    ? Theme.of(context).colorScheme.primary
                    : null,
                onPressed: svc.svgBytes != null
                    ? () => svc.setEditingNodes(!svc.editingNodes)
                    : null,
              ),
              // Manual add cart item.
              IconButton(
                icon: const Icon(Icons.add_shopping_cart_outlined),
                tooltip: 'Add cart item manually',
                onPressed: svc.svgBytes != null
                    ? () => _addManualCartItem(context, svc)
                    : null,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 720;
            if (wide) {
              return Row(
                children: [
                  // Canvas.
                  Expanded(
                    child: FloorPlanCanvas(service: svc),
                  ),
                  // Right sidebar.
                  SizedBox(
                    width: 300,
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: CartPanel(),
                    ),
                  ),
                ],
              );
            }

            // Narrow: canvas + bottom sheet toggle.
            return Stack(
              children: [
                FloorPlanCanvas(service: svc),
                DraggableScrollableSheet(
                  initialChildSize: 0.25,
                  minChildSize: 0.1,
                  maxChildSize: 0.75,
                  builder: (ctx, scrollController) => Card(
                    margin: EdgeInsets.zero,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: CartPanel(),
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  Future<void> _pickSvg(BuildContext context, FloorPlanService svc) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['svg'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      svc.loadSvg(
        result.files.single.bytes!,
        result.files.single.name,
      );
    }
  }

  Future<void> _addManualCartItem(
      BuildContext context, FloorPlanService svc) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Cart Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Item name / SKU',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      svc.addCartItem(CartItem(
        id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
      ));
    }
  }
}
