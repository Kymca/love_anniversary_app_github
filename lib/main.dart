import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/tamagotchi_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/coupons_screen.dart';
import 'screens/secret_notes_screen.dart';
import 'screens/postcards_screen.dart';
import 'screens/pairs_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/roulette_screen.dart';
import 'models/app_release.dart';
import 'widgets/duck_mood.dart';
import 'widgets/app_update_banner.dart';
import 'models/coupon.dart';
import 'services/app_update_service.dart';
import 'services/app_sound_service.dart';
import 'services/coupon_repository.dart';
import 'services/duck_local_notification_service.dart';
import 'services/pair_push_registration_service.dart';
import 'services/pair_repository.dart';
import 'services/duck_ownership_repository.dart';
import 'services/duck_name_repository.dart';
import 'services/roulette_repository.dart';
import 'services/supabase_backend.dart';
import 'services/pair_email_auth_service.dart';
import 'services/supabase_coupon_repository.dart';
import 'services/supabase_duck_ownership_repository.dart';
import 'services/supabase_pair_repository.dart';
import 'services/supabase_roulette_repository.dart';
import 'services/unavailable_backend.dart';
import 'services/postcard_delivery_gateway.dart';
import 'services/postcard_push_gateway.dart';
import 'services/supabase_postcard_gateway.dart';
import 'services/participant_profile_repository.dart';
import 'services/mood_pair_repository.dart';
import 'services/supabase_mood_pair_repository.dart';
import 'services/telegram_coupon_notifier.dart';
import 'services/telegram_chat_service.dart';
import 'l10n/app_locale.dart';
import 'l10n/generated/app_localizations.dart';
import 'theme/app_theme.dart';
import 'widgets/random_memories_card.dart';

final relationshipStartDate = DateTime(2023, 11, 14);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await (await SharedPreferences.getInstance()).remove(
    'lan_postcard_config_v1',
  );
  SupabaseClient? backendClient;
  Object? backendError;
  try {
    backendClient = await initializeSupabase();
  } catch (error) {
    backendError = error;
  }
  final backendErrorMessage = backendError is AuthException
      ? 'Supabase authentication is unavailable.'
      : backendError?.toString() ?? 'Supabase is unavailable.';
  final couponClient = backendClient;
  final profiles = ParticipantProfileRepository();
  final pairRepository = backendClient == null
      ? UnavailablePairRepository(backendError ?? backendErrorMessage)
      : SupabasePairRepository(backendClient);
  final moodPairRepository = backendClient == null
      ? SharedPreferencesMoodPairRepository(profileRepository: profiles)
      : SupabaseMoodPairRepository(backendClient, pairRepository);
  runApp(
    LoveAnniversaryApp(
      couponRepositoryFactory: () async {
        final localRepository = await HiveCouponRepository.open();
        if (couponClient == null) return localRepository;
        return SupabaseCouponRepository(
          client: couponClient,
          pairRepository: pairRepository,
          fallback: localRepository,
        );
      },
      pairRepository: pairRepository,
      moodPairRepository: moodPairRepository,
      appUpdateService: backendClient == null
          ? null
          : SupabaseAppUpdateService(client: backendClient),
      pairEmailAuthService: backendClient == null
          ? null
          : SupabasePairEmailAuthService(backendClient.auth),
      duckNameRepository: backendClient == null
          ? UnavailableDuckNameRepository(backendErrorMessage)
          : SupabaseDuckNameRepository(backendClient),
      duckOwnershipRepository: backendClient == null
          ? UnavailableDuckOwnershipRepository(backendErrorMessage)
          : SupabaseDuckOwnershipRepository(
              client: backendClient,
              pairRepository: pairRepository,
              profileRepository: profiles,
            ),
      rouletteRepository: backendClient == null
          ? UnavailableRouletteRepository(backendErrorMessage)
          : SupabaseRouletteRepository(
              client: backendClient,
              activePairId: () async =>
                  (await pairRepository.loadActivePair())?.id,
            ),
      postcardDeliveryGateway: backendClient == null
          ? null
          : SupabasePostcardGateway(
              client: backendClient,
              pairRepository: pairRepository,
            ),
      postcardPushGateway: backendClient == null
          ? null
          : SupabasePostcardRealtimeGateway(backendClient),
    ),
  );
  if (backendClient != null) {
    unawaited(_initializePairPush(backendClient));
  }
}

Future<void> _initializePairPush(SupabaseClient client) async {
  try {
    await PairPushRegistrationService.initialize(client: client);
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'pair push registration',
        context: ErrorDescription('while initializing device notifications'),
      ),
    );
  }
}

class LoveAnniversaryApp extends StatefulWidget {
  const LoveAnniversaryApp({
    super.key,
    this.couponRepository,
    this.couponRepositoryFactory,
    this.couponNotifier,
    this.duckNotificationService,
    this.postcardDeliveryGateway,
    this.postcardPushGateway,
    this.pairRepository,
    this.moodPairRepository,
    this.pairEmailAuthService,
    this.duckNameRepository,
    this.duckOwnershipRepository,
    this.rouletteRepository,
    this.appUpdateService,
  });

  final CouponRepository? couponRepository;
  final Future<CouponRepository> Function()? couponRepositoryFactory;
  final CouponActivationNotifier? couponNotifier;
  final DuckLocalNotificationService? duckNotificationService;
  final PostcardDeliveryGateway? postcardDeliveryGateway;
  final PostcardPushGateway? postcardPushGateway;
  final PairRepository? pairRepository;
  final MoodPairRepository? moodPairRepository;
  final PairEmailAuthService? pairEmailAuthService;
  final DuckNameRepository? duckNameRepository;
  final DuckOwnershipService? duckOwnershipRepository;
  final RouletteRepository? rouletteRepository;
  final AppUpdateService? appUpdateService;

  @override
  State<LoveAnniversaryApp> createState() => _LoveAnniversaryAppState();
}

class _LoveAnniversaryAppState extends State<LoveAnniversaryApp> {
  Locale _locale = appSupportedLocales.first;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final locale = await loadSavedAppLocale();
    if (mounted) setState(() => _locale = locale);
  }

  Future<void> _setLocale(Locale locale) async {
    await saveAppLocale(locale);
    if (mounted) setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appSupportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _AppShell(
        couponRepository: widget.couponRepository,
        couponRepositoryFactory: widget.couponRepositoryFactory,
        couponNotifier: widget.couponNotifier,
        duckNotificationService: widget.duckNotificationService,
        postcardDeliveryGateway: widget.postcardDeliveryGateway,
        postcardPushGateway: widget.postcardPushGateway,
        pairRepository: widget.pairRepository,
        moodPairRepository: widget.moodPairRepository,
        pairEmailAuthService: widget.pairEmailAuthService,
        duckNameRepository: widget.duckNameRepository,
        duckOwnershipRepository: widget.duckOwnershipRepository,
        rouletteRepository: widget.rouletteRepository,
        appUpdateService: widget.appUpdateService,
        onLanguageChanged: _setLocale,
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({
    required this.couponRepository,
    required this.couponRepositoryFactory,
    required this.couponNotifier,
    required this.duckNotificationService,
    required this.postcardDeliveryGateway,
    required this.postcardPushGateway,
    required this.pairRepository,
    required this.moodPairRepository,
    required this.pairEmailAuthService,
    required this.duckNameRepository,
    required this.duckOwnershipRepository,
    required this.rouletteRepository,
    required this.appUpdateService,
    required this.onLanguageChanged,
  });

  final CouponRepository? couponRepository;
  final Future<CouponRepository> Function()? couponRepositoryFactory;
  final CouponActivationNotifier? couponNotifier;
  final DuckLocalNotificationService? duckNotificationService;
  final PostcardDeliveryGateway? postcardDeliveryGateway;
  final PostcardPushGateway? postcardPushGateway;
  final PairRepository? pairRepository;
  final MoodPairRepository? moodPairRepository;
  final PairEmailAuthService? pairEmailAuthService;
  final DuckNameRepository? duckNameRepository;
  final DuckOwnershipService? duckOwnershipRepository;
  final RouletteRepository? rouletteRepository;
  final AppUpdateService? appUpdateService;
  final Future<void> Function(Locale locale) onLanguageChanged;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;
  int _messengerEventId = 0;
  int _pairRevision = 0;
  DuckPartnerSide _partnerSide = DuckPartnerSide.first;
  String? _duckTabName;
  AppRelease? _availableUpdate;
  bool _isInstallingUpdate = false;
  late final PairRepository _pairRepository =
      widget.pairRepository ?? SharedPreferencesPairRepository();
  late final MoodPairRepository _moodPairRepository =
      widget.moodPairRepository ??
      SharedPreferencesMoodPairRepository(
        profileRepository: _participantProfiles,
      );
  late final DuckNameRepository _duckNameRepository =
      widget.duckNameRepository ?? SharedPreferencesDuckNameRepository();
  late final DuckLocalNotificationService _duckNotificationService =
      widget.duckNotificationService ?? DuckLocalNotificationService();
  late final DuckOwnershipService _duckOwnershipRepository =
      widget.duckOwnershipRepository ??
      DuckOwnershipRepository(profileRepository: _participantProfiles);
  late final ParticipantProfileRepository _participantProfiles =
      ParticipantProfileRepository();

  @override
  void initState() {
    super.initState();
    _loadParticipantSide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForAppUpdateAutomatically());
    });
  }

  Future<void> _checkForAppUpdateAutomatically() async {
    try {
      await _checkForAppUpdate();
    } catch (_) {
      // The error is reported by _checkForAppUpdate.
    }
  }

  Future<AppRelease?> _checkForAppUpdate() async {
    final service = widget.appUpdateService;
    if (service == null) return null;
    try {
      final release = await service.checkForUpdate();
      if (mounted) setState(() => _availableUpdate = release);
      return release;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app updater',
          context: ErrorDescription('while checking for an Android update'),
        ),
      );
      rethrow;
    }
  }

  Future<void> _installAppUpdate() async {
    final service = widget.appUpdateService;
    final release = _availableUpdate;
    if (service == null || release == null || _isInstallingUpdate) return;

    setState(() => _isInstallingUpdate = true);
    try {
      await service.installUpdate(release);
    } on AppInstallPermissionRequired {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.appUpdatePermissionHint,
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app updater',
          context: ErrorDescription('while downloading or installing an APK'),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.appUpdateFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInstallingUpdate = false);
    }
  }

  Future<void> _loadParticipantSide() async {
    final side = await _participantProfiles.loadCurrentSide();
    if (!mounted) return;
    setState(() {
      _partnerSide = side == 'second'
          ? DuckPartnerSide.second
          : DuckPartnerSide.first;
      _pairRevision++;
    });
  }

  void _onPairUpdated() => _loadParticipantSide();

  void _onDuckNameChanged(String? name) {
    if (_duckTabName == name) return;
    setState(() => _duckTabName = name);
  }

  void _selectPage(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  void _showCouponMessenger() {
    HapticFeedback.selectionClick();
    setState(() {
      _messengerEventId++;
      _selectedIndex = 1;
    });
  }

  Future<void> _onCouponActivated(Coupon coupon) async {
    _showCouponMessenger();
    try {
      await _duckNotificationService.notifyCouponActivated(coupon);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'local coupon notification',
          context: ErrorDescription(
            'while notifying about an activated coupon',
          ),
        ),
      );
    }
    unawaited(AppSoundService.play(AppSoundEvent.couponActivated));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return AppGradientBackground(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_availableUpdate case final release?)
                AppUpdateBanner(
                  release: release,
                  isInstalling: _isInstallingUpdate,
                  onInstall: _installAppUpdate,
                  onDismiss: () => setState(() => _availableUpdate = null),
                ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _TabTransition(
                      active: _selectedIndex == 0,
                      child: AnniversaryHomePage(
                        onOpenDuck: () => _selectPage(1),
                        onOpenPairs: () => _selectPage(6),
                        onLanguageChanged: widget.onLanguageChanged,
                        onParticipantNameChanged: _onPairUpdated,
                        pairRepository: _pairRepository,
                        isActive: _selectedIndex == 0,
                      ),
                    ),
                    _TabTransition(
                      active: _selectedIndex == 1,
                      child: TamagotchiScreen(
                        messengerEventId: _messengerEventId,
                        pairRepository: _pairRepository,
                        pairRevision: _pairRevision,
                        onOpenPairs: () => _selectPage(6),
                        onDuckNameChanged: _onDuckNameChanged,
                        partnerSide: _partnerSide,
                        isActive: _selectedIndex == 1,
                        duckNameRepository: _duckNameRepository,
                        moodPairRepository: _moodPairRepository,
                        ownershipRepository: _duckOwnershipRepository,
                      ),
                    ),
                    _TabTransition(
                      active: _selectedIndex == 2,
                      child: const MemoriesScreen(),
                    ),
                    _TabTransition(
                      active: _selectedIndex == 3,
                      child: CouponsScreen(
                        repository: widget.couponRepository,
                        repositoryFactory: widget.couponRepositoryFactory,
                        notifier: widget.couponNotifier,
                        onActivated: _onCouponActivated,
                        pairRevision: _pairRevision,
                        isActive: _selectedIndex == 3,
                      ),
                    ),
                    _TabTransition(
                      active: _selectedIndex == 4,
                      child: SecretNotesScreen(
                        deliveryGateway: widget.postcardDeliveryGateway,
                        pushGateway: widget.postcardPushGateway,
                        moodPairRepository: _moodPairRepository,
                        pairRepository: _pairRepository,
                        isActive: _selectedIndex == 4,
                      ),
                    ),
                    _TabTransition(
                      active: _selectedIndex == 5,
                      child: PostcardsScreen(
                        deliveryGateway: widget.postcardDeliveryGateway,
                        pushGateway: widget.postcardPushGateway,
                        isActive: _selectedIndex == 5,
                      ),
                    ),
                    _TabTransition(
                      active: _selectedIndex == 6,
                      child: PairsScreen(
                        repository: _pairRepository,
                        profileRevision: _pairRevision,
                        onPairUpdated: _onPairUpdated,
                      ),
                    ),
                    _TabTransition(
                      active: _selectedIndex == 7,
                      child: RouletteScreen(
                        repository: widget.rouletteRepository,
                        pairRevision: _pairRevision,
                        isActive: _selectedIndex == 7,
                      ),
                    ),
                    _TabTransition(
                      active: _selectedIndex == 8,
                      child: SettingsScreen(
                        authService: widget.pairEmailAuthService,
                        onAuthChanged: _onPairUpdated,
                        onCheckForUpdate: widget.appUpdateService == null
                            ? null
                            : _checkForAppUpdate,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            radius: 26,
            child: SizedBox(
              key: const ValueKey('main-navigation'),
              height: 62,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      height: 62,
                      child: _NavigationDestination(
                        selected: _selectedIndex == 0,
                        icon: Icons.favorite_rounded,
                        label: localizations.homeTab,
                        onTap: () => _selectPage(0),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 62,
                      child: _NavigationDestination(
                        selected: _selectedIndex == 1,
                        icon: Icons.pets_rounded,
                        label: _duckTabName ?? localizations.petTab,
                        onTap: () => _selectPage(1),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 62,
                      child: _NavigationDestination(
                        selected: _selectedIndex == 2,
                        icon: Icons.photo_library_rounded,
                        label: localizations.memoriesTab,
                        onTap: () => _selectPage(2),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 62,
                      child: _NavigationDestination(
                        selected: _selectedIndex == 3,
                        icon: Icons.card_giftcard_rounded,
                        label: localizations.couponsTab,
                        onTap: () => _selectPage(3),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 62,
                      child: _NavigationDestination(
                        selected: _selectedIndex == 4,
                        icon: Icons.lock_rounded,
                        label: localizations.notesTab,
                        onTap: () => _selectPage(4),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 62,
                      child: _NavigationDestination(
                        selected: _selectedIndex == 5,
                        icon: Icons.mail_rounded,
                        label: localizations.postcardsTab,
                        onTap: () => _selectPage(5),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 62,
                      child: _NavigationDestination(
                        selected: _selectedIndex == 7,
                        icon: Icons.casino_rounded,
                        label: localizations.rouletteTab,
                        onTap: () => _selectPage(7),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      height: 62,
                      child: _NavigationDestination(
                        selected: _selectedIndex == 8,
                        icon: Icons.settings_rounded,
                        label: localizations.settingsTab,
                        onTap: () => _selectPage(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabTransition extends StatelessWidget {
  const _TabTransition({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: active ? 1 : 0,
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOut,
    child: AnimatedSlide(
      offset: active ? Offset.zero : const Offset(0, 0.025),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: child,
    ),
  );
}

class _NavigationDestination extends StatelessWidget {
  const _NavigationDestination({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        key: ValueKey('navigation-$label'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.rose.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.rose : AppColors.mutedInk,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.roseDeep : AppColors.mutedInk,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnniversaryHomePage extends StatefulWidget {
  const AnniversaryHomePage({
    super.key,
    this.onOpenDuck,
    this.onOpenPairs,
    this.onLanguageChanged,
    this.onParticipantNameChanged,
    this.profileRepository,
    this.pairRepository,
    this.memoryService,
    this.isActive = true,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final VoidCallback? onOpenDuck;
  final VoidCallback? onOpenPairs;
  final Future<void> Function(Locale locale)? onLanguageChanged;
  final VoidCallback? onParticipantNameChanged;
  final ParticipantProfileRepository? profileRepository;
  final PairRepository? pairRepository;
  final TelegramChatService? memoryService;
  final bool isActive;
  final DateTime Function() clock;

  @override
  State<AnniversaryHomePage> createState() => _AnniversaryHomePageState();
}

class _AnniversaryHomePageState extends State<AnniversaryHomePage> {
  late DateTime _now;
  late final ParticipantProfileRepository _profileRepository =
      widget.profileRepository ?? ParticipantProfileRepository();
  late final PairRepository _pairRepository =
      widget.pairRepository ?? SharedPreferencesPairRepository();
  String? _participantName;
  String _participantSide = 'first';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = widget.clock();
    _loadParticipantName();
    _updateClockActivity();
  }

  @override
  void didUpdateWidget(covariant AnniversaryHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) _updateClockActivity();
  }

  void _updateClockActivity() {
    _timer?.cancel();
    if (!widget.isActive) return;
    _now = widget.clock();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = widget.clock());
    });
  }

  Future<void> _loadParticipantName() async {
    final side = await _profileRepository.loadCurrentSide();
    final pair = await _pairRepository.loadActivePair();
    final names = await _profileRepository.loadNames(pair: pair);
    if (mounted) {
      setState(() {
        _participantSide = side;
        _participantName = names[side];
      });
    }
  }

  Future<void> _editParticipantName() async {
    final strings = AppLocalizations.of(context)!;
    final nameFieldKey = GlobalKey<FormFieldState<String>>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.editParticipantName),
        content: TextFormField(
          key: nameFieldKey,
          initialValue: _participantName ?? '',
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: strings.yourName),
          onFieldSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(nameFieldKey.currentState?.value),
            child: Text(strings.save),
          ),
        ],
      ),
    );
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty || !mounted) return;
    await _profileRepository.saveName(_participantSide, trimmedName);
    if (!mounted) return;
    setState(() => _participantName = trimmedName);
    widget.onParticipantNameChanged?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = RelationshipDuration.since(relationshipStartDate, _now);
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: localizations.openPairs,
                    child: Tooltip(
                      message: localizations.openPairs,
                      child: InkWell(
                        key: const ValueKey('home-pairs-bubble'),
                        onTap: widget.onOpenPairs,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE9B7C7)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1C8F5266),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.people_alt_rounded,
                            color: Color(0xFF9B536A),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        SegmentedButton<String>(
                          key: const ValueKey('language-selector'),
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment<String>(
                              value: 'ru',
                              label: const Text('RU'),
                              tooltip: localizations.russian,
                            ),
                            ButtonSegment<String>(
                              value: 'uk',
                              label: const Text('UK'),
                              tooltip: localizations.ukrainian,
                            ),
                          ],
                          selected: {
                            Localizations.localeOf(context).languageCode,
                          },
                          onSelectionChanged: (selection) {
                            final update = widget.onLanguageChanged;
                            if (update != null && selection.isNotEmpty) {
                              unawaited(update(Locale(selection.first)));
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.onOpenDuck,
                          icon: const Icon(Icons.pets_rounded),
                          label: Text(localizations.duckShortcut),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('home-profile-name'),
                onPressed: _editParticipantName,
                icon: Icon(
                  _participantName == null
                      ? Icons.person_add_alt_1_rounded
                      : Icons.edit_rounded,
                ),
                label: Text(_participantName ?? localizations.yourName),
              ),
              const SizedBox(height: 10),
              RomanticTap(
                semanticsLabel: localizations.sendHeart,
                onTap: HapticFeedback.selectionClick,
                child: _PulsingHeart(isActive: widget.isActive),
              ),
              const SizedBox(height: 22),
              Text(
                localizations.homeEyebrow,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF9B536A),
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                localizations.homeHeadline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF542B3A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localizations.relationshipStarted,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF916A78),
                ),
              ),
              const SizedBox(height: 28),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _TimeCard(
                            value: elapsed.years,
                            label: localizations.durationYears(elapsed.years),
                            prominent: true,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _TimeCard(
                            value: elapsed.months,
                            label: localizations.durationMonths(elapsed.months),
                            prominent: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeCard(
                            value: elapsed.days,
                            label: localizations.durationDays(elapsed.days),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeCard(
                            value: elapsed.hours,
                            label: localizations.durationHours(elapsed.hours),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeCard(
                            value: elapsed.minutes,
                            label: localizations.durationMinutes(
                              elapsed.minutes,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeCard(
                            value: elapsed.seconds,
                            label: localizations.durationSeconds(
                              elapsed.seconds,
                            ),
                            key: const ValueKey('seconds-card'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              RandomMemoriesCard(service: widget.memoryService),
              const SizedBox(height: 24),
              Text(
                localizations.beginning,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF9B536A),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingHeart extends StatefulWidget {
  const _PulsingHeart({required this.isActive});

  final bool isActive;

  @override
  State<_PulsingHeart> createState() => _PulsingHeartState();
}

class _PulsingHeartState extends State<_PulsingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.94,
    upperBound: 1.06,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller,
      key: const ValueKey('home-pulsing-heart-scale'),
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.78),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33B63D68),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(
          Icons.favorite_rounded,
          size: 44,
          color: Color(0xFFC5416C),
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    super.key,
    required this.value,
    required this.label,
    this.prominent = false,
  });

  final int value;
  final String label;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final color = prominent ? const Color(0xFF8F3154) : const Color(0xFF623748);

    return GlassCard(
      padding: EdgeInsets.symmetric(
        vertical: prominent ? 20 : 16,
        horizontal: 8,
      ),
      radius: 21,
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.18),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: TextStyle(
                color: color,
                fontSize: prominent ? 42 : 27,
                height: 1.05,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.78),
                fontSize: prominent ? 14 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RelationshipDuration {
  const RelationshipDuration({
    required this.years,
    required this.months,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  final int years;
  final int months;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  factory RelationshipDuration.since(DateTime start, DateTime now) {
    if (!now.isAfter(start)) {
      return const RelationshipDuration(
        years: 0,
        months: 0,
        days: 0,
        hours: 0,
        minutes: 0,
        seconds: 0,
      );
    }

    var anchor = start;
    var years = now.year - anchor.year;
    var candidate = DateTime(
      start.year + years,
      start.month,
      start.day,
      start.hour,
      start.minute,
      start.second,
    );
    if (candidate.isAfter(now)) {
      years--;
      candidate = DateTime(
        start.year + years,
        start.month,
        start.day,
        start.hour,
        start.minute,
        start.second,
      );
    }
    anchor = candidate;

    var months = (now.year - anchor.year) * 12 + now.month - anchor.month;
    candidate = DateTime(
      anchor.year,
      anchor.month + months,
      anchor.day,
      anchor.hour,
      anchor.minute,
      anchor.second,
    );
    if (candidate.isAfter(now)) {
      months--;
      candidate = DateTime(
        anchor.year,
        anchor.month + months,
        anchor.day,
        anchor.hour,
        anchor.minute,
        anchor.second,
      );
    }
    anchor = candidate;

    var remainder = now.difference(anchor);
    final days = remainder.inDays;
    remainder -= Duration(days: days);
    final hours = remainder.inHours;
    remainder -= Duration(hours: hours);
    final minutes = remainder.inMinutes;
    remainder -= Duration(minutes: minutes);

    return RelationshipDuration(
      years: years,
      months: months,
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: remainder.inSeconds,
    );
  }
}
