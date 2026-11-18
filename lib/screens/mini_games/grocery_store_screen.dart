import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/grocery_catalog.dart';
import '../../services/grocery_wallet.dart';
import '../../services/duck_ownership_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/duck_painter.dart';
import '../../widgets/duck_sprite.dart';
import 'grocery_aisle_scene.dart';
import 'warehouse_work_screen.dart';

class GroceryStoreScreen extends StatefulWidget {
  const GroceryStoreScreen({
    super.key,
    required this.duckName,
    this.wallet,
    this.duckAppearance = const DuckAppearance(),
    this.catalogSeed,
    this.canWork = true,
    this.ownershipRepository,
  });

  static const inventoryKey = 'tamagotchi_grocery_inventory';
  static const _legacyCrumbsItemId = 'bread';

  final String duckName;
  final GroceryWallet? wallet;
  final DuckAppearance duckAppearance;
  final int? catalogSeed;
  final bool canWork;
  final DuckOwnershipService? ownershipRepository;

  static List<String> normalizeInventory(List<String> inventory) =>
      inventory.map((id) => id == _legacyCrumbsItemId ? 'crumbs' : id).toList();

  @override
  State<GroceryStoreScreen> createState() => _GroceryStoreScreenState();
}

enum _StorePhase { shelves, checkout, receipt, claimed }

class _GroceryStoreScreenState extends State<GroceryStoreScreen>
    with SingleTickerProviderStateMixin {
  late final GroceryCatalog _catalog;

  List<_GroceryItem> get _items {
    final strings = AppLocalizations.of(context)!;
    return _catalog.products
        .map(
          (product) => _GroceryItem(
            id: product.id,
            name: _productName(strings, product.id),
            price: product.price,
            shelfPosition: product.shelfPosition,
            shelfRow: product.shelfRow,
          ),
        )
        .toList(growable: false);
  }

  String _productName(AppLocalizations strings, String productId) =>
      switch (productId) {
        'crumbs' => strings.foodBreadCrumbs,
        'watermelon' => strings.foodWatermelonStore,
        'worm' => strings.foodWorms,
        'pizza' => strings.foodPizza,
        'apple' => strings.foodApple,
        'cheese' => strings.foodCheese,
        'carrot' => strings.foodCarrot,
        'milk' => strings.foodMilk,
        _ => throw ArgumentError.value(productId, 'productId'),
      };

  int get _basketTotal => _totalForIds(_collectedIds);

  int _totalForIds(Iterable<String> productIds) {
    final selected = productIds.toSet();
    return _items
        .where((item) => selected.contains(item.id))
        .fold(0, (total, item) => total + item.price);
  }

  late final DuckFrameTicker _animationClock = DuckFrameTicker(
    vsync: this,
    onFrame: (frame) {
      if (!mounted) return;
      if (_walkStartFrame != null &&
          duckAnimationProgressAtFrame(
                frame - _walkStartFrame!,
                duckStoreWalkDuration,
              ) >=
              1) {
        _walkStartFrame = null;
        _walkCompleted = true;
      }
      if (_joyStartFrame != null &&
          duckAnimationProgressAtFrame(
                frame - _joyStartFrame!,
                duckStoreJoyDuration,
              ) >=
              1) {
        _joyStartFrame = null;
      }
      setState(() {});
    },
  );
  int? _walkStartFrame;
  int? _joyStartFrame;
  bool _walkCompleted = false;
  final Set<String> _collectedIds = <String>{};
  final Set<String> _animatingCollectionIds = <String>{};
  final Set<String> _scannedIds = <String>{};
  _StorePhase _phase = _StorePhase.shelves;
  bool _isScanningBasket = false;
  String? _lastCollectedId;
  String? _lastScannedId;
  Timer? _feedbackTimer;
  Timer? _basketScanTimer;
  bool _isSaving = false;
  GroceryWallet? _wallet;
  bool _workMode = false;

  @override
  void initState() {
    super.initState();
    _catalog = GroceryCatalog.generate(
      random: widget.catalogSeed == null
          ? math.Random()
          : math.Random(widget.catalogSeed),
    );
    _animationClock.start();
    _loadWallet();
  }

  double get _walkProgress {
    final startFrame = _walkStartFrame;
    if (startFrame == null) return _walkCompleted ? 1 : 0;
    return duckAnimationProgressAtFrame(
      _animationClock.frameIndex - startFrame,
      duckStoreWalkDuration,
    );
  }

  double get _joyProgress {
    final startFrame = _joyStartFrame;
    if (startFrame == null) return 0;
    return duckAnimationProgressAtFrame(
      _animationClock.frameIndex - startFrame,
      duckStoreJoyDuration,
    );
  }

  double get _gaitProgress => duckAnimationProgressAtFrame(
    _animationClock.frameIndex,
    duckStoreGaitDuration,
    loop: true,
  );

  Future<void> _loadWallet() async {
    try {
      final wallet = widget.wallet ?? await GroceryWallet.open();
      if (mounted) setState(() => _wallet = wallet);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.storeSaveError(error.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _collect(_GroceryItem item) async {
    if (_phase != _StorePhase.shelves || _collectedIds.contains(item.id)) {
      return;
    }
    final wallet = _wallet;
    if (wallet == null) return;
    if (_basketTotal + item.price > wallet.balance) {
      await _showInsufficientFunds(item);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _collectedIds.add(item.id);
      _animatingCollectionIds.add(item.id);
      _lastCollectedId = item.id;
    });
    _celebrate();
    _clearFeedbackLater();
  }

  Future<void> _showInsufficientFunds(_GroceryItem item) async {
    final strings = AppLocalizations.of(context)!;
    final wallet = _wallet!;
    final removableId = _collectedIds.isEmpty ? null : _collectedIds.last;
    final canReplace =
        removableId != null &&
        _basketTotal -
                _items
                    .firstWhere((candidate) => candidate.id == removableId)
                    .price +
                item.price <=
            wallet.balance;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.storeInsufficientFundsTitle),
        content: Text(
          strings.storeInsufficientFunds(
            wallet.balance - _basketTotal,
            item.price,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.storeChooseAnother),
          ),
          if (canReplace)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.storeReplaceLastItem(item.name)),
            ),
        ],
      ),
    );
    if (replace != true || !mounted || removableId == null) return;
    setState(() {
      _collectedIds
        ..remove(removableId)
        ..add(item.id);
      _animatingCollectionIds
        ..remove(removableId)
        ..add(item.id);
      _lastCollectedId = item.id;
    });
    _celebrate();
    _clearFeedbackLater();
  }

  void _goToCheckout() {
    if (_collectedIds.isEmpty) return;
    setState(() {
      _phase = _StorePhase.checkout;
      _walkCompleted = false;
      _walkStartFrame = _animationClock.frameIndex;
    });
  }

  void _scan(_GroceryItem item) {
    if (_phase != _StorePhase.checkout || _scannedIds.contains(item.id)) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _scannedIds.add(item.id);
      _lastScannedId = item.id;
      if (_scannedIds.length == _collectedIds.length) {
        _phase = _StorePhase.receipt;
      }
    });
    _celebrate();
    _clearFeedbackLater();
  }

  void _scanBasket() {
    if (_phase != _StorePhase.checkout || _isScanningBasket) return;
    final remaining = _items
        .where(
          (item) =>
              _collectedIds.contains(item.id) && !_scannedIds.contains(item.id),
        )
        .toList();
    if (remaining.isEmpty) return;
    setState(() => _isScanningBasket = true);
    _scanNextBasketItem(remaining, 0);
  }

  void _scanNextBasketItem(List<_GroceryItem> items, int index) {
    if (!mounted || _phase != _StorePhase.checkout) return;
    if (index >= items.length) {
      setState(() => _isScanningBasket = false);
      return;
    }
    _scan(items[index]);
    if (_phase == _StorePhase.receipt) {
      _isScanningBasket = false;
      return;
    }
    _basketScanTimer = Timer(
      const Duration(milliseconds: 700),
      () => _scanNextBasketItem(items, index + 1),
    );
  }

  void _celebrate() {
    _joyStartFrame = _animationClock.frameIndex;
    setState(() {});
  }

  void _clearFeedbackLater() {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _lastCollectedId = null;
        _lastScannedId = null;
      });
    });
  }

  Future<void> _claimPurchases() async {
    if (_isSaving || _phase != _StorePhase.receipt) return;
    final wallet = _wallet;
    if (wallet == null) return;
    setState(() => _isSaving = true);
    var walletCharged = false;
    List<String>? previousInventory;
    final purchaseTotal = _basketTotal;
    try {
      final preferences = await SharedPreferences.getInstance();
      final inventory = GroceryStoreScreen.normalizeInventory(
        preferences.getStringList(GroceryStoreScreen.inventoryKey) ?? [],
      );
      previousInventory = List<String>.from(inventory);
      for (final item in _items) {
        if (_collectedIds.contains(item.id)) inventory.add(item.id);
      }
      if (!await wallet.spend(purchaseTotal)) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _phase = _StorePhase.shelves;
          _collectedIds.clear();
          _scannedIds.clear();
        });
        await _showInsufficientFunds(_items.first);
        return;
      }
      walletCharged = true;
      final saved = await preferences.setStringList(
        GroceryStoreScreen.inventoryKey,
        inventory,
      );
      if (!saved) throw StateError('Could not save grocery inventory');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _phase = _StorePhase.claimed;
      });
    } catch (error) {
      if (walletCharged) await wallet.refund(purchaseTotal);
      if (previousInventory != null) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setStringList(
          GroceryStoreScreen.inventoryKey,
          previousInventory,
        );
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.storeSaveError(error.toString()),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _basketScanTimer?.cancel();
    _animationClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.storeTitle),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF315D58),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(widget.canWork ? 56 : 0),
          child: Padding(
            padding: widget.canWork
                ? const EdgeInsets.fromLTRB(20, 0, 20, 10)
                : EdgeInsets.zero,
            child: widget.canWork
                ? SegmentedButton<bool>(
                    key: const ValueKey('grocery-store-work-switch'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        icon: const Icon(Icons.shopping_basket_rounded),
                        label: Text(strings.groceryStoreTab),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: const Icon(Icons.inventory_2_rounded),
                        label: Text(strings.groceryWorkTab),
                      ),
                    ],
                    selected: {_workMode},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        setState(() => _workMode = selection.first);
                      }
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: _workMode
              ? WarehouseWorkScreen(
                  wallet: _wallet,
                  ownershipRepository: widget.ownershipRepository,
                  embedded: true,
                  onReturnToStore: () => setState(() => _workMode = false),
                )
              : _wallet == null
              ? const Center(child: CircularProgressIndicator())
              : switch (_phase) {
                  _StorePhase.shelves => _buildShelves(),
                  _StorePhase.checkout => _buildCheckout(),
                  _StorePhase.receipt => _buildReceipt(),
                  _StorePhase.claimed => _buildClaimed(),
                },
        ),
      ),
    );
  }

  Widget _buildShelves() {
    return Column(
      children: [
        _progressHeader(
          title: AppLocalizations.of(context)!.storeChooseProducts,
          collected: _collectedIds.length,
          total: _items.length,
          counterLabel: AppLocalizations.of(context)!.storeCollected,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final cartPosition = Offset(width / 2 + 54, height - 90);
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const Positioned.fill(child: GroceryAisleBackdrop()),
                  Positioned(
                    left: width / 2 + 48,
                    bottom: 8,
                    child: _ShoppingCart(
                      items: _items
                          .where((item) => _collectedIds.contains(item.id))
                          .toList(),
                      totalPrice: _basketTotal,
                    ),
                  ),
                  Positioned(
                    left: width / 2 - 56,
                    bottom: 17,
                    child: _animatedDuck(),
                  ),
                  for (final item in _items)
                    _buildShelfProduct(item, width, height, cartPosition),
                  if (_lastCollectedId != null)
                    Positioned(
                      left:
                          _items
                              .firstWhere((item) => item.id == _lastCollectedId)
                              .shelfPosition *
                          width,
                      top: 28,
                      child: const _FeedbackBadge(label: '+1'),
                    ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _collectedIds.isNotEmpty ? _goToCheckout : null,
              icon: const Icon(Icons.shopping_cart_checkout_rounded),
              label: Text(
                _collectedIds.isEmpty
                    ? AppLocalizations.of(context)!.storeChooseAtLeastOne
                    : AppLocalizations.of(context)!.storeCheckout,
              ),
              style: _buttonStyle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShelfProduct(
    _GroceryItem item,
    double width,
    double height,
    Offset cartPosition,
  ) {
    final cardWidth = math.min(88.0, width * 0.3);
    final shelfY = height * item.shelfRow;
    final start = Offset(
      (width * item.shelfPosition - cardWidth / 2)
          .clamp(0, width - cardWidth)
          .toDouble(),
      (shelfY - 64).clamp(0, height - 107).toDouble(),
    );
    final isCollected = _collectedIds.contains(item.id);
    final isAnimating = _animatingCollectionIds.contains(item.id);
    return AnimatedPositioned(
      key: ValueKey('grocery-product-${item.id}'),
      left: isCollected ? cartPosition.dx : start.dx,
      top: isCollected ? cartPosition.dy : start.dy,
      duration: isAnimating ? const Duration(milliseconds: 650) : Duration.zero,
      curve: Curves.easeInCubic,
      onEnd: () {
        if (!mounted || !isAnimating) return;
        setState(() => _animatingCollectionIds.remove(item.id));
      },
      child: !isCollected
          ? _ProductBubble(
              item: item,
              width: cardWidth,
              onTap: () => _collect(item),
            )
          : isAnimating
          ? _foodIcon(item.id, 30)
          : SizedBox.shrink(key: ValueKey('picked-${item.id}')),
    );
  }

  Widget _buildCheckout() {
    final pickedItems = _items
        .where((item) => _collectedIds.contains(item.id))
        .toList();
    return Column(
      children: [
        _progressHeader(
          title: AppLocalizations.of(context)!
              .storeCheckoutPrompt(widget.duckName),
          collected: _scannedIds.length,
          total: pickedItems.length,
          counterLabel: AppLocalizations.of(context)!.storeScanned,
        ),
        Expanded(
          child: GroceryCashierScene(
            cashierFrame: 0,
            customerDuck: _animatedDuck(),
            customerProgress: _walkProgress,
            checkoutItems: _CheckoutBasket(
              items: pickedItems,
              scannedIds: _scannedIds,
              totalPrice: _basketTotal,
              isScanning: _isScanningBasket,
              scannedItem: _lastScannedId == null
                  ? null
                  : _items.firstWhere((item) => item.id == _lastScannedId),
              onTap: _scanBasket,
            ),
          ),
        ),
        if (_lastScannedId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Opacity(
              opacity: 1 - _joyProgress,
              child: Transform.scale(
                scale: 0.8 + _joyProgress * 0.7,
                child: Text(
                  AppLocalizations.of(context)!.storeScanBeep,
                  style: const TextStyle(
                    color: Color(0xFFE28B43),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _progressHeader({
    required String title,
    required int collected,
    required int total,
    required String counterLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF315D58),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$counterLabel: $collected/$total',
            style: const TextStyle(
              color: Color(0xFF4F8E85),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!
                .storeWalletStatus(_wallet?.balance ?? 0, _basketTotal),
            key: const ValueKey('grocery-wallet-balance'),
            style: const TextStyle(
              color: Color(0xFF315D58),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedDuck() {
    final joy = _joyProgress;
    return Transform.scale(
      scale: 1 + 0.025 * joy,
      child: Column(
        children: [
          GroceryRearDuck(
            gait: _gaitProgress,
            joy: joy,
            onTap: _celebrate,
            name: widget.duckName,
            appearance: widget.duckAppearance,
          ),
          Text(
            widget.duckName,
            style: const TextStyle(
              color: Color(0xFF315D58),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceipt() {
    final pickedItems = _items
        .where((item) => _collectedIds.contains(item.id))
        .toList();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _receiptCard(
          children: [
            const Text('🧾', style: TextStyle(fontSize: 58)),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.storeReceiptTitle,
              style: TextStyle(
                color: Color(0xFF315D58),
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.storePurchasesFor(widget.duckName),
              style: const TextStyle(color: Color(0xFF66817A)),
            ),
            const Divider(height: 28),
            for (final item in pickedItems) _ReceiptRow(item: item),
            const Divider(height: 28),
            Text(
              AppLocalizations.of(context)!.storeTotalPrice(
                pickedItems.length,
                pickedItems.fold(0, (total, item) => total + item.price),
              ),
              key: const ValueKey('grocery-receipt-total'),
              style: const TextStyle(
                color: Color(0xFF315D58),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.storeBringFood,
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF66817A)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _claimPurchases,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.inventory_2_rounded),
                label: Text(AppLocalizations.of(context)!.storeClaim),
                style: _buttonStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimed() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _receiptCard(
          children: [
            const Text('💚', style: TextStyle(fontSize: 58)),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.storeClaimed,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF315D58),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.storeDuckCanEat(widget.duckName),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.favorite_rounded),
                label: Text(
                  AppLocalizations.of(context)!
                      .storeReturnToPet(widget.duckName),
                ),
                style: _buttonStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptCard({required List<Widget> children}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        radius: 28,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  ButtonStyle get _buttonStyle => FilledButton.styleFrom(
    backgroundColor: const Color(0xFF598E87),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  );
}

class _GroceryItem {
  const _GroceryItem({
    required this.id,
    required this.name,
    required this.price,
    required this.shelfPosition,
    required this.shelfRow,
  });

  final String id;
  final String name;
  final int price;
  final double shelfPosition;
  final double shelfRow;
}

Widget _foodIcon(String productId, double size, {Key? key}) => KeyedSubtree(
  key: key,
  child: PixelGroceryProduct(productId: productId, size: size),
);

class _ProductBubble extends StatelessWidget {
  const _ProductBubble({
    required this.item,
    required this.width,
    required this.onTap,
  });

  final _GroceryItem item;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.storeTakeItem(item.name),
      child: GestureDetector(
        key: ValueKey('shelf-${item.id}'),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              height: 64,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    PixelGroceryProduct.shelfRestOffset(item.id),
                  ),
                  child: _foodIcon(item.id, 64),
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              key: ValueKey('price-tag-${item.id}'),
              width: width,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/grocery_price_tag_blank.png',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF382F2C),
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${item.price} ₴',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF382F2C),
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingCart extends StatelessWidget {
  const _ShoppingCart({required this.items, required this.totalPrice});

  final List<_GroceryItem> items;
  final int totalPrice;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('grocery-shopping-basket'),
      width: 96,
      height: 88,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: 15 + (i % 4) * 17,
              top: 16 + (i ~/ 4) * 8,
              child: _foodIcon(
                items[i].id,
                24,
                key: ValueKey('shelf-basket-item-${items[i].id}'),
              ),
            ),
          Positioned(bottom: 12, child: _basketImage(96, 72)),
          if (items.isNotEmpty)
            Positioned(
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD978),
                  border: Border.all(color: const Color(0xFF69503D)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    '$totalPrice ₴',
                    key: const ValueKey('grocery-basket-total'),
                    style: const TextStyle(
                      color: Color(0xFF382F2C),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _basketImage(double width, double height) => Image.asset(
  'assets/images/grocery_basket_red.png',
  key: const ValueKey('grocery-basket-art'),
  width: width,
  height: height,
  fit: BoxFit.contain,
  filterQuality: FilterQuality.none,
  errorBuilder: (context, error, stackTrace) => Icon(
    Icons.shopping_basket_rounded,
    color: const Color(0xFFD94A48),
    size: width,
  ),
);

class _CheckoutBasket extends StatelessWidget {
  const _CheckoutBasket({
    required this.items,
    required this.scannedIds,
    required this.totalPrice,
    required this.isScanning,
    required this.scannedItem,
    required this.onTap,
  });

  final List<_GroceryItem> items;
  final Set<String> scannedIds;
  final int totalPrice;
  final bool isScanning;
  final _GroceryItem? scannedItem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remaining = items
        .where((item) => !scannedIds.contains(item.id))
        .toList();
    return Semantics(
      button: remaining.isNotEmpty && !isScanning,
      label: AppLocalizations.of(context)!.storeTapBasket,
      child: GestureDetector(
        key: const ValueKey('grocery-checkout-basket'),
        onTap: remaining.isEmpty || isScanning ? null : onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          scale: isScanning ? 0.96 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 128,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var index = 0; index < remaining.length; index++)
                      Positioned(
                        left: 25 + (index % 4) * 18,
                        top: 12 + (index ~/ 4) * 10,
                        child: _foodIcon(
                          remaining[index].id,
                          26,
                          key: ValueKey(
                            'checkout-basket-item-${remaining[index].id}',
                          ),
                        ),
                      ),
                    _basketImage(96, 72),
                    if (isScanning)
                      const Positioned(
                        top: 0,
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Color(0xFF315D58),
                          size: 25,
                        ),
                      ),
                  ],
                ),
              ),
              if (scannedItem != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Row(
                    key: ValueKey(scannedItem!.id),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _foodIcon(scannedItem!.id, 24),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!
                            .storeScannedItem(scannedItem!.name),
                        style: const TextStyle(
                          color: Color(0xFF315D58),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                isScanning
                    ? AppLocalizations.of(context)!.storeBasketScanning
                    : AppLocalizations.of(context)!.storeTapBasket,
                key: const ValueKey('grocery-basket-action-label'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF315D58),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${remaining.length}/${items.length} · $totalPrice ₴',
                key: const ValueKey('grocery-basket-contents'),
                style: const TextStyle(
                  color: Color(0xFF382F2C),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackBadge extends StatelessWidget {
  const _FeedbackBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF70A989),
          border: Border.all(color: const Color(0xFF315D58), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66315D58),
              blurRadius: 0,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.item});

  final _GroceryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _foodIcon(item.id, 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                color: Color(0xFF315D58),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${item.price} ₴',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
