import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:love_anniversary_app/widgets/duck_painter.dart';
import 'package:love_anniversary_app/widgets/duck_sprite.dart';

Future<DuckSpriteSheetPainter> _waitForSpriteImage(
  WidgetTester tester,
  int width,
) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('pixel-duck-animation')),
    );
    final painter = paint.painter! as DuckSpriteSheetPainter;
    if (painter.image?.width == width) return painter;
  }
  fail('Duck sprite sheet did not finish loading.');
}

void main() {
  test('jacket sheets contain no unjacketed torso or wing pixels', () async {
    for (final (asset, frameCount) in [
      ('assets/images/duck_front_jacket_sheet.png', duckFrontFrameCount),
      ('assets/images/duck_rear_jacket_sheet.png', duckRearFrameCount),
    ]) {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      for (var frame = 0; frame < frameCount; frame++) {
        var visibleWingPixels = 0;
        for (var y = 38; y < 56; y++) {
          for (var x = 22; x < 42; x++) {
            final offset =
                (y * image.width + frame * duckSpriteFrameSize + x) * 4;
            final rgba =
                (pixels!.getUint8(offset) << 24) |
                (pixels.getUint8(offset + 1) << 16) |
                (pixels.getUint8(offset + 2) << 8) |
                pixels.getUint8(offset + 3);
            expect(
              rgba,
              isNot(0xfffcf1ff),
              reason: 'Uncovered white feathers in $asset, frame $frame.',
            );
            expect(
              rgba,
              isNot(0xffffffff),
              reason: 'Uncovered white feathers in $asset, frame $frame.',
            );
          }
        }
        for (var y = 37; y < 49; y++) {
          for (var x = 8; x < 16; x++) {
            final offset =
                (y * image.width + frame * duckSpriteFrameSize + x) * 4;
            final rgba =
                (pixels!.getUint8(offset) << 24) |
                (pixels.getUint8(offset + 1) << 16) |
                (pixels.getUint8(offset + 2) << 8) |
                pixels.getUint8(offset + 3);
            if (rgba == 0xfffcf1ff ||
                rgba == 0xffffffff ||
                rgba == 0xece6dcff) {
              visibleWingPixels++;
            }
          }
        }
        expect(
          visibleWingPixels,
          greaterThan(0),
          reason:
              'No cream wing feathers visible from jacket sleeve in $asset, frame $frame.',
        );
      }
      image.dispose();
      codec.dispose();
    }
  });

  testWidgets('custom rear sprite is pixel-clean at grocery size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CustomPaint(
              key: ValueKey('custom-rear-preview'),
              size: Size(112, 122),
              painter: PixelDuckRearPainter(gait: 0.25),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('custom-rear-preview')),
      matchesGoldenFile('goldens/duck_custom_rear.png'),
    );
  });

  testWidgets('front sprite renders at grocery-compatible target size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: DuckSpriteWidget(size: Size(240, 205), frameProgress: 0.3),
          ),
        ),
      ),
    );
    final painter = await _waitForSpriteImage(
      tester,
      duckSpriteFrameSize * duckFrontFrameCount,
    );
    expect(painter, isA<DuckSpriteSheetPainter>());
    expect(
      tester.getSize(find.byKey(const ValueKey('pixel-duck-animation'))),
      const Size(240, 205),
    );
    await expectLater(
      find.byKey(const ValueKey('pixel-duck-sprite')),
      matchesGoldenFile('goldens/duck_front_frame.png'),
    );
  });

  testWidgets('blink uses the actual closed-eye frame', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: DuckSpriteWidget(
              size: Size(160, 160),
              frameProgress: 0,
              blink: true,
            ),
          ),
        ),
      ),
    );
    final painter = await _waitForSpriteImage(
      tester,
      duckSpriteFrameSize * duckFrontFrameCount,
    );
    expect(painter.frame, 3);
    await expectLater(
      find.byKey(const ValueKey('pixel-duck-sprite')),
      matchesGoldenFile('goldens/duck_front_blink.png'),
    );
  });

  testWidgets('rear sprite renders at grocery target size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: DuckSpriteWidget(
              size: Size(112, 122),
              view: DuckView.rear,
              frameProgress: 0.3,
            ),
          ),
        ),
      ),
    );
    final painter = await _waitForSpriteImage(
      tester,
      duckSpriteFrameSize * duckRearFrameCount,
    );
    expect(painter.view, DuckView.rear);
    await expectLater(
      find.byKey(const ValueKey('pixel-duck-sprite')),
      matchesGoldenFile('goldens/duck_rear_frame.png'),
    );
  });

  testWidgets('leather jacket is applied to every front and rear frame', (
    tester,
  ) async {
    const jacket = DuckAppearance(equippedItems: ['leather_jacket']);
    for (final (view, frameCount) in [
      (DuckView.front, duckFrontFrameCount),
      (DuckView.rear, duckRearFrameCount),
    ]) {
      for (var frame = 0; frame < frameCount; frame++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: DuckSpriteWidget(
                  size: const Size(160, 160),
                  view: view,
                  appearance: jacket,
                  frameProgress: frame / frameCount,
                ),
              ),
            ),
          ),
        );
        final painter = await _waitForSpriteImage(
          tester,
          duckSpriteFrameSize * frameCount,
        );
        expect(painter.view, view);
        expect(painter.frame, frame);
        expect(painter.jacket, isTrue);
        expect(painter.image?.width, duckSpriteFrameSize * frameCount);
        expect(painter.appearance.equippedItems, contains('leather_jacket'));
      }
    }
  });

  testWidgets('heart pajamas use generated front and rear pixel sheets', (
    tester,
  ) async {
    const pajamas = DuckAppearance(equippedItems: ['heart_pajamas']);
    for (final (view, frameCount) in [
      (DuckView.front, duckFrontFrameCount),
      (DuckView.rear, duckRearFrameCount),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DuckSpriteWidget(
                size: const Size(160, 160),
                view: view,
                appearance: pajamas,
                frameProgress: 0,
              ),
            ),
          ),
        ),
      );
      final painter = await _waitForSpriteImage(
        tester,
        duckSpriteFrameSize * frameCount,
      );
      expect(painter.view, view);
      expect(painter.jacket, isFalse);
      expect(painter.heartPajamas, isTrue);
      expect(painter.image?.width, duckSpriteFrameSize * frameCount);
    }
  });

  testWidgets('outfit changes switch to the integrated jacket sprite sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: DuckSpriteWidget(size: Size(160, 160), frameProgress: 0),
          ),
        ),
      ),
    );
    final basePainter = await _waitForSpriteImage(
      tester,
      duckSpriteFrameSize * duckFrontFrameCount,
    );
    expect(basePainter.jacket, isFalse);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: DuckSpriteWidget(
              size: Size(160, 160),
              appearance: DuckAppearance(equippedItems: ['leather_jacket']),
              frameProgress: 0,
            ),
          ),
        ),
      ),
    );
    final jacketPainter = await _waitForSpriteImage(
      tester,
      duckSpriteFrameSize * duckFrontFrameCount,
    );
    expect(jacketPainter.jacket, isTrue);
    expect(jacketPainter.image, isNot(same(basePainter.image)));
  });

  testWidgets('front sprite sheet asset keeps transparency and pixel edges', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Image(
              image: AssetImage('assets/images/duck_front_sheet.png'),
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Image),
      matchesGoldenFile('goldens/duck_front_sheet.png'),
    );
  });
}
