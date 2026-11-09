import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кохання'**
  String get appTitle;

  /// No description provided for @homeTab.
  ///
  /// In ru, this message translates to:
  /// **'Наша история'**
  String get homeTab;

  /// No description provided for @petTab.
  ///
  /// In ru, this message translates to:
  /// **'Тамагочи'**
  String get petTab;

  /// No description provided for @memoriesTab.
  ///
  /// In ru, this message translates to:
  /// **'Воспоминания'**
  String get memoriesTab;

  /// No description provided for @couponsTab.
  ///
  /// In ru, this message translates to:
  /// **'Купоны'**
  String get couponsTab;

  /// No description provided for @notesTab.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get notesTab;

  /// No description provided for @pairsTab.
  ///
  /// In ru, this message translates to:
  /// **'Пары'**
  String get pairsTab;

  /// No description provided for @rouletteTab.
  ///
  /// In ru, this message translates to:
  /// **'Рулетка'**
  String get rouletteTab;

  /// No description provided for @duckShortcut.
  ///
  /// In ru, this message translates to:
  /// **'Наша уточка'**
  String get duckShortcut;

  /// No description provided for @sendHeart.
  ///
  /// In ru, this message translates to:
  /// **'Отправить сердечко'**
  String get sendHeart;

  /// No description provided for @homeEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'НАША ИСТОРИЯ'**
  String get homeEyebrow;

  /// No description provided for @homeHeadline.
  ///
  /// In ru, this message translates to:
  /// **'Вместе — с каждым мгновением'**
  String get homeHeadline;

  /// No description provided for @couponTitle.
  ///
  /// In ru, this message translates to:
  /// **'Купоны на желания'**
  String get couponTitle;

  /// No description provided for @couponSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Маленькие радости, которые можно активировать'**
  String get couponSubtitle;

  /// No description provided for @couponLoading.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем купоны…'**
  String get couponLoading;

  /// No description provided for @couponLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить купоны.'**
  String get couponLoadError;

  /// No description provided for @couponRetry.
  ///
  /// In ru, this message translates to:
  /// **'Попробовать снова'**
  String get couponRetry;

  /// No description provided for @couponEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет купонов'**
  String get couponEmptyTitle;

  /// No description provided for @couponEmptyDescription.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся ваши желания и сюрпризы.'**
  String get couponEmptyDescription;

  /// No description provided for @couponNotificationNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Внешние уведомления не настроены.'**
  String get couponNotificationNotConfigured;

  /// No description provided for @couponActivationError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить активацию купона.'**
  String get couponActivationError;

  /// No description provided for @couponScratchHint.
  ///
  /// In ru, this message translates to:
  /// **'Проведи пальцем, чтобы стереть'**
  String get couponScratchHint;

  /// No description provided for @couponActivate.
  ///
  /// In ru, this message translates to:
  /// **'Активировать'**
  String get couponActivate;

  /// No description provided for @couponUsed.
  ///
  /// In ru, this message translates to:
  /// **'Уже использован'**
  String get couponUsed;

  /// No description provided for @couponMonthly.
  ///
  /// In ru, this message translates to:
  /// **'Можно раз в месяц'**
  String get couponMonthly;

  /// No description provided for @couponOneTime.
  ///
  /// In ru, this message translates to:
  /// **'Одноразовый'**
  String get couponOneTime;

  /// No description provided for @couponDaily.
  ///
  /// In ru, this message translates to:
  /// **'Ежедневный купон'**
  String get couponDaily;

  /// No description provided for @dailyCouponTitle.
  ///
  /// In ru, this message translates to:
  /// **'Маленькое желание дня'**
  String get dailyCouponTitle;

  /// No description provided for @dailyCouponDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выбери приятный сюрприз для нас сегодня.'**
  String get dailyCouponDescription;

  /// No description provided for @dailyCouponExpired.
  ///
  /// In ru, this message translates to:
  /// **'Срок этого дневного купона истёк'**
  String get dailyCouponExpired;

  /// No description provided for @couponCallbackError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить действие купона.'**
  String get couponCallbackError;

  /// No description provided for @couponNotificationWarning.
  ///
  /// In ru, this message translates to:
  /// **'Купон активирован, но уведомление не удалось показать.'**
  String get couponNotificationWarning;

  /// No description provided for @notificationDenied.
  ///
  /// In ru, this message translates to:
  /// **'Купон активирован. Локальные уведомления отключены или недоступны.'**
  String get notificationDenied;

  /// No description provided for @notificationFailure.
  ///
  /// In ru, this message translates to:
  /// **'Купон активирован. Не удалось показать локальное уведомление.'**
  String get notificationFailure;

  /// No description provided for @overlayPetTapHint.
  ///
  /// In ru, this message translates to:
  /// **'Коснитесь уточки, чтобы порадовать её'**
  String get overlayPetTapHint;

  /// No description provided for @pairCreateError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать пару: {error}'**
  String pairCreateError(Object error);

  /// No description provided for @relationshipStarted.
  ///
  /// In ru, this message translates to:
  /// **'С 13 ноября 2023 года • 20:30'**
  String get relationshipStarted;

  /// No description provided for @beginning.
  ///
  /// In ru, this message translates to:
  /// **'И это только начало ♥'**
  String get beginning;

  /// No description provided for @couponActivatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Купон активирован! Уточка несёт тебе радость!'**
  String get couponActivatedMessage;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @russian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get russian;

  /// No description provided for @ukrainian.
  ///
  /// In ru, this message translates to:
  /// **'Українська'**
  String get ukrainian;

  /// No description provided for @durationYears.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} год} few{{count} года} many{{count} лет} other{{count} лет}}'**
  String durationYears(int count);

  /// No description provided for @durationMonths.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} месяц} few{{count} месяца} many{{count} месяцев} other{{count} месяцев}}'**
  String durationMonths(int count);

  /// No description provided for @durationDays.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} день} few{{count} дня} many{{count} дней} other{{count} дней}}'**
  String durationDays(int count);

  /// No description provided for @durationHours.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} час} few{{count} часа} many{{count} часов} other{{count} часов}}'**
  String durationHours(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} минута} few{{count} минуты} many{{count} минут} other{{count} минут}}'**
  String durationMinutes(int count);

  /// No description provided for @durationSeconds.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} секунда} few{{count} секунды} many{{count} секунд} other{{count} секунд}}'**
  String durationSeconds(int count);

  /// No description provided for @nameDuckTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как назовём уточку? 🦆'**
  String get nameDuckTitle;

  /// No description provided for @participantNameTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как зовут участников?'**
  String get participantNameTitle;

  /// No description provided for @participantNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя участника {number}'**
  String participantNameLabel(int number);

  /// No description provided for @participantNamePrompt.
  ///
  /// In ru, this message translates to:
  /// **'Имена сохраняются отдельно от подключения пары.'**
  String get participantNamePrompt;

  /// No description provided for @editParticipantName.
  ///
  /// In ru, this message translates to:
  /// **'Изменить имя'**
  String get editParticipantName;

  /// No description provided for @defaultDuckName.
  ///
  /// In ru, this message translates to:
  /// **'Кряква'**
  String get defaultDuckName;

  /// No description provided for @duckNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Кряква'**
  String get duckNameHint;

  /// No description provided for @getAcquainted.
  ///
  /// In ru, this message translates to:
  /// **'Знакомиться!'**
  String get getAcquainted;

  /// No description provided for @petScreenTitle.
  ///
  /// In ru, this message translates to:
  /// **'Совместный тамагочи'**
  String get petScreenTitle;

  /// No description provided for @familyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Наша маленькая семья'**
  String get familyTitle;

  /// No description provided for @petAge.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} день вместе с вами} few{{count} дня вместе с вами} many{{count} дней вместе с вами} other{{count} дня вместе с вами}}'**
  String petAge(int count);

  /// No description provided for @rename.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get rename;

  /// No description provided for @overlayTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выпустить {name} на экран'**
  String overlayTitle(Object name);

  /// No description provided for @duckNamed.
  ///
  /// In ru, this message translates to:
  /// **'Уточка {name}'**
  String duckNamed(Object name);

  /// No description provided for @overlayAndroid.
  ///
  /// In ru, this message translates to:
  /// **'Уточка будет плавать поверх приложений'**
  String get overlayAndroid;

  /// No description provided for @overlayUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Плавающее окно доступно только на Android'**
  String get overlayUnavailable;

  /// No description provided for @overlayPermission.
  ///
  /// In ru, this message translates to:
  /// **'Разрешите показ поверх других приложений.'**
  String get overlayPermission;

  /// No description provided for @overlayLaunchError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось запустить оверлей: {error}'**
  String overlayLaunchError(Object error);

  /// No description provided for @petSemantics.
  ///
  /// In ru, this message translates to:
  /// **'Погладить уточку'**
  String get petSemantics;

  /// No description provided for @petWearLeatherJacket.
  ///
  /// In ru, this message translates to:
  /// **'Надеть чёрную кожанку'**
  String get petWearLeatherJacket;

  /// No description provided for @petRemoveLeatherJacket.
  ///
  /// In ru, this message translates to:
  /// **'Снять кожанку'**
  String get petRemoveLeatherJacket;

  /// No description provided for @wardrobeEntry.
  ///
  /// In ru, this message translates to:
  /// **'Гардероб'**
  String get wardrobeEntry;

  /// No description provided for @wardrobeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Гардероб уточки'**
  String get wardrobeTitle;

  /// No description provided for @wardrobeShopTitle.
  ///
  /// In ru, this message translates to:
  /// **'Магазин костюмов'**
  String get wardrobeShopTitle;

  /// No description provided for @wardrobeDefaultName.
  ///
  /// In ru, this message translates to:
  /// **'Обычный образ'**
  String get wardrobeDefaultName;

  /// No description provided for @wardrobeDefaultDescription.
  ///
  /// In ru, this message translates to:
  /// **'Простой и уютный образ — бесплатно.'**
  String get wardrobeDefaultDescription;

  /// No description provided for @wardrobeJacketName.
  ///
  /// In ru, this message translates to:
  /// **'Чёрная кожаная куртка'**
  String get wardrobeJacketName;

  /// No description provided for @wardrobeJacketDescription.
  ///
  /// In ru, this message translates to:
  /// **'Стильная чёрная кожаная куртка по фигуре.'**
  String get wardrobeJacketDescription;

  /// No description provided for @wardrobeHeartPajamasName.
  ///
  /// In ru, this message translates to:
  /// **'Пижама с сердечками'**
  String get wardrobeHeartPajamasName;

  /// No description provided for @wardrobeHeartPajamasDescription.
  ///
  /// In ru, this message translates to:
  /// **'Мягкая розовая пижама с сердечками для сладких снов.'**
  String get wardrobeHeartPajamasDescription;

  /// No description provided for @wardrobeFree.
  ///
  /// In ru, this message translates to:
  /// **'Бесплатно'**
  String get wardrobeFree;

  /// No description provided for @wardrobePrice.
  ///
  /// In ru, this message translates to:
  /// **'{price} ₴'**
  String wardrobePrice(int price);

  /// No description provided for @wardrobeTapToPreview.
  ///
  /// In ru, this message translates to:
  /// **'Нажми на образ, чтобы посмотреть'**
  String get wardrobeTapToPreview;

  /// No description provided for @wardrobePreviewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр: {name}'**
  String wardrobePreviewTitle(Object name);

  /// No description provided for @wardrobeInsufficientFunds.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно средств: нужно {price} ₴, на балансе {balance} ₴.'**
  String wardrobeInsufficientFunds(int price, int balance);

  /// No description provided for @wardrobeOwned.
  ///
  /// In ru, this message translates to:
  /// **'Куплено'**
  String get wardrobeOwned;

  /// No description provided for @wardrobeSelected.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано'**
  String get wardrobeSelected;

  /// No description provided for @wardrobeChoose.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать'**
  String get wardrobeChoose;

  /// No description provided for @wardrobeBuying.
  ///
  /// In ru, this message translates to:
  /// **'Покупка…'**
  String get wardrobeBuying;

  /// No description provided for @wardrobeBuy.
  ///
  /// In ru, this message translates to:
  /// **'Купить'**
  String get wardrobeBuy;

  /// No description provided for @moodHappy.
  ///
  /// In ru, this message translates to:
  /// **'Кря-кря! Какой чудесный день!'**
  String get moodHappy;

  /// No description provided for @moodHungry.
  ///
  /// In ru, this message translates to:
  /// **'Кажется, я немного проголодалась…'**
  String get moodHungry;

  /// No description provided for @moodVeryHungry.
  ///
  /// In ru, this message translates to:
  /// **'Уточка очень хочет кушать…'**
  String get moodVeryHungry;

  /// No description provided for @satiety.
  ///
  /// In ru, this message translates to:
  /// **'Сытость'**
  String get satiety;

  /// No description provided for @dailyHungerLoss.
  ///
  /// In ru, this message translates to:
  /// **'Каждый день без угощения −25%'**
  String get dailyHungerLoss;

  /// No description provided for @feedDuck.
  ///
  /// In ru, this message translates to:
  /// **'Угости уточку'**
  String get feedDuck;

  /// No description provided for @feedVarietyRequired.
  ///
  /// In ru, this message translates to:
  /// **'Уточке нужно разнообразие — предложи ей что-нибудь другое.'**
  String get feedVarietyRequired;

  /// No description provided for @tamagotchiHelpTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как заботиться об уточке'**
  String get tamagotchiHelpTitle;

  /// No description provided for @tamagotchiHelpCare.
  ///
  /// In ru, this message translates to:
  /// **'Сытость уменьшается на 25% за каждый день без еды. Если не кормить 4 дня, уточка уйдёт — её можно позвать обратно.'**
  String get tamagotchiHelpCare;

  /// No description provided for @tamagotchiHelpFeed.
  ///
  /// In ru, this message translates to:
  /// **'Нажимай на еду или продукты из магазина. Одну и ту же еду можно дать два раза подряд, но на третий раз уточка попросит разнообразия. История сохраняется.'**
  String get tamagotchiHelpFeed;

  /// No description provided for @tamagotchiHelpPlay.
  ///
  /// In ru, this message translates to:
  /// **'Нажми на уточку, чтобы поиграть и порадовать её. В гардеробе можно примерять, покупать и надевать образы.'**
  String get tamagotchiHelpPlay;

  /// No description provided for @foodCrumbs.
  ///
  /// In ru, this message translates to:
  /// **'Крошки'**
  String get foodCrumbs;

  /// No description provided for @foodWorm.
  ///
  /// In ru, this message translates to:
  /// **'Червячок'**
  String get foodWorm;

  /// No description provided for @foodWatermelon.
  ///
  /// In ru, this message translates to:
  /// **'Арбузик'**
  String get foodWatermelon;

  /// No description provided for @foodBreadCrumbs.
  ///
  /// In ru, this message translates to:
  /// **'Крошки'**
  String get foodBreadCrumbs;

  /// No description provided for @foodWatermelonStore.
  ///
  /// In ru, this message translates to:
  /// **'Арбуз'**
  String get foodWatermelonStore;

  /// No description provided for @foodWorms.
  ///
  /// In ru, this message translates to:
  /// **'Червячки'**
  String get foodWorms;

  /// No description provided for @foodPizza.
  ///
  /// In ru, this message translates to:
  /// **'Пицца'**
  String get foodPizza;

  /// No description provided for @foodApple.
  ///
  /// In ru, this message translates to:
  /// **'Яблоко'**
  String get foodApple;

  /// No description provided for @foodCheese.
  ///
  /// In ru, this message translates to:
  /// **'Сыр'**
  String get foodCheese;

  /// No description provided for @foodCarrot.
  ///
  /// In ru, this message translates to:
  /// **'Морковь'**
  String get foodCarrot;

  /// No description provided for @foodMilk.
  ///
  /// In ru, this message translates to:
  /// **'Молоко'**
  String get foodMilk;

  /// No description provided for @foodCrumbsSnack.
  ///
  /// In ru, this message translates to:
  /// **'крошки'**
  String get foodCrumbsSnack;

  /// No description provided for @foodWormSnack.
  ///
  /// In ru, this message translates to:
  /// **'червячка'**
  String get foodWormSnack;

  /// No description provided for @foodWatermelonSnack.
  ///
  /// In ru, this message translates to:
  /// **'арбузик'**
  String get foodWatermelonSnack;

  /// No description provided for @foodWatermelonStoreSnack.
  ///
  /// In ru, this message translates to:
  /// **'арбуз'**
  String get foodWatermelonStoreSnack;

  /// No description provided for @foodPizzaSnack.
  ///
  /// In ru, this message translates to:
  /// **'пиццу'**
  String get foodPizzaSnack;

  /// No description provided for @feedConfirmation.
  ///
  /// In ru, this message translates to:
  /// **'{name} с удовольствием съела {food}! 💚'**
  String feedConfirmation(Object name, Object food);

  /// No description provided for @inventoryHint.
  ///
  /// In ru, this message translates to:
  /// **'Покупки из магазина — нажми, чтобы накормить:'**
  String get inventoryHint;

  /// No description provided for @goToStore.
  ///
  /// In ru, this message translates to:
  /// **'Магазин продуктов'**
  String get goToStore;

  /// No description provided for @goToWarehouseWork.
  ///
  /// In ru, this message translates to:
  /// **'Работа на складе'**
  String get goToWarehouseWork;

  /// No description provided for @duckWalletBalance.
  ///
  /// In ru, this message translates to:
  /// **'Баланс: {balance} ₴'**
  String duckWalletBalance(int balance);

  /// No description provided for @careDay.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня день ухода за {name} у {caregiver}'**
  String careDay(Object name, Object caregiver);

  /// No description provided for @you.
  ///
  /// In ru, this message translates to:
  /// **'тебя'**
  String get you;

  /// No description provided for @yourPartner.
  ///
  /// In ru, this message translates to:
  /// **'твоей половинки'**
  String get yourPartner;

  /// No description provided for @comingSoonOutfits.
  ///
  /// In ru, this message translates to:
  /// **'Магазин костюмов для {name}'**
  String comingSoonOutfits(Object name);

  /// No description provided for @runawayTitle.
  ///
  /// In ru, this message translates to:
  /// **'{name} улетела на поиски еды...'**
  String runawayTitle(Object name);

  /// No description provided for @runawayDescription.
  ///
  /// In ru, this message translates to:
  /// **'Кажется, ей очень не хватало ваших забот.'**
  String get runawayDescription;

  /// No description provided for @callDuckBack.
  ///
  /// In ru, this message translates to:
  /// **'Позвать обратно'**
  String get callDuckBack;

  /// No description provided for @storeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Поход в магазин'**
  String get storeTitle;

  /// No description provided for @storeChooseProducts.
  ///
  /// In ru, this message translates to:
  /// **'Выбери продукты на полках'**
  String get storeChooseProducts;

  /// No description provided for @storeChooseAtLeastOne.
  ///
  /// In ru, this message translates to:
  /// **'Выбери хотя бы один продукт'**
  String get storeChooseAtLeastOne;

  /// No description provided for @storeWalletStatus.
  ///
  /// In ru, this message translates to:
  /// **'Баланс: {balance} ₴ · корзина: {price} ₴'**
  String storeWalletStatus(int balance, int price);

  /// No description provided for @storeInsufficientFundsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не хватает гривен'**
  String get storeInsufficientFundsTitle;

  /// No description provided for @storeInsufficientFunds.
  ///
  /// In ru, this message translates to:
  /// **'На балансе {balance} ₴, а товар стоит {price} ₴. Убери товар из корзины или выбери другой.'**
  String storeInsufficientFunds(int balance, int price);

  /// No description provided for @storeReplaceLastItem.
  ///
  /// In ru, this message translates to:
  /// **'Убрать один товар и взять {item}'**
  String storeReplaceLastItem(Object item);

  /// No description provided for @storeChooseAnother.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать другой товар'**
  String get storeChooseAnother;

  /// No description provided for @storeCheckout.
  ///
  /// In ru, this message translates to:
  /// **'Перейти к кассе'**
  String get storeCheckout;

  /// No description provided for @storeChooseAll.
  ///
  /// In ru, this message translates to:
  /// **'Выбери все продукты ({collected}/{total})'**
  String storeChooseAll(int collected, int total);

  /// No description provided for @storeCheckoutPrompt.
  ///
  /// In ru, this message translates to:
  /// **'{name} у кассы! Нажми на корзину, чтобы уточка просканировала продукты'**
  String storeCheckoutPrompt(Object name);

  /// No description provided for @storeSign.
  ///
  /// In ru, this message translates to:
  /// **'МАГАЗИН'**
  String get storeSign;

  /// No description provided for @storeScanBeep.
  ///
  /// In ru, this message translates to:
  /// **'Бип! ✨'**
  String get storeScanBeep;

  /// No description provided for @storeTapBasket.
  ///
  /// In ru, this message translates to:
  /// **'Нажми на корзину, чтобы уточка просканировала продукты'**
  String get storeTapBasket;

  /// No description provided for @storeBasketScanning.
  ///
  /// In ru, this message translates to:
  /// **'Уточка сканирует продукты…'**
  String get storeBasketScanning;

  /// No description provided for @rearDuckSemantics.
  ///
  /// In ru, this message translates to:
  /// **'Погладить уточку {name}, вид сзади'**
  String rearDuckSemantics(Object name);

  /// No description provided for @storeScanned.
  ///
  /// In ru, this message translates to:
  /// **'Отсканировано'**
  String get storeScanned;

  /// No description provided for @storeCollected.
  ///
  /// In ru, this message translates to:
  /// **'Собрано'**
  String get storeCollected;

  /// No description provided for @storeSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить покупки: {error}'**
  String storeSaveError(Object error);

  /// No description provided for @storeReceiptTitle.
  ///
  /// In ru, this message translates to:
  /// **'Еда собрана!'**
  String get storeReceiptTitle;

  /// No description provided for @storeTotalPrice.
  ///
  /// In ru, this message translates to:
  /// **'Итого: {count} товара · {price} ₴'**
  String storeTotalPrice(int count, int price);

  /// No description provided for @storePurchasesFor.
  ///
  /// In ru, this message translates to:
  /// **'Покупки для {name}'**
  String storePurchasesFor(Object name);

  /// No description provided for @storeBringFood.
  ///
  /// In ru, this message translates to:
  /// **'Отнесём вкусности в инвентарь?'**
  String get storeBringFood;

  /// No description provided for @storeClaim.
  ///
  /// In ru, this message translates to:
  /// **'Забрать покупки в инвентарь'**
  String get storeClaim;

  /// No description provided for @storeClaimed.
  ///
  /// In ru, this message translates to:
  /// **'Покупки в инвентаре!'**
  String get storeClaimed;

  /// No description provided for @storeDuckCanEat.
  ///
  /// In ru, this message translates to:
  /// **'Теперь {name} будет чем угостить 🦆'**
  String storeDuckCanEat(Object name);

  /// No description provided for @storeReturnToPet.
  ///
  /// In ru, this message translates to:
  /// **'Вернуться к {name}'**
  String storeReturnToPet(Object name);

  /// No description provided for @storeTakeItem.
  ///
  /// In ru, this message translates to:
  /// **'Взять {item}'**
  String storeTakeItem(Object item);

  /// No description provided for @storeScannedItem.
  ///
  /// In ru, this message translates to:
  /// **'{item}, отсканирован'**
  String storeScannedItem(Object item);

  /// No description provided for @storeScanItem.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать {item}'**
  String storeScanItem(Object item);

  /// No description provided for @storePiece.
  ///
  /// In ru, this message translates to:
  /// **'1 шт.'**
  String get storePiece;

  /// No description provided for @memoriesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Капсула воспоминаний'**
  String get memoriesTitle;

  /// No description provided for @memoriesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Собирайте моменты, к которым хочется возвращаться'**
  String get memoriesSubtitle;

  /// No description provided for @addMemory.
  ///
  /// In ru, this message translates to:
  /// **'Добавить воспоминание'**
  String get addMemory;

  /// No description provided for @pickPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать фотографию'**
  String get pickPhoto;

  /// No description provided for @pickVideo.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать видео'**
  String get pickVideo;

  /// No description provided for @saveMemoryError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить воспоминание: {error}'**
  String saveMemoryError(Object error);

  /// No description provided for @loadMemoriesError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить воспоминания.'**
  String get loadMemoriesError;

  /// No description provided for @captionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подпись к воспоминанию'**
  String get captionTitle;

  /// No description provided for @captionHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, наш вечер'**
  String get captionHint;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @skip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get skip;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @memoryCaptionMissing.
  ///
  /// In ru, this message translates to:
  /// **'Без подписи'**
  String get memoryCaptionMissing;

  /// No description provided for @openPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Открыть фотографию'**
  String get openPhoto;

  /// No description provided for @openVideo.
  ///
  /// In ru, this message translates to:
  /// **'Открыть видео'**
  String get openVideo;

  /// No description provided for @openMemoryCaption.
  ///
  /// In ru, this message translates to:
  /// **'Открыть воспоминание: {caption}'**
  String openMemoryCaption(Object caption);

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @videoUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Видео недоступно'**
  String get videoUnavailable;

  /// No description provided for @mediaFileMissing.
  ///
  /// In ru, this message translates to:
  /// **'Выбранный файл не найден.'**
  String get mediaFileMissing;

  /// No description provided for @unknownAuthor.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестно'**
  String get unknownAuthor;

  /// No description provided for @dailyQuoteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кря-цитата дня'**
  String get dailyQuoteTitle;

  /// No description provided for @removeFavorite.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из избранного'**
  String get removeFavorite;

  /// No description provided for @addFavorite.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в избранное'**
  String get addFavorite;

  /// No description provided for @showAnotherMoment.
  ///
  /// In ru, this message translates to:
  /// **'Показать другой момент'**
  String get showAnotherMoment;

  /// No description provided for @noSuitableMemory.
  ///
  /// In ru, this message translates to:
  /// **'Подходящего воспоминания пока нет.'**
  String get noSuitableMemory;

  /// No description provided for @noEligibleMemoryError.
  ///
  /// In ru, this message translates to:
  /// **'Пока не найдено подходящее воспоминание: нужны реплики обоих участников, без ссор и сервисных сообщений.'**
  String get noEligibleMemoryError;

  /// No description provided for @randomMemoryLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось загрузить воспоминание. Проверьте файл экспорта чата.'**
  String get randomMemoryLoadError;

  /// No description provided for @favoriteUpdateError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить избранное. Попробуйте ещё раз.'**
  String get favoriteUpdateError;

  /// No description provided for @pairsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пары'**
  String get pairsTitle;

  /// No description provided for @pairSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Создайте локальную пару или введите код пары, уже сохранённой на этом устройстве.'**
  String get pairSubtitle;

  /// No description provided for @pairLocalNotice.
  ///
  /// In ru, this message translates to:
  /// **'Данные пары сохраняются только на этом устройстве. Для синхронизации с другим устройством нужен настроенный сервер.'**
  String get pairLocalNotice;

  /// No description provided for @yourName.
  ///
  /// In ru, this message translates to:
  /// **'Ваше имя'**
  String get yourName;

  /// No description provided for @pairNameSetupRequired.
  ///
  /// In ru, this message translates to:
  /// **'Сначала укажите своё имя в Совместном тамагочи.'**
  String get pairNameSetupRequired;

  /// No description provided for @enterYourName.
  ///
  /// In ru, this message translates to:
  /// **'Введите своё имя.'**
  String get enterYourName;

  /// No description provided for @nameTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Имя должно быть короче 40 символов.'**
  String get nameTooLong;

  /// No description provided for @invalidPairCode.
  ///
  /// In ru, this message translates to:
  /// **'Введите код пары из четырёх цифр.'**
  String get invalidPairCode;

  /// No description provided for @pairNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Пара с таким кодом не найдена на этом устройстве.'**
  String get pairNotFound;

  /// No description provided for @pairFull.
  ///
  /// In ru, this message translates to:
  /// **'В этой паре уже два участника.'**
  String get pairFull;

  /// No description provided for @createPair.
  ///
  /// In ru, this message translates to:
  /// **'Создать пару'**
  String get createPair;

  /// No description provided for @pairCode.
  ///
  /// In ru, this message translates to:
  /// **'Код пары'**
  String get pairCode;

  /// No description provided for @joinPair.
  ///
  /// In ru, this message translates to:
  /// **'Присоединиться'**
  String get joinPair;

  /// No description provided for @pairCodeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Код локальной пары (тест)'**
  String get pairCodeTitle;

  /// No description provided for @pairCodePrompt.
  ///
  /// In ru, this message translates to:
  /// **'Код работает только на этом устройстве. Для подключения другого устройства нужен сервер.'**
  String get pairCodePrompt;

  /// No description provided for @copy.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать'**
  String get copy;

  /// No description provided for @done.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get done;

  /// No description provided for @yourPair.
  ///
  /// In ru, this message translates to:
  /// **'Ваша пара'**
  String get yourPair;

  /// No description provided for @waitingForPartner.
  ///
  /// In ru, this message translates to:
  /// **'Ожидаем второго участника. Код можно передать лично.'**
  String get waitingForPartner;

  /// No description provided for @moodCalendarTitle.
  ///
  /// In ru, this message translates to:
  /// **'Календарь настроения'**
  String get moodCalendarTitle;

  /// No description provided for @moodTodayPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Как ты себя чувствуешь сегодня?'**
  String get moodTodayPrompt;

  /// No description provided for @previousMonth.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий месяц'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In ru, this message translates to:
  /// **'Следующий месяц'**
  String get nextMonth;

  /// No description provided for @moodHistoryError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить историю настроения.'**
  String get moodHistoryError;

  /// No description provided for @moodJoyful.
  ///
  /// In ru, this message translates to:
  /// **'Радостно'**
  String get moodJoyful;

  /// No description provided for @moodJoyfulResponseOne.
  ///
  /// In ru, this message translates to:
  /// **'Сохрани этот яркий момент — пусть утка тоже порадуется вместе с тобой.'**
  String get moodJoyfulResponseOne;

  /// No description provided for @moodJoyfulResponseTwo.
  ///
  /// In ru, this message translates to:
  /// **'Твоя улыбка сегодня заразительна. Подари её кому-нибудь рядом.'**
  String get moodJoyfulResponseTwo;

  /// No description provided for @moodJoyfulResponseThree.
  ///
  /// In ru, this message translates to:
  /// **'Какой чудесный день! Устрой маленький праздник из обычного момента.'**
  String get moodJoyfulResponseThree;

  /// No description provided for @moodCalm.
  ///
  /// In ru, this message translates to:
  /// **'Спокойно'**
  String get moodCalm;

  /// No description provided for @moodCalmResponseOne.
  ///
  /// In ru, this message translates to:
  /// **'Тихие дни тоже прекрасны. Можно просто побыть в своём ритме.'**
  String get moodCalmResponseOne;

  /// No description provided for @moodCalmResponseTwo.
  ///
  /// In ru, this message translates to:
  /// **'Уточка напоминает: не обязательно торопиться, чтобы всё успеть.'**
  String get moodCalmResponseTwo;

  /// No description provided for @moodCalmResponseThree.
  ///
  /// In ru, this message translates to:
  /// **'Пусть сегодня будет побольше уютных пауз и любимого чая.'**
  String get moodCalmResponseThree;

  /// No description provided for @moodThoughtful.
  ///
  /// In ru, this message translates to:
  /// **'Обычно'**
  String get moodThoughtful;

  /// No description provided for @moodThoughtfulResponseOne.
  ///
  /// In ru, this message translates to:
  /// **'Обычный день — отличная возможность заметить что-то хорошее вокруг.'**
  String get moodThoughtfulResponseOne;

  /// No description provided for @moodThoughtfulResponseTwo.
  ///
  /// In ru, this message translates to:
  /// **'Добавь в день одну маленькую радость — уточка одобряет.'**
  String get moodThoughtfulResponseTwo;

  /// No description provided for @moodThoughtfulResponseThree.
  ///
  /// In ru, this message translates to:
  /// **'Даже спокойный день может спрятать приятный сюрприз.'**
  String get moodThoughtfulResponseThree;

  /// No description provided for @moodTired.
  ///
  /// In ru, this message translates to:
  /// **'Устала'**
  String get moodTired;

  /// No description provided for @moodTiredResponseOne.
  ///
  /// In ru, this message translates to:
  /// **'Уточка советует устроить себе уютную передышку, если получится.'**
  String get moodTiredResponseOne;

  /// No description provided for @moodTiredResponseTwo.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня можно выбрать самый мягкий темп и поберечь силы.'**
  String get moodTiredResponseTwo;

  /// No description provided for @moodTiredResponseThree.
  ///
  /// In ru, this message translates to:
  /// **'Плед, вода и немного тишины — утка шлёт тебе поддержку.'**
  String get moodTiredResponseThree;

  /// No description provided for @moodBlue.
  ///
  /// In ru, this message translates to:
  /// **'Грустно'**
  String get moodBlue;

  /// No description provided for @moodBlueResponseOne.
  ///
  /// In ru, this message translates to:
  /// **'Уточка рядом и желает тебе чего-нибудь тёплого и доброго.'**
  String get moodBlueResponseOne;

  /// No description provided for @moodBlueResponseTwo.
  ///
  /// In ru, this message translates to:
  /// **'Пусть сегодня найдётся хотя бы один маленький повод улыбнуться.'**
  String get moodBlueResponseTwo;

  /// No description provided for @moodBlueResponseThree.
  ///
  /// In ru, this message translates to:
  /// **'Ты не обязана быть весёлой каждую минуту. Уточка просто посидит рядом.'**
  String get moodBlueResponseThree;

  /// No description provided for @moodAngry.
  ///
  /// In ru, this message translates to:
  /// **'Злюсь'**
  String get moodAngry;

  /// No description provided for @moodAngryResponseOne.
  ///
  /// In ru, this message translates to:
  /// **'Злиться можно. Уточка рядом и поможет спокойно перевести дух.'**
  String get moodAngryResponseOne;

  /// No description provided for @moodAngryResponseTwo.
  ///
  /// In ru, this message translates to:
  /// **'Пусть гнев немного утихнет, а рядом найдётся место для твоих чувств.'**
  String get moodAngryResponseTwo;

  /// No description provided for @moodAngryResponseThree.
  ///
  /// In ru, this message translates to:
  /// **'Уточка сердито топает лапкой вместе с тобой, а потом предлагает чай.'**
  String get moodAngryResponseThree;

  /// No description provided for @moodBlueReaction.
  ///
  /// In ru, this message translates to:
  /// **'Утка укутывает вас пледом и приносит чай. Можно просто поддержать друг друга.'**
  String get moodBlueReaction;

  /// No description provided for @moodJoyfulReaction.
  ///
  /// In ru, this message translates to:
  /// **'Утка приглашает вас на маленький праздничный танец!'**
  String get moodJoyfulReaction;

  /// No description provided for @moodOtherReaction.
  ///
  /// In ru, this message translates to:
  /// **'Утка напоминает: сегодня можно спросить друг друга, какая поддержка будет приятна.'**
  String get moodOtherReaction;

  /// No description provided for @moodToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня: {mood}'**
  String moodToday(Object mood);

  /// No description provided for @moodResponse.
  ///
  /// In ru, this message translates to:
  /// **'Пусть сегодня найдётся маленький повод позаботиться о себе и немного порадоваться.'**
  String get moodResponse;

  /// No description provided for @weekdayMon.
  ///
  /// In ru, this message translates to:
  /// **'Пн'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In ru, this message translates to:
  /// **'Вт'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In ru, this message translates to:
  /// **'Ср'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In ru, this message translates to:
  /// **'Чт'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In ru, this message translates to:
  /// **'Пт'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In ru, this message translates to:
  /// **'Сб'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In ru, this message translates to:
  /// **'Вс'**
  String get weekdaySun;

  /// No description provided for @moodParticipantOne.
  ///
  /// In ru, this message translates to:
  /// **'Участник 1'**
  String get moodParticipantOne;

  /// No description provided for @moodParticipantTwo.
  ///
  /// In ru, this message translates to:
  /// **'Участник 2'**
  String get moodParticipantTwo;

  /// No description provided for @moodPairTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настроение вдвоём'**
  String get moodPairTitle;

  /// No description provided for @localPairDemo.
  ///
  /// In ru, this message translates to:
  /// **'Локальная демо-запись на этом устройстве. Для синхронизации нужен backend.'**
  String get localPairDemo;

  /// No description provided for @moodPairLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить записи.'**
  String get moodPairLoadError;

  /// No description provided for @moodPairWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Реакция уточки появится после двух отметок.'**
  String get moodPairWaiting;

  /// No description provided for @cinemaTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кино-ночь'**
  String get cinemaTitle;

  /// No description provided for @cinemaDailyNotice.
  ///
  /// In ru, this message translates to:
  /// **'Новый случайный выбор при каждом запуске. Свои фильмы и исключения сохраняются только на этом устройстве.'**
  String get cinemaDailyNotice;

  /// No description provided for @cinemaSpin.
  ///
  /// In ru, this message translates to:
  /// **'Крутить рулетку'**
  String get cinemaSpin;

  /// No description provided for @cinemaTodayMovie.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня смотрим: {title}'**
  String cinemaTodayMovie(Object title);

  /// No description provided for @cinemaWatchPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Будем смотреть этот фильм?'**
  String get cinemaWatchPrompt;

  /// No description provided for @cinemaWatched.
  ///
  /// In ru, this message translates to:
  /// **'Уже смотрели'**
  String get cinemaWatched;

  /// No description provided for @cinemaSkipWeek.
  ///
  /// In ru, this message translates to:
  /// **'Не будем — убрать на неделю'**
  String get cinemaSkipWeek;

  /// No description provided for @cinemaWatchedSaved.
  ///
  /// In ru, this message translates to:
  /// **'Отличный выбор! Приятного вечера.'**
  String get cinemaWatchedSaved;

  /// No description provided for @cinemaSkippedSaved.
  ///
  /// In ru, this message translates to:
  /// **'Фильм убран из рулетки на неделю.'**
  String get cinemaSkippedSaved;

  /// No description provided for @cinemaNoFilms.
  ///
  /// In ru, this message translates to:
  /// **'На сегодня фильмов не осталось. Добавьте свой или попробуйте завтра.'**
  String get cinemaNoFilms;

  /// No description provided for @cinemaManageFilms.
  ///
  /// In ru, this message translates to:
  /// **'Фильмы на сегодня'**
  String get cinemaManageFilms;

  /// No description provided for @cinemaFilmHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, Интерстеллар'**
  String get cinemaFilmHint;

  /// No description provided for @cinemaAddFilm.
  ///
  /// In ru, this message translates to:
  /// **'Добавить фильм'**
  String get cinemaAddFilm;

  /// No description provided for @cinemaRemoveToday.
  ///
  /// In ru, this message translates to:
  /// **'Убрать {title} из рулетки на сегодня'**
  String cinemaRemoveToday(Object title);

  /// No description provided for @cinemaActionError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить список фильмов.'**
  String get cinemaActionError;

  /// No description provided for @duckNeedsPair.
  ///
  /// In ru, this message translates to:
  /// **'Чтобы заботиться об уточке, сначала создайте пару или присоединитесь к ней в главном меню.'**
  String get duckNeedsPair;

  /// No description provided for @testCreatePair.
  ///
  /// In ru, this message translates to:
  /// **'Создать тестовую пару (временно)'**
  String get testCreatePair;

  /// No description provided for @testPairMemberName.
  ///
  /// In ru, this message translates to:
  /// **'Тестовый участник'**
  String get testPairMemberName;

  /// No description provided for @duckNameLocalNotice.
  ///
  /// In ru, this message translates to:
  /// **'Имя уточки сохраняется только на этом устройстве. Синхронизация между участниками пока не подключена.'**
  String get duckNameLocalNotice;

  /// No description provided for @cinemaLike.
  ///
  /// In ru, this message translates to:
  /// **'нравится'**
  String get cinemaLike;

  /// No description provided for @cinemaDislike.
  ///
  /// In ru, this message translates to:
  /// **'не нравится'**
  String get cinemaDislike;

  /// No description provided for @cinemaLocalNotice.
  ///
  /// In ru, this message translates to:
  /// **'Демо на одном устройстве: выборы видны здесь, но не синхронизируются и не являются приватным голосованием между устройствами.'**
  String get cinemaLocalNotice;

  /// No description provided for @tmdbNotice.
  ///
  /// In ru, this message translates to:
  /// **'This product uses the TMDB API but is not endorsed or certified by TMDB.'**
  String get tmdbNotice;

  /// No description provided for @movieSearchLabel.
  ///
  /// In ru, this message translates to:
  /// **'Найти фильм в каталоге'**
  String get movieSearchLabel;

  /// No description provided for @movieSearchOnlineHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по каталогу TMDB'**
  String get movieSearchOnlineHint;

  /// No description provided for @movieSearchOfflineHint.
  ///
  /// In ru, this message translates to:
  /// **'Офлайн-каталог ограничен. Для расширенного поиска настройте TMDB_API_KEY через --dart-define; для production нужен backend proxy.'**
  String get movieSearchOfflineHint;

  /// No description provided for @searchMovie.
  ///
  /// In ru, this message translates to:
  /// **'Найти фильм'**
  String get searchMovie;

  /// No description provided for @movieSearchEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено. Попробуйте другое название.'**
  String get movieSearchEmpty;

  /// No description provided for @addMovieLabel.
  ///
  /// In ru, this message translates to:
  /// **'Добавить фильм или мультик'**
  String get addMovieLabel;

  /// No description provided for @addMovie.
  ///
  /// In ru, this message translates to:
  /// **'Добавить фильм'**
  String get addMovie;

  /// No description provided for @movieLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить фильмы.'**
  String get movieLoadError;

  /// No description provided for @watched.
  ///
  /// In ru, this message translates to:
  /// **'Смотрели'**
  String get watched;

  /// No description provided for @alreadyWatched.
  ///
  /// In ru, this message translates to:
  /// **'Уже смотрели'**
  String get alreadyWatched;

  /// No description provided for @chooseSecretly.
  ///
  /// In ru, this message translates to:
  /// **'{participant}, выбери тайно:'**
  String chooseSecretly(Object participant);

  /// No description provided for @voteSavedSecretly.
  ///
  /// In ru, this message translates to:
  /// **'Голос записан тайно.'**
  String get voteSavedSecretly;

  /// No description provided for @movieMatch.
  ///
  /// In ru, this message translates to:
  /// **'🍿 Мэтч! Сегодня смотрим {title}!'**
  String movieMatch(Object title);

  /// No description provided for @movieNoMatch.
  ///
  /// In ru, this message translates to:
  /// **'Голоса не совпали — выберите другой фильм.'**
  String get movieNoMatch;

  /// No description provided for @movieAdded.
  ///
  /// In ru, this message translates to:
  /// **'«{title}» добавлен в список.'**
  String movieAdded(Object title);

  /// No description provided for @addMovieResult.
  ///
  /// In ru, this message translates to:
  /// **'Добавить {title}'**
  String addMovieResult(Object title);

  /// No description provided for @loadMorePages.
  ///
  /// In ru, this message translates to:
  /// **'Показать ещё · {page}/{totalPages}'**
  String loadMorePages(int page, int totalPages);

  /// No description provided for @movieMatchNotificationError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось показать локальное уведомление о мэтче.'**
  String get movieMatchNotificationError;

  /// No description provided for @secretNotesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Секретные заметки'**
  String get secretNotesTitle;

  /// No description provided for @secretNotesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Тёплые слова и сюрпризы, которые подождут своего момента'**
  String get secretNotesSubtitle;

  /// No description provided for @openPairs.
  ///
  /// In ru, this message translates to:
  /// **'Открыть раздел «Пары»'**
  String get openPairs;

  /// No description provided for @smallSurprise.
  ///
  /// In ru, this message translates to:
  /// **'Маленький сюрприз'**
  String get smallSurprise;

  /// No description provided for @postcardsTab.
  ///
  /// In ru, this message translates to:
  /// **'Открытки'**
  String get postcardsTab;

  /// No description provided for @postcardsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Открытки'**
  String get postcardsTitle;

  /// No description provided for @postcardsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Здесь хранятся действительно отправленные и полученные открытки.'**
  String get postcardsSubtitle;

  /// No description provided for @postcardPushUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'LAN-сервер не настроен. Запустите сервер на ноутбуке, подключите оба телефона к той же Wi-Fi сети, затем укажите адрес и общий токен. Для получения нажмите «Обновить».'**
  String get postcardPushUnavailable;

  /// No description provided for @postcardLanConfigured.
  ///
  /// In ru, this message translates to:
  /// **'LAN-сервер настроен. Телефоны должны быть в той же Wi-Fi сети, сервер на ноутбуке — запущен. Новые открытки проверяются вручную.'**
  String get postcardLanConfigured;

  /// No description provided for @postcardLanSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настроить LAN-сервер'**
  String get postcardLanSettings;

  /// No description provided for @postcardLanUpdate.
  ///
  /// In ru, this message translates to:
  /// **'Обновить входящие'**
  String get postcardLanUpdate;

  /// No description provided for @postcardLanSetupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подключение к серверу ноутбука'**
  String get postcardLanSetupTitle;

  /// No description provided for @postcardLanEndpoint.
  ///
  /// In ru, this message translates to:
  /// **'Адрес ноутбука, например http://192.168.1.5:8787'**
  String get postcardLanEndpoint;

  /// No description provided for @postcardLanToken.
  ///
  /// In ru, this message translates to:
  /// **'Общий токен пары из терминала сервера'**
  String get postcardLanToken;

  /// No description provided for @postcardLanSide.
  ///
  /// In ru, this message translates to:
  /// **'Этот телефон использует сторону'**
  String get postcardLanSide;

  /// No description provided for @postcardLanFirst.
  ///
  /// In ru, this message translates to:
  /// **'Участник 1'**
  String get postcardLanFirst;

  /// No description provided for @postcardLanSecond.
  ///
  /// In ru, this message translates to:
  /// **'Участник 2'**
  String get postcardLanSecond;

  /// No description provided for @postcardLanSaved.
  ///
  /// In ru, this message translates to:
  /// **'Подключение к LAN-серверу сохранено.'**
  String get postcardLanSaved;

  /// No description provided for @postcardLanHttpWarning.
  ///
  /// In ru, this message translates to:
  /// **'Используйте только доверенную домашнюю Wi-Fi сеть: HTTP не шифрует трафик. Токен даёт доступ к открыткам пары.'**
  String get postcardLanHttpWarning;

  /// No description provided for @postcardLanRefreshFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить открытки с LAN-сервера. Проверьте адрес, токен, Wi-Fi и firewall.'**
  String get postcardLanRefreshFailed;

  /// No description provided for @postcardsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока открыток нет.'**
  String get postcardsEmpty;

  /// No description provided for @postcardAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get postcardAll;

  /// No description provided for @postcardSentTab.
  ///
  /// In ru, this message translates to:
  /// **'Отправленные'**
  String get postcardSentTab;

  /// No description provided for @postcardReceivedTab.
  ///
  /// In ru, this message translates to:
  /// **'Полученные'**
  String get postcardReceivedTab;

  /// No description provided for @postcardComposeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новая открытка'**
  String get postcardComposeTitle;

  /// No description provided for @postcardRecipient.
  ///
  /// In ru, this message translates to:
  /// **'Имя партнёра'**
  String get postcardRecipient;

  /// No description provided for @postcardMessage.
  ///
  /// In ru, this message translates to:
  /// **'Текст открытки'**
  String get postcardMessage;

  /// No description provided for @postcardSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get postcardSend;

  /// No description provided for @postcardFieldsRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите получателя и напишите текст открытки.'**
  String get postcardFieldsRequired;

  /// No description provided for @postcardSendFailed.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не подтвердил сохранение открытки. Она не добавлена в отправленные.'**
  String get postcardSendFailed;

  /// No description provided for @postcardSent.
  ///
  /// In ru, this message translates to:
  /// **'Сервер сохранил открытку.'**
  String get postcardSent;

  /// No description provided for @postcardLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить архив открыток.'**
  String get postcardLoadError;

  /// No description provided for @postcardSentTo.
  ///
  /// In ru, this message translates to:
  /// **'Для: {name}'**
  String postcardSentTo(Object name);

  /// No description provided for @postcardReceivedFrom.
  ///
  /// In ru, this message translates to:
  /// **'От: {name}'**
  String postcardReceivedFrom(Object name);

  /// No description provided for @openPostcards.
  ///
  /// In ru, this message translates to:
  /// **'Открыть архив открыток'**
  String get openPostcards;

  /// No description provided for @countdownTitle.
  ///
  /// In ru, this message translates to:
  /// **'Важные даты'**
  String get countdownTitle;

  /// No description provided for @addEvent.
  ///
  /// In ru, this message translates to:
  /// **'Добавить событие'**
  String get addEvent;

  /// No description provided for @countdownLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить события.'**
  String get countdownLoadError;

  /// No description provided for @countdownEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте поездку, день рождения или другую важную дату.'**
  String get countdownEmpty;

  /// No description provided for @editEvent.
  ///
  /// In ru, this message translates to:
  /// **'Изменить событие'**
  String get editEvent;

  /// No description provided for @eventPassed.
  ///
  /// In ru, this message translates to:
  /// **'Это событие уже наступило · {date}'**
  String eventPassed(Object date);

  /// No description provided for @untilEvent.
  ///
  /// In ru, this message translates to:
  /// **'До события {date}'**
  String untilEvent(Object date);

  /// No description provided for @rememberThisDay.
  ///
  /// In ru, this message translates to:
  /// **'Сохраняем этот день в памяти'**
  String get rememberThisDay;

  /// No description provided for @eventToday.
  ///
  /// In ru, this message translates to:
  /// **'Событие уже сегодня'**
  String get eventToday;

  /// No description provided for @daysRemaining.
  ///
  /// In ru, this message translates to:
  /// **'Осталось {days} дн.'**
  String daysRemaining(int days);

  /// No description provided for @newEvent.
  ///
  /// In ru, this message translates to:
  /// **'Новое событие'**
  String get newEvent;

  /// No description provided for @eventTitleHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, поездка'**
  String get eventTitleHint;

  /// No description provided for @saveEventError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить событие: {error}'**
  String saveEventError(Object error);

  /// No description provided for @deleteEventError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить событие: {error}'**
  String deleteEventError(Object error);

  /// No description provided for @editEventNamed.
  ///
  /// In ru, this message translates to:
  /// **'Изменить событие {title}'**
  String editEventNamed(Object title);

  /// No description provided for @deleteEventNamed.
  ///
  /// In ru, this message translates to:
  /// **'Удалить событие {title}'**
  String deleteEventNamed(Object title);

  /// No description provided for @timeCapsuleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Капсула времени'**
  String get timeCapsuleTitle;

  /// No description provided for @timeCapsuleSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Оставьте записку или фото для будущего'**
  String get timeCapsuleSubtitle;

  /// No description provided for @createTimeCapsule.
  ///
  /// In ru, this message translates to:
  /// **'Создать капсулу времени'**
  String get createTimeCapsule;

  /// No description provided for @timeCapsuleLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить капсулы времени.'**
  String get timeCapsuleLoadError;

  /// No description provided for @timeCapsuleEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет капсул. Создайте первую для себя в будущем.'**
  String get timeCapsuleEmpty;

  /// No description provided for @createCapsuleError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать капсулу: {error}'**
  String createCapsuleError(Object error);

  /// No description provided for @openCapsuleFrom.
  ///
  /// In ru, this message translates to:
  /// **'Открыть капсулу от {date}'**
  String openCapsuleFrom(Object date);

  /// No description provided for @sealedUntil.
  ///
  /// In ru, this message translates to:
  /// **'Запечатана до {date}'**
  String sealedUntil(Object date);

  /// No description provided for @capsuleOpened.
  ///
  /// In ru, this message translates to:
  /// **'Капсула открыта'**
  String get capsuleOpened;

  /// No description provided for @capsuleSealed.
  ///
  /// In ru, this message translates to:
  /// **'Капсула запечатана'**
  String get capsuleSealed;

  /// No description provided for @rouletteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Рулетка свиданий'**
  String get rouletteTitle;

  /// No description provided for @rouletteSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите категорию и доверьте выбор случаю'**
  String get rouletteSubtitle;

  /// No description provided for @rouletteFood.
  ///
  /// In ru, this message translates to:
  /// **'Еда'**
  String get rouletteFood;

  /// No description provided for @rouletteMovie.
  ///
  /// In ru, this message translates to:
  /// **'Кино'**
  String get rouletteMovie;

  /// No description provided for @rouletteActivity.
  ///
  /// In ru, this message translates to:
  /// **'Занятия'**
  String get rouletteActivity;

  /// No description provided for @rouletteSpin.
  ///
  /// In ru, this message translates to:
  /// **'Крутить'**
  String get rouletteSpin;

  /// No description provided for @rouletteSpinAgain.
  ///
  /// In ru, this message translates to:
  /// **'Крутить ещё'**
  String get rouletteSpinAgain;

  /// No description provided for @rouletteResult.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня выбираем:'**
  String get rouletteResult;

  /// No description provided for @rouletteAddChoice.
  ///
  /// In ru, this message translates to:
  /// **'Добавить вариант'**
  String get rouletteAddChoice;

  /// No description provided for @rouletteChoiceHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, приготовить пасту'**
  String get rouletteChoiceHint;

  /// No description provided for @rouletteEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте хотя бы один вариант, чтобы запустить рулетку.'**
  String get rouletteEmpty;

  /// No description provided for @rouletteRemoveChoice.
  ///
  /// In ru, this message translates to:
  /// **'Удалить вариант {choice}'**
  String rouletteRemoveChoice(Object choice);

  /// No description provided for @rouletteSavedChoice.
  ///
  /// In ru, this message translates to:
  /// **'Вариант добавлен'**
  String get rouletteSavedChoice;

  /// No description provided for @rouletteError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить варианты рулетки.'**
  String get rouletteError;

  /// No description provided for @timeCapsuleOpen.
  ///
  /// In ru, this message translates to:
  /// **'Можно посмотреть'**
  String get timeCapsuleOpen;

  /// No description provided for @timeCapsuleOpensOn.
  ///
  /// In ru, this message translates to:
  /// **'Откроется {date}'**
  String timeCapsuleOpensOn(Object date);

  /// No description provided for @newTimeCapsule.
  ///
  /// In ru, this message translates to:
  /// **'Новая капсула времени'**
  String get newTimeCapsule;

  /// No description provided for @timeCapsuleNoteHint.
  ///
  /// In ru, this message translates to:
  /// **'Записка для себя в будущем'**
  String get timeCapsuleNoteHint;

  /// No description provided for @attachPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Прикрепить фото'**
  String get attachPhoto;

  /// No description provided for @photoSelected.
  ///
  /// In ru, this message translates to:
  /// **'Фото выбрано'**
  String get photoSelected;

  /// No description provided for @openOnDate.
  ///
  /// In ru, this message translates to:
  /// **'Открыть: {date}'**
  String openOnDate(Object date);

  /// No description provided for @sealCapsule.
  ///
  /// In ru, this message translates to:
  /// **'Запечатать'**
  String get sealCapsule;

  /// No description provided for @choosePhotoError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выбрать фото: {error}'**
  String choosePhotoError(Object error);

  /// No description provided for @capsuleNeedsContent.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте текст или выберите фото.'**
  String get capsuleNeedsContent;

  /// No description provided for @photoUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Фото недоступно'**
  String get photoUnavailable;

  /// No description provided for @rouletteFoodOptionCook.
  ///
  /// In ru, this message translates to:
  /// **'Приготовить вместе'**
  String get rouletteFoodOptionCook;

  /// No description provided for @rouletteFoodOptionOrder.
  ///
  /// In ru, this message translates to:
  /// **'Заказать любимую еду'**
  String get rouletteFoodOptionOrder;

  /// No description provided for @rouletteFoodOptionCafe.
  ///
  /// In ru, this message translates to:
  /// **'Сходить в кафе'**
  String get rouletteFoodOptionCafe;

  /// No description provided for @rouletteFoodOptionPicnic.
  ///
  /// In ru, this message translates to:
  /// **'Устроить пикник'**
  String get rouletteFoodOptionPicnic;

  /// No description provided for @rouletteFoodOptionDessert.
  ///
  /// In ru, this message translates to:
  /// **'Испечь десерт'**
  String get rouletteFoodOptionDessert;

  /// No description provided for @rouletteMovieOptionRomcom.
  ///
  /// In ru, this message translates to:
  /// **'Романтическая комедия'**
  String get rouletteMovieOptionRomcom;

  /// No description provided for @rouletteMovieOptionCartoon.
  ///
  /// In ru, this message translates to:
  /// **'Мультфильм'**
  String get rouletteMovieOptionCartoon;

  /// No description provided for @rouletteMovieOptionFavorite.
  ///
  /// In ru, this message translates to:
  /// **'Любимый фильм'**
  String get rouletteMovieOptionFavorite;

  /// No description provided for @rouletteMovieOptionNew.
  ///
  /// In ru, this message translates to:
  /// **'Найти что-то новое'**
  String get rouletteMovieOptionNew;

  /// No description provided for @rouletteMovieOptionNight.
  ///
  /// In ru, this message translates to:
  /// **'Устроить кино-ночь'**
  String get rouletteMovieOptionNight;

  /// No description provided for @rouletteActivityOptionWalk.
  ///
  /// In ru, this message translates to:
  /// **'Прогуляться вместе'**
  String get rouletteActivityOptionWalk;

  /// No description provided for @rouletteActivityOptionBoardGame.
  ///
  /// In ru, this message translates to:
  /// **'Сыграть в настольную игру'**
  String get rouletteActivityOptionBoardGame;

  /// No description provided for @rouletteActivityOptionPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Сделать фото-прогулку'**
  String get rouletteActivityOptionPhoto;

  /// No description provided for @rouletteActivityOptionHomeDate.
  ///
  /// In ru, this message translates to:
  /// **'Устроить домашнее свидание'**
  String get rouletteActivityOptionHomeDate;

  /// No description provided for @rouletteActivityOptionMusic.
  ///
  /// In ru, this message translates to:
  /// **'Послушать музыку'**
  String get rouletteActivityOptionMusic;

  /// No description provided for @warehouseTitle.
  ///
  /// In ru, this message translates to:
  /// **'Работа на складе'**
  String get warehouseTitle;

  /// No description provided for @warehouseSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Лови падающие коробки, двигая рохлю. Поймай все 15!'**
  String get warehouseSubtitle;

  /// No description provided for @warehouseSceneSemantics.
  ///
  /// In ru, this message translates to:
  /// **'Склад: перетаскивай пальцем, чтобы двигать рохлю и ловить коробки.'**
  String get warehouseSceneSemantics;

  /// No description provided for @warehouseStart.
  ///
  /// In ru, this message translates to:
  /// **'Начать смену'**
  String get warehouseStart;

  /// No description provided for @warehouseTired.
  ///
  /// In ru, this message translates to:
  /// **'Уточка устала. Ей нужно отдохнуть.'**
  String get warehouseTired;

  /// No description provided for @warehouseCooldownRemaining.
  ///
  /// In ru, this message translates to:
  /// **'Вернуться на работу можно через {hours} ч {minutes} мин.'**
  String warehouseCooldownRemaining(int hours, int minutes);

  /// No description provided for @warehouseProgress.
  ///
  /// In ru, this message translates to:
  /// **'Завершено: {caught} из {total}'**
  String warehouseProgress(int caught, int total);

  /// No description provided for @warehouseCaught.
  ///
  /// In ru, this message translates to:
  /// **'Поймано: {count}'**
  String warehouseCaught(int count);

  /// No description provided for @warehouseMissed.
  ///
  /// In ru, this message translates to:
  /// **'Мимо: {count}'**
  String warehouseMissed(int count);

  /// No description provided for @warehouseMoveLeft.
  ///
  /// In ru, this message translates to:
  /// **'Двигать рохлю влево'**
  String get warehouseMoveLeft;

  /// No description provided for @warehouseMoveRight.
  ///
  /// In ru, this message translates to:
  /// **'Двигать рохлю вправо'**
  String get warehouseMoveRight;

  /// No description provided for @warehouseControlsHint.
  ///
  /// In ru, this message translates to:
  /// **'Перетащи по складу или нажимай стрелки'**
  String get warehouseControlsHint;

  /// No description provided for @warehouseResultPerfectTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отличная смена!'**
  String get warehouseResultPerfectTitle;

  /// No description provided for @warehouseResultPartialTitle.
  ///
  /// In ru, this message translates to:
  /// **'Хорошая работа!'**
  String get warehouseResultPartialTitle;

  /// No description provided for @warehouseResultFailureTitle.
  ///
  /// In ru, this message translates to:
  /// **'Смена завершена'**
  String get warehouseResultFailureTitle;

  /// No description provided for @warehouseResultPerfectMessage.
  ///
  /// In ru, this message translates to:
  /// **'Пойманы все коробки — уточка гордится тобой!'**
  String get warehouseResultPerfectMessage;

  /// No description provided for @warehouseResultPartialMessage.
  ///
  /// In ru, this message translates to:
  /// **'Больше половины коробок пойманы. Неплохо!'**
  String get warehouseResultPartialMessage;

  /// No description provided for @warehouseResultFailureMessage.
  ///
  /// In ru, this message translates to:
  /// **'Поймано меньше половины коробок. Попробуем позже.'**
  String get warehouseResultFailureMessage;

  /// No description provided for @warehouseReward.
  ///
  /// In ru, this message translates to:
  /// **'Заработано: {amount} ₴'**
  String warehouseReward(int amount);

  /// No description provided for @warehouseReturnHome.
  ///
  /// In ru, this message translates to:
  /// **'На главную'**
  String get warehouseReturnHome;

  /// No description provided for @warehouseRetrySave.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get warehouseRetrySave;

  /// No description provided for @warehouseWorkSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить смену на складе: {error}'**
  String warehouseWorkSaveError(Object error);

  /// No description provided for @groceryStoreTab.
  ///
  /// In ru, this message translates to:
  /// **'Магазин'**
  String get groceryStoreTab;

  /// No description provided for @groceryWorkTab.
  ///
  /// In ru, this message translates to:
  /// **'Работа'**
  String get groceryWorkTab;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
