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
  String get settingsLanguageRow => 'اللغة';

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
  String get signOffChecked => 'تم التحقق';

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
      'تعرّف على المهندسين ورؤساء العمال والحِرفيين والموردين. جهّز حضورك عندما تكون مستعدًا.';

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
  String get entryAudience4Body => 'احصل على التحقق من العمل واعتماده في وقته.';

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
      'تصفّح أولًا، وجهّز حضورك عندما تكون مستعدًا.';

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
      'انضم برقمك الذي تستخدمه. يستغرق الأمر دقيقة تقريبًا.';

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
      'نرسل رمزًا من 6 أرقام عبر واتساب. لا حاجة لكلمة مرور.';

  @override
  String get phoneHelpSms =>
      'نرسل رمزًا من 6 أرقام برسالة نصية. لا حاجة لكلمة مرور.';

  @override
  String get phoneSendSms => 'أرسل الرمز برسالة نصية بدلًا من ذلك';

  @override
  String get phoneUseEmail => 'استخدم بريدك الإلكتروني بدلًا من ذلك';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String phoneErrorMarket(String country, int digits) {
    return 'أدخل رقم جوال في $country من $digits أرقام.';
  }

  @override
  String get phoneErrorOther => 'أدخل رقم جوالك كاملًا.';

  @override
  String get dialCodeTitle => 'رمز الدولة';

  @override
  String get dialCodeOther => 'رمز دولة آخر';

  @override
  String get dialCodeOtherHelp => 'اكتب الرمز، مثلًا +91.';

  @override
  String get comingSoon => 'قريبًا';

  @override
  String get notOpenTitle => 'الحسابات الجديدة غير متاحة لهذا الرقم بعد';

  @override
  String notOpenSoon(String country) {
    return 'سنصل إلى $country قريبًا. إذا دعاك أحد إلى مساحة، افتح رابط الدعوة للانضمام الآن.';
  }

  @override
  String notOpenOther(String countries) {
    return 'الحسابات الجديدة متاحة حاليًا في $countries. إذا دعاك أحد إلى مساحة، افتح رابط الدعوة للانضمام الآن.';
  }

  @override
  String get commonOk => 'حسنًا';

  @override
  String get emailTitle => 'بريدك الإلكتروني';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get emailHelp => 'نرسل رمزًا من 6 أرقام. لا حاجة لكلمة مرور.';

  @override
  String get emailError => 'تحقق من عنوان البريد الإلكتروني.';

  @override
  String get emailUsePhone => 'استخدم رقم هاتفك بدلًا من ذلك';

  @override
  String get codeTitleWhatsapp => 'تحقق من واتساب';

  @override
  String get codeTitleSms => 'تحقق من رسائلك';

  @override
  String get codeTitleEmail => 'تحقق من بريدك';

  @override
  String codeSentWhatsapp(String destination) {
    return 'أرسلنا رمزًا من 6 أرقام إلى $destination عبر واتساب. يعمل لمدة 10 دقائق.';
  }

  @override
  String codeSentSms(String destination) {
    return 'أرسلنا رمزًا من 6 أرقام إلى $destination برسالة نصية. يعمل لمدة 10 دقائق.';
  }

  @override
  String codeSentEmail(String destination) {
    return 'أرسلنا رمزًا من 6 أرقام إلى $destination. يعمل لمدة 10 دقائق. تحقق من البريد غير المرغوب فيه إن لم تجده.';
  }

  @override
  String codeResendIn(String time) {
    return 'إعادة الإرسال بعد $time';
  }

  @override
  String get codeResend => 'أرسل رمزًا جديدًا';

  @override
  String get codeDifferentNumber => 'استخدم رقمًا آخر';

  @override
  String get codeDifferentEmail => 'استخدم بريدًا آخر';

  @override
  String get codeWrong => 'الرمز غير صحيح. تحقق منه وحاول مرة أخرى.';

  @override
  String get codeExpired => 'انتهت صلاحية الرمز. أرسل رمزًا جديدًا.';

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
      'الخطوة 1 من 2. هكذا سيجدك الناس. يمكنك التغيير لاحقًا.';

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
      'ماذا تعمل في الموقع أو المكتب؟ يظهر تحت اسمك ويحدد الأشخاص والمساحات التي تراها أولًا.';

  @override
  String get roleSearch => 'ابحث عن حرفة أو دور';

  @override
  String rolePopularIn(String country) {
    return 'الأكثر شيوعًا في $country';
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
  String get joinWallBody => 'يستغرق دقيقة تقريبًا. بدون كلمة مرور.';

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
  String get proofConfirmed => 'مؤكَّد';

  @override
  String get proofWaiting => 'بانتظار التأكيد';

  @override
  String get proofEmptyTitle => 'أضف مشروعًا لتبدأ إثباتك';

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
  String get workDeliveredEmpty => 'لا شيء تم التحقق منه بعد.';

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
      'لن يرى أيّ منكما منشورات الآخر أو ملفه، وتُزال المتابعات بينكما. ولا يصله أي إشعار.';

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
  String get startNewRecord => 'ليس أيًّا منها؟ ابدأ سجلًا جديدًا';

  @override
  String get startNewRecordSub =>
      'الاسم والنوع والتواريخ ودورك. دقيقة تقريبًا.';

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
  String get projectNameHint => 'مثال: مجمع الكوت المرحلة 2';

  @override
  String get projectTitle => 'المشروع';

  @override
  String get projectNoOwnerNote =>
      'يمكن لأي شخص وضع هذا المشروع في سيرته. لا أحد يملكه، وتراجع BuildVibes التصحيحات.';

  @override
  String get suggestEdit => 'اقترح تعديلًا';

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
    return 'اقترح تعديلًا على $project';
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
  String get correctValueHelp => 'أضف مصدرًا إن وُجد، مثل صورة لوحة الموقع.';

  @override
  String get correctValueRequired => 'اكتب القيمة الصحيحة.';

  @override
  String get sendForReview => 'إرسال للمراجعة';

  @override
  String get suggestionSent => 'شكرًا، سنراجعه.';

  @override
  String get monthPickerPresent => 'مستمر حتى الآن';

  @override
  String get entryContinueEmail => 'المتابعة بالبريد الإلكتروني';

  @override
  String get entryJoinBodyEmail =>
      'انضم ببريدك الإلكتروني. يستغرق الأمر دقيقة تقريبًا.';

  @override
  String get countryChangeLater => 'يمكنك تغييرها من الإعدادات.';

  @override
  String get mobileOptional => 'رقم الجوال (اختياري)';

  @override
  String get mobileHelp => 'خاص: أنت فقط تراه، ولا يظهر في ملفك أبدًا.';

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
  String get spacesEmptyTitle => 'انضم إلى أول مساحة لك';

  @override
  String get spacesEmptyBody =>
      'المساحة هي المكان الذي يدير فيه فريق المشروع عمله اليومي. عندما تنضم إلى مساحة، يظهر تقريرك اليومي هنا: الردود والتحديثات وكل ما ينتظرك.';

  @override
  String get spacesEmptyFeedNote =>
      'ستجد في الأخبار منشورات شبكتك وإعلاناتها وتهانيها.';

  @override
  String get spacesEnterCode => 'أدخل رمز الدعوة';

  @override
  String get spacesCodeHint => '6 أحرف وأرقام من الشخص الذي دعاك';

  @override
  String spacesInvitedBy(String name) {
    return 'دعوة من $name';
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
  String get spacesDeclinedWait => 'يمكنك الطلب مرة أخرى غدًا.';

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
  String get spacesNameHint => 'مثال: البرج B — فريق التصميم';

  @override
  String get spacesNameRequired => 'اكتب اسمًا من حرفين على الأقل.';

  @override
  String get spacesAboutLabel => 'نبذة (اختياري)';

  @override
  String get spacesAboutHelp => 'تظهر لمن تدعوهم.';

  @override
  String get spacesLinkLabel => 'ربط بمشروع (اختياري)';

  @override
  String get spacesLinkPlaceholder => 'اختر مشروعًا';

  @override
  String get spacesLinkHelp =>
      'ربط مشروع يجعل هذه مساحة المشروع، ويظهر المشروع مؤكَّدًا في ملف كل عضو تؤكّده.';

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
      'أرسل الرمز عبر واتساب أو اقرأه عليهم. يؤكد مدير المساحة كل شخص قبل انضمامه.';

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
      'أنشأت مساحات كثيرة اليوم. حاول مرة أخرى غدًا.';

  @override
  String get spacesInviteCodeTag => 'رمز الدعوة';

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'قبل $n دقيقة',
      few: 'قبل $n دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'قبل $n ساعة',
      few: 'قبل $n ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
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
      other: 'قبل $n يومًا',
      few: 'قبل $n أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String get spacesDecline => 'رفض';

  @override
  String get spacesYouTag => 'أنت';

  @override
  String get spacesPassLead => 'مسؤول';

  @override
  String get spacesPassCrew => 'فريق تنفيذ';

  @override
  String get spacesPassViewer => 'مُطّلع';

  @override
  String get spacesLeadOpens =>
      'يتيح: إنشاء البنود · التحقق والإغلاق · الملفات · الدعوة';

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
    return 'مؤكَّد من $name';
  }

  @override
  String get spacesConfirmedByYou => 'مؤكَّد منك';

  @override
  String get spacesRightChat => 'المحادثة في «الجميع» والفِرق';

  @override
  String get spacesRightMarkDone => 'توقيع البنود المكلّف بها كمنجزة';

  @override
  String get spacesRightFiles => 'إضافة ملفات إلى المكتبة';

  @override
  String get spacesRightCreate => 'إنشاء بنود عمل';

  @override
  String get spacesRightInvite => 'دعوة أشخاص';

  @override
  String get spacesAlways => 'دائمًا';

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
    return 'فُتحت صلاحية «$right» لـ $name. يظهر التصريح كمخصّص.';
  }

  @override
  String spacesRightLocked(String right, String name) {
    return 'أُقفلت صلاحية «$right» لـ $name.';
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
      'تحتاج المساحة إلى مدير. اجعل شخصًا آخر مديرًا أولًا.';

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
  String proofConfirmedBy(String names) {
    return 'مؤكَّد من $names';
  }

  @override
  String get spacesInfoTitle => 'معلومات المساحة';

  @override
  String get spacesWhoCanInvite => 'من يمكنه الدعوة';

  @override
  String get spacesNotifications => 'الإشعارات';

  @override
  String get spacesNotifyOff => 'إيقاف';

  @override
  String get spacesTransfer => 'نقل إدارة المساحة';

  @override
  String get spacesDeleteSpace => 'حذف المساحة';

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
  String get spacesEditTitle => 'تعديل المساحة';

  @override
  String get spacesTransferIntro =>
      'اختر عضوًا لتنتقل إليه إدارة المساحة. ستبقى في المساحة كعضو.';

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
    return 'تنتقل إدارة $space إلى $name وتصبح أنت عضوًا.';
  }

  @override
  String get spacesTransferButton => 'نقل';

  @override
  String spacesTransferred(String name) {
    return '$name الآن من مديري المساحة، وأنت عضو.';
  }

  @override
  String get spacesNoOneToTransfer => 'أكّد انضمام شخص إلى المساحة أولًا.';

  @override
  String get spacesTeams => 'الفِرق';

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
      other: 'إنشاء الفريق · $n شخصًا',
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
  String get spacesLastAdmin => 'اجعل شخصًا آخر مديرًا أولًا، أو احذف المساحة.';

  @override
  String get workItemGone => 'هذا البند غير متاح.';

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
    return 'التحقق: $name · $date';
  }

  @override
  String get deliveredFooter =>
      'يرى الناس من تحقّق من كل بند. تبقى بنود المساحة التي غادرتها لك لتعرضها أو تخفيها.';

  @override
  String get deliveredEmpty => 'لا شيء بعد. تظهر هنا بنودك بعد التحقق منها.';

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
  String get deliveredCheckedRow => 'التحقق';

  @override
  String deliveredPrivacy(String name) {
    return 'عُرض هذا باختيار $name. يبقى النقاش والملفات والمساحة خاصة. يظهر العنوان والصورة والمكان ومن تحقّق منه فقط.';
  }

  @override
  String get deliveredNoneShown =>
      'لا شيء معروض بعد. اضغط «عرض الكل» لتختار ما يظهر.';

  @override
  String deliveredCheckedOn(String date) {
    return 'تم التحقق · $date';
  }

  @override
  String get deliveredCheckedRowNoName => 'تم التحقق';

  @override
  String get chatEveryone => 'الجميع';

  @override
  String get chatTeam => 'الفريق';

  @override
  String get chatThreadsNote => 'ترى محادثة «الجميع» ومحادثات فِرقك.';

  @override
  String get chatThreadsNoteAdmin =>
      'بصفتك مدير المساحة، ترى «الجميع» وكل الفِرق.';

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
      'سيرى الجميع في هذه المحادثة «حُذفت الرسالة» بدلًا منها.';

  @override
  String get chatDeleteConfirm => 'حذف';

  @override
  String chatReplyingTo(String name) {
    return 'ردًّا على $name';
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
    return 'تحقّق وإغلاق من $name';
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
  String get chatCardHidden => 'بند عمل';

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
    return 'تحقّق وإغلاق $ref من $name';
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
  String get chatAttachPdfHelp => 'يُضاف إلى مكتبة المساحة أيضًا.';

  @override
  String get chatRemoveFile => 'إزالة';

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
  String get librarySearch => 'ابحث في الملفات';

  @override
  String get libraryFiles => 'الملفات';

  @override
  String get libraryFromChat => 'من المحادثة';

  @override
  String get libraryEmpty =>
      'لا ملفات بعد. تظهر هنا المخططات والصور التي تمت مشاركتها في هذه المساحة.';

  @override
  String get libraryNoMatch => 'لا نتائج.';

  @override
  String previewFrom(String name) {
    return 'من $name';
  }

  @override
  String previewCurrent(String rev) {
    return '$rev · الحالي';
  }

  @override
  String get previewCurrentNoRev => 'الحالي';

  @override
  String previewUploaded(String date) {
    return 'رُفع في $date';
  }

  @override
  String get previewUsedIn => 'مستخدم في';

  @override
  String get previewSuperseded => 'استُبدل، ويبقى في السجل';

  @override
  String get previewReplaced => 'حلّ محله إصدار أحدث.';

  @override
  String get previewOpenCurrent => 'افتح الإصدار الحالي';

  @override
  String get previewShare => 'شارك في المحادثة';

  @override
  String get previewDownload => 'تنزيل';

  @override
  String get previewShareTo => 'المشاركة في أي محادثة؟';

  @override
  String get previewShareTeamOnly => 'يُشارك ملف الفريق في محادثة فريقه فقط.';

  @override
  String get previewSaved => 'تم الحفظ.';

  @override
  String get previewCantShow => 'لا يمكن عرض هذا الملف هنا. نزّله لفتحه.';

  @override
  String get previewClose => 'إغلاق';

  @override
  String get previewSendFile => 'مشاركة الملف';

  @override
  String get chatFileRemoved => 'تمت إزالة الملف';

  @override
  String get chatRecord => 'اضغط مطولًا لتسجيل رسالة صوتية';

  @override
  String get chatSlideToCancel => 'اسحب بعيدًا للإلغاء';

  @override
  String get chatReleaseToCancel => 'ارفع إصبعك للإلغاء';

  @override
  String get chatMicDenied =>
      'اسمح باستخدام الميكروفون من إعدادات هاتفك للتسجيل.';

  @override
  String get chatVoiceTooShort => 'اضغط مدة أطول قليلًا للتسجيل.';

  @override
  String get chatPlay => 'تشغيل';

  @override
  String get chatPause => 'إيقاف مؤقت';

  @override
  String feedBeyond(String market) {
    return 'خارج $market';
  }

  @override
  String get feedEmpty => 'لا منشورات بعد. شارك ما حدث في العمل اليوم.';

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
    return 'علامة مفيد من $a';
  }

  @override
  String postUsefulTwo(String a, String b) {
    return 'علامة مفيد من $a و$b';
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
  String get postTitle => 'منشور';

  @override
  String get postReplies => 'الردود';

  @override
  String get postNoReplies => 'لا ردود بعد.';

  @override
  String get postWriteReply => 'اكتب ردًا';

  @override
  String postReplyingTo(String name) {
    return 'ردًّا على $name';
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
  String get langEnglish => 'English';

  @override
  String get langArabic => 'العربية';

  @override
  String get tagEmpty => 'أضف مشروعًا في ملفك أولًا';

  @override
  String get tagNone => 'بدون مشروع';

  @override
  String get projectPosts => 'المنشورات';

  @override
  String get projectPostsEmpty => 'لا منشورات مرتبطة بهذا المشروع بعد.';

  @override
  String homeDayNeedsYou(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n شيئًا بانتظارك',
      few: '$n أشياء بانتظارك',
      two: 'شيئان بانتظارك',
      one: 'شيء واحد بانتظارك',
    );
    return '$_temp0';
  }

  @override
  String get homeNeedsYou => 'بانتظارك';

  @override
  String get homeSeeAll => 'عرض الكل';

  @override
  String get homeJoinWithCode => 'انضم برمز';

  @override
  String get homeSearch => 'ابحث عن أشخاص';

  @override
  String get homeMySpaces => 'مساحاتي';

  @override
  String needsForYou(String name, String title) {
    return 'بند عمل لك من $name: $title';
  }

  @override
  String needsForYouSelf(String title) {
    return 'بند عمل لك: $title';
  }

  @override
  String needsYouCheck(String name, String title) {
    return 'منجز بتوقيع $name، بانتظار تحقّقك: $title';
  }

  @override
  String needsYouCheckSelf(String title) {
    return 'منجز، بانتظار تحقّقك: $title';
  }

  @override
  String needsSentBack(String name, String title) {
    return 'أُرجع إليك بند عمل من $name: $title';
  }

  @override
  String needsSentBackSelf(String title) {
    return 'أُرجع إليك بند عمل: $title';
  }

  @override
  String needsOwnerLeft(String title) {
    return 'لم يعد المكلّف في المساحة. يلزم تكليف شخص آخر: $title';
  }

  @override
  String needsJoin(String name, String space) {
    return 'طلب انضمام من $name إلى $space';
  }

  @override
  String needsDue(String date) {
    return 'الاستحقاق $date';
  }

  @override
  String todayItem(String event, String name, String ref, String title) {
    String _temp0 = intl.Intl.selectLogic(event, {
      'done': '$ref منجز بتوقيع $name',
      'checked': 'تحقّق $ref من $name',
      'sent_back': 'إرجاع $ref من $name',
      'comment': 'تحديث من $name · $ref',
      'reassigned': 'إعادة تكليف $ref من $name',
      'other': 'بند جديد $ref من $name',
    });
    return '$_temp0: $title';
  }

  @override
  String todayFile(String name, String file) {
    return 'ملف جديد من $name: $file';
  }

  @override
  String todayChat(String name, String text) {
    return '$name: $text';
  }

  @override
  String todayChatKind(String kind, String name) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'photo': 'صورة من $name',
      'voice': 'رسالة صوتية من $name',
      'file': 'ملف من $name',
      'other': 'رسالة من $name',
    });
    return '$_temp0';
  }

  @override
  String get activitySomeone => 'أحدهم';

  @override
  String get activityGroupNetwork => 'شبكتك';

  @override
  String activityJoinRequest(String name) {
    return 'طلب انضمام من $name';
  }

  @override
  String activityJoinConfirmed(String space) {
    return 'تم تأكيد انضمامك إلى $space';
  }

  @override
  String activityConfirmedBy(String name) {
    return 'مؤكَّد من $name';
  }

  @override
  String activityRoleConfirmed(String name) {
    return 'تأكيد دورك من $name';
  }

  @override
  String activityFollow(String name) {
    return 'متابِع جديد: $name';
  }

  @override
  String activityReplyPost(String name) {
    return 'ردّ من $name على منشورك';
  }

  @override
  String activityReplyReply(String name) {
    return 'ردّ من $name عليك';
  }

  @override
  String activityUseful1(String a) {
    return 'علامة مفيد على منشورك من $a';
  }

  @override
  String activityUseful2(String a, String b) {
    return 'علامة مفيد على منشورك من $a و$b';
  }

  @override
  String get activityUseful0 => 'علامة مفيد على منشورك';

  @override
  String activityItemDone(String name, String title) {
    return 'منجز بتوقيع $name: $title';
  }

  @override
  String activityItemChecked(String name, String title) {
    return 'تم الفحص من $name: $title';
  }

  @override
  String activityItemSentBack(String name, String title) {
    return 'إرجاع من $name: $title';
  }

  @override
  String activityItemUpdate(String name, String title) {
    return 'تحديث من $name: $title';
  }

  @override
  String activityRoleConfirmedOn(String name, String project) {
    return 'تأكيد دورك في $project من $name';
  }

  @override
  String activityReplyPostText(String name, String text) {
    return 'ردّ من $name على منشورك: $text';
  }

  @override
  String activityReplyReplyText(String name, String text) {
    return 'ردّ من $name عليك: $text';
  }

  @override
  String get activityWherePost => 'منشورك';

  @override
  String get activityWhereProfile => 'ملفك';

  @override
  String get activityEmptyTitle => 'لا شيء بانتظارك الآن.';

  @override
  String get activityEmptyBody => 'ما يحتاج ردّك ينتظرك هنا. هذا ما سيظهر:';

  @override
  String get ledgerWork => 'بنود العمل';

  @override
  String get ledgerWorkLine => 'تكليف لك ببند عمل، أو توقيع بند أنشأته كمنجز.';

  @override
  String get ledgerRequests => 'طلبات المساحات';

  @override
  String get ledgerRequestsLine => 'طلب انضمام إلى مساحة تديرها.';

  @override
  String get ledgerPosts => 'منشوراتك';

  @override
  String get ledgerPostsLine => 'ردّ على منشورك.';

  @override
  String get ledgerNetwork => 'شبكتك';

  @override
  String get ledgerNetworkLine => 'متابِع جديد لك.';

  @override
  String get ledgerWait => 'أثناء الانتظار';

  @override
  String get ledgerAddProject => 'أضف مشروعًا عملت فيه';

  @override
  String get settingsNotifications => 'الإشعارات';

  @override
  String get notifPeople => 'الأشخاص';

  @override
  String get notifFollowers => 'متابِعون جدد';

  @override
  String get notifPosts => 'منشوراتك';

  @override
  String get notifReplies => 'الردود';

  @override
  String get notifMessages => 'الرسائل';

  @override
  String get notifLockText => 'إظهار نص الرسالة على شاشة القفل';

  @override
  String get notifSpaces => 'المساحات';

  @override
  String get notifSpacesLine => 'لكل مساحة من معلومات المساحة ← الإشعارات';

  @override
  String get notifFooter => 'لا تذكر الإشعارات اسم مشروع أو مساحة أو بند عمل.';

  @override
  String get pushOffTitle => 'الإشعارات متوقفة';

  @override
  String get pushOffBody =>
      'ستفوتك بنود العمل والرسائل. فعّلها من إعدادات الهاتف.';

  @override
  String get pushOpenSettings => 'افتح إعدادات الهاتف';

  @override
  String get pushNotReaching => 'الإشعارات لا تصل إلى هذا الهاتف';

  @override
  String get pushFixIt => 'إصلاح';

  @override
  String get pushFixTitle => 'لتصل الإشعارات إلى هذا الهاتف';

  @override
  String get pushFixAutostart => 'التشغيل التلقائي: مفعّل لتطبيق BuildVibes.';

  @override
  String get pushFixBattery => 'توفير البطارية: «بلا قيود» لتطبيق BuildVibes.';

  @override
  String get pushFixPlayServices => 'إعداد البطارية نفسه لخدمات Google Play.';

  @override
  String get pushFixRestart => 'ثم إعادة تشغيل الهاتف.';

  @override
  String get pushFixOpen => 'فتح إعدادات BuildVibes';

  @override
  String get feedNew => 'جديد';

  @override
  String get daybookNew => 'جديد';

  @override
  String reportTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'post': 'الإبلاغ عن هذا المنشور',
      'reply': 'الإبلاغ عن هذا الرد',
      'message': 'الإبلاغ عن هذه الرسالة',
      'dm_message': 'الإبلاغ عن هذه الرسالة',
      'other': 'الإبلاغ عن هذا الحساب',
    });
    return '$_temp0';
  }

  @override
  String get reportSubtitle => 'لن يُعرف من أبلغ. اختر الأنسب.';

  @override
  String get reasonSpam => 'رسائل مزعجة أو احتيال';

  @override
  String get reasonSpamHelp => 'عروض وهمية، ترويج غير مرغوب';

  @override
  String get reasonHarassment => 'مضايقة أو إساءة';

  @override
  String get reasonHarassmentHelp => 'إهانات أو تهديدات أو استهداف شخص';

  @override
  String get reasonMisleading => 'خاطئ أو مضلل';

  @override
  String get reasonMisleadingHelp => 'ادعاءات غير صحيحة';

  @override
  String get reasonFake => 'هذا غير حقيقي';

  @override
  String get reasonFakeHelp => 'شخص أو شركة أو مشروع وهمي';

  @override
  String get reasonPrivate => 'كشف معلومات خاصة';

  @override
  String get reasonPrivateHelp => 'مستندات أو مخططات أو تفاصيل ليست للنشر';

  @override
  String get reasonOther => 'شيء آخر';

  @override
  String get reasonOtherHelp => 'أخبرنا بكلمات قليلة';

  @override
  String get reportNoteTitle => 'ما المشكلة؟';

  @override
  String get reportNoteHint => 'بضع كلمات';

  @override
  String get reportSend => 'إرسال البلاغ';

  @override
  String get reportSentTitle => 'تم إرسال البلاغ';

  @override
  String get reportSentBody =>
      'سنراجعه وقد نزيل ما يخالف القواعد. لن يُعرف من أبلغ.';

  @override
  String get reportDone => 'تم';

  @override
  String get reportBlock => 'حظر هذا الحساب';

  @override
  String get postReport => 'الإبلاغ عن المنشور';

  @override
  String get replyReport => 'الإبلاغ عن الرد';

  @override
  String get chatReport => 'الإبلاغ عن الرسالة';

  @override
  String get profileReport => 'الإبلاغ عن الحساب';

  @override
  String blockDone(String name) {
    return 'تم حظر $name';
  }

  @override
  String get blockedTitle => 'الحسابات المحظورة';

  @override
  String blockedCount(int n) {
    return 'المحظورون · $n';
  }

  @override
  String get blockedNone => 'لا أحد محظور';

  @override
  String get unblock => 'إلغاء الحظر';

  @override
  String unblocked(String name) {
    return 'تم إلغاء حظر $name';
  }

  @override
  String get blockedNote =>
      'لا تستطيع الحسابات المحظورة متابعتك أو رؤية منشوراتك، ولا يصلها أي إشعار.';

  @override
  String removedTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'post': 'منشور محذوف',
      'reply': 'رد محذوف',
      'other': 'رسالة محذوفة',
    });
    return '$_temp0';
  }

  @override
  String removedHeading(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'post': 'أزلنا منشورك',
      'reply': 'أزلنا ردّك',
      'other': 'أزلنا رسالتك',
    });
    return '$_temp0';
  }

  @override
  String removedBody(String reason) {
    return 'تم الإبلاغ عن المحتوى بسبب $reason، وتأكدنا من ذلك بعد المراجعة. لا يرى هذا الإشعار غيرك.';
  }

  @override
  String reasonPhrase(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'spam': 'رسائل مزعجة أو احتيال',
      'harassment': 'مضايقة أو إساءة',
      'misleading': 'معلومات خاطئة أو مضللة',
      'fake': 'أنه غير حقيقي',
      'private_info': 'كشف معلومات خاصة',
      'other': 'أمر آخر',
    });
    return '$_temp0';
  }

  @override
  String removedYour(String kind, String date) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'post': 'منشورك',
      'reply': 'ردّك',
      'other': 'رسالتك',
    });
    return '$_temp0 · $date';
  }

  @override
  String get removedAppealNote => 'أمامك 14 يومًا للاعتراض. سنراجعه مرة أخرى.';

  @override
  String get removedAppeal => 'اعترض على القرار';

  @override
  String removedAppealOpen(String date) {
    return 'اعترضت في $date. سنخبرك بالنتيجة في النشاط.';
  }

  @override
  String get removedClosed => 'انتهت مدة الاعتراض (14 يومًا).';

  @override
  String get removedUpheld => 'راجعناه مرة أخرى: يبقى محذوفًا.';

  @override
  String get removedReversed => 'راجعناه مرة أخرى وأعدناه.';

  @override
  String get removedGone => 'هذا الإشعار غير متاح.';

  @override
  String get appealTitle => 'اعتراض';

  @override
  String get appealHeading => 'أخبرنا لماذا كان هذا خطأ';

  @override
  String get appealHelp =>
      'أضف ما يساعد المراجعة. لا تذكر تفاصيل خاصة بأشخاص آخرين.';

  @override
  String get appealLabel => 'توضيحك';

  @override
  String get appealLimit => 'حتى 500 حرف';

  @override
  String get appealSend => 'إرسال الاعتراض';

  @override
  String get appealReceived => 'تم استلام الاعتراض';

  @override
  String get appealReceivedBody =>
      'سنراجعه مرة أخرى، وسنخبرك بالنتيجة في النشاط، عادةً خلال 3 أيام.';

  @override
  String activityRemoved(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'post': 'أُزيل منشورك',
      'reply': 'أُزيل ردّك',
      'other': 'أُزيلت رسالتك',
    });
    return '$_temp0';
  }

  @override
  String activityAppealResult(String result) {
    String _temp0 = intl.Intl.selectLogic(result, {
      'reversed': 'اعتراضك: أُعيد المحتوى',
      'other': 'اعتراضك: يبقى محذوفًا',
    });
    return '$_temp0';
  }

  @override
  String get settingsViewProfile => 'عرض الملف الشخصي';

  @override
  String get settingsLanguageLabel => 'اللغة';

  @override
  String get accountSecurity => 'الحساب والأمان';

  @override
  String get accountSecuritySub => 'تنزيل البيانات، حذف الحساب';

  @override
  String get privacySafety => 'الخصوصية والأمان';

  @override
  String get languageRegion => 'اللغة والمنطقة';

  @override
  String get helpFeedback => 'المساعدة والملاحظات';

  @override
  String get aboutLegal => 'عن BuildVibes والشروط';

  @override
  String get aboutLegalSub => 'الشروط وسياسة الخصوصية';

  @override
  String aboutBuild(String version, String build, String commit) {
    return 'الإصدار $version · البناء $build · $commit';
  }

  @override
  String get legalTerms => 'شروط الاستخدام';

  @override
  String get legalPrivacy => 'سياسة الخصوصية';

  @override
  String get legalSoon => 'هذه الصفحات قيد الإعداد. يسعدنا تلقي أي سؤال.';

  @override
  String get linkFailed => 'تعذّر فتح هذا على الهاتف.';

  @override
  String get signOutTitle => 'تسجيل الخروج من BuildVibes؟';

  @override
  String get signOutBody =>
      'للدخول مرة أخرى يلزم رمز يُرسل إلى البريد الإلكتروني.';

  @override
  String get accountYourData => 'بياناتك';

  @override
  String get downloadData => 'تنزيل بياناتي';

  @override
  String get downloadDataSub => 'نرسل نسخة بالبريد خلال 7 أيام';

  @override
  String get dangerZone => 'منطقة الخطر';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountSub => 'يُحذف بعد 30 يومًا، ويمكن استعادته قبل ذلك.';

  @override
  String get privacySafetySection => 'الأمان';

  @override
  String get privacyNote =>
      'بنود العمل والمحادثة والمكتبة تبقى داخل كل مساحة، ولا يراها إلا أعضاؤها.';

  @override
  String get languageEnglishDir => 'من اليسار إلى اليمين';

  @override
  String get languageArabicDir => 'من اليمين إلى اليسار';

  @override
  String get regionSection => 'المنطقة';

  @override
  String get regionCountry => 'الدولة';

  @override
  String get regionWeekStart => 'بداية الأسبوع';

  @override
  String get regionNote =>
      'العربية تجعل التطبيق كله من اليمين إلى اليسار. تبقى المنشورات باللغة التي كُتبت بها.';

  @override
  String get downloadHeading => 'نسخة من بياناتك';

  @override
  String get downloadBody => 'نرسل بالبريد ملفًا فيه كل ما يلي، خلال 7 أيام.';

  @override
  String get downloadIncluded => 'ما يشمله';

  @override
  String get downloadProfile => 'الملف والإعدادات';

  @override
  String get downloadPosts => 'المنشورات والردود';

  @override
  String get downloadMessages => 'الرسائل المرسلة منك';

  @override
  String get downloadWork => 'بنود العمل والملاحظات الخاصة بك';

  @override
  String get downloadRequest => 'طلب بياناتي';

  @override
  String downloadFoot(String email) {
    return 'نرسلها إلى $email.';
  }

  @override
  String get requestReceived => 'وصل الطلب';

  @override
  String requestReceivedBody(String email) {
    return 'سنراسل $email خلال 7 أيام.';
  }

  @override
  String get deleteHeading => 'قبل الحذف';

  @override
  String get deleteBody => 'يُخفى ملفك فورًا، ولديك 30 يومًا لتغيير رأيك.';

  @override
  String get deleteWhat => 'ما الذي يحدث';

  @override
  String get deleteProfile => 'يُحذف الملف والمنشورات والردود';

  @override
  String get deleteSpaceWork => 'العمل والملفات في المساحة تبقى فيها';

  @override
  String get deleteSpaceWorkSub => 'باسم «عضو سابق»';

  @override
  String get deleteMessages => 'الرسائل المرسلة تبقى في محادثة المساحة';

  @override
  String get deleteContinue => 'متابعة';

  @override
  String get deleteKeep => 'إبقاء حسابي';

  @override
  String get transferFirst => 'نقل الإدارة أولًا';

  @override
  String get transferFirstBody =>
      'لا مدير لهذه المساحة غيرك، وفيها أعضاء آخرون. يلزم نقل إدارتها إلى عضو آخر قبل حذف الحساب.';

  @override
  String get transferOnlyAdmin => 'المدير الوحيد';

  @override
  String get confirmHeading => 'تأكيد الهوية';

  @override
  String confirmBody(String email) {
    return 'يُرجى إدخال الرمز المرسل إلى $email.';
  }

  @override
  String get deleteMyAccount => 'حذف حسابي';

  @override
  String deleteFoot(String date) {
    return 'سيُحذف الحساب في $date. يمكن استعادته بالدخول قبل ذلك.';
  }

  @override
  String get scheduledTitle => 'الحذف مجدول';

  @override
  String scheduledBody(String date) {
    return 'سيُحذف الحساب في $date. الملف مخفي الآن، ويمكن استعادته في أي وقت قبل ذلك.';
  }

  @override
  String get restoreAccount => 'استعادة حسابي';

  @override
  String get formerMember => 'عضو سابق';

  @override
  String get daybookYou => 'أنت';

  @override
  String get daybookForYou => 'لك';

  @override
  String daybookForPerson(String name) {
    return 'لـ $name';
  }

  @override
  String daybookMeta(String who, String due) {
    return '$who · $due';
  }

  @override
  String daybookDueDate(String date) {
    return 'موعده $date';
  }

  @override
  String get daybookDueToday => 'خلال اليوم';

  @override
  String get daybookDueTomorrow => 'غدًا';

  @override
  String daybookDueDateAt(String date, String time) {
    return 'قبل الساعة $time يوم $date';
  }

  @override
  String daybookDueTodayAt(String time) {
    return 'قبل الساعة $time اليوم';
  }

  @override
  String daybookDueTomorrowAt(String time) {
    return 'قبل الساعة $time غدًا';
  }

  @override
  String daybookWasDue(String date) {
    return 'كان موعده $date';
  }

  @override
  String daybookWasDueAt(String date, String time) {
    return 'كان موعده الساعة $time يوم $date';
  }

  @override
  String daybookWasDueTodayAt(String time) {
    return 'كان موعده الساعة $time اليوم';
  }

  @override
  String get daybookToDo => 'مطلوب منك';

  @override
  String daybookPoints(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n نقطة',
      many: '$n نقطة',
      few: '$n نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get daybookToday => 'اليوم';

  @override
  String get daybookTomorrow => 'غدًا';

  @override
  String get daybookStampDone => 'منجز';

  @override
  String get daybookStampChecked => 'تم التحقق';

  @override
  String get daybookStampSentBack => 'مُرجَع';

  @override
  String get daybookStampCancelled => 'ملغى';

  @override
  String get daybookWorkItem => 'بند عمل';

  @override
  String get daybookReadOnly => 'للقراءة فقط';

  @override
  String get daybookMonthPosts => 'منشورات';

  @override
  String get daybookMonthDue => 'موعد مستحق';

  @override
  String get daybookFirstTitle => 'الصفحة الأولى من يومية فريقك';

  @override
  String get daybookFirstBody => 'كل ما ينشره فريقك سيُعلَّق هنا، يومًا بيوم.';

  @override
  String get daybookFirstPost => 'انشر أول بند عمل';

  @override
  String get daybookFirstInvite => 'ادعُ فريقك';

  @override
  String daybookStampBy(String name, String time) {
    return '$name · $time';
  }

  @override
  String timePeriod(String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'morning': 'صباحًا',
      'noon': 'ظهرًا',
      'afternoon': 'عصرًا',
      'evening': 'مساءً',
      'other': 'مساءً',
    });
    return '$_temp0';
  }

  @override
  String timeClock12(String time, String period) {
    return '$time $period';
  }

  @override
  String get daybookDoubleTapToCheck => 'انقر مرتين على الصورة للتحقق';

  @override
  String daybookFileChip(String name, String revision) {
    return '$name $revision';
  }

  @override
  String get daybookWaitingToSend => 'بانتظار الإرسال';

  @override
  String get daybookDraft => 'مسودة';

  @override
  String get daybookWritingTitle => 'العنوان';

  @override
  String get daybookWritingBody => 'اكتب ما يجب عمله';

  @override
  String get daybookAssign => 'تكليف';

  @override
  String get daybookLocation => 'المكان';

  @override
  String get daybookDueDateMenu => 'الموعد';

  @override
  String daybookDueProperty(String date, String time) {
    return '$date، $time';
  }

  @override
  String get daybookCamera => 'التقاط صورة';

  @override
  String get daybookAddPhoto => 'إضافة صورة';

  @override
  String get daybookMore => 'المزيد';

  @override
  String get daybookPost => 'نشر';

  @override
  String get daybookRemovePhoto => 'إزالة الصورة';

  @override
  String get daybookGiveToSearch => 'التكليف إلى…';

  @override
  String get daybookOwnerNow => 'الآن';

  @override
  String get daybookPlaceHint => 'أين';

  @override
  String get daybookNoTime => 'بدون وقت';

  @override
  String get daybookDueTimeHelp => 'قبل ساعة محددة؟';

  @override
  String get daybookAssignSearch => 'التكليف إلى…';

  @override
  String get daybookCouldNotSend => 'تعذّر الإرسال. انقر للتصحيح';

  @override
  String get daybookRemoveDue => 'إزالة';

  @override
  String get daybookSignAsDone => 'وقّع كمنجز';

  @override
  String get daybookHoldToProve => 'اضغط مطوّلًا للإثبات';

  @override
  String get daybookCheck => 'تحقّق';

  @override
  String get daybookSendBack => 'إرجاع';

  @override
  String get daybookAddUpdate => 'إضافة تحديث';

  @override
  String get daybookEdit => 'تعديل';

  @override
  String get daybookGiveTo => 'تكليف شخص آخر';

  @override
  String get daybookCancelItem => 'إلغاء بند العمل';

  @override
  String daybookSendBackTo(String name) {
    return 'إرجاع إلى $name';
  }

  @override
  String get daybookReasonPhotoMissing => 'الصورة غير موجودة';

  @override
  String get daybookReasonNotAsAsked => 'غير مطابق للمطلوب';

  @override
  String get daybookReasonNotFinished => 'غير مكتمل';

  @override
  String get daybookReasonOther => 'سبب آخر';

  @override
  String get daybookNoteOptional => 'ملاحظة (اختياري)';

  @override
  String get daybookNoteNeeded => 'اكتب ما المشكلة';

  @override
  String get daybookChecked => 'تم التحقق';

  @override
  String get daybookCancelled => 'أُلغي';

  @override
  String get daybookUndo => 'تراجع';

  @override
  String get daybookUpdateHint => 'اكتب تحديثًا';

  @override
  String get daybookSendAsDone => 'أرسل كمنجز';

  @override
  String get daybookAddAnotherPhoto => 'أضف صورة أخرى';

  @override
  String get daybookWithoutPhoto => 'بلا صورة';

  @override
  String get daybookWhatWasDone => 'ما الذي أُنجز؟';

  @override
  String get daybookSignedUndo => 'وُقّع كمنجز';

  @override
  String get daybookCloseProof => 'إغلاق';

  @override
  String get daybookSave => 'حفظ';

  @override
  String daybookSentBackText(String reason, String note) {
    return '$reason. $note';
  }

  @override
  String get daybookCouldNotCheck => 'تعذّر التحقق';

  @override
  String get daybookCouldNotSendBack => 'تعذّر الإرجاع';

  @override
  String get daybookCouldNotCancel => 'تعذّر الإلغاء';

  @override
  String get daybookCouldNotGiveTo => 'تعذّر تكليف شخص آخر';

  @override
  String get daybookCouldNotUpdate => 'تعذّرت إضافة التحديث';

  @override
  String daybookRefusedBecause(String action, String reason) {
    return '$action: $reason';
  }

  @override
  String daybookRefusedPlain(String action) {
    return '$action.';
  }

  @override
  String get daybookWhyCancelled => 'تم إلغاء هذا البند';

  @override
  String get daybookWhyChecked => 'تم التحقق منه من قبل';

  @override
  String get daybookWhyChanged => 'تغيّر في هذه الأثناء';

  @override
  String get daybookWhyRemoved => 'تمت إزالته';

  @override
  String get daybookWhyNotAllowed => 'تصريحك لا يسمح بذلك';

  @override
  String get daybookSwitchItem => 'إثبات بند عمل آخر';

  @override
  String get daybookDiscardProofTitle => 'حذف هذا الإثبات؟';

  @override
  String get daybookDiscardProofBody =>
      'الصور موجودة على هذا الهاتف فقط. إذا حذفتها لن تعود.';

  @override
  String get daybookDiscardProofKeep => 'إبقاء';

  @override
  String get daybookDiscardProofDelete => 'حذف';

  @override
  String get spacesMenu => 'قائمة المساحة';

  @override
  String get spacesInfoYou => 'أنت';

  @override
  String get spacesInfoInvite => 'الدعوة';

  @override
  String get spacesInfoSpace => 'المساحة';

  @override
  String get spacesYourPass => 'تصريحك';

  @override
  String get spacesNotifyChoiceAll => 'كل شيء';

  @override
  String get spacesNotifyChoiceNeedsYou => 'بانتظارك';

  @override
  String get spacesInviteChoiceAdmins => 'المدراء';

  @override
  String get spacesInviteChoiceLeads => 'المسؤولون';

  @override
  String get spacesInviteChoiceEveryone => 'الجميع';

  @override
  String get spacesCopy => 'نسخ';

  @override
  String get spacesCodeCopied => 'تم نسخ رمز الدعوة';

  @override
  String get spacesAdminRow => 'مدير المساحة';

  @override
  String get spacesOnSiteSince => 'في الموقع منذ';

  @override
  String get spacesOnSiteNotSet => 'غير محدد';

  @override
  String get spacesOnSiteChange => 'اختيار يوم آخر';

  @override
  String get spacesOnSiteRemove => 'إزالة اليوم';

  @override
  String get spacesOnSiteNote =>
      'تعدّ صفحة العمل «اليوم 1 في الموقع» من هذا اليوم.';

  @override
  String get spacesEditNameAbout => 'الاسم والنبذة';

  @override
  String get needsTitle => 'بانتظارك';

  @override
  String get needsRowCheck => 'للتحقق';

  @override
  String get needsRowForYou => 'لك';

  @override
  String get needsRowSentBack => 'أُرجع إليك';

  @override
  String get needsRowOwnerLeft => 'يحتاج مكلّفًا';

  @override
  String get needsRowJoin => 'طلب انضمام';

  @override
  String get needsNone => 'لا شيء بانتظارك الآن.';

  @override
  String get profileProofOfWork => 'إثبات العمل';

  @override
  String get profileProjectsConfirmed => 'مشاريع أكّدها الزملاء';

  @override
  String get proofStampConfirmed => 'مؤكد';

  @override
  String get proofStampWaiting => 'بالانتظار';

  @override
  String get proofChooseShown => 'اختر ما يظهر';

  @override
  String get postWritingAuthor => 'أنت · للجميع';

  @override
  String postLangAuto(String lang) {
    String _temp0 = intl.Intl.selectLogic(lang, {
      'ar': 'العربية',
      'other': 'الإنجليزية',
    });
    return 'تلقائي: $_temp0';
  }

  @override
  String get postWritingHint => 'ماذا حدث في العمل اليوم؟';

  @override
  String get postWritingProject => 'المشروع';

  @override
  String postWritingLang(String lang) {
    String _temp0 = intl.Intl.selectLogic(lang, {
      'ar': 'بالعربية',
      'other': 'بالإنجليزية',
    });
    return 'مكتوب $_temp0';
  }

  @override
  String get postWritingPhotosMax => 'حتى 4 صور.';

  @override
  String get homeNothingNeedsYou => 'لا شيء بانتظارك';

  @override
  String get homeYourSpaces => 'مساحاتك';

  @override
  String get createPostToEveryone => 'منشور للجميع';

  @override
  String get createPostToEveryoneLine => 'في الأخبار، يراه الجميع';

  @override
  String get createWorkItem => 'بند عمل في مساحة';

  @override
  String get createWorkItemLine => 'يراه أعضاء المساحة فقط';

  @override
  String get createPickSpace => 'في أي مساحة؟';

  @override
  String get createLastSpace => 'آخر مساحة فُتحت';

  @override
  String get createNoWorkSpaces =>
      'لا توجد بعد مساحة يمكن كتابة بنود العمل فيها. يمكن الانضمام إلى مساحة برمز دعوة، أو إنشاء مساحة جديدة.';

  @override
  String get daybookShowEarlier => 'عرض الأقدم';

  @override
  String daybookHistoryLead(String lead) {
    return '$lead:';
  }

  @override
  String daybookCardRef(String ref) {
    return '· $ref';
  }

  @override
  String get daybookRemoved => 'تمت إزالة هذا';

  @override
  String daybookQuote(String ref, String title) {
    return '$ref · $title';
  }

  @override
  String get daybookSendUpdate => 'أرسل التحديث';

  @override
  String daybookTrace(String what, String title) {
    return '$what · $title';
  }

  @override
  String get daybookTodayDivider => 'اليوم';

  @override
  String daybookLineSigned(String name) {
    return '$name · توقيع كمنجز';
  }

  @override
  String get daybookLineYouSigned => 'أنت · توقيع كمنجز';

  @override
  String daybookLineChecked(String name) {
    return '$name · تحقّق';
  }

  @override
  String get daybookLineYouChecked => 'أنت · تحقّق';

  @override
  String daybookLineSentBack(String name) {
    return '$name · إرجاع';
  }

  @override
  String get daybookLineYouSentBack => 'أنت · إرجاع';

  @override
  String daybookLineUpdate(String name) {
    return '$name · تحديث';
  }

  @override
  String get daybookLineYouUpdate => 'أنت · تحديث';

  @override
  String get daybookLineYouComment => 'أنت · تحديث';

  @override
  String daybookLineComment(String name) {
    return '$name · تحديث';
  }

  @override
  String daybookLineGave(String name, String to, String from) {
    return '$name · إسناد إلى $to بدلًا من $from';
  }

  @override
  String daybookLineYouGave(String to, String from) {
    return 'أنت · إسناد إلى $to بدلًا من $from';
  }

  @override
  String daybookLineEdited(String name) {
    return '$name · تعديل';
  }

  @override
  String get daybookLineYouEdited => 'أنت · تعديل';

  @override
  String daybookLineMovedDue(String name, String from, String to) {
    return '$name · تعديل الموعد: من $from إلى $to';
  }

  @override
  String daybookLineYouMovedDue(String from, String to) {
    return 'أنت · تعديل الموعد: من $from إلى $to';
  }

  @override
  String daybookLineRemovedDue(String name) {
    return '$name · إزالة الموعد';
  }

  @override
  String get daybookLineYouRemovedDue => 'أنت · إزالة الموعد';

  @override
  String daybookLineCancelled(String name) {
    return '$name · إلغاء';
  }

  @override
  String get daybookLineYouCancelled => 'أنت · إلغاء';

  @override
  String daybookLinePosted(String name) {
    return '$name · نشر';
  }

  @override
  String get daybookLineYouPosted => 'أنت · نشر';

  @override
  String get daybookKindChecklistWord => '· قائمة تحقق';

  @override
  String get daybookKindActivityWord => '· مُجدول';

  @override
  String get daybookKindFileWord => '· ملف';

  @override
  String get daybookToEveryone => '· للجميع';

  @override
  String daybookToTeam(String team) {
    return '· لـ $team';
  }

  @override
  String daybookTicked(int ticked, int total) {
    return 'تم تأشير $ticked من $total';
  }

  @override
  String get daybookGotIt => 'فهمت';

  @override
  String get daybookReceived => 'استلمت';

  @override
  String get daybookOnMyWay => 'في الطريق';

  @override
  String get daybookAddToCalendar => 'أضف إلى تقويمي';

  @override
  String get daybookInMyCalendar => 'في تقويمي';

  @override
  String daybookReceivedBy(String names) {
    return 'الاستلام: $names';
  }

  @override
  String daybookFileTitle(String title, String revision) {
    return '$title · $revision';
  }

  @override
  String get daybookStampNewVersion => 'نسخة جديدة';

  @override
  String daybookStampReplaces(String revision) {
    return 'يحل محل $revision';
  }

  @override
  String daybookPinnedUntil(String day) {
    return 'حتى $day';
  }

  @override
  String daybookChecklistBy(String date) {
    return 'قبل $date';
  }

  @override
  String daybookChecklistByAt(String date, String time) {
    return 'قبل الساعة $time يوم $date';
  }

  @override
  String daybookNamesAnd(String list, String last) {
    return '$list و$last';
  }

  @override
  String get daybookNamesComma => '، ';

  @override
  String daybookNamesOthers(String list) {
    return '$list وآخرون';
  }

  @override
  String daybookForYouAnd(String names) {
    return 'لك ولـ $names';
  }

  @override
  String get daybookTomorrowStart => 'غدًا';

  @override
  String daybookActivityWhen(String day, String time) {
    return '$day، $time';
  }

  @override
  String daybookStartsIn(String time, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      many: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتين',
      one: 'دقيقة',
      zero: 'أقل من دقيقة',
    );
    return '$time · يبدأ بعد $_temp0';
  }

  @override
  String daybookOnNow(String time) {
    return '$time · جارٍ الآن';
  }

  @override
  String get daybookPdf => 'PDF';

  @override
  String get daybookPhoto => 'صورة';

  @override
  String timeRange(String from, String to) {
    return 'من $from إلى $to';
  }

  @override
  String daybookLineTicked(String name) {
    return '$name · تأشير';
  }

  @override
  String get daybookLineYouTicked => 'أنت · تأشير';

  @override
  String daybookLineUnticked(String name) {
    return '$name · إلغاء التأشير';
  }

  @override
  String get daybookLineYouUnticked => 'أنت · إلغاء التأشير';

  @override
  String daybookLineGotIt(String name) {
    return '$name · فهمت';
  }

  @override
  String get daybookLineYouGotIt => 'أنت · فهمت';

  @override
  String daybookLineReceived(String name) {
    return '$name · استلام';
  }

  @override
  String get daybookLineYouReceived => 'أنت · استلام';

  @override
  String daybookLineOnMyWay(String name) {
    return '$name · في الطريق';
  }

  @override
  String get daybookLineYouOnMyWay => 'أنت · في الطريق';

  @override
  String daybookLineInMyCalendar(String name) {
    return '$name · في التقويم';
  }

  @override
  String get daybookLineYouInMyCalendar => 'أنت · في التقويم';

  @override
  String daybookTraceTicked(String name) {
    return '$name · تأشير';
  }

  @override
  String get daybookTraceYouTicked => 'أنت · تأشير';

  @override
  String daybookTraceUnticked(String name) {
    return '$name · إلغاء التأشير';
  }

  @override
  String get daybookTraceYouUnticked => 'أنت · إلغاء التأشير';

  @override
  String get daybookCouldNotTick => 'تعذّر التأشير';

  @override
  String get daybookCouldNotAck => 'تعذّر الحفظ';

  @override
  String get daybookKindChecklist => 'قائمة تحقق';

  @override
  String get daybookKindAnnouncement => 'إعلان';

  @override
  String get daybookKindActivity => 'نشاط مجدول';

  @override
  String get daybookBodyNote => 'أضف ملاحظة';

  @override
  String get daybookBodyAnnouncement => 'اكتب الإعلان';

  @override
  String get daybookBodyActivity => 'عمّ يدور';

  @override
  String get daybookPointHint => 'أضف نقطة';

  @override
  String get daybookPeople => 'لمن';

  @override
  String get daybookPeopleSearch => 'لمن…';

  @override
  String get daybookPinUntil => 'تثبيت حتى';

  @override
  String daybookPinnedProperty(String day) {
    return 'مثبّت حتى $day';
  }

  @override
  String get daybookActivityTime => 'الوقت';

  @override
  String get daybookStartsAtHelp => 'يبدأ الساعة';

  @override
  String get daybookEndsAtHelp => 'ينتهي الساعة';

  @override
  String get daybookNoEndTime => 'بدون وقت انتهاء';

  @override
  String get daybookStartLater => 'اختر وقتًا لم يأتِ بعد';

  @override
  String get daybookAttachTitle => 'أضف إلى هذا المنشور';

  @override
  String get daybookAttachPhotos => 'صورة من المعرض';

  @override
  String daybookAttachPhotosNote(int n) {
    return 'حتى $n صور';
  }

  @override
  String get daybookFileChooseTitle => 'اختر ملفًا';

  @override
  String get daybookFileFromPhone => 'من الهاتف';

  @override
  String get daybookFileFromPhoneNote => 'يُضاف إلى المكتبة أيضًا';

  @override
  String get daybookFileInLibrary => 'في المكتبة';

  @override
  String get daybookReplacesTitle => 'هل هو نسخة جديدة من ملف؟';

  @override
  String daybookReplacesOption(String name) {
    return 'يحل محل $name';
  }

  @override
  String get daybookReplacesDone => 'تم';

  @override
  String get daybookFilesFull => 'حتى 10 صور وملفات في المنشور';

  @override
  String get daybookRemovePoint => 'إزالة النقطة';

  @override
  String get daybookRemoveFile => 'إزالة الملف';

  @override
  String get daybookCancelPost => 'إلغاء المنشور';

  @override
  String get previewModelViewVersions =>
      'الإصدارات الجديدة تأتي من BuildVibes 360';

  @override
  String get daybookPeopleDone => 'تم';

  @override
  String daybookDayTime(String day, String time) {
    return '$day، $time';
  }

  @override
  String get daybookKindDocument => 'ملف';

  @override
  String get daybookUnpin => 'إلغاء التثبيت';

  @override
  String get daybookKindNote => 'ملاحظة';

  @override
  String get daybookKindNoteWord => '· ملاحظة';

  @override
  String get daybookForChoose => 'لـ: اختر';

  @override
  String get daybookComingChoose => 'من سيحضر: اختر';

  @override
  String get daybookChooseWho => 'اختر لمن';

  @override
  String get daybookPostAsNote => 'للعلم فقط؟ انشرها كملاحظة';

  @override
  String daybookToAudience(String audience) {
    return 'إلى: $audience';
  }

  @override
  String get daybookEveryone => 'الجميع';

  @override
  String daybookMastheadToday(String date) {
    return '· $date';
  }

  @override
  String get daybookNothingYetToday => 'لا شيء بعد اليوم';

  @override
  String get daybookSendBackNewDate => 'موعد جديد';

  @override
  String get daybookSendBackToday => 'اليوم';

  @override
  String get daybookSendBackTomorrow => 'غدًا';

  @override
  String get daybookSendBackPickDate => 'اختر تاريخًا';

  @override
  String daybookLineNewDate(String date) {
    return 'موعد جديد $date';
  }

  @override
  String get daybookLineNoNewDate => 'بلا موعد جديد';

  @override
  String needsDoneWaiting(String time) {
    return 'منجز $time · بانتظار تحققك';
  }

  @override
  String get messagesTitle => 'الرسائل';

  @override
  String get messagesRequest => 'طلب مراسلة';

  @override
  String get messagesRequests => 'طلبات المراسلة';

  @override
  String get messagesToday => 'اليوم';

  @override
  String get messagesEarlier => 'سابقًا';

  @override
  String messagesYou(String text) {
    return 'أنت: $text';
  }

  @override
  String messagesVoice(String length) {
    return 'رسالة صوتية · $length';
  }

  @override
  String get messagesEmpty => 'لا رسائل بعد. ابدأ محادثة بزر +.';

  @override
  String get messagesNew => 'رسالة جديدة';

  @override
  String get messagesSearch => 'ابحث بالاسم';

  @override
  String get messagesUnread => 'غير مقروءة';

  @override
  String dmBothIn(String space) {
    return 'معًا في $space';
  }

  @override
  String get dmNotInSpaces => 'ليس في مساحاتك';

  @override
  String get dmDecline => 'رفض';

  @override
  String dmDeclined(String name) {
    return 'تم الرفض. لن يُبلَّغ $name.';
  }

  @override
  String get dmTapToShow => 'اضغط للعرض';

  @override
  String get dmMute => 'كتم';

  @override
  String get dmUnmute => 'إلغاء الكتم';

  @override
  String dmReportPerson(String name) {
    return 'الإبلاغ عن $name';
  }

  @override
  String dmPaused(String day) {
    return 'كثير ممن راسلتهم لم يردّوا. يمكنك بدء محادثات جديدة مرة أخرى يوم $day.';
  }

  @override
  String get dmWarning => 'كثير ممن راسلتهم لم يردّوا بعد.';

  @override
  String get dmPhoto => 'صورة';

  @override
  String get profileMessage => 'مراسلة';

  @override
  String get chatNewChat => 'محادثة جديدة';

  @override
  String get chatNewGroup => 'فريق جديد في هذه المساحة';

  @override
  String get chatNewGroupNote =>
      'اختر اسمًا وأعضاء. يستطيع مدير المساحة فعل ذلك.';

  @override
  String get chatOnePerson => 'راسل شخصًا واحدًا';

  @override
  String chatOnePersonNote(String space) {
    return 'تُفتح في الرسائل، مع علامة «من $space»';
  }

  @override
  String get chatWorkNote =>
      'يُكلَّف العمل من تبويب «العمل». المحادثة للتواصل.';

  @override
  String chatThreadsDmNote(String space) {
    return 'الرسائل إلى شخص واحد تُفتح في الرسائل، مع علامة «من $space».';
  }

  @override
  String get photoPreparing => 'جارٍ التجهيز…';

  @override
  String get photoCannotOpen => 'تعذّر فتح هذه الصورة. اختر صورة أخرى.';

  @override
  String daybookDocketTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n بند عمل لك',
      few: '$n بنود عمل لك',
      two: 'بندا عمل لك',
      one: 'بند عمل واحد لك',
    );
    return '$_temp0';
  }

  @override
  String daybookDocketFrom(String day) {
    return 'منذ $day';
  }

  @override
  String daybookDocketRest(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '، و$n بنود أخرى',
      one: '، وبند آخر',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String daybookQuoteFrom(String name, String when) {
    return 'من $name · $when';
  }

  @override
  String daybookQuoteFromName(String name) {
    return 'من $name';
  }

  @override
  String get dmPutInSpace => 'ضعها في مساحة';

  @override
  String get dmPutInSpaceNone => 'لست بعد في مساحة يمكنك إضافة عمل فيها.';

  @override
  String get chatTurnIntoWorkItem => 'حوّلها إلى بند عمل';

  @override
  String get peopleWantsToJoin => 'يطلب الانضمام';

  @override
  String get peopleLetIn => 'اقبله';

  @override
  String get peopleChoosePass => 'اختر التصريح';

  @override
  String peopleLetInAs(String pass) {
    return 'اقبله ك$pass';
  }

  @override
  String get peopleLeads => 'المسؤولون';

  @override
  String get peopleCrew => 'فريق التنفيذ';

  @override
  String get peopleViewers => 'المُطّلعون';

  @override
  String get peopleAdmin => 'مدير المساحة';

  @override
  String get peopleNewTeam => '+ فريق جديد';

  @override
  String peopleInviteCode(String code) {
    return 'ادعُ بالرمز $code';
  }

  @override
  String peopleLetInDone(String name, String pass) {
    return '$name في المساحة الآن، بتصريح $pass.';
  }

  @override
  String libraryOlderVersions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نسخة أقدم',
      few: '$count نسخ أقدم',
      two: 'نسختان أقدم',
      one: 'نسخة أقدم واحدة',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddFile => 'أضف ملفًا';

  @override
  String get libraryVersions => 'النسخ';

  @override
  String libraryInUse(String rev) {
    return '$rev · الحالية';
  }

  @override
  String get libraryVersion => 'نسخة';

  @override
  String get libraryOpen => 'افتح';

  @override
  String get libraryAddVersion => 'أضف نسخة جديدة';

  @override
  String get libraryFileMenu => 'المزيد لهذا الملف';

  @override
  String get libraryOpenFull => 'افتح بملء الشاشة';

  @override
  String get searchMenu => 'بحث';

  @override
  String get searchHint => 'ابحث في هذه المساحة';

  @override
  String get searchClear => 'امسح';

  @override
  String get searchWorkItems => 'بنود العمل';

  @override
  String get searchFiles => 'الملفات';

  @override
  String get searchChat => 'المحادثة';

  @override
  String searchNothing(String query) {
    return 'لا شيء عن «$query»';
  }

  @override
  String searchMessage(String text) {
    return '«$text»';
  }

  @override
  String get pageOpen => 'افتح الصفحة';

  @override
  String get pageEdit => 'تعديل الصفحة';

  @override
  String get pageDone => 'تم';

  @override
  String get pageClose => 'أغلق الصفحة';

  @override
  String get pageUnder => 'بنود العمل تحت هذا البند';

  @override
  String pageUnderChecked(int checked, int total) {
    return '$checked من $total تم التحقق منها';
  }

  @override
  String get pageAddBlock => 'اكتب / لإضافة جزء';

  @override
  String get pageMenuTitle => 'أضف';

  @override
  String get pageText => 'نص';

  @override
  String get pageHeading => 'عنوان';

  @override
  String get pageChecklist => 'قائمة تحقق';

  @override
  String get pageToggle => 'قسم قابل للطي';

  @override
  String get pageTable => 'جدول';

  @override
  String get pagePhoto => 'صورة';

  @override
  String get pageFile => 'ملف';

  @override
  String get pageItemUnder => 'بند عمل تحت هذا البند';

  @override
  String get pagePoint => 'نقطة في قائمة التحقق';

  @override
  String get pageTurnInto => 'حوّلها إلى';

  @override
  String get pageTickedStays => 'النقطة المؤشَّر عليها تبقى كما هي.';

  @override
  String get pageDelete => 'احذف';

  @override
  String get pageDeleted => 'حُذف الجزء.';

  @override
  String get pageMove => 'انقل';

  @override
  String get pageBlockMenu => 'المزيد لهذا الجزء';

  @override
  String get pageAddRow => 'أضف صفًا';

  @override
  String get pageAddColumn => 'أضف عمودًا';

  @override
  String get pageDeleteRow => 'احذف الصف';

  @override
  String get pageDeleteColumn => 'احذف العمود';

  @override
  String get pageStale => 'تغيّرت هذه الصفحة على هاتف آخر. نسختك محفوظة هنا.';

  @override
  String get pageUseMine => 'استخدم نسختي';

  @override
  String get pageUseNewer => 'استخدم الأحدث';

  @override
  String get pageFull => 'تتسع الصفحة لعشر صور وملفات على الأكثر.';

  @override
  String get pageItemTitle => 'ما المطلوب';

  @override
  String get pageTooLongForItem => 'اختصرها إلى 140 حرفًا لتصبح بند عمل.';

  @override
  String get pagePhotoCaption => 'أضف وصفًا';

  @override
  String get walkMenu => 'وضع الجولة';

  @override
  String get walkTitle => 'جولة';

  @override
  String get walkNameHint => 'سمِّ هذه الجولة';

  @override
  String get walkStart => 'التقط الصورة الأولى';

  @override
  String get walkLineHint => 'ما المطلوب هنا';

  @override
  String get walkOwner => 'من ينفّذه';

  @override
  String get walkNext => 'الصورة التالية';

  @override
  String walkPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صورة',
      few: '$count صور',
      two: 'صورتان',
      one: 'صورة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get walkFinish => 'إنهاء';

  @override
  String get walkNeedsLine => 'اكتب ما المطلوب، ثم الصورة التالية.';

  @override
  String get walkNeedsOwner => 'اختر من ينفّذه، ثم الصورة التالية.';

  @override
  String get walkFull => 'تتسع الجولة لثلاثين صورة. أنهِها ثم ابدأ أخرى.';

  @override
  String get walkDiscardTitle => 'تتخلص من هذه الجولة؟';

  @override
  String get walkDiscardBody => 'لن تُرسل صورها.';

  @override
  String get walkKeep => 'تابع الجولة';

  @override
  String get walkDiscard => 'تخلّص منها';

  @override
  String get walkRemovePhoto => 'احذف هذه الصورة';

  @override
  String walkEachItem(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صورة، كلٌّ منها بند عمل',
      few: '$count صور، كلٌّ منها بند عمل',
      two: 'صورتان، كلٌّ منهما بند عمل',
      one: 'صورة واحدة، بند عمل',
    );
    return '$_temp0';
  }

  @override
  String get walkShowAll => 'اعرض الكل';

  @override
  String get walkInProgress => 'لديك جولة لم تكتمل';

  @override
  String get walkContinue => 'متابعة الجولة';

  @override
  String get walkThrowAway => 'التخلّص منها';

  @override
  String get peopleSearchHint => 'الاسم أو الدور أو الشركة';

  @override
  String get peopleInYourSpaces => 'أشخاص في مساحاتك';

  @override
  String peopleSearchNothing(String query) {
    return 'لا أحد يطابق «$query»';
  }

  @override
  String get peopleSearchStart => 'اكتب اسمًا لتجد شخصًا.';

  @override
  String get daybookSending => 'يُرسل';

  @override
  String daybookSendingBytes(String sent, String total) {
    return 'يُرسل · $sent من $total ميغابايت';
  }

  @override
  String get peoplePassRow => 'التصريح';

  @override
  String get daybookNewFile => 'ملف جديد';

  @override
  String get daybookNewVersion => 'نسخة جديدة من ملف';

  @override
  String get daybookPickVersionTitle => 'نسخة جديدة من أي ملف؟';

  @override
  String libraryVersionNo(int version) {
    return 'V$version';
  }

  @override
  String get daybookNotNewVersion => 'ليست نسخة جديدة';

  @override
  String get daybookAttachFiles => 'ملف من الهاتف';

  @override
  String get daybookAttachLibrary => 'من المكتبة';

  @override
  String get daybookFileToEveryone =>
      'الملف يذهب إلى المساحة كلها. لإرساله إلى شخص واحد استخدم رسالة مباشرة.';

  @override
  String get daybookAttachCameraNote => 'بكاميرا الهاتف';

  @override
  String get daybookAttachLibraryNote => 'ملف موجود في هذه المساحة';

  @override
  String daybookStampNewVersionNo(String version) {
    return 'نسخة جديدة · $version';
  }

  @override
  String daybookReplacedBy(String version, String when) {
    return 'استُبدلت بـ $version · $when';
  }

  @override
  String libraryInUseNo(String version) {
    return '$version · المعتمدة';
  }

  @override
  String libraryReplacedOn(String day) {
    return 'استُبدلت $day، وتبقى في السجل';
  }

  @override
  String get pageTypeInside => 'اكتب هنا';

  @override
  String get daybookLineYouEditedPage => 'عدّلتَ الصفحة';

  @override
  String daybookLineEditedPage(String name) {
    return '$name · تعديل الصفحة';
  }

  @override
  String daybookPinnedUntilAt(String day, String time) {
    return 'حتى $day · $time';
  }

  @override
  String daybookPinnedLineUntil(String day) {
    return 'حتى $day';
  }

  @override
  String get daybookPinAddTime => '+ وقت';

  @override
  String get daybookPinRemoveTime => 'إزالة الوقت';

  @override
  String get daybookPinTimeHelp => 'مثبّت حتى أي وقت؟';

  @override
  String get daybookPinLater => 'اختر وقتًا لاحقًا';

  @override
  String get daybookKindReport => 'تقرير يومي';

  @override
  String get daybookKindReportWord => '· تقرير يومي';

  @override
  String get dailyReportMenu => 'تقرير يومي';

  @override
  String get dailyReportOnSite => 'في الموقع';

  @override
  String get dailyReportDoneToday => 'أنجز اليوم';

  @override
  String get dailyReportProblems => 'المشكلات';

  @override
  String get dailyReportOnSiteHint => 'من كان حاضرًا، وماذا وصل';

  @override
  String get dailyReportProblemsHint => 'ما الذي أخّر العمل';

  @override
  String get dailyReportNothingChecked => 'لم يُتحقق من شيء اليوم بعد';

  @override
  String get dailyReportTakeOut => 'أخرجه من التقرير';

  @override
  String get dailyReportNotes => 'ملاحظات اليوم';

  @override
  String get dailyReportAddNote => 'أضف';

  @override
  String get dailyReportSharePdf => 'شارك كملف PDF';

  @override
  String get dailyReportMakingPdf => 'جارٍ تجهيز ملف PDF…';

  @override
  String get dailyReportPdfFailed => 'تعذّر تجهيز ملف PDF. حاول مرة أخرى.';

  @override
  String dailyReportPdfBy(String name, String time) {
    return 'بواسطة $name · $time';
  }

  @override
  String dailyReportPdfChecked(String time, String name) {
    return 'تم التحقق $time بواسطة $name';
  }

  @override
  String dailyReportPdfFile(String day) {
    return 'تقرير يومي $day';
  }

  @override
  String get dailyReportTodayOnly =>
      'التقرير اليومي لليوم فقط. أُزيلت مسودة الأمس.';

  @override
  String get templateMenu => 'قالب';

  @override
  String get templatePickTitle => 'ابدأ من قالب';

  @override
  String get templateSpaceOwn => 'قوالب هذه المساحة';

  @override
  String templateFrom(String name) {
    return 'من: $name';
  }

  @override
  String get templateDrop => 'بدون قالب';

  @override
  String get templateSave => 'احفظ كقالب';

  @override
  String get templateNameTitle => 'سمِّ هذا القالب';

  @override
  String get templateNameHint => 'اسم القالب';

  @override
  String get templateSaved => 'حُفظ كقالب';

  @override
  String templateFull(int count) {
    return 'لهذه المساحة $count قالبًا، وهو الحد. احذف واحدًا من معلومات المساحة › القوالب لتحفظ غيره.';
  }

  @override
  String get templateOpenList => 'افتح القوالب';

  @override
  String get templatesTitle => 'القوالب';

  @override
  String get templatesNoneOwn =>
      'لا قوالب محفوظة في هذه المساحة بعد. يحفظ المسؤول قالبًا من قائمة أي منشور.';

  @override
  String get templateDelete => 'احذف القالب';

  @override
  String templateDeleteAsk(String name) {
    return 'حذف «$name»؟ تبقى المنشورات التي صُنعت منه كما هي.';
  }

  @override
  String get templateDeleted => 'حُذف القالب';

  @override
  String get templateBuiltinDailyReport => 'تقرير يومي';

  @override
  String get dailyReportDraftFirst =>
      'انشر البطاقة التي تكتبها أو ضعها جانبًا أولًا.';

  @override
  String get notebookTitle => 'دفتري';

  @override
  String get notebookOnlyYou => 'أنت فقط';

  @override
  String get notebookOnlyYouBody =>
      'لا يرى دفترك أحد غيرك. لا يذهب شيء منه إلى مساحة حتى تضعه فيها.';

  @override
  String get notebookNote => 'ملاحظة';

  @override
  String get notebookTodo => 'مهمة';

  @override
  String get notebookVoice => 'ملاحظة صوتية';

  @override
  String notebookSlipHead(String kind, String time) {
    return '$kind · $time';
  }

  @override
  String get notebookEmptyTitle => 'مكان عملك الخاص';

  @override
  String get notebookEmptyBody =>
      'احتفظ بملاحظاتك وقوائم التحقق والمهام لعملك. لا يراها أحد غيرك.';

  @override
  String get notebookPinTop => 'ثبّت في الأعلى';

  @override
  String get notebookDeleteTitle => 'حذف هذه الملاحظة؟';

  @override
  String get notebookDeleteBody =>
      'ستُحذف من دفترك. ما وضعته في مساحة يبقى فيها.';

  @override
  String get notebookPut => 'وُضعت في مساحة';

  @override
  String get notebookSaved => 'حُفظت في دفترك';

  @override
  String get notebookSaveMessage => 'احفظ في دفتري';

  @override
  String get notebookPutNone => 'لست بعد في مساحة يمكنك إضافة عمل فيها.';

  @override
  String get notebookTooShort => 'اضغط مدة أطول للتسجيل';

  @override
  String get calendarTitle => 'تقويمي';

  @override
  String get calendarSubtitle => 'مساحاتك ودفترك معاً';

  @override
  String get calendarAllDay => 'طوال اليوم';

  @override
  String get calendarDueForYou => 'مستحق عليك';

  @override
  String get calendarDueToday => 'مستحق اليوم';

  @override
  String get calendarDue => 'مستحق';

  @override
  String get calendarToCheck => 'منجز، بانتظار التحقق';

  @override
  String get calendarScheduled => 'موعد';

  @override
  String get calendarEmpty => 'لا شيء مخطط هذا الأسبوع';

  @override
  String get calendarEmptyBody =>
      'تظهر هنا بنود العمل وقوائم التحقق والأنشطة من مساحاتك، ومهامك.';

  @override
  String get calendarWeekBefore => 'الأسبوع السابق';

  @override
  String get calendarWeekAfter => 'الأسبوع التالي';

  @override
  String get notebookCouldntLoad => 'تعذّر تحميل دفترك';

  @override
  String get calendarCouldntLoad => 'تعذّر تحميل تقويمك';

  @override
  String get meetingTurn => 'حوّل الأسطر إلى بنود عمل';

  @override
  String meetingPost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'انشر $count بند عمل',
      few: 'انشر $count بنود عمل',
      two: 'انشر بندَي عمل',
      one: 'انشر بند عمل واحد',
      zero: 'انشر بنود العمل',
    );
    return '$_temp0';
  }

  @override
  String meetingPosted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نُشر $count بند عمل',
      few: 'نُشرت $count بنود عمل',
      two: 'نُشر بندا عمل',
      one: 'نُشر بند عمل واحد',
    );
    return '$_temp0';
  }

  @override
  String get meetingNoSignal => 'لا توجد إشارة. حاول مرة أخرى.';

  @override
  String get meetingChangeOwner => 'غيّر من ينفّذه';

  @override
  String get weekReportTitle => 'تقرير الأسبوع';

  @override
  String get weekReportShare => 'شارك في المحادثة';

  @override
  String get weekReportShareWhere => 'شارك في أي محادثة؟';

  @override
  String weekReportShared(String thread) {
    return 'شوركت في $thread';
  }

  @override
  String weekReportRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get weekNeedsDecision => 'بانتظار قرار';

  @override
  String get weekChecked => 'تم التحقق هذا الأسبوع';

  @override
  String get weekTargets => 'الأهداف';

  @override
  String get weekComingUp => 'القادم';

  @override
  String weekSignedDone(String when) {
    return 'وقّع كمنجز $when';
  }

  @override
  String get weekFoot => 'من يومية الفريق. يرى كل شخص ما يحق له فقط.';

  @override
  String get weekEmpty => 'لا شيء في تقرير هذا الأسبوع.';

  @override
  String get weekCouldntLoad => 'تعذّر تحميل تقرير الأسبوع';

  @override
  String weekReportCard(String range) {
    return 'تقرير الأسبوع · $range';
  }

  @override
  String activityItemEdited(String name, String title) {
    return 'تعديل من $name على $title';
  }

  @override
  String activityItemCancelled(String name, String title) {
    return 'إلغاء من $name: $title';
  }

  @override
  String activityAnnouncement(String name, String title) {
    return 'إعلان من $name: $title';
  }

  @override
  String activityChecklist(String name, String title) {
    return 'قائمة تحقق لك من $name: $title';
  }

  @override
  String activityInvited(String name, String title) {
    return 'دعوة من $name إلى نشاط مجدول: $title';
  }

  @override
  String activityFileVersion(String name, String title) {
    return 'نسخة جديدة من $name: $title';
  }

  @override
  String get pushNotYet =>
      'لا يصل الإشعار إلى هذا الهاتف بعد. أعد تشغيل الهاتف ثم افتح BuildVibes.';

  @override
  String get dmViewProfile => 'عرض الملف الشخصي';

  @override
  String get dmStartLine => 'بداية محادثتكما';

  @override
  String get notebookRemindMe => 'ذكّرني';

  @override
  String notebookReminderLine(String when) {
    return 'تذكير · $when';
  }

  @override
  String notebookReminderWhen(String day, String time) {
    return '$day $time';
  }

  @override
  String get notebookRemindPast => 'اختر وقتًا لم يأتِ بعد.';

  @override
  String get notebookExactTitle => 'تذكيرات في موعدها';

  @override
  String get notebookExactBody =>
      'لتصلك التذكيرات في موعدها بالدقيقة، اسمح بالمنبّهات الدقيقة لـ BuildVibes.';

  @override
  String get notebookExactOpen => 'فتح الإعدادات';

  @override
  String get notebookExactNotNow => 'ليس الآن';

  @override
  String get notebookNow => 'الآن';

  @override
  String get notebookDraftKept => 'محفوظة كما تركتها. اضغط لتكمل الكتابة.';

  @override
  String get notebookRemoveReminder => 'إزالة التذكير';

  @override
  String get notebookDraftFirst => 'أكمل المسودة أو امسحها أولًا.';

  @override
  String get reminderTitle => 'تذكير';

  @override
  String get reminderChannel => 'التذكيرات';

  @override
  String get reminderChannelAbout => 'التذكيرات التي تضبطها في دفتري.';

  @override
  String get noSignalStrip => 'لا توجد إشارة. كل ما تنشره ينتظر ويُرسل وحده.';

  @override
  String get pageNoSignal =>
      'لا توجد إشارة. تبقى تعديلاتك هنا. اضغط تم مرة أخرى عند عودة الإشارة.';

  @override
  String get pageLeaveTitle => 'المغادرة دون حفظ؟';

  @override
  String get pageLeaveBody => 'تعديلاتك على هذه الصفحة لم تُحفظ بعد.';

  @override
  String get pageLeaveStay => 'تابع التعديل';

  @override
  String get pageLeaveGo => 'غادر';

  @override
  String dmBannerTitle(String name) {
    return 'رسالة من $name';
  }

  @override
  String get dmBannerHidden => 'رسالة جديدة';

  @override
  String dmBannerHiddenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة جديدة',
      many: '$count رسالة جديدة',
      few: '$count رسائل جديدة',
      two: 'رسالتان جديدتان',
      one: 'رسالة جديدة',
    );
    return '$_temp0';
  }

  @override
  String get spacesTeamMembersTitle => 'الأعضاء';

  @override
  String needsChecklist(String name, String title) {
    return 'قائمة تحقق لك من $name: $title';
  }

  @override
  String needsChecklistSelf(String title) {
    return 'قائمة تحقق لك: $title';
  }

  @override
  String get needsRowChecklist => 'للتأشير';

  @override
  String get muteForHowLong => 'لأي مدة؟';

  @override
  String get muteFor8Hours => '8 ساعات';

  @override
  String get muteFor1Week => 'أسبوع واحد';

  @override
  String get muteForAlways => 'دائمًا';

  @override
  String get muteMute => 'كتم';

  @override
  String get muteUnmute => 'إلغاء الكتم';

  @override
  String get muteMutedLabel => 'الإشعارات مكتومة';

  @override
  String daybookFacesMore(int count) {
    return '+$count';
  }

  @override
  String get notebookCategories => 'الأنواع';

  @override
  String get notebookOrTypeSlash => 'أو اكتب /';

  @override
  String get notebookSubheading => 'عنوان فرعي';

  @override
  String get notebookTodoList => 'قائمة مهام';

  @override
  String get notebookBullets => 'قائمة نقطية';

  @override
  String get notebookNumbers => 'قائمة مرقّمة';

  @override
  String get notebookCallout => 'ملاحظة بارزة';

  @override
  String get notebookQuote => 'اقتباس';

  @override
  String get notebookDivider => 'فاصل';

  @override
  String get notebookTodoHint => 'مهمة';

  @override
  String get notebookListHint => 'قائمة';

  @override
  String get notebookCalloutHint => 'شيء يجب أن يبرز';

  @override
  String get notebookQuoteHint => 'اقتباس';

  @override
  String get notebookHoldVoice => 'اضغط مطولًا على «صوت» في الشريط للتسجيل.';

  @override
  String get notebookVoiceTool => 'صوت';

  @override
  String get notebookLocation => 'المكان';

  @override
  String get notebookImage => 'صورة';

  @override
  String get notebookFile => 'ملف';

  @override
  String get notebookDate => 'التاريخ';

  @override
  String get notebookWhereHint => 'أين';

  @override
  String get notebookAddGps => 'أضف إحداثيات GPS';

  @override
  String get notebookGpsAdded => 'أُضيفت إحداثيات GPS';

  @override
  String notebookGpsLine(String lat, String lng, String metres) {
    return '$lat، $lng · ±$metres م';
  }

  @override
  String get notebookGpsFinding => 'جارٍ تحديد مكانك…';

  @override
  String get notebookGpsDenied =>
      'اسمح لـ BuildVibes بتحديد المكان من إعدادات هاتفك لإضافة إحداثياتك.';

  @override
  String get notebookGpsOff => 'شغّل تحديد المكان في هاتفك لإضافة إحداثياتك.';

  @override
  String get notebookGpsFailed =>
      'تعذّر تحديد مكانك. حاول مجددًا في مكان مفتوح.';

  @override
  String get notebookLocationHelp =>
      'اكتب المكان، أو أضف GPS الهاتف، أو كليهما.';

  @override
  String notebookGpsChip(String metres) {
    return 'GPS ±$metres م';
  }

  @override
  String get notebookRemoveLocation => 'إزالة المكان';

  @override
  String get notebookRemoveGps => 'إزالة إحداثيات GPS';

  @override
  String get notebookRemoveFile => 'إزالة الملف';

  @override
  String get notebookRemoveDate => 'إزالة التاريخ';

  @override
  String get notebookFilesFull => 'تتسع الملاحظة لـ 10 ملفات كحد أقصى.';

  @override
  String get notebookPhotosFull => 'تتسع الملاحظة لـ 10 صور كحد أقصى.';

  @override
  String notebookPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صورة',
      few: '$count صور',
      two: 'صورتان',
      one: 'صورة واحدة',
    );
    return '$_temp0';
  }

  @override
  String notebookFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String get notebookIncludeGps => 'أرفق إحداثيات GPS';

  @override
  String get notebookRemindTime => 'ذكّرني الساعة…';

  @override
  String get notebookRemindMorning => 'في الصباح';

  @override
  String get notebookCouldntKeep => 'تعذّر حفظ هذه الملاحظة. عادت كمسودة.';

  @override
  String get notebookReminderGone => 'مضى وقت التذكير، فأُزيل.';

  @override
  String get notebookPhotosStay => 'بقيت الصور في دفترك: تعذّرت إضافتها.';

  @override
  String get notebookTitleHint => 'العنوان';
}
