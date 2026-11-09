import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:love_anniversary_app/models/coupon.dart';
import 'package:love_anniversary_app/services/coupon_repository.dart';

void main() {
  late Directory hiveDirectory;
  var boxNumber = 0;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('coupon_hive_test');
    Hive.init(hiveDirectory.path);
    if (!Hive.isAdapterRegistered(CouponAdapter.adapterTypeId)) {
      Hive.registerAdapter(CouponAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  Future<Box<Coupon>> openBox() =>
      Hive.openBox<Coupon>('coupon_test_${boxNumber++}');

  test('adapter round-trips coupon fields and activation date', () async {
    final box = await openBox();
    final activatedAt = DateTime(2026, 3, 12, 9, 15);
    const coupon = Coupon(
      id: 'monthly-coffee',
      title: 'Кофе',
      description: 'Вместе',
      icon: 'restaurant',
      type: CouponType.monthly,
      isActivated: true,
      lastActivatedAt: null,
    );
    await box.put(coupon.id, coupon.copyWith(lastActivatedAt: activatedAt));

    final restored = box.get(coupon.id)!;
    expect(restored.id, coupon.id);
    expect(restored.title, coupon.title);
    expect(restored.description, coupon.description);
    expect(restored.icon, coupon.icon);
    expect(restored.type, CouponType.monthly);
    expect(restored.isActivated, isTrue);
    expect(restored.lastActivatedAt, activatedAt);
    await box.close();
  });

  test('one-time activation remains spent after reopening the box', () async {
    const coupon = Coupon(
      id: 'once',
      title: 'Один раз',
      description: 'Навсегда',
      icon: 'favorite',
      type: CouponType.oneTime,
    );
    final box = await openBox();
    await box.put(coupon.id, coupon);
    final repository = HiveCouponRepository(box);
    final date = DateTime(2026, 1, 31, 23, 59);

    expect(await repository.activate(coupon.id, at: date), isTrue);
    expect(await repository.activate(coupon.id, at: date), isFalse);
    await box.close();

    final reopened = await Hive.openBox<Coupon>(box.name);
    final restored = await HiveCouponRepository(reopened)
        .load(now: DateTime(2027, 2, 1));
    final restoredOneTime = restored.singleWhere(
      (item) => item.id == coupon.id,
    );
    expect(restoredOneTime.isActivated, isTrue);
    expect(restoredOneTime.lastActivatedAt, date);
    expect(
      await HiveCouponRepository(reopened)
          .activate(coupon.id, at: DateTime(2027, 2, 1)),
      isFalse,
    );
    await reopened.close();
  });

  test('monthly coupons reset at calendar month and year boundaries', () async {
    const coupon = Coupon(
      id: 'monthly',
      title: 'Ежемесячный',
      description: 'Каждый месяц',
      icon: 'spa',
      type: CouponType.monthly,
    );
    final box = await openBox();
    await box.put(
      coupon.id,
      coupon.copyWith(
        isActivated: true,
        lastActivatedAt: DateTime(2025, 12, 31, 23, 59),
      ),
    );
    final boxName = box.name;
    await box.close();
    final reopened = await Hive.openBox<Coupon>(boxName);
    final repository = HiveCouponRepository(reopened);

    final reset = await repository.load(now: DateTime(2026, 1, 1));
    final resetMonthly = reset.singleWhere((item) => item.id == coupon.id);
    expect(resetMonthly.isActivated, isFalse);
    expect(reopened.get(coupon.id)!.isActivated, isFalse);
    expect(
      await repository.activate(coupon.id, at: DateTime(2026, 1, 1)),
      isTrue,
    );
    expect(
      await repository.activate(coupon.id, at: DateTime(2026, 1, 31, 23, 59)),
      isFalse,
    );
    await reopened.close();
  });

  test('only one concurrent activation succeeds', () async {
    const coupon = Coupon(
      id: 'race',
      title: 'Купон',
      description: '',
      icon: 'favorite',
      type: CouponType.oneTime,
    );
    final box = await openBox();
    await box.put(coupon.id, coupon);
    final repository = HiveCouponRepository(box);

    final results = await Future.wait([
      repository.activate(coupon.id, at: DateTime(2026, 5, 1)),
      repository.activate(coupon.id, at: DateTime(2026, 5, 1)),
    ]);

    expect(results.where((result) => result).length, 1);
    await box.close();
  });

  test(
    'daily coupons persist once per date without resetting used records',
    () async {
      final firstDay = DateTime(2026, 8, 12, 8);
      final box = await openBox();
      final repository = HiveCouponRepository(box);

      final initial = await repository.load(now: firstDay);
      final daily = initial.singleWhere(
        (coupon) => coupon.type == CouponType.daily,
      );
      expect(daily.id, 'daily-2026-08-12');
      expect(await repository.activate(daily.id, at: firstDay), isTrue);
      expect(await repository.activate(daily.id, at: firstDay), isFalse);
      expect(
        (await repository.load(now: firstDay))
            .where((coupon) => coupon.type == CouponType.daily),
        hasLength(1),
      );
      await box.close();

      final reopened = await Hive.openBox<Coupon>(box.name);
      final reloaded = HiveCouponRepository(reopened);
      final nextDay = await reloaded.load(now: DateTime(2026, 8, 13));
      final dailyCoupons = nextDay
          .where((coupon) => coupon.type == CouponType.daily)
          .toList();
      expect(dailyCoupons, hasLength(2));
      expect(
        dailyCoupons.singleWhere((coupon) => coupon.id == daily.id).isActivated,
        isTrue,
      );
      expect(daily.isEligibleAt(DateTime(2026, 8, 13)), isFalse);
      final tomorrow = dailyCoupons.singleWhere(
        (coupon) => coupon.id == 'daily-2026-08-13',
      );
      expect(tomorrow.isEligibleAt(DateTime(2026, 8, 13)), isTrue);
      expect(
        await reloaded.activate(tomorrow.id, at: DateTime(2026, 8, 13)),
        isTrue,
      );
      expect(
        await reloaded.activate(tomorrow.id, at: DateTime(2026, 8, 13)),
        isFalse,
      );
      await reopened.close();
    },
  );
}
