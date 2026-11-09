import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/screens/mini_games/grocery_store_screen.dart';
import 'package:love_anniversary_app/widgets/duck_mood.dart';
import 'package:love_anniversary_app/widgets/duck_painter.dart';
import 'package:love_anniversary_app/widgets/duck_sprite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  testWidgets('jacket and pixel shop contact sheet preview', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    const jacket = DuckAppearance(equippedItems: ['leather_jacket']);

    Widget poseCell(
      String label, {
      required DuckView view,
      required double progress,
      DuckEmotion emotion = DuckEmotion.neutral,
      Offset offset = Offset.zero,
    }) => SizedBox(
      width: 100,
      height: 116,
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 9, color: Color(0xFF40372F)),
          ),
          const SizedBox(height: 2),
          Transform.translate(
            offset: offset,
            child: DuckSpriteWidget(
              size: const Size(96, 96),
              view: view,
              appearance: jacket,
              frameProgress: progress,
              emotion: emotion,
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFF3E7D1),
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PIXEL DUCK — LEATHER JACKET',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF382F2C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (
                              var frame = 0;
                              frame < duckFrontFrameCount;
                              frame++
                            )
                              poseCell(
                                'idle ${frame + 1}',
                                view: DuckView.front,
                                progress: frame / duckFrontFrameCount,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'MOOD REACTIONS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF382F2C),
                          ),
                        ),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final emotion in DuckEmotion.values)
                              poseCell(
                                emotion.name,
                                view: DuckView.front,
                                progress: 0.34,
                                emotion: emotion,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'JUMP / PARTNER TRANSITION',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF382F2C),
                          ),
                        ),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            poseCell(
                              'takeoff',
                              view: DuckView.front,
                              progress: 0.18,
                              offset: const Offset(0, -10),
                            ),
                            poseCell(
                              'landing',
                              view: DuckView.front,
                              progress: 0.68,
                              offset: const Offset(0, 5),
                            ),
                            poseCell(
                              'exit right',
                              view: DuckView.front,
                              progress: 0.5,
                              offset: const Offset(14, 0),
                            ),
                            poseCell(
                              'enter left',
                              view: DuckView.front,
                              progress: 0.5,
                              offset: const Offset(-14, 0),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'REAR / SHOP GAIT',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF382F2C),
                          ),
                        ),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (
                              var frame = 0;
                              frame < duckRearFrameCount;
                              frame++
                            )
                              poseCell(
                                'rear ${frame + 1}',
                                view: DuckView.rear,
                                progress: frame / duckRearFrameCount,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'PIXEL GROCERY — PERSPECTIVE VIEW',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF382F2C),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRect(
                          child: GroceryStoreScreen(
                            duckName: 'Кряква',
                            duckAppearance: jacket,
                            catalogSeed: 41,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    final aisleContext = tester.element(
      find.byKey(const ValueKey('grocery-aisle-scene')),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/grocery_aisle_scene.png'),
        aisleContext,
      );
      await precacheImage(
        const AssetImage('assets/images/grocery_products_sheet.png'),
        aisleContext,
      );
      await precacheImage(
        const AssetImage('assets/images/grocery_price_tag_blank.png'),
        aisleContext,
      );
    });
    await tester.pump();

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/duck_jacket_pixel_shop_preview.png'),
    );
  });
}
