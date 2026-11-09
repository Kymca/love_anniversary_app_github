import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/services/grocery_catalog.dart';

void main() {
  test('generated catalogs preserve the original products and add variety', () {
    final catalog = GroceryCatalog.generate(random: Random(5));
    final ids = catalog.products.map((product) => product.id).toSet();

    expect(ids, containsAll(['crumbs', 'watermelon', 'worm', 'pizza']));
    expect(ids, containsAll(['apple', 'cheese', 'carrot', 'milk']));
    expect(ids.length, GroceryCatalog.productIds.length);
  });

  test('prices are unique, non-round, bounded, and total less than ₴1,000', () {
    for (var seed = 0; seed < 100; seed++) {
      final catalog = GroceryCatalog.generate(random: Random(seed));
      final prices = catalog.products.map((product) => product.price).toList();

      expect(prices.toSet().length, prices.length);
      expect(prices, everyElement(greaterThanOrEqualTo(21)));
      expect(prices, everyElement(lessThanOrEqualTo(149)));
      expect(prices.every((price) => price % 10 != 0), isTrue);
      expect(catalog.totalPrice, lessThan(1000));
      expect(catalog.totalPrice, isNot(1000));
    }
  });

  test('seeded assortment and prices stay stable for a store session', () {
    final first = GroceryCatalog.generate(random: Random(42));
    final second = GroceryCatalog.generate(random: Random(42));

    expect(
      first.products.map((product) => (product.id, product.price)).toList(),
      second.products.map((product) => (product.id, product.price)).toList(),
    );
    expect(
      GroceryCatalog.generate(random: Random(43)).products
          .map((product) => (product.id, product.price))
          .toList(),
      isNot(
        first.products.map((product) => (product.id, product.price)).toList(),
      ),
    );
  });
}
