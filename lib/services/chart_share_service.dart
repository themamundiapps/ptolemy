import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/chart_models.dart';
import '../theme.dart';

const double _shareImageSize = 1080;
const double _shareMargin = 56;
const double _shareGutter = 48;
const double _shareWatermarkBand = 64;
const double _shareWheelMaxSide = 460;

const _sharePlanetOrder = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'];

/// Captures the on-screen chart wheel (via the [RepaintBoundary] attached to
/// [wheelBoundaryKey]) and composes it with a planet list into a single
/// self-contained 1080x1080 share image, then opens the native share sheet.
///
/// Must be called from a tap handler (or otherwise after at least one frame
/// has been painted) since [RenderRepaintBoundary.toImage] requires the
/// boundary to already be laid out and painted.
Future<void> shareNatalChart({
  required BuildContext context,
  required GlobalKey wheelBoundaryKey,
  required ChartResponse result,
}) async {
  final boundary = wheelBoundaryKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) {
    throw StateError('Chart wheel is not ready to capture.');
  }

  final wheelImage = await boundary.toImage(pixelRatio: 3.0);
  ui.Image? composed;
  try {
    composed = await _composeShareImage(wheelImage: wheelImage, result: result);
    final byteData = await composed.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('Could not encode share image.');

    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(byteData.buffer.asUint8List(), mimeType: 'image/png')],
        fileNameOverrides: ['ptolemy-chart.png'],
        text: 'My natal chart, via Ptolemy.',
      ),
    );
  } finally {
    wheelImage.dispose();
    composed?.dispose();
  }
}

Future<ui.Image> _composeShareImage({required ui.Image wheelImage, required ChartResponse result}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _shareImageSize, _shareImageSize));

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _shareImageSize, _shareImageSize),
    Paint()..color = AppColors.background,
  );

  final contentTop = _shareMargin;
  final contentBottom = _shareImageSize - _shareWatermarkBand;
  final contentHeight = contentBottom - contentTop;

  final wheelSide = math.min(_shareWheelMaxSide, contentHeight);
  final wheelRect = Rect.fromLTWH(
    _shareMargin,
    contentTop + (contentHeight - wheelSide) / 2,
    wheelSide,
    wheelSide,
  );
  canvas.drawImageRect(
    wheelImage,
    Rect.fromLTWH(0, 0, wheelImage.width.toDouble(), wheelImage.height.toDouble()),
    wheelRect,
    Paint()..filterQuality = FilterQuality.high,
  );

  final listLeft = wheelRect.right + _shareGutter;
  final listRight = _shareImageSize - _shareMargin;
  _drawPlanetList(canvas: canvas, result: result, left: listLeft, right: listRight, top: contentTop, height: contentHeight);

  _drawWatermark(canvas);

  final picture = recorder.endRecording();
  return picture.toImage(_shareImageSize.round(), _shareImageSize.round());
}

void _drawPlanetList({
  required Canvas canvas,
  required ChartResponse result,
  required double left,
  required double right,
  required double top,
  required double height,
}) {
  final entries = <MapEntry<String, ZodiacPosition>>[
    for (final name in _sharePlanetOrder)
      if (result.planets.containsKey(name)) MapEntry(name, result.planets[name]!),
    MapEntry('ASC', result.ascendant),
    MapEntry('MC', result.midheaven),
  ];

  final width = right - left;
  final rowHeight = height / entries.length;

  for (var i = 0; i < entries.length; i++) {
    final name = entries[i].key;
    final position = entries[i].value;
    final rowTop = top + i * rowHeight;

    final dignityLabel = position.dignities.map((d) => d[0].toUpperCase() + d.substring(1)).join(', ');

    final namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.gold),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    namePainter.paint(canvas, Offset(left, rowTop));

    if (dignityLabel.isNotEmpty) {
      final dignityPainter = TextPainter(
        text: TextSpan(text: dignityLabel, style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedGold)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      dignityPainter.paint(canvas, Offset(right - dignityPainter.width, rowTop + 5));
    }

    final detailText =
        '${position.signLongitude.toStringAsFixed(2)}° ${position.sign}'
        '${position.retrograde ? ' (R)' : ''} · House ${position.house}';
    final detailPainter = TextPainter(
      text: TextSpan(text: detailText, style: GoogleFonts.inter(fontSize: 16, color: AppColors.bodyText)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    detailPainter.paint(canvas, Offset(left, rowTop + 32));

    if (i < entries.length - 1) {
      canvas.drawLine(
        Offset(left, rowTop + rowHeight - 6),
        Offset(right, rowTop + rowHeight - 6),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = 1,
      );
    }
  }
}

void _drawWatermark(Canvas canvas) {
  final painter = TextPainter(
    text: TextSpan(
      text: 'Ptolemy — Traditional Astrology',
      style: GoogleFonts.cormorantGaramond(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.gold.withValues(alpha: 0.5),
        letterSpacing: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset((_shareImageSize - painter.width) / 2, _shareImageSize - _shareWatermarkBand / 2 - painter.height / 2),
  );
}
