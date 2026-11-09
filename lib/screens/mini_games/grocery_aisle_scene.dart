import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/grocery_catalog.dart';
import '../../widgets/duck_painter.dart';
import '../../widgets/duck_sprite.dart';

class GroceryAisleBackdrop extends StatelessWidget {
  const GroceryAisleBackdrop({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const ValueKey('grocery-aisle-scene'),
    painter: GroceryAisleScenePainter(
      storeSign: AppLocalizations.of(context)!.storeSign,
    ),
    child: const SizedBox.expand(),
  );
}

class GroceryCashierScene extends StatelessWidget {
  const GroceryCashierScene({
    super.key,
    required this.cashierFrame,
    required this.customerDuck,
    required this.checkoutItems,
    required this.customerProgress,
  });

  final int cashierFrame;
  final Widget customerDuck;
  final Widget checkoutItems;
  final double customerProgress;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final cashierSize = math.min(width * 0.18, height * 0.21);
      return Stack(
        key: const ValueKey('grocery-cashier-scene'),
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/grocery_cashier_scene.png',
              key: const ValueKey('grocery-cashier-background'),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
          Positioned(
            left: width * 0.41,
            top: height * 0.4583 - cashierSize * 0.92,
            child: DuckCashierSprite(
              frame: cashierFrame,
              size: Size.square(cashierSize),
            ),
          ),
          Positioned(
            left: width * (0.05 + 0.45 * customerProgress) - 56,
            bottom: height * 0.45,
            child: customerDuck,
          ),
          Positioned(
            left: width * 0.09,
            right: width * 0.09,
            top: height * 0.62,
            child: checkoutItems,
          ),
        ],
      );
    },
  );
}

class DuckCashierSprite extends StatelessWidget {
  const DuckCashierSprite({super.key, required this.frame, required this.size});

  static const frameCount = 6;

  final int frame;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final safeFrame = frame % frameCount;
    return SizedBox(
      key: const ValueKey('grocery-cashier-duck'),
      width: size.width,
      height: size.height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: size.width * frameCount,
          maxHeight: size.height,
          child: Transform.translate(
            offset: Offset(-size.width * safeFrame, 0),
            child: Image.asset(
              'assets/images/duck_cashier_front_sheet.png',
              width: size.width * frameCount,
              height: size.height,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
      ),
    );
  }
}

class GroceryRearDuck extends StatelessWidget {
  const GroceryRearDuck({
    super.key,
    required this.gait,
    required this.joy,
    required this.onTap,
    required this.name,
    this.appearance = const DuckAppearance(),
  });

  final double gait;
  final double joy;
  final VoidCallback onTap;
  final String name;
  final DuckAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final stride = math.sin(gait * math.pi * 2);
    final pixelDuck =
        appearance.equippedItems.contains('leather_jacket') ||
        (appearance.bodyColor == const Color(0xFFFFE38C) &&
            appearance.hat == DuckHat.none &&
            appearance.equippedItems.isEmpty);
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.rearDuckSemantics(name),
      child: GestureDetector(
        key: const ValueKey('grocery-duck-rear'),
        onTap: onTap,
        child: Transform.translate(
          offset: Offset(stride * 2.2, -joy * 8 * (1 - joy).abs()),
          child: Transform.rotate(
            angle: stride * 0.035,
            alignment: Alignment.bottomCenter,
            child: pixelDuck
                ? DuckSpriteWidget(
                    size: const Size(112, 122),
                    view: DuckView.rear,
                    appearance: appearance,
                    frameProgress: gait,
                  )
                : CustomPaint(
                    size: const Size(112, 122),
                    painter: PixelDuckRearPainter(
                      appearance: appearance,
                      gait: gait,
                      joy: joy,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class GroceryAisleScenePainter extends CustomPainter {
  const GroceryAisleScenePainter({required this.storeSign});

  final String storeSign;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 160, size.height / 220);
    final wall = _paint(const Color(0xFFE8D9B6));
    final wallLight = _paint(const Color(0xFFF5EACD));
    final wallShade = _paint(const Color(0xFFC9B58F));
    final darkWood = _paint(const Color(0xFF554239));
    final floor = _paint(const Color(0xFFB88F68));
    final floorLight = _paint(const Color(0xFFD2AA7A));
    final deepFloor = _paint(const Color(0xFF806047));

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 160, 220),
      _paint(const Color(0xFF9A795D)),
    );
    canvas.drawRect(const Rect.fromLTWH(0, 0, 160, 57), wall);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 160, 8), darkWood);
    canvas.drawRect(const Rect.fromLTWH(0, 8, 160, 3), wallShade);
    canvas.drawRect(const Rect.fromLTWH(0, 11, 160, 2), wallLight);
    for (var beam = 0; beam < 5; beam++) {
      final x = beam * 40.0;
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, 13), darkWood);
    }
    for (var panel = 0; panel < 5; panel++) {
      final x = 8 + panel * 31;
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), 18, 24, 32), wallShade);
      canvas.drawRect(Rect.fromLTWH(x + 2.0, 20, 20, 27), wallLight);
      canvas.drawRect(
        Rect.fromLTWH(x + 4.0, 22, 16, 2),
        _paint(const Color(0xFFFFF6DD)),
      );
      canvas.drawRect(Rect.fromLTWH(x + 4.0, 46, 16, 1), wallShade);
    }

    canvas.drawRect(const Rect.fromLTWH(57, 14, 46, 17), darkWood);
    canvas.drawRect(
      const Rect.fromLTWH(60, 17, 40, 11),
      _paint(const Color(0xFF5F9278)),
    );
    _drawText(
      canvas,
      storeSign,
      const Offset(80, 19),
      7,
      const Color(0xFFFFF3D0),
    );
    for (final lampX in [24.0, 136.0]) {
      canvas.drawRect(Rect.fromLTWH(lampX - 7, 37, 14, 2), wallShade);
      canvas.drawRect(
        Rect.fromLTWH(lampX - 5, 39, 10, 4),
        _paint(const Color(0xFFFFD978)),
      );
      canvas.drawRect(
        Rect.fromLTWH(lampX - 3, 43, 6, 2),
        _paint(const Color(0xFFE7AE5F)),
      );
    }

    final vanishing = const Offset(80, 138);
    final aisle = Path()
      ..moveTo(72, 138)
      ..lineTo(88, 138)
      ..lineTo(160, 220)
      ..lineTo(0, 220)
      ..close();
    canvas.drawPath(aisle, floor);
    canvas.drawPath(
      Path()
        ..moveTo(72, 138)
        ..lineTo(88, 138)
        ..lineTo(160, 220)
        ..lineTo(0, 220)
        ..close(),
      _paint(const Color(0xFFE0BD8D), style: PaintingStyle.stroke, width: 2),
    );

    for (final endX in [0.0, 160.0]) {
      canvas.drawLine(
        vanishing,
        Offset(endX, 220),
        _paint(const Color(0xFF8E6B4E), width: 2),
      );
    }
    for (final row in [151.0, 164.0, 181.0, 202.0, 216.0]) {
      final depth = (row - 138) / (220 - 138);
      final half = 8 + depth * 72;
      canvas.drawRect(
        Rect.fromLTWH(80 - half, row, half * 2, depth * 2 + 1),
        floorLight,
      );
      canvas.drawRect(
        Rect.fromLTWH(80 - half, row + depth * 2 + 1, half * 2, 1),
        deepFloor,
      );
    }

    _drawShelf(canvas, 0);
    _drawShelf(canvas, 1);
    canvas.drawRect(const Rect.fromLTWH(0, 214, 160, 6), deepFloor);
    canvas.drawRect(
      const Rect.fromLTWH(8, 211, 144, 2),
      _paint(const Color(0xFFF0C184)),
    );
    canvas.restore();
  }

  void _drawShelf(Canvas canvas, int index) {
    final shelfY = GroceryCatalog.shelfRowPositions[index] * 220;
    final back = _paint(const Color(0xFF46675D));
    final backLight = _paint(const Color(0xFF658676));
    final ink = _paint(const Color(0xFF49392F));
    final wood = _paint(const Color(0xFF9A6749));
    final woodLight = _paint(const Color(0xFFDDA66D));
    final woodShade = _paint(const Color(0xFF684936));

    canvas.drawRect(Rect.fromLTWH(3, shelfY - 15, 154, 15), back);
    canvas.drawRect(Rect.fromLTWH(5, shelfY - 13, 150, 2), backLight);
    for (final supportX in [5.0, 154.0]) {
      canvas.drawRect(Rect.fromLTWH(supportX, shelfY - 15, 2, 21), ink);
      canvas.drawRect(
        Rect.fromLTWH(supportX + 2, shelfY - 12, 1, 16),
        backLight,
      );
    }
    canvas.drawRect(Rect.fromLTWH(0, shelfY - 2, 160, 4), ink);
    canvas.drawRect(Rect.fromLTWH(2, shelfY - 2, 156, 2), woodLight);
    canvas.drawRect(Rect.fromLTWH(0, shelfY + 2, 160, 8), wood);
    canvas.drawRect(Rect.fromLTWH(3, shelfY + 3, 154, 2), woodLight);
    canvas.drawRect(Rect.fromLTWH(0, shelfY + 10, 160, 2), woodShade);
    canvas.drawRect(Rect.fromLTWH(8, shelfY + 13, 144, 2), ink);
    canvas.drawRect(
      Rect.fromLTWH(11, shelfY + 13, 138, 1),
      index.isEven
          ? _paint(const Color(0xFFB27A4D))
          : _paint(const Color(0xFFB98A55)),
    );

    for (final bracketX in [18.0, 80.0, 142.0]) {
      canvas.drawRect(Rect.fromLTWH(bracketX, shelfY + 12, 3, 8), ink);
      canvas.drawRect(
        Rect.fromLTWH(bracketX + 1, shelfY + 13, 1, 5),
        backLight,
      );
    }
  }

  Paint _paint(
    Color color, {
    PaintingStyle style = PaintingStyle.fill,
    double width = 1,
  }) => Paint()
    ..color = color
    ..isAntiAlias = false
    ..style = style
    ..strokeWidth = width;

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    double scale,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: scale,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant GroceryAisleScenePainter oldDelegate) =>
      oldDelegate.storeSign != storeSign;
}

class PixelGroceryProduct extends StatelessWidget {
  const PixelGroceryProduct({
    super.key,
    required this.productId,
    required this.size,
  });

  final String productId;
  final double size;

  static const _frameByProduct = {
    'crumbs': 0,
    'watermelon': 1,
    'worm': 2,
    'pizza': 3,
    'apple': 4,
    'cheese': 5,
    'carrot': 6,
    'milk': 7,
  };

  static const _shelfRestOffsets = <String, double>{
    'crumbs': 8,
    'watermelon': 16,
    'worm': 6,
    'pizza': 11,
    'apple': 10,
    'cheese': 13,
    'carrot': 8,
    'milk': 7,
  };

  static double shelfRestOffset(String productId) {
    final offset = _shelfRestOffsets[productId];
    if (offset == null) throw ArgumentError.value(productId, 'productId');
    return offset;
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frameByProduct[productId];
    if (frame == null) {
      throw ArgumentError.value(productId, 'productId');
    }

    if (productId == 'worm') {
      return SizedBox(
        key: key ?? ValueKey('pixel-product-$productId'),
        width: size,
        height: size,
        child: _PixelWormJar(size: size),
      );
    }

    return Image.asset(
      key: key ?? ValueKey('pixel-product-$productId'),
      'assets/images/grocery_products/$productId.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
    );
  }
}

class _PixelWormJar extends StatefulWidget {
  const _PixelWormJar({required this.size});

  final double size;

  @override
  State<_PixelWormJar> createState() => _PixelWormJarState();
}

class _PixelWormJarState extends State<_PixelWormJar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _crawl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _crawl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _crawl,
    builder: (context, child) => CustomPaint(
      key: const ValueKey('pixel-worm-jar-painter'),
      painter: PixelWormJarPainter(progress: _crawl.value),
      size: Size.square(widget.size),
    ),
  );
}

class PixelWormJarPainter extends CustomPainter {
  const PixelWormJarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 64;
    Rect rect(double x, double y, double width, double height) =>
        Rect.fromLTWH(x * unit, y * unit, width * unit, height * unit);
    Paint paint(Color color) => Paint()
      ..color = color
      ..isAntiAlias = false;
    void pixel(Color color, double x, double y, double width, double height) {
      canvas.drawRect(rect(x, y, width, height), paint(color));
    }

    const outline = Color(0xFF493A34);
    const glass = Color(0xB9B8E5E8);
    const glassShade = Color(0xFF80B8C0);
    const glint = Color(0xFFF0FFFF);

    pixel(outline, 20, 5, 24, 2);
    pixel(glassShade, 18, 7, 28, 2);
    pixel(outline, 17, 9, 30, 2);
    pixel(outline, 14, 14, 36, 39);
    pixel(glass, 16, 14, 32, 38);
    pixel(glassShade, 14, 18, 3, 30);
    pixel(glassShade, 47, 18, 3, 30);
    pixel(outline, 16, 52, 32, 3);
    pixel(glassShade, 18, 54, 28, 2);
    pixel(glint, 20, 17, 2, 10);
    pixel(glint, 20, 29, 1, 4);
    pixel(glint.withValues(alpha: 0.6), 43, 19, 2, 8);

    final travel = 2 + progress * 10;
    final bounce = math.sin(progress * math.pi * 2) * 1.5;
    final wormY = 40 + bounce;
    const wormOutline = Color(0xFF36533A);
    const wormLight = Color(0xFFB8D975);
    const wormMid = Color(0xFF78B94F);
    const wormDark = Color(0xFF4F8D47);
    for (var index = 0; index < 5; index++) {
      final x = 18 + travel + index * 3.8;
      final y =
          wormY -
          (index == 2
              ? 2.0
              : index == 3
              ? 1.0
              : 0.0);
      pixel(wormOutline, x - 1, y - 1, 4, 4);
      pixel(index.isEven ? wormLight : wormMid, x, y, 2, 2);
      pixel(wormDark, x + 1, y + 2, 1, 1);
    }
    final headX = 18 + travel + 15.5;
    pixel(wormOutline, headX, wormY - 2, 4, 4);
    pixel(wormLight, headX + 1, wormY - 1, 2, 2);
    pixel(outline, headX + 3, wormY - 1, 1, 1);
    pixel(wormDark, headX + 2, wormY - 3, 1, 2);
    pixel(wormDark, headX + 4, wormY - 3, 1, 2);

    pixel(outline, 14, 12, 36, 2);
    pixel(glassShade, 17, 14, 30, 1);
    pixel(outline, 14, 53, 36, 2);
    pixel(glassShade, 18, 55, 28, 1);
  }

  @override
  bool shouldRepaint(covariant PixelWormJarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
