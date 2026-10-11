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
}
