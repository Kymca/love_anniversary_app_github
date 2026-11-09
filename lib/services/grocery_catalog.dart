import 'dart:math';

class GroceryProduct {
  const GroceryProduct({
    required this.id,
    required this.price,
    required this.shelfPosition,
    required this.shelfRow,
  });

  final String id;
  final int price;
  final double shelfPosition;
  final double shelfRow;
}

class GroceryCatalog {
  GroceryCatalog._(this.products);

  static const int maxCatalogTotal = 999;
  static const int minProductPrice = 21;
  static const int maxProductPrice = 149;
  static const shelfRowPositions = [0.285, 0.599];

  static const productIds = [
    'crumbs',
    'watermelon',
    'worm',
    'pizza',
    'apple',
    'cheese',
    'carrot',
    'milk',
  ];

  final List<GroceryProduct> products;

  int get totalPrice =>
      products.fold(0, (total, product) => total + product.price);

  factory GroceryCatalog.generate({required Random random}) {
    final ids = List<String>.of(productIds)..shuffle(random);
    final slots = <(double, double)>[
      (0.094, shelfRowPositions[0]),
      (0.331, shelfRowPositions[0]),
      (0.569, shelfRowPositions[0]),
      (0.806, shelfRowPositions[0]),
      (0.094, shelfRowPositions[1]),
      (0.331, shelfRowPositions[1]),
      (0.569, shelfRowPositions[1]),
      (0.806, shelfRowPositions[1]),
    ]..shuffle(random);
    final pricePool = [
      for (var price = minProductPrice; price <= maxProductPrice; price++)
        if (price % 10 != 0) price,
    ]..shuffle(random);

    final products = <GroceryProduct>[];
    final usedPrices = <int>{};
    var total = 0;
    for (var index = 0; index < ids.length; index++) {
      final remainingCount = ids.length - index - 1;
      final maxPrice = min(
        maxProductPrice,
        maxCatalogTotal - total - minProductPrice * remainingCount,
      );
      final candidates = pricePool
          .where((price) => price <= maxPrice && !usedPrices.contains(price))
          .toList();
      if (candidates.isEmpty) {
        throw StateError('Could not generate a valid grocery catalog.');
      }
      final price = candidates[random.nextInt(candidates.length)];
      usedPrices.add(price);
      total += price;
      final (position, row) = slots[index];
      products.add(
        GroceryProduct(
          id: ids[index],
          price: price,
          shelfPosition: position,
          shelfRow: row,
        ),
      );
    }

    if (total > maxCatalogTotal || total == 1000) {
      throw StateError('Generated grocery catalog exceeds its price limit.');
    }
    return GroceryCatalog._(List.unmodifiable(products));
  }
}
