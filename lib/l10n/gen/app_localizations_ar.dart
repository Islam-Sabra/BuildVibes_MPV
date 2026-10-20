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
  String get spacesSearchMembers => 'ابحث في الأعضاء';

  @override
  String get spacesRequestsTitle => 'طلبات الانضمام · أنت تؤكدها';

  @override
  String spacesAsked(String when) {
    return 'قُدّم الطلب $when';
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
  String get spacesAdminSection => 'مدير المساحة';

  @override
  String get spacesAdminTag => 'مدير المساحة';

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
  String get spacesGivePass => 'امنح تصريحًا لهذه المساحة';

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
  String spacesConfirmAs(String pass) {
    return 'تأكيد بتصريح $pass';
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
  String spacesTeamMembers(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n عضو',
      many: '$n عضوًا',
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
  String get workNote => 'ملاحظة';

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
      'لا ملفات بعد. تظهر هنا المخططات والصور التي تمت مشاركتها في هذه المساحة.';

  @override
  String get libraryNoMatch => 'لا نتائج.';

  @override
  String get libraryAdd => 'إضافة ملف';

  @override
  String get libraryAddTitle => 'إضافة إلى المكتبة';

  @override
  String get libraryRevisionTitle => 'إصدار جديد';

  @override
  String libraryRevisionOf(String name) {
    return 'يحل محل $name. تبقى النسخة القديمة في السجل.';
  }

  @override
  String get libraryPickFile => 'اختر ملف PDF أو صورة';

  @override
  String get libraryChangeFile => 'اختر ملفًا آخر';

  @override
  String get libraryName => 'العنوان';

  @override
  String get libraryFor => 'من يراه';

  @override
  String libraryTeamOnly(String team) {
    return 'لا يراه إلا $team ومديرو المساحة.';
  }

  @override
  String get libraryRev => 'الإصدار';

  @override
  String get libraryRevHint => 'مثلًا Rev C';

  @override
  String get libraryNoteHint => 'ما الذي تغيّر';

  @override
  String get libraryUpload => 'رفع';

  @override
  String get libraryAdded => 'أُضيف إلى المكتبة.';

  @override
  String get libraryPickFirst => 'اختر ملفًا أولًا.';

  @override
  String get libraryNameRequired => 'أضف عنوانًا.';

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
  String get previewNewRevision => 'رفع إصدار جديد';

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
  String get settingsViewProfile => 'عرض الملف';

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
  String daybookDueTodayStrip(String titles) {
    return 'مستحق اليوم: $titles';
  }

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
    return '$time $period';
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
  String get daybookKindFileWord => '· للاستلام';

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
    return 'بدل $revision';
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
  String get daybookKindFile => 'ملف';

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
  String get daybookReplacesNone => 'لا، ملف جديد';

  @override
  String daybookReplacesOption(String name) {
    return 'بدل $name';
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
  String get daybookKindDocument => 'مستند للاستلام';

  @override
  String get daybookKindDocumentNote => 'كل شخص يؤكد الاستلام';

  @override
  String get daybookUnpin => 'إلغاء التثبيت';

  @override
  String get daybookKindNote => 'ملاحظة';

  @override
  String get daybookKindNoteNote => 'للعلم، لا يلزم أي إجراء';

  @override
  String get daybookKindNoteWord => '· ملاحظة';
}
