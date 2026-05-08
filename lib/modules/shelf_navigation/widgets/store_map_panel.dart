import 'dart:math' as math;

import 'package:flutter/material.dart';

class StoreMapPanel extends StatelessWidget {
  const StoreMapPanel({
    super.key,
    required this.user,
    required this.target,
    required this.path,
    required this.heading,
    required this.entrance,
    required this.exit1,
    required this.exit2,
  });

  final Offset user;
  final Offset? target;
  final List<Offset> path;
  final double heading;
  final Offset entrance;
  final Offset exit1;
  final Offset exit2;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/store_map.png', fit: BoxFit.cover),
                CustomPaint(
                  painter: _MapPainter(
                    user: user,
                    target: target,
                    path: path,
                    heading: heading,
                    mapSize: size,
                    entrance: entrance,
                    exit1: exit1,
                    exit2: exit2,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
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

  final Offset user;
  final Offset? target;
  final List<Offset> path;
  final double heading;
  final Size mapSize;
  final Offset entrance;
  final Offset exit1;
  final Offset exit2;

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

    canvas.drawCircle(p, 9, paint);
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

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

    tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
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
