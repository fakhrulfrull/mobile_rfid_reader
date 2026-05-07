import 'dart:typed_data';
import 'dart:ui';
import 'package:xml/xml.dart';
import '../models/floor_node.dart';

/// Parses an SVG file's bytes and extracts named location nodes.
///
/// Looks for SVG elements that carry an `id` attribute and have a
/// recognisable position (rect, circle, use, g with transform, or
/// any element with explicit x/y/cx/cy attributes).
class SvgParserService {
  /// Parse [svgBytes] and return a list of [FloorNode]s.
  ///
  /// [viewWidth] and [viewHeight] are the SVG viewBox dimensions used
  /// to normalise positions into [0.0, 1.0] range.
  List<FloorNode> parse(Uint8List svgBytes) {
    final document = XmlDocument.parse(String.fromCharCodes(svgBytes));
    final svgRoot = document.rootElement;

    // Resolve viewBox dimensions for normalisation.
    double vbW = 1000;
    double vbH = 1000;
    final viewBoxAttr = svgRoot.getAttribute('viewBox');
    if (viewBoxAttr != null) {
      final parts = viewBoxAttr.trim().split(RegExp(r'[\s,]+'));
      if (parts.length >= 4) {
        vbW = double.tryParse(parts[2]) ?? vbW;
        vbH = double.tryParse(parts[3]) ?? vbH;
      }
    } else {
      vbW = double.tryParse(svgRoot.getAttribute('width') ?? '') ?? vbW;
      vbH = double.tryParse(svgRoot.getAttribute('height') ?? '') ?? vbH;
    }

    final nodes = <FloorNode>[];

    for (final element in svgRoot.descendants.whereType<XmlElement>()) {
      final id = element.getAttribute('id');
      if (id == null || id.isEmpty) continue;

      // Skip defs, style, mask – non-visual structural elements.
      final tag = element.localName.toLowerCase();
      if (const {'defs', 'style', 'clippath', 'mask', 'symbol'}.contains(tag)) {
        continue;
      }

      final pos = _extractPosition(element, tag);
      if (pos == null) continue;

      final label = element.getAttribute('data-label') ??
          element.getAttribute('inkscape:label') ??
          _titleChild(element) ??
          id;

      nodes.add(FloorNode(
        id: id,
        label: label,
        position: Offset(
          (pos.dx / vbW).clamp(0.0, 1.0),
          (pos.dy / vbH).clamp(0.0, 1.0),
        ),
      ));
    }

    return nodes;
  }

  Offset? _extractPosition(XmlElement el, String tag) {
    switch (tag) {
      case 'rect':
      case 'use':
      case 'image':
      case 'foreignobject':
        final x = double.tryParse(el.getAttribute('x') ?? '');
        final y = double.tryParse(el.getAttribute('y') ?? '');
        final w = double.tryParse(el.getAttribute('width') ?? '') ?? 0;
        final h = double.tryParse(el.getAttribute('height') ?? '') ?? 0;
        if (x != null && y != null) return Offset(x + w / 2, y + h / 2);
        break;

      case 'circle':
      case 'ellipse':
        final cx = double.tryParse(el.getAttribute('cx') ?? '');
        final cy = double.tryParse(el.getAttribute('cy') ?? '');
        if (cx != null && cy != null) return Offset(cx, cy);
        break;

      case 'text':
      case 'tspan':
        final x = double.tryParse(el.getAttribute('x') ?? '');
        final y = double.tryParse(el.getAttribute('y') ?? '');
        if (x != null && y != null) return Offset(x, y);
        break;

      default:
        // Try generic x/y then transform="translate(x,y)"
        final x = double.tryParse(el.getAttribute('x') ?? '');
        final y = double.tryParse(el.getAttribute('y') ?? '');
        if (x != null && y != null) return Offset(x, y);
        return _translateFromTransform(el);
    }
    return null;
  }

  Offset? _translateFromTransform(XmlElement el) {
    final transform = el.getAttribute('transform') ?? '';
    final match = RegExp(r'translate\(\s*([\d.+-]+)[\s,]+([\d.+-]+)')
        .firstMatch(transform);
    if (match != null) {
      final tx = double.tryParse(match.group(1)!);
      final ty = double.tryParse(match.group(2)!);
      if (tx != null && ty != null) return Offset(tx, ty);
    }
    return null;
  }

  String? _titleChild(XmlElement el) {
    for (final child in el.childElements) {
      if (child.localName.toLowerCase() == 'title') {
        return child.innerText.trim().isNotEmpty
            ? child.innerText.trim()
            : null;
      }
    }
    return null;
  }
}
