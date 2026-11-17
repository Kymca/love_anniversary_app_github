// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Кохання';

  @override
  String get appUpdateMessage => 'Доступне оновлення';

  @override
  String get appUpdateAction => 'Оновити';

  @override
  String get appUpdateInstalling => 'Підготовка…';

  @override
  String get appUpdateDismiss => 'Пізніше';

  @override
  String get appUpdatePermissionHint =>
      'Дозвольте встановлення для цього застосунку в налаштуваннях Android, потім натисніть «Оновити» ще раз.';

  @override
  String get appUpdateFailed =>
      'Не вдалося завантажити оновлення. Спробуйте пізніше.';

  @override
  String get homeTab => 'Наша історія';

  @override
  String get petTab => 'Тамагочі';

  @override
  String get memoriesTab => 'Спогади';

  @override
  String get couponsTab => 'Купони';

  @override
  String get notesTab => 'Нотатки';

  @override
  String get pairsTab => 'Пари';

  @override
  String get settingsTab => 'Налаштування';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get rouletteTab => 'Рулетка';

  @override
  String get duckShortcut => 'Наша качечка';

  @override
  String get sendHeart => 'Надіслати серденько';

  @override
  String get homeEyebrow => 'НАША ІСТОРІЯ';

  @override
  String get homeHeadline => 'Разом — з кожною миттю';

  @override
  String get couponTitle => 'Купони на бажання';

  @override
  String get couponSubtitle => 'Маленькі радощі, які можна активувати';

  @override
  String get couponLoading => 'Завантажуємо купони…';

  @override
  String get couponLoadError => 'Не вдалося завантажити купони.';

  @override
  String get couponRetry => 'Спробувати ще раз';

  @override
  String get couponEmptyTitle => 'Поки немає купонів';

  @override
  String get couponEmptyDescription =>
      'Тут з\'являться ваші бажання та сюрпризи.';

  @override
  String get couponNotificationNotConfigured =>
      'Push-сповіщення на пристрій партнера поки не підключені.';

  @override
  String get couponActivationError => 'Не вдалося зберегти активацію купона.';

  @override
  String get couponScratchHint => 'Проведи пальцем, щоб стерти';

  @override
  String get couponActivate => 'Активувати';

  @override
  String get couponUsed => 'Вже використаний';

  @override
  String get couponMonthly => 'Можна раз на місяць';

  @override
  String get couponOneTime => 'Одноразовий';

  @override
  String get couponDaily => 'Щоденний купон';

  @override
  String get dailyCouponTitle => 'Маленьке бажання дня';

  @override
  String get dailyCouponDescription =>
      'Обери приємний сюрприз для нас сьогодні.';

  @override
  String get dailyCouponExpired => 'Термін цього щоденного купона минув';

  @override
  String get couponCallbackError => 'Не вдалося виконати дію купона.';

  @override
  String get couponNotificationWarning =>
      'Купон активовано, але сповіщення не вдалося показати.';

  @override
  String get notificationDenied =>
      'Купон активовано. Локальні сповіщення вимкнені або недоступні.';

  @override
  String get notificationFailure =>
      'Купон активовано. Не вдалося показати локальне сповіщення.';

  @override
  String get overlayPetTapHint => 'Торкніться качечки, щоб потішити її';

  @override
  String pairCreateError(Object error) {
    return 'Не вдалося створити пару: $error';
  }

  @override
  String get anonymousSignInDisabled =>
      'Щоб створити пару, увімкніть анонімні входи в Supabase: Auth > Sign In / Providers > Anonymous Sign-Ins.';

  @override
  String get pairAuthUnavailable =>
      'Не вдалося увійти через Supabase. Спробуйте пізніше.';

  @override
  String get relationshipStarted => 'З 14 листопада 2023 року';

  @override
  String get beginning => 'І це лише початок ♥';

  @override
  String get couponActivatedMessage =>
      'Купон активовано! Качечка несе тобі радість!';

  @override
  String get language => 'Мова';

  @override
  String get russian => 'Русский';

  @override
  String get ukrainian => 'Українська';

  @override
  String durationYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count року',
      many: '$count років',
      few: '$count роки',
      one: '$count рік',
    );
    return '$_temp0';
  }

  @override
  String durationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count місяця',
      many: '$count місяців',
      few: '$count місяці',
      one: '$count місяць',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count днів',
      few: '$count дні',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count години',
      many: '$count годин',
      few: '$count години',
      one: '$count година',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count хвилини',
      many: '$count хвилин',
      few: '$count хвилини',
      one: '$count хвилина',
    );
    return '$_temp0';
  }

  @override
  String durationSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count секунди',
      many: '$count секунд',
      few: '$count секунди',
      one: '$count секунда',
    );
    return '$_temp0';
  }

  @override
  String get nameDuckTitle => 'Як назвемо качечку? 🦆';

  @override
  String get participantNameTitle => 'Як звати учасників?';

  @override
  String participantNameLabel(int number) {
    return 'Ім\'я учасника $number';
  }

  @override
  String get participantNamePrompt =>
      'Імена зберігаються окремо від підключення пари.';

  @override
  String get editParticipantName => 'Змінити ім\'я';

  @override
  String get defaultDuckName => 'Кряква';

  @override
  String get duckNameHint => 'Кряква';

  @override
  String get getAcquainted => 'Знайомитися!';

  @override
  String get petScreenTitle => 'Наш спільний тамагочі';

  @override
  String get familyTitle => 'Наша маленька родина';

  @override
  String petAge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня разом із вами',
      many: '$count днів разом із вами',
      few: '$count дні разом із вами',
      one: '$count день разом із вами',
    );
    return '$_temp0';
  }

  @override
  String get rename => 'Перейменувати';

  @override
  String overlayTitle(Object name) {
    return 'Випустити $name на екран';
  }

  @override
  String duckNamed(Object name) {
    return 'Качечка $name';
  }

  @override
  String get overlayAndroid => 'Качечка плаватиме поверх інших програм';

  @override
  String get overlayUnavailable => 'Плаваюче вікно доступне лише на Android';

  @override
  String get overlayPermission => 'Дозвольте показ поверх інших програм.';

  @override
  String overlayLaunchError(Object error) {
    return 'Не вдалося запустити оверлей: $error';
  }

  @override
  String get petSemantics => 'Погладити качечку';

  @override
  String get petWearLeatherJacket => 'Одягнути чорну шкірянку';

  @override
  String get petRemoveLeatherJacket => 'Зняти шкірянку';

  @override
  String get wardrobeEntry => 'Гардероб';

  @override
  String get wardrobeTitle => 'Гардероб качечки';

  @override
  String get wardrobeShopTitle => 'Магазин костюмів';

  @override
  String get wardrobeDefaultName => 'Звичайний образ';

  @override
  String get wardrobeDefaultDescription =>
      'Простий і затишний образ — безкоштовно.';

  @override
  String get wardrobeJacketName => 'Чорна шкіряна куртка';

  @override
  String get wardrobeJacketDescription =>
      'Стильна чорна шкіряна куртка по фігурі.';

  @override
  String get wardrobeHeartPajamasName => 'Піжама із сердечками';

  @override
  String get wardrobeHeartPajamasDescription =>
      'М\'яка рожева піжама із сердечками для солодких снів.';

  @override
  String get wardrobeFree => 'Безкоштовно';

  @override
  String wardrobePrice(int price) {
    return '$price ₴';
  }

  @override
  String get wardrobeTapToPreview => 'Натисни на образ, щоб переглянути';

  @override
  String wardrobePreviewTitle(Object name) {
    return 'Перегляд: $name';
  }

  @override
  String wardrobeInsufficientFunds(int price, int balance) {
    return 'Недостатньо коштів: потрібно $price ₴, на балансі $balance ₴.';
  }

  @override
  String get wardrobeOwned => 'Придбано';

  @override
  String get wardrobeSelected => 'Обрано';

  @override
  String get wardrobeChoose => 'Обрати';

  @override
  String get wardrobeBuying => 'Купівля…';

  @override
  String get wardrobeBuy => 'Купити';

  @override
  String get moodHappy => 'Кря-кря! Який чудовий день!';

  @override
  String get moodHungry => 'Здається, я трохи зголодніла…';

  @override
  String get moodVeryHungry => 'Качечка дуже хоче їсти…';

  @override
  String get satiety => 'Ситість';

  @override
  String get dailyHungerLoss => 'Щодня без частування −25%';

  @override
  String get feedDuck => 'Почастуй качечку';

  @override
  String get feedVarietyRequired =>
      'Качечці потрібне різноманіття — запропонуй їй щось інше.';

  @override
  String get tamagotchiHelpTitle => 'Як піклуватися про качечку';

  @override
  String get tamagotchiHelpCare =>
      'Ситість зменшується на 25% за кожен день без їжі. Якщо не годувати 4 дні, качечка піде.';

  @override
  String get tamagotchiHelpFeed =>
      'Натискай на їжу або продукти з магазину. Одну й ту саму їжу можна дати двічі поспіль, але втретє качечка попросить різноманіття. Історія зберігається.';

  @override
  String get tamagotchiHelpPlay =>
      'Натисни на качечку, щоб погратися й потішити її. У гардеробі можна приміряти, купувати та вдягати образи.';

  @override
  String get foodCrumbs => 'Крихти';

  @override
  String get foodWorm => 'Черв\'ячок';

  @override
  String get foodWatermelon => 'Кавунчик';

  @override
  String get foodBreadCrumbs => 'Крихти';

  @override
  String get foodWatermelonStore => 'Кавун';

  @override
  String get foodWorms => 'Черв\'ячки';

  @override
  String get foodPizza => 'Піца';

  @override
  String get foodApple => 'Яблуко';

  @override
  String get foodCheese => 'Сир';

  @override
  String get foodCarrot => 'Морква';

  @override
  String get foodMilk => 'Молоко';

  @override
  String get foodCrumbsSnack => 'крихти';

  @override
  String get foodWormSnack => 'черв\'ячка';

  @override
  String get foodWatermelonSnack => 'кавунчик';

  @override
  String get foodWatermelonStoreSnack => 'кавун';

  @override
  String get foodPizzaSnack => 'піцу';

  @override
  String feedConfirmation(Object name, Object food) {
    return '$name із задоволенням з\'їла $food! 💚';
  }

  @override
  String get inventoryHint => 'Покупки з магазину — натисни, щоб нагодувати:';

  @override
  String get goToStore => 'Продуктовий магазин';

  @override
  String get goToWarehouseWork => 'Робота на складі';

  @override
  String duckWalletBalance(int balance) {
    return 'Баланс: $balance ₴';
  }

  @override
  String careDay(Object name, Object caregiver) {
    return 'Сьогодні день турботи про $name у $caregiver';
  }

  @override
  String get you => 'тебе';

  @override
  String get yourPartner => 'твоєї половинки';

  @override
  String comingSoonOutfits(Object name) {
    return 'Магазин костюмів для $name';
  }

  @override
  String runawayTitle(Object name) {
    return '$name полетіла шукати їжу...';
  }

  @override
  String get runawayDescription => 'Здається, їй дуже бракувало вашої турботи.';

  @override
  String get callDuckBack => 'Покликати назад';

  @override
  String get storeTitle => 'Похід до магазину';

  @override
  String get storeChooseProducts => 'Обери продукти на полицях';

  @override
  String get storeChooseAtLeastOne => 'Обери хоча б один продукт';

  @override
  String storeWalletStatus(int balance, int price) {
    return 'Баланс: $balance ₴ · кошик: $price ₴';
  }

  @override
  String get storeInsufficientFundsTitle => 'Не вистачає гривень';

  @override
  String storeInsufficientFunds(int balance, int price) {
    return 'На балансі $balance ₴, а товар коштує $price ₴. Прибери товар із кошика або обери інший.';
  }

  @override
  String storeReplaceLastItem(Object item) {
    return 'Прибрати один товар і взяти $item';
  }

  @override
  String get storeChooseAnother => 'Обрати інший товар';

  @override
  String get storeCheckout => 'Перейти до каси';

  @override
  String storeChooseAll(int collected, int total) {
    return 'Обери всі продукти ($collected/$total)';
  }

  @override
  String storeCheckoutPrompt(Object name) {
    return '$name біля каси! Натисни на кошик, щоб качечка просканувала продукти';
  }

  @override
  String get storeSign => 'МАГАЗИН';

  @override
  String get storeScanBeep => 'Біп! ✨';

  @override
  String get storeTapBasket =>
      'Натисни на кошик, щоб качечка просканувала продукти';

  @override
  String get storeBasketScanning => 'Качечка сканує продукти…';

  @override
  String rearDuckSemantics(Object name) {
    return 'Погладити качечку $name, вигляд ззаду';
  }

  @override
  String get storeScanned => 'Проскановано';

  @override
  String get storeCollected => 'Зібрано';

  @override
  String storeSaveError(Object error) {
    return 'Не вдалося зберегти покупки: $error';
  }

  @override
  String get storeReceiptTitle => 'Їжу зібрано!';

  @override
  String storeTotalPrice(int count, int price) {
    return 'Разом: $count товар(и) · $price ₴';
  }

  @override
  String storePurchasesFor(Object name) {
    return 'Покупки для $name';
  }

  @override
  String get storeBringFood => 'Віднесемо смаколики до інвентарю?';

  @override
  String get storeClaim => 'Забрати покупки до інвентарю';

  @override
  String get storeClaimed => 'Покупки в інвентарі!';

  @override
  String storeDuckCanEat(Object name) {
    return 'Тепер $name буде чим почастувати 🦆';
  }

  @override
  String storeReturnToPet(Object name) {
    return 'Повернутися до $name';
  }

  @override
  String storeTakeItem(Object item) {
    return 'Взяти: $item';
  }

  @override
  String storeScannedItem(Object item) {
    return '$item, відскановано';
  }

  @override
  String storeScanItem(Object item) {
    return 'Сканувати: $item';
  }

  @override
  String get storePiece => '1 шт.';

  @override
  String get memoriesTitle => 'Капсула спогадів';

  @override
  String get memoriesSubtitle => 'Збирайте миті, до яких хочеться повертатися';

  @override
  String get addMemory => 'Додати спогад';

  @override
  String get pickPhoto => 'Вибрати фото';

  @override
  String get pickVideo => 'Вибрати відео';

  @override
  String saveMemoryError(Object error) {
    return 'Не вдалося зберегти спогад: $error';
  }

  @override
  String get loadMemoriesError => 'Не вдалося завантажити спогади.';

  @override
  String get captionTitle => 'Підпис до спогаду';

  @override
  String get captionHint => 'Наприклад, наш вечір';

  @override
  String get cancel => 'Скасувати';

  @override
  String get skip => 'Пропустити';

  @override
  String get save => 'Зберегти';

  @override
  String get memoryCaptionMissing => 'Без підпису';

  @override
  String get openPhoto => 'Відкрити фото';

  @override
  String get openVideo => 'Відкрити відео';

  @override
  String openMemoryCaption(Object caption) {
    return 'Відкрити спогад: $caption';
  }

  @override
  String get close => 'Закрити';

  @override
  String get videoUnavailable => 'Відео недоступне';

  @override
  String get mediaFileMissing => 'Вибраний файл не знайдено.';

  @override
  String get unknownAuthor => 'Невідомо';

  @override
  String get dailyQuoteTitle => 'Кря-цитата дня';

  @override
  String get removeFavorite => 'Прибрати з обраного';

  @override
  String get addFavorite => 'Додати до обраного';

  @override
  String get showAnotherMoment => 'Показати іншу мить';

  @override
  String get noSuitableMemory => 'Поки немає відповідного спогаду.';

  @override
  String get noEligibleMemoryError =>
      'Поки не знайдено відповідного спогаду: потрібні репліки обох учасників, без сварок і службових повідомлень.';

  @override
  String get randomMemoryLoadError =>
      'Не вдалося завантажити спогад. Перевірте файл експорту чату.';

  @override
  String get favoriteUpdateError =>
      'Не вдалося оновити обране. Спробуйте ще раз.';

  @override
  String get pairsTitle => 'Пари';

  @override
  String get pairSubtitle => 'Створіть пару та передайте код другому учаснику.';

  @override
  String get yourName => 'Ваше ім\'я';

  @override
  String get pairNameSetupRequired => 'Введіть ім\'я учасника.';

  @override
  String get pairEmailAuthTitle =>
      'Створити обліковий запис / увійти за email-кодом';

  @override
  String get pairEmailAuthDescription =>
      'Під’єднайте email-код, щоб створити обліковий запис або увійти з іншого пристрою. Підтвердження пошти не потрібне, щоб створити пару або приєднатися до неї.';

  @override
  String get pairEmailLabel => 'Електронна пошта';

  @override
  String get pairSendEmailCode => 'Надіслати код';

  @override
  String get pairEmailCodeLabel => 'Код із листа';

  @override
  String get pairConfirmEmailCode => 'Підтвердити email';

  @override
  String pairEmailVerified(Object email) {
    return 'Пошту прив\'язано: $email';
  }

  @override
  String get pairEmailAuthRequired =>
      'Створювати пару та приєднуватися до неї можна без підтвердження email, зокрема анонімно.';

  @override
  String get pairEmailOptional =>
      'Підтверджувати пошту не обов’язково, щоб створити пару або приєднатися до неї.';

  @override
  String get pairBackendUpdateRequired =>
      'Щоб створювати пари без обов’язкової пошти, оновіть міграції Supabase.';

  @override
  String get pairEmailAuthError =>
      'Не вдалося підтвердити email. Перевірте адресу й код та спробуйте ще раз.';

  @override
  String pairEmailSendCodeError(Object error) {
    return 'Supabase не надіслав код: $error';
  }

  @override
  String get pairEmailRateLimitError =>
      'Supabase тимчасово обмежив надсилання листів. Код не надіслано. Не повторюйте запити — дочекайтеся оновлення ліміту. Якщо це часто трапляється, власник проєкту може налаштувати власний SMTP або Send Email Hook.';

  @override
  String pairEmailVerifyCodeError(Object error) {
    return 'Supabase не підтвердив код: $error';
  }

  @override
  String get pairEmailAuthUnavailable =>
      'Вхід за email зараз недоступний. Спробуйте пізніше.';

  @override
  String get breakPair => 'Розірвати пару';

  @override
  String get breakPairTitle => 'Розірвати пару?';

  @override
  String get breakPairWarning =>
      'Пару та всі її спільні дані буде видалено без можливості відновлення. Ваш обліковий запис залишиться активним.';

  @override
  String get breakPairConfirm => 'Видалити пару й дані';

  @override
  String get pairDeleteError => 'Не вдалося видалити пару. Спробуйте ще раз.';

  @override
  String get pairEmailNotVerified =>
      'Пошту не підтверджено. Пару все одно можна створити або приєднатися до неї.';

  @override
  String get enterYourName => 'Введіть своє ім\'я.';

  @override
  String get nameTooLong => 'Ім\'я має бути коротшим за 40 символів.';

  @override
  String get invalidPairCode => 'Введіть код пари з чотирьох цифр.';

  @override
  String get pairNotFound => 'Пару з таким кодом не знайдено.';

  @override
  String get pairFull => 'У цій парі вже є два учасники.';

  @override
  String get pairAlreadyInPair =>
      'Ви вже перебуваєте в парі. Відкрийте наявну пару замість створення нової.';

  @override
  String get backendConnectionError =>
      'Не вдалося зв’язатися із сервером. Перевірте з’єднання та спробуйте ще раз.';

  @override
  String get createPair => 'Створити пару';

  @override
  String get pairCode => 'Код пари';

  @override
  String get joinPair => 'Приєднатися';

  @override
  String get pairCodeTitle => 'Код пари';

  @override
  String get pairCodePrompt =>
      'Передайте цей код другому учаснику, щоб під’єднати його до вашої пари.';

  @override
  String get copy => 'Скопіювати';

  @override
  String get done => 'Готово';

  @override
  String get yourPair => 'Ваша пара';

  @override
  String get waitingForPartner =>
      'Очікуємо на другого учасника. Код можна передати особисто.';

  @override
  String get moodCalendarTitle => 'Календар настрою';

  @override
  String get moodTodayPrompt => 'Як ти почуваєшся сьогодні?';

  @override
  String get previousMonth => 'Попередній місяць';

  @override
  String get nextMonth => 'Наступний місяць';

  @override
  String get moodHistoryError => 'Не вдалося завантажити історію настрою.';

  @override
  String get moodJoyful => 'Радісно';

  @override
  String get moodJoyfulResponseOne =>
      'Збережи цю яскраву мить — нехай качечка теж порадіє разом із тобою.';

  @override
  String get moodJoyfulResponseTwo =>
      'Твоя усмішка сьогодні заразлива. Поділися нею з кимось поруч.';

  @override
  String get moodJoyfulResponseThree =>
      'Який чудовий день! Влаштуй маленьке свято зі звичайної миті.';

  @override
  String get moodCalm => 'Спокійно';

  @override
  String get moodCalmResponseOne =>
      'Тихі дні теж прекрасні. Можна просто побути у своєму ритмі.';

  @override
  String get moodCalmResponseTwo =>
      'Качечка нагадує: не обов\'язково поспішати, щоб усе встигнути.';

  @override
  String get moodCalmResponseThree =>
      'Нехай сьогодні буде більше затишних пауз і улюбленого чаю.';

  @override
  String get moodThoughtful => 'Звичайно';

  @override
  String get moodThoughtfulResponseOne =>
      'Звичайний день — чудова нагода помітити щось хороше навколо.';

  @override
  String get moodThoughtfulResponseTwo =>
      'Додай до дня одну маленьку радість — качечка схвалює.';

  @override
  String get moodThoughtfulResponseThree =>
      'Навіть спокійний день може приховати приємний сюрприз.';

  @override
  String get moodTired => 'Втомилася';

  @override
  String get moodTiredResponseOne =>
      'Качечка радить влаштувати собі затишний перепочинок, якщо вийде.';

  @override
  String get moodTiredResponseTwo =>
      'Сьогодні можна обрати найм\'якший темп і поберегти сили.';

  @override
  String get moodTiredResponseThree =>
      'Плед, вода й трохи тиші — качечка надсилає тобі підтримку.';

  @override
  String get moodBlue => 'Сумно';

  @override
  String get moodBlueResponseOne =>
      'Качечка поруч і бажає тобі чогось теплого й доброго.';

  @override
  String get moodBlueResponseTwo =>
      'Нехай сьогодні знайдеться хоча б один маленький привід усміхнутися.';

  @override
  String get moodBlueResponseThree =>
      'Ти не мусиш бути веселою щохвилини. Качечка просто посидить поруч.';

  @override
  String get moodAngry => 'Злюся';

  @override
  String get moodAngryResponseOne =>
      'Злитися можна. Качечка поруч і допоможе спокійно перевести подих.';

  @override
  String get moodAngryResponseTwo =>
      'Нехай гнів трохи вщухне, а поруч знайдеться місце для твоїх почуттів.';

  @override
  String get moodAngryResponseThree =>
      'Качечка сердито тупає лапкою разом із тобою, а потім пропонує чай.';

  @override
  String get moodBlueReaction =>
      'Качечка вкриває вас пледом і приносить чай. Можна просто підтримати одне одного.';

  @override
  String get moodJoyfulReaction =>
      'Качечка запрошує вас на маленький святковий танець!';

  @override
  String get moodOtherReaction =>
      'Качечка нагадує: сьогодні можна запитати одне одного, яка підтримка буде приємною.';

  @override
  String moodToday(Object mood) {
    return 'Сьогодні: $mood';
  }

  @override
  String get moodChange => 'Змінити настрій';

  @override
  String get moodChangeTitle => 'Обери настрій';

  @override
  String moodHistoryForDate(Object date) {
    return 'Настрій за $date';
  }

  @override
  String get moodNoHistory => 'Для цієї дати ще немає записів.';

  @override
  String get moodHistoryLatest => 'зараз';

  @override
  String get moodHistoryTimeUnknown => 'Час не збережено';

  @override
  String get duckOwnedByYouToday => 'Сьогодні качечка у вас.';

  @override
  String duckOwnedByPartnerToday(Object name) {
    return 'Сьогодні качечка в учасника: $name.';
  }

  @override
  String get duckMoodEnvelopeClosed =>
      'Настрій партнера. Натисніть, щоб відкрити.';

  @override
  String duckMoodEnvelopeOpen(Object mood) {
    return 'Настрій партнера: $mood';
  }

  @override
  String get duckNotOwnerAction =>
      'Сьогодні піклуватися про качечку може лише її власник.';

  @override
  String get moodResponse =>
      'Нехай сьогодні знайдеться маленький привід подбати про себе й трохи порадіти.';

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
  String get weekdaySun => 'Нд';

  @override
  String get moodParticipantOne => 'Учасник 1';

  @override
  String get moodParticipantTwo => 'Учасник 2';

  @override
  String get moodPairTitle => 'Настрій удвох';

  @override
  String get localPairDemo =>
      'Локальний демозапис на цьому пристрої. Для синхронізації потрібен backend.';

  @override
  String get moodPairLoadError => 'Не вдалося завантажити записи.';

  @override
  String get moodPairWaiting =>
      'Реакція качечки з\'явиться після двох позначок.';

  @override
  String get cinemaTitle => 'Кіноніч';

  @override
  String get cinemaDailyNotice =>
      'Новий випадковий вибір під час кожного запуску. Власні фільми та виключення зберігаються лише на цьому пристрої.';

  @override
  String get cinemaSpin => 'Крутити рулетку';

  @override
  String cinemaTodayMovie(Object title) {
    return 'Сьогодні дивимося: $title';
  }

  @override
  String get cinemaWatchPrompt => 'Дивимось цей фільм?';

  @override
  String get cinemaWatched => 'Уже дивилися';

  @override
  String get cinemaSkipWeek => 'Не будемо — прибрати на тиждень';

  @override
  String get cinemaWatchedSaved => 'Чудовий вибір! Гарного вечора.';

  @override
  String get cinemaSkippedSaved => 'Фільм прибрано з рулетки на тиждень.';

  @override
  String get cinemaNoFilms =>
      'На сьогодні фільми закінчилися. Додайте свій або спробуйте завтра.';

  @override
  String get cinemaManageFilms => 'Фільми на сьогодні';

  @override
  String get cinemaFilmHint => 'Наприклад, Інтерстеллар';

  @override
  String get cinemaAddFilm => 'Додати фільм';

  @override
  String cinemaRemoveToday(Object title) {
    return 'Прибрати $title з рулетки на сьогодні';
  }

  @override
  String get cinemaActionError => 'Не вдалося оновити список фільмів.';

  @override
  String get duckNeedsPair =>
      'Щоб піклуватися про качечку, спочатку створіть пару або приєднайтеся до неї в головному меню.';

  @override
  String get testCreatePair => 'Створити тестову пару (тимчасово)';

  @override
  String get testPairMemberName => 'Тестовий учасник';

  @override
  String get duckNameLocalNotice =>
      'Ім\'я качечки зберігається лише на цьому пристрої. Синхронізацію між учасниками ще не підключено.';

  @override
  String get duckNameSynchronizedNotice =>
      'Ім\'я качечки синхронізується між учасниками пари.';

  @override
  String get sharedPairSyncNotice =>
      'Настрої синхронізуються між учасниками пари.';

  @override
  String get cinemaLike => 'подобається';

  @override
  String get cinemaDislike => 'не подобається';

  @override
  String get cinemaLocalNotice =>
      'Демо на одному пристрої: вибори видимі тут, але не синхронізуються та не є приватним голосуванням між пристроями.';

  @override
  String get tmdbNotice =>
      'This product uses the TMDB API but is not endorsed or certified by TMDB.';

  @override
  String get movieSearchLabel => 'Знайти фільм у каталозі';

  @override
  String get movieSearchOnlineHint => 'Пошук у каталозі TMDB';

  @override
  String get movieSearchOfflineHint =>
      'Офлайн-каталог обмежений. Для розширеного пошуку налаштуйте TMDB_API_KEY через --dart-define; для production потрібен backend proxy.';

  @override
  String get searchMovie => 'Знайти фільм';

  @override
  String get movieSearchEmpty => 'Нічого не знайдено. Спробуйте іншу назву.';

  @override
  String get addMovieLabel => 'Додати фільм або мультфільм';

  @override
  String get addMovie => 'Додати фільм';

  @override
  String get movieLoadError => 'Не вдалося завантажити фільми.';

  @override
  String get watched => 'Дивилися';

  @override
  String get alreadyWatched => 'Уже дивилися';

  @override
  String chooseSecretly(Object participant) {
    return '$participant, обери таємно:';
  }

  @override
  String get voteSavedSecretly => 'Голос записано таємно.';

  @override
  String movieMatch(Object title) {
    return '🍿 Метч! Сьогодні дивимося $title!';
  }

  @override
  String get movieNoMatch => 'Голоси не збіглися — оберіть інший фільм.';

  @override
  String movieAdded(Object title) {
    return '«$title» додано до списку.';
  }

  @override
  String addMovieResult(Object title) {
    return 'Додати $title';
  }

  @override
  String loadMorePages(int page, int totalPages) {
    return 'Показати ще · $page/$totalPages';
  }

  @override
  String get movieMatchNotificationError =>
      'Не вдалося показати локальне сповіщення про метч.';

  @override
  String get secretNotesTitle => 'Секретні нотатки';

  @override
  String get secretNotesSubtitle =>
      'Теплі слова й сюрпризи, які дочекаються слушної миті';

  @override
  String get openPairs => 'Відкрити розділ «Пари»';

  @override
  String get smallSurprise => 'Маленький сюрприз';

  @override
  String get postcardsTab => 'Листівки';

  @override
  String get postcardsTitle => 'Листівки';

  @override
  String get postcardsSubtitle =>
      'Тут зберігаються справді надіслані та отримані листівки.';

  @override
  String get postcardPushUnavailable =>
      'Синхронізацію листівок із сервером ще не підключено.';

  @override
  String get postcardBackendConfigured =>
      'Листівки синхронізуються із сервером пари, поки застосунок відкритий; push-сповіщення не підключені.';

  @override
  String get postcardRefreshInbox => 'Оновити вхідні';

  @override
  String get postcardBackendRefreshFailed =>
      'Не вдалося отримати листівки із сервера. Перевірте з’єднання та спробуйте ще раз.';

  @override
  String get postcardsEmpty => 'Поки листівок немає.';

  @override
  String get postcardAll => 'Усі';

  @override
  String get postcardSentTab => 'Надіслані';

  @override
  String get postcardReceivedTab => 'Отримані';

  @override
  String get postcardComposeTitle => 'Нова листівка';

  @override
  String get postcardRecipient => 'Ім\'я партнера';

  @override
  String get postcardMessage => 'Текст листівки';

  @override
  String get postcardSend => 'Надіслати';

  @override
  String get postcardFieldsRequired =>
      'Вкажіть отримувача та напишіть текст листівки.';

  @override
  String get postcardSendFailed =>
      'Сервер не підтвердив збереження листівки. Її не додано до надісланих.';

  @override
  String get postcardSent => 'Сервер зберіг листівку.';

  @override
  String get postcardLoadError => 'Не вдалося завантажити архів листівок.';

  @override
  String postcardSentTo(Object name) {
    return 'Для: $name';
  }

  @override
  String postcardReceivedFrom(Object name) {
    return 'Від: $name';
  }

  @override
  String get openPostcards => 'Відкрити архів листівок';

  @override
  String get countdownTitle => 'Важливі дати';

  @override
  String get addEvent => 'Додати подію';

  @override
  String get countdownLoadError => 'Не вдалося завантажити події.';

  @override
  String get countdownEmpty =>
      'Додайте подорож, день народження чи іншу важливу дату.';

  @override
  String get editEvent => 'Змінити подію';

  @override
  String eventPassed(Object date) {
    return 'Ця подія вже відбулася · $date';
  }

  @override
  String untilEvent(Object date) {
    return 'До події $date';
  }

  @override
  String get rememberThisDay => 'Зберігаємо цей день у пам\'яті';

  @override
  String get eventToday => 'Подія вже сьогодні';

  @override
  String daysRemaining(int days) {
    return 'Залишилося $days дн.';
  }

  @override
  String get newEvent => 'Нова подія';

  @override
  String get eventTitleHint => 'Наприклад, подорож';

  @override
  String saveEventError(Object error) {
    return 'Не вдалося зберегти подію: $error';
  }

  @override
  String deleteEventError(Object error) {
    return 'Не вдалося видалити подію: $error';
  }

  @override
  String editEventNamed(Object title) {
    return 'Змінити подію $title';
  }

  @override
  String deleteEventNamed(Object title) {
    return 'Видалити подію $title';
  }

  @override
  String get timeCapsuleTitle => 'Капсула часу';

  @override
  String get timeCapsuleSubtitle => 'Залиште записку або фото для майбутнього';

  @override
  String get createTimeCapsule => 'Створити капсулу часу';

  @override
  String get timeCapsuleLoadError => 'Не вдалося завантажити капсули часу.';

  @override
  String get timeCapsuleEmpty =>
      'Поки немає капсул. Створіть першу для себе в майбутньому.';

  @override
  String createCapsuleError(Object error) {
    return 'Не вдалося створити капсулу: $error';
  }

  @override
  String openCapsuleFrom(Object date) {
    return 'Відкрити капсулу від $date';
  }

  @override
  String sealedUntil(Object date) {
    return 'Запечатана до $date';
  }

  @override
  String get capsuleOpened => 'Капсулу відкрито';

  @override
  String get capsuleSealed => 'Капсулу запечатано';

  @override
  String get rouletteTitle => 'Рулетка побачень';

  @override
  String get rouletteSubtitle => 'Оберіть категорію та довірте вибір випадку';

  @override
  String get rouletteFood => 'Їжа';

  @override
  String get rouletteMovie => 'Кіно';

  @override
  String get rouletteActivity => 'Заняття';

  @override
  String get rouletteSpin => 'Крутити';

  @override
  String get rouletteSpinAgain => 'Крутити ще';

  @override
  String get rouletteResult => 'Сьогодні обираємо:';

  @override
  String get rouletteAddChoice => 'Додати варіант';

  @override
  String get rouletteChoiceHint => 'Наприклад, приготувати пасту';

  @override
  String get rouletteEmpty =>
      'Додайте хоча б один варіант, щоб запустити рулетку.';

  @override
  String rouletteRemoveChoice(Object choice) {
    return 'Видалити варіант $choice';
  }

  @override
  String get rouletteSavedChoice => 'Варіант додано';

  @override
  String get rouletteError => 'Не вдалося синхронізувати варіанти рулетки.';

  @override
  String get rouletteListSwipeHint =>
      'Гортайте вбік: активні варіанти та спільний список';

  @override
  String get rouletteDoThis => 'Робимо';

  @override
  String get rouletteChoiceApplied => 'Вибір збережено';

  @override
  String get timeCapsuleOpen => 'Можна переглянути';

  @override
  String timeCapsuleOpensOn(Object date) {
    return 'Відкриється $date';
  }

  @override
  String get newTimeCapsule => 'Нова капсула часу';

  @override
  String get timeCapsuleNoteHint => 'Записка для себе в майбутньому';

  @override
  String get attachPhoto => 'Додати фото';

  @override
  String get photoSelected => 'Фото вибрано';

  @override
  String openOnDate(Object date) {
    return 'Відкрити: $date';
  }

  @override
  String get sealCapsule => 'Запечатати';

  @override
  String choosePhotoError(Object error) {
    return 'Не вдалося вибрати фото: $error';
  }

  @override
  String get capsuleNeedsContent => 'Додайте текст або виберіть фото.';

  @override
  String get photoUnavailable => 'Фото недоступне';

  @override
  String get rouletteFoodOptionCook => 'Приготувати разом';

  @override
  String get rouletteFoodOptionOrder => 'Замовити улюблену їжу';

  @override
  String get rouletteFoodOptionCafe => 'Сходити до кафе';

  @override
  String get rouletteFoodOptionPicnic => 'Влаштувати пікнік';

  @override
  String get rouletteFoodOptionDessert => 'Спекти десерт';

  @override
  String get rouletteMovieOptionRomcom => 'Романтична комедія';

  @override
  String get rouletteMovieOptionCartoon => 'Мультфільм';

  @override
  String get rouletteMovieOptionFavorite => 'Улюблений фільм';

  @override
  String get rouletteMovieOptionNew => 'Знайти щось нове';

  @override
  String get rouletteMovieOptionNight => 'Влаштувати кіноніч';

  @override
  String get rouletteActivityOptionWalk => 'Погуляти разом';

  @override
  String get rouletteActivityOptionBoardGame => 'Зіграти в настільну гру';

  @override
  String get rouletteActivityOptionPhoto => 'Влаштувати фотопрогулянку';

  @override
  String get rouletteActivityOptionHomeDate => 'Влаштувати побачення вдома';

  @override
  String get rouletteActivityOptionMusic => 'Послухати музику';

  @override
  String get warehouseTitle => 'Робота на складі';

  @override
  String get warehouseSubtitle =>
      'Лови коробки, що падають, рухаючи роклу. Спіймай усі 15!';

  @override
  String get warehouseSceneSemantics =>
      'Склад: перетягуй пальцем, щоб рухати роклу та ловити коробки.';

  @override
  String get warehouseStart => 'Почати зміну';

  @override
  String get warehouseTired => 'Качечка втомилася. Їй потрібно відпочити.';

  @override
  String warehouseCooldownRemaining(int hours, int minutes) {
    return 'Повернутися до роботи можна через $hours год $minutes хв.';
  }

  @override
  String warehouseProgress(int caught, int total) {
    return 'Завершено: $caught з $total';
  }

  @override
  String warehouseCaught(int count) {
    return 'Спіймано: $count';
  }

  @override
  String warehouseMissed(int count) {
    return 'Повз: $count';
  }

  @override
  String get warehouseMoveLeft => 'Рухати роклу ліворуч';

  @override
  String get warehouseMoveRight => 'Рухати роклу праворуч';

  @override
  String get warehouseControlsHint => 'Перетягуй склад або натискай стрілки';

  @override
  String get warehouseResultPerfectTitle => 'Чудова зміна!';

  @override
  String get warehouseResultPartialTitle => 'Гарна робота!';

  @override
  String get warehouseResultFailureTitle => 'Зміну завершено';

  @override
  String get warehouseResultPerfectMessage =>
      'Усі коробки спіймано — качечка пишається тобою!';

  @override
  String get warehouseResultPartialMessage =>
      'Спіймано більше половини коробок. Непогано!';

  @override
  String get warehouseResultFailureMessage =>
      'Спіймано менше половини коробок. Спробуємо пізніше.';

  @override
  String warehouseReward(int amount) {
    return 'Зароблено: $amount ₴';
  }

  @override
  String get warehouseReturnHome => 'На головну';

  @override
  String get warehouseRetrySave => 'Повторити';

  @override
  String warehouseWorkSaveError(Object error) {
    return 'Не вдалося зберегти зміну на складі: $error';
  }

  @override
  String get groceryStoreTab => 'Магазин';

  @override
  String get groceryWorkTab => 'Робота';
}
