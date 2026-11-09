import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/screens/duck_clothing_shop_screen.dart';
import 'package:love_anniversary_app/screens/mini_games/grocery_store_screen.dart';
import 'package:love_anniversary_app/screens/mini_games/grocery_aisle_scene.dart';
import 'package:love_anniversary_app/services/grocery_catalog.dart';
import 'package:love_anniversary_app/services/grocery_wallet.dart';
import 'package:love_anniversary_app/widgets/duck_painter.dart';
import 'package:love_anniversary_app/widgets/duck_sprite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  testWidgets('wardrobe lists only the default and purchased costumes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final wallet = await GroceryWallet.open();
    await tester.pumpWidget(
      localizedTestApp(
        home: DuckClothingShopScreen(
          wallet: wallet,
          selectedSkinId: null,
          onSelectSkin: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('duck-skin-default')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('duck-skin-leather-jacket')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('buy-skin-leather-jacket')), findsNothing);
  });

  testWidgets('shop allows an unaffordable click and explains the shortfall', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final wallet = await GroceryWallet.open();
    await tester.pumpWidget(
      localizedTestApp(
        home: DuckClothingShopScreen(
          wallet: wallet,
          selectedSkinId: null,
          showShop: true,
          onSelectSkin: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('duck-skin-default')), findsNothing);
    expect(
      find.byKey(const ValueKey('duck-skin-leather-jacket')),
      findsOneWidget,
    );
    final buyButton = find.byKey(const ValueKey('buy-skin-leather-jacket'));
    expect(tester.widget<FilledButton>(buyButton).onPressed, isNotNull);
    await tester.ensureVisible(buyButton);
    await tester.tap(buyButton);
    await tester.pump();

    expect(find.textContaining('Недостаточно средств'), findsOneWidget);
  });

  testWidgets('shop localizes unaffordable purchase feedback in Ukrainian', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final wallet = await GroceryWallet.open();
    await tester.pumpWidget(
      localizedTestApp(
        locale: const Locale('uk'),
        home: DuckClothingShopScreen(
          wallet: wallet,
          selectedSkinId: null,
          showShop: true,
          onSelectSkin: (_) async {},
        ),
      ),
    );
    await tester.pump();
    final buyButton = find.byKey(const ValueKey('buy-skin-leather-jacket'));
    await tester.ensureVisible(buyButton);
    await tester.pump();
    await tester.tap(buyButton);
    await tester.pump();

    expect(find.textContaining('Недостатньо коштів'), findsOneWidget);
  });

  testWidgets('purchased costume appears in wardrobe with wear action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      GroceryWallet.storageKey: jsonEncode({
        'balance': 0,
        'lastGrantDate': '2026-11-09',
        'purchasedSkinIds': ['leather_jacket'],
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final wallet = await GroceryWallet.open(preferences: preferences);
    await tester.pumpWidget(
      localizedTestApp(
        home: DuckClothingShopScreen(
          wallet: wallet,
          selectedSkinId: null,
          onSelectSkin: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('duck-skin-leather-jacket')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('buy-skin-leather-jacket')), findsNothing);
    expect(
      find.byKey(const ValueKey('select-skin-leather_jacket')),
      findsOneWidget,
    );
  });

  testWidgets('heart pajamas preview, purchase price, and wear action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      GroceryWallet.storageKey: jsonEncode({'balance': 7500}),
    });
    final wallet = await GroceryWallet.open();
    String? selectedSkinId;
    await tester.pumpWidget(
      localizedTestApp(
        home: DuckClothingShopScreen(
          wallet: wallet,
          selectedSkinId: null,
          showShop: true,
          onSelectSkin: (skinId) async {
            selectedSkinId = skinId;
          },
        ),
      ),
    );
    await tester.pump();

    final pajamasCard = find.byKey(const ValueKey('duck-skin-heart-pajamas'));
    await tester.ensureVisible(pajamasCard);
    await tester.tap(pajamasCard);
    await tester.pump();
    final preview = find.byKey(const ValueKey('skin-preview-heart_pajamas'));
    expect(preview, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    final previewPainter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: preview,
                    matching: find.byKey(
                      const ValueKey('pixel-duck-animation'),
                    ),
                  ),
                )
                .painter!
            as DuckSpriteSheetPainter;
    expect(previewPainter.heartPajamas, isTrue);
    await tester.tap(find.text('Закрыть'));
    await tester.pump();

    final buyButton = find.byKey(const ValueKey('buy-skin-heart_pajamas'));
    expect(find.text('7500 ₴'), findsOneWidget);
    await tester.ensureVisible(buyButton);
    await tester.tap(buyButton);
    await tester.pump();
    expect(wallet.balance, 0);
    expect(wallet.purchasedSkinIds, ['heart_pajamas']);

    final wearButton = find.byKey(const ValueKey('select-skin-heart_pajamas'));
    await tester.ensureVisible(wearButton);
    await tester.tap(wearButton);
    await tester.pump();
    expect(selectedSkinId, 'heart_pajamas');
  });

  testWidgets('grocery products use the sharp individual pixel sprites', (
    tester,
  ) async {
    const productIds = GroceryCatalog.productIds;
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            for (final productId in productIds)
              PixelGroceryProduct(productId: productId, size: 64),
          ],
        ),
      ),
    );
    await tester.pump();

    for (final productId in productIds) {
      if (productId == 'worm') {
        expect(
          find.byKey(const ValueKey('pixel-product-worm')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('pixel-worm-jar-painter')),
          findsOneWidget,
        );
        continue;
      }
      final image = tester.widget<Image>(
        find.byKey(ValueKey('pixel-product-$productId')),
      );
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/grocery_products/$productId.png',
      );
      expect(image.width, 64);
      expect(image.height, 64);
      expect(image.filterQuality, FilterQuality.none);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('worm crawls in its jar and keeps its cycle through rebuilds', (
    tester,
  ) async {
    Widget product() => const MaterialApp(
      home: Center(child: PixelGroceryProduct(productId: 'worm', size: 64)),
    );

    await tester.pumpWidget(product());
    await tester.pump(const Duration(milliseconds: 450));
    double progress() =>
        (tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('pixel-worm-jar-painter')),
                    )
                    .painter!
                as PixelWormJarPainter)
            .progress;

    final beforeRebuild = progress();
    expect(beforeRebuild, greaterThan(0));
    await tester.pumpWidget(product());
    await tester.pump(const Duration(milliseconds: 100));
    final afterRebuild = progress();
    expect(afterRebuild, greaterThan(beforeRebuild));

    await tester.pump(const Duration(milliseconds: 1500));
    expect(progress(), lessThan(afterRebuild));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty basket cannot proceed to checkout', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final wallet = await GroceryWallet.open();
    await tester.pumpWidget(
      localizedTestApp(
        home: GroceryStoreScreen(
          duckName: 'Кряква',
          wallet: wallet,
          catalogSeed: 41,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('grocery-shopping-basket')),
      findsOneWidget,
    );
    final basketArt = tester.widget<Image>(
      find.byKey(const ValueKey('grocery-basket-art')),
    );
    expect(
      (basketArt.image as AssetImage).assetName,
      'assets/images/grocery_basket_red.png',
    );
    expect(basketArt.width, 96);
    expect(basketArt.height, 72);
    final checkoutButton = find.widgetWithText(
      FilledButton,
      'Выбери хотя бы один продукт',
    );
    expect(tester.widget<FilledButton>(checkoutButton).onPressed, isNull);
    expect(find.byKey(const ValueKey('grocery-checkout-basket')), findsNothing);
  });

  testWidgets('grocery duck uses a distinct animated rear sprite', (
    tester,
  ) async {
    Widget scene(double gait) => localizedTestApp(
      home: Scaffold(
        body: GroceryRearDuck(gait: gait, joy: 0, onTap: () {}, name: 'Кряква'),
      ),
    );

    await tester.pumpWidget(scene(0));
    await tester.pump(const Duration(milliseconds: 300));
    final finder = find.descendant(
      of: find.byKey(const ValueKey('grocery-duck-rear')),
      matching: find.byType(CustomPaint),
    );
    final first = tester.widget<CustomPaint>(finder).painter!;
    expect(first, isA<DuckSpriteSheetPainter>());
    expect((first as DuckSpriteSheetPainter).view, DuckView.rear);

    await tester.pumpWidget(scene(0.3));
    await tester.pump();
    final next = tester.widget<CustomPaint>(finder).painter!;
    expect((next as DuckSpriteSheetPainter).frame, isNot(first.frame));
  });

  test(
    'wallet has no daily allowance and keeps explicit transaction rewards',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final firstOpen = await GroceryWallet.open(preferences: preferences);

      expect(firstOpen.balance, 0);
      expect(await firstOpen.grantOnce('warehouse:completed-run', 500), isTrue);
      expect(firstOpen.balance, 500);
      expect(
        await firstOpen.grantOnce('warehouse:completed-run', 500),
        isFalse,
      );

      final restarted = await GroceryWallet.open(preferences: preferences);
      expect(restarted.balance, 500);
      expect(await restarted.spend(550), isFalse);
      expect(restarted.balance, 500);
    },
  );

  test('leather jacket purchases are affordable and idempotent', () async {
    SharedPreferences.setMockInitialValues({
      GroceryWallet.storageKey: jsonEncode({
        'balance': GroceryWallet.leatherJacketPrice,
        'lastGrantDate': '2026-11-06',
        'purchasedSkinIds': <String>[],
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final wallet = await GroceryWallet.open(preferences: preferences);

    expect(
      await wallet.purchaseSkinOnce(
        'leather_jacket',
        GroceryWallet.leatherJacketPrice,
      ),
      isTrue,
    );
    expect(wallet.balance, 0);
    expect(
      await wallet.purchaseSkinOnce(
        'leather_jacket',
        GroceryWallet.leatherJacketPrice,
      ),
      isTrue,
    );
    expect(wallet.balance, 0);
    expect(await wallet.purchaseSkinOnce('another_skin', 1), isFalse);
    expect(wallet.purchasedSkinIds, ['leather_jacket']);
  });

  testWidgets('user collects products, scans them, then claims the receipt', (
    tester,
  ) async {
    const seed = 41;
    final catalog = GroceryCatalog.generate(random: Random(seed));
    final today = DateTime.now();
    final dateKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      GroceryWallet.storageKey: jsonEncode({
        'balance': 999,
        'lastGrantDate': dateKey,
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final wallet = await GroceryWallet.open(preferences: preferences);
    await tester.pumpWidget(
      localizedTestApp(
        home: GroceryStoreScreen(
          duckName: 'Кряква',
          wallet: wallet,
          catalogSeed: seed,
          duckAppearance: DuckAppearance(
            bodyColor: Colors.deepOrange,
            hat: DuckHat.crown,
            equippedItems: ['bow', 'leather_jacket'],
          ),
        ),
      ),
    );
    await tester.pump();

    final aisleScene = find.byKey(const ValueKey('grocery-aisle-scene'));
    expect(aisleScene, findsOneWidget);
    final aislePainter = tester.widget<CustomPaint>(aisleScene).painter;
    expect(aislePainter, isA<GroceryAisleScenePainter>());
    expect(
      find.descendant(of: aisleScene, matching: find.byType(Image)),
      findsNothing,
      reason: 'The backdrop must not contain duplicate baked-in products.',
    );
    expect(find.byKey(const ValueKey('grocery-duck-rear')), findsOneWidget);
    final aisleRect = tester.getRect(aisleScene);
    for (final product in catalog.products) {
      final productSprite = find.byKey(ValueKey('pixel-product-${product.id}'));
      expect(productSprite, findsOneWidget);
      final spriteRect = tester.getRect(productSprite);
      final shelfSurfaceY = aisleRect.top + aisleRect.height * product.shelfRow;
      expect(
        spriteRect.bottom - PixelGroceryProduct.shelfRestOffset(product.id),
        closeTo(shelfSurfaceY, 1),
        reason: '${product.id} should rest on its shelf surface.',
      );
      expect(
        tester.getRect(find.byKey(ValueKey('price-tag-${product.id}'))).top,
        closeTo(shelfSurfaceY + 3, 1),
        reason: '${product.id} price tag should attach below the shelf edge.',
      );
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('shelf-crumbs'))).width,
      greaterThan(60),
      reason: 'Pixel products should keep their full tap target.',
    );
    final sceneRect = tester.getRect(aisleScene);
    final shelfProductRect = tester.getRect(
      find.byKey(const ValueKey('shelf-crumbs')),
    );
    expect(shelfProductRect.center.dy, greaterThan(sceneRect.top));
    expect(shelfProductRect.center.dy, lessThan(sceneRect.bottom));
    final duckPaintFinder = find.descendant(
      of: find.byKey(const ValueKey('grocery-duck-rear')),
      matching: find.byType(CustomPaint),
    );
    final initialDuckPainter = tester
        .widget<CustomPaint>(duckPaintFinder)
        .painter;
    expect(initialDuckPainter, isA<DuckSpriteSheetPainter>());
    final duckPainter = initialDuckPainter! as DuckSpriteSheetPainter;
    expect(duckPainter.jacket, isTrue);
    expect(duckPainter.view, DuckView.rear);
    expect(duckPainter.appearance.bodyColor, Colors.deepOrange);
    expect(duckPainter.appearance.hat, DuckHat.crown);
    expect(duckPainter.appearance.equippedItems, ['bow', 'leather_jacket']);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('grocery-duck-rear')), findsOneWidget);
    expect(
      identical(
        initialDuckPainter,
        tester.widget<CustomPaint>(duckPaintFinder).painter,
      ),
      isFalse,
      reason:
          'The rear-view duck painter should update during its walking gait.',
    );
    final productIds = catalog.products.map((product) => product.id).toList();
    expect(find.text('Собрано: 0/${productIds.length}'), findsOneWidget);
    for (final product in catalog.products) {
      expect(find.byKey(ValueKey('price-tag-${product.id}')), findsOneWidget);
      expect(find.text('${product.price} ₴'), findsWidgets);
    }
    for (final id in productIds) {
      expect(find.byKey(ValueKey('pixel-product-$id')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('shelf-$id')));
      await tester.pump();
      final productAnimation = tester.widget<AnimatedPositioned>(
        find.byKey(ValueKey('grocery-product-$id')),
      );
      expect(productAnimation.duration, const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(ValueKey('picked-$id')), findsOneWidget);
      expect(find.byKey(ValueKey('shelf-basket-item-$id')), findsOneWidget);
    }
    for (final id in productIds) {
      expect(find.byKey(ValueKey('shelf-basket-item-$id')), findsOneWidget);
    }

    expect(
      find.text('Собрано: ${productIds.length}/${productIds.length}'),
      findsOneWidget,
    );
    expect(find.text('Перейти к кассе'), findsOneWidget);
    expect(preferences.getStringList(GroceryStoreScreen.inventoryKey), isNull);

    await tester.tap(find.text('Перейти к кассе'));
    await tester.pump();
    expect(find.text('Отсканировано: 0/${productIds.length}'), findsOneWidget);
    expect(find.byKey(const ValueKey('grocery-cashier-scene')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('grocery-cashier-background')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('grocery-cashier-duck')), findsOneWidget);
    final checkoutBasket = find.byKey(
      const ValueKey('grocery-checkout-basket'),
    );
    expect(checkoutBasket, findsOneWidget);
    for (final id in productIds) {
      expect(find.byKey(ValueKey('checkout-basket-item-$id')), findsOneWidget);
    }
    final cashierSheet = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('grocery-cashier-duck')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (cashierSheet.image as AssetImage).assetName,
      'assets/images/duck_cashier_front_sheet.png',
    );
    await tester.tap(checkoutBasket);
    await tester.pump();
    expect(find.text('Отсканировано: 1/${productIds.length}'), findsOneWidget);
    expect(
      find.byKey(ValueKey('checkout-basket-item-${productIds.first}')),
      findsNothing,
    );
    await tester.tap(checkoutBasket, warnIfMissed: false);
    await tester.pump();
    expect(find.text('Отсканировано: 1/${productIds.length}'), findsOneWidget);
    for (var index = 1; index < productIds.length; index++) {
      await tester.pump(const Duration(milliseconds: 700));
      if (index + 1 < productIds.length) {
        expect(
          find.text('Отсканировано: ${index + 1}/${productIds.length}'),
          findsOneWidget,
        );
      }
    }

    expect(find.text('Еда собрана!'), findsOneWidget);
    expect(find.text('Забрать покупки в инвентарь'), findsOneWidget);
    await tester.ensureVisible(find.text('Забрать покупки в инвентарь'));
    await tester.tap(find.text('Забрать покупки в инвентарь'));
    await tester.pump();
    await tester.pump();

    expect(wallet.balance, 999 - catalog.totalPrice);
    expect(
      preferences.getStringList(GroceryStoreScreen.inventoryKey),
      productIds,
    );
    expect(find.text('Вернуться к Кряква'), findsOneWidget);
  });

  testWidgets('insufficient balance can replace a basket item and buy', (
    tester,
  ) async {
    const seed = 73;
    final catalog = GroceryCatalog.generate(random: Random(seed));
    final cheapest = catalog.products.toList()
      ..sort((first, second) => first.price.compareTo(second.price));
    final basket = cheapest.take(3).toList();
    final target = cheapest[3];
    final basketTotal = basket.fold(
      0,
      (total, product) => total + product.price,
    );
    final balance = basketTotal + target.price - 1;
    SharedPreferences.setMockInitialValues({
      GroceryWallet.storageKey: jsonEncode({
        'balance': balance,
        'lastGrantDate': '2026-11-06',
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final wallet = await GroceryWallet.open(preferences: preferences);
    await tester.pumpWidget(
      localizedTestApp(
        home: GroceryStoreScreen(
          duckName: 'Кряква',
          wallet: wallet,
          catalogSeed: seed,
        ),
      ),
    );
    await tester.pump();

    for (final product in basket) {
      await tester.tap(find.byKey(ValueKey('shelf-${product.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    await tester.tap(find.byKey(ValueKey('shelf-${target.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Не хватает гривен'), findsOneWidget);
    final replacementLabel = find.textContaining('Убрать один товар и взять');
    expect(replacementLabel, findsOneWidget);
    await tester.ensureVisible(replacementLabel);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(replacementLabel);
    await tester.pump();
    expect(find.text('Собрано: 3/8'), findsOneWidget);

    await tester.tap(find.text('Перейти к кассе'));
    await tester.pump();
    final purchased = [...basket.take(2), target];
    final checkoutBasket = find.byKey(
      const ValueKey('grocery-checkout-basket'),
    );
    for (final product in purchased) {
      expect(
        find.byKey(ValueKey('checkout-basket-item-${product.id}')),
        findsOneWidget,
      );
    }
    await tester.tap(checkoutBasket);
    await tester.pump();
    for (var index = 1; index < purchased.length; index++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    expect(find.byKey(const ValueKey('grocery-receipt-total')), findsOneWidget);
    final total = purchased.fold(0, (sum, product) => sum + product.price);
    expect(find.text('Итого: 3 товара · $total ₴'), findsOneWidget);
    await tester.ensureVisible(find.text('Забрать покупки в инвентарь'));
    await tester.tap(find.text('Забрать покупки в инвентарь'));
    await tester.pump();

    expect(wallet.balance, balance - total);
    expect(
      preferences.getStringList(GroceryStoreScreen.inventoryKey),
      catalog.products
          .where((product) => purchased.any((item) => item.id == product.id))
          .map((product) => product.id)
          .toList(),
    );
  });

  test('legacy bread inventory is migrated to crumbs id', () {
    expect(GroceryStoreScreen.normalizeInventory(['bread', 'pizza']), [
      'crumbs',
      'pizza',
    ]);
  });
}
