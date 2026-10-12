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
  String get role => 'الدور';

  @override
  String get rolePlaceholder => 'اختر دورك';

  @override
  String get companyOptional => 'الشركة (اختياري)';

  @override
  String get companyPlaceholder => 'ابحث عن شركتك أو اكتب اسمها';

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

  @override
  String get entryContinueEmail => 'المتابعة بالبريد الإلكتروني';

  @override
  String get entryJoinBodyEmail =>
      'انضم ببريدك الإلكتروني. يستغرق الأمر دقيقة تقريباً.';

  @override
  String get countryChangeLater => 'يمكنك تغييرها من الإعدادات.';

  @override
  String get mobileOptional => 'رقم الجوال (اختياري)';

  @override
  String get mobileHelp => 'خاص: أنت فقط تراه، ولا يظهر في ملفك أبداً.';

  @override
  String get homeFeed => 'الأخبار';

  @override
  String get homeSpaces => 'المساحات';

  @override
  String get spacesProjectSpaces => 'مساحات المشاريع';

  @override
  String spacesNeedsYou(int count) {
    return '$count بانتظارك';
  }

  @override
  String get spacesPrivateWork => 'عمل خاص';

  @override
  String get spacesProjectSpaceLine => 'عمل خاص · مساحة مشروع';

  @override
  String get spacesEmptyTitle => 'انضم إلى أول مساحة لك';

  @override
  String get spacesEmptyBody =>
      'المساحة هي المكان الذي يدير فيه فريق المشروع عمله اليومي. عندما تنضم إلى مساحة، يظهر تقريرك اليومي هنا: الردود وتحديثات الموقع وكل ما ينتظرك.';

  @override
  String get spacesEmptyFeedNote =>
      'تبقى الخلاصة تعرض المنشورات والإعلانات والتهاني من شبكتك.';

  @override
  String get spacesEnterCode => 'أدخل رمز الدعوة';

  @override
  String get spacesCodeHint => '6 أحرف وأرقام من الشخص الذي دعاك';

  @override
  String spacesInvitedBy(String name) {
    return 'دعاك $name';
  }

  @override
  String get spacesAskToJoin => 'اطلب الانضمام';

  @override
  String get spacesCodeNotValid =>
      'هذا الرمز غير صالح. تأكد منه مع من أرسله إليك.';

  @override
  String get spacesTooManyTries => 'محاولات كثيرة. حاول مرة أخرى بعد ساعة.';

  @override
  String get spacesAlreadyMember => 'أنت عضو في هذه المساحة بالفعل.';

  @override
  String get spacesDeclinedWait => 'يمكنك الطلب مرة أخرى غداً.';

  @override
  String get spacesRequestSent => 'تم إرسال طلبك. سيؤكد مدير المساحة انضمامك.';

  @override
  String get spacesAlreadyWaiting =>
      'طلبت الانضمام من قبل. بانتظار مدير المساحة.';

  @override
  String get spacesWaiting => 'بانتظار تأكيد مدير المساحة';

  @override
  String get spacesCancelRequest => 'إلغاء الطلب';

  @override
  String get spacesNotConfirmed => 'لم يتم التأكيد';

  @override
  String get spacesDismiss => 'إخفاء';

  @override
  String get spacesNewTitle => 'مساحة جديدة';

  @override
  String get spacesPreviewLabel => 'كيف ستظهر للأعضاء';

  @override
  String get spacesNameLabel => 'الاسم';

  @override
  String get spacesNameHint => 'مثال: البرج B — فريق الموقع';

  @override
  String get spacesNameRequired => 'اكتب اسماً من حرفين على الأقل.';

  @override
  String get spacesAboutLabel => 'نبذة (اختياري)';

  @override
  String get spacesAboutHelp => 'تظهر لمن تدعوهم.';

  @override
  String get spacesLinkLabel => 'ربط بمشروع (اختياري)';

  @override
  String get spacesLinkPlaceholder => 'اختر مشروعاً';

  @override
  String get spacesLinkHelp =>
      'ربط مشروع يجعل هذه مساحة المشروع. الأعضاء الذين تؤكدهم يظهر المشروع في ملفاتهم مؤكَّداً.';

  @override
  String get spacesCreateButton => 'إنشاء المساحة';

  @override
  String get spacesLinkTitle => 'ربط بمشروع';

  @override
  String get spacesLinkSearch => 'ابحث في مشاريعك';

  @override
  String spacesYourRole(String role) {
    return 'دورك: $role';
  }

  @override
  String get spacesTabWork => 'العمل';

  @override
  String get spacesTabChat => 'المحادثة';

  @override
  String get spacesTabPeople => 'الأشخاص';

  @override
  String get spacesTabLibrary => 'المكتبة';

  @override
  String get spacesInvitePeople => 'دعوة أشخاص';

  @override
  String spacesInviteTitle(String space) {
    return 'دعوة إلى $space';
  }

  @override
  String get spacesInviteCode => 'رمز الدعوة';

  @override
  String spacesCodeWorksUntil(String date) {
    return 'صالح حتى $date';
  }

  @override
  String get spacesShareCode => 'شارك الرمز';

  @override
  String get spacesNewCode => 'رمز جديد';

  @override
  String get spacesNewCodeTitle => 'إنشاء رمز جديد؟';

  @override
  String get spacesNewCodeNote => 'يتوقف الرمز القديم عن العمل.';

  @override
  String get spacesInviteHow =>
      'أرسل الرمز عبر واتساب أو اقرأه في الموقع. يؤكد مدير المساحة كل شخص قبل انضمامه.';

  @override
  String spacesShareText(String space, String code) {
    return 'انضم إلى $space على BuildVibes. رمز الدعوة: $code';
  }

  @override
  String get spacesNotFound => 'هذه المساحة غير متاحة.';

  @override
  String get spacesNotAllowed => 'لا يمكنك القيام بذلك في هذه المساحة.';

  @override
  String get spacesTooManyToday =>
      'أنشأت مساحات كثيرة اليوم. حاول مرة أخرى غداً.';

  @override
  String get spacesInviteCodeTag => 'رمز الدعوة';

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n دقيقة',
      few: 'منذ $n دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n ساعة',
      few: 'منذ $n ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
    );
    return '$_temp0';
  }

  @override
  String get timeYesterday => 'أمس';

  @override
  String timeDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n يوماً',
      few: 'منذ $n أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
    );
    return '$_temp0';
  }

  @override
  String get spacesSearchMembers => 'ابحث في الأعضاء';

  @override
  String get spacesRequestsTitle => 'طلبات الانضمام · أنت تؤكدها';

  @override
  String spacesAsked(String when) {
    return 'طلب الانضمام $when';
  }

  @override
  String spacesViaCodeFrom(String name) {
    return 'رمز دعوة من $name';
  }

  @override
  String get spacesViaCode => 'رمز دعوة';

  @override
  String get spacesDecline => 'رفض';

  @override
  String get spacesConfirm => 'تأكيد';

  @override
  String get spacesOwners => 'مديرو المساحة';

  @override
  String get spacesOwnerTag => 'مدير المساحة';

  @override
  String get spacesMembers => 'الأعضاء';

  @override
  String get spacesYouTag => 'أنت';

  @override
  String get spacesNoMatch => 'لا يوجد من يطابق البحث.';

  @override
  String get spacesPassLead => 'مسؤول';

  @override
  String get spacesPassCrew => 'فريق تنفيذ';

  @override
  String get spacesPassViewer => 'مُطّلع';

  @override
  String spacesPassLine(String pass) {
    return 'تصريح $pass';
  }

  @override
  String get spacesGivePass => 'امنح تصريحاً لهذه المساحة';

  @override
  String get spacesLeadOpens =>
      'يتيح: إنشاء البنود · الفحص والإغلاق · الملفات · الدعوة';

  @override
  String get spacesLeadFor => 'المهندسون والمشرفون';

  @override
  String get spacesCrewOpens =>
      'يتيح: المحادثة · توقيع البنود المكلّف بها كمنجزة بصورة · الملفات';

  @override
  String get spacesCrewFor => 'رؤساء العمال والفنيون ومقاولو الباطن';

  @override
  String get spacesViewerOpens => 'يتيح: القراءة والمحادثة فقط';

  @override
  String get spacesViewerFor => 'العميل والمورّد';

  @override
  String spacesConfirmAs(String pass) {
    return 'تأكيد: $pass';
  }

  @override
  String spacesJoinedAs(String name, String pass) {
    return 'تم تأكيد انضمام $name بتصريح $pass. أصبحت المساحة متاحة الآن.';
  }

  @override
  String spacesDeclined(String name) {
    return 'تم رفض طلب $name دون ذكر السبب.';
  }

  @override
  String get spacesUndo => 'تراجع';

  @override
  String get spacesAlreadyAnswered => 'تمت الإجابة على هذا الطلب بالفعل.';

  @override
  String get spacesMemberTitle => 'العضو';

  @override
  String get spacesPassOpens => 'ما يتيحه هذا التصريح';

  @override
  String spacesPassCustom(String pass) {
    return '$pass · مخصّص';
  }

  @override
  String spacesConfirmedBy(String name) {
    return 'تم التأكيد بواسطة $name';
  }

  @override
  String get spacesConfirmedByYou => 'تم التأكيد بواسطتك';

  @override
  String get spacesRightChat => 'المحادثة في «الجميع» والفِرق';

  @override
  String get spacesRightMarkDone => 'توقيع البنود المكلّف بها كمنجزة';

  @override
  String get spacesRightFiles => 'إضافة ملفات إلى المكتبة';

  @override
  String get spacesRightCreate => 'إنشاء بنود عمل';

  @override
  String get spacesRightCheck => 'فحص البنود وإغلاقها';

  @override
  String get spacesRightInvite => 'دعوة أشخاص';

  @override
  String get spacesAlways => 'دائماً';

  @override
  String get spacesOpenRight => 'فتح';

  @override
  String get spacesLockRight => 'قفل';

  @override
  String get spacesChangePass => 'تغيير التصريح';

  @override
  String get spacesTeamsLabel => 'الفِرق';

  @override
  String get spacesMakeAdmin => 'تعيين كمدير';

  @override
  String get spacesMakeAdminHelp =>
      'يؤكد المديرون الأشخاص ويمنحون التصاريح ويديرون المساحة.';

  @override
  String get spacesRemove => 'إزالة من المساحة';

  @override
  String spacesRemoveTitle(String name) {
    return 'إزالة $name؟';
  }

  @override
  String get spacesRemoveBody => 'تبقى بنود العمل المغلقة في السجل.';

  @override
  String spacesRightOpened(String right, String name) {
    return '$right: مفتوح لـ$name. يظهر التصريح كمخصّص.';
  }

  @override
  String spacesRightLocked(String right, String name) {
    return '$right: مقفل لـ$name.';
  }

  @override
  String spacesPassChanged(String name, String pass) {
    return 'تصريح $name الآن: $pass.';
  }

  @override
  String spacesAdminOn(String name) {
    return '$name الآن من مديري المساحة.';
  }

  @override
  String spacesAdminOff(String name) {
    return 'تمت إزالة $name من مديري المساحة.';
  }

  @override
  String get spacesTeamsSaved => 'تم حفظ الفِرق.';

  @override
  String get spacesNeedsAdmin =>
      'تحتاج المساحة إلى مدير. اجعل شخصاً آخر مديراً أولاً.';

  @override
  String spacesRemoved(String name) {
    return 'تمت إزالة $name من المساحة.';
  }

  @override
  String get spacesAdminRights => 'لدى المديرين كل الصلاحيات في المساحة.';

  @override
  String listAnd(String a, String b) {
    return '$a و$b';
  }

  @override
  String listAndOthers(String names) {
    return '$names وآخرون';
  }

  @override
  String get youLower => 'أنت';

  @override
  String proofConfirmedBy(String names) {
    return 'تم التأكيد بواسطة $names';
  }

  @override
  String get spacesInfoTitle => 'معلومات المساحة';

  @override
  String get spacesAccess => 'الوصول';

  @override
  String spacesAccessLinked(String project) {
    return 'عمل خاص · مرتبطة بـ$project';
  }

  @override
  String get spacesInviteRowSub => 'شارك رمز الدعوة';

  @override
  String spacesOwnersLine(String names) {
    return 'مديرو المساحة: $names';
  }

  @override
  String get spacesWhoCanInvite => 'من يمكنه الدعوة';

  @override
  String get spacesWhoCanInviteNote =>
      'كل انضمام يحتاج إلى تأكيد مدير المساحة.';

  @override
  String get spacesInviteAdmins => 'مديرو المساحة';

  @override
  String get spacesInviteAdminsHelp => 'المديرون فقط يشاركون رمز الدعوة.';

  @override
  String get spacesInviteLeads => 'المديرون وأصحاب تصريح مسؤول';

  @override
  String get spacesInviteLeadsHelp => 'يمكن لأصحاب تصريح مسؤول دعوة فِرقهم.';

  @override
  String get spacesInviteEveryone => 'كل من في المساحة';

  @override
  String get spacesInviteEveryoneHelp =>
      'يمكن لأي عضو مشاركة الرمز، ويؤكد المديرون كل انضمام.';

  @override
  String get spacesNotifications => 'الإشعارات';

  @override
  String get spacesNotificationsNote => 'لهذه المساحة فقط.';

  @override
  String get spacesNotifyAll => '«الجميع» وفِرقي';

  @override
  String get spacesNotifyAllHelp => 'رسائل «الجميع» وفِرقك، وكل ما ينتظرك.';

  @override
  String get spacesNotifyNeedsYou => 'بانتظارك فقط';

  @override
  String get spacesNotifyNeedsYouHelp =>
      'البنود المكلّف بها، والبنود التي تحتاج فحصاً، وطلبات الانضمام.';

  @override
  String get spacesNotifyOff => 'إيقاف';

  @override
  String get spacesNotifyOffHelp =>
      'لا تنبيهات. يبقى «بانتظارك» ظاهراً في الرئيسية.';

  @override
  String get spacesTransfer => 'نقل إدارة المساحة';

  @override
  String get spacesDeleteSpace => 'حذف المساحة';

  @override
  String get spacesDeleteSpaceHelp => 'للمديرين فقط. تُحذف لدى الجميع.';

  @override
  String get spacesDeleteButton => 'حذف';

  @override
  String spacesDeleted(String space) {
    return 'تم حذف $space.';
  }

  @override
  String get spacesLeave => 'مغادرة المساحة';

  @override
  String spacesLeaveTitle(String space) {
    return 'مغادرة $space؟';
  }

  @override
  String get spacesLeaveButton => 'مغادرة';

  @override
  String spacesLeft(String space) {
    return 'غادرت $space.';
  }

  @override
  String get spacesEdit => 'تعديل';

  @override
  String get spacesEditTitle => 'تعديل المساحة';

  @override
  String get spacesTransferIntro =>
      'اختر عضواً لتنتقل إليه إدارة المساحة. ستبقى في المساحة كعضو.';

  @override
  String spacesTransferTo(String name) {
    return 'نقل إلى $name';
  }

  @override
  String spacesTransferTitle(String name) {
    return 'نقل الإدارة إلى $name؟';
  }

  @override
  String spacesTransferBody(String name, String space) {
    return 'تنتقل إدارة $space إلى $name وتصبح أنت عضواً.';
  }

  @override
  String get spacesTransferButton => 'نقل';

  @override
  String spacesTransferred(String name) {
    return '$name الآن من مديري المساحة، وأنت عضو.';
  }

  @override
  String get spacesNoOneToTransfer => 'أكّد انضمام شخص إلى المساحة أولاً.';

  @override
  String get spacesTeams => 'الفِرق';

  @override
  String spacesTeamMembers(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n عضواً',
      few: '$n أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
      zero: 'لا أعضاء بعد',
    );
    return '$_temp0';
  }

  @override
  String get spacesInTeam => 'أنت فيه';

  @override
  String get spacesNewTeam => 'فريق جديد';

  @override
  String get spacesTeamName => 'اسم الفريق';

  @override
  String get spacesTeamNameHint => 'مثال: فريق MEP';

  @override
  String get spacesTeamHelp =>
      'يرى كل من في المساحة أسماء الفِرق وأعضاءها. المحادثة لأعضاء الفريق فقط.';

  @override
  String get spacesAddMembers => 'إضافة أعضاء';

  @override
  String spacesCreateTeam(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'إنشاء الفريق · $n شخصاً',
      few: 'إنشاء الفريق · $n أشخاص',
      two: 'إنشاء الفريق · شخصان',
      one: 'إنشاء الفريق · شخص واحد',
      zero: 'إنشاء الفريق',
    );
    return '$_temp0';
  }

  @override
  String get spacesTeamNameRequired => 'اكتب اسم الفريق.';

  @override
  String get spacesTeamDuplicate => 'يوجد فريق بهذا الاسم بالفعل.';

  @override
  String spacesTeamIntro(String space) {
    return 'فريق في $space. منشورات الفريق ومحادثاته لأعضائه فقط.';
  }

  @override
  String get spacesAddPeople => 'إضافة أشخاص';

  @override
  String get spacesTeamPeopleTitle => 'أعضاء الفريق';

  @override
  String get spacesRenameTeam => 'إعادة تسمية الفريق';

  @override
  String get spacesDeleteTeam => 'حذف الفريق';

  @override
  String spacesDeleteTeamTitle(String team) {
    return 'حذف $team؟';
  }

  @override
  String get spacesDeleteTeamBody => 'يبقى أعضاؤه في المساحة.';

  @override
  String get spacesNoTeamMembers => 'لا أحد في هذا الفريق بعد.';

  @override
  String spacesDeleteTitle(String space) {
    return 'حذف $space؟';
  }

  @override
  String get spacesDeleteBody => 'ستُحذف لدى الجميع.';

  @override
  String get spacesLeaveBodyPrivate =>
      'لن ترى محادثاتها وأعمالها بعد الآن. للعودة تحتاج إلى دعوة جديدة.';

  @override
  String get spacesLastAdmin => 'اجعل شخصاً آخر مديراً أولاً، أو احذف المساحة.';

  @override
  String get workPrivacyLine =>
      'الأعضاء أشخاص أكّدهم مدير المساحة. لا يظهر شيء هنا خارج المساحة.';

  @override
  String get workFilterAll => 'الكل';

  @override
  String get workFilterMine => 'الخاصة بي';

  @override
  String get workFilterOpen => 'مفتوحة';

  @override
  String get workFilterToCheck => 'للفحص';

  @override
  String get workFilterChecked => 'تم الفحص';

  @override
  String get workSectionNeedsYou => 'بانتظارك';

  @override
  String get workSectionOpen => 'مفتوحة';

  @override
  String get workSectionWaitingCheck => 'بانتظار الفحص';

  @override
  String get workSectionCheckedWeek => 'تم فحصها هذا الأسبوع';

  @override
  String get workSectionCheckedEarlier => 'تم فحصها سابقاً';

  @override
  String get workStatusOpen => 'مفتوح';

  @override
  String workStatusOpenDue(String date) {
    return 'مفتوح · الاستحقاق $date';
  }

  @override
  String workStatusOverdue(String date) {
    return 'مفتوح · كان مستحقاً $date';
  }

  @override
  String get workStatusDoneYouCheck => 'منجز · تفحصه أنت';

  @override
  String get workStatusDoneWaiting => 'منجز · بانتظار الفحص';

  @override
  String workStatusChecked(String date) {
    return 'تم الفحص · $date';
  }

  @override
  String get workOwnerYou => 'المكلّف: أنت';

  @override
  String workOwner(String name) {
    return 'المكلّف: $name';
  }

  @override
  String get workFromYou => 'منك';

  @override
  String workFrom(String name) {
    return 'من $name';
  }

  @override
  String workCheckedByLine(String name) {
    return 'الفحص: $name';
  }

  @override
  String workCheckedBy(String name) {
    return 'الفحص: $name';
  }

  @override
  String workPhotos(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n صورة',
      few: '$n صور',
      two: 'صورتان',
      one: 'صورة واحدة',
      zero: 'بلا صورة',
    );
    return '$_temp0';
  }

  @override
  String get workSignAsDone => 'وقّع كمنجز';

  @override
  String get workCheckIt => 'افحصه';

  @override
  String get workNewItem => 'بند جديد';

  @override
  String get workEmptyTitle => 'لا بنود عمل بعد';

  @override
  String get workEmptyCanCreate =>
      'أنشئ أول بند من «بند جديد». يوقّعه المكلّف كمنجز، ثم يُفحص.';

  @override
  String get workEmptyCannot =>
      'تظهر البنود هنا عندما يُنشئ أحدهم بنداً للفريق.';

  @override
  String get workNothingNeedsYou => 'لا شيء بانتظارك الآن.';

  @override
  String get workFilterEmpty => 'لا شيء هنا.';

  @override
  String get workStatusOwnerLeft => 'غادر المكلّف · أعد التكليف';

  @override
  String get workReassign => 'أعد التكليف';

  @override
  String get workNewTitle => 'بند عمل جديد';

  @override
  String get workTakePhoto => 'التقط صورة';

  @override
  String get workFromGallery => 'اختر من المعرض';

  @override
  String get workRetake => 'إعادة';

  @override
  String get workPhotoFirst => 'ابدأ بصورة للمكان.';

  @override
  String workNewStamp(String ref) {
    return 'جديد · $ref';
  }

  @override
  String get workNewStampPlain => 'جديد';

  @override
  String get workTitleHint => 'ما المطلوب · سطر واحد يكفي';

  @override
  String get workTitleRequired => 'اكتب ما المطلوب.';

  @override
  String get workCellOwner => 'المكلّف · شخص واحد';

  @override
  String get workCellDue => 'الاستحقاق';

  @override
  String get workCellPlace => 'المكان في الموقع';

  @override
  String get workCellTeam => 'الفريق';

  @override
  String get workChoose => 'اختر';

  @override
  String get workOwnerRequired => 'اختر من سينفّذه.';

  @override
  String get workNoDue => 'بلا موعد';

  @override
  String get workToday => 'اليوم';

  @override
  String get workTomorrow => 'غداً';

  @override
  String get workPickDate => 'اختر تاريخاً';

  @override
  String get workNoTeam => 'بلا فريق';

  @override
  String get workPlaceHint => 'مثال: Level 2 · Grid C7';

  @override
  String workNewFooter(String owner) {
    return 'يصل إلى $owner في «بانتظارك». وعند توقيعه كمنجز تفحصه أنت.';
  }

  @override
  String get workNewFooterNoOwner =>
      'يصل إلى المكلّف في «بانتظارك». وعند توقيعه كمنجز تفحصه أنت.';

  @override
  String get workCreate => 'إنشاء البند';

  @override
  String get workNotSent => 'لم يُرسل بعد';

  @override
  String get workRetry => 'إعادة المحاولة';

  @override
  String get workNotSentNote =>
      'محفوظ على هذا الهاتف. أعد المحاولة عند عودة الإشارة.';

  @override
  String get workSent => 'تم الإرسال.';

  @override
  String get workSignOff => 'التوقيعات';

  @override
  String get workEvidence => 'الإثبات';

  @override
  String get workPhotosLabel => 'الصور';

  @override
  String get workDiscussion => 'النقاش';

  @override
  String get workAddComment => 'أضف تعليقاً';

  @override
  String get workSendComment => 'إرسال';

  @override
  String get workNoComments => 'لا تعليقات بعد.';

  @override
  String workWaitingCheckBy(String name) {
    return 'بانتظار فحص $name';
  }

  @override
  String get workWaitingCheckBody => 'يمكن قبوله أو إرجاعه مع ذكر السبب.';

  @override
  String workCheckBannerTitle(String name) {
    return 'تم توقيعه كمنجز بواسطة $name. افحصه.';
  }

  @override
  String get workCheckBannerBody =>
      'انظر إلى الصورة، ثم اقبله أو أرجعه مع ذكر السبب.';

  @override
  String get workDoneWaiting => 'منجز. بانتظار الفحص.';

  @override
  String get workClosed => 'أُغلق. يبقى في سجل المساحة.';

  @override
  String workClosedCanShow(String name) {
    return 'يمكن عرضه في ملف $name كعمل منجز.';
  }

  @override
  String workClosedBy(String name) {
    return 'الإغلاق: $name';
  }

  @override
  String get workClosedStays => 'يبقى في سجل المساحة.';

  @override
  String workSentBackTitle(String reason) {
    return 'أُرجع: $reason';
  }

  @override
  String get workReasonPhotoMissing => 'الصورة غير موجودة';

  @override
  String get workReasonNotAsDrawing => 'غير مطابق للمخطط';

  @override
  String get workReasonNotFinished => 'غير مكتمل';

  @override
  String get workReasonOther => 'سبب آخر';

  @override
  String get workOwnerLeftTitle => 'غادر المكلّف المساحة';

  @override
  String get workOwnerLeftBody => 'كلّف شخصاً آخر بإكماله.';

  @override
  String workCheckedStamp(String date, String name) {
    return 'تم الفحص · $date · $name';
  }

  @override
  String get workYouCheckIt => 'تفحصه أنت';

  @override
  String get workCheckAndClose => 'افحص وأغلق';

  @override
  String get workSendBack => 'إرجاع';

  @override
  String get workReassignTitle => 'إعادة التكليف إلى';

  @override
  String workReassigned(String name) {
    return 'المكلّف الآن: $name.';
  }

  @override
  String get workItemGone => 'هذا البند غير متاح.';

  @override
  String workTodayAt(String time) {
    return 'اليوم $time';
  }

  @override
  String workSignTitle(String ref) {
    return 'وقّع كمنجز على $ref';
  }

  @override
  String workSignBody(String name) {
    return 'يُكتب اسمك والوقت في التوقيع. أضف صورة أو ملاحظة حتى يمكن فحصه من قِبل $name.';
  }

  @override
  String get workAddPhoto => 'أضف صورة';

  @override
  String get workNote => 'ملاحظة';

  @override
  String get workNoteHint => 'ما الذي تم';

  @override
  String get workSignNeedsSomething => 'أضف صورة أو ملاحظة.';

  @override
  String get workSigned => 'تم التوقيع كمنجز. بانتظار الفحص.';

  @override
  String get workPendingSignOff => 'التوقيع لم يُرسل بعد';

  @override
  String workSendBackTitle(String ref, String name) {
    return 'إرجاع $ref إلى $name';
  }

  @override
  String workSendBackBody(String name) {
    return 'يعود البند مفتوحاً مع سببك مكتوباً عليه، ويصل إلى «بانتظارك» لدى $name.';
  }

  @override
  String get workReason => 'السبب';

  @override
  String workNoteFor(String name) {
    return 'ملاحظة إلى $name';
  }

  @override
  String workSendBackTo(String name) {
    return 'إرجاع إلى $name';
  }

  @override
  String get workReasonRequired => 'اختر سبباً.';

  @override
  String get workOtherNeedsNote => 'اذكر ما الخطأ.';

  @override
  String workSentBack(String name) {
    return 'تم الإرجاع إلى $name.';
  }

  @override
  String workCheckTitle(String ref) {
    return 'فحص $ref وإغلاقه؟';
  }

  @override
  String get workCheckBody =>
      'يُكتب اسمك والوقت في التوقيع. يُغلق ويبقى في سجل المساحة.';

  @override
  String get workShowOnProfile => 'اعرضه في ملفي';

  @override
  String get workShowOnProfileHelp =>
      'العنوان وصورة واحدة والمكان ومن فحصه فقط. لا تظهر المساحة ولا النقاش.';

  @override
  String workReassignedLine(String from, String to) {
    return 'أُعيد التكليف من $from إلى $to';
  }

  @override
  String get workSomeone => 'شخص ما';

  @override
  String get deliveredTitle => 'عمل أنجزته';

  @override
  String get deliveredIntro =>
      'بنود العمل التي فُحصت وأُغلقت في مساحة فقط. كل شيء مخفي حتى تُظهره. تظهر البنود المعروضة في ملفك.';

  @override
  String get deliveredShown => 'معروض في الملف';

  @override
  String get deliveredHidden => 'مخفي · اضغط للعرض';

  @override
  String deliveredCheckedBy(String name, String date) {
    return 'الفحص: $name · $date';
  }

  @override
  String get deliveredFooter =>
      'يرى الناس من فحص كل بند. تبقى بنود المساحة التي غادرتها لك لتعرضها أو تخفيها.';

  @override
  String get deliveredEmpty => 'لا شيء بعد. تظهر هنا بنودك بعد فحصها.';

  @override
  String get deliveredSeeAll => 'عرض الكل';

  @override
  String get deliveredPublicTitle => 'عمل منجز';

  @override
  String deliveredShownBy(String name) {
    return 'من ملف $name';
  }

  @override
  String get deliveredProject => 'المشروع';

  @override
  String get deliveredPlace => 'المكان';

  @override
  String get deliveredCheckedRow => 'الفحص';

  @override
  String deliveredPrivacy(String name) {
    return 'عُرض هذا باختيار $name. يبقى النقاش والملفات والمساحة خاصة. يظهر العنوان والصورة والمكان ومن فحصه فقط.';
  }

  @override
  String deliveredStamp(String date) {
    return 'تم الفحص · $date';
  }

  @override
  String get workCheckConfirm => 'أغلقه';

  @override
  String get deliveredNoneShown =>
      'لا شيء معروض بعد. اضغط «عرض الكل» لتختار ما يظهر.';

  @override
  String deliveredCheckedOn(String date) {
    return 'تم الفحص · $date';
  }

  @override
  String get deliveredCheckedRowNoName => 'تم الفحص';

  @override
  String get chatEveryone => 'الجميع';

  @override
  String get chatTeam => 'الفريق';

  @override
  String get chatThreadsNote => 'ترى محادثة «الجميع» ومحادثات فرقك.';

  @override
  String get chatThreadsNoteAdmin =>
      'بصفتك مدير المساحة، ترى «الجميع» وكل الفرق.';

  @override
  String get chatNoMessages => 'لا رسائل بعد.';

  @override
  String get chatYou => 'أنت';

  @override
  String chatLastLine(String name, String text) {
    return '$name: $text';
  }

  @override
  String get chatPhoto => 'صورة';

  @override
  String get chatFile => 'ملف';

  @override
  String get chatVoice => 'رسالة صوتية';

  @override
  String get chatWorkItemUpdate => 'تحديث بند عمل';

  @override
  String get chatToday => 'اليوم';

  @override
  String get chatYesterday => 'أمس';

  @override
  String chatTeamPrivacy(String team) {
    return 'لا يرى هذه المحادثة إلا $team ومديرو المساحة.';
  }

  @override
  String get chatMessageHint => 'رسالة';

  @override
  String get chatSend => 'إرسال';

  @override
  String get chatDeleted => 'حُذفت الرسالة';

  @override
  String get chatSending => 'جارٍ الإرسال…';

  @override
  String get chatNotSent => 'لم تُرسل';

  @override
  String get chatRetry => 'إعادة المحاولة';

  @override
  String get chatReply => 'رد';

  @override
  String get chatCopy => 'نسخ';

  @override
  String get chatCopied => 'تم النسخ.';

  @override
  String get chatDelete => 'حذف الرسالة';

  @override
  String get chatDeleteTitle => 'حذف هذه الرسالة؟';

  @override
  String get chatDeleteBody =>
      'سيرى الجميع في هذه المحادثة «حُذفت الرسالة» بدلاً منها.';

  @override
  String get chatDeleteConfirm => 'حذف';

  @override
  String chatReplyingTo(String name) {
    return 'رد على $name';
  }

  @override
  String get chatCancelReply => 'إلغاء الرد';

  @override
  String chatCardRaised(String name) {
    return 'بند عمل جديد من $name';
  }

  @override
  String chatCardDone(String name) {
    return 'توقيع كمنجز من $name';
  }

  @override
  String chatCardChecked(String name) {
    return 'فحص وإغلاق من $name';
  }

  @override
  String chatCardSentBack(String name) {
    return 'إرجاع بند عمل من $name';
  }

  @override
  String chatCardReassigned(String name) {
    return 'إعادة تكليف بند عمل من $name';
  }

  @override
  String get chatItemGone => 'لم يعد بند العمل هذا في المساحة.';

  @override
  String chatLastRaised(String name, String ref) {
    return 'بند عمل جديد $ref من $name';
  }

  @override
  String chatLastDone(String name, String ref) {
    return 'توقيع $ref كمنجز من $name';
  }

  @override
  String chatLastChecked(String name, String ref) {
    return 'فحص وإغلاق $ref من $name';
  }

  @override
  String chatLastSentBack(String name, String ref) {
    return 'إرجاع $ref من $name';
  }

  @override
  String chatLastReassigned(String name, String ref) {
    return 'إعادة تكليف $ref من $name';
  }

  @override
  String get chatAttach => 'إضافة صورة أو ملف';

  @override
  String get chatAttachCamera => 'التقط صورة';

  @override
  String get chatAttachGallery => 'صورة من هاتفك';

  @override
  String get chatAttachPdf => 'ملف PDF من هاتفك';

  @override
  String get chatAttachPdfHelp => 'يُضاف إلى مكتبة المساحة أيضاً.';

  @override
  String get chatRemoveFile => 'إزالة';

  @override
  String get chatFileNotAllowed => 'ملفات PDF والصور فقط.';

  @override
  String get chatFileTooBig => 'حتى 25 ميغابايت للملف.';

  @override
  String get chatOneDocument => 'ملف PDF واحد في كل رسالة.';

  @override
  String fileSizeMb(String size) {
    return '$size ميغابايت';
  }

  @override
  String fileSizeKb(String size) {
    return '$size كيلوبايت';
  }

  @override
  String get librarySearch => 'ابحث في العناوين وأسماء الملفات';

  @override
  String get libraryAll => 'الكل';

  @override
  String get libraryFiles => 'الملفات';

  @override
  String get libraryRecent => 'الأحدث في هذه المساحة';

  @override
  String get libraryFromChat => 'من المحادثة';

  @override
  String get libraryEmpty =>
      'لا ملفات بعد. تظهر هنا الرسومات والصور المشتركة في هذه المساحة.';

  @override
  String get libraryNoMatch => 'لا نتائج.';

  @override
  String get libraryAdd => 'إضافة ملف';

  @override
  String get libraryAddTitle => 'إضافة إلى المكتبة';

  @override
  String get libraryRevisionTitle => 'مراجعة جديدة';

  @override
  String libraryRevisionOf(String name) {
    return 'يحل محل $name. تبقى النسخة القديمة في السجل.';
  }

  @override
  String get libraryPickFile => 'اختر ملف PDF أو صورة';

  @override
  String get libraryChangeFile => 'اختر ملفاً آخر';

  @override
  String get libraryName => 'العنوان';

  @override
  String get libraryFor => 'من يراه';

  @override
  String libraryTeamOnly(String team) {
    return 'لا يراه إلا $team ومديرو المساحة.';
  }

  @override
  String get libraryRev => 'المراجعة';

  @override
  String get libraryRevHint => 'مثلاً Rev C';

  @override
  String get libraryNoteHint => 'ما الذي تغيّر';

  @override
  String get libraryUpload => 'رفع';

  @override
  String get libraryAdded => 'أُضيف إلى المكتبة.';

  @override
  String get libraryPickFirst => 'اختر ملفاً أولاً.';

  @override
  String get libraryNameRequired => 'أضف عنواناً.';

  @override
  String previewFrom(String name) {
    return 'من $name';
  }

  @override
  String previewCurrent(String rev) {
    return '$rev · الحالية';
  }

  @override
  String get previewCurrentNoRev => 'الحالية';

  @override
  String previewUploaded(String date) {
    return 'رُفع في $date';
  }

  @override
  String get previewUsedIn => 'مستخدم في';

  @override
  String get previewSuperseded => 'استُبدل، ويبقى في السجل';

  @override
  String get previewReplaced => 'حلّت مراجعة أحدث محل هذه.';

  @override
  String get previewOpenCurrent => 'افتح الحالية';

  @override
  String get previewShare => 'شارك في المحادثة';

  @override
  String get previewDownload => 'تنزيل';

  @override
  String get previewNewRevision => 'رفع مراجعة جديدة';

  @override
  String get previewShareTo => 'المشاركة في أي محادثة؟';

  @override
  String get previewShareTeamOnly => 'يُشارك ملف الفريق في محادثة فريقه فقط.';

  @override
  String previewShared(String thread) {
    return 'تمت المشاركة في $thread.';
  }

  @override
  String get previewSaved => 'تم الحفظ.';

  @override
  String get previewCantShow => 'لا يمكن عرض هذا الملف هنا. نزّله لفتحه.';

  @override
  String get previewClose => 'إغلاق';

  @override
  String get previewSendFile => 'مشاركة الملف';

  @override
  String workAttachTitle(String ref) {
    return 'إرفاق بـ $ref';
  }

  @override
  String get workAttachLibrary => 'من مكتبة المساحة';

  @override
  String get workAttachLibraryHelp => 'رسومات وملفات مشتركة في هذه المساحة';

  @override
  String get workAttachPhone => 'من هاتفك';

  @override
  String get workAttachPhoneHelp =>
      'PDF أو صورة · تُحفظ في مكتبة المساحة أيضاً';

  @override
  String get workAttachPhoto => 'التقط صورة أخرى';

  @override
  String get workAttachPhotoHelp => 'تُضاف إلى صور البند';

  @override
  String get workAttached => 'مرفقات';

  @override
  String get workAttachedFromLibrary => 'من مكتبة المساحة';

  @override
  String get workAttach => 'إرفاق رسم أو ملف';

  @override
  String get workAttachedToast => 'تم الإرفاق.';

  @override
  String get workAlsoInTeamChat => 'أيضاً في محادثة الفريق';

  @override
  String get libraryPickTitle => 'اختر من المكتبة';

  @override
  String libraryPickTeamNote(String team) {
    return 'يمكن إرفاق ملفات «الجميع» وملفات $team فقط بهذا البند.';
  }

  @override
  String get chatFileRemoved => 'تمت إزالة الملف';

  @override
  String get chatRecord => 'اضغط مطولاً لتسجيل رسالة صوتية';

  @override
  String get chatSlideToCancel => 'اسحب بعيداً للإلغاء';

  @override
  String get chatReleaseToCancel => 'ارفع إصبعك للإلغاء';

  @override
  String get chatMicDenied =>
      'اسمح باستخدام الميكروفون من إعدادات هاتفك للتسجيل.';

  @override
  String get chatVoiceTooShort => 'اضغط مدة أطول قليلاً للتسجيل.';

  @override
  String get chatPlay => 'تشغيل';

  @override
  String get chatPause => 'إيقاف مؤقت';

  @override
  String feedBeyond(String market) {
    return 'خارج $market';
  }

  @override
  String get feedEmpty => 'لا منشورات بعد. شارك ما حدث في الموقع اليوم.';

  @override
  String get feedCouldntLoad => 'تعذّر تحميل الأخبار';

  @override
  String get feedCouldntLoadBody =>
      'تحقّق من الاتصال وحاول مرة أخرى. لم يُفقد شيء.';

  @override
  String get feedOffline => 'أنت غير متصل. نعرض ما حمّلته من قبل.';

  @override
  String get feedNewPost => 'منشور جديد';

  @override
  String get postUseful => 'مفيد';

  @override
  String get postReply => 'رد';

  @override
  String postUsefulOne(String a) {
    return 'وجده مفيداً: $a';
  }

  @override
  String postUsefulTwo(String a, String b) {
    return 'وجده مفيداً: $a و$b';
  }

  @override
  String get postEdited => 'معدّل';

  @override
  String get postMenu => 'خيارات المنشور';

  @override
  String postMute(String name) {
    return 'كتم $name';
  }

  @override
  String postMuted(String name) {
    return 'تم كتم $name';
  }

  @override
  String get postUndo => 'تراجع';

  @override
  String get postEdit => 'تعديل المنشور';

  @override
  String get postDelete => 'حذف المنشور';

  @override
  String get postDeleteTitle => 'حذف هذا المنشور؟';

  @override
  String get postDeleteBody => 'سيُحذف من الأخبار وملفك وصفحة المشروع.';

  @override
  String get postDeleted => 'حُذف المنشور.';

  @override
  String get postOpenPhoto => 'فتح الصورة';

  @override
  String get postTitle => 'منشور';

  @override
  String get postReplies => 'الردود';

  @override
  String get postNoReplies => 'لا ردود بعد.';

  @override
  String get postAddComment => 'أضف تعليقاً';

  @override
  String get postWriteReply => 'اكتب رداً';

  @override
  String postReplyingTo(String name) {
    return 'ردّاً على $name';
  }

  @override
  String get postCancelReply => 'إلغاء الرد';

  @override
  String get postSendReply => 'إرسال';

  @override
  String get postReplyMenu => 'خيارات التعليق';

  @override
  String get postDeleteReply => 'حذف التعليق';

  @override
  String get postDeleteReplyTitle => 'حذف التعليق؟';

  @override
  String get postDeleteReplyBody => 'سيُحذف من هذا المنشور لدى الجميع.';

  @override
  String get postUnavailable => 'هذا المنشور غير متاح';

  @override
  String get postUnavailableBody =>
      'ربما حُذف، أو ليس لديك صلاحية الوصول إليه.';

  @override
  String get postBackHome => 'العودة إلى الرئيسية';

  @override
  String get postPosting => 'جارٍ النشر لشبكتك…';

  @override
  String get postFailed => 'تعذّر النشر. حُفظ كمسودة.';

  @override
  String get postFailedHint => 'تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get postDiscardDraft => 'حذف المسودة';

  @override
  String get composerPostingTo => 'النشر إلى';

  @override
  String get composerYourNetwork => 'شبكتك';

  @override
  String get composerEveryone => 'الجميع';

  @override
  String composerTagged(String project) {
    return 'مع وسم $project';
  }

  @override
  String get composerHint => 'ماذا حدث في الموقع اليوم؟';

  @override
  String get composerStartFrom => 'ابدأ من';

  @override
  String get tplProgress => 'تحديث سير العمل';

  @override
  String get tplProgressHelp => 'تم اليوم · التالي · ما يعيقنا';

  @override
  String get tplProgressLines => 'تم اليوم:\nالتالي:\nما يعيقنا:';

  @override
  String get tplMilestone => 'إنجاز مرحلة';

  @override
  String get tplMilestoneHelp => 'ماذا · متى · من أنجزه';

  @override
  String get tplMilestoneLines => 'ماذا:\nمتى:\nمن أنجزه:';

  @override
  String get tplVisit => 'زيارة موقع';

  @override
  String get tplVisitHelp => 'أين · ماذا وجدنا · الإجراءات';

  @override
  String get tplVisitLines => 'أين:\nماذا وجدنا:\nالإجراءات:';

  @override
  String get tplAsk => 'اسأل المجتمع';

  @override
  String get tplAskHelp => 'السؤال · من يعرف';

  @override
  String get tplAskLines => 'السؤال:\nمن يعرف:';

  @override
  String get composerMedia => 'الوسائط';

  @override
  String get composerProject => 'المشروع';

  @override
  String get composerPost => 'نشر';

  @override
  String get composerSave => 'حفظ';

  @override
  String get composerChooseHint => 'اختر طريقة البدء، أو اكتب مباشرة';

  @override
  String composerPostingToProject(String project) {
    return 'النشر إلى $project';
  }

  @override
  String get composerAudience => 'يمكن لأي شخص على BuildVibes رؤية هذا.';

  @override
  String get composerAudienceProject =>
      'يمكن لأي شخص على BuildVibes رؤية هذا. ويظهر أيضاً في صفحة المشروع.';

  @override
  String composerWrittenIn(String lang) {
    String _temp0 = intl.Intl.selectLogic(lang, {
      'ar': 'بالعربية',
      'other': 'بالإنجليزية',
    });
    return 'مكتوب $_temp0';
  }

  @override
  String get composerChange => 'تغيير';

  @override
  String get langEnglish => 'English';

  @override
  String get langArabic => 'العربية';

  @override
  String get langAuto => 'يُحدَّد تلقائياً';

  @override
  String get composerLangTitle => 'لغة المنشور';

  @override
  String get composerPhotosMax => 'حتى 4 صور.';

  @override
  String get composerRemovePhoto => 'إزالة الصورة';

  @override
  String get postToTitle => 'النشر إلى';

  @override
  String get postToWho => 'من يراه';

  @override
  String get postToNetworkHelp => 'المتابعون والاستكشاف · يمكن لأي شخص الرؤية';

  @override
  String get postToNote =>
      'المنشورات عامة ويمكن ربطها بمشروع. عمل فريقك يذهب إلى مساحة المشروع كبند عمل.';

  @override
  String get tagTitle => 'ربط مشروع';

  @override
  String get tagHelp => 'المشاريع التي لديك فيها دور مؤكَّد فقط.';

  @override
  String get tagEmpty => 'أضف مشروعاً في ملفك أولاً';

  @override
  String get tagSpaceNote => 'عمل فريقك يذهب إلى مساحة المشروع كبند عمل';

  @override
  String get tagNone => 'بدون مشروع';

  @override
  String get discardTitle => 'تجاهل هذا المنشور؟';

  @override
  String get discardBody => 'سيُحذف النص والصور ورابط المشروع.';

  @override
  String get discardConfirm => 'تجاهل';

  @override
  String get projectPosts => 'المنشورات';

  @override
  String get projectPostsEmpty => 'لا منشورات مرتبطة بهذا المشروع بعد.';

  @override
  String get timeNowShort => 'الآن';

  @override
  String timeMinutesShort(int n) {
    return '$n د';
  }

  @override
  String timeHoursShort(int n) {
    return '$n س';
  }

  @override
  String get discardKeep => 'متابعة التعديل';
}
