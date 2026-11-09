import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/grocery_wallet.dart';
import '../widgets/duck_painter.dart';
import '../widgets/duck_sprite.dart';

class DuckClothingShopScreen extends StatefulWidget {
  const DuckClothingShopScreen({
    super.key,
    required this.wallet,
    required this.selectedSkinId,
    required this.onSelectSkin,
    this.showShop = false,
  });

  static const defaultSkinId = 'default';
  static const jacketSkinId = 'leather_jacket';
  static const heartPajamasSkinId = 'heart_pajamas';

  final GroceryWallet wallet;
  final String? selectedSkinId;
  final Future<void> Function(String?) onSelectSkin;
  final bool showShop;

  @override
  State<DuckClothingShopScreen> createState() => _DuckClothingShopScreenState();
}

class _DuckClothingShopScreenState extends State<DuckClothingShopScreen> {
  late String? _selectedSkinId = widget.selectedSkinId;
  bool _isPurchasing = false;
  bool _isSelecting = false;

  bool get _jacketOwned => widget.wallet.purchasedSkinIds.contains(
    DuckClothingShopScreen.jacketSkinId,
  );

  bool get _heartPajamasOwned => widget.wallet.purchasedSkinIds.contains(
    DuckClothingShopScreen.heartPajamasSkinId,
  );

  Future<void> _purchaseSkin(String skinId, int price) async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);
    try {
      final purchased = await widget.wallet.purchaseSkinOnce(skinId, price);
      if (!mounted) return;
      if (!purchased) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .wardrobeInsufficientFunds(price, widget.wallet.balance),
            ),
          ),
        );
        return;
      }
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.storeSaveError(error.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _selectSkin(String? skinId) async {
    if (_isSelecting || (skinId == _selectedSkinId)) return;
    setState(() => _isSelecting = true);
    try {
      await widget.onSelectSkin(skinId);
      if (mounted) setState(() => _selectedSkinId = skinId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.storeSaveError(error.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  Future<void> _showPreview(String? skinId) async {
    final strings = AppLocalizations.of(context)!;
    final name = switch (skinId) {
      DuckClothingShopScreen.jacketSkinId => strings.wardrobeJacketName,
      DuckClothingShopScreen.heartPajamasSkinId =>
        strings.wardrobeHeartPajamasName,
      _ => strings.wardrobeDefaultName,
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: ValueKey('skin-preview-${skinId ?? 'default'}'),
        title: Text(strings.wardrobePreviewTitle(name)),
        content: SizedBox(
          width: 280,
          height: 300,
          child: DuckSpriteWidget(
            size: const Size(260, 260),
            appearance: _appearanceFor(skinId),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }

  DuckAppearance _appearanceFor(String? skinId) =>
      DuckAppearance(equippedItems: skinId == null ? const [] : [skinId]);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final showJacket = widget.showShop || _jacketOwned;
    final showPajamas = widget.showShop || _heartPajamasOwned;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showShop ? strings.wardrobeShopTitle : strings.wardrobeTitle,
        ),
        foregroundColor: const Color(0xFF315D58),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (!widget.showShop)
            Card(
              key: const ValueKey('duck-skin-default'),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showPreview(null),
                child: _skinCard(
                  name: strings.wardrobeDefaultName,
                  description: strings.wardrobeDefaultDescription,
                  skinId: null,
                  price: strings.wardrobeFree,
                  owned: true,
                  itemPrice: 0,
                  strings: strings,
                ),
              ),
            ),
          if (!widget.showShop) const SizedBox(height: 12),
          if (showJacket)
            Card(
              key: const ValueKey('duck-skin-leather-jacket'),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showPreview(DuckClothingShopScreen.jacketSkinId),
                child: _skinCard(
                  name: strings.wardrobeJacketName,
                  description: strings.wardrobeJacketDescription,
                  skinId: DuckClothingShopScreen.jacketSkinId,
                  price: widget.showShop && !_jacketOwned
                      ? strings.wardrobePrice(GroceryWallet.leatherJacketPrice)
                      : strings.wardrobeOwned,
                  owned: _jacketOwned,
                  itemPrice: GroceryWallet.leatherJacketPrice,
                  strings: strings,
                ),
              ),
            ),
          if (showPajamas)
            Card(
              key: const ValueKey('duck-skin-heart-pajamas'),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () =>
                    _showPreview(DuckClothingShopScreen.heartPajamasSkinId),
                child: _skinCard(
                  name: strings.wardrobeHeartPajamasName,
                  description: strings.wardrobeHeartPajamasDescription,
                  skinId: DuckClothingShopScreen.heartPajamasSkinId,
                  price: widget.showShop && !_heartPajamasOwned
                      ? strings.wardrobePrice(GroceryWallet.heartPajamasPrice)
                      : strings.wardrobeOwned,
                  owned: _heartPajamasOwned,
                  itemPrice: GroceryWallet.heartPajamasPrice,
                  strings: strings,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            strings.duckWalletBalance(widget.wallet.balance),
            key: const ValueKey('wardrobe-wallet-balance'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF315D58),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skinCard({
    required String name,
    required String description,
    required String? skinId,
    required String price,
    required bool owned,
    required int itemPrice,
    required AppLocalizations strings,
  }) {
    final isSelected = _selectedSkinId == skinId;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(description, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            strings.wardrobeTapToPreview,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(
            height: 152,
            child: DuckSpriteWidget(
              size: const Size(160, 150),
              appearance: _appearanceFor(skinId),
            ),
          ),
          if (owned)
            FilledButton(
              key: ValueKey('select-skin-${skinId ?? 'default'}'),
              onPressed: isSelected || _isSelecting
                  ? null
                  : () => _selectSkin(skinId),
              child: Text(
                isSelected ? strings.wardrobeSelected : strings.wardrobeChoose,
              ),
            )
          else
            FilledButton(
              key: ValueKey(
                skinId == DuckClothingShopScreen.jacketSkinId
                    ? 'buy-skin-leather-jacket'
                    : 'buy-skin-$skinId',
              ),
              onPressed: _isPurchasing
                  ? null
                  : () => _purchaseSkin(skinId!, itemPrice),
              child: Text(
                _isPurchasing ? strings.wardrobeBuying : strings.wardrobeBuy,
              ),
            ),
        ],
      ),
    );
  }
}
