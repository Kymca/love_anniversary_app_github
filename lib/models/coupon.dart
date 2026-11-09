import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum CouponType { oneTime, monthly, daily }

class Coupon {
  const Coupon({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    this.isActivated = false,
    this.lastActivatedAt,
  });

  final String id;
  final String title;
  final String description;

  /// A Material icon identifier, resolved by [couponIcon].
  final String icon;
  final CouponType type;
  final bool isActivated;
  final DateTime? lastActivatedAt;

  bool isEligibleAt(DateTime date) {
    if (type == CouponType.oneTime) return !isActivated;
    if (type == CouponType.daily) {
      return !isActivated && id == 'daily-${_calendarDateKey(date)}';
    }
    final lastActivation = lastActivatedAt;
    if (lastActivation == null) return !isActivated;
    return lastActivation.year != date.year ||
        lastActivation.month != date.month;
  }

  Coupon copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    CouponType? type,
    bool? isActivated,
    DateTime? lastActivatedAt,
  }) {
    return Coupon(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      isActivated: isActivated ?? this.isActivated,
      lastActivatedAt: lastActivatedAt ?? this.lastActivatedAt,
    );
  }
}

String _calendarDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

IconData couponIcon(String name) {
  return switch (name) {
    'favorite' => Icons.favorite_rounded,
    'restaurant' => Icons.restaurant_rounded,
    'movie' => Icons.movie_rounded,
    'spa' => Icons.spa_rounded,
    'celebration' => Icons.celebration_rounded,
    'photo' => Icons.photo_camera_rounded,
    _ => Icons.card_giftcard_rounded,
  };
}

class CouponAdapter extends TypeAdapter<Coupon> {
  static const int adapterTypeId = 41;

  @override
  int get typeId => adapterTypeId;

  @override
  Coupon read(BinaryReader reader) {
    final fields = <int, dynamic>{
      for (var index = 0, count = reader.readByte(); index < count; index++)
        reader.readByte(): reader.read(),
    };
    final typeIndex = fields[4] as int;
    return Coupon(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      icon: fields[3] as String,
      type: CouponType.values[typeIndex],
      isActivated: fields[5] as bool? ?? false,
      lastActivatedAt: fields[6] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[6] as int),
    );
  }

  @override
  void write(BinaryWriter writer, Coupon obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.icon)
      ..writeByte(4)
      ..write(obj.type.index)
      ..writeByte(5)
      ..write(obj.isActivated)
      ..writeByte(6)
      ..write(obj.lastActivatedAt?.millisecondsSinceEpoch);
  }
}
