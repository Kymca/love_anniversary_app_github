import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/daily_mood.dart';
import '../services/grocery_wallet.dart';
import '../services/app_sound_service.dart';
import '../services/mood_pair_repository.dart';
import '../services/duck_ownership_repository.dart';
import '../services/duck_name_repository.dart';
import '../services/pair_repository.dart';
import '../services/participant_profile_repository.dart';
import '../widgets/duck_painter.dart';
import '../widgets/duck_mood.dart';
import '../widgets/duck_sprite.dart';
import '../widgets/mood_pair_widget.dart';
import '../widgets/mood_envelope.dart';
import 'duck_clothing_shop_screen.dart';
import 'mini_games/grocery_aisle_scene.dart';
import 'mini_games/grocery_store_screen.dart';
import 'mini_games/warehouse_work_screen.dart';
import '../theme/app_theme.dart';

Future<bool> checkOverlayPermission() async {
  if (!Platform.isAndroid) return false;
  return FlutterOverlayWindow.isPermissionGranted();
}

bool shouldShowDuckRecall({required bool debugMode}) => debugMode;

class TamagotchiScreen extends StatefulWidget {
  const TamagotchiScreen({
    super.key,
    this.messengerEventId = 0,
    this.pairRepository,
    this.pairRevision = 0,
    this.onOpenPairs,
    this.onDuckNameChanged,
    this.partnerSide = DuckPartnerSide.first,
    this.isActive = true,
    this.moodPairRepository,
    this.ownershipRepository,
    this.duckNameRepository,
  });

  final int messengerEventId;
  final PairRepository? pairRepository;
  final int pairRevision;
  final VoidCallback? onOpenPairs;
  final ValueChanged<String?>? onDuckNameChanged;
  final DuckPartnerSide partnerSide;
  final bool isActive;
  final MoodPairRepository? moodPairRepository;
  final DuckOwnershipService? ownershipRepository;
  final DuckNameRepository? duckNameRepository;

  static String outfitStorageKey(DuckPartnerSide side) =>
      'tamagotchi_duck_outfit_${side.name}';

  @override
  State<TamagotchiScreen> createState() => _TamagotchiScreenState();
}

class _TamagotchiScreenState extends State<TamagotchiScreen>
    with SingleTickerProviderStateMixin {
  static const _birthDateKey = 'tamagotchi_birth_date';
  static const _lastFedDateKey = 'tamagotchi_last_fed_date';
  static const _recentFoodIdsKey = 'tamagotchi_recent_food_ids';
  static const _duckOutfitKey = 'tamagotchi_duck_outfit';
  static const _duckColor = Color(0xFF598E87);

  late final PairRepository _pairRepository =
      widget.pairRepository ?? SharedPreferencesPairRepository();
  late final MoodPairRepository _moodPairRepository =
      widget.moodPairRepository ?? SharedPreferencesMoodPairRepository();
  late final ParticipantProfileRepository _participantProfileRepository =
      ParticipantProfileRepository();
  late final DuckOwnershipService _ownershipRepository =
      widget.ownershipRepository ??
      DuckOwnershipRepository(profileRepository: _participantProfileRepository);
  late final DuckNameRepository _duckNameRepository =
      widget.duckNameRepository ?? SharedPreferencesDuckNameRepository();
  final _nameController = TextEditingController();

  SharedPreferences? _preferences;
  GroceryWallet? _wallet;
  String _duckName = 'Кряква';
  DateTime? _birthDate;
  DateTime? _lastFedDate;
  DateTime _now = DateTime.now();
  DailyMood? _partnerMood;
  bool _isLoading = true;
  int _petLoadGeneration = 0;
  String? _loadError;
  bool _isPaired = false;
  bool _isDuckOwner = false;
  bool? _lastKnownDuckOwner;
  Map<String, String> _participantNames = const {};
  bool _isBlinking = false;
  bool _isOverlayEnabled = false;
  bool _isOverlayBusy = false;
  bool _feedVarietyError = false;
  List<String> _groceryInventory = [];
  List<String> _recentFoodIds = [];
  int _detailSeed = math.Random().nextInt(1 << 31);
  int _duckJoyTrigger = 0;
  late final DuckBlinkTicker _blinkClock = DuckBlinkTicker(
    vsync: this,
    onBlink: (blinking) {
      if (mounted) setState(() => _isBlinking = blinking);
    },
  );
  Timer? _timer;
  Timer? _messengerTimer;
  StreamSubscription<String?>? _duckNameSubscription;
  StreamSubscription<DailyPairMood>? _pairMoodSubscription;
  String? _moodWatchDateKey;
  bool _showCouponMessage = false;
  bool _showingHelp = false;

  // The closet can provide these later without changing the painter API.
  List<String> _equippedItems = [];
  final DuckHat _equippedHat = DuckHat.none;
  DuckAppearance get _duckAppearance => DuckAppearance(
    hat: _equippedHat,
    equippedItems: List.unmodifiable(_equippedItems),
  );
  bool get _hasLeatherJacket =>
      _equippedItems.contains(DuckClothingShopScreen.jacketSkinId);
  String? get _selectedSkinId {
    if (_equippedItems.contains(DuckClothingShopScreen.heartPajamasSkinId)) {
      return DuckClothingShopScreen.heartPajamasSkinId;
    }
    return _hasLeatherJacket ? DuckClothingShopScreen.jacketSkinId : null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _loadPet();
      _loadPartnerMood();
      _watchPartnerMood();
      _startClock();
      if (Platform.isAndroid) _refreshOverlayStatus();
    }
  }

  @override
  void didUpdateWidget(covariant TamagotchiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _now = DateTime.now();
        _loadPet();
        _loadPartnerMood();
        _watchPartnerMood();
        _startClock();
        if (Platform.isAndroid) _refreshOverlayStatus();
      } else {
        _timer?.cancel();
        _blinkClock.stop();
        _pairMoodSubscription?.cancel();
        _pairMoodSubscription = null;
        _moodWatchDateKey = null;
      }
    } else if (widget.isActive &&
        widget.pairRevision != oldWidget.pairRevision) {
      _loadPet();
    }
    if (widget.partnerSide != oldWidget.partnerSide) {
      final preferences = _preferences;
      if (preferences != null) {
        _equippedItems =
            preferences.getStringList(
              TamagotchiScreen.outfitStorageKey(widget.partnerSide),
            ) ??
            (widget.partnerSide == DuckPartnerSide.first
                ? preferences.getStringList(_duckOutfitKey)
                : null) ??
            [];
      }
      if (widget.isActive) {
        _loadPartnerMood();
        _watchPartnerMood();
        _loadPet();
      }
    }
    if (widget.messengerEventId != oldWidget.messengerEventId) {
      _showCouponMessenger();
    }
  }

  void _startClock() {
    _timer?.cancel();
    if (!widget.isActive) return;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      if (mounted) setState(() => _now = now);
      _loadPartnerMood();
      _watchPartnerMood();
      _refreshDuckOwnership();
    });
  }

  Future<void> _loadPartnerMood() async {
    try {
      final pairMood = await _moodPairRepository.loadFor(_now);
      if (!mounted) return;
      final mood = duckPartnerMoodForSide(pairMood.moods, widget.partnerSide);
      if (_partnerMood != mood) setState(() => _partnerMood = mood);
    } catch (_) {
      if (mounted && _partnerMood != null) {
        setState(() => _partnerMood = null);
      }
    }
  }

  void _watchPartnerMood() {
    if (!widget.isActive) return;
    final dateKey = moodDateKey(_now);
    if (_moodWatchDateKey == dateKey) return;
    _moodWatchDateKey = dateKey;
    _pairMoodSubscription?.cancel();
    _pairMoodSubscription = _moodPairRepository
        .watchFor(_now)
        .listen(
          (pairMood) {
            if (!mounted) return;
            final mood = duckPartnerMoodForSide(
              pairMood.moods,
              widget.partnerSide,
            );
            if (_partnerMood != mood) setState(() => _partnerMood = mood);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (mounted && _partnerMood != null) {
              setState(() => _partnerMood = null);
            }
          },
        );
  }

  Future<void> _refreshDuckOwnership() async {
    try {
      final isOwner = await _ownershipRepository.isCurrentParticipantOwner(
        DateTime.now(),
      );
      final previousOwnerState = _lastKnownDuckOwner;
      _lastKnownDuckOwner = isOwner;
      if (mounted && previousOwnerState == false && isOwner) {
        unawaited(AppSoundService.play(AppSoundEvent.duckArrived));
      }
      if (mounted && isOwner != _isDuckOwner) {
        setState(() => _isDuckOwner = isOwner);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _loadError = AppLocalizations.of(context)!.backendConnectionError,
        );
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCouponMessenger() {
    _messengerTimer?.cancel();
    setState(() {
      _showCouponMessage = true;
      _duckJoyTrigger++;
    });
    _messengerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showCouponMessage = false);
    });
  }

  Future<void> _refreshOverlayStatus() async {
    final active = await FlutterOverlayWindow.isActive();
    if (mounted) setState(() => _isOverlayEnabled = active);
  }

  Future<void> _setOverlayEnabled(bool enable) async {
    if (_isOverlayBusy) return;
    final strings = AppLocalizations.of(context)!;
    setState(() => _isOverlayBusy = true);
    try {
      if (!enable) {
        await FlutterOverlayWindow.closeOverlay();
        if (mounted) setState(() => _isOverlayEnabled = false);
        return;
      }

      var hasPermission = await checkOverlayPermission();
      if (!hasPermission) {
        await FlutterOverlayWindow.requestPermission();
        hasPermission = await checkOverlayPermission();
      }
      if (!hasPermission) {
        _showOverlayMessage(strings.overlayPermission);
        return;
      }

      await FlutterOverlayWindow.showOverlay(
        height: 190,
        width: 190,
        alignment: OverlayAlignment.centerRight,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: strings.overlayTitle(_duckName),
        overlayContent: strings.overlayPetTapHint,
        dismissConfig: const OverlayDismissConfig(),
      );
      if (!mounted) return;
      setState(() => _isOverlayEnabled = true);
      await const MethodChannel('love_anniversary_app/app')
          .invokeMethod<void>('minimize');
    } on PlatformException catch (error) {
      _showOverlayMessage(
        strings.overlayLaunchError(error.message ?? error.code),
      );
    } finally {
      if (mounted) setState(() => _isOverlayBusy = false);
    }
  }

  void _showOverlayMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadPet() async {
    final loadGeneration = ++_petLoadGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final outfitSide = widget.partnerSide;
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || loadGeneration != _petLoadGeneration) return;
      final activePair = await _pairRepository.loadActivePair();
      if (!mounted || loadGeneration != _petLoadGeneration) return;
      final participantNames = await _participantProfileRepository.loadNames(
        pair: activePair,
      );
      if (!mounted || loadGeneration != _petLoadGeneration) return;
      final currentParticipantName = participantNames[widget.partnerSide.name];
      if (activePair == null || currentParticipantName == null) {
        _blinkClock.stop();
        setState(() {
          _preferences = preferences;
          _participantNames = participantNames;
          _isPaired = false;
          _lastKnownDuckOwner = null;
          _isLoading = false;
        });
        widget.onDuckNameChanged?.call(null);
        return;
      }
      final wallet = await GroceryWallet.open(preferences: preferences);
      if (!mounted || loadGeneration != _petLoadGeneration) return;
      final defaultDuckName = AppLocalizations.of(context)!.defaultDuckName;
      final today = _dateOnly(DateTime.now());
      final birthTimestamp = preferences.getInt(_birthDateKey);
      final lastFedTimestamp = preferences.getInt(_lastFedDateKey);
      final savedInventory =
          preferences.getStringList(GroceryStoreScreen.inventoryKey) ?? [];
      final migratedInventory = GroceryStoreScreen.normalizeInventory(
        savedInventory,
      );
      if (savedInventory.contains('bread')) {
        await preferences.setStringList(
          GroceryStoreScreen.inventoryKey,
          migratedInventory,
        );
      }
      final equippedItems = await _loadOutfit(preferences, outfitSide);
      final isDuckOwner = await _ownershipRepository.isCurrentParticipantOwner(
        DateTime.now(),
      );

      if (birthTimestamp == null || lastFedTimestamp == null) {
        await preferences.setInt(_birthDateKey, today.millisecondsSinceEpoch);
        await preferences.setInt(_lastFedDateKey, today.millisecondsSinceEpoch);
      }
      final duckName = await _duckNameRepository.loadName(activePair.id);
      final shouldPromptForName = duckName == null
          ? await _duckNameRepository.claimNamingPrompt(activePair.id)
          : false;
      await _duckNameSubscription?.cancel();
      if (duckName == null) {
        _duckNameSubscription = _duckNameRepository
            .watchName(activePair.id)
            .listen(
              (name) {
                if (mounted && name != null && name != _duckName) {
                  setState(() => _duckName = name);
                  widget.onDuckNameChanged?.call(name);
                }
              },
              onError: (Object _) {
                if (mounted) {
                  setState(
                    () =>
                        _loadError = AppLocalizations.of(context)!
                            .backendConnectionError,
                  );
                }
              },
            );
      }

      if (!mounted || loadGeneration != _petLoadGeneration) return;
      setState(() {
        _preferences = preferences;
        _wallet = wallet;
        _isPaired = true;
        _isDuckOwner = isDuckOwner;
        _lastKnownDuckOwner = isDuckOwner;
        _participantNames = participantNames;
        _duckName = duckName ?? defaultDuckName;
        _birthDate =
            _dateFromTimestamp(preferences.getInt(_birthDateKey)) ?? today;
        _lastFedDate =
            _dateFromTimestamp(preferences.getInt(_lastFedDateKey)) ?? today;
        _groceryInventory = migratedInventory;
        final savedFoodIds = preferences.getStringList(_recentFoodIdsKey) ?? [];
        _recentFoodIds = savedFoodIds.length <= 2
            ? savedFoodIds
            : savedFoodIds.sublist(savedFoodIds.length - 2);
        _equippedItems = equippedItems;
        _isLoading = false;
      });
      _blinkClock.start();
      widget.onDuckNameChanged?.call(_duckName);
      if (shouldPromptForName) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showNameDialog();
        });
      }
    } catch (_) {
      if (!mounted || loadGeneration != _petLoadGeneration) return;
      setState(() {
        _isLoading = false;
        _isPaired = false;
        _lastKnownDuckOwner = null;
        _loadError = AppLocalizations.of(context)!.backendConnectionError;
      });
    }
  }

  Future<List<String>> _loadOutfit(
    SharedPreferences preferences,
    DuckPartnerSide side,
  ) async {
    final sideKey = TamagotchiScreen.outfitStorageKey(side);
    final savedItems = preferences.getStringList(sideKey);
    if (savedItems != null || side != DuckPartnerSide.first) {
      return savedItems ?? [];
    }

    final legacyItems = preferences.getStringList(_duckOutfitKey);
    if (legacyItems == null) return [];
    final saved = await preferences.setStringList(sideKey, legacyItems);
    if (!saved) throw StateError('Could not migrate the duck outfit.');
    await preferences.remove(_duckOutfitKey);
    return legacyItems;
  }

  Future<void> _saveSelectedSkin(
    DuckPartnerSide outfitSide,
    String? skinId,
  ) async {
    final preferences = _preferences;
    if (preferences == null) {
      throw StateError('Pet preferences are not loaded yet.');
    }
    if (skinId != null &&
        skinId != DuckClothingShopScreen.jacketSkinId &&
        skinId != DuckClothingShopScreen.heartPajamasSkinId) {
      throw ArgumentError.value(skinId, 'skinId');
    }
    if (skinId != null &&
        !(_wallet?.purchasedSkinIds.contains(skinId) ?? false)) {
      throw StateError('The selected outfit has not been purchased.');
    }

    final nextItems = List<String>.of(_equippedItems)
      ..remove(DuckClothingShopScreen.jacketSkinId)
      ..remove(DuckClothingShopScreen.heartPajamasSkinId);
    if (skinId != null) nextItems.add(skinId);
    final saved = await preferences.setStringList(
      TamagotchiScreen.outfitStorageKey(outfitSide),
      nextItems,
    );
    if (!saved) throw StateError('Could not save the duck outfit.');
    if (mounted && widget.partnerSide == outfitSide) {
      setState(() => _equippedItems = nextItems);
    }
  }

  DateTime? _dateFromTimestamp(int? timestamp) {
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  int get _daysSinceLastMeal {
    final lastFedDate = _lastFedDate;
    if (lastFedDate == null) return 0;
    return _dateOnly(_now)
        .difference(_dateOnly(lastFedDate))
        .inDays
        .clamp(0, 100000);
  }

  int get _hunger => (100 - _daysSinceLastMeal * 25).clamp(0, 100);

  int _inventoryCount(String itemId) =>
      _groceryInventory.where((item) => item == itemId).length;

  bool get _hasRunAway => _daysSinceLastMeal >= 4;

  int get _ageInDays {
    final birthDate = _birthDate;
    if (birthDate == null) return 0;
    return _dateOnly(_now)
        .difference(_dateOnly(birthDate))
        .inDays
        .clamp(0, 100000);
  }

  Future<void> _showNameDialog() async {
    final strings = AppLocalizations.of(context)!;
    _nameController.text = _duckName;
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(strings.nameDuckTitle),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: strings.duckNameHint,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_nameController.text),
            child: Text(strings.getAcquainted),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final pair = await _pairRepository.loadActivePair();
    String savedName;
    try {
      savedName = await _duckNameRepository.saveName(pair?.id, trimmedName);
    } catch (_) {
      if (mounted) _showMessage(strings.backendConnectionError);
      return;
    }
    if (mounted) {
      setState(() => _duckName = savedName);
      widget.onDuckNameChanged?.call(savedName);
      if (_isOverlayEnabled) {
        await FlutterOverlayWindow.updateNotification(
          title: strings.duckNamed(savedName),
          content: strings.petSemantics,
        );
      }
    }
  }

  Future<void> _feed(_Food food, {String? inventoryItemId}) async {
    final strings = AppLocalizations.of(context)!;
    try {
      await _ownershipRepository.requireCurrentOwner(DateTime.now());
    } on DuckNotOwnedException {
      if (mounted) {
        _showMessage(strings.duckNotOwnerAction);
      }
      return;
    } catch (_) {
      if (mounted) _showMessage(strings.backendConnectionError);
      return;
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    if (_recentFoodIds.length == 2 &&
        _recentFoodIds.every((id) => id == food.id)) {
      if (mounted) setState(() => _feedVarietyError = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(strings.feedVarietyRequired),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final today = _dateOnly(DateTime.now());
    final recentFoodIds = [..._recentFoodIds, food.id];
    if (recentFoodIds.length > 2) recentFoodIds.removeAt(0);
    if (inventoryItemId != null &&
        _groceryInventory.contains(inventoryItemId)) {
      final updatedInventory = List<String>.from(_groceryInventory)
        ..remove(inventoryItemId);
      await _preferences?.setStringList(
        GroceryStoreScreen.inventoryKey,
        updatedInventory,
      );
      if (mounted) setState(() => _groceryInventory = updatedInventory);
    }
    await _preferences?.setStringList(_recentFoodIdsKey, recentFoodIds);
    await _preferences?.setInt(_lastFedDateKey, today.millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() {
      _feedVarietyError = false;
      _lastFedDate = today;
      _recentFoodIds = recentFoodIds;
      _now = DateTime.now();
      _detailSeed = math.Random().nextInt(1 << 31);
      _duckJoyTrigger++;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(strings.feedConfirmation(_duckName, food.foodName)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _tapDuck() {
    HapticFeedback.lightImpact();
    setState(() {
      _detailSeed = math.Random().nextInt(1 << 31);
      _duckJoyTrigger++;
    });
  }

  Future<void> _openGroceryStore() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => GroceryStoreScreen(
          duckName: _duckName,
          wallet: _wallet,
          duckAppearance: _duckAppearance,
          canWork: _isDuckOwner,
          ownershipRepository: _ownershipRepository,
        ),
      ),
    );
    final preferences = _preferences;
    if (!mounted || preferences == null) return;
    setState(() {
      _groceryInventory = GroceryStoreScreen.normalizeInventory(
        preferences.getStringList(GroceryStoreScreen.inventoryKey) ?? [],
      );
    });
  }

  Future<void> _openWarehouseWork() async {
    final strings = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    try {
      await _ownershipRepository.requireCurrentOwner(DateTime.now());
    } on DuckNotOwnedException {
      if (mounted) {
        _showMessage(strings.duckNotOwnerAction);
      }
      return;
    } catch (_) {
      if (mounted) _showMessage(strings.backendConnectionError);
      return;
    }
    if (!mounted) return;
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WarehouseWorkScreen(
          wallet: _wallet,
          ownershipRepository: _ownershipRepository,
        ),
      ),
    );
  }

  Future<void> _openWardrobe() async {
    await _openClothingScreen(showShop: false);
  }

  Future<void> _showHelp() async {
    if (_showingHelp) return;
    setState(() => _showingHelp = true);
    try {
      final strings = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('duck-help-dialog'),
          titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
          title: Row(
            children: [
              Expanded(child: Text(strings.tamagotchiHelpTitle)),
              IconButton(
                key: const ValueKey('duck-help-close'),
                tooltip: strings.close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.tamagotchiHelpCare),
                const SizedBox(height: 12),
                Text(strings.tamagotchiHelpFeed),
                const SizedBox(height: 12),
                Text(strings.tamagotchiHelpPlay),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _showingHelp = false);
    }
  }

  Future<void> _openOutfitShop() async {
    await _openClothingScreen(showShop: true);
  }

  Future<void> _openClothingScreen({required bool showShop}) async {
    final wallet = _wallet;
    if (wallet == null) return;
    final outfitSide = widget.partnerSide;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DuckClothingShopScreen(
          wallet: wallet,
          selectedSkinId: _selectedSkinId,
          onSelectSkin: (skinId) => _saveSelectedSkin(outfitSide, skinId),
          showShop: showShop,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _callBack() async {
    final now = _dateOnly(DateTime.now());
    final birthDate = _birthDate ?? now;
    final lastFedDate = now;
    await _preferences?.setInt(_birthDateKey, birthDate.millisecondsSinceEpoch);
    await _preferences?.setInt(
      _lastFedDateKey,
      lastFedDate.millisecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() {
      _birthDate = birthDate;
      _lastFedDate = lastFedDate;
      _now = DateTime.now();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blinkClock.dispose();
    _messengerTimer?.cancel();
    _duckNameSubscription?.cancel();
    _pairMoodSubscription?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.petScreenTitle),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF315D58),
        actions: [
          IconButton(
            key: const ValueKey('duck-help-button'),
            tooltip: strings.tamagotchiHelpTitle,
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: AppGradientBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _duckColor))
            : _loadError != null
            ? Center(child: Text(_loadError!, textAlign: TextAlign.center))
            : !_isPaired
            ? _buildPairRequired()
            : _hasRunAway
            ? _buildRunawayScreen()
            : _buildPetScreen(),
      ),
    );
  }

  Widget _buildPairRequired() {
    final strings = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_alt_rounded,
                  size: 44,
                  color: _duckColor,
                ),
                const SizedBox(height: 12),
                Text(
                  strings.createPair,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('duck-open-pairs'),
                  onPressed: widget.onOpenPairs,
                  icon: const Icon(Icons.favorite_rounded),
                  label: Text(strings.openPairs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPetScreen() {
    final strings = AppLocalizations.of(context)!;
    final hungerColor = _hunger > 50
        ? const Color(0xFF70A989)
        : _hunger > 25
        ? const Color(0xFFE6A855)
        : const Color(0xFFE47773);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                _card(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Color(0xFFE5899D),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.familyTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.teal.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.favorite,
                            color: Color(0xFFE5899D),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _duckName,
                        style: const TextStyle(
                          color: Color(0xFF315D58),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.petAge(_ageInDays),
                        style: TextStyle(color: Colors.teal.shade700),
                      ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: _showNameDialog,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(strings.rename),
                      ),
                      Text(
                        _duckNameRepository.isSynchronized
                            ? strings.duckNameSynchronizedNotice
                            : strings.duckNameLocalNotice,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                MoodPairWidget(
                  repository: _moodPairRepository,
                  participantSide: widget.partnerSide.name,
                  isActive: widget.isActive,
                  participantNames: _participantNames,
                  onNameChanged: (names) {
                    setState(() => _participantNames = names);
                  },
                  onChanged: _loadPartnerMood,
                ),
                const SizedBox(height: 18),
                _card(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_in_picture_alt_rounded,
                        color: _duckColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.overlayTitle(_duckName),
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              Platform.isAndroid
                                  ? strings.overlayAndroid
                                  : strings.overlayUnavailable,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mutedInk),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch.adaptive(
                        value: _isOverlayEnabled,
                        onChanged: _isOverlayBusy || !Platform.isAndroid
                            ? null
                            : _setOverlayEnabled,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _card(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _showCouponMessage
                            ? Container(
                                key: const ValueKey('coupon-messenger-bubble'),
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1D9),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFEACD9D),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.mark_email_unread_rounded,
                                      color: Color(0xFFB58248),
                                      size: 19,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        strings.couponActivatedMessage,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xFF725436),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('coupon-messenger-hidden'),
                              ),
                      ),
                      DuckJoyReaction(
                        trigger: _duckJoyTrigger,
                        builder: (context, joy) => Transform.translate(
                          offset: Offset(0, -28 * joy * (1 - joy).abs()),
                          child: Transform.scale(
                            scale: 1 + 0.04 * joy,
                            child: Stack(
                              children: [
                                DuckPartnerTransition(
                                  side: widget.partnerSide,
                                  child: DuckPetWidget(
                                    key: ValueKey(widget.partnerSide),
                                    size: const Size(240, 205),
                                    semanticsLabel: strings.petSemantics,
                                    onTap: _tapDuck,
                                    appearance: _duckAppearance,
                                    blink: _isBlinking,
                                    joy: joy,
                                    detailSeed: _detailSeed,
                                    emotion: duckEmotionForMood(_partnerMood),
                                  ),
                                ),
                                if (_showCouponMessage)
                                  const Positioned(
                                    right: 46,
                                    bottom: 18,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0xFFFFF1D9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(7),
                                        child: Icon(
                                          Icons.mail_rounded,
                                          size: 19,
                                          color: Color(0xFFB58248),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (!_isDuckOwner && _partnerMood != null)
                                  Positioned(
                                    right: 34,
                                    bottom: 10,
                                    child: MoodIncomingEnvelope(
                                      key: ValueKey(
                                        'incoming-mood-${_partnerMood!.name}',
                                      ),
                                      mood: _partnerMood!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hunger > 50
                            ? strings.moodHappy
                            : _hunger > 0
                            ? strings.moodHungry
                            : strings.moodVeryHungry,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.teal.shade800,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isDuckOwner
                            ? strings.duckOwnedByYouToday
                            : strings.duckOwnedByPartnerToday(
                                _participantNames[widget.partnerSide ==
                                            DuckPartnerSide.first
                                        ? 'second'
                                        : 'first'] ??
                                    (widget.partnerSide == DuckPartnerSide.first
                                        ? strings.moodParticipantTwo
                                        : strings.moodParticipantOne),
                              ),
                        key: const ValueKey('daily-duck-owner-status'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('open-duck-wardrobe'),
                        onPressed: _openWardrobe,
                        icon: const Icon(Icons.checkroom),
                        label: Text(strings.wardrobeEntry),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF252A32),
                          side: const BorderSide(color: Color(0xFF252A32)),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.restaurant_rounded,
                            color: _duckColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.satiety,
                              style: TextStyle(
                                color: Color(0xFF315D58),
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          Text(
                            '$_hunger%',
                            style: TextStyle(
                              color: hungerColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: _hunger / 100),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, child) =>
                            LinearProgressIndicator(
                              value: value,
                              minHeight: 13,
                              borderRadius: BorderRadius.circular(20),
                              color: hungerColor,
                              backgroundColor: const Color(0xFFE8F0EC),
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        strings.dailyHungerLoss,
                        style: TextStyle(
                          color: Colors.blueGrey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.feedDuck,
                        style: TextStyle(
                          color: Color(0xFF315D58),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_feedVarietyError) ...[
                        const SizedBox(height: 8),
                        Text(
                          strings.feedVarietyRequired,
                          key: const ValueKey('feed-variety-warning'),
                          style: TextStyle(
                            color: Colors.deepOrange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_groceryInventory.isNotEmpty) ...[
                        Text(
                          strings.inventoryHint,
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children:
                            [
                                  _Food(
                                    'crumbs',
                                    strings.foodCrumbs,
                                    strings.foodCrumbsSnack,
                                  ),
                                  _Food(
                                    'watermelon',
                                    strings.foodWatermelonStore,
                                    strings.foodWatermelonStoreSnack,
                                  ),
                                  _Food(
                                    'worm',
                                    strings.foodWorm,
                                    strings.foodWormSnack,
                                  ),
                                ]
                                .map((food) {
                                  return ActionChip(
                                    avatar: _foodAvatar(food),
                                    label: Text('${food.label} (0)'),
                                    onPressed: _isDuckOwner
                                        ? () => _feed(food)
                                        : null,
                                    backgroundColor: const Color(0xFFFFF8FB),
                                    side: BorderSide(
                                      color: AppColors.rose.withValues(
                                        alpha: 0.13,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    elevation: 2,
                                  );
                                })
                                .toList(growable: false),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: _inventoryProducts(strings).entries
                            .map((entry) {
                              final count = _inventoryCount(entry.key);
                              final isStarterFood = const {
                                'crumbs',
                                'worm',
                                'watermelon',
                              }.contains(entry.key);
                              return ActionChip(
                                avatar: _foodAvatar(entry.value),
                                label: Text('${entry.value.label} ×$count'),
                                onPressed:
                                    _isDuckOwner && (count > 0 || isStarterFood)
                                    ? () => _feed(
                                        entry.value,
                                        inventoryItemId: count > 0
                                            ? entry.key
                                            : null,
                                      )
                                    : null,
                                backgroundColor: count > 0
                                    ? const Color(0xFFFFF5E9)
                                    : const Color(0xFFFFF8FB),
                                side: BorderSide(
                                  color: count > 0
                                      ? AppColors.peach.withValues(alpha: 0.9)
                                      : AppColors.rose.withValues(alpha: 0.13),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 2,
                              );
                            })
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        strings.duckWalletBalance(_wallet?.balance ?? 0),
                        key: const ValueKey('duck-wallet-balance'),
                        style: TextStyle(
                          color: _duckColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              label: strings.goToStore,
                              button: true,
                              onTap: _openGroceryStore,
                              child: ExcludeSemantics(
                                child: FilledButton(
                                  key: const ValueKey(
                                    'tamagotchi-grocery-store-button',
                                  ),
                                  onPressed: _openGroceryStore,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _duckColor,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 72),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.shopping_cart_rounded),
                                      const SizedBox(height: 4),
                                      Text(
                                        strings.goToStore,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Semantics(
                              label: strings.goToWarehouseWork,
                              button: true,
                              onTap: _isDuckOwner ? _openWarehouseWork : null,
                              child: ExcludeSemantics(
                                child: FilledButton(
                                  key: const ValueKey(
                                    'tamagotchi-warehouse-work-button',
                                  ),
                                  onPressed: _isDuckOwner
                                      ? _openWarehouseWork
                                      : null,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFB96842),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 72),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.inventory_2_rounded),
                                      const SizedBox(height: 4),
                                      Text(
                                        strings.goToWarehouseWork,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _card(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: _duckColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.careDay(
                            _duckName,
                            _now.day.isEven ? strings.you : strings.yourPartner,
                          ),
                          style: const TextStyle(
                            color: Color(0xFF315D58),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _card(
                  child: InkWell(
                    key: const ValueKey('open-duck-outfit-shop'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: _openOutfitShop,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Text('👒', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              strings.comingSoonOutfits(_duckName),
                              style: const TextStyle(
                                color: Color(0xFF315D58),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.storefront_rounded,
                            color: Color(0xFF8DA8A0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRunawayScreen() {
    final strings = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🥺', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              Text(
                strings.runawayTitle(_duckName),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF315D58),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                strings.runawayDescription,
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF66817A)),
              ),
              const SizedBox(height: 24),
              if (shouldShowDuckRecall(debugMode: kDebugMode))
                FilledButton.icon(
                  key: const ValueKey('debug-call-duck-back'),
                  onPressed: _callBack,
                  icon: const Icon(Icons.favorite_rounded),
                  label: Text(strings.callDuckBack),
                  style: FilledButton.styleFrom(
                    backgroundColor: _duckColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return SizedBox(
      width: double.infinity,
      child: GlassCard(child: child),
    );
  }
}

class _Food {
  const _Food(this.id, this.label, this.foodName);

  final String id;
  final String label;
  final String foodName;
}

Widget _foodAvatar(_Food food) =>
    PixelGroceryProduct(productId: food.id, size: 28);

Map<String, _Food> _inventoryProducts(AppLocalizations strings) => {
  'crumbs': _Food('crumbs', strings.foodCrumbs, strings.foodCrumbsSnack),
  'watermelon': _Food(
    'watermelon',
    strings.foodWatermelonStore,
    strings.foodWatermelonStoreSnack,
  ),
  'worm': _Food('worm', strings.foodWorms, strings.foodWormSnack),
  'pizza': _Food('pizza', strings.foodPizza, strings.foodPizzaSnack),
  'apple': _Food('apple', strings.foodApple, strings.foodApple),
  'cheese': _Food('cheese', strings.foodCheese, strings.foodCheese),
  'carrot': _Food('carrot', strings.foodCarrot, strings.foodCarrot),
  'milk': _Food('milk', strings.foodMilk, strings.foodMilk),
};

class DuckPetWidget extends StatefulWidget {
  const DuckPetWidget({
    super.key,
    required this.size,
    this.semanticsLabel,
    this.onTap,
    this.appearance = const DuckAppearance(),
    this.blink = false,
    this.joy = 0,
    this.detailSeed = 0,
    this.emotion = DuckEmotion.neutral,
  });

  final Size size;
  final String? semanticsLabel;
  final VoidCallback? onTap;
  final DuckAppearance appearance;
  final bool blink;
  final double joy;
  final int detailSeed;
  final DuckEmotion emotion;

  @override
  State<DuckPetWidget> createState() => _DuckPetWidgetState();
}

class _DuckPetWidgetState extends State<DuckPetWidget>
    with SingleTickerProviderStateMixin {
  static const _jumpDuration = duckJumpAnimationDuration;
  static const _idleDuration = Duration(microseconds: 2600000);
  late final DuckFrameTicker _clock = DuckFrameTicker(
    vsync: this,
    onFrame: (frame) {
      if (!mounted) return;
      final jumpStart = _jumpStartFrame;
      if (jumpStart != null &&
          duckAnimationProgressAtFrame(frame - jumpStart, _jumpDuration) >= 1) {
        setState(() => _jumpStartFrame = null);
      } else {
        setState(() {});
      }
    },
  );
  int? _jumpStartFrame;

  void _playAnimation() {
    widget.onTap?.call();
    setState(() => _jumpStartFrame = _clock.frameIndex);
  }

  double get _jumpProgress {
    final jumpStart = _jumpStartFrame;
    if (jumpStart == null) return 0;
    return duckAnimationProgressAtFrame(
      _clock.frameIndex - jumpStart,
      _jumpDuration,
    );
  }

  double _jumpOffset(double progress) {
    if (progress < 0.45) {
      return -25 * Curves.easeOut.transform(progress / 0.45);
    }
    return -25 + 25 * Curves.bounceOut.transform((progress - 0.45) / 0.55);
  }

  @override
  void initState() {
    super.initState();
    _clock.start();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  bool get _usePixelSprite =>
      widget.appearance.equippedItems.contains('leather_jacket') ||
      widget.appearance.bodyColor == const Color(0xFFFFE38C);

  @override
  Widget build(BuildContext context) {
    final idleProgress = duckAnimationProgressAtFrame(
      _clock.frameIndex,
      _idleDuration,
      loop: true,
    );
    final flutter = math.sin(idleProgress * math.pi * 2);
    final jump = _jumpProgress;
    final takeoff = jump < 0.12 ? (1 - jump / 0.12) : 0.0;
    final landing = jump > 0.86
        ? math.sin((jump - 0.86) / 0.14 * math.pi)
        : 0.0;
    final stretch = math.sin(jump * math.pi);

    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _playAnimation,
        child: RepaintBoundary(
          key: const ValueKey('pixel-duck-animation-preview'),
          child: SizedBox(
            width: widget.size.width,
            height: widget.size.height,
            child: Transform.translate(
              key: const ValueKey('duck-jump-transform'),
              offset: Offset(0, _jumpOffset(jump) + flutter * 1.8),
              child: Transform.scale(
                key: const ValueKey('duck-jump-squash'),
                scaleX: 1 - stretch * 0.055 + landing * 0.08,
                scaleY: 1 + stretch * 0.09 - takeoff * 0.08 - landing * 0.13,
                alignment: Alignment.bottomCenter,
                child: Transform.rotate(
                  angle: flutter * 0.012,
                  alignment: Alignment.bottomCenter,
                  child: Stack(
                    children: [
                      if (_usePixelSprite)
                        Positioned.fill(
                          child: DuckSpriteWidget(
                            size: widget.size,
                            appearance: widget.appearance,
                            blink: widget.blink,
                            emotion: widget.emotion,
                          ),
                        )
                      else
                        CustomPaint(
                          size: widget.size,
                          painter: DuckPainter(
                            appearance: widget.appearance,
                            blink: widget.blink,
                            joy: widget.joy,
                            detailSeed: widget.detailSeed,
                            emotion: widget.emotion,
                          ),
                        ),
                      Positioned.fill(
                        child: CustomPaint(
                          key: const ValueKey('pixel-duck-hearts'),
                          painter: _PixelHeartBurstPainter(jump),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelHeartBurstPainter extends CustomPainter {
  const _PixelHeartBurstPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    const pattern = [
      [0, 1],
      [1, 0],
      [2, 0],
      [3, 1],
      [1, 2],
      [2, 2],
      [1, 3],
      [2, 3],
    ];
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height * 0.48);
    final colors = [
      const Color(0xFFE982A0),
      const Color(0xFFB55271),
      const Color(0xFFFFB7CA),
      const Color(0xFFD66E8B),
    ];
    for (var index = 0; index < colors.length; index++) {
      final angle = math.pi * 2 * index / colors.length - math.pi / 2;
      final distance = 14 + progress * 45;
      final pixel = 2.2;
      final origin =
          center +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance);
      final paint = Paint()
        ..color = colors[index].withValues(alpha: opacity)
        ..isAntiAlias = false;
      for (final cell in pattern) {
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + cell[0] * pixel,
            origin.dy + cell[1] * pixel,
            pixel,
            pixel,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelHeartBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: DuckOverlayWindow(),
    ),
  );
}

class DuckOverlayWindow extends StatefulWidget {
  const DuckOverlayWindow({super.key, this.pairRepository});

  final PairRepository? pairRepository;

  @override
  State<DuckOverlayWindow> createState() => _DuckOverlayWindowState();
}

class _DuckOverlayWindowState extends State<DuckOverlayWindow>
    with SingleTickerProviderStateMixin {
  late final PairRepository _pairRepository =
      widget.pairRepository ?? SharedPreferencesPairRepository();

  String _duckName = '';
  bool _isLoading = true;
  bool _isPaired = false;
  bool _isBlinking = false;
  int _detailSeed = math.Random().nextInt(1 << 31);
  int _duckJoyTrigger = 0;
  late final DuckBlinkTicker _blinkClock = DuckBlinkTicker(
    vsync: this,
    onBlink: (blinking) {
      if (mounted) setState(() => _isBlinking = blinking);
    },
  );

  @override
  void initState() {
    super.initState();
    _loadDuckName();
  }

  Future<void> _loadDuckName() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final activePair = await _pairRepository.loadActivePair();
    if (!mounted) return;
    if (activePair == null) {
      setState(() => _isLoading = false);
      return;
    }
    final defaultDuckName = AppLocalizations.of(context)!.defaultDuckName;
    setState(() {
      _isLoading = false;
      _isPaired = true;
      _duckName = preferences.getString('tamagotchi_name') ?? defaultDuckName;
    });
    _blinkClock.start();
  }

  void _onDuckTapped() {
    setState(() {
      _detailSeed = math.Random().nextInt(1 << 31);
      _duckJoyTrigger++;
    });
  }

  @override
  void dispose() {
    _blinkClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isPaired) return const SizedBox.shrink();
    final strings = AppLocalizations.of(context)!;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: 184,
          height: 184,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E8).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(92),
            border: Border.all(color: const Color(0xFFFFD967), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x406D4E1D),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DuckJoyReaction(
                trigger: _duckJoyTrigger,
                builder: (context, joy) => Transform.translate(
                  offset: Offset(0, -17 * joy * (1 - joy).abs()),
                  child: Transform.scale(
                    scale: 0.78 + 0.04 * joy,
                    child: DuckPetWidget(
                      size: const Size(150, 128),
                      semanticsLabel: strings.petSemantics,
                      onTap: _onDuckTapped,
                      blink: _isBlinking,
                      joy: joy,
                      detailSeed: _detailSeed,
                    ),
                  ),
                ),
              ),
              Text(
                _duckName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF70562A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
