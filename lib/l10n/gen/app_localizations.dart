import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ar'),
    Locale('en'),
  ];

  /// App name. Not translated.
  ///
  /// In en, this message translates to:
  /// **'BuildVibes'**
  String get appTitle;

  /// Bottom bar tab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom bar tab.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// Bottom bar centre action.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// Bottom bar tab.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// Bottom bar tab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Temporary text on screens that are not built yet.
  ///
  /// In en, this message translates to:
  /// **'This part of the app is being built.'**
  String get placeholderBody;

  /// Row and sheet title for choosing the app language.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguage;

  /// Language name, always written in English.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Language name, always written in Arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// Sheet footer button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Sheet footer button.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// Stamp on the chosen pass card. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'SELECTED'**
  String get stampSelected;

  /// Section label above the sign-off strip.
  ///
  /// In en, this message translates to:
  /// **'SIGN-OFF'**
  String get signOffLabel;

  /// Sign-off step.
  ///
  /// In en, this message translates to:
  /// **'RAISED'**
  String get signOffRaised;

  /// Sign-off step.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get signOffDone;

  /// Sign-off step.
  ///
  /// In en, this message translates to:
  /// **'CHECKED'**
  String get signOffChecked;

  /// Sign-off step not signed yet.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get signOffWaiting;

  /// Site tag cell: who raised the item.
  ///
  /// In en, this message translates to:
  /// **'FROM'**
  String get siteTagFrom;

  /// Site tag cell: owner of the work item.
  ///
  /// In en, this message translates to:
  /// **'OWNER'**
  String get siteTagOwner;

  /// Site tag cell: due date.
  ///
  /// In en, this message translates to:
  /// **'DUE'**
  String get siteTagDue;

  /// Pass card name.
  ///
  /// In en, this message translates to:
  /// **'LEAD PASS'**
  String get passLead;

  /// Pass card name.
  ///
  /// In en, this message translates to:
  /// **'CREW PASS'**
  String get passCrew;

  /// Pass card name.
  ///
  /// In en, this message translates to:
  /// **'VIEWER PASS'**
  String get passViewer;

  /// Counter under a multi-line field.
  ///
  /// In en, this message translates to:
  /// **'{count} / {max}'**
  String fieldCharacterCount(int count, int max);

  /// Debug-only screen that shows every BV component.
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get componentsGallery;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
