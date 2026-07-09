import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A simple placeholder armillary sphere -- concentric rings at different
/// tilts around a central sphere -- used in place of a real app icon asset,
/// which doesn't exist yet.
class ArmillarySphereIcon extends StatelessWidget {
  final double size;

  const ArmillarySphereIcon({this.size = 96, super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _ArmillarySpherePainter());
  }
}

class _ArmillarySpherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - size.width * 0.05;
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025;

    canvas.drawOval(Rect.fromCircle(center: center, radius: radius), paint);
    canvas.drawOval(Rect.fromCenter(center: center, width: radius * 2, height: radius * 0.55), paint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 7);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 0.7), paint);
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 2);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 0.55), paint);
    canvas.restore();

    canvas.drawCircle(center, radius * 0.09, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
