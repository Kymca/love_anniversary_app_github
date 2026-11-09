import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GroceryWallet {
  GroceryWallet._(
    this._preferences,
    this._balance,
    this._purchasedSkinIds,
    this._grantedTransactionIds,
  );

  static const storageKey = 'tamagotchi_grocery_wallet';
  static const leatherJacketPrice = 5000;
  static const heartPajamasPrice = 7500;

  final SharedPreferences _preferences;
  int _balance;
  List<String> _purchasedSkinIds;
  List<String> _grantedTransactionIds;

  int get balance => _balance;
  List<String> get purchasedSkinIds => List.unmodifiable(_purchasedSkinIds);

  static Future<GroceryWallet> open({SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final stored = prefs.getString(storageKey);
    var balance = 0;
    var purchasedSkinIds = <String>[];
    var grantedTransactionIds = <String>[];
    if (stored != null) {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic> ||
          decoded['balance'] is! int ||
          (decoded['lastGrantDate'] != null &&
              decoded['lastGrantDate'] is! String) ||
          (decoded['purchasedSkinIds'] != null &&
              (decoded['purchasedSkinIds'] is! List ||
                  (decoded['purchasedSkinIds'] as List).any(
                    (id) => id is! String,
                  ))) ||
          (decoded['grantedTransactionIds'] != null &&
              (decoded['grantedTransactionIds'] is! List ||
                  (decoded['grantedTransactionIds'] as List).any(
                    (id) => id is! String,
                  )))) {
        throw const FormatException('Invalid grocery wallet data');
      }
      balance = decoded['balance'] as int;
      purchasedSkinIds = List<String>.from(
        decoded['purchasedSkinIds'] as List? ?? const [],
      );
      grantedTransactionIds = List<String>.from(
        decoded['grantedTransactionIds'] as List? ?? const [],
      );
      if (balance < 0) {
        throw const FormatException(
          'Grocery wallet balance cannot be negative',
        );
      }
    }

    final wallet = GroceryWallet._(
      prefs,
      balance,
      purchasedSkinIds,
      grantedTransactionIds,
    );
    return wallet;
  }

  Future<bool> purchaseSkinOnce(String skinId, int price) async {
    if (skinId.isEmpty) throw ArgumentError.value(skinId, 'skinId');
    if (price < 0) throw ArgumentError.value(price, 'price');
    if (_purchasedSkinIds.contains(skinId)) return true;
    if (price > _balance) return false;
    await _save(
      balance: _balance - price,
      purchasedSkinIds: [..._purchasedSkinIds, skinId],
    );
    return true;
  }

  Future<bool> spend(int amount) async {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    if (amount > _balance) return false;
    await _save(balance: _balance - amount);
    return true;
  }

  Future<void> refund(int amount) async {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    await _save(balance: _balance + amount);
  }

  Future<bool> grantOnce(String transactionId, int amount) async {
    if (transactionId.isEmpty) {
      throw ArgumentError.value(transactionId, 'transactionId');
    }
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    if (_grantedTransactionIds.contains(transactionId)) return false;
    await _save(
      balance: _balance + amount,
      grantedTransactionIds: [..._grantedTransactionIds, transactionId],
    );
    return true;
  }

  Future<void> _save({
    required int balance,
    List<String>? purchasedSkinIds,
    List<String>? grantedTransactionIds,
  }) async {
    final nextPurchasedSkinIds = purchasedSkinIds ?? _purchasedSkinIds;
    final nextGrantedTransactionIds =
        grantedTransactionIds ?? _grantedTransactionIds;
    final data = jsonEncode({
      'balance': balance,
      'purchasedSkinIds': nextPurchasedSkinIds,
      'grantedTransactionIds': nextGrantedTransactionIds,
    });
    final saved = await _preferences.setString(storageKey, data);
    if (!saved) throw StateError('Could not save grocery wallet');
    _balance = balance;
    _purchasedSkinIds = nextPurchasedSkinIds;
    _grantedTransactionIds = nextGrantedTransactionIds;
  }
}
