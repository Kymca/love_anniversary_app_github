import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/pair_room.dart';
import 'package:love_anniversary_app/screens/pairs_screen.dart';
import 'package:love_anniversary_app/services/pair_repository.dart';
import 'package:love_anniversary_app/services/participant_profile_repository.dart';
import 'package:love_anniversary_app/services/unavailable_backend.dart';
import 'package:love_anniversary_app/screens/settings_screen.dart';
import 'package:love_anniversary_app/services/pair_email_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('in-memory repository creates a unique four-digit pair code', () async {
    final repository = InMemoryPairRepository();
    final first = await repository.createPair('  Алина ');
    final second = await repository.createPair('Саша');

    expect(first.code, matches(RegExp(r'^\d{4}$')));
    expect(second.code, matches(RegExp(r'^\d{4}$')));
    expect(second.code, isNot(first.code));
    expect(first.members.single.name, 'Алина');
    expect(first.members, hasLength(1));
    expect((await repository.loadActivePair())?.code, second.code);
  });

  test('joining validates name and code and creates two-member room', () async {
    final repository = InMemoryPairRepository();
    final room = await repository.createPair('Алина');

    await expectLater(
      repository.createPair('  '),
      throwsA(isA<PairRepositoryException>()),
    );
    await expectLater(
      repository.joinPair('', room.code),
      throwsA(isA<PairRepositoryException>()),
    );
    await expectLater(
      repository.joinPair('Саша', '12'),
      throwsA(isA<PairRepositoryException>()),
    );
    await expectLater(
      repository.joinPair('Саша', '0000'),
      throwsA(isA<PairRepositoryException>()),
    );

    final joined = await repository.joinPair('Саша', room.code);
    expect(joined.members.map((member) => member.name), ['Алина', 'Саша']);
    expect((await repository.loadActivePair())?.code, room.code);
    await expectLater(
      repository.joinPair('Кто-то ещё', room.code),
      throwsA(isA<PairRepositoryException>()),
    );
  });

  test('shared-preferences repository restores local room state', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final firstRepository = SharedPreferencesPairRepository(
      preferences: preferences,
    );
    final created = await firstRepository.createPair('Алина');
    final secondRepository = SharedPreferencesPairRepository(
      preferences: preferences,
    );

    final found = await secondRepository.findPair(created.code);
    expect(found?.members.single.name, 'Алина');
    expect((await secondRepository.loadActivePair())?.code, created.code);
    final joined = await secondRepository.joinPair('Саша', created.code);
    expect(joined.members, hasLength(2));
    final profiles = ParticipantProfileRepository(preferences: preferences);
    await profiles.saveCurrentSide('second');
    expect(
      await ParticipantProfileRepository(preferences: preferences)
          .loadCurrentSide(),
      'second',
    );
    expect(
      (await firstRepository.findPair(created.code))?.members.last.name,
      'Саша',
    );
  });

  test('pair participant names override stale local profile names', () async {
    final preferences = await SharedPreferences.getInstance();
    final profiles = ParticipantProfileRepository(preferences: preferences);
    await profiles.saveName('first', 'Старое имя 1');
    await profiles.saveName('second', 'Старое имя 2');

    final names = await profiles.loadNames(
      pair: const PairRoom(
        id: 'one-shared-pair',
        code: '1234',
        members: [
          PairMember(name: 'Алина'),
          PairMember(name: 'Руслан'),
        ],
      ),
    );

    expect(names, {'first': 'Алина', 'second': 'Руслан'});
    expect(
      preferences.getString(ParticipantProfileRepository.firstNameKey),
      'Алина',
    );
    expect(
      preferences.getString(ParticipantProfileRepository.secondNameKey),
      'Руслан',
    );
  });

  testWidgets('pair screen creates and shares code then allows joining', (
    tester,
  ) async {
    final repository = InMemoryPairRepository();
    final preferences = await SharedPreferences.getInstance();
    final profileRepository = ParticipantProfileRepository(
      preferences: preferences,
    );
    await profileRepository.saveName('first', 'Алина');
    await profileRepository.saveName('second', 'Саша');
    await tester.pumpWidget(
      localizedTestApp(
        home: PairsScreen(
          repository: repository,
          profileRepository: profileRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.tap(find.text('Создать пару'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Код пары').last, findsOneWidget);
    final code = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data;
    expect(code, matches(RegExp(r'^\d{4}$')));
    await tester.tap(find.text('Готово'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).last, code!);
    await tester.tap(find.text('Присоединиться'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ваша пара'), findsOneWidget);
    expect(find.text('Алина'), findsWidgets);
    expect(find.widgetWithText(ListTile, 'Саша'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('anonymous auth setup error is localized without raw details', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final profileRepository = ParticipantProfileRepository(
      preferences: preferences,
    );
    await profileRepository.saveName('first', 'Алина');
    await tester.pumpWidget(
      localizedTestApp(
        locale: const Locale('uk'),
        home: PairsScreen(
          repository: UnavailablePairRepository(
            const AuthApiException(
              'Anonymous sign-ins are disabled',
              code: 'anonymous_provider_disabled',
            ),
          ),
          profileRepository: profileRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Створити пару'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Щоб створити пару, увімкніть анонімні входи в Supabase: '
        'Auth > Sign In / Providers > Anonymous Sign-Ins.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('AuthApiException'), findsNothing);
    expect(
      find.textContaining('Anonymous sign-ins are disabled'),
      findsNothing,
    );
  });

  testWidgets('settings completes email OTP flow and notifies the app', (
    tester,
  ) async {
    final auth = FakePairEmailAuthService();
    var authChanged = false;
    await tester.pumpWidget(
      localizedTestApp(
        home: SettingsScreen(
          authService: auth,
          onAuthChanged: () => authChanged = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Создать аккаунт / войти по email-коду'), findsOneWidget);
    expect(
      find.text(
        'Подтверждать почту необязательно для создания пары или вступления '
        'в неё.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Подключите email-код, чтобы создать аккаунт или войти с другого '
        'устройства. Подтверждение почты не требуется для создания пары или '
        'вступления в неё.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Электронная почта'),
      'person@example.com',
    );
    await tester.tap(find.text('Отправить код'));
    await tester.pumpAndSettle();
    expect(auth.sentEmail, 'person@example.com');
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Электронная почта'),
          )
          .enabled,
      isTrue,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Электронная почта'),
      'corrected@example.com',
    );
    await tester.pumpAndSettle();
    expect(auth.clearedPendingCodeCount, 1);
    expect(find.text('Код из письма'), findsNothing);
    await tester.tap(find.text('Отправить код'));
    await tester.pumpAndSettle();
    expect(auth.sentEmail, 'corrected@example.com');

    await tester.enterText(
      find.widgetWithText(TextField, 'Код из письма'),
      '123456',
    );
    await tester.tap(find.text('Подтвердить email'));
    await tester.pumpAndSettle();
    expect(auth.isEmailVerified, isTrue);
    expect(authChanged, isTrue);
    expect(find.text('Почта привязана: corrected@example.com'), findsOneWidget);
    expect(find.text('Отправить код'), findsNothing);
  });

  testWidgets('settings shows bound-email copy in Ukrainian', (tester) async {
    final auth = FakePairEmailAuthService(isEmailVerified: true)
      ..email = 'user@example.com';
    await tester.pumpWidget(
      localizedTestApp(
        locale: const Locale('uk'),
        home: SettingsScreen(authService: auth),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Налаштування'), findsOneWidget);
    expect(find.text("Пошту прив'язано: user@example.com"), findsOneWidget);
  });

  testWidgets('settings exposes send-code API errors and reports them', (
    tester,
  ) async {
    final previousErrorHandler = FlutterError.onError;
    final reportedErrors = <FlutterErrorDetails>[];
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = previousErrorHandler);
    final auth = FakePairEmailAuthService(
      sendError: const AuthApiException(
        'Email rate limit exceeded',
        code: 'over_email_send_rate_limit',
        statusCode: '429',
      ),
    );
    await tester.pumpWidget(
      localizedTestApp(home: SettingsScreen(authService: auth)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Электронная почта'),
      'person@example.com',
    );
    await tester.tap(find.text('Отправить код'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Supabase временно ограничил отправку писем. Код не был отправлен. '
        'Не повторяйте запросы — дождитесь обновления лимита. Если это '
        'происходит часто, владелец проекта может настроить собственный '
        'SMTP или Send Email Hook.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('проверьте адрес и код'), findsNothing);
    expect(reportedErrors, hasLength(1));
    expect(reportedErrors.single.library, 'Supabase email OTP send OTP');
  });

  testWidgets('anonymous user can create and join without email verification', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final profiles = ParticipantProfileRepository(preferences: preferences);
    await profiles.saveName('first', 'Алина');
    await tester.pumpWidget(
      localizedTestApp(
        home: PairsScreen(
          repository: InMemoryPairRepository(),
          profileRepository: profiles,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Создать пару'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Присоединиться'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Создать пару'));
    await tester.pumpAndSettle();
    expect(find.text('Код пары'), findsNWidgets(2));
    final code = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, code);
    await tester.tap(find.text('Присоединиться'));
    await tester.pumpAndSettle();
    expect(find.text('Ваша пара'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified user can enter a name inline before creating a pair', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final profiles = ParticipantProfileRepository(preferences: preferences);
    final repository = InMemoryPairRepository();
    await tester.pumpWidget(
      localizedTestApp(
        home: PairsScreen(repository: repository, profileRepository: profiles),
      ),
    );
    await tester.pumpAndSettle();

    final createButton = find.widgetWithText(FilledButton, 'Создать пару');
    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect(find.text('Введите имя участника.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ваше имя'), 'Алина');
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect((await repository.loadActivePair())?.members.single.name, 'Алина');
    expect(find.text('Код пары'), findsNWidgets(2));
  });

  testWidgets('breaking a pair requires confirmation and clears active pair', (
    tester,
  ) async {
    final repository = InMemoryPairRepository();
    await repository.createPair('Алина');
    final preferences = await SharedPreferences.getInstance();
    final profiles = ParticipantProfileRepository(preferences: preferences);
    await profiles.saveName('first', 'Алина');
    await tester.pumpWidget(
      localizedTestApp(
        home: PairsScreen(repository: repository, profileRepository: profiles),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ваша пара'), findsOneWidget);

    await tester.ensureVisible(find.text('Разорвать пару'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Разорвать пару'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Пара и все её общие данные будут удалены без возможности '
        'восстановления. Ваш аккаунт останется активным.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect((await repository.loadActivePair())?.code, isNotNull);

    await tester.ensureVisible(find.text('Разорвать пару'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Разорвать пару'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить пару и данные'));
    await tester.pumpAndSettle();
    expect(await repository.loadActivePair(), isNull);
    expect(find.text('Ваша пара'), findsNothing);
  });

  testWidgets(
    'settings email confirmation callback leaves pair access enabled',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final profiles = ParticipantProfileRepository(preferences: preferences);
      await profiles.saveName('first', 'Алина');
      final auth = FakePairEmailAuthService();
      await tester.pumpWidget(
        localizedTestApp(
          home: _SettingsAndPairsHarness(
            authService: auth,
            profileRepository: profiles,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Электронная почта'),
        'person@example.com',
      );
      await tester.tap(find.text('Отправить код'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Код из письма'),
        '123456',
      );
      await tester.tap(find.text('Подтвердить email'));
      await tester.pumpAndSettle();

      expect(auth.isEmailVerified, isTrue);
      final createButton = find.widgetWithText(FilledButton, 'Создать пару');
      expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
    },
  );

  test('pair room model rejects malformed persisted data', () {
    expect(
      () => PairRoom.fromJson({'code': '123', 'members': <Object?>[]}),
      throwsFormatException,
    );
  });
}

class FakePairEmailAuthService implements PairEmailAuthService {
  FakePairEmailAuthService({this.isEmailVerified = false, this.sendError});

  @override
  bool isEmailVerified;

  @override
  String? email;

  String? sentEmail;
  int clearedPendingCodeCount = 0;
  final Object? sendError;

  @override
  Future<void> sendCode(String email) async {
    final error = sendError;
    if (error != null) throw error;
    sentEmail = email.trim().toLowerCase();
    this.email = sentEmail;
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    if (email != sentEmail || code != '123456') {
      throw const FormatException('Invalid test OTP.');
    }
    isEmailVerified = true;
  }

  @override
  void clearPendingCode() {
    clearedPendingCodeCount++;
    sentEmail = null;
  }
}

class _SettingsAndPairsHarness extends StatefulWidget {
  const _SettingsAndPairsHarness({
    required this.authService,
    required this.profileRepository,
  });

  final FakePairEmailAuthService authService;
  final ParticipantProfileRepository profileRepository;

  @override
  State<_SettingsAndPairsHarness> createState() =>
      _SettingsAndPairsHarnessState();
}

class _SettingsAndPairsHarnessState extends State<_SettingsAndPairsHarness> {
  int _revision = 0;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: _selectedIndex,
    children: [
      SettingsScreen(
        authService: widget.authService,
        onAuthChanged: () => setState(() {
          _revision++;
          _selectedIndex = 1;
        }),
      ),
      PairsScreen(
        repository: InMemoryPairRepository(),
        profileRepository: widget.profileRepository,
        profileRevision: _revision,
      ),
    ],
  );
}
