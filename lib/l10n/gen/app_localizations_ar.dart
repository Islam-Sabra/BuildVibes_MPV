// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'BuildVibes';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navExplore => 'استكشف';

  @override
  String get navCreate => 'إنشاء';

  @override
  String get navActivity => 'النشاط';

  @override
  String get navProfile => 'ملفي';

  @override
  String get placeholderBody => 'هذا القسم من التطبيق قيد البناء.';

  @override
  String get settingsLanguage => 'لغة التطبيق';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get stampSelected => 'مختار';

  @override
  String get signOffLabel => 'التوقيعات';

  @override
  String get signOffRaised => 'أُنشئ';

  @override
  String get signOffDone => 'منجز';

  @override
  String get signOffChecked => 'تم الفحص';

  @override
  String get signOffWaiting => 'قيد الانتظار';

  @override
  String get siteTagFrom => 'من';

  @override
  String get siteTagOwner => 'المكلّف';

  @override
  String get siteTagDue => 'الاستحقاق';

  @override
  String get passLead => 'تصريح مسؤول';

  @override
  String get passCrew => 'تصريح فريق تنفيذ';

  @override
  String get passViewer => 'تصريح مُطّلع';

  @override
  String fieldCharacterCount(int count, int max) {
    return '$count / $max';
  }

  @override
  String get componentsGallery => 'المكوّنات';

  @override
  String entryStartingIn(String country) {
    return 'نبدأ في $country';
  }

  @override
  String get entryWelcomeTitle => 'مجتمع البناء من حولك.';

  @override
  String get entryWelcomeBody =>
      'تعرّف على المهندسين ورؤساء العمال والحِرفيين والموردين. جهّز حضورك عندما تكون مستعداً.';

  @override
  String entryBuiltFor(String country) {
    return 'مصمَّم لقطاع البناء في $country';
  }

  @override
  String get entryAudience1Title => 'المهندسون';

  @override
  String get entryAudience1Body => 'شارك مشاريعك واحصل على تأكيد عملك.';

  @override
  String get entryAudience2Title => 'فرق الموقع والحِرفيون';

  @override
  String get entryAudience2Body => 'اعرض عملك، واحصل على تأكيد فريقك.';

  @override
  String get entryAudience3Title => 'رؤساء العمال والمشرفون';

  @override
  String get entryAudience3Body => 'أدِر عمل اليوم من هاتفك.';

  @override
  String get entryAudience4Title => 'مقاولو الباطن';

  @override
  String get entryAudience4Body => 'احصل على فحص العمل واعتماده في وقته.';

  @override
  String get entryAudience5Title => 'الموردون والتجار';

  @override
  String get entryAudience5Body => 'ليجدك من يبنون.';

  @override
  String get entryAudience6Title => 'BIM والتصميم';

  @override
  String get entryAudience6Body => 'اربط النموذج بالعمل في الموقع.';

  @override
  String get entryBrowseFirstNote =>
      'تصفّح أولاً، وجهّز حضورك عندما تكون مستعداً.';

  @override
  String get entryCreateAccount => 'إنشاء حساب';

  @override
  String get entrySignIn => 'تسجيل الدخول';

  @override
  String get entrySkipToHome => 'تخطَّ إلى الرئيسية';

  @override
  String get entryJoinTitle => 'عملك، يؤكده من بنوه معك.';

  @override
  String get entryJoinBody =>
      'انضم برقمك الذي تستخدمه. يستغرق الأمر دقيقة تقريباً.';

  @override
  String get entrySampleName => 'سامي المنصور';

  @override
  String get entrySampleRole => 'مدير BIM · برج الميناء';

  @override
  String get entrySampleBadge => 'أكّده زملاء العمل';

  @override
  String get entryContinuePhone => 'المتابعة برقم الهاتف';

  @override
  String get entryOrContinueWith => 'أو تابع باستخدام';

  @override
  String get entryGoogle => 'Google';

  @override
  String get entryApple => 'Apple';

  @override
  String get entryLinkedIn => 'LinkedIn';

  @override
  String get entryUseEmail => 'استخدم البريد الإلكتروني';

  @override
  String get entryNoPassword =>
      'بدون كلمة مرور. لا ننشر باسمك ولا نقرأ جهات اتصالك.';

  @override
  String get entryTerms => 'بالمتابعة، أنت توافق على الشروط وسياسة الخصوصية.';

  @override
  String get entryJustLooking => 'تتصفح فقط؟ ابدأ بالتصفح';

  @override
  String get phoneTitle => 'رقم هاتفك';

  @override
  String get phoneLabel => 'رقم الجوال';

  @override
  String get phoneHelpWhatsapp =>
      'نرسل رمزاً من 6 أرقام عبر واتساب. لا حاجة لكلمة مرور.';

  @override
  String get phoneHelpSms =>
      'نرسل رمزاً من 6 أرقام برسالة نصية. لا حاجة لكلمة مرور.';

  @override
  String get phoneSendSms => 'أرسل الرمز برسالة نصية بدلاً من ذلك';

  @override
  String get phoneUseEmail => 'استخدم بريدك الإلكتروني بدلاً من ذلك';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String phoneErrorMarket(String country, int digits) {
    return 'أدخل رقم جوال في $country من $digits أرقام.';
  }

  @override
  String get phoneErrorOther => 'أدخل رقم جوالك كاملاً.';

  @override
  String get dialCodeTitle => 'رمز الدولة';

  @override
  String get dialCodeOther => 'رمز دولة آخر';

  @override
  String get dialCodeOtherHelp => 'اكتب الرمز، مثلاً +91.';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get notOpenTitle => 'الحسابات الجديدة غير متاحة لهذا الرقم بعد';

  @override
  String notOpenSoon(String country) {
    return 'سنصل إلى $country قريباً. إذا دعاك أحد إلى مساحة، افتح رابط الدعوة للانضمام الآن.';
  }

  @override
  String notOpenOther(String countries) {
    return 'الحسابات الجديدة متاحة حالياً في $countries. إذا دعاك أحد إلى مساحة، افتح رابط الدعوة للانضمام الآن.';
  }

  @override
  String get commonOk => 'حسناً';

  @override
  String get emailTitle => 'بريدك الإلكتروني';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get emailHelp => 'نرسل رمزاً من 6 أرقام. لا حاجة لكلمة مرور.';

  @override
  String get emailError => 'تحقق من عنوان البريد الإلكتروني.';

  @override
  String get emailUsePhone => 'استخدم رقم هاتفك بدلاً من ذلك';

  @override
  String get codeTitleWhatsapp => 'تحقق من واتساب';

  @override
  String get codeTitleSms => 'تحقق من رسائلك';

  @override
  String get codeTitleEmail => 'تحقق من بريدك';

  @override
  String codeSentWhatsapp(String destination) {
    return 'أرسلنا رمزاً من 6 أرقام إلى $destination عبر واتساب. يعمل لمدة 10 دقائق.';
  }

  @override
  String codeSentSms(String destination) {
    return 'أرسلنا رمزاً من 6 أرقام إلى $destination برسالة نصية. يعمل لمدة 10 دقائق.';
  }

  @override
  String codeSentEmail(String destination) {
    return 'أرسلنا رمزاً من 6 أرقام إلى $destination. يعمل لمدة 10 دقائق. تحقق من البريد غير المرغوب فيه إن لم تجده.';
  }

  @override
  String codeResendIn(String time) {
    return 'إعادة الإرسال بعد $time';
  }

  @override
  String get codeResend => 'أرسل رمزاً جديداً';

  @override
  String get codeDifferentNumber => 'استخدم رقماً آخر';

  @override
  String get codeDifferentEmail => 'استخدم بريداً آخر';

  @override
  String get codeWrong => 'الرمز غير صحيح. تحقق منه وحاول مرة أخرى.';

  @override
  String get codeExpired => 'انتهت صلاحية الرمز. أرسل رمزاً جديداً.';

  @override
  String get codeFieldLabel => 'رمز من 6 أرقام';

  @override
  String get errorNetwork => 'لا يوجد اتصال. تحقق من الإنترنت وحاول مرة أخرى.';

  @override
  String get errorTooMany => 'محاولات كثيرة. انتظر دقيقة وحاول مرة أخرى.';

  @override
  String get errorGeneric => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get errorSendFailed =>
      'تعذّر إرسال الرمز. حاول مرة أخرى أو استخدم البريد الإلكتروني.';

  @override
  String get commonRetry => 'حاول مرة أخرى';

  @override
  String get aboutTitle => 'عنك';

  @override
  String get aboutIntro =>
      'الخطوة 1 من 2. هكذا سيجدك الناس. يمكنك التغيير لاحقاً.';

  @override
  String get firstName => 'الاسم الأول';

  @override
  String get lastName => 'اسم العائلة';

  @override
  String get country => 'الدولة';

  @override
  String get countryFromPhone => 'من رقم هاتفك. يمكنك تغييرها من الإعدادات.';

  @override
  String get role => 'الدور';

  @override
  String get rolePlaceholder => 'اختر دورك';

  @override
  String get companyOptional => 'الشركة (اختياري)';

  @override
  String get companyPlaceholder => 'ابحث عن شركتك أو اكتب اسمها';

  @override
  String get recoveryEmail => 'بريد لاستعادة الدخول (اختياري)';

  @override
  String get recoveryEmailHelp => 'يساعدك على الدخول إذا تغيّر رقمك.';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get firstNameRequired => 'اكتب اسمك الأول.';

  @override
  String get lastNameRequired => 'اكتب اسم عائلتك.';

  @override
  String get roleRequired => 'اختر دورك.';

  @override
  String get countryRequired => 'اختر دولتك.';

  @override
  String get companySheetTitle => 'شركتك';

  @override
  String get companySearch => 'ابحث عن الشركات';

  @override
  String companyUseTyped(String name) {
    return 'استخدم «$name»';
  }

  @override
  String get companyUseTypedHelp =>
      'يُحفظ كما كتبته، ولا يرتبط بصفحة شركة إلا إذا كانت مسجّلة.';

  @override
  String get companyNone => 'بدون شركة';

  @override
  String get roleTitle => 'دورك';

  @override
  String get roleIntro =>
      'ماذا تعمل في الموقع أو المكتب؟ يظهر تحت اسمك ويحدد الأشخاص والمساحات التي تراها أولاً.';

  @override
  String get roleSearch => 'ابحث عن حرفة أو دور';

  @override
  String rolePopularIn(String country) {
    return 'الأكثر شيوعاً في $country';
  }

  @override
  String roleAddCustom(String text) {
    return 'أضف «$text» كدور لك';
  }

  @override
  String get roleNotInList => 'ليس في القائمة؟ اكتبه في البحث وأضفه كدور لك.';

  @override
  String get save => 'حفظ';

  @override
  String get peopleTitle => 'أشخاص لتتابعهم';

  @override
  String get skip => 'تخطَّ';

  @override
  String stepOf(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get peopleHeadline => 'ابدأ بأشخاص قد تعمل معهم';

  @override
  String peopleBody(String role, String country) {
    return 'اخترناهم لدور $role في $country. يمكنك التغيير في أي وقت.';
  }

  @override
  String peopleFromCompany(String company) {
    return 'من $company';
  }

  @override
  String get peopleNearYou => 'يعملون بالقرب منك';

  @override
  String get reasonCompany => 'شركتك';

  @override
  String reasonNear(String place) {
    return 'بالقرب منك · $place';
  }

  @override
  String reasonSameCountry(String country) {
    return 'يعمل في $country';
  }

  @override
  String get follow => 'متابعة';

  @override
  String get following => 'تتابعه';

  @override
  String get peopleEmpty =>
      'لا توجد اقتراحات بعد. عندما ينضم فريقك إلى BuildVibes ستراهم هنا.';

  @override
  String get joinWallTitle => 'انضم إلى BuildVibes لتقوم بهذا';

  @override
  String get joinWallBody => 'يستغرق دقيقة تقريباً. بدون كلمة مرور.';

  @override
  String get guestProfileTitle => 'أنت تتصفح كزائر';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String profileFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count متابع',
      many: '$count متابعًا',
      few: '$count متابعين',
      two: 'متابعان',
      one: 'متابع واحد',
      zero: 'لا متابعين',
    );
    return '$_temp0';
  }

  @override
  String profileFollowing(int count) {
    return 'يتابع $count';
  }

  @override
  String get profileEdit => 'تعديل الملف';

  @override
  String get profileTabOverview => 'نظرة عامة';

  @override
  String get profileTabPosts => 'المنشورات';

  @override
  String get profileTabProjects => 'المشاريع';

  @override
  String get profileTabExperience => 'الخبرات';

  @override
  String get proofLabel => 'الإثبات · أين تم التأكيد';

  @override
  String get proofConfirmed => 'مؤكَّد';

  @override
  String get proofWaiting => 'بانتظار التأكيد';

  @override
  String get proofEmptyTitle => 'أضف مشروعاً لتبدأ إثباتك';

  @override
  String get proofEmptyBody =>
      'تظهر هنا المشاريع في سيرتك، ويؤكدها زملاؤك في مساحاتك.';

  @override
  String get finishProfileTitle => 'أكمل ملفك';

  @override
  String finishProfileProgress(int done, int total) {
    return '$done من $total مكتملة';
  }

  @override
  String get openToTitle => 'منفتح على';

  @override
  String get openToContract => 'عقد';

  @override
  String get openToConsulting => 'استشارات';

  @override
  String get openToFullTime => 'دوام كامل';

  @override
  String get openToPartTime => 'دوام جزئي';

  @override
  String get openToMentoring => 'إرشاد';

  @override
  String get openToOnlyYou => 'أنت فقط ترى هذا.';

  @override
  String get openToConnectionsOnly => 'جهات اتصالك فقط ترى هذا.';

  @override
  String get profileAbout => 'نبذة';

  @override
  String get profileSeeAllProjects => 'كل المشاريع';

  @override
  String get workDeliveredTitle => 'العمل الذي سلّمته';

  @override
  String get workDeliveredVisitorTitle => 'العمل المُسلَّم';

  @override
  String get workDeliveredBody =>
      'أنت تختار ما يظهر. فقط البنود التي تم فحصها وإغلاقها في مساحة.';

  @override
  String get workDeliveredEmpty => 'لا شيء تم فحصه بعد.';

  @override
  String get experienceEmpty => 'لم تُضف خبرة بعد.';

  @override
  String get projectsEmpty => 'لا مشاريع في السيرة بعد.';

  @override
  String get postsEmpty => 'لا منشورات بعد.';

  @override
  String get present => 'حتى الآن';

  @override
  String expectedMonth(String month) {
    return 'متوقع $month';
  }

  @override
  String dateRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get profileMore => 'المزيد';

  @override
  String blockPerson(String name) {
    return 'حظر $name';
  }

  @override
  String blockConfirmTitle(String name) {
    return 'حظر $name؟';
  }

  @override
  String get blockConfirmBody =>
      'لن يرى أحدكما ملف الآخر، وتُزال المتابعات بينكما. ولن يتم إبلاغه.';

  @override
  String get block => 'حظر';

  @override
  String get profileNotFound => 'هذا الملف غير متاح.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get editBasics => 'الاسم والصورة والمسمى';

  @override
  String get editAboutEmpty => 'أضف بضعة أسطر عن عملك';

  @override
  String get editProjectsSub => 'الظهور لكل مشروع';

  @override
  String get editOpenToEmpty => 'اذكر ما أنت منفتح عليه';

  @override
  String get headline => 'المسمى';

  @override
  String get headlineHint => 'مثال: مدير BIM';

  @override
  String get addPhoto => 'أضف صورة';

  @override
  String get changePhoto => 'تغيير الصورة';

  @override
  String get removePhoto => 'إزالة الصورة';

  @override
  String get placeLabel => 'المدينة أو المنطقة';

  @override
  String get placeOptional => 'المدينة أو المنطقة (اختياري)';

  @override
  String get aboutHint => 'ماذا تعمل، وفي أي نوع من المشاريع؟';

  @override
  String get experienceAdd => 'إضافة خبرة';

  @override
  String get experienceEdit => 'تعديل الخبرة';

  @override
  String get titleLabel => 'المسمى';

  @override
  String get titleRequired => 'اكتب المسمى.';

  @override
  String get startedLabel => 'البداية';

  @override
  String get endedLabel => 'النهاية';

  @override
  String get startRequired => 'اختر تاريخ البداية.';

  @override
  String get whoCanSee => 'من يمكنه رؤية هذا';

  @override
  String get visibilityEveryone => 'الجميع';

  @override
  String get visibilityEveryoneSub => 'أي شخص مسجّل في BuildVibes.';

  @override
  String get visibilityConnections => 'جهات الاتصال فقط';

  @override
  String get visibilityConnectionsSub => 'من تتابعهم ويتابعونك.';

  @override
  String get visibilityOnlyMe => 'أنا فقط';

  @override
  String get visibilityOnlyMeSub => 'لا يراه أحد غيرك.';

  @override
  String get delete => 'حذف';

  @override
  String get openToNote => 'ملاحظة قصيرة (اختياري)';

  @override
  String get openToNoteHint => 'مثال: متاح من الشهر القادم';

  @override
  String get cvShowOnProfile => 'إظهار في ملفي';

  @override
  String get addProject => 'إضافة مشروع';

  @override
  String get projectSearchHint => 'اسم المشروع';

  @override
  String get addProjectIntro =>
      'سجل واحد لكل مشروع، ليظهر كل من عمل فيه في مكان واحد.';

  @override
  String get matchSameName => 'الاسم نفسه';

  @override
  String get matchSameSite => 'الموقع نفسه';

  @override
  String get thisIsIt => 'هذا هو · أضفه إلى سيرتي';

  @override
  String get startNewRecord => 'ليس أيّاً منها؟ ابدأ سجلاً جديداً';

  @override
  String get startNewRecordSub =>
      'الاسم والنوع والتواريخ ودورك. دقيقة تقريباً.';

  @override
  String get onYourCvBadge => 'في سيرتك';

  @override
  String cvEntryTitle(String project) {
    return 'دورك في $project';
  }

  @override
  String get yourRole => 'دورك';

  @override
  String get roleTitleRequired => 'اكتب دورك.';

  @override
  String get addToCv => 'أضف إلى سيرتي';

  @override
  String get newProjectTitle => 'مشروع جديد';

  @override
  String get projectRecordLabel => 'سجل المشروع';

  @override
  String get draftStamp => 'إصدار أ · مسودة';

  @override
  String get sharedRecordStamp => 'سجل مشترك · بلا مالك';

  @override
  String get cellProjectName => 'اسم المشروع';

  @override
  String get cellType => 'النوع';

  @override
  String get cellLocation => 'الموقع';

  @override
  String get cellStarted => 'البداية';

  @override
  String get cellEnded => 'النهاية';

  @override
  String get cellYourRole => 'دورك';

  @override
  String get choose => 'اختر';

  @override
  String get newProjectNote =>
      'هذا يعرّف المشروع ويضعه في سيرتك بدورك. لا أحد يملك المشروع، ويمكن لكل من عمل فيه إضافته إلى سيرته.';

  @override
  String get projectNameRequired => 'اكتب اسم المشروع.';

  @override
  String get projectTypeRequired => 'اختر النوع.';

  @override
  String get projectNameHint => 'مثال: مجمع الكوت المرحلة 2';

  @override
  String get projectTitle => 'المشروع';

  @override
  String get projectNoOwnerNote =>
      'يمكن لأي شخص وضع هذا المشروع في سيرته. لا أحد يملكه، وتراجع BuildVibes التصحيحات.';

  @override
  String get suggestEdit => 'اقترح تعديلاً';

  @override
  String get onYourCv => 'في سيرتك';

  @override
  String get peopleOnProject => 'أشخاص وضعوه في سيرتهم';

  @override
  String get peopleOnProjectNote => 'فقط من اختاروا إظهاره في ملفهم.';

  @override
  String get peopleOnProjectEmpty => 'لم يُظهره أحد غيرك بعد.';

  @override
  String suggestTitle(String project) {
    return 'اقترح تعديلاً على $project';
  }

  @override
  String get suggestBody =>
      'لا أحد يملك هذا السجل، لذا تراجع BuildVibes كل تغيير، ويُبلَّغ من أدرجوه عند تغييره.';

  @override
  String get whatsWrong => 'ما الخطأ';

  @override
  String get wrongName => 'الاسم';

  @override
  String get wrongType => 'النوع';

  @override
  String get wrongLocation => 'الموقع';

  @override
  String get wrongDates => 'التواريخ';

  @override
  String get wrongDuplicate => 'إنه مكرر';

  @override
  String get correctValue => 'القيمة الصحيحة';

  @override
  String get correctValueHelp => 'أضف مصدراً إن وُجد، مثل صورة لوحة الموقع.';

  @override
  String get correctValueRequired => 'اكتب القيمة الصحيحة.';

  @override
  String get sendForReview => 'إرسال للمراجعة';

  @override
  String get suggestionSent => 'شكراً، سنراجعه.';

  @override
  String get monthPickerPresent => 'مستمر حتى الآن';
}
