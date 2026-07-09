import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/chart_models.dart';
import '../theme.dart';

const _planetOrder = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'];

// Sun is drawn by hand (see _drawPlanetGlyph) since its Unicode glyph isn't
// covered by every platform's fallback font. The rest render fine as text.
const _planetGlyphs = {
  'Moon': '☽',
  'Mercury': '☿',
  'Venus': '♀',
  'Mars': '♂',
  'Jupiter': '♃',
  'Saturn': '♄',
};

const _lotOfFortuneKey = 'Lot of Fortune';
const _lotOfSpiritKey = 'Lot of Spirit';

const _signGlyphs = [
  '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓',
];

// Muted, semi-transparent element tints painted over the dark background.
const _elementColors = [
  Color(0x40B5651D), // Fire — muted amber
  Color(0x404C7A4C), // Earth — muted green
  Color(0x40E8D75A), // Air — light yellow
  Color(0x50355E9E), // Water — deep blue (slightly more opaque to read against near-black bg)
];

const _trineSextileColor = Color(0xFF6FA8DC); // harmonious — blue
const _squareOppositionColor = Color(0xFFB05C5C); // hard — red
const _conjunctionColor = Color(0xFF5FA86F); // green

const _bandGap = 34.0;
const _minGapDeg = 8.0;

/// Converts a longitude, expressed relative to the wheel's rotation origin
/// (the start of the rising sign), into a point on a circle of [radius]
/// around [center]. 0° sits at the left (the traditional Ascendant position)
/// and increases counterclockwise through houses 2, 3, 4 (bottom)...
Offset pointOnWheel(Offset center, double radius, double relativeDeg) {
  final mathAngleDeg = (180 + relativeDeg) % 360;
  final rad = mathAngleDeg * math.pi / 180;
  return Offset(center.dx + radius * math.cos(rad), center.dy - radius * math.sin(rad));
}

double signStartFor(double ascendantLongitude) => (ascendantLongitude / 30).floorToDouble() * 30;

String _degreeMinuteLabel(double signLongitude, bool retrograde) {
  final totalMinutes = (signLongitude * 60).round();
  final deg = totalMinutes ~/ 60;
  final min = totalMinutes % 60;
  return '$deg°${min.toString().padLeft(2, '0')}${retrograde ? '℞' : ''}';
}

class WheelPlacement {
  final double relative;
  final double radius;
  final Offset point;

  const WheelPlacement({required this.relative, required this.radius, required this.point});
}

/// Lays out every planet + lot around the wheel. Points within [_minGapDeg]
/// of their neighbors are grouped into a cluster (with circular wraparound
/// across the 0°/360° seam), and every member of a cluster gets its own
/// radius band so glyphs never stack on top of each other regardless of
/// how many bodies are conjunct. The Sun is always given priority for the
/// outermost band within its cluster so it's never the one pushed inward.
Map<String, WheelPlacement> computeWheelPlacements({
  required ChartResponse result,
  required double signStart,
  required Offset center,
  required double baseRadius,
}) {
  final longitudes = <String, double>{
    for (final entry in result.planets.entries) entry.key: entry.value.longitude,
    _lotOfFortuneKey: result.lotOfFortune.longitude,
    _lotOfSpiritKey: result.lotOfSpirit.longitude,
  };

  final sorted = longitudes.entries.map((e) => MapEntry(e.key, (e.value - signStart) % 360)).toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  final n = sorted.length;
  final clusterOf = List<int>.filled(n, 0);
  for (var i = 1; i < n; i++) {
    final gap = sorted[i].value - sorted[i - 1].value;
    clusterOf[i] = gap < _minGapDeg ? clusterOf[i - 1] : clusterOf[i - 1] + 1;
  }
  // Merge the wraparound seam: if the last point is within range of the
  // first (going the short way through 0°/360°), they're one cluster too.
  if (n > 1 && (sorted[0].value + 360 - sorted[n - 1].value) < _minGapDeg) {
    final lastCluster = clusterOf[n - 1];
    final firstCluster = clusterOf[0];
    if (lastCluster != firstCluster) {
      for (var i = 0; i < n; i++) {
        if (clusterOf[i] == lastCluster) clusterOf[i] = firstCluster;
      }
    }
  }

  final clusters = <int, List<int>>{};
  for (var i = 0; i < n; i++) {
    clusters.putIfAbsent(clusterOf[i], () => []).add(i);
  }

  final placements = <String, WheelPlacement>{};
  for (final indices in clusters.values) {
    final sunPos = indices.indexWhere((i) => sorted[i].key == 'Sun');
    if (sunPos > 0) {
      final sunIdx = indices.removeAt(sunPos);
      indices.insert(0, sunIdx);
    }
    for (var band = 0; band < indices.length; band++) {
      final e = sorted[indices[band]];
      final radius = baseRadius - band * _bandGap;
      placements[e.key] = WheelPlacement(relative: e.value, radius: radius, point: pointOnWheel(center, radius, e.value));
    }
  }
  return placements;
}

class ChartWheel extends StatelessWidget {
  final ChartResponse result;
  final ValueChanged<String> onPlanetTap;

  const ChartWheel({required this.result, required this.onPlanetTap, super.key});

  @override
  Widget build(BuildContext context) {
    final signStart = signStartFor(result.ascendant.longitude);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final center = Offset(side / 2, side / 2);
        final outerRadius = side / 2 - 4;
        final degreeScaleInner = outerRadius * 0.92;
        final zodiacInner = degreeScaleInner * 0.78;
        final houseNumInner = zodiacInner * 0.84;
        final baseRadius = houseNumInner - 40;

        final placements = computeWheelPlacements(
          result: result,
          signStart: signStart,
          center: center,
          baseRadius: baseRadius,
        );

        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(side, side),
                painter: _ChartWheelPainter(result: result, signStart: signStart, placements: placements),
              ),
              for (final name in _planetOrder)
                if (placements.containsKey(name)) _tapTarget(placements[name]!.point, () => onPlanetTap(name)),
            ],
          ),
        );
      },
    );
  }

  Widget _tapTarget(Offset point, VoidCallback onTap) {
    const targetSize = 40.0;
    return Positioned(
      left: point.dx - targetSize / 2,
      top: point.dy - targetSize / 2,
      width: targetSize,
      height: targetSize,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
      ),
    );
  }
}

class _ChartWheelPainter extends CustomPainter {
  final ChartResponse result;
  final double signStart;
  final Map<String, WheelPlacement> placements;

  _ChartWheelPainter({required this.result, required this.signStart, required this.placements});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 4;
    final degreeScaleInner = outerRadius * 0.92;
    final zodiacInner = degreeScaleInner * 0.78;
    final houseNumInner = zodiacInner * 0.84;

    final risingSignIndex = (signStart / 30).round() % 12;

    _drawDegreeScale(canvas, center, outerRadius, degreeScaleInner);
    _drawZodiacRing(canvas, center, degreeScaleInner, zodiacInner, risingSignIndex);
    _drawHouseNumberRing(canvas, center, zodiacInner, houseNumInner);
    _drawBoundaryDividers(canvas, center, houseNumInner, outerRadius);
    _drawAngleMarkers(canvas, center, zodiacInner);
    _drawAspectLines(canvas, center, houseNumInner - 6);
    _drawPoints(canvas, center, houseNumInner);
  }

  void _drawDegreeScale(Canvas canvas, Offset center, double outer, double inner) {
    final tickPaint = Paint()
      ..color = AppColors.mutedText.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var j = 0; j < 12; j++) {
      final relStart = j * 30.0;
      for (var k = 0; k < 30; k++) {
        final rel = relStart + k;
        final isMajor = k % 5 == 0;
        final tickInner = isMajor ? outer - 9 : outer - 4;
        canvas.drawLine(pointOnWheel(center, outer, rel), pointOnWheel(center, tickInner, rel), tickPaint);
        if (isMajor) {
          _drawText(canvas, '$k', pointOnWheel(center, outer - 15, rel), color: AppColors.mutedText, fontSize: 7);
        }
      }
    }

    final ringLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, outer, ringLine);
    canvas.drawCircle(center, inner, ringLine);
  }

  void _drawZodiacRing(Canvas canvas, Offset center, double outer, double inner, int risingSignIndex) {
    for (var j = 0; j < 12; j++) {
      final signIndex = (risingSignIndex + j) % 12;
      final relStart = j * 30.0;

      final fill = Paint()
        ..color = _elementColors[signIndex % 4]
        ..style = PaintingStyle.fill;
      canvas.drawPath(_wedgePath(center, inner, outer, relStart, 30), fill);

      _drawText(
        canvas,
        _signGlyphs[signIndex],
        pointOnWheel(center, (outer + inner) / 2, relStart + 15),
        color: AppColors.bodyText,
        fontSize: 22,
      );
    }

    final ringLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, inner, ringLine);
  }

  void _drawHouseNumberRing(Canvas canvas, Offset center, double outer, double inner) {
    for (var j = 0; j < 12; j++) {
      final relStart = j * 30.0;
      _drawText(
        canvas,
        '${j + 1}',
        pointOnWheel(center, (outer + inner) / 2, relStart + 15),
        color: AppColors.mutedText,
        fontSize: 12,
      );
    }

    final ringLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, inner, ringLine);
  }

  /// One continuous, subtle divider per 30° house/sign boundary, spanning
  /// from the inner circle all the way out to the degree scale. Deliberately
  /// muted so the angle axes (ASC/DSC/MC/IC) read as the prominent lines.
  void _drawBoundaryDividers(Canvas canvas, Offset center, double inner, double outer) {
    final line = Paint()
      ..color = const Color(0xFFAAAAAA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var j = 0; j < 12; j++) {
      final relStart = j * 30.0;
      canvas.drawLine(pointOnWheel(center, inner, relStart), pointOnWheel(center, outer, relStart), line);
    }
  }

  /// True Ascendant/Descendant and Midheaven/Imum Coeli, plotted at their
  /// exact ecliptic longitudes — these are independent sensitive points and,
  /// in whole-sign houses, generally will NOT sit exactly on a house cusp.
  /// Both axes are drawn identically (gold, thicker than the subtle house
  /// dividers) and reach all the way out to the zodiac ring's inner edge,
  /// so ASC/DSC/MC/IC read as one consistent "angle axis" category.
  void _drawAngleMarkers(Canvas canvas, Offset center, double boundary) {
    final ascRel = (result.ascendant.longitude - signStart) % 360;
    final mcRel = (result.midheaven.longitude - signStart) % 360;
    final dscRel = (ascRel + 180) % 360;
    final icRel = (mcRel + 180) % 360;

    final axisPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(pointOnWheel(center, boundary, ascRel), pointOnWheel(center, boundary, dscRel), axisPaint);
    canvas.drawLine(pointOnWheel(center, boundary, mcRel), pointOnWheel(center, boundary, icRel), axisPaint);

    _drawAngleTick(canvas, center, boundary, ascRel, 'ASC');
    _drawAngleTick(canvas, center, boundary, dscRel, 'DSC');
    _drawAngleTick(canvas, center, boundary, mcRel, 'MC');
    _drawAngleTick(canvas, center, boundary, icRel, 'IC');
  }

  void _drawAngleTick(Canvas canvas, Offset center, double boundary, double rel, String label) {
    final tickPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(pointOnWheel(center, boundary - 8, rel), pointOnWheel(center, boundary + 8, rel), tickPaint);
    // Just inside the zodiac ring, clear of the sign glyphs above it. Drawn
    // on an opaque backdrop so the axis line can't show through the label.
    _drawTextOnBackdrop(
      canvas,
      label,
      pointOnWheel(center, boundary - 18, rel),
      color: AppColors.gold,
      fontSize: 11,
      bold: true,
    );
  }

  void _drawAspectLines(Canvas canvas, Offset center, double radius) {
    for (final aspect in result.aspects) {
      final color = switch (aspect.aspect) {
        'trine' || 'sextile' => _trineSextileColor,
        'square' || 'opposition' => _squareOppositionColor,
        'conjunction' => _conjunctionColor,
        _ => null,
      };
      if (color == null) continue;

      final a = placements[aspect.planetA];
      final b = placements[aspect.planetB];
      if (a == null || b == null) continue;

      final paint = Paint()
        ..color = color.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawLine(pointOnWheel(center, radius, a.relative), pointOnWheel(center, radius, b.relative), paint);
    }
  }

  void _drawPoints(Canvas canvas, Offset center, double ringInner) {
    // Ticks and degree labels first, for every body...
    for (final entry in result.planets.entries) {
      final placement = placements[entry.key];
      if (placement == null) continue;
      _drawTick(canvas, center, ringInner, placement);
      _drawDegreeLabel(canvas, center, placement, entry.value.signLongitude, entry.value.retrograde);
    }

    final fortune = placements[_lotOfFortuneKey];
    if (fortune != null) {
      _drawTick(canvas, center, ringInner, fortune);
      _drawLotShape(canvas, fortune.point, isSpirit: false);
      _drawDegreeLabel(canvas, center, fortune, result.lotOfFortune.signLongitude, false);
    }

    final spirit = placements[_lotOfSpiritKey];
    if (spirit != null) {
      _drawTick(canvas, center, ringInner, spirit);
      _drawLotShape(canvas, spirit.point, isSpirit: true);
      _drawDegreeLabel(canvas, center, spirit, result.lotOfSpirit.signLongitude, false);
    }

    // ...then glyphs on top, with the Sun drawn last so it's never obscured
    // by an overlapping neighbor.
    final planetNames = result.planets.keys.toList();
    final sunIndex = planetNames.indexOf('Sun');
    if (sunIndex > 0) {
      planetNames
        ..removeAt(sunIndex)
        ..add('Sun');
    }
    for (final name in planetNames) {
      final placement = placements[name];
      if (placement == null) continue;
      _drawPlanetGlyph(canvas, placement.point, name, AppColors.gold);
    }
  }

  /// The Sun's Unicode glyph (☉) isn't covered by every platform's fallback
  /// font and can render as a missing-glyph box, so it's hand-drawn instead.
  /// Every other planet still renders as plain Unicode text, unchanged.
  void _drawPlanetGlyph(Canvas canvas, Offset center, String name, Color color) {
    if (name == 'Sun') {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, 8, paint);
      canvas.drawCircle(center, 8 * 0.22, Paint()..color = color);
      return;
    }
    final glyph = _planetGlyphs[name];
    if (glyph == null) return;
    _drawText(canvas, glyph, center, color: color, fontSize: 34);
  }

  void _drawTick(Canvas canvas, Offset center, double ringInner, WheelPlacement placement) {
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outer = pointOnWheel(center, ringInner, placement.relative);
    final inner = pointOnWheel(center, placement.radius + 19, placement.relative);
    canvas.drawLine(outer, inner, tickPaint);
  }

  void _drawDegreeLabel(
    Canvas canvas,
    Offset center,
    WheelPlacement placement,
    double signLongitude,
    bool retrograde,
  ) {
    final inwardPoint = pointOnWheel(center, placement.radius - 23, placement.relative);
    _drawText(
      canvas,
      _degreeMinuteLabel(signLongitude, retrograde),
      inwardPoint,
      color: AppColors.mutedText,
      fontSize: 10,
    );
  }

  void _drawLotShape(Canvas canvas, Offset point, {required bool isSpirit}) {
    const r = 10.0;
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(point, r, paint);
    if (isSpirit) {
      final d = r * 0.75;
      canvas.drawLine(point + Offset(-d, -d), point + Offset(d, d), paint);
      canvas.drawLine(point + Offset(-d, d), point + Offset(d, -d), paint);
    } else {
      canvas.drawLine(point + Offset(-r, 0), point + Offset(r, 0), paint);
      canvas.drawLine(point + Offset(0, -r), point + Offset(0, r), paint);
    }
  }

  Path _wedgePath(Offset center, double rInner, double rOuter, double relStart, double relSweep) {
    const steps = 8;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final rel = relStart + relSweep * i / steps;
      final p = pointOnWheel(center, rOuter, rel);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    for (var i = steps; i >= 0; i--) {
      final rel = relStart + relSweep * i / steps;
      final p = pointOnWheel(center, rInner, rel);
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset centerPoint, {
    required Color color,
    required double fontSize,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, centerPoint - Offset(painter.width / 2, painter.height / 2));
  }

  /// Same as [_drawText], but paints an opaque backdrop behind the glyphs
  /// first so a line passing behind the label (e.g. an angle axis) can't
  /// show through the open parts of letterforms like "A" or "C".
  void _drawTextOnBackdrop(
    Canvas canvas,
    String text,
    Offset centerPoint, {
    required Color color,
    required double fontSize,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final topLeft = centerPoint - Offset(painter.width / 2, painter.height / 2);
    final backdropRect = Rect.fromLTWH(topLeft.dx - 3, topLeft.dy - 1, painter.width + 6, painter.height + 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(backdropRect, const Radius.circular(3)),
      Paint()..color = AppColors.background,
    );
    painter.paint(canvas, topLeft);
  }

  @override
  bool shouldRepaint(covariant _ChartWheelPainter oldDelegate) =>
      oldDelegate.result != result || oldDelegate.signStart != signStart;
}
