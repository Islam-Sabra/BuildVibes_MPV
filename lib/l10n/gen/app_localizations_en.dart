// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BuildVibes';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navCreate => 'Create';

  @override
  String get navActivity => 'Activity';

  @override
  String get navProfile => 'Profile';

  @override
  String get placeholderBody => 'This part of the app is being built.';

  @override
  String get settingsLanguage => 'App language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get stampSelected => 'SELECTED';

  @override
  String get signOffLabel => 'SIGN-OFF';

  @override
  String get signOffRaised => 'RAISED';

  @override
  String get signOffDone => 'DONE';

  @override
  String get signOffChecked => 'CHECKED';

  @override
  String get signOffWaiting => 'Waiting';

  @override
  String get siteTagFrom => 'FROM';

  @override
  String get siteTagOwner => 'OWNER';

  @override
  String get siteTagDue => 'DUE';

  @override
  String get passLead => 'LEAD PASS';

  @override
  String get passCrew => 'CREW PASS';

  @override
  String get passViewer => 'VIEWER PASS';

  @override
  String fieldCharacterCount(int count, int max) {
    return '$count / $max';
  }

  @override
  String get componentsGallery => 'Components';
}
