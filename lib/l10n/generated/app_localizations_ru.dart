// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Кохання';

  @override
  String get homeTab => 'Наша история';

  @override
  String get petTab => 'Тамагочи';

  @override
  String get memoriesTab => 'Воспоминания';

  @override
  String get couponsTab => 'Купоны';

  @override
  String get notesTab => 'Заметки';

  @override
  String get pairsTab => 'Пары';

  @override
  String get rouletteTab => 'Рулетка';

  @override
  String get duckShortcut => 'Наша уточка';

  @override
  String get sendHeart => 'Отправить сердечко';

  @override
  String get homeEyebrow => 'НАША ИСТОРИЯ';

  @override
  String get homeHeadline => 'Вместе — с каждым мгновением';

  @override
  String get couponTitle => 'Купоны на желания';

  @override
  String get couponSubtitle => 'Маленькие радости, которые можно активировать';

  @override
  String get couponLoading => 'Загружаем купоны…';

  @override
  String get couponLoadError => 'Не удалось загрузить купоны.';

  @override
  String get couponRetry => 'Попробовать снова';

  @override
  String get couponEmptyTitle => 'Пока нет купонов';

  @override
  String get couponEmptyDescription =>
      'Здесь появятся ваши желания и сюрпризы.';

  @override
  String get couponNotificationNotConfigured =>
      'Внешние уведомления не настроены.';

  @override
  String get couponActivationError => 'Не удалось сохранить активацию купона.';

  @override
  String get couponScratchHint => 'Проведи пальцем, чтобы стереть';

  @override
  String get couponActivate => 'Активировать';

  @override
  String get couponUsed => 'Уже использован';

  @override
  String get couponMonthly => 'Можно раз в месяц';

  @override
  String get couponOneTime => 'Одноразовый';

  @override
  String get couponDaily => 'Ежедневный купон';

  @override
  String get dailyCouponTitle => 'Маленькое желание дня';

  @override
  String get dailyCouponDescription =>
      'Выбери приятный сюрприз для нас сегодня.';

  @override
  String get dailyCouponExpired => 'Срок этого дневного купона истёк';

  @override
  String get couponCallbackError => 'Не удалось выполнить действие купона.';

  @override
  String get couponNotificationWarning =>
      'Купон активирован, но уведомление не удалось показать.';

  @override
  String get notificationDenied =>
      'Купон активирован. Локальные уведомления отключены или недоступны.';

  @override
  String get notificationFailure =>
      'Купон активирован. Не удалось показать локальное уведомление.';

  @override
  String get overlayPetTapHint => 'Коснитесь уточки, чтобы порадовать её';

  @override
  String pairCreateError(Object error) {
    return 'Не удалось создать пару: $error';
  }

  @override
  String get relationshipStarted => 'С 13 ноября 2023 года • 20:30';

  @override
  String get beginning => 'И это только начало ♥';

  @override
  String get couponActivatedMessage =>
      'Купон активирован! Уточка несёт тебе радость!';

  @override
  String get language => 'Язык';

  @override
  String get russian => 'Русский';

  @override
  String get ukrainian => 'Українська';

  @override
  String durationYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count лет',
      many: '$count лет',
      few: '$count года',
      one: '$count год',
    );
    return '$_temp0';
  }

  @override
  String durationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяцев',
      many: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часов',
      many: '$count часов',
      few: '$count часа',
      one: '$count час',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минут',
      many: '$count минут',
      few: '$count минуты',
      one: '$count минута',
    );
    return '$_temp0';
  }

  @override
  String durationSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count секунд',
      many: '$count секунд',
      few: '$count секунды',
      one: '$count секунда',
    );
    return '$_temp0';
  }

  @override
  String get nameDuckTitle => 'Как назовём уточку? 🦆';

  @override
  String get participantNameTitle => 'Как зовут участников?';

  @override
  String participantNameLabel(int number) {
    return 'Имя участника $number';
  }

  @override
  String get participantNamePrompt =>
      'Имена сохраняются отдельно от подключения пары.';

  @override
  String get editParticipantName => 'Изменить имя';

  @override
  String get defaultDuckName => 'Кряква';

  @override
  String get duckNameHint => 'Кряква';

  @override
  String get getAcquainted => 'Знакомиться!';

  @override
  String get petScreenTitle => 'Совместный тамагочи';

  @override
  String get familyTitle => 'Наша маленькая семья';

  @override
  String petAge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня вместе с вами',
      many: '$count дней вместе с вами',
      few: '$count дня вместе с вами',
      one: '$count день вместе с вами',
    );
    return '$_temp0';
  }

  @override
  String get rename => 'Переименовать';

  @override
  String overlayTitle(Object name) {
    return 'Выпустить $name на экран';
  }

  @override
  String duckNamed(Object name) {
    return 'Уточка $name';
  }

  @override
  String get overlayAndroid => 'Уточка будет плавать поверх приложений';

  @override
  String get overlayUnavailable => 'Плавающее окно доступно только на Android';

  @override
  String get overlayPermission => 'Разрешите показ поверх других приложений.';

  @override
  String overlayLaunchError(Object error) {
    return 'Не удалось запустить оверлей: $error';
  }

  @override
  String get petSemantics => 'Погладить уточку';

  @override
  String get petWearLeatherJacket => 'Надеть чёрную кожанку';

  @override
  String get petRemoveLeatherJacket => 'Снять кожанку';

  @override
  String get wardrobeEntry => 'Гардероб';

  @override
  String get wardrobeTitle => 'Гардероб уточки';

  @override
  String get wardrobeShopTitle => 'Магазин костюмов';

  @override
  String get wardrobeDefaultName => 'Обычный образ';

  @override
  String get wardrobeDefaultDescription =>
      'Простой и уютный образ — бесплатно.';

  @override
  String get wardrobeJacketName => 'Чёрная кожаная куртка';

  @override
  String get wardrobeJacketDescription =>
      'Стильная чёрная кожаная куртка по фигуре.';

  @override
  String get wardrobeHeartPajamasName => 'Пижама с сердечками';

  @override
  String get wardrobeHeartPajamasDescription =>
      'Мягкая розовая пижама с сердечками для сладких снов.';

  @override
  String get wardrobeFree => 'Бесплатно';

  @override
  String wardrobePrice(int price) {
    return '$price ₴';
  }

  @override
  String get wardrobeTapToPreview => 'Нажми на образ, чтобы посмотреть';

  @override
  String wardrobePreviewTitle(Object name) {
    return 'Предпросмотр: $name';
  }

  @override
  String wardrobeInsufficientFunds(int price, int balance) {
    return 'Недостаточно средств: нужно $price ₴, на балансе $balance ₴.';
  }

  @override
  String get wardrobeOwned => 'Куплено';

  @override
  String get wardrobeSelected => 'Выбрано';

  @override
  String get wardrobeChoose => 'Выбрать';

  @override
  String get wardrobeBuying => 'Покупка…';

  @override
  String get wardrobeBuy => 'Купить';

  @override
  String get moodHappy => 'Кря-кря! Какой чудесный день!';

  @override
  String get moodHungry => 'Кажется, я немного проголодалась…';

  @override
  String get moodVeryHungry => 'Уточка очень хочет кушать…';

  @override
  String get satiety => 'Сытость';

  @override
  String get dailyHungerLoss => 'Каждый день без угощения −25%';

  @override
  String get feedDuck => 'Угости уточку';

  @override
  String get feedVarietyRequired =>
      'Уточке нужно разнообразие — предложи ей что-нибудь другое.';

  @override
  String get tamagotchiHelpTitle => 'Как заботиться об уточке';

  @override
  String get tamagotchiHelpCare =>
      'Сытость уменьшается на 25% за каждый день без еды. Если не кормить 4 дня, уточка уйдёт — её можно позвать обратно.';

  @override
  String get tamagotchiHelpFeed =>
      'Нажимай на еду или продукты из магазина. Одну и ту же еду можно дать два раза подряд, но на третий раз уточка попросит разнообразия. История сохраняется.';

  @override
  String get tamagotchiHelpPlay =>
      'Нажми на уточку, чтобы поиграть и порадовать её. В гардеробе можно примерять, покупать и надевать образы.';

  @override
  String get foodCrumbs => 'Крошки';

  @override
  String get foodWorm => 'Червячок';

  @override
  String get foodWatermelon => 'Арбузик';

  @override
  String get foodBreadCrumbs => 'Крошки';

  @override
  String get foodWatermelonStore => 'Арбуз';

  @override
  String get foodWorms => 'Червячки';

  @override
  String get foodPizza => 'Пицца';

  @override
  String get foodApple => 'Яблоко';

  @override
  String get foodCheese => 'Сыр';

  @override
  String get foodCarrot => 'Морковь';

  @override
  String get foodMilk => 'Молоко';

  @override
  String get foodCrumbsSnack => 'крошки';

  @override
  String get foodWormSnack => 'червячка';

  @override
  String get foodWatermelonSnack => 'арбузик';

  @override
  String get foodWatermelonStoreSnack => 'арбуз';

  @override
  String get foodPizzaSnack => 'пиццу';

  @override
  String feedConfirmation(Object name, Object food) {
    return '$name с удовольствием съела $food! 💚';
  }

  @override
  String get inventoryHint => 'Покупки из магазина — нажми, чтобы накормить:';

  @override
  String get goToStore => 'Магазин продуктов';

  @override
  String get goToWarehouseWork => 'Работа на складе';

  @override
  String duckWalletBalance(int balance) {
    return 'Баланс: $balance ₴';
  }

  @override
  String careDay(Object name, Object caregiver) {
    return 'Сегодня день ухода за $name у $caregiver';
  }

  @override
  String get you => 'тебя';

  @override
  String get yourPartner => 'твоей половинки';

  @override
  String comingSoonOutfits(Object name) {
    return 'Магазин костюмов для $name';
  }

  @override
  String runawayTitle(Object name) {
    return '$name улетела на поиски еды...';
  }

  @override
  String get runawayDescription => 'Кажется, ей очень не хватало ваших забот.';

  @override
  String get callDuckBack => 'Позвать обратно';

  @override
  String get storeTitle => 'Поход в магазин';

  @override
  String get storeChooseProducts => 'Выбери продукты на полках';

  @override
  String get storeChooseAtLeastOne => 'Выбери хотя бы один продукт';

  @override
  String storeWalletStatus(int balance, int price) {
    return 'Баланс: $balance ₴ · корзина: $price ₴';
  }

  @override
  String get storeInsufficientFundsTitle => 'Не хватает гривен';

  @override
  String storeInsufficientFunds(int balance, int price) {
    return 'На балансе $balance ₴, а товар стоит $price ₴. Убери товар из корзины или выбери другой.';
  }

  @override
  String storeReplaceLastItem(Object item) {
    return 'Убрать один товар и взять $item';
  }

  @override
  String get storeChooseAnother => 'Выбрать другой товар';

  @override
  String get storeCheckout => 'Перейти к кассе';

  @override
  String storeChooseAll(int collected, int total) {
    return 'Выбери все продукты ($collected/$total)';
  }

  @override
  String storeCheckoutPrompt(Object name) {
    return '$name у кассы! Нажми на корзину, чтобы уточка просканировала продукты';
  }

  @override
  String get storeSign => 'МАГАЗИН';

  @override
  String get storeScanBeep => 'Бип! ✨';

  @override
  String get storeTapBasket =>
      'Нажми на корзину, чтобы уточка просканировала продукты';

  @override
  String get storeBasketScanning => 'Уточка сканирует продукты…';

  @override
  String rearDuckSemantics(Object name) {
    return 'Погладить уточку $name, вид сзади';
  }

  @override
  String get storeScanned => 'Отсканировано';

  @override
  String get storeCollected => 'Собрано';

  @override
  String storeSaveError(Object error) {
    return 'Не удалось сохранить покупки: $error';
  }

  @override
  String get storeReceiptTitle => 'Еда собрана!';

  @override
  String storeTotalPrice(int count, int price) {
    return 'Итого: $count товара · $price ₴';
  }

  @override
  String storePurchasesFor(Object name) {
    return 'Покупки для $name';
  }

  @override
  String get storeBringFood => 'Отнесём вкусности в инвентарь?';

  @override
  String get storeClaim => 'Забрать покупки в инвентарь';

  @override
  String get storeClaimed => 'Покупки в инвентаре!';

  @override
  String storeDuckCanEat(Object name) {
    return 'Теперь $name будет чем угостить 🦆';
  }

  @override
  String storeReturnToPet(Object name) {
    return 'Вернуться к $name';
  }

  @override
  String storeTakeItem(Object item) {
    return 'Взять $item';
  }

  @override
  String storeScannedItem(Object item) {
    return '$item, отсканирован';
  }

  @override
  String storeScanItem(Object item) {
    return 'Сканировать $item';
  }

  @override
  String get storePiece => '1 шт.';

  @override
  String get memoriesTitle => 'Капсула воспоминаний';

  @override
  String get memoriesSubtitle =>
      'Собирайте моменты, к которым хочется возвращаться';

  @override
  String get addMemory => 'Добавить воспоминание';

  @override
  String get pickPhoto => 'Выбрать фотографию';

  @override
  String get pickVideo => 'Выбрать видео';

  @override
  String saveMemoryError(Object error) {
    return 'Не удалось сохранить воспоминание: $error';
  }

  @override
  String get loadMemoriesError => 'Не удалось загрузить воспоминания.';

  @override
  String get captionTitle => 'Подпись к воспоминанию';

  @override
  String get captionHint => 'Например, наш вечер';

  @override
  String get cancel => 'Отмена';

  @override
  String get skip => 'Пропустить';

  @override
  String get save => 'Сохранить';

  @override
  String get memoryCaptionMissing => 'Без подписи';

  @override
  String get openPhoto => 'Открыть фотографию';

  @override
  String get openVideo => 'Открыть видео';

  @override
  String openMemoryCaption(Object caption) {
    return 'Открыть воспоминание: $caption';
  }

  @override
  String get close => 'Закрыть';

  @override
  String get videoUnavailable => 'Видео недоступно';

  @override
  String get mediaFileMissing => 'Выбранный файл не найден.';

  @override
  String get unknownAuthor => 'Неизвестно';

  @override
  String get dailyQuoteTitle => 'Кря-цитата дня';

  @override
  String get removeFavorite => 'Убрать из избранного';

  @override
  String get addFavorite => 'Добавить в избранное';

  @override
  String get showAnotherMoment => 'Показать другой момент';

  @override
  String get noSuitableMemory => 'Подходящего воспоминания пока нет.';

  @override
  String get noEligibleMemoryError =>
      'Пока не найдено подходящее воспоминание: нужны реплики обоих участников, без ссор и сервисных сообщений.';

  @override
  String get randomMemoryLoadError =>
      'Не получилось загрузить воспоминание. Проверьте файл экспорта чата.';

  @override
  String get favoriteUpdateError =>
      'Не удалось обновить избранное. Попробуйте ещё раз.';

  @override
  String get pairsTitle => 'Пары';

  @override
  String get pairSubtitle =>
      'Создайте локальную пару или введите код пары, уже сохранённой на этом устройстве.';

  @override
  String get pairLocalNotice =>
      'Данные пары сохраняются только на этом устройстве. Для синхронизации с другим устройством нужен настроенный сервер.';

  @override
  String get yourName => 'Ваше имя';

  @override
  String get pairNameSetupRequired =>
      'Сначала укажите своё имя в Совместном тамагочи.';

  @override
  String get enterYourName => 'Введите своё имя.';

  @override
  String get nameTooLong => 'Имя должно быть короче 40 символов.';

  @override
  String get invalidPairCode => 'Введите код пары из четырёх цифр.';

  @override
  String get pairNotFound =>
      'Пара с таким кодом не найдена на этом устройстве.';

  @override
  String get pairFull => 'В этой паре уже два участника.';

  @override
  String get createPair => 'Создать пару';

  @override
  String get pairCode => 'Код пары';

  @override
  String get joinPair => 'Присоединиться';

  @override
  String get pairCodeTitle => 'Код локальной пары (тест)';

  @override
  String get pairCodePrompt =>
      'Код работает только на этом устройстве. Для подключения другого устройства нужен сервер.';

  @override
  String get copy => 'Скопировать';

  @override
  String get done => 'Готово';

  @override
  String get yourPair => 'Ваша пара';

  @override
  String get waitingForPartner =>
      'Ожидаем второго участника. Код можно передать лично.';

  @override
  String get moodCalendarTitle => 'Календарь настроения';

  @override
  String get moodTodayPrompt => 'Как ты себя чувствуешь сегодня?';

  @override
  String get previousMonth => 'Предыдущий месяц';

  @override
  String get nextMonth => 'Следующий месяц';

  @override
  String get moodHistoryError => 'Не удалось загрузить историю настроения.';

  @override
  String get moodJoyful => 'Радостно';

  @override
  String get moodJoyfulResponseOne =>
      'Сохрани этот яркий момент — пусть утка тоже порадуется вместе с тобой.';

  @override
  String get moodJoyfulResponseTwo =>
      'Твоя улыбка сегодня заразительна. Подари её кому-нибудь рядом.';

  @override
  String get moodJoyfulResponseThree =>
      'Какой чудесный день! Устрой маленький праздник из обычного момента.';

  @override
  String get moodCalm => 'Спокойно';

  @override
  String get moodCalmResponseOne =>
      'Тихие дни тоже прекрасны. Можно просто побыть в своём ритме.';

  @override
  String get moodCalmResponseTwo =>
      'Уточка напоминает: не обязательно торопиться, чтобы всё успеть.';

  @override
  String get moodCalmResponseThree =>
      'Пусть сегодня будет побольше уютных пауз и любимого чая.';

  @override
  String get moodThoughtful => 'Обычно';

  @override
  String get moodThoughtfulResponseOne =>
      'Обычный день — отличная возможность заметить что-то хорошее вокруг.';

  @override
  String get moodThoughtfulResponseTwo =>
      'Добавь в день одну маленькую радость — уточка одобряет.';

  @override
  String get moodThoughtfulResponseThree =>
      'Даже спокойный день может спрятать приятный сюрприз.';

  @override
  String get moodTired => 'Устала';

  @override
  String get moodTiredResponseOne =>
      'Уточка советует устроить себе уютную передышку, если получится.';

  @override
  String get moodTiredResponseTwo =>
      'Сегодня можно выбрать самый мягкий темп и поберечь силы.';

  @override
  String get moodTiredResponseThree =>
      'Плед, вода и немного тишины — утка шлёт тебе поддержку.';

  @override
  String get moodBlue => 'Грустно';

  @override
  String get moodBlueResponseOne =>
      'Уточка рядом и желает тебе чего-нибудь тёплого и доброго.';

  @override
  String get moodBlueResponseTwo =>
      'Пусть сегодня найдётся хотя бы один маленький повод улыбнуться.';

  @override
  String get moodBlueResponseThree =>
      'Ты не обязана быть весёлой каждую минуту. Уточка просто посидит рядом.';

  @override
  String get moodAngry => 'Злюсь';

  @override
  String get moodAngryResponseOne =>
      'Злиться можно. Уточка рядом и поможет спокойно перевести дух.';

  @override
  String get moodAngryResponseTwo =>
      'Пусть гнев немного утихнет, а рядом найдётся место для твоих чувств.';

  @override
  String get moodAngryResponseThree =>
      'Уточка сердито топает лапкой вместе с тобой, а потом предлагает чай.';

  @override
  String get moodBlueReaction =>
      'Утка укутывает вас пледом и приносит чай. Можно просто поддержать друг друга.';

  @override
  String get moodJoyfulReaction =>
      'Утка приглашает вас на маленький праздничный танец!';

  @override
  String get moodOtherReaction =>
      'Утка напоминает: сегодня можно спросить друг друга, какая поддержка будет приятна.';

  @override
  String moodToday(Object mood) {
    return 'Сегодня: $mood';
  }

  @override
  String get moodResponse =>
      'Пусть сегодня найдётся маленький повод позаботиться о себе и немного порадоваться.';

  @override
  String get weekdayMon => 'Пн';

  @override
  String get weekdayTue => 'Вт';

  @override
  String get weekdayWed => 'Ср';

  @override
  String get weekdayThu => 'Чт';

  @override
  String get weekdayFri => 'Пт';

  @override
  String get weekdaySat => 'Сб';

  @override
  String get weekdaySun => 'Вс';

  @override
  String get moodParticipantOne => 'Участник 1';

  @override
  String get moodParticipantTwo => 'Участник 2';

  @override
  String get moodPairTitle => 'Настроение вдвоём';

  @override
  String get localPairDemo =>
      'Локальная демо-запись на этом устройстве. Для синхронизации нужен backend.';

  @override
  String get moodPairLoadError => 'Не удалось загрузить записи.';

  @override
  String get moodPairWaiting => 'Реакция уточки появится после двух отметок.';

  @override
  String get cinemaTitle => 'Кино-ночь';

  @override
  String get cinemaDailyNotice =>
      'Новый случайный выбор при каждом запуске. Свои фильмы и исключения сохраняются только на этом устройстве.';

  @override
  String get cinemaSpin => 'Крутить рулетку';

  @override
  String cinemaTodayMovie(Object title) {
    return 'Сегодня смотрим: $title';
  }

  @override
  String get cinemaWatchPrompt => 'Будем смотреть этот фильм?';

  @override
  String get cinemaWatched => 'Уже смотрели';

  @override
  String get cinemaSkipWeek => 'Не будем — убрать на неделю';

  @override
  String get cinemaWatchedSaved => 'Отличный выбор! Приятного вечера.';

  @override
  String get cinemaSkippedSaved => 'Фильм убран из рулетки на неделю.';

  @override
  String get cinemaNoFilms =>
      'На сегодня фильмов не осталось. Добавьте свой или попробуйте завтра.';

  @override
  String get cinemaManageFilms => 'Фильмы на сегодня';

  @override
  String get cinemaFilmHint => 'Например, Интерстеллар';

  @override
  String get cinemaAddFilm => 'Добавить фильм';

  @override
  String cinemaRemoveToday(Object title) {
    return 'Убрать $title из рулетки на сегодня';
  }

  @override
  String get cinemaActionError => 'Не удалось обновить список фильмов.';

  @override
  String get duckNeedsPair =>
      'Чтобы заботиться об уточке, сначала создайте пару или присоединитесь к ней в главном меню.';

  @override
  String get testCreatePair => 'Создать тестовую пару (временно)';

  @override
  String get testPairMemberName => 'Тестовый участник';

  @override
  String get duckNameLocalNotice =>
      'Имя уточки сохраняется только на этом устройстве. Синхронизация между участниками пока не подключена.';

  @override
  String get cinemaLike => 'нравится';

  @override
  String get cinemaDislike => 'не нравится';

  @override
  String get cinemaLocalNotice =>
      'Демо на одном устройстве: выборы видны здесь, но не синхронизируются и не являются приватным голосованием между устройствами.';

  @override
  String get tmdbNotice =>
      'This product uses the TMDB API but is not endorsed or certified by TMDB.';

  @override
  String get movieSearchLabel => 'Найти фильм в каталоге';

  @override
  String get movieSearchOnlineHint => 'Поиск по каталогу TMDB';

  @override
  String get movieSearchOfflineHint =>
      'Офлайн-каталог ограничен. Для расширенного поиска настройте TMDB_API_KEY через --dart-define; для production нужен backend proxy.';

  @override
  String get searchMovie => 'Найти фильм';

  @override
  String get movieSearchEmpty =>
      'Ничего не найдено. Попробуйте другое название.';

  @override
  String get addMovieLabel => 'Добавить фильм или мультик';

  @override
  String get addMovie => 'Добавить фильм';

  @override
  String get movieLoadError => 'Не удалось загрузить фильмы.';

  @override
  String get watched => 'Смотрели';

  @override
  String get alreadyWatched => 'Уже смотрели';

  @override
  String chooseSecretly(Object participant) {
    return '$participant, выбери тайно:';
  }

  @override
  String get voteSavedSecretly => 'Голос записан тайно.';

  @override
  String movieMatch(Object title) {
    return '🍿 Мэтч! Сегодня смотрим $title!';
  }

  @override
  String get movieNoMatch => 'Голоса не совпали — выберите другой фильм.';

  @override
  String movieAdded(Object title) {
    return '«$title» добавлен в список.';
  }

  @override
  String addMovieResult(Object title) {
    return 'Добавить $title';
  }

  @override
  String loadMorePages(int page, int totalPages) {
    return 'Показать ещё · $page/$totalPages';
  }

  @override
  String get movieMatchNotificationError =>
      'Не удалось показать локальное уведомление о мэтче.';

  @override
  String get secretNotesTitle => 'Секретные заметки';

  @override
  String get secretNotesSubtitle =>
      'Тёплые слова и сюрпризы, которые подождут своего момента';

  @override
  String get openPairs => 'Открыть раздел «Пары»';

  @override
  String get smallSurprise => 'Маленький сюрприз';

  @override
  String get postcardsTab => 'Открытки';

  @override
  String get postcardsTitle => 'Открытки';

  @override
  String get postcardsSubtitle =>
      'Здесь хранятся действительно отправленные и полученные открытки.';

  @override
  String get postcardPushUnavailable =>
      'LAN-сервер не настроен. Запустите сервер на ноутбуке, подключите оба телефона к той же Wi-Fi сети, затем укажите адрес и общий токен. Для получения нажмите «Обновить».';

  @override
  String get postcardLanConfigured =>
      'LAN-сервер настроен. Телефоны должны быть в той же Wi-Fi сети, сервер на ноутбуке — запущен. Новые открытки проверяются вручную.';

  @override
  String get postcardLanSettings => 'Настроить LAN-сервер';

  @override
  String get postcardLanUpdate => 'Обновить входящие';

  @override
  String get postcardLanSetupTitle => 'Подключение к серверу ноутбука';

  @override
  String get postcardLanEndpoint =>
      'Адрес ноутбука, например http://192.168.1.5:8787';

  @override
  String get postcardLanToken => 'Общий токен пары из терминала сервера';

  @override
  String get postcardLanSide => 'Этот телефон использует сторону';

  @override
  String get postcardLanFirst => 'Участник 1';

  @override
  String get postcardLanSecond => 'Участник 2';

  @override
  String get postcardLanSaved => 'Подключение к LAN-серверу сохранено.';

  @override
  String get postcardLanHttpWarning =>
      'Используйте только доверенную домашнюю Wi-Fi сеть: HTTP не шифрует трафик. Токен даёт доступ к открыткам пары.';

  @override
  String get postcardLanRefreshFailed =>
      'Не удалось получить открытки с LAN-сервера. Проверьте адрес, токен, Wi-Fi и firewall.';

  @override
  String get postcardsEmpty => 'Пока открыток нет.';

  @override
  String get postcardAll => 'Все';

  @override
  String get postcardSentTab => 'Отправленные';

  @override
  String get postcardReceivedTab => 'Полученные';

  @override
  String get postcardComposeTitle => 'Новая открытка';

  @override
  String get postcardRecipient => 'Имя партнёра';

  @override
  String get postcardMessage => 'Текст открытки';

  @override
  String get postcardSend => 'Отправить';

  @override
  String get postcardFieldsRequired =>
      'Укажите получателя и напишите текст открытки.';

  @override
  String get postcardSendFailed =>
      'Сервер не подтвердил сохранение открытки. Она не добавлена в отправленные.';

  @override
  String get postcardSent => 'Сервер сохранил открытку.';

  @override
  String get postcardLoadError => 'Не удалось загрузить архив открыток.';

  @override
  String postcardSentTo(Object name) {
    return 'Для: $name';
  }

  @override
  String postcardReceivedFrom(Object name) {
    return 'От: $name';
  }

  @override
  String get openPostcards => 'Открыть архив открыток';

  @override
  String get countdownTitle => 'Важные даты';

  @override
  String get addEvent => 'Добавить событие';

  @override
  String get countdownLoadError => 'Не удалось загрузить события.';

  @override
  String get countdownEmpty =>
      'Добавьте поездку, день рождения или другую важную дату.';

  @override
  String get editEvent => 'Изменить событие';

  @override
  String eventPassed(Object date) {
    return 'Это событие уже наступило · $date';
  }

  @override
  String untilEvent(Object date) {
    return 'До события $date';
  }

  @override
  String get rememberThisDay => 'Сохраняем этот день в памяти';

  @override
  String get eventToday => 'Событие уже сегодня';

  @override
  String daysRemaining(int days) {
    return 'Осталось $days дн.';
  }

  @override
  String get newEvent => 'Новое событие';

  @override
  String get eventTitleHint => 'Например, поездка';

  @override
  String saveEventError(Object error) {
    return 'Не удалось сохранить событие: $error';
  }

  @override
  String deleteEventError(Object error) {
    return 'Не удалось удалить событие: $error';
  }

  @override
  String editEventNamed(Object title) {
    return 'Изменить событие $title';
  }

  @override
  String deleteEventNamed(Object title) {
    return 'Удалить событие $title';
  }

  @override
  String get timeCapsuleTitle => 'Капсула времени';

  @override
  String get timeCapsuleSubtitle => 'Оставьте записку или фото для будущего';

  @override
  String get createTimeCapsule => 'Создать капсулу времени';

  @override
  String get timeCapsuleLoadError => 'Не удалось загрузить капсулы времени.';

  @override
  String get timeCapsuleEmpty =>
      'Пока нет капсул. Создайте первую для себя в будущем.';

  @override
  String createCapsuleError(Object error) {
    return 'Не удалось создать капсулу: $error';
  }

  @override
  String openCapsuleFrom(Object date) {
    return 'Открыть капсулу от $date';
  }

  @override
  String sealedUntil(Object date) {
    return 'Запечатана до $date';
  }

  @override
  String get capsuleOpened => 'Капсула открыта';

  @override
  String get capsuleSealed => 'Капсула запечатана';

  @override
  String get rouletteTitle => 'Рулетка свиданий';

  @override
  String get rouletteSubtitle => 'Выберите категорию и доверьте выбор случаю';

  @override
  String get rouletteFood => 'Еда';

  @override
  String get rouletteMovie => 'Кино';

  @override
  String get rouletteActivity => 'Занятия';

  @override
  String get rouletteSpin => 'Крутить';

  @override
  String get rouletteSpinAgain => 'Крутить ещё';

  @override
  String get rouletteResult => 'Сегодня выбираем:';

  @override
  String get rouletteAddChoice => 'Добавить вариант';

  @override
  String get rouletteChoiceHint => 'Например, приготовить пасту';

  @override
  String get rouletteEmpty =>
      'Добавьте хотя бы один вариант, чтобы запустить рулетку.';

  @override
  String rouletteRemoveChoice(Object choice) {
    return 'Удалить вариант $choice';
  }

  @override
  String get rouletteSavedChoice => 'Вариант добавлен';

  @override
  String get rouletteError => 'Не удалось сохранить варианты рулетки.';

  @override
  String get timeCapsuleOpen => 'Можно посмотреть';

  @override
  String timeCapsuleOpensOn(Object date) {
    return 'Откроется $date';
  }

  @override
  String get newTimeCapsule => 'Новая капсула времени';

  @override
  String get timeCapsuleNoteHint => 'Записка для себя в будущем';

  @override
  String get attachPhoto => 'Прикрепить фото';

  @override
  String get photoSelected => 'Фото выбрано';

  @override
  String openOnDate(Object date) {
    return 'Открыть: $date';
  }

  @override
  String get sealCapsule => 'Запечатать';

  @override
  String choosePhotoError(Object error) {
    return 'Не удалось выбрать фото: $error';
  }

  @override
  String get capsuleNeedsContent => 'Добавьте текст или выберите фото.';

  @override
  String get photoUnavailable => 'Фото недоступно';

  @override
  String get rouletteFoodOptionCook => 'Приготовить вместе';

  @override
  String get rouletteFoodOptionOrder => 'Заказать любимую еду';

  @override
  String get rouletteFoodOptionCafe => 'Сходить в кафе';

  @override
  String get rouletteFoodOptionPicnic => 'Устроить пикник';

  @override
  String get rouletteFoodOptionDessert => 'Испечь десерт';

  @override
  String get rouletteMovieOptionRomcom => 'Романтическая комедия';

  @override
  String get rouletteMovieOptionCartoon => 'Мультфильм';

  @override
  String get rouletteMovieOptionFavorite => 'Любимый фильм';

  @override
  String get rouletteMovieOptionNew => 'Найти что-то новое';

  @override
  String get rouletteMovieOptionNight => 'Устроить кино-ночь';

  @override
  String get rouletteActivityOptionWalk => 'Прогуляться вместе';

  @override
  String get rouletteActivityOptionBoardGame => 'Сыграть в настольную игру';

  @override
  String get rouletteActivityOptionPhoto => 'Сделать фото-прогулку';

  @override
  String get rouletteActivityOptionHomeDate => 'Устроить домашнее свидание';

  @override
  String get rouletteActivityOptionMusic => 'Послушать музыку';

  @override
  String get warehouseTitle => 'Работа на складе';

  @override
  String get warehouseSubtitle =>
      'Лови падающие коробки, двигая рохлю. Поймай все 15!';

  @override
  String get warehouseSceneSemantics =>
      'Склад: перетаскивай пальцем, чтобы двигать рохлю и ловить коробки.';

  @override
  String get warehouseStart => 'Начать смену';

  @override
  String get warehouseTired => 'Уточка устала. Ей нужно отдохнуть.';

  @override
  String warehouseCooldownRemaining(int hours, int minutes) {
    return 'Вернуться на работу можно через $hours ч $minutes мин.';
  }

  @override
  String warehouseProgress(int caught, int total) {
    return 'Завершено: $caught из $total';
  }

  @override
  String warehouseCaught(int count) {
    return 'Поймано: $count';
  }

  @override
  String warehouseMissed(int count) {
    return 'Мимо: $count';
  }

  @override
  String get warehouseMoveLeft => 'Двигать рохлю влево';

  @override
  String get warehouseMoveRight => 'Двигать рохлю вправо';

  @override
  String get warehouseControlsHint => 'Перетащи по складу или нажимай стрелки';

  @override
  String get warehouseResultPerfectTitle => 'Отличная смена!';

  @override
  String get warehouseResultPartialTitle => 'Хорошая работа!';

  @override
  String get warehouseResultFailureTitle => 'Смена завершена';

  @override
  String get warehouseResultPerfectMessage =>
      'Пойманы все коробки — уточка гордится тобой!';

  @override
  String get warehouseResultPartialMessage =>
      'Больше половины коробок пойманы. Неплохо!';

  @override
  String get warehouseResultFailureMessage =>
      'Поймано меньше половины коробок. Попробуем позже.';

  @override
  String warehouseReward(int amount) {
    return 'Заработано: $amount ₴';
  }

  @override
  String get warehouseReturnHome => 'На главную';

  @override
  String get warehouseRetrySave => 'Повторить';

  @override
  String warehouseWorkSaveError(Object error) {
    return 'Не удалось сохранить смену на складе: $error';
  }

  @override
  String get groceryStoreTab => 'Магазин';

  @override
  String get groceryWorkTab => 'Работа';
}
