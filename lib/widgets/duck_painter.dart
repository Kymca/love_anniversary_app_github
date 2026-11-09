import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'duck_mood.dart';

enum DuckHat { none, partyHat, glasses, crown }

enum DuckView { front, rear }

@immutable
class DuckAppearance {
  const DuckAppearance({
    this.bodyColor = const Color(0xFFFFE38C),
    this.hat = DuckHat.none,
    this.equippedItems = const [],
  });

  final Color bodyColor;
  final DuckHat hat;
  final List<String> equippedItems;
}

class DuckPainter extends CustomPainter {
  const DuckPainter({
    this.appearance = const DuckAppearance(),
    this.view = DuckView.front,
    this.blink = false,
    this.joy = 0,
    this.gait = 0,
    this.detailSeed = 0,
    this.showHalo = true,
    this.emotion = DuckEmotion.neutral,
  });

  final DuckAppearance appearance;
  final DuckView view;
  final bool blink;
  final double joy;
  final double gait;
  final int detailSeed;
  final bool showHalo;
  final DuckEmotion emotion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 205);
    if (showHalo) {
      canvas.drawOval(
        const Rect.fromLTWH(63, 24, 114, 154),
        Paint()..color = const Color(0x184F796D),
      );
      canvas.drawCircle(
        const Offset(120, 102),
        76,
        Paint()..color = const Color(0xFFFFF8E8),
      );
      canvas.drawCircle(
        const Offset(120, 102),
        76,
        Paint()
          ..color = const Color(0xFFFFD6A0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    final bodyColor = appearance.bodyColor;
    final shade = Color.lerp(bodyColor, const Color(0xFFCE9A4B), 0.28)!;
    final outlineColor = Color.lerp(bodyColor, const Color(0xFF603F35), 0.38)!;
    final fill = Paint()..color = bodyColor;
    final outline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final bob = joy.clamp(0.0, 1.0).toDouble() * 3;
    final body = Rect.fromCenter(
      center: const Offset(120, 132),
      width: 137,
      height: 108,
    );
    canvas.drawOval(body, fill);
    canvas.drawOval(body, outline);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(120, 142), width: 91, height: 76),
      Paint()..color = const Color(0xFFFFF3CE),
    );

    for (final side in [-1.0, 1.0]) {
      final wing = Rect.fromCenter(
        center: Offset(120 + side * 48, 132),
        width: 39,
        height: 62,
      );
      canvas.drawOval(wing, Paint()..color = shade);
      canvas.drawOval(wing, outline);
    }

    final footPaint = Paint()
      ..color = const Color(0xFFE99243)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final stride = gait == 0 ? 0.0 : math.sin(gait * math.pi * 2) * 3;
    for (final side in [-1.0, 1.0]) {
      final x = 120 + side * 27;
      final footY = 180 + stride * side;
      canvas.drawLine(
        Offset(x, 169),
        Offset(x + stride * side, footY),
        footPaint,
      );
      canvas.drawLine(
        Offset(x + stride * side, footY),
        Offset(x + stride * side - 11, footY + 2),
        footPaint,
      );
      canvas.drawLine(
        Offset(x + stride * side, footY),
        Offset(x + stride * side + 10, footY + 2),
        footPaint,
      );
    }

    final head = Rect.fromCenter(
      center: Offset(120, 78 - bob),
      width: 104,
      height: 91,
    );
    canvas.drawOval(head, fill);
    canvas.drawOval(head, outline);

    if (view == DuckView.front) {
      final beak = Path()
        ..moveTo(99, 98)
        ..quadraticBezierTo(120, 90, 141, 98)
        ..lineTo(120, 115)
        ..close();
      canvas.drawPath(beak, Paint()..color = const Color(0xFFEE9545));
      canvas.drawPath(beak, outline);
      for (final x in [99.0, 141.0]) {
        if (blink) {
          canvas.drawLine(
            Offset(x - 5, 76),
            Offset(x + 5, 76),
            Paint()
              ..color = const Color(0xFF493A32)
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round,
          );
        } else {
          canvas.drawCircle(
            Offset(x, 76),
            4.2,
            Paint()..color = const Color(0xFF493A32),
          );
          canvas.drawCircle(
            Offset(x - 1, 74),
            1.2,
            Paint()..color = Colors.white,
          );
        }
      }
      final cheeks = Paint()
        ..color = const Color(0xFFF3A1A0).withValues(alpha: 0.62);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(82, 91), width: 15, height: 8),
        cheeks,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(158, 91), width: 15, height: 8),
        cheeks,
      );
      _drawEmotion(canvas, bob);
    } else {
      final tail = Path()
        ..moveTo(105, 117)
        ..quadraticBezierTo(120, 99, 135, 117)
        ..lineTo(130, 127)
        ..quadraticBezierTo(120, 122, 110, 127)
        ..close();
      canvas.drawPath(tail, Paint()..color = shade);
    }

    _drawHat(canvas);
    if (appearance.equippedItems.contains('bow')) {
      final bow = Paint()..color = const Color(0xFFCE6D88);
      canvas.drawCircle(const Offset(120, 123), 4, bow);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(111, 121), width: 12, height: 8),
        bow,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(129, 121), width: 12, height: 8),
        bow,
      );
    }
    canvas.restore();
  }

  void _drawEmotion(Canvas canvas, double bob) {
    if (emotion == DuckEmotion.neutral) return;
    final face = Paint()..color = const Color(0xFFFFFCF1);
    final ink = Paint()
      ..color = const Color(0xFF493A32)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.square;
    for (final x in [94.0, 136.0]) {
      canvas.drawRect(Rect.fromLTWH(x, 68 - bob, 11, 14), face);
    }

    switch (emotion) {
      case DuckEmotion.neutral:
        return;
      case DuckEmotion.joyful:
      case DuckEmotion.calm:
        for (final x in [96.0, 138.0]) {
          canvas.drawLine(Offset(x, 77 - bob), Offset(x + 7, 77 - bob), ink);
        }
        return;
      case DuckEmotion.thoughtful:
        canvas.drawCircle(
          Offset(101, 76 - bob),
          3.2,
          Paint()..color = const Color(0xFF493A32),
        );
        canvas.drawCircle(
          Offset(143, 76 - bob),
          1.8,
          Paint()..color = const Color(0xFF493A32),
        );
        canvas.drawLine(Offset(139, 68 - bob), Offset(146, 67 - bob), ink);
        return;
      case DuckEmotion.tired:
        for (final x in [96.0, 138.0]) {
          canvas.drawRect(
            Rect.fromLTWH(x, 74 - bob, 7, 4),
            Paint()..color = const Color(0xFF493A32),
          );
        }
        return;
      case DuckEmotion.blue:
        for (final x in [97.0, 139.0]) {
          canvas.drawCircle(
            Offset(x, 75 - bob),
            2.7,
            Paint()..color = const Color(0xFF493A32),
          );
        }
        canvas.drawCircle(
          Offset(148, 83 - bob),
          2.2,
          Paint()..color = const Color(0xFF91CDE0),
        );
        return;
      case DuckEmotion.angry:
        canvas.drawLine(Offset(94, 69 - bob), Offset(103, 73 - bob), ink);
        canvas.drawLine(Offset(146, 69 - bob), Offset(137, 73 - bob), ink);
        for (final x in [98.0, 140.0]) {
          canvas.drawRect(
            Rect.fromLTWH(x, 76 - bob, 5, 4),
            Paint()..color = const Color(0xFF493A32),
          );
        }
        final huff = Paint()..color = const Color(0xFFFF9DA7);
        canvas.drawCircle(Offset(157, 69 - bob), 2.8, huff);
        canvas.drawCircle(Offset(161, 65 - bob), 1.8, huff);
        return;
    }
  }

  void _drawHat(Canvas canvas) {
    final fill = Paint()..color = const Color(0xFFB65A76);
    switch (appearance.hat) {
      case DuckHat.none:
        return;
      case DuckHat.partyHat:
        final path = Path()
          ..moveTo(91, 41)
          ..lineTo(120, 5)
          ..lineTo(148, 41)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawCircle(
          const Offset(120, 5),
          4,
          Paint()..color = Colors.white,
        );
      case DuckHat.crown:
        final path = Path()
          ..moveTo(92, 48)
          ..lineTo(87, 24)
          ..lineTo(104, 35)
          ..lineTo(120, 15)
          ..lineTo(136, 35)
          ..lineTo(153, 24)
          ..lineTo(148, 48)
          ..close();
        canvas.drawPath(path, fill);
      case DuckHat.glasses:
        final glasses = Paint()
          ..color = const Color(0xFF68506B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(86, 66, 27, 21),
            const Radius.circular(8),
          ),
          glasses,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(127, 66, 27, 21),
            const Radius.circular(8),
          ),
          glasses,
        );
        canvas.drawLine(const Offset(113, 74), const Offset(127, 74), glasses);
    }
  }

  @override
  bool shouldRepaint(covariant DuckPainter oldDelegate) =>
      oldDelegate.appearance.bodyColor != appearance.bodyColor ||
      oldDelegate.appearance.hat != appearance.hat ||
      !listEquals(
        oldDelegate.appearance.equippedItems,
        appearance.equippedItems,
      ) ||
      oldDelegate.view != view ||
      oldDelegate.blink != blink ||
      oldDelegate.joy != joy ||
      oldDelegate.gait != gait ||
      oldDelegate.detailSeed != detailSeed ||
      oldDelegate.showHalo != showHalo ||
      oldDelegate.emotion != emotion;
}

class PixelDuckRearPainter extends CustomPainter {
  const PixelDuckRearPainter({
    this.appearance = const DuckAppearance(),
    this.gait = 0,
    this.joy = 0,
  });

  final DuckAppearance appearance;
  final double gait;
  final double joy;

  @override
  void paint(Canvas canvas, Size size) {
    const columns = 18.0;
    const rows = 30.0;
    const horizontalScale = 1.25;
    final pixel = math.min(
      size.width / (columns * horizontalScale),
      size.height / rows,
    );
    final left = (size.width - columns * pixel * horizontalScale) / 2;
    final top = (size.height - rows * pixel) / 2;
    canvas
      ..save()
      ..translate(left, top)
      ..scale(pixel * horizontalScale, pixel);

    final outline = Paint()
      ..color = const Color(0xFF403A38)
      ..isAntiAlias = false;
    final body = Paint()
      ..color = Color.lerp(const Color(0xFFFFF9E6), appearance.bodyColor, 0.18)!
      ..isAntiAlias = false;
    final featherShadow = Paint()
      ..color = const Color(0xFFC3CED9)
      ..isAntiAlias = false;
    final featherLight = Paint()
      ..color = const Color(0xFFFEF7E5)
      ..isAntiAlias = false;
    final footShade = Paint()
      ..color = const Color(0xFFB94207)
      ..isAntiAlias = false;
    final footColor = Paint()
      ..color = const Color(0xFFFA7600)
      ..isAntiAlias = false;

    void pixelAt(Paint paint, int x, int y) {
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
    }

    void row(Paint paint, int y, int start, int end) {
      for (var x = start; x <= end; x++) {
        pixelAt(paint, x, y);
      }
    }

    const silhouette = <(int, int)>[
      (8, 9),
      (7, 10),
      (6, 11),
      (5, 12),
      (4, 13),
      (4, 13),
      (3, 14),
      (3, 14),
      (3, 14),
      (2, 15),
      (2, 15),
      (1, 16),
      (1, 16),
      (0, 17),
      (0, 17),
      (0, 17),
      (0, 17),
      (0, 17),
      (0, 17),
      (1, 16),
      (1, 16),
      (2, 15),
      (3, 14),
      (4, 13),
      (5, 12),
      (6, 11),
    ];
    for (var y = 0; y < silhouette.length; y++) {
      final (start, end) = silhouette[y];
      row(outline, y, start, end);
      row(body, y, start + 1, end - 1);
      if (y >= 7 && y <= 20) {
        pixelAt(featherShadow, start + 1, y);
        pixelAt(featherShadow, end - 1, y);
      }
    }

    final pose = ((gait * 4).floor() % 4);
    final wingOffsets = const [0, -1, -2, 0];
    final wingOffset = wingOffsets[pose] + (joy > 0.35 ? -1 : 0);
    const wingRows = <(int, int)>[
      (2, 3),
      (1, 4),
      (0, 4),
      (0, 5),
      (1, 5),
      (2, 5),
      (3, 5),
      (4, 5),
    ];
    for (final side in [0, 1]) {
      final wingX = side == 0 ? 0 : 12;
      final wingY = 13 + (side == 0 ? wingOffset : -wingOffset);
      for (var y = 0; y < wingRows.length; y++) {
        final (start, end) = wingRows[y];
        final rowStart = side == 0 ? start : 5 - end;
        final rowEnd = side == 0 ? end : 5 - start;
        for (var x = rowStart; x <= rowEnd; x++) {
          final featherX = side == 0 ? x : 5 - x;
          final edge =
              x == rowStart ||
              x == rowEnd ||
              y == 0 ||
              y == wingRows.length - 1;
          final featherMark =
              (y == 2 && featherX == 2) ||
              (y == 3 && featherX == 3) ||
              (y == 4 && featherX == 4);
          final paint = edge
              ? outline
              : (featherMark ? featherShadow : featherLight);
          pixelAt(paint, wingX + x, wingY + y);
        }
      }
      pixelAt(body, wingX + (side == 0 ? 4 : 1), wingY + 3);
      pixelAt(body, wingX + (side == 0 ? 4 : 1), wingY + 4);
    }

    pixelAt(featherShadow, 8, 20);
    pixelAt(featherLight, 9, 20);
    pixelAt(featherShadow, 10, 20);
    pixelAt(outline, 8, 21);
    pixelAt(featherLight, 9, 21);
    pixelAt(outline, 10, 21);
    pixelAt(featherShadow, 9, 22);

    final stride = math.sin(gait * math.pi * 2);
    final leftLift = stride > 0.25 ? -1 : 0;
    final rightLift = stride < -0.25 ? -1 : 0;
    for (final foot in [(x: 4, lift: leftLift), (x: 10, lift: rightLift)]) {
      final y = 26 + foot.lift;
      row(outline, y, foot.x + 1, foot.x + 3);
      row(footShade, y + 1, foot.x + 1, foot.x + 3);
      row(footColor, y + 2, foot.x, foot.x + 4);
      row(footColor, y + 3, foot.x - 1, foot.x + 5);
      pixelAt(outline, foot.x - 1, y + 3);
      pixelAt(outline, foot.x + 5, y + 3);
    }

    if (appearance.hat != DuckHat.none) {
      final accessory = Paint()
        ..color = const Color(0xFFB65A76)
        ..isAntiAlias = false;
      row(accessory, 0, 8, 9);
      row(accessory, 1, 7, 10);
      if (appearance.hat == DuckHat.crown) {
        pixelAt(accessory, 7, 0);
        pixelAt(accessory, 10, 0);
      }
    }
    if (appearance.equippedItems.contains('bow')) {
      final bow = Paint()
        ..color = const Color(0xFFCE6D88)
        ..isAntiAlias = false;
      pixelAt(bow, 7, 11);
      pixelAt(bow, 10, 11);
      row(bow, 12, 8, 9);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PixelDuckRearPainter oldDelegate) =>
      oldDelegate.appearance.bodyColor != appearance.bodyColor ||
      oldDelegate.appearance.hat != appearance.hat ||
      !listEquals(
        oldDelegate.appearance.equippedItems,
        appearance.equippedItems,
      ) ||
      oldDelegate.gait != gait ||
      oldDelegate.joy != joy;
}
