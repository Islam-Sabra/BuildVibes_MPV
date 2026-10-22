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

  /// Settings row: opens Language and region (review 54 A5).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageRow;

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

  /// Sign-off step.
  ///
  /// In en, this message translates to:
  /// **'CHECKED'**
  String get signOffChecked;

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

  /// Welcome pill. Country from the market pack.
  ///
  /// In en, this message translates to:
  /// **'Starting in {country}'**
  String entryStartingIn(String country);

  /// E1 headline.
  ///
  /// In en, this message translates to:
  /// **'The construction community around you.'**
  String get entryWelcomeTitle;

  /// E1 body.
  ///
  /// In en, this message translates to:
  /// **'Meet engineers, foremen, trades and suppliers. Set up your presence when you\'re ready.'**
  String get entryWelcomeBody;

  /// E1 audience card header.
  ///
  /// In en, this message translates to:
  /// **'Built for {country} construction'**
  String entryBuiltFor(String country);

  /// E1 rotating audience card title.
  ///
  /// In en, this message translates to:
  /// **'Engineers'**
  String get entryAudience1Title;

  /// E1 rotating audience card text.
  ///
  /// In en, this message translates to:
  /// **'Share your projects. Get your work confirmed.'**
  String get entryAudience1Body;

  /// E1 rotating audience card title.
  ///
  /// In en, this message translates to:
  /// **'Site crews and trades'**
  String get entryAudience2Title;

  /// E1 rotating audience card text.
  ///
  /// In en, this message translates to:
  /// **'Show your work. Get it confirmed by your team.'**
  String get entryAudience2Body;

  /// E1 rotating audience card title.
  ///
  /// In en, this message translates to:
  /// **'Foremen and supervisors'**
  String get entryAudience3Title;

  /// E1 rotating audience card text.
  ///
  /// In en, this message translates to:
  /// **'Run the day\'s work from your phone.'**
  String get entryAudience3Body;

  /// E1 rotating audience card title.
  ///
  /// In en, this message translates to:
  /// **'Subcontractors'**
  String get entryAudience4Title;

  /// E1 rotating audience card text.
  ///
  /// In en, this message translates to:
  /// **'Get work checked and signed off on time.'**
  String get entryAudience4Body;

  /// E1 rotating audience card title.
  ///
  /// In en, this message translates to:
  /// **'Suppliers and traders'**
  String get entryAudience5Title;

  /// E1 rotating audience card text.
  ///
  /// In en, this message translates to:
  /// **'Be found by the people who build.'**
  String get entryAudience5Body;

  /// E1 rotating audience card title.
  ///
  /// In en, this message translates to:
  /// **'BIM and design'**
  String get entryAudience6Title;

  /// E1 rotating audience card text.
  ///
  /// In en, this message translates to:
  /// **'Connect the model to the work on site.'**
  String get entryAudience6Body;

  /// E1 card footer.
  ///
  /// In en, this message translates to:
  /// **'Browse first. Set up your presence when you\'re ready.'**
  String get entryBrowseFirstNote;

  /// E1 button.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get entryCreateAccount;

  /// E1 button.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get entrySignIn;

  /// E1 link: browse as a guest.
  ///
  /// In en, this message translates to:
  /// **'Skip to Home'**
  String get entrySkipToHome;

  /// E2 headline.
  ///
  /// In en, this message translates to:
  /// **'Your work, confirmed by the people who built it.'**
  String get entryJoinTitle;

  /// E2 body.
  ///
  /// In en, this message translates to:
  /// **'Join with the number you already use. It takes about a minute.'**
  String get entryJoinBody;

  /// E2 illustration: sample person.
  ///
  /// In en, this message translates to:
  /// **'Sami Al-Mansour'**
  String get entrySampleName;

  /// E2 illustration: sample role and project.
  ///
  /// In en, this message translates to:
  /// **'BIM Manager · Harbour Tower'**
  String get entrySampleRole;

  /// E2 illustration badge.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by teammates'**
  String get entrySampleBadge;

  /// E2 main button.
  ///
  /// In en, this message translates to:
  /// **'Continue with phone number'**
  String get entryContinuePhone;

  /// E2 divider above Google / Apple.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get entryOrContinueWith;

  /// Brand name.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get entryGoogle;

  /// Brand name.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get entryApple;

  /// Brand name.
  ///
  /// In en, this message translates to:
  /// **'LinkedIn'**
  String get entryLinkedIn;

  /// E2 link.
  ///
  /// In en, this message translates to:
  /// **'Use email instead'**
  String get entryUseEmail;

  /// E2 reassurance.
  ///
  /// In en, this message translates to:
  /// **'No password. We never post for you or read your contacts.'**
  String get entryNoPassword;

  /// E2 legal line.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to the Terms and Privacy Policy.'**
  String get entryTerms;

  /// E2 guest link.
  ///
  /// In en, this message translates to:
  /// **'Just looking? Browse first'**
  String get entryJustLooking;

  /// E2p title.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get phoneTitle;

  /// E2p field label.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// E2p helper.
  ///
  /// In en, this message translates to:
  /// **'We send a 6-digit code on WhatsApp. No password needed.'**
  String get phoneHelpWhatsapp;

  /// E2p helper.
  ///
  /// In en, this message translates to:
  /// **'We send a 6-digit code by SMS. No password needed.'**
  String get phoneHelpSms;

  /// E2p secondary button.
  ///
  /// In en, this message translates to:
  /// **'Send the code by SMS instead'**
  String get phoneSendSms;

  /// E2p link.
  ///
  /// In en, this message translates to:
  /// **'Use your email instead'**
  String get phoneUseEmail;

  /// Footer button.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// E2p validation.
  ///
  /// In en, this message translates to:
  /// **'Enter a {country} mobile number with {digits} digits.'**
  String phoneErrorMarket(String country, int digits);

  /// E2p validation.
  ///
  /// In en, this message translates to:
  /// **'Enter your full mobile number.'**
  String get phoneErrorOther;

  /// Dial code sheet title.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get dialCodeTitle;

  /// Dial code option.
  ///
  /// In en, this message translates to:
  /// **'Other country code'**
  String get dialCodeOther;

  /// Dial code field helper.
  ///
  /// In en, this message translates to:
  /// **'Type the code, for example +91.'**
  String get dialCodeOtherHelp;

  /// A market that is not open yet.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// Sign-up gate sheet title.
  ///
  /// In en, this message translates to:
  /// **'New accounts aren\'t open for this number yet'**
  String get notOpenTitle;

  /// Sign-up gate: market coming soon.
  ///
  /// In en, this message translates to:
  /// **'We\'re coming to {country} soon. If someone invited you to a Space, open their invite link to join now.'**
  String notOpenSoon(String country);

  /// Sign-up gate: no market for this number.
  ///
  /// In en, this message translates to:
  /// **'New accounts are open in {countries} for now. If someone invited you to a Space, open their invite link to join now.'**
  String notOpenOther(String countries);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Email entry title.
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get emailTitle;

  /// Email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Email helper.
  ///
  /// In en, this message translates to:
  /// **'We send a 6-digit code. No password needed.'**
  String get emailHelp;

  /// Email validation.
  ///
  /// In en, this message translates to:
  /// **'Check the email address.'**
  String get emailError;

  /// Email screen link.
  ///
  /// In en, this message translates to:
  /// **'Use your phone number instead'**
  String get emailUsePhone;

  /// E3 title.
  ///
  /// In en, this message translates to:
  /// **'Check WhatsApp'**
  String get codeTitleWhatsapp;

  /// E3 title.
  ///
  /// In en, this message translates to:
  /// **'Check your messages'**
  String get codeTitleSms;

  /// E3e title.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get codeTitleEmail;

  /// E3 text.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {destination} on WhatsApp. It works for 10 minutes.'**
  String codeSentWhatsapp(String destination);

  /// E3 text.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {destination} by SMS. It works for 10 minutes.'**
  String codeSentSms(String destination);

  /// E3e text.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {destination}. It works for 10 minutes. Check spam if you don\'t see it.'**
  String codeSentEmail(String destination);

  /// E3 timer.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {time}'**
  String codeResendIn(String time);

  /// E3 link.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get codeResend;

  /// E3 link.
  ///
  /// In en, this message translates to:
  /// **'Use a different number'**
  String get codeDifferentNumber;

  /// E3e link.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get codeDifferentEmail;

  /// E3 error.
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t right. Check it and try again.'**
  String get codeWrong;

  /// E3 error.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Send a new one.'**
  String get codeExpired;

  /// Accessibility label for the code boxes.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeFieldLabel;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get errorNetwork;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait a minute and try again.'**
  String get errorTooMany;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorGeneric;

  /// Error.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t send the code. Try again, or use email instead.'**
  String get errorSendFailed;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// E9 title.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get aboutTitle;

  /// E9 intro.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 2. This is how people will find you. You can change it later.'**
  String get aboutIntro;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// Field placeholder.
  ///
  /// In en, this message translates to:
  /// **'Choose your role'**
  String get rolePlaceholder;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Company (optional)'**
  String get companyOptional;

  /// Field placeholder.
  ///
  /// In en, this message translates to:
  /// **'Search or type your company'**
  String get companyPlaceholder;

  /// Footer button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Write your first name.'**
  String get firstNameRequired;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Write your last name.'**
  String get lastNameRequired;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Choose your role.'**
  String get roleRequired;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Choose your country.'**
  String get countryRequired;

  /// Company search sheet title.
  ///
  /// In en, this message translates to:
  /// **'Your company'**
  String get companySheetTitle;

  /// Search placeholder.
  ///
  /// In en, this message translates to:
  /// **'Search companies'**
  String get companySearch;

  /// Save the typed company name.
  ///
  /// In en, this message translates to:
  /// **'Use “{name}”'**
  String companyUseTyped(String name);

  /// Company sheet helper.
  ///
  /// In en, this message translates to:
  /// **'Saved as you typed it. It links to a company page only if one is registered.'**
  String get companyUseTypedHelp;

  /// Clear the company.
  ///
  /// In en, this message translates to:
  /// **'No company'**
  String get companyNone;

  /// E9b title.
  ///
  /// In en, this message translates to:
  /// **'Your role'**
  String get roleTitle;

  /// E9b intro.
  ///
  /// In en, this message translates to:
  /// **'What do you do on site or in the office? It shows under your name and decides which people and Spaces you see first.'**
  String get roleIntro;

  /// E9b search.
  ///
  /// In en, this message translates to:
  /// **'Search trade or role'**
  String get roleSearch;

  /// E9b section. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'POPULAR IN {country}'**
  String rolePopularIn(String country);

  /// E9b custom role row.
  ///
  /// In en, this message translates to:
  /// **'Add “{text}” as your role'**
  String roleAddCustom(String text);

  /// E9b footer note.
  ///
  /// In en, this message translates to:
  /// **'Not in the list? Type it in search and add it as your role.'**
  String get roleNotInList;

  /// Footer button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// E10 title.
  ///
  /// In en, this message translates to:
  /// **'People to follow'**
  String get peopleTitle;

  /// App bar action.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Progress label.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepOf(int step, int total);

  /// E10 headline.
  ///
  /// In en, this message translates to:
  /// **'Start with people you\'d work with'**
  String get peopleHeadline;

  /// E10 body.
  ///
  /// In en, this message translates to:
  /// **'Picked for a {role} in {country}. You can change this any time.'**
  String peopleBody(String role, String country);

  /// E10 section. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'FROM {company}'**
  String peopleFromCompany(String company);

  /// E10 section.
  ///
  /// In en, this message translates to:
  /// **'WORKING NEAR YOU'**
  String get peopleNearYou;

  /// E10 reason.
  ///
  /// In en, this message translates to:
  /// **'Your company'**
  String get reasonCompany;

  /// E10 reason.
  ///
  /// In en, this message translates to:
  /// **'Near you · {place}'**
  String reasonNear(String place);

  /// E10 reason.
  ///
  /// In en, this message translates to:
  /// **'Works in {country}'**
  String reasonSameCountry(String country);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// Button state.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// E10 empty state.
  ///
  /// In en, this message translates to:
  /// **'No suggestions yet. As your team joins BuildVibes, you\'ll see them here.'**
  String get peopleEmpty;

  /// Join wall (H7) title.
  ///
  /// In en, this message translates to:
  /// **'Join BuildVibes to do this'**
  String get joinWallTitle;

  /// Join wall body.
  ///
  /// In en, this message translates to:
  /// **'It takes about a minute. No password.'**
  String get joinWallBody;

  /// Profile tab for guests.
  ///
  /// In en, this message translates to:
  /// **'You\'re browsing as a guest'**
  String get guestProfileTitle;

  /// Profile row.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Follower count on a profile (allowed by the founder).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 follower} other{{count} followers}}'**
  String profileFollowers(int count);

  /// Following count on your own profile.
  ///
  /// In en, this message translates to:
  /// **'{count} following'**
  String profileFollowing(int count);

  /// Button and screen title.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEdit;

  /// Profile tab.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get profileTabOverview;

  /// Profile tab.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profileTabPosts;

  /// Profile tab.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get profileTabProjects;

  /// Profile tab.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get profileTabExperience;

  /// A CV project confirmed by a teammate.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get proofConfirmed;

  /// A CV project not confirmed yet.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get proofWaiting;

  /// Proof card with no projects.
  ///
  /// In en, this message translates to:
  /// **'Add a project to start your proof'**
  String get proofEmptyTitle;

  /// Proof card with no projects.
  ///
  /// In en, this message translates to:
  /// **'Projects on your CV show here. Teammates in your Spaces confirm them.'**
  String get proofEmptyBody;

  /// Own profile row.
  ///
  /// In en, this message translates to:
  /// **'Finish your profile'**
  String get finishProfileTitle;

  /// Own profile row.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String finishProfileProgress(int done, int total);

  /// Profile section.
  ///
  /// In en, this message translates to:
  /// **'Open to'**
  String get openToTitle;

  /// Open to option.
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get openToContract;

  /// Open to option.
  ///
  /// In en, this message translates to:
  /// **'Consulting'**
  String get openToConsulting;

  /// Open to option.
  ///
  /// In en, this message translates to:
  /// **'Full-time role'**
  String get openToFullTime;

  /// Open to option.
  ///
  /// In en, this message translates to:
  /// **'Part-time'**
  String get openToPartTime;

  /// Open to option.
  ///
  /// In en, this message translates to:
  /// **'Mentoring'**
  String get openToMentoring;

  /// Open to visibility note.
  ///
  /// In en, this message translates to:
  /// **'Only you see this.'**
  String get openToOnlyYou;

  /// Open to visibility note.
  ///
  /// In en, this message translates to:
  /// **'Only your connections see this.'**
  String get openToConnectionsOnly;

  /// Profile section.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAbout;

  /// Link to the Projects tab.
  ///
  /// In en, this message translates to:
  /// **'See all projects'**
  String get profileSeeAllProjects;

  /// Work delivered empty state.
  ///
  /// In en, this message translates to:
  /// **'Nothing checked yet.'**
  String get workDeliveredEmpty;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'No experience added yet.'**
  String get experienceEmpty;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'No projects on the CV yet.'**
  String get projectsEmpty;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'No posts yet.'**
  String get postsEmpty;

  /// Open end of a date range.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// Forecast end date.
  ///
  /// In en, this message translates to:
  /// **'Expected {month}'**
  String expectedMonth(String month);

  /// A date range.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String dateRange(String start, String end);

  /// Overflow menu.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get profileMore;

  /// Overflow action.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String blockPerson(String name);

  /// Confirm sheet title.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockConfirmTitle(String name);

  /// Confirm sheet body.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see each other\'s posts or profiles, and follows between you are removed. They aren\'t told.'**
  String get blockConfirmBody;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// Missing or blocked profile.
  ///
  /// In en, this message translates to:
  /// **'This profile isn\'t available.'**
  String get profileNotFound;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Confirmation.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// Edit profile row.
  ///
  /// In en, this message translates to:
  /// **'Name, photo and headline'**
  String get editBasics;

  /// Edit profile row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a few lines about your work'**
  String get editAboutEmpty;

  /// Edit profile row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Visibility per project'**
  String get editProjectsSub;

  /// Edit profile row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Say what you\'re open to'**
  String get editOpenToEmpty;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Headline'**
  String get headline;

  /// Field placeholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. BIM Manager'**
  String get headlineHint;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get addPhoto;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'City or area (optional)'**
  String get placeOptional;

  /// About field placeholder.
  ///
  /// In en, this message translates to:
  /// **'What do you do, and on which kind of projects?'**
  String get aboutHint;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Add experience'**
  String get experienceAdd;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Edit experience'**
  String get experienceEdit;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Write the title.'**
  String get titleRequired;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get startedLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get endedLabel;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Choose when it started.'**
  String get startRequired;

  /// Visibility section label.
  ///
  /// In en, this message translates to:
  /// **'Who can see this'**
  String get whoCanSee;

  /// Visibility option.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get visibilityEveryone;

  /// Visibility option.
  ///
  /// In en, this message translates to:
  /// **'Anyone signed in to BuildVibes.'**
  String get visibilityEveryoneSub;

  /// Visibility option.
  ///
  /// In en, this message translates to:
  /// **'Connections only'**
  String get visibilityConnections;

  /// Visibility option.
  ///
  /// In en, this message translates to:
  /// **'People you follow who follow you back.'**
  String get visibilityConnectionsSub;

  /// Visibility option.
  ///
  /// In en, this message translates to:
  /// **'Only me'**
  String get visibilityOnlyMe;

  /// Visibility option.
  ///
  /// In en, this message translates to:
  /// **'Nobody else can see it.'**
  String get visibilityOnlyMeSub;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'A short note (optional)'**
  String get openToNote;

  /// Field placeholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Available from next month'**
  String get openToNoteHint;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Show on my profile'**
  String get cvShowOnProfile;

  /// Button and screen title.
  ///
  /// In en, this message translates to:
  /// **'Add a project'**
  String get addProject;

  /// Search placeholder.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectSearchHint;

  /// P13 intro.
  ///
  /// In en, this message translates to:
  /// **'One record per project, so everyone who worked on it shows up in one place.'**
  String get addProjectIntro;

  /// Match reason. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'SAME NAME'**
  String get matchSameName;

  /// Match reason. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'SAME SITE'**
  String get matchSameSite;

  /// P13 button.
  ///
  /// In en, this message translates to:
  /// **'This is it · add to my CV'**
  String get thisIsIt;

  /// P13 card.
  ///
  /// In en, this message translates to:
  /// **'None of these? Start a new record'**
  String get startNewRecord;

  /// P13 card.
  ///
  /// In en, this message translates to:
  /// **'Name, type, dates and your role. About a minute.'**
  String get startNewRecordSub;

  /// Badge on a match already on your CV.
  ///
  /// In en, this message translates to:
  /// **'On your CV'**
  String get onYourCvBadge;

  /// CV entry sheet title.
  ///
  /// In en, this message translates to:
  /// **'Your role on {project}'**
  String cvEntryTitle(String project);

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Your role'**
  String get yourRole;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Write your role.'**
  String get roleTitleRequired;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Add to my CV'**
  String get addToCv;

  /// P14 title.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newProjectTitle;

  /// Title block header. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'PROJECT RECORD'**
  String get projectRecordLabel;

  /// Title block stamp. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'REV A · DRAFT'**
  String get draftStamp;

  /// Title block stamp. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'SHARED RECORD · NO OWNER'**
  String get sharedRecordStamp;

  /// Title block cell. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'PROJECT NAME'**
  String get cellProjectName;

  /// Title block cell.
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get cellType;

  /// Title block cell.
  ///
  /// In en, this message translates to:
  /// **'LOCATION'**
  String get cellLocation;

  /// Title block cell.
  ///
  /// In en, this message translates to:
  /// **'STARTED'**
  String get cellStarted;

  /// Title block cell.
  ///
  /// In en, this message translates to:
  /// **'ENDED'**
  String get cellEnded;

  /// Title block cell.
  ///
  /// In en, this message translates to:
  /// **'YOUR ROLE'**
  String get cellYourRole;

  /// Empty title block cell.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// P14 note.
  ///
  /// In en, this message translates to:
  /// **'This defines the project and puts it on your CV with your role. Nobody owns a project; anyone who worked on it can add it to their own CV.'**
  String get newProjectNote;

  /// Field placeholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Al Kout Mall Phase 2'**
  String get projectNameHint;

  /// PJ1 title.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get projectTitle;

  /// PJ1 note.
  ///
  /// In en, this message translates to:
  /// **'Anyone can put this project on their CV. Nobody owns it; corrections are checked by BuildVibes.'**
  String get projectNoOwnerNote;

  /// Link.
  ///
  /// In en, this message translates to:
  /// **'Suggest an edit'**
  String get suggestEdit;

  /// PJ1 section. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'ON YOUR CV'**
  String get onYourCv;

  /// PJ1 section. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'PEOPLE WHO PUT IT ON THEIR CV'**
  String get peopleOnProject;

  /// PJ1 note.
  ///
  /// In en, this message translates to:
  /// **'Only people who chose to show it on their profile.'**
  String get peopleOnProjectNote;

  /// PJ1 empty state.
  ///
  /// In en, this message translates to:
  /// **'Nobody else has shown it yet.'**
  String get peopleOnProjectEmpty;

  /// Sheet title.
  ///
  /// In en, this message translates to:
  /// **'Suggest an edit to {project}'**
  String suggestTitle(String project);

  /// Sheet body.
  ///
  /// In en, this message translates to:
  /// **'Nobody owns this record, so BuildVibes checks every change. People who listed it are told when it changes.'**
  String get suggestBody;

  /// Sheet section. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S WRONG'**
  String get whatsWrong;

  /// Chip.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get wrongName;

  /// Chip.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get wrongType;

  /// Chip.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get wrongLocation;

  /// Chip.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get wrongDates;

  /// Chip.
  ///
  /// In en, this message translates to:
  /// **'It\'s a duplicate'**
  String get wrongDuplicate;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Correct value'**
  String get correctValue;

  /// Field helper.
  ///
  /// In en, this message translates to:
  /// **'Add a source if you have one, such as a site board photo.'**
  String get correctValueHelp;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Write the correct value.'**
  String get correctValueRequired;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get sendForReview;

  /// Confirmation.
  ///
  /// In en, this message translates to:
  /// **'Thanks. We\'ll check it.'**
  String get suggestionSent;

  /// Month sheet option.
  ///
  /// In en, this message translates to:
  /// **'Still going'**
  String get monthPickerPresent;

  /// E2 main button (decision 04: email code only).
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get entryContinueEmail;

  /// E2 body when sign-in is by email.
  ///
  /// In en, this message translates to:
  /// **'Join with your email. It takes about a minute.'**
  String get entryJoinBodyEmail;

  /// E9 country helper.
  ///
  /// In en, this message translates to:
  /// **'You can change it in Settings.'**
  String get countryChangeLater;

  /// E9 field label.
  ///
  /// In en, this message translates to:
  /// **'Mobile number (optional)'**
  String get mobileOptional;

  /// E9 field helper.
  ///
  /// In en, this message translates to:
  /// **'Private: only you see it. It\'s never shown on your profile.'**
  String get mobileHelp;

  /// Home tab: the social feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get homeFeed;

  /// Home tab: your Spaces.
  ///
  /// In en, this message translates to:
  /// **'Spaces'**
  String get homeSpaces;

  /// S1 section overline.
  ///
  /// In en, this message translates to:
  /// **'PROJECT SPACES'**
  String get spacesProjectSpaces;

  /// S1 badge: join requests waiting for this admin.
  ///
  /// In en, this message translates to:
  /// **'{count} needs you'**
  String spacesNeedsYou(int count);

  /// A private work Space with no project.
  ///
  /// In en, this message translates to:
  /// **'Private work'**
  String get spacesPrivateWork;

  /// H1e card title.
  ///
  /// In en, this message translates to:
  /// **'Join your first Space'**
  String get spacesEmptyTitle;

  /// H1e card body (work Spaces only in the MVP).
  ///
  /// In en, this message translates to:
  /// **'A Space is where a project team runs its daily work. Once you join one, your daily report appears here: replies, updates and anything waiting for you.'**
  String get spacesEmptyBody;

  /// H1e note under the card.
  ///
  /// In en, this message translates to:
  /// **'Your feed still shows posts, announcements and celebrations from your network.'**
  String get spacesEmptyFeedNote;

  /// Button and sheet title.
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code'**
  String get spacesEnterCode;

  /// Code sheet helper.
  ///
  /// In en, this message translates to:
  /// **'6 letters and numbers, from the person who invited you'**
  String get spacesCodeHint;

  /// Code sheet: who shared the code.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name}'**
  String spacesInvitedBy(String name);

  /// Code sheet button.
  ///
  /// In en, this message translates to:
  /// **'Ask to join'**
  String get spacesAskToJoin;

  /// Code sheet error.
  ///
  /// In en, this message translates to:
  /// **'This code isn\'t valid. Check it with the person who sent it.'**
  String get spacesCodeNotValid;

  /// Code sheet error after 10 wrong codes.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Try again in an hour.'**
  String get spacesTooManyTries;

  /// Code sheet: already a member.
  ///
  /// In en, this message translates to:
  /// **'You\'re already in this Space.'**
  String get spacesAlreadyMember;

  /// Code sheet: declined in the last day.
  ///
  /// In en, this message translates to:
  /// **'You can ask again tomorrow.'**
  String get spacesDeclinedWait;

  /// Toast after asking to join.
  ///
  /// In en, this message translates to:
  /// **'Request sent. The Space admin will confirm you.'**
  String get spacesRequestSent;

  /// Code sheet: a request is already pending.
  ///
  /// In en, this message translates to:
  /// **'You already asked. Waiting for the Space admin.'**
  String get spacesAlreadyWaiting;

  /// Waiting card line.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the Space admin to confirm you'**
  String get spacesWaiting;

  /// Waiting card button.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get spacesCancelRequest;

  /// Declined card line. No reason, no name.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed'**
  String get spacesNotConfirmed;

  /// Declined card button.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get spacesDismiss;

  /// S5 title.
  ///
  /// In en, this message translates to:
  /// **'New Space'**
  String get spacesNewTitle;

  /// S5 preview overline.
  ///
  /// In en, this message translates to:
  /// **'HOW IT WILL APPEAR TO MEMBERS'**
  String get spacesPreviewLabel;

  /// S5 field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get spacesNameLabel;

  /// S5 placeholder. No country facts.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tower B — Design team'**
  String get spacesNameHint;

  /// S5 error.
  ///
  /// In en, this message translates to:
  /// **'Write a name with at least 2 letters.'**
  String get spacesNameRequired;

  /// S5 field.
  ///
  /// In en, this message translates to:
  /// **'About (optional)'**
  String get spacesAboutLabel;

  /// S5 helper.
  ///
  /// In en, this message translates to:
  /// **'Shown to people you invite.'**
  String get spacesAboutHelp;

  /// S5 field.
  ///
  /// In en, this message translates to:
  /// **'Link to a project (optional)'**
  String get spacesLinkLabel;

  /// S5 select placeholder.
  ///
  /// In en, this message translates to:
  /// **'Choose a project'**
  String get spacesLinkPlaceholder;

  /// S5 helper.
  ///
  /// In en, this message translates to:
  /// **'Linking a project makes this its project Space. Members you confirm get that project confirmed on their profile.'**
  String get spacesLinkHelp;

  /// S5 main button.
  ///
  /// In en, this message translates to:
  /// **'Create Space'**
  String get spacesCreateButton;

  /// Link a project sheet title.
  ///
  /// In en, this message translates to:
  /// **'Link a project'**
  String get spacesLinkTitle;

  /// Link a project sheet search.
  ///
  /// In en, this message translates to:
  /// **'Search your projects'**
  String get spacesLinkSearch;

  /// Link a project sheet row.
  ///
  /// In en, this message translates to:
  /// **'Your role: {role}'**
  String spacesYourRole(String role);

  /// Space tab.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get spacesTabWork;

  /// Space tab.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get spacesTabChat;

  /// Space tab.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get spacesTabPeople;

  /// Space tab.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get spacesTabLibrary;

  /// Space People tab and Space info.
  ///
  /// In en, this message translates to:
  /// **'Invite people'**
  String get spacesInvitePeople;

  /// S16 title.
  ///
  /// In en, this message translates to:
  /// **'Invite to {space}'**
  String spacesInviteTitle(String space);

  /// S16 card label and code sheet field.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get spacesInviteCode;

  /// S16 code expiry.
  ///
  /// In en, this message translates to:
  /// **'Works until {date}'**
  String spacesCodeWorksUntil(String date);

  /// S16 button.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get spacesShareCode;

  /// S16 admin button.
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get spacesNewCode;

  /// S16 confirm sheet title.
  ///
  /// In en, this message translates to:
  /// **'Make a new code?'**
  String get spacesNewCodeTitle;

  /// S16 note.
  ///
  /// In en, this message translates to:
  /// **'The old code stops working.'**
  String get spacesNewCodeNote;

  /// S16 explanation.
  ///
  /// In en, this message translates to:
  /// **'Send the code on WhatsApp or read it out. The Space admin confirms each person before they join.'**
  String get spacesInviteHow;

  /// Text shared with the system share sheet.
  ///
  /// In en, this message translates to:
  /// **'Join {space} on BuildVibes. Invite code: {code}'**
  String spacesShareText(String space, String code);

  /// Space screen when it is gone or you are not a member.
  ///
  /// In en, this message translates to:
  /// **'This Space isn\'t available.'**
  String get spacesNotFound;

  /// Space error 42501.
  ///
  /// In en, this message translates to:
  /// **'You can\'t do that in this Space.'**
  String get spacesNotAllowed;

  /// create_space limit (P0001).
  ///
  /// In en, this message translates to:
  /// **'You made many Spaces today. Try again tomorrow.'**
  String get spacesTooManyToday;

  /// S16 code card overline.
  ///
  /// In en, this message translates to:
  /// **'INVITE CODE'**
  String get spacesInviteCodeTag;

  /// Relative time.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// Relative time in minutes.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 min ago} other{{n} min ago}}'**
  String timeMinutesAgo(int n);

  /// Relative time in hours.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String timeHoursAgo(int n);

  /// Relative time.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get timeYesterday;

  /// Relative time in days.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day ago} other{{n} days ago}}'**
  String timeDaysAgo(int n);

  /// S10k search.
  ///
  /// In en, this message translates to:
  /// **'Search members'**
  String get spacesSearchMembers;

  /// S10k overline, admins only.
  ///
  /// In en, this message translates to:
  /// **'REQUESTS TO JOIN · YOU CONFIRM'**
  String get spacesRequestsTitle;

  /// Request line: when.
  ///
  /// In en, this message translates to:
  /// **'Asked {when}'**
  String spacesAsked(String when);

  /// Request line: who shared the code.
  ///
  /// In en, this message translates to:
  /// **'invite code shared by {name}'**
  String spacesViaCodeFrom(String name);

  /// Request line: no name.
  ///
  /// In en, this message translates to:
  /// **'invite code'**
  String get spacesViaCode;

  /// Request button.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get spacesDecline;

  /// Request button.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get spacesConfirm;

  /// S10k section: the Space admins (glossary: Space admin).
  ///
  /// In en, this message translates to:
  /// **'Space admin'**
  String get spacesAdminSection;

  /// The line under a Space admin's name in People.
  ///
  /// In en, this message translates to:
  /// **'Space admin'**
  String get spacesAdminTag;

  /// S10k section.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get spacesMembers;

  /// Tag on your own row.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get spacesYouTag;

  /// S10k search with no result.
  ///
  /// In en, this message translates to:
  /// **'No one matches.'**
  String get spacesNoMatch;

  /// Pass name.
  ///
  /// In en, this message translates to:
  /// **'Lead'**
  String get spacesPassLead;

  /// Pass name.
  ///
  /// In en, this message translates to:
  /// **'Crew'**
  String get spacesPassCrew;

  /// Pass name.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get spacesPassViewer;

  /// Member row: the pass.
  ///
  /// In en, this message translates to:
  /// **'{pass} pass'**
  String spacesPassLine(String pass);

  /// Confirm sheet overline. Neutral: no him/her.
  ///
  /// In en, this message translates to:
  /// **'GIVE A PASS FOR THIS SPACE'**
  String get spacesGivePass;

  /// Lead pass card.
  ///
  /// In en, this message translates to:
  /// **'Opens: create items · check and close · files · invite'**
  String get spacesLeadOpens;

  /// Lead pass card.
  ///
  /// In en, this message translates to:
  /// **'Engineers, supervisors'**
  String get spacesLeadFor;

  /// Crew pass card.
  ///
  /// In en, this message translates to:
  /// **'Opens: chat · mark own items done with a photo · files'**
  String get spacesCrewOpens;

  /// Crew pass card.
  ///
  /// In en, this message translates to:
  /// **'Foremen, technicians, subcontractors'**
  String get spacesCrewFor;

  /// Viewer pass card.
  ///
  /// In en, this message translates to:
  /// **'Opens: read and chat only'**
  String get spacesViewerOpens;

  /// Viewer pass card.
  ///
  /// In en, this message translates to:
  /// **'Client, supplier'**
  String get spacesViewerFor;

  /// Confirm sheet main button.
  ///
  /// In en, this message translates to:
  /// **'Confirm as {pass}'**
  String spacesConfirmAs(String pass);

  /// S17k banner after confirming.
  ///
  /// In en, this message translates to:
  /// **'{name} joined as {pass}. The Space is open to them now.'**
  String spacesJoinedAs(String name, String pass);

  /// S10k-D toast.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s request declined. They aren\'t told why.'**
  String spacesDeclined(String name);

  /// Toast action.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get spacesUndo;

  /// confirm/decline P0001.
  ///
  /// In en, this message translates to:
  /// **'This request was already answered.'**
  String get spacesAlreadyAnswered;

  /// S17k title.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get spacesMemberTitle;

  /// S17k overline.
  ///
  /// In en, this message translates to:
  /// **'THIS PASS OPENS'**
  String get spacesPassOpens;

  /// S17k stamp when rights were changed.
  ///
  /// In en, this message translates to:
  /// **'{pass} · CUSTOM'**
  String spacesPassCustom(String pass);

  /// S17k line.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by {name}'**
  String spacesConfirmedBy(String name);

  /// S17k line.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by you'**
  String get spacesConfirmedByYou;

  /// Right, always on.
  ///
  /// In en, this message translates to:
  /// **'Chat in Everyone and their Teams'**
  String get spacesRightChat;

  /// Right, set by the pass.
  ///
  /// In en, this message translates to:
  /// **'Mark own items done'**
  String get spacesRightMarkDone;

  /// Right.
  ///
  /// In en, this message translates to:
  /// **'Add files to the Library'**
  String get spacesRightFiles;

  /// Right.
  ///
  /// In en, this message translates to:
  /// **'Create work items'**
  String get spacesRightCreate;

  /// Right.
  ///
  /// In en, this message translates to:
  /// **'Invite people'**
  String get spacesRightInvite;

  /// Right that can't change.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get spacesAlways;

  /// Action: give this right.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get spacesOpenRight;

  /// Action: take this right away.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get spacesLockRight;

  /// S17k overline.
  ///
  /// In en, this message translates to:
  /// **'CHANGE PASS'**
  String get spacesChangePass;

  /// S17k overline.
  ///
  /// In en, this message translates to:
  /// **'TEAMS'**
  String get spacesTeamsLabel;

  /// S17k switch.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get spacesMakeAdmin;

  /// S17k switch helper.
  ///
  /// In en, this message translates to:
  /// **'Admins confirm people, give passes and manage the Space.'**
  String get spacesMakeAdminHelp;

  /// S17k destructive button.
  ///
  /// In en, this message translates to:
  /// **'Remove from Space'**
  String get spacesRemove;

  /// Confirm sheet.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String spacesRemoveTitle(String name);

  /// Confirm sheet.
  ///
  /// In en, this message translates to:
  /// **'Their closed work items stay in the record.'**
  String get spacesRemoveBody;

  /// S17k-b banner.
  ///
  /// In en, this message translates to:
  /// **'{right}: open for {name}. The pass shows as Custom.'**
  String spacesRightOpened(String right, String name);

  /// S17k banner.
  ///
  /// In en, this message translates to:
  /// **'{right}: locked for {name}.'**
  String spacesRightLocked(String right, String name);

  /// S17k banner.
  ///
  /// In en, this message translates to:
  /// **'{name} now has a {pass} pass.'**
  String spacesPassChanged(String name, String pass);

  /// S17k banner.
  ///
  /// In en, this message translates to:
  /// **'{name} is now a Space admin.'**
  String spacesAdminOn(String name);

  /// S17k banner.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer a Space admin.'**
  String spacesAdminOff(String name);

  /// S17k banner.
  ///
  /// In en, this message translates to:
  /// **'Teams saved.'**
  String get spacesTeamsSaved;

  /// Last admin (P0001).
  ///
  /// In en, this message translates to:
  /// **'A Space needs an admin. Make someone else an admin first.'**
  String get spacesNeedsAdmin;

  /// Toast after removing.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed from the Space.'**
  String spacesRemoved(String name);

  /// S17k note for an admin member.
  ///
  /// In en, this message translates to:
  /// **'Admins have every right in the Space.'**
  String get spacesAdminRights;

  /// Joins the last two names.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b}'**
  String listAnd(String a, String b);

  /// More names than shown. No count (rule 3).
  ///
  /// In en, this message translates to:
  /// **'{names} and others'**
  String listAndOthers(String names);

  /// Profile project row: who confirmed (founder decision, 11 Oct).
  ///
  /// In en, this message translates to:
  /// **'Confirmed by {names}'**
  String proofConfirmedBy(String names);

  /// S15 title.
  ///
  /// In en, this message translates to:
  /// **'Space info'**
  String get spacesInfoTitle;

  /// S15 row and S15k-I title.
  ///
  /// In en, this message translates to:
  /// **'Who can invite'**
  String get spacesWhoCanInvite;

  /// S15 row and S15k-N title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get spacesNotifications;

  /// Option.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get spacesNotifyOff;

  /// S15 row and S15d title.
  ///
  /// In en, this message translates to:
  /// **'Hand over Space admin'**
  String get spacesTransfer;

  /// S15 row.
  ///
  /// In en, this message translates to:
  /// **'Delete Space'**
  String get spacesDeleteSpace;

  /// Confirm button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get spacesDeleteButton;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'{space} was deleted.'**
  String spacesDeleted(String space);

  /// S15 row.
  ///
  /// In en, this message translates to:
  /// **'Leave Space'**
  String get spacesLeave;

  /// S15c title.
  ///
  /// In en, this message translates to:
  /// **'Leave {space}?'**
  String spacesLeaveTitle(String space);

  /// S15c button.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get spacesLeaveButton;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'You left {space}.'**
  String spacesLeft(String space);

  /// Edit sheet title.
  ///
  /// In en, this message translates to:
  /// **'Edit Space'**
  String get spacesEditTitle;

  /// S15d intro.
  ///
  /// In en, this message translates to:
  /// **'Choose a member to become a Space admin. You will stay in the Space as a member.'**
  String get spacesTransferIntro;

  /// S15d button.
  ///
  /// In en, this message translates to:
  /// **'Hand over to {name}'**
  String spacesTransferTo(String name);

  /// S15e title.
  ///
  /// In en, this message translates to:
  /// **'Hand over to {name}?'**
  String spacesTransferTitle(String name);

  /// S15e body. Neutral.
  ///
  /// In en, this message translates to:
  /// **'{name} becomes an admin of {space} and you become a member.'**
  String spacesTransferBody(String name, String space);

  /// S15e button.
  ///
  /// In en, this message translates to:
  /// **'Hand over'**
  String get spacesTransferButton;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'{name} is now a Space admin. You\'re a member.'**
  String spacesTransferred(String name);

  /// S15d empty.
  ///
  /// In en, this message translates to:
  /// **'Confirm someone into the Space first.'**
  String get spacesNoOneToTransfer;

  /// S10k section.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get spacesTeams;

  /// Team size inside a Space (founder ok, 12 Oct).
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{No members yet} =1{1 member} other{{n} members}}'**
  String spacesTeamMembers(int n);

  /// Team row.
  ///
  /// In en, this message translates to:
  /// **'you\'re in it'**
  String get spacesInTeam;

  /// S10k link and S12 title.
  ///
  /// In en, this message translates to:
  /// **'New Team'**
  String get spacesNewTeam;

  /// S12 field.
  ///
  /// In en, this message translates to:
  /// **'Team name'**
  String get spacesTeamName;

  /// S12 placeholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. MEP Team'**
  String get spacesTeamNameHint;

  /// S12 helper.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the Space can see Team names and members. Only members see its chat.'**
  String get spacesTeamHelp;

  /// S12 section.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get spacesAddMembers;

  /// S12 button.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{Create Team} =1{Create Team · 1 person} other{Create Team · {n} people}}'**
  String spacesCreateTeam(int n);

  /// S12 error.
  ///
  /// In en, this message translates to:
  /// **'Write a Team name.'**
  String get spacesTeamNameRequired;

  /// 23505.
  ///
  /// In en, this message translates to:
  /// **'There\'s already a Team with this name.'**
  String get spacesTeamDuplicate;

  /// S11k line (Figma copy fixed to this Space's name).
  ///
  /// In en, this message translates to:
  /// **'A Team in {space}. Posts and threads for this Team are seen only by its members.'**
  String spacesTeamIntro(String space);

  /// S11k button.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get spacesAddPeople;

  /// Add people sheet title.
  ///
  /// In en, this message translates to:
  /// **'People in this Team'**
  String get spacesTeamPeopleTitle;

  /// S11k menu.
  ///
  /// In en, this message translates to:
  /// **'Rename Team'**
  String get spacesRenameTeam;

  /// S11k menu.
  ///
  /// In en, this message translates to:
  /// **'Delete Team'**
  String get spacesDeleteTeam;

  /// Confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {team}?'**
  String spacesDeleteTeamTitle(String team);

  /// Confirm.
  ///
  /// In en, this message translates to:
  /// **'Its members stay in the Space.'**
  String get spacesDeleteTeamBody;

  /// S11k empty.
  ///
  /// In en, this message translates to:
  /// **'No one in this Team yet.'**
  String get spacesNoTeamMembers;

  /// Delete Space dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete {space}?'**
  String spacesDeleteTitle(String space);

  /// Delete Space dialog.
  ///
  /// In en, this message translates to:
  /// **'It\'s removed for everyone.'**
  String get spacesDeleteBody;

  /// S15c, private Space.
  ///
  /// In en, this message translates to:
  /// **'You will stop seeing its chats and work. To come back, you need a new invite.'**
  String get spacesLeaveBodyPrivate;

  /// Last admin tries to leave (P0001).
  ///
  /// In en, this message translates to:
  /// **'Make someone else an admin first, or delete the Space.'**
  String get spacesLastAdmin;

  /// W3 when gone or not a member.
  ///
  /// In en, this message translates to:
  /// **'This item isn\'t available.'**
  String get workItemGone;

  /// W4 field.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get workNote;

  /// RE2 title.
  ///
  /// In en, this message translates to:
  /// **'Work you delivered'**
  String get deliveredTitle;

  /// RE2 intro.
  ///
  /// In en, this message translates to:
  /// **'Only work items that were checked and closed in a Space. Everything is hidden until you switch it on. Shown items appear on your profile.'**
  String get deliveredIntro;

  /// RE2 stamp.
  ///
  /// In en, this message translates to:
  /// **'SHOWN ON PROFILE'**
  String get deliveredShown;

  /// RE2 card state.
  ///
  /// In en, this message translates to:
  /// **'Hidden · tap to show'**
  String get deliveredHidden;

  /// RE2 / RE1 line.
  ///
  /// In en, this message translates to:
  /// **'Checked by {name} · {date}'**
  String deliveredCheckedBy(String name, String date);

  /// RE2 footer.
  ///
  /// In en, this message translates to:
  /// **'People see who checked each item. Items from a Space you left stay yours to show or hide.'**
  String get deliveredFooter;

  /// RE2 empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Work items you own appear here once they\'re checked.'**
  String get deliveredEmpty;

  /// Profile section link.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get deliveredSeeAll;

  /// RE1 title.
  ///
  /// In en, this message translates to:
  /// **'Delivered work'**
  String get deliveredPublicTitle;

  /// RE1 subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shown by {name}'**
  String deliveredShownBy(String name);

  /// RE1 row.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get deliveredProject;

  /// RE1 row.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get deliveredPlace;

  /// RE1 row.
  ///
  /// In en, this message translates to:
  /// **'Checked by'**
  String get deliveredCheckedRow;

  /// RE1 note. Neutral.
  ///
  /// In en, this message translates to:
  /// **'{name} chose to show this. The discussion, files and the Space stay private. Only the title, photo, place and who checked it are shown.'**
  String deliveredPrivacy(String name);

  /// Own profile: checked items exist but all are hidden.
  ///
  /// In en, this message translates to:
  /// **'Nothing shown yet. Tap See all to choose what shows.'**
  String get deliveredNoneShown;

  /// Delivered card when the checker's name is hidden (a block).
  ///
  /// In en, this message translates to:
  /// **'Checked · {date}'**
  String deliveredCheckedOn(String date);

  /// RE1 row label when the checker's name is hidden (a block).
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get deliveredCheckedRowNoName;

  /// The Space-wide thread.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get chatEveryone;

  /// Thread subtitle for a Team thread.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get chatTeam;

  /// S7k footer for members.
  ///
  /// In en, this message translates to:
  /// **'You see threads for Everyone and your Teams.'**
  String get chatThreadsNote;

  /// S7k footer for admins.
  ///
  /// In en, this message translates to:
  /// **'As a Space admin, you see Everyone and every Team.'**
  String get chatThreadsNoteAdmin;

  /// Thread with no messages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.'**
  String get chatNoMessages;

  /// Last line: your own message.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatYou;

  /// S7k last message line.
  ///
  /// In en, this message translates to:
  /// **'{name}: {text}'**
  String chatLastLine(String name, String text);

  /// A photo message, in a list.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPhoto;

  /// A file message, in a list.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFile;

  /// A voice message, in a list.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get chatVoice;

  /// A card, in the thread list.
  ///
  /// In en, this message translates to:
  /// **'Work item update'**
  String get chatWorkItemUpdate;

  /// Day divider.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// Day divider and list time.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// S9k banner. No member count: admins see it too.
  ///
  /// In en, this message translates to:
  /// **'Only {team} and the Space admins see this thread.'**
  String chatTeamPrivacy(String team);

  /// Composer placeholder.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatMessageHint;

  /// Send button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// A deleted message.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get chatDeleted;

  /// Pending message.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get chatSending;

  /// Failed message.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get chatNotSent;

  /// Failed message action.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatRetry;

  /// Message action.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReply;

  /// Message action.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopy;

  /// Toast after Copy.
  ///
  /// In en, this message translates to:
  /// **'Copied.'**
  String get chatCopied;

  /// Message action.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatDelete;

  /// Delete dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete this message?'**
  String get chatDeleteTitle;

  /// Delete dialog body.
  ///
  /// In en, this message translates to:
  /// **'Everyone in this thread sees “Message deleted” instead.'**
  String get chatDeleteBody;

  /// Delete dialog button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDeleteConfirm;

  /// Above the composer.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String chatReplyingTo(String name);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get chatCancelReply;

  /// Card line. Arabic is a noun form, gender-neutral.
  ///
  /// In en, this message translates to:
  /// **'{name} raised a work item'**
  String chatCardRaised(String name);

  /// Card line (S8k).
  ///
  /// In en, this message translates to:
  /// **'{name} marked a work item done'**
  String chatCardDone(String name);

  /// Card line.
  ///
  /// In en, this message translates to:
  /// **'{name} checked and closed a work item'**
  String chatCardChecked(String name);

  /// Card line.
  ///
  /// In en, this message translates to:
  /// **'{name} sent a work item back'**
  String chatCardSentBack(String name);

  /// Card line.
  ///
  /// In en, this message translates to:
  /// **'{name} reassigned a work item'**
  String chatCardReassigned(String name);

  /// An old chat card for a work item the reader can't see: no title, no name.
  ///
  /// In en, this message translates to:
  /// **'Work item'**
  String get chatCardHidden;

  /// S7k last line: a card. Arabic noun form, gender-neutral.
  ///
  /// In en, this message translates to:
  /// **'{name} raised {ref}'**
  String chatLastRaised(String name, String ref);

  /// S7k last line: a card.
  ///
  /// In en, this message translates to:
  /// **'{name} marked {ref} done'**
  String chatLastDone(String name, String ref);

  /// S7k last line: a card.
  ///
  /// In en, this message translates to:
  /// **'{name} checked and closed {ref}'**
  String chatLastChecked(String name, String ref);

  /// S7k last line: a card.
  ///
  /// In en, this message translates to:
  /// **'{name} sent {ref} back'**
  String chatLastSentBack(String name, String ref);

  /// S7k last line: a card.
  ///
  /// In en, this message translates to:
  /// **'{name} reassigned {ref}'**
  String chatLastReassigned(String name, String ref);

  /// Composer attach button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or file'**
  String get chatAttach;

  /// Attach sheet.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get chatAttachCamera;

  /// Attach sheet.
  ///
  /// In en, this message translates to:
  /// **'Photo from your phone'**
  String get chatAttachGallery;

  /// Attach sheet.
  ///
  /// In en, this message translates to:
  /// **'PDF from your phone'**
  String get chatAttachPdf;

  /// Attach sheet helper.
  ///
  /// In en, this message translates to:
  /// **'It goes to the Space Library too.'**
  String get chatAttachPdfHelp;

  /// Remove a picked file (tooltip).
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get chatRemoveFile;

  /// File too large.
  ///
  /// In en, this message translates to:
  /// **'Files up to 25 MB.'**
  String get chatFileTooBig;

  /// Second PDF picked.
  ///
  /// In en, this message translates to:
  /// **'One PDF per message.'**
  String get chatOneDocument;

  /// File size.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String fileSizeMb(String size);

  /// File size.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String fileSizeKb(String size);

  /// LV1: the search field on top; it filters the list in the app (names, revisions, notes).
  ///
  /// In en, this message translates to:
  /// **'Search files'**
  String get librarySearch;

  /// S13k filter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryAll;

  /// S13k filter.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get libraryFiles;

  /// S13k section.
  ///
  /// In en, this message translates to:
  /// **'Recent in this Space'**
  String get libraryRecent;

  /// A file that came from chat.
  ///
  /// In en, this message translates to:
  /// **'From chat'**
  String get libraryFromChat;

  /// S13k empty.
  ///
  /// In en, this message translates to:
  /// **'No files yet. Drawings and photos shared in this Space appear here.'**
  String get libraryEmpty;

  /// S13k search empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches.'**
  String get libraryNoMatch;

  /// S13k button.
  ///
  /// In en, this message translates to:
  /// **'Add file'**
  String get libraryAdd;

  /// Add file title.
  ///
  /// In en, this message translates to:
  /// **'Add to the Library'**
  String get libraryAddTitle;

  /// New revision title.
  ///
  /// In en, this message translates to:
  /// **'New revision'**
  String get libraryRevisionTitle;

  /// New revision helper.
  ///
  /// In en, this message translates to:
  /// **'Replaces {name}. The old one is kept in the record.'**
  String libraryRevisionOf(String name);

  /// Add file picker.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF or photo'**
  String get libraryPickFile;

  /// Add file picker, after a pick.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get libraryChangeFile;

  /// Add file field.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get libraryName;

  /// Add file: Everyone or one Team (single choice).
  ///
  /// In en, this message translates to:
  /// **'Who sees it'**
  String get libraryFor;

  /// Add file helper for a Team file.
  ///
  /// In en, this message translates to:
  /// **'Only {team} and the Space admins see it.'**
  String libraryTeamOnly(String team);

  /// Add file field.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get libraryRev;

  /// Add file placeholder.
  ///
  /// In en, this message translates to:
  /// **'For example Rev C'**
  String get libraryRevHint;

  /// Add file note placeholder.
  ///
  /// In en, this message translates to:
  /// **'What changed'**
  String get libraryNoteHint;

  /// Add file button.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get libraryUpload;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Added to the Library.'**
  String get libraryAdded;

  /// Add file error.
  ///
  /// In en, this message translates to:
  /// **'Choose a file first.'**
  String get libraryPickFirst;

  /// Add file error.
  ///
  /// In en, this message translates to:
  /// **'Give it a title.'**
  String get libraryNameRequired;

  /// F1 subtitle part.
  ///
  /// In en, this message translates to:
  /// **'from {name}'**
  String previewFrom(String name);

  /// F1 stamp.
  ///
  /// In en, this message translates to:
  /// **'{rev} · CURRENT'**
  String previewCurrent(String rev);

  /// F1 stamp without a revision label.
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get previewCurrentNoRev;

  /// F1.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {date}'**
  String previewUploaded(String date);

  /// F1.
  ///
  /// In en, this message translates to:
  /// **'Used in'**
  String get previewUsedIn;

  /// F1 older revision line.
  ///
  /// In en, this message translates to:
  /// **'superseded, kept in the record'**
  String get previewSuperseded;

  /// F1 on an old revision.
  ///
  /// In en, this message translates to:
  /// **'A newer revision replaced this one.'**
  String get previewReplaced;

  /// F1 link.
  ///
  /// In en, this message translates to:
  /// **'Open the current one'**
  String get previewOpenCurrent;

  /// F1 button.
  ///
  /// In en, this message translates to:
  /// **'Share in chat'**
  String get previewShare;

  /// F1 button.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get previewDownload;

  /// F1 link.
  ///
  /// In en, this message translates to:
  /// **'Upload a new revision'**
  String get previewNewRevision;

  /// Share sheet title.
  ///
  /// In en, this message translates to:
  /// **'Share in which thread?'**
  String get previewShareTo;

  /// Share sheet helper.
  ///
  /// In en, this message translates to:
  /// **'A Team file is shared in its Team\'s thread only.'**
  String get previewShareTeamOnly;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Shared in {thread}.'**
  String previewShared(String thread);

  /// Toast after Download.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get previewSaved;

  /// F1 when the preview fails.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be shown here. Download it to open it.'**
  String get previewCantShow;

  /// F1 close tooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get previewClose;

  /// F1 top share icon (system share).
  ///
  /// In en, this message translates to:
  /// **'Share the file'**
  String get previewSendFile;

  /// A shared Library file that was removed since (review 14).
  ///
  /// In en, this message translates to:
  /// **'File removed'**
  String get chatFileRemoved;

  /// Mic button label, and the hint after a tap.
  ///
  /// In en, this message translates to:
  /// **'Hold to record a voice note'**
  String get chatRecord;

  /// While recording.
  ///
  /// In en, this message translates to:
  /// **'Slide away to cancel'**
  String get chatSlideToCancel;

  /// While recording, slid away.
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get chatReleaseToCancel;

  /// Microphone refused.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone in your phone\'s settings to record.'**
  String get chatMicDenied;

  /// Recording under a second.
  ///
  /// In en, this message translates to:
  /// **'Hold a little longer to record.'**
  String get chatVoiceTooShort;

  /// Voice note button.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get chatPlay;

  /// Voice note button.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get chatPause;

  /// Feed divider before posts from outside the home market.
  ///
  /// In en, this message translates to:
  /// **'Beyond {market}'**
  String feedBeyond(String market);

  /// Empty feed.
  ///
  /// In en, this message translates to:
  /// **'No posts yet. Share what happened at work today.'**
  String get feedEmpty;

  /// H5.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your Feed'**
  String get feedCouldntLoad;

  /// H5 body.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again. Nothing was lost.'**
  String get feedCouldntLoadBody;

  /// H6 banner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing what you already loaded.'**
  String get feedOffline;

  /// Create sheet and composer title.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get feedNewPost;

  /// Card action.
  ///
  /// In en, this message translates to:
  /// **'Useful'**
  String get postUseful;

  /// Card action.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get postReply;

  /// Proof line, one name. Arabic: one neutral form (review 16).
  ///
  /// In en, this message translates to:
  /// **'{a} found this useful'**
  String postUsefulOne(String a);

  /// Proof line, two names.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b} found this useful'**
  String postUsefulTwo(String a, String b);

  /// P2 label.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get postEdited;

  /// Tooltip for the card's ••• menu.
  ///
  /// In en, this message translates to:
  /// **'Post options'**
  String get postMenu;

  /// H8.
  ///
  /// In en, this message translates to:
  /// **'Mute {name}'**
  String postMute(String name);

  /// Toast after Mute.
  ///
  /// In en, this message translates to:
  /// **'Muted {name}'**
  String postMuted(String name);

  /// Toast action.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get postUndo;

  /// H8b.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get postEdit;

  /// H8b.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get postDelete;

  /// H11.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get postDeleteTitle;

  /// H11.
  ///
  /// In en, this message translates to:
  /// **'It\'s removed from the Feed, your profile and the project\'s page.'**
  String get postDeleteBody;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Post deleted.'**
  String get postDeleted;

  /// H10 title.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postTitle;

  /// H10 section.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get postReplies;

  /// H10 empty replies.
  ///
  /// In en, this message translates to:
  /// **'No replies yet.'**
  String get postNoReplies;

  /// Composer hint when replying.
  ///
  /// In en, this message translates to:
  /// **'Write a reply'**
  String get postWriteReply;

  /// H17.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String postReplyingTo(String name);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get postCancelReply;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get postSendReply;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Comment options'**
  String get postReplyMenu;

  /// H13.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get postDeleteReply;

  /// H14.
  ///
  /// In en, this message translates to:
  /// **'Delete comment?'**
  String get postDeleteReplyTitle;

  /// H14.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from this post for everyone.'**
  String get postDeleteReplyBody;

  /// P6 title.
  ///
  /// In en, this message translates to:
  /// **'This post isn\'t available'**
  String get postUnavailable;

  /// P6 body.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted, or you may not have access to it.'**
  String get postUnavailableBody;

  /// P6 button.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get postBackHome;

  /// Language name (each in its own script).
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// Language name.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get langArabic;

  /// C10 empty.
  ///
  /// In en, this message translates to:
  /// **'Add a project on your profile first'**
  String get tagEmpty;

  /// C10: remove the tag.
  ///
  /// In en, this message translates to:
  /// **'No project'**
  String get tagNone;

  /// Project sheet section.
  ///
  /// In en, this message translates to:
  /// **'POSTS'**
  String get projectPosts;

  /// Project sheet, no posts.
  ///
  /// In en, this message translates to:
  /// **'No posts tagged with this project yet.'**
  String get projectPostsEmpty;

  /// H1b summary, first part (orange).
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 thing needs you} other{{n} things need you}}'**
  String homeDayNeedsYou(int n);

  /// H1b section.
  ///
  /// In en, this message translates to:
  /// **'NEEDS YOU'**
  String get homeNeedsYou;

  /// H1b: more than 3 needs; opens Activity.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// Home → Spaces: join a Space with the code an engineer gave you (review 50 F28).
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get homeJoinWithCode;

  /// Home top bar search tooltip.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get homeSearch;

  /// Profile top bar Spaces icon tooltip.
  ///
  /// In en, this message translates to:
  /// **'My Spaces'**
  String get homeMySpaces;

  /// Needs-you card.
  ///
  /// In en, this message translates to:
  /// **'{name} gave you a work item: {title}'**
  String needsForYou(String name, String title);

  /// Needs-you card, raised by you.
  ///
  /// In en, this message translates to:
  /// **'A work item for you: {title}'**
  String needsForYouSelf(String title);

  /// Needs-you card.
  ///
  /// In en, this message translates to:
  /// **'{name} signed a work item as done: {title}'**
  String needsYouCheck(String name, String title);

  /// Needs-you card, no name.
  ///
  /// In en, this message translates to:
  /// **'Signed as done. You check it: {title}'**
  String needsYouCheckSelf(String title);

  /// Needs-you card.
  ///
  /// In en, this message translates to:
  /// **'{name} sent a work item back: {title}'**
  String needsSentBack(String name, String title);

  /// Needs-you card, no name.
  ///
  /// In en, this message translates to:
  /// **'A work item came back to you: {title}'**
  String needsSentBackSelf(String title);

  /// Needs-you card.
  ///
  /// In en, this message translates to:
  /// **'The owner left. Reassign it: {title}'**
  String needsOwnerLeft(String title);

  /// Needs-you card.
  ///
  /// In en, this message translates to:
  /// **'{name} asked to join {space}'**
  String needsJoin(String name, String space);

  /// Needs-you card line.
  ///
  /// In en, this message translates to:
  /// **'due {date}'**
  String needsDue(String date);

  /// H1b row: a work item event.
  ///
  /// In en, this message translates to:
  /// **'{event, select, done{{name} signed {ref} as done} checked{{name} checked {ref}} sent_back{{name} sent {ref} back} comment{{name} added an update · {ref}} reassigned{{name} reassigned {ref}} other{{name} raised {ref}}}: {title}'**
  String todayItem(String event, String name, String ref, String title);

  /// H1b row: a Library file.
  ///
  /// In en, this message translates to:
  /// **'{name} added {file}'**
  String todayFile(String name, String file);

  /// H1b row: a chat message.
  ///
  /// In en, this message translates to:
  /// **'{name}: {text}'**
  String todayChat(String name, String text);

  /// H1b row: a chat message without text.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, photo{{name} sent a photo} voice{{name} sent a voice note} file{{name} sent a file} other{{name} posted in chat}}'**
  String todayChatKind(String kind, String name);

  /// When the name is unknown.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get activitySomeone;

  /// A1 group.
  ///
  /// In en, this message translates to:
  /// **'Your network'**
  String get activityGroupNetwork;

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'{name} asked to join'**
  String activityJoinRequest(String name);

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'You\'re in {space}'**
  String activityJoinConfirmed(String space);

  /// A1 row line.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by {name}'**
  String activityConfirmedBy(String name);

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'{name} confirmed your role'**
  String activityRoleConfirmed(String name);

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'{name} started following you'**
  String activityFollow(String name);

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'{name} replied to your post'**
  String activityReplyPost(String name);

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'{name} replied to you'**
  String activityReplyReply(String name);

  /// A1 row: one name you follow. Arabic: one neutral form (review 16 §5).
  ///
  /// In en, this message translates to:
  /// **'{a} found your post useful'**
  String activityUseful1(String a);

  /// A1 row: two names you follow.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b} found your post useful'**
  String activityUseful2(String a, String b);

  /// A1 row: no names you follow. No count.
  ///
  /// In en, this message translates to:
  /// **'Your post was found useful'**
  String get activityUseful0;

  /// A1 v3 row: the owner signed a work item as done.
  ///
  /// In en, this message translates to:
  /// **'{name} signed as done: {title}'**
  String activityItemDone(String name, String title);

  /// A1 v3 row: the author checked a work item.
  ///
  /// In en, this message translates to:
  /// **'{name} checked: {title}'**
  String activityItemChecked(String name, String title);

  /// A1 v3 row: a work item was sent back to you.
  ///
  /// In en, this message translates to:
  /// **'{name} sent back: {title}'**
  String activityItemSentBack(String name, String title);

  /// A1 v3 row: someone added an update to a work item (the daybook's word, F28).
  ///
  /// In en, this message translates to:
  /// **'{name} added an update: {title}'**
  String activityItemUpdate(String name, String title);

  /// A1 v3 row: someone confirmed your role on a project.
  ///
  /// In en, this message translates to:
  /// **'{name} confirmed your role on {project}'**
  String activityRoleConfirmedOn(String name, String project);

  /// A1 v3 row: a reply to your post, with the start of the reply.
  ///
  /// In en, this message translates to:
  /// **'{name} replied to your post: {text}'**
  String activityReplyPostText(String name, String text);

  /// A1 v3 row: a reply to your reply, with the start of it.
  ///
  /// In en, this message translates to:
  /// **'{name} replied to you: {text}'**
  String activityReplyReplyText(String name, String text);

  /// A1 v3 row, the small grey line: it happened on your post.
  ///
  /// In en, this message translates to:
  /// **'Your post'**
  String get activityWherePost;

  /// A1 v3 row, the small grey line: it happened on your profile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get activityWhereProfile;

  /// A2 title.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you right now.'**
  String get activityEmptyTitle;

  /// A2 line.
  ///
  /// In en, this message translates to:
  /// **'When someone needs an answer from you, it waits here. This is what will show up.'**
  String get activityEmptyBody;

  /// A2 ledger.
  ///
  /// In en, this message translates to:
  /// **'WORK ITEMS'**
  String get ledgerWork;

  /// A2 ledger.
  ///
  /// In en, this message translates to:
  /// **'Someone gives you a work item, or one you raised is done.'**
  String get ledgerWorkLine;

  /// A2 ledger.
  ///
  /// In en, this message translates to:
  /// **'SPACE REQUESTS'**
  String get ledgerRequests;

  /// A2 ledger.
  ///
  /// In en, this message translates to:
  /// **'Someone asks to join a Space you run.'**
  String get ledgerRequestsLine;

  /// A2 ledger.
  ///
  /// In en, this message translates to:
  /// **'YOUR POSTS'**
  String get ledgerPosts;

  /// A2 ledger.
  ///
  /// In en, this message translates to:
  /// **'Someone replies to your post.'**
  String get ledgerPostsLine;

  /// A2 ledger.
  ///
  /// In en, this message translates to:
  /// **'YOUR NETWORK'**
  String get ledgerNetwork;

  /// A2 ledger.
  ///
  /// In en, this message translates to:
  /// **'Someone follows you.'**
  String get ledgerNetworkLine;

  /// A2 ledger.
  ///
  /// In en, this message translates to:
  /// **'WHILE YOU WAIT'**
  String get ledgerWait;

  /// A2 link.
  ///
  /// In en, this message translates to:
  /// **'Add a project you worked on'**
  String get ledgerAddProject;

  /// Settings row and S3 title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// S3 section.
  ///
  /// In en, this message translates to:
  /// **'PEOPLE'**
  String get notifPeople;

  /// S3 switch.
  ///
  /// In en, this message translates to:
  /// **'New followers'**
  String get notifFollowers;

  /// S3 section.
  ///
  /// In en, this message translates to:
  /// **'YOUR POSTS'**
  String get notifPosts;

  /// S3 switch.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get notifReplies;

  /// S3 section.
  ///
  /// In en, this message translates to:
  /// **'MESSAGES'**
  String get notifMessages;

  /// S3 switch, off by default.
  ///
  /// In en, this message translates to:
  /// **'Show message text on lock screen'**
  String get notifLockText;

  /// S3 section.
  ///
  /// In en, this message translates to:
  /// **'SPACES'**
  String get notifSpaces;

  /// S3 row; opens My Spaces. The arrow points forward in each direction.
  ///
  /// In en, this message translates to:
  /// **'Set for each Space in Space info → Notifications'**
  String get notifSpacesLine;

  /// S3 footer (founder decision).
  ///
  /// In en, this message translates to:
  /// **'Notifications never name a project, a Space or a work item.'**
  String get notifFooter;

  /// S4 banner.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are off'**
  String get pushOffTitle;

  /// S4 banner, without "Email alerts still work" (no email alerts in the MVP).
  ///
  /// In en, this message translates to:
  /// **'You will miss work items and messages. Turn them on in your phone settings.'**
  String get pushOffBody;

  /// S4 button.
  ///
  /// In en, this message translates to:
  /// **'Open phone settings'**
  String get pushOpenSettings;

  /// F9: the quiet line on Home and in Settings → Notifications when the phone gave no push token.
  ///
  /// In en, this message translates to:
  /// **'Notifications aren\'t reaching this phone'**
  String get pushNotReaching;

  /// F9: the quiet line's action.
  ///
  /// In en, this message translates to:
  /// **'Fix it'**
  String get pushFixIt;

  /// F9: the steps sheet on Xiaomi, Redmi and POCO phones.
  ///
  /// In en, this message translates to:
  /// **'Let notifications reach this phone'**
  String get pushFixTitle;

  /// F9 step 1 (the phone's own word: Autostart).
  ///
  /// In en, this message translates to:
  /// **'Autostart: on for BuildVibes.'**
  String get pushFixAutostart;

  /// F9 step 2 (the phone's own words).
  ///
  /// In en, this message translates to:
  /// **'Battery saver: \"No restrictions\" for BuildVibes.'**
  String get pushFixBattery;

  /// F9 step 3.
  ///
  /// In en, this message translates to:
  /// **'The same battery setting for Google Play services.'**
  String get pushFixPlayServices;

  /// F9 step 4.
  ///
  /// In en, this message translates to:
  /// **'Then restart the phone.'**
  String get pushFixRestart;

  /// F9: opens the phone's page for BuildVibes.
  ///
  /// In en, this message translates to:
  /// **'Open BuildVibes settings'**
  String get pushFixOpen;

  /// F11: the chip over the Home feed when new posts came in while reading further down.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get feedNew;

  /// F11: the chip over the daybook when new entries came in while reading older days.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get daybookNew;

  /// R1 title. kind: post, reply, message, profile.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, post{Report this post} reply{Report this reply} message{Report this message} dm_message{Report this message} other{Report this account}}'**
  String reportTitle(String kind);

  /// R1 line.
  ///
  /// In en, this message translates to:
  /// **'The person won\'t be told who reported. Choose what fits best.'**
  String get reportSubtitle;

  /// R1 reason.
  ///
  /// In en, this message translates to:
  /// **'Spam or scam'**
  String get reasonSpam;

  /// R1 reason line.
  ///
  /// In en, this message translates to:
  /// **'Fake offers, unwanted promotion'**
  String get reasonSpamHelp;

  /// R1 reason.
  ///
  /// In en, this message translates to:
  /// **'Harassment or abuse'**
  String get reasonHarassment;

  /// R1 reason line.
  ///
  /// In en, this message translates to:
  /// **'Insults, threats, targeting someone'**
  String get reasonHarassmentHelp;

  /// R1 reason.
  ///
  /// In en, this message translates to:
  /// **'Wrong or misleading'**
  String get reasonMisleading;

  /// R1 reason line.
  ///
  /// In en, this message translates to:
  /// **'Claims that are false'**
  String get reasonMisleadingHelp;

  /// R1 reason.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t real'**
  String get reasonFake;

  /// R1 reason line.
  ///
  /// In en, this message translates to:
  /// **'A fake person, company or project'**
  String get reasonFakeHelp;

  /// R1 reason.
  ///
  /// In en, this message translates to:
  /// **'Shares private information'**
  String get reasonPrivate;

  /// R1 reason line.
  ///
  /// In en, this message translates to:
  /// **'Documents, plans or details not meant to be public'**
  String get reasonPrivateHelp;

  /// R1 reason.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reasonOther;

  /// R1 reason line.
  ///
  /// In en, this message translates to:
  /// **'Tell us in a few words'**
  String get reasonOtherHelp;

  /// Something else: the note sheet title.
  ///
  /// In en, this message translates to:
  /// **'What\'s wrong?'**
  String get reportNoteTitle;

  /// Something else: the field hint.
  ///
  /// In en, this message translates to:
  /// **'A few words'**
  String get reportNoteHint;

  /// Something else: send.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSend;

  /// R2 title.
  ///
  /// In en, this message translates to:
  /// **'Report sent'**
  String get reportSentTitle;

  /// R2 line.
  ///
  /// In en, this message translates to:
  /// **'We\'ll review it and may remove anything that breaks the rules. The person isn\'t told who reported.'**
  String get reportSentBody;

  /// R2 and R5 button.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reportDone;

  /// R2 button.
  ///
  /// In en, this message translates to:
  /// **'Block this account'**
  String get reportBlock;

  /// Post menu row (someone else's post).
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get postReport;

  /// Reply menu row (someone else's reply).
  ///
  /// In en, this message translates to:
  /// **'Report reply'**
  String get replyReport;

  /// S8c: the message sheet row.
  ///
  /// In en, this message translates to:
  /// **'Report message'**
  String get chatReport;

  /// Person profile menu row.
  ///
  /// In en, this message translates to:
  /// **'Report account'**
  String get profileReport;

  /// Toast after blocking, with Undo.
  ///
  /// In en, this message translates to:
  /// **'{name} blocked'**
  String blockDone(String name);

  /// S7 title and the Settings row.
  ///
  /// In en, this message translates to:
  /// **'Blocked accounts'**
  String get blockedTitle;

  /// S7 section: your own count.
  ///
  /// In en, this message translates to:
  /// **'{n} BLOCKED'**
  String blockedCount(int n);

  /// S7 empty.
  ///
  /// In en, this message translates to:
  /// **'Nobody blocked'**
  String get blockedNone;

  /// S7 row action.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// Toast after unblocking.
  ///
  /// In en, this message translates to:
  /// **'{name} unblocked'**
  String unblocked(String name);

  /// S7 footnote. Nothing about messages: the MVP has none.
  ///
  /// In en, this message translates to:
  /// **'Blocked accounts can\'t follow you or see your posts. They are not told.'**
  String get blockedNote;

  /// R3 app bar.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, post{Removed post} reply{Removed reply} other{Removed message}}'**
  String removedTitle(String kind);

  /// R3 heading.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, post{We removed your post} reply{We removed your reply} other{We removed your message}}'**
  String removedHeading(String kind);

  /// R3 line.
  ///
  /// In en, this message translates to:
  /// **'It was reported for {reason}, and our review agreed. Only you can see this notice.'**
  String removedBody(String reason);

  /// R3: the reason inside the sentence.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, spam{spam or a scam} harassment{harassment or abuse} misleading{being wrong or misleading} fake{not being real} private_info{sharing private information} other{something else}}'**
  String reasonPhrase(String reason);

  /// R3 card label.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, post{Your post} reply{Your reply} other{Your message}} · {date}'**
  String removedYour(String kind, String date);

  /// R3 line (review 23: one reviewer in the pilot).
  ///
  /// In en, this message translates to:
  /// **'You have 14 days to appeal. We\'ll look at it again.'**
  String get removedAppealNote;

  /// R3 button.
  ///
  /// In en, this message translates to:
  /// **'Appeal this decision'**
  String get removedAppeal;

  /// R3 when the appeal is open.
  ///
  /// In en, this message translates to:
  /// **'You appealed on {date}. We\'ll tell you the result in Activity.'**
  String removedAppealOpen(String date);

  /// R3 after 14 days.
  ///
  /// In en, this message translates to:
  /// **'The 14 days to appeal have passed.'**
  String get removedClosed;

  /// R3 after an upheld appeal.
  ///
  /// In en, this message translates to:
  /// **'We looked at it again: the removal stands.'**
  String get removedUpheld;

  /// R3 after a reversed appeal.
  ///
  /// In en, this message translates to:
  /// **'We looked at it again and brought it back.'**
  String get removedReversed;

  /// R3 when the notice is not yours or is gone.
  ///
  /// In en, this message translates to:
  /// **'This notice isn\'t available.'**
  String get removedGone;

  /// R4 and R5 app bar.
  ///
  /// In en, this message translates to:
  /// **'Appeal'**
  String get appealTitle;

  /// R4 heading.
  ///
  /// In en, this message translates to:
  /// **'Tell us why this was a mistake'**
  String get appealHeading;

  /// R4 line.
  ///
  /// In en, this message translates to:
  /// **'Add anything that helps the reviewer. Don\'t include other people\'s private details.'**
  String get appealHelp;

  /// R4 field label.
  ///
  /// In en, this message translates to:
  /// **'Your explanation'**
  String get appealLabel;

  /// R4 field help.
  ///
  /// In en, this message translates to:
  /// **'Up to 500 characters'**
  String get appealLimit;

  /// R4 button.
  ///
  /// In en, this message translates to:
  /// **'Send appeal'**
  String get appealSend;

  /// R5 title.
  ///
  /// In en, this message translates to:
  /// **'Appeal received'**
  String get appealReceived;

  /// R5 line (review 23 wording).
  ///
  /// In en, this message translates to:
  /// **'We\'ll look at it again. We\'ll tell you the result in Activity, usually within 3 days.'**
  String get appealReceivedBody;

  /// A1 row: a removal.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, post{Your post was removed} reply{Your reply was removed} other{Your message was removed}}'**
  String activityRemoved(String kind);

  /// A1 row: an appeal result.
  ///
  /// In en, this message translates to:
  /// **'{result, select, reversed{Your appeal: it\'s back} other{Your appeal: the removal stands}}'**
  String activityAppealResult(String result);

  /// S1 header link.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get settingsViewProfile;

  /// S1 words row label; S8 section.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsLanguageLabel;

  /// S1 row, S2 title.
  ///
  /// In en, this message translates to:
  /// **'Account and security'**
  String get accountSecurity;

  /// S1 row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Download my data, delete account'**
  String get accountSecuritySub;

  /// S1 row, S5 title.
  ///
  /// In en, this message translates to:
  /// **'Privacy and safety'**
  String get privacySafety;

  /// S1 row, S8 title.
  ///
  /// In en, this message translates to:
  /// **'Language and region'**
  String get languageRegion;

  /// S1 row: writes to the pack support email.
  ///
  /// In en, this message translates to:
  /// **'Help and feedback'**
  String get helpFeedback;

  /// S1 row.
  ///
  /// In en, this message translates to:
  /// **'About BuildVibes and legal'**
  String get aboutLegal;

  /// S1 row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Terms, privacy policy'**
  String get aboutLegalSub;

  /// About sheet: which build is on this phone (review 53 Part D). The commit is the short git commit, or 'dev'.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · build {build} · {commit}'**
  String aboutBuild(String version, String build, String commit);

  /// About sheet row.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get legalTerms;

  /// About sheet row.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get legalPrivacy;

  /// About sheet when the pack has no links yet.
  ///
  /// In en, this message translates to:
  /// **'These pages are on their way. Write to us with any question.'**
  String get legalSoon;

  /// A link or email app failed to open.
  ///
  /// In en, this message translates to:
  /// **'This couldn\'t be opened on this phone.'**
  String get linkFailed;

  /// S15 dialog.
  ///
  /// In en, this message translates to:
  /// **'Sign out of BuildVibes?'**
  String get signOutTitle;

  /// S15 dialog: there are no passwords.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need a code sent to your email to sign in again.'**
  String get signOutBody;

  /// S2 section.
  ///
  /// In en, this message translates to:
  /// **'YOUR DATA'**
  String get accountYourData;

  /// S2 row, S10 title.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get downloadData;

  /// S2 row subtitle.
  ///
  /// In en, this message translates to:
  /// **'We email you a copy within 7 days'**
  String get downloadDataSub;

  /// S2 section.
  ///
  /// In en, this message translates to:
  /// **'DANGER ZONE'**
  String get dangerZone;

  /// S2 row, S12 title.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// S2 row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Removed after 30 days. You can restore it until then.'**
  String get deleteAccountSub;

  /// S5 section.
  ///
  /// In en, this message translates to:
  /// **'SAFETY'**
  String get privacySafetySection;

  /// S5 note.
  ///
  /// In en, this message translates to:
  /// **'Work items, chat and the Library stay inside each Space. Only its members see them.'**
  String get privacyNote;

  /// S8 English card.
  ///
  /// In en, this message translates to:
  /// **'Left to right'**
  String get languageEnglishDir;

  /// S8 Arabic card.
  ///
  /// In en, this message translates to:
  /// **'Right to left'**
  String get languageArabicDir;

  /// S8 section.
  ///
  /// In en, this message translates to:
  /// **'REGION'**
  String get regionSection;

  /// S8 row and sheet title.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get regionCountry;

  /// S8 read-only row, from the pack.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get regionWeekStart;

  /// S8 note.
  ///
  /// In en, this message translates to:
  /// **'Arabic switches the whole app to right-to-left. Your posts keep the language they were written in.'**
  String get regionNote;

  /// S10 heading.
  ///
  /// In en, this message translates to:
  /// **'Get a copy of your data'**
  String get downloadHeading;

  /// S10 body.
  ///
  /// In en, this message translates to:
  /// **'We email you a file with everything below, within 7 days.'**
  String get downloadBody;

  /// S10 section.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS INCLUDED'**
  String get downloadIncluded;

  /// S10 row.
  ///
  /// In en, this message translates to:
  /// **'Profile and settings'**
  String get downloadProfile;

  /// S10 row.
  ///
  /// In en, this message translates to:
  /// **'Posts and replies'**
  String get downloadPosts;

  /// S10 row.
  ///
  /// In en, this message translates to:
  /// **'Messages you sent'**
  String get downloadMessages;

  /// S10 row.
  ///
  /// In en, this message translates to:
  /// **'Your work items and notes'**
  String get downloadWork;

  /// S10 button.
  ///
  /// In en, this message translates to:
  /// **'Request my data'**
  String get downloadRequest;

  /// S10 under the button.
  ///
  /// In en, this message translates to:
  /// **'We send it to {email}.'**
  String downloadFoot(String email);

  /// S11 title.
  ///
  /// In en, this message translates to:
  /// **'Request received'**
  String get requestReceived;

  /// S11 body.
  ///
  /// In en, this message translates to:
  /// **'We will email {email} within 7 days.'**
  String requestReceivedBody(String email);

  /// S12 heading.
  ///
  /// In en, this message translates to:
  /// **'Before you delete'**
  String get deleteHeading;

  /// S12 body.
  ///
  /// In en, this message translates to:
  /// **'Your profile is hidden right away. You have 30 days to change your mind.'**
  String get deleteBody;

  /// S12 section.
  ///
  /// In en, this message translates to:
  /// **'WHAT HAPPENS'**
  String get deleteWhat;

  /// S12 row.
  ///
  /// In en, this message translates to:
  /// **'Profile, posts and replies are removed'**
  String get deleteProfile;

  /// S12 row.
  ///
  /// In en, this message translates to:
  /// **'Work and files in a Space stay there'**
  String get deleteSpaceWork;

  /// S12 row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shown as a former member'**
  String get deleteSpaceWorkSub;

  /// S12 row.
  ///
  /// In en, this message translates to:
  /// **'Messages you sent stay in the Space\'s chat'**
  String get deleteMessages;

  /// S12 button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get deleteContinue;

  /// S12 button.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get deleteKeep;

  /// S12b heading.
  ///
  /// In en, this message translates to:
  /// **'Hand over Space admin first'**
  String get transferFirst;

  /// S12b body.
  ///
  /// In en, this message translates to:
  /// **'You are the only admin of a Space that has other members. Make someone else its admin before you delete your account.'**
  String get transferFirstBody;

  /// S12b section.
  ///
  /// In en, this message translates to:
  /// **'ONLY ADMIN'**
  String get transferOnlyAdmin;

  /// S13 heading.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get confirmHeading;

  /// S13: an email code, never a password.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent to {email}.'**
  String confirmBody(String email);

  /// S13 button.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteMyAccount;

  /// S13 under the button.
  ///
  /// In en, this message translates to:
  /// **'Your account will be removed on {date}. Sign in before then to restore it.'**
  String deleteFoot(String date);

  /// S14 title.
  ///
  /// In en, this message translates to:
  /// **'Deletion scheduled'**
  String get scheduledTitle;

  /// S14 body.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted on {date}. Your profile is hidden. Restore it any time before then.'**
  String scheduledBody(String date);

  /// S14 button.
  ///
  /// In en, this message translates to:
  /// **'Restore my account'**
  String get restoreAccount;

  /// A Space member whose account is hidden or deleted.
  ///
  /// In en, this message translates to:
  /// **'Former member'**
  String get formerMember;

  /// Slip header for your own post; the avatar keeps your initials.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get daybookYou;

  /// Slip meta: you own the work item.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get daybookForYou;

  /// Slip meta: who owns the work item.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String daybookForPerson(String name);

  /// Slip meta: owner, then due ("For Omar Haddad, by Thu 15 Oct").
  ///
  /// In en, this message translates to:
  /// **'{who} · {due}'**
  String daybookMeta(String who, String due);

  /// Due on a day ("by Thu 15 Oct").
  ///
  /// In en, this message translates to:
  /// **'by {date}'**
  String daybookDueDate(String date);

  /// Due today, no time. Arabic never says 'before today' (review 44 C2).
  ///
  /// In en, this message translates to:
  /// **'by today'**
  String get daybookDueToday;

  /// Due tomorrow, no time.
  ///
  /// In en, this message translates to:
  /// **'by tomorrow'**
  String get daybookDueTomorrow;

  /// Due on a day at a time.
  ///
  /// In en, this message translates to:
  /// **'by {date} {time}'**
  String daybookDueDateAt(String date, String time);

  /// Due today at a time (AR frame 2547:35262).
  ///
  /// In en, this message translates to:
  /// **'by today {time}'**
  String daybookDueTodayAt(String time);

  /// Due tomorrow at a time.
  ///
  /// In en, this message translates to:
  /// **'by tomorrow {time}'**
  String daybookDueTomorrowAt(String time);

  /// A late item's due day (L1).
  ///
  /// In en, this message translates to:
  /// **'was due {date}'**
  String daybookWasDue(String date);

  /// A late item's due day and time.
  ///
  /// In en, this message translates to:
  /// **'was due {date} {time}'**
  String daybookWasDueAt(String date, String time);

  /// A timed item that went late today.
  ///
  /// In en, this message translates to:
  /// **'was due today {time}'**
  String daybookWasDueTodayAt(String time);

  /// The one-line strip under the masthead (review 50 F68), followed by ' · ' and the count of your own items still to do, today or from earlier days; also the title of the sheet it opens (review 73 A1), which lists them oldest first.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get daybookToDo;

  /// Slip chip: checklist points on a work item.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 point} other{{n} points}}'**
  String daybookPoints(int n);

  /// A day word in the edited line.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get daybookToday;

  /// A day word in the edited line.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get daybookTomorrow;

  /// Ink stamp (glossary Done).
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get daybookStampDone;

  /// Ink stamp (glossary Checked).
  ///
  /// In en, this message translates to:
  /// **'CHECKED'**
  String get daybookStampChecked;

  /// Ink stamp after Send back.
  ///
  /// In en, this message translates to:
  /// **'SENT BACK'**
  String get daybookStampSentBack;

  /// Ink stamp on a cancelled post.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get daybookStampCancelled;

  /// Post bar notepad (glossary).
  ///
  /// In en, this message translates to:
  /// **'Work item'**
  String get daybookWorkItem;

  /// Viewer post bar, after the pass chip (V1).
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get daybookReadOnly;

  /// Month drop-down legend: a day with posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get daybookMonthPosts;

  /// Month drop-down legend: a day with something due.
  ///
  /// In en, this message translates to:
  /// **'Something due'**
  String get daybookMonthDue;

  /// Day one card title (DY3).
  ///
  /// In en, this message translates to:
  /// **'The first page of your daybook'**
  String get daybookFirstTitle;

  /// Day one card body.
  ///
  /// In en, this message translates to:
  /// **'Everything your team posts will hang here, day by day.'**
  String get daybookFirstBody;

  /// Day one card, main action.
  ///
  /// In en, this message translates to:
  /// **'Post the first work item'**
  String get daybookFirstPost;

  /// Day one card: opens the invite screen.
  ///
  /// In en, this message translates to:
  /// **'Invite your team'**
  String get daybookFirstInvite;

  /// Second line of the large stamp on a proof photo: the signer's short name and the time ("OMAR H · 09:40").
  ///
  /// In en, this message translates to:
  /// **'{name} · {time}'**
  String daybookStampBy(String name, String time);

  /// The part of the day after a 12-hour time. period is morning (before noon), noon (12 to 3 pm), afternoon (3 to 6 pm) or evening. English: am or pm. Arabic: the words, on a small second line in the daybook's time column.
  ///
  /// In en, this message translates to:
  /// **'{period, select, morning{am} noon{pm} afternoon{pm} evening{pm} other{pm}}'**
  String timePeriod(String period);

  /// A 12-hour time on one line, everywhere in the app (review 54 A1): the time with its minutes and the part of the day (timePeriod): "2:00 pm", "2:00 ظهرًا". A no-break space between them, so a time never wraps (review 82 S1).
  ///
  /// In en, this message translates to:
  /// **'{time} {period}'**
  String timeClock12(String time, String period);

  /// Hint on a proof waiting for your check.
  ///
  /// In en, this message translates to:
  /// **'Double-tap the photo to check it'**
  String get daybookDoubleTapToCheck;

  /// A Library file on a work item slip: its name and revision ("M-201 Rev C").
  ///
  /// In en, this message translates to:
  /// **'{name} {revision}'**
  String daybookFileChip(String name, String revision);

  /// A post made with no signal: it sends when the signal is back.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get daybookWaitingToSend;

  /// On a card reopened with unsent text: only the author sees it.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get daybookDraft;

  /// Writing card: title placeholder.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get daybookWritingTitle;

  /// Writing card: text placeholder.
  ///
  /// In en, this message translates to:
  /// **'Write what needs doing'**
  String get daybookWritingBody;

  /// Writing More menu: choose who does it.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get daybookAssign;

  /// Writing More menu: where on site.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get daybookLocation;

  /// Writing More menu: when it is due.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get daybookDueDateMenu;

  /// Writing card: a due date with a time ("Sun 18 Oct, 14:00").
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String daybookDueProperty(String date, String time);

  /// Writing toolbar: camera (read out).
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get daybookCamera;

  /// Writing toolbar: attach a photo from the phone (read out).
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get daybookAddPhoto;

  /// Writing toolbar: More (read out).
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get daybookMore;

  /// Writing toolbar: Post (read out).
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get daybookPost;

  /// Writing card: the cover photo's remove button (read out).
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get daybookRemovePhoto;

  /// Give-to picker: search placeholder.
  ///
  /// In en, this message translates to:
  /// **'Give to…'**
  String get daybookGiveToSearch;

  /// Give-to picker: under the current owner.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get daybookOwnerNow;

  /// Writing: the place field placeholder.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get daybookPlaceHint;

  /// Due time picker: keep the date only.
  ///
  /// In en, this message translates to:
  /// **'No time'**
  String get daybookNoTime;

  /// Due time picker: its title. Optional.
  ///
  /// In en, this message translates to:
  /// **'Due by a time?'**
  String get daybookDueTimeHelp;

  /// Writing: the assign picker's search field (the More menu says "Assign"). Review 46.
  ///
  /// In en, this message translates to:
  /// **'Assign to…'**
  String get daybookAssignSearch;

  /// A Draft whose post the server refused (not a missing signal), in red under the card. Tapping reopens writing. Review 46.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Tap to fix'**
  String get daybookCouldNotSend;

  /// Due date picker: takes the due date (and time) off.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get daybookRemoveDue;

  /// The action pill on the owner's open work item slip (camera icon). Glossary.
  ///
  /// In en, this message translates to:
  /// **'Sign as done'**
  String get daybookSignAsDone;

  /// Read out for the post bar's camera: holding it signs your open work item as done with a photo.
  ///
  /// In en, this message translates to:
  /// **'Hold to prove'**
  String get daybookHoldToProve;

  /// Long-press menu on someone's proof (B1).
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get daybookCheck;

  /// Long-press menu on someone's proof, and the send-back card's button (B1, B2). Glossary.
  ///
  /// In en, this message translates to:
  /// **'Send back'**
  String get daybookSendBack;

  /// Long-press menu; also read out for the + a swipe shows (Y1).
  ///
  /// In en, this message translates to:
  /// **'Add update'**
  String get daybookAddUpdate;

  /// Long-press menu on your own work item (X1).
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get daybookEdit;

  /// Long-press menu on your own work item (X1).
  ///
  /// In en, this message translates to:
  /// **'Give to someone else'**
  String get daybookGiveTo;

  /// Long-press menu on your own work item (X1), in red.
  ///
  /// In en, this message translates to:
  /// **'Cancel work item'**
  String get daybookCancelItem;

  /// The send-back card's title (B2), with the owner's first name.
  ///
  /// In en, this message translates to:
  /// **'Send back to {name}'**
  String daybookSendBackTo(String name);

  /// Send-back reason (one choice).
  ///
  /// In en, this message translates to:
  /// **'Photo missing'**
  String get daybookReasonPhotoMissing;

  /// Send-back reason (one choice).
  ///
  /// In en, this message translates to:
  /// **'Not as asked'**
  String get daybookReasonNotAsAsked;

  /// Send-back reason (one choice).
  ///
  /// In en, this message translates to:
  /// **'Not finished'**
  String get daybookReasonNotFinished;

  /// Send-back reason (one choice); it needs a note.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get daybookReasonOther;

  /// Placeholder of a short note: on the send-back card (B2) and with the proof photo (O2).
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get daybookNoteOptional;

  /// Placeholder of the send-back note once "Something else" is chosen: it needs a note.
  ///
  /// In en, this message translates to:
  /// **'Say what is wrong'**
  String get daybookNoteNeeded;

  /// The undo bar after a check (B3). Glossary.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get daybookChecked;

  /// The undo bar after cancelling a work item.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get daybookCancelled;

  /// The undo bar's action: nothing reaches the server.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get daybookUndo;

  /// The one-line field of an update (after a swipe or Add update).
  ///
  /// In en, this message translates to:
  /// **'Write an update'**
  String get daybookUpdateHint;

  /// The round button under the proof photo (O2): signs the work item as done.
  ///
  /// In en, this message translates to:
  /// **'Send as done'**
  String get daybookSendAsDone;

  /// Read out for the + tile next to the proof photo (O2).
  ///
  /// In en, this message translates to:
  /// **'Add another photo'**
  String get daybookAddAnotherPhoto;

  /// The link on the proof screen (F6): sign as done with a note and no photo.
  ///
  /// In en, this message translates to:
  /// **'Without a photo'**
  String get daybookWithoutPhoto;

  /// Placeholder of the note on the proof screen without a photo (F6): the note is required then.
  ///
  /// In en, this message translates to:
  /// **'What was done?'**
  String get daybookWhatWasDone;

  /// The undo bar after Send as done (F7); nothing is sent until it closes. Glossary.
  ///
  /// In en, this message translates to:
  /// **'Signed as done'**
  String get daybookSignedUndo;

  /// Read out for the × on the linked work item at the top of the proof photo: leaves without signing.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get daybookCloseProof;

  /// Read out for the round send button while editing a posted work item.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get daybookSave;

  /// A send-back slip: the reason, then the note (S1).
  ///
  /// In en, this message translates to:
  /// **'{reason}. {note}'**
  String daybookSentBackText(String reason, String note);

  /// A check the server refused (review 47, answer 5).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check'**
  String get daybookCouldNotCheck;

  /// A send-back the server refused.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send back'**
  String get daybookCouldNotSendBack;

  /// A cancel the server refused.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel'**
  String get daybookCouldNotCancel;

  /// Give to someone else, refused.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t give it to someone else'**
  String get daybookCouldNotGiveTo;

  /// An update, refused.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the update'**
  String get daybookCouldNotUpdate;

  /// What was refused and why: "Couldn't check: this item was cancelled".
  ///
  /// In en, this message translates to:
  /// **'{action}: {reason}'**
  String daybookRefusedBecause(String action, String reason);

  /// What was refused, when the server gives no reason.
  ///
  /// In en, this message translates to:
  /// **'{action}.'**
  String daybookRefusedPlain(String action);

  /// Why it was refused.
  ///
  /// In en, this message translates to:
  /// **'this item was cancelled'**
  String get daybookWhyCancelled;

  /// Why it was refused.
  ///
  /// In en, this message translates to:
  /// **'it was already checked'**
  String get daybookWhyChecked;

  /// Why it was refused: someone else changed the item first.
  ///
  /// In en, this message translates to:
  /// **'it changed in the meantime'**
  String get daybookWhyChanged;

  /// Why it was refused.
  ///
  /// In en, this message translates to:
  /// **'it was removed'**
  String get daybookWhyRemoved;

  /// Why it was refused.
  ///
  /// In en, this message translates to:
  /// **'your pass doesn\'t allow it'**
  String get daybookWhyNotAllowed;

  /// Read out for the item name at the top of the proof screen: it lists your other open items (review 47, answer 3).
  ///
  /// In en, this message translates to:
  /// **'Prove another work item'**
  String get daybookSwitchItem;

  /// The x on a refused proof that was reopened.
  ///
  /// In en, this message translates to:
  /// **'Delete this proof?'**
  String get daybookDiscardProofTitle;

  /// Body of the dialog.
  ///
  /// In en, this message translates to:
  /// **'The photos are only on this phone. Deleted, they are gone.'**
  String get daybookDiscardProofBody;

  /// Keep the refused proof on the phone.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get daybookDiscardProofKeep;

  /// Delete the refused proof and its photos.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get daybookDiscardProofDelete;

  /// Read out for the ⋯ in the Space header (MN1).
  ///
  /// In en, this message translates to:
  /// **'Space menu'**
  String get spacesMenu;

  /// Space info group: your own pass and notifications (SI1).
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get spacesInfoYou;

  /// Space info group: the invite code (SI1).
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get spacesInfoInvite;

  /// Space info group: the Space itself (SI1).
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get spacesInfoSpace;

  /// Space info row (SI1).
  ///
  /// In en, this message translates to:
  /// **'Your pass'**
  String get spacesYourPass;

  /// One of the three notification choices in Space info (SI1).
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get spacesNotifyChoiceAll;

  /// One of the three notification choices in Space info (SI1).
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get spacesNotifyChoiceNeedsYou;

  /// Who can invite, in Space info (SI1): Space admins only.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get spacesInviteChoiceAdmins;

  /// Who can invite, in Space info (SI1): admins and Lead passes.
  ///
  /// In en, this message translates to:
  /// **'Leads'**
  String get spacesInviteChoiceLeads;

  /// Who can invite, in Space info (SI1).
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get spacesInviteChoiceEveryone;

  /// Copy the invite code (SI1).
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get spacesCopy;

  /// After Copy in Space info.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied'**
  String get spacesCodeCopied;

  /// Space info row: who runs the Space (SI1).
  ///
  /// In en, this message translates to:
  /// **'Space admin'**
  String get spacesAdminRow;

  /// Space info row: the day work started on site, the daybook's day 1 (review 44, answer 2).
  ///
  /// In en, this message translates to:
  /// **'On site since'**
  String get spacesOnSiteSince;

  /// On site since, when no day is set.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get spacesOnSiteNotSet;

  /// On site since: pick another day.
  ///
  /// In en, this message translates to:
  /// **'Choose another day'**
  String get spacesOnSiteChange;

  /// On site since: clear it. The daybook then shows only the date.
  ///
  /// In en, this message translates to:
  /// **'Remove the day'**
  String get spacesOnSiteRemove;

  /// Under the On site since sheet title.
  ///
  /// In en, this message translates to:
  /// **'Work counts \"day 1 on site\" from this day.'**
  String get spacesOnSiteNote;

  /// Space info row for admins: edit the name and About.
  ///
  /// In en, this message translates to:
  /// **'Name and About'**
  String get spacesEditNameAbout;

  /// Needs you across all Spaces (2544:35068).
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get needsTitle;

  /// Needs you row: a proof waiting for your check.
  ///
  /// In en, this message translates to:
  /// **'Check it'**
  String get needsRowCheck;

  /// Needs you row: a work item given to you.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get needsRowForYou;

  /// Needs you row: your proof was sent back.
  ///
  /// In en, this message translates to:
  /// **'Sent back'**
  String get needsRowSentBack;

  /// Needs you row: the owner left the Space.
  ///
  /// In en, this message translates to:
  /// **'Give it to someone'**
  String get needsRowOwnerLeft;

  /// Needs you row: a join request you can confirm.
  ///
  /// In en, this message translates to:
  /// **'Asks to join'**
  String get needsRowJoin;

  /// Needs you, empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you now.'**
  String get needsNone;

  /// Profile section (R1 v4): work that was checked and closed in a Space.
  ///
  /// In en, this message translates to:
  /// **'Proof of work'**
  String get profileProofOfWork;

  /// Profile section (R1 v4).
  ///
  /// In en, this message translates to:
  /// **'Projects, confirmed by teammates'**
  String get profileProjectsConfirmed;

  /// Stamp on a project a teammate confirmed (R1 v4).
  ///
  /// In en, this message translates to:
  /// **'CONFIRMED'**
  String get proofStampConfirmed;

  /// Stamp on a project not confirmed yet (R1 v4).
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get proofStampWaiting;

  /// Own profile: opens Work you delivered, to show or hide each item.
  ///
  /// In en, this message translates to:
  /// **'Choose what shows'**
  String get proofChooseShown;

  /// A post being written on Home (H2 2555:35426): who writes it and who sees it. Posts are public to every signed-in person.
  ///
  /// In en, this message translates to:
  /// **'You · to everyone'**
  String get postWritingAuthor;

  /// The language picker while writing a post (L6): the language found from its letters, chosen by default.
  ///
  /// In en, this message translates to:
  /// **'Detected: {lang, select, ar{Arabic} other{English}}'**
  String postLangAuto(String lang);

  /// The text field of a post being written on Home (H2).
  ///
  /// In en, this message translates to:
  /// **'What happened at work today?'**
  String get postWritingHint;

  /// The More menu while writing a post: tag a project from your profile.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get postWritingProject;

  /// The More menu while writing a post: its language; opens the language picker (L6).
  ///
  /// In en, this message translates to:
  /// **'Written in {lang, select, ar{Arabic} other{English}}'**
  String postWritingLang(String lang);

  /// Writing a post: a fifth photo was tried (create_post takes four).
  ///
  /// In en, this message translates to:
  /// **'Up to 4 photos.'**
  String get postWritingPhotosMax;

  /// H1b header line, after the date, when nothing needs you.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you'**
  String get homeNothingNeedsYou;

  /// H1b section: every Space once, its latest news.
  ///
  /// In en, this message translates to:
  /// **'YOUR SPACES'**
  String get homeYourSpaces;

  /// Create choice (F1): a public post in the Home feed.
  ///
  /// In en, this message translates to:
  /// **'Post to everyone'**
  String get createPostToEveryone;

  /// Create choice: under Post to everyone.
  ///
  /// In en, this message translates to:
  /// **'In the Home feed, for everyone'**
  String get createPostToEveryoneLine;

  /// Create choice (F1): write a work item in one of your Spaces.
  ///
  /// In en, this message translates to:
  /// **'Work item in a Space'**
  String get createWorkItem;

  /// Create choice: under Work item in a Space.
  ///
  /// In en, this message translates to:
  /// **'Only the Space\'s members see it'**
  String get createWorkItemLine;

  /// Create, second step: the Spaces where you can write work items.
  ///
  /// In en, this message translates to:
  /// **'Which Space?'**
  String get createPickSpace;

  /// Create, Space list: the Space you opened last, listed first.
  ///
  /// In en, this message translates to:
  /// **'Last opened'**
  String get createLastSpace;

  /// Create, Space list: none where you can create work items.
  ///
  /// In en, this message translates to:
  /// **'There\'s no Space yet where you can write work items. Join one with an invite code, or start a new Space.'**
  String get createNoWorkSpaces;

  /// Daybook card: opens the rest of its history in place.
  ///
  /// In en, this message translates to:
  /// **'Show earlier'**
  String get daybookShowEarlier;

  /// Daybook card history: the bold start of a line before its note ("Omar Haddad signed as done:").
  ///
  /// In en, this message translates to:
  /// **'{lead}:'**
  String daybookHistoryLead(String lead);

  /// Daybook card header: the work item's reference after the author.
  ///
  /// In en, this message translates to:
  /// **'· {ref}'**
  String daybookCardRef(String ref);

  /// F20: an Activity row, a push or a Needs you card opened a work item that was deleted or can no longer be seen.
  ///
  /// In en, this message translates to:
  /// **'This was removed'**
  String get daybookRemoved;

  /// F24: the work item quoted in one line on the update and send-back sheets.
  ///
  /// In en, this message translates to:
  /// **'{ref} · {title}'**
  String daybookQuote(String ref, String title);

  /// F24: the round send button of the Add update sheet, read out.
  ///
  /// In en, this message translates to:
  /// **'Send update'**
  String get daybookSendUpdate;

  /// Daybook trace on an earlier day: what happened, then the work item's title.
  ///
  /// In en, this message translates to:
  /// **'{what} · {title}'**
  String daybookTrace(String what, String title);

  /// Daybook day divider for today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get daybookTodayDivider;

  /// Daybook history line or trace: someone signed the work item as done.
  ///
  /// In en, this message translates to:
  /// **'{name} signed as done'**
  String daybookLineSigned(String name);

  /// Daybook history line or trace: you signed the work item as done.
  ///
  /// In en, this message translates to:
  /// **'You signed as done'**
  String get daybookLineYouSigned;

  /// Daybook history line or trace: someone checked the work item.
  ///
  /// In en, this message translates to:
  /// **'{name} checked it'**
  String daybookLineChecked(String name);

  /// Daybook history line or trace: you checked the work item.
  ///
  /// In en, this message translates to:
  /// **'You checked it'**
  String get daybookLineYouChecked;

  /// Daybook history line or trace: someone sent the proof back.
  ///
  /// In en, this message translates to:
  /// **'{name} sent it back'**
  String daybookLineSentBack(String name);

  /// Daybook history line or trace: you sent the proof back.
  ///
  /// In en, this message translates to:
  /// **'You sent it back'**
  String get daybookLineYouSentBack;

  /// Daybook trace: someone added an update to the work item.
  ///
  /// In en, this message translates to:
  /// **'{name} added an update'**
  String daybookLineUpdate(String name);

  /// Daybook trace: you added an update to the work item.
  ///
  /// In en, this message translates to:
  /// **'You added an update'**
  String get daybookLineYouUpdate;

  /// Daybook history line: your own update, before its words.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get daybookLineYouComment;

  /// Daybook history line: someone's update, before its words ("Omar Haddad: Sleeves arrived."). Arabic in the ledger form, the name then the action (review 54 A3).
  ///
  /// In en, this message translates to:
  /// **'{name}'**
  String daybookLineComment(String name);

  /// Daybook history line or trace: someone gave the work item to another owner.
  ///
  /// In en, this message translates to:
  /// **'{name} gave it to {to} instead of {from}'**
  String daybookLineGave(String name, String to, String from);

  /// Daybook history line or trace: you gave the work item to another owner.
  ///
  /// In en, this message translates to:
  /// **'You gave it to {to} instead of {from}'**
  String daybookLineYouGave(String to, String from);

  /// Daybook history line or trace: someone edited the work item.
  ///
  /// In en, this message translates to:
  /// **'{name} edited it'**
  String daybookLineEdited(String name);

  /// Daybook history line or trace: you edited the work item.
  ///
  /// In en, this message translates to:
  /// **'You edited it'**
  String get daybookLineYouEdited;

  /// Daybook history line or trace: someone moved the due date.
  ///
  /// In en, this message translates to:
  /// **'{name} moved the due date from {from} to {to}'**
  String daybookLineMovedDue(String name, String from, String to);

  /// Daybook history line or trace: you moved the due date.
  ///
  /// In en, this message translates to:
  /// **'You moved the due date from {from} to {to}'**
  String daybookLineYouMovedDue(String from, String to);

  /// Daybook history line or trace: someone removed the due date.
  ///
  /// In en, this message translates to:
  /// **'{name} took the due date off'**
  String daybookLineRemovedDue(String name);

  /// Daybook history line or trace: you removed the due date.
  ///
  /// In en, this message translates to:
  /// **'You took the due date off'**
  String get daybookLineYouRemovedDue;

  /// Daybook history line or trace: someone cancelled the work item.
  ///
  /// In en, this message translates to:
  /// **'{name} cancelled it'**
  String daybookLineCancelled(String name);

  /// Daybook history line or trace: you cancelled the work item.
  ///
  /// In en, this message translates to:
  /// **'You cancelled it'**
  String get daybookLineYouCancelled;

  /// Daybook trace: someone posted the work item that day.
  ///
  /// In en, this message translates to:
  /// **'{name} posted it'**
  String daybookLinePosted(String name);

  /// Daybook trace: you posted the work item that day.
  ///
  /// In en, this message translates to:
  /// **'You posted it'**
  String get daybookLineYouPosted;

  /// Daybook card header after the author: the post is a checklist.
  ///
  /// In en, this message translates to:
  /// **'· checklist'**
  String get daybookKindChecklistWord;

  /// Daybook card header after the author: the post is a scheduled activity (K2 v13).
  ///
  /// In en, this message translates to:
  /// **'· scheduled'**
  String get daybookKindActivityWord;

  /// A file post's kind word in its card header (F74).
  ///
  /// In en, this message translates to:
  /// **'· file'**
  String get daybookKindFileWord;

  /// An announcement is for everyone in the Space (K1 v13).
  ///
  /// In en, this message translates to:
  /// **'· to everyone'**
  String get daybookToEveryone;

  /// An announcement is for one Team.
  ///
  /// In en, this message translates to:
  /// **'· to {team}'**
  String daybookToTeam(String team);

  /// A checklist's progress: its own points, the one count the Daybook shows (rule 3).
  ///
  /// In en, this message translates to:
  /// **'{ticked} of {total} ticked'**
  String daybookTicked(int ticked, int total);

  /// Button on an announcement: I have read it.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get daybookGotIt;

  /// Button on a file post: I have the file.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get daybookReceived;

  /// Main button on a scheduled activity on its day.
  ///
  /// In en, this message translates to:
  /// **'On my way'**
  String get daybookOnMyWay;

  /// Button on a scheduled activity.
  ///
  /// In en, this message translates to:
  /// **'Add to my calendar'**
  String get daybookAddToCalendar;

  /// A scheduled activity is in my calendar; a tap takes it out.
  ///
  /// In en, this message translates to:
  /// **'In my calendar'**
  String get daybookInMyCalendar;

  /// Who received a file post (K2 v13), names only.
  ///
  /// In en, this message translates to:
  /// **'Received by {names}'**
  String daybookReceivedBy(String names);

  /// A file post's title with the file's revision.
  ///
  /// In en, this message translates to:
  /// **'{title} · {revision}'**
  String daybookFileTitle(String title, String revision);

  /// Ink stamp on a file post that replaces an older version.
  ///
  /// In en, this message translates to:
  /// **'NEW VERSION'**
  String get daybookStampNewVersion;

  /// The NEW VERSION stamp's second line.
  ///
  /// In en, this message translates to:
  /// **'REPLACES {revision}'**
  String daybookStampReplaces(String revision);

  /// How long an announcement stays pinned (K1 v13).
  ///
  /// In en, this message translates to:
  /// **'Until {day}'**
  String daybookPinnedUntil(String day);

  /// A checklist's due date on its card.
  ///
  /// In en, this message translates to:
  /// **'By {date}'**
  String daybookChecklistBy(String date);

  /// A checklist's due date and time on its card.
  ///
  /// In en, this message translates to:
  /// **'By {date} {time}'**
  String daybookChecklistByAt(String date, String time);

  /// Names in a list: the last one joined with and.
  ///
  /// In en, this message translates to:
  /// **'{list} and {last}'**
  String daybookNamesAnd(String list, String last);

  /// Between names in a list.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get daybookNamesComma;

  /// The first names, then and others (never a number).
  ///
  /// In en, this message translates to:
  /// **'{list} and others'**
  String daybookNamesOthers(String list);

  /// A checklist or activity for the reader and others.
  ///
  /// In en, this message translates to:
  /// **'For you and {names}'**
  String daybookForYouAnd(String names);

  /// An activity starts tomorrow, at the start of its line.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get daybookTomorrowStart;

  /// When an activity is: Tomorrow, 7:00 to 8:00 am.
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String daybookActivityWhen(String day, String time);

  /// An activity on its day, in its last hour before it starts (K3 v13).
  ///
  /// In en, this message translates to:
  /// **'{time} · starts in {minutes} min'**
  String daybookStartsIn(String time, int minutes);

  /// An activity that has started and not ended.
  ///
  /// In en, this message translates to:
  /// **'{time} · on now'**
  String daybookOnNow(String time);

  /// A file post is a PDF.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get daybookPdf;

  /// A file post is a photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get daybookPhoto;

  /// A time span: 7:00 to 8:00 am.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String timeRange(String from, String to);

  /// Daybook history line: someone ticked a checklist point (its words follow).
  ///
  /// In en, this message translates to:
  /// **'{name} · ticked'**
  String daybookLineTicked(String name);

  /// Daybook history line: you ticked a point.
  ///
  /// In en, this message translates to:
  /// **'You · ticked'**
  String get daybookLineYouTicked;

  /// Daybook history line: someone unticked a point.
  ///
  /// In en, this message translates to:
  /// **'{name} · unticked'**
  String daybookLineUnticked(String name);

  /// Daybook history line: you unticked a point.
  ///
  /// In en, this message translates to:
  /// **'You · unticked'**
  String get daybookLineYouUnticked;

  /// Daybook history line: someone said Got it (only the author sees others).
  ///
  /// In en, this message translates to:
  /// **'{name} · Got it'**
  String daybookLineGotIt(String name);

  /// Daybook history line: you said Got it.
  ///
  /// In en, this message translates to:
  /// **'You · Got it'**
  String get daybookLineYouGotIt;

  /// Daybook history line: someone received the file.
  ///
  /// In en, this message translates to:
  /// **'{name} · Received'**
  String daybookLineReceived(String name);

  /// Daybook history line: you received the file.
  ///
  /// In en, this message translates to:
  /// **'You · Received'**
  String get daybookLineYouReceived;

  /// Daybook history line: someone is on the way (K3 v13).
  ///
  /// In en, this message translates to:
  /// **'{name} · On my way'**
  String daybookLineOnMyWay(String name);

  /// Daybook history line: you are on the way.
  ///
  /// In en, this message translates to:
  /// **'You · On my way'**
  String get daybookLineYouOnMyWay;

  /// Daybook history line: someone added the activity to their calendar.
  ///
  /// In en, this message translates to:
  /// **'{name} · In my calendar'**
  String daybookLineInMyCalendar(String name);

  /// Daybook history line: you added the activity to your calendar.
  ///
  /// In en, this message translates to:
  /// **'You · In my calendar'**
  String get daybookLineYouInMyCalendar;

  /// Daybook trace on an earlier day: someone ticked a point.
  ///
  /// In en, this message translates to:
  /// **'{name} ticked a point'**
  String daybookTraceTicked(String name);

  /// Daybook trace: you ticked a point.
  ///
  /// In en, this message translates to:
  /// **'You ticked a point'**
  String get daybookTraceYouTicked;

  /// Daybook trace: someone unticked a point.
  ///
  /// In en, this message translates to:
  /// **'{name} unticked a point'**
  String daybookTraceUnticked(String name);

  /// Daybook trace: you unticked a point.
  ///
  /// In en, this message translates to:
  /// **'You unticked a point'**
  String get daybookTraceYouUnticked;

  /// A tick the server refused.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t tick'**
  String get daybookCouldNotTick;

  /// A Got it, Received, On my way or calendar add the server refused.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save'**
  String get daybookCouldNotAck;

  /// Kind menu and chip: a checklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get daybookKindChecklist;

  /// Kind menu and chip: an announcement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get daybookKindAnnouncement;

  /// Kind menu and chip: a scheduled activity.
  ///
  /// In en, this message translates to:
  /// **'Scheduled activity'**
  String get daybookKindActivity;

  /// Kind menu and chip: a file; also the attach sheet row.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get daybookKindFile;

  /// Writing card text line: a checklist or file post.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get daybookBodyNote;

  /// Writing card text line: an announcement.
  ///
  /// In en, this message translates to:
  /// **'Write the announcement'**
  String get daybookBodyAnnouncement;

  /// Writing card text line: a scheduled activity.
  ///
  /// In en, this message translates to:
  /// **'What it is about'**
  String get daybookBodyActivity;

  /// Writing a checklist: the empty point line.
  ///
  /// In en, this message translates to:
  /// **'Add a point'**
  String get daybookPointHint;

  /// More menu: who a checklist or activity is for.
  ///
  /// In en, this message translates to:
  /// **'Who it\'s for'**
  String get daybookPeople;

  /// People picker search placeholder.
  ///
  /// In en, this message translates to:
  /// **'Who is it for…'**
  String get daybookPeopleSearch;

  /// More menu: pin an announcement until a day.
  ///
  /// In en, this message translates to:
  /// **'Pin until'**
  String get daybookPinUntil;

  /// Writing card: the announcement is pinned until a day.
  ///
  /// In en, this message translates to:
  /// **'Pinned until {day}'**
  String daybookPinnedProperty(String day);

  /// More menu: when a scheduled activity starts and ends.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get daybookActivityTime;

  /// Time picker title: the activity starts.
  ///
  /// In en, this message translates to:
  /// **'Starts at'**
  String get daybookStartsAtHelp;

  /// Time picker title: the activity ends.
  ///
  /// In en, this message translates to:
  /// **'Ends at'**
  String get daybookEndsAtHelp;

  /// Time picker: the activity has no end time.
  ///
  /// In en, this message translates to:
  /// **'No end time'**
  String get daybookNoEndTime;

  /// An activity must start in the future.
  ///
  /// In en, this message translates to:
  /// **'Choose a time that has not come yet'**
  String get daybookStartLater;

  /// Attach sheet title (K4 v13).
  ///
  /// In en, this message translates to:
  /// **'Add to this post'**
  String get daybookAttachTitle;

  /// Attach sheet: photos from the phone.
  ///
  /// In en, this message translates to:
  /// **'Photo from the gallery'**
  String get daybookAttachPhotos;

  /// Attach sheet: how many photos at most.
  ///
  /// In en, this message translates to:
  /// **'Up to {n} photos'**
  String daybookAttachPhotosNote(int n);

  /// File chooser sheet title.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get daybookFileChooseTitle;

  /// File chooser: a PDF or photo on the phone.
  ///
  /// In en, this message translates to:
  /// **'From the phone'**
  String get daybookFileFromPhone;

  /// File chooser: a new file also goes to the Library.
  ///
  /// In en, this message translates to:
  /// **'It goes to the Library too'**
  String get daybookFileFromPhoneNote;

  /// File chooser: the Space's Library files.
  ///
  /// In en, this message translates to:
  /// **'In the Library'**
  String get daybookFileInLibrary;

  /// Sheet title after picking a file on the phone.
  ///
  /// In en, this message translates to:
  /// **'Is it a new version of a file?'**
  String get daybookReplacesTitle;

  /// The picked file replaces nothing.
  ///
  /// In en, this message translates to:
  /// **'No, a new file'**
  String get daybookReplacesNone;

  /// The picked file is a new version of this one.
  ///
  /// In en, this message translates to:
  /// **'Replaces {name}'**
  String daybookReplacesOption(String name);

  /// Confirms the new-version choice.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get daybookReplacesDone;

  /// A post takes at most 10 photos and files.
  ///
  /// In en, this message translates to:
  /// **'Up to 10 photos and files on a post'**
  String get daybookFilesFull;

  /// Read out for a checklist point's remove button while writing.
  ///
  /// In en, this message translates to:
  /// **'Remove point'**
  String get daybookRemovePoint;

  /// Read out for a file's remove button while writing.
  ///
  /// In en, this message translates to:
  /// **'Remove file'**
  String get daybookRemoveFile;

  /// Long-press menu: the author cancels a checklist, announcement, activity or file post.
  ///
  /// In en, this message translates to:
  /// **'Cancel post'**
  String get daybookCancelPost;

  /// Library preview of a model view: instead of Upload a new revision (review 61 G4).
  ///
  /// In en, this message translates to:
  /// **'New versions come from BuildVibes 360'**
  String get previewModelViewVersions;

  /// Closes the people sheet, keeping who was chosen (F45).
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get daybookPeopleDone;

  /// A day and a time: when someone tapped Received (F48).
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String daybookDayTime(String day, String time);

  /// The kind menu's name for a file post (F74: "File"; the request to confirm stays on the card as the Received pill).
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get daybookKindDocument;

  /// Long-press menu on a pinned announcement (F44): it becomes an ordinary card on its day.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get daybookUnpin;

  /// Kind menu: the plain post, for information (F58).
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get daybookKindNote;

  /// Card header after the author's name: a note (K5).
  ///
  /// In en, this message translates to:
  /// **'· note'**
  String get daybookKindNoteWord;

  /// Writing card: the who row before anyone is chosen, on a work item and a checklist (F56). The row's caret is an icon, never a character (review 79 A2).
  ///
  /// In en, this message translates to:
  /// **'For: Choose'**
  String get daybookForChoose;

  /// Writing card: the who row of a scheduled activity before anyone is chosen (F56). The row's caret is an icon (review 79 A2).
  ///
  /// In en, this message translates to:
  /// **'Who\'s coming: Choose'**
  String get daybookComingChoose;

  /// Writing card: the who row, pulsing, after Post was tapped with nobody chosen (F56).
  ///
  /// In en, this message translates to:
  /// **'Choose who it\'s for'**
  String get daybookChooseWho;

  /// Under the owner picker of a work item: turn it into a note (F56, F58).
  ///
  /// In en, this message translates to:
  /// **'Just for information? Post as a Note'**
  String get daybookPostAsNote;

  /// Writing card: who an announcement or a Document for receipt goes to (F56). A caret icon follows when it can be changed (review 79 A2).
  ///
  /// In en, this message translates to:
  /// **'To: {audience}'**
  String daybookToAudience(String audience);

  /// Writing card and its To menu: the whole Space (F56).
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get daybookEveryone;

  /// The masthead at Now, after the bold word Today (review 50 F59): "Today · Wednesday 21 October".
  ///
  /// In en, this message translates to:
  /// **'· {date}'**
  String daybookMastheadToday(String date);

  /// Under the Today divider when nothing has been posted today (F59).
  ///
  /// In en, this message translates to:
  /// **'Nothing yet today'**
  String get daybookNothingYetToday;

  /// Send-back sheet (review 50 F62): the label over the new date's one choice, nothing chosen first.
  ///
  /// In en, this message translates to:
  /// **'New date'**
  String get daybookSendBackNewDate;

  /// Send-back sheet, new date: today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get daybookSendBackToday;

  /// Send-back sheet, new date: tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get daybookSendBackTomorrow;

  /// Send-back sheet, new date: opens the day picker; then shows the day picked.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get daybookSendBackPickDate;

  /// A send-back line on the card, after the reason (F62): "Photo missing · new date Thu 23 Oct".
  ///
  /// In en, this message translates to:
  /// **'new date {date}'**
  String daybookLineNewDate(String date);

  /// A send-back line on the card, after the reason, when the author chose no new date (F62, F64).
  ///
  /// In en, this message translates to:
  /// **'no new date'**
  String get daybookLineNoNewDate;

  /// Needs you, the author's row for a work item signed as done (F62): never red, no due.
  ///
  /// In en, this message translates to:
  /// **'Done {time} · waiting for your check'**
  String needsDoneWaiting(String time);

  /// Messages (DM1): the screen title, and the Home icon's label.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// DM1: the label above the newest request from someone new.
  ///
  /// In en, this message translates to:
  /// **'Message request'**
  String get messagesRequest;

  /// The list of every request from someone new.
  ///
  /// In en, this message translates to:
  /// **'Message requests'**
  String get messagesRequests;

  /// DM1: the group of threads with a message today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get messagesToday;

  /// DM1: the group of older threads.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get messagesEarlier;

  /// DM1: the last message, when you sent it.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String messagesYou(String text);

  /// DM1: a voice note as the last message.
  ///
  /// In en, this message translates to:
  /// **'Voice note · {length}'**
  String messagesVoice(String length);

  /// DM1 with no threads.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Start one with +.'**
  String get messagesEmpty;

  /// DM1: the + button's label, and the person picker's title.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get messagesNew;

  /// DM1: the search field's hint.
  ///
  /// In en, this message translates to:
  /// **'Search names'**
  String get messagesSearch;

  /// Read out for a thread's dot (never a number).
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get messagesUnread;

  /// DM2: the first Space both people are in. Never a count.
  ///
  /// In en, this message translates to:
  /// **'Both in {space}'**
  String dmBothIn(String space);

  /// DM6: a request from someone with no work link to you.
  ///
  /// In en, this message translates to:
  /// **'Not in your Spaces'**
  String get dmNotInSpaces;

  /// DM6: decline a request; the sender isn't told.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get dmDecline;

  /// After Decline.
  ///
  /// In en, this message translates to:
  /// **'Declined. {name} isn\'t told.'**
  String dmDeclined(String name);

  /// DM6: a photo or file from someone you haven't answered.
  ///
  /// In en, this message translates to:
  /// **'Tap to show'**
  String get dmTapToShow;

  /// DM2 ⋯ menu: no pushes from this thread.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get dmMute;

  /// DM2 ⋯ menu.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get dmUnmute;

  /// DM2 ⋯ menu.
  ///
  /// In en, this message translates to:
  /// **'Report {name}'**
  String dmReportPerson(String name);

  /// A new conversation's field hint, before the thread exists.
  ///
  /// In en, this message translates to:
  /// **'Write the first message'**
  String get dmFirstMessage;

  /// start_dm paused by the spam guard.
  ///
  /// In en, this message translates to:
  /// **'Many people you wrote to haven\'t answered. You can start new conversations again on {day}.'**
  String dmPaused(String day);

  /// start_dm's warning, before the pause.
  ///
  /// In en, this message translates to:
  /// **'Many people you wrote to haven\'t answered yet.'**
  String get dmWarning;

  /// A photo in a message.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get dmPhoto;

  /// A person's profile (R5 v3): open or start the conversation.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get profileMessage;

  /// S7 v4: the button on a Space's Chat tab, and its sheet's title.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatNewChat;

  /// S7-N: a new Team.
  ///
  /// In en, this message translates to:
  /// **'New group in this Space'**
  String get chatNewGroup;

  /// S7-N: under New group.
  ///
  /// In en, this message translates to:
  /// **'Pick a name and members. The Space admin can do this.'**
  String get chatNewGroupNote;

  /// S7-N: a direct message to someone in this Space.
  ///
  /// In en, this message translates to:
  /// **'Message one person'**
  String get chatOnePerson;

  /// S7-N and the threads note: where a message to one person goes.
  ///
  /// In en, this message translates to:
  /// **'Opens in Messages, marked “From {space}”'**
  String chatOnePersonNote(String space);

  /// S7-N: the sheet's last line.
  ///
  /// In en, this message translates to:
  /// **'Work is given in the Work tab. Chat is for talking.'**
  String get chatWorkNote;

  /// S7 v4: under the threads, after who sees which.
  ///
  /// In en, this message translates to:
  /// **'Messages to one person open in Messages, marked “From {space}”.'**
  String chatThreadsDmNote(String space);

  /// A photo slot while the photo is made safe to leave the phone (review 74 H2), with a small spinner.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get photoPreparing;

  /// A picked photo nobody could open; it isn't sent, and the others still go (review 74 H1).
  ///
  /// In en, this message translates to:
  /// **'This photo can\'t be opened. Choose another.'**
  String get photoCannotOpen;

  /// The To do docket's first line (review 50 F68b): your own open and sent-back items, due today or earlier. Western digits.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 work item for you} other{{n} work items for you}}'**
  String daybookDocketTitle(int n);

  /// The docket's second line, after the oldest title: due on an earlier day ("from Sun"), grey, never a warning (F57).
  ///
  /// In en, this message translates to:
  /// **'from {day}'**
  String daybookDocketFrom(String day);

  /// The docket's second line, at its end: how many more items after the oldest one (F68b).
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{} =1{, and 1 more} other{, and {n} more}}'**
  String daybookDocketRest(int n);

  /// Over a message quoted in a post (review 64, DM5): who wrote it and when.
  ///
  /// In en, this message translates to:
  /// **'From {name} · {when}'**
  String daybookQuoteFrom(String name, String when);

  /// Over a quoted message with no time.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String daybookQuoteFromName(String name);

  /// DM3 hold menu and the DM4 sheet's title (review 64): make a work item in a Space from this message, quoted. The message stays in the thread.
  ///
  /// In en, this message translates to:
  /// **'Put in a Space'**
  String get dmPutInSpace;

  /// DM4 when the person has no Space where their pass lets them post.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in a Space where you can add work yet.'**
  String get dmPutInSpaceNone;

  /// S8m hold menu in Space chat (review 64): the Work tab opens with a work item being written, this message quoted.
  ///
  /// In en, this message translates to:
  /// **'Turn into a work item'**
  String get chatTurnIntoWorkItem;

  /// P1: the end of a join request's line (Foreman · Gulf Build Co. · wants to join).
  ///
  /// In en, this message translates to:
  /// **'wants to join'**
  String get peopleWantsToJoin;

  /// P1: the pill on a join request; opens the three passes in place.
  ///
  /// In en, this message translates to:
  /// **'Let in'**
  String get peopleLetIn;

  /// P2: the grey pill until a pass is chosen (nothing is chosen first, review 69).
  ///
  /// In en, this message translates to:
  /// **'Choose a pass'**
  String get peopleChoosePass;

  /// P2: the pill once a pass is chosen (Let in as Crew).
  ///
  /// In en, this message translates to:
  /// **'Let in as {pass}'**
  String peopleLetInAs(String pass);

  /// P1: the section of people with a Lead pass.
  ///
  /// In en, this message translates to:
  /// **'Leads'**
  String get peopleLeads;

  /// P1: the section of people with a Crew pass.
  ///
  /// In en, this message translates to:
  /// **'Crew'**
  String get peopleCrew;

  /// P1: the section of people with a Viewer pass.
  ///
  /// In en, this message translates to:
  /// **'Viewers'**
  String get peopleViewers;

  /// P1: after the role in a member's line for the Space admin (BIM Manager · admin).
  ///
  /// In en, this message translates to:
  /// **'admin'**
  String get peopleAdmin;

  /// P1: the chip after the Teams, for the Space admin only.
  ///
  /// In en, this message translates to:
  /// **'+ New team'**
  String get peopleNewTeam;

  /// P1: the row at the bottom; a tap copies the code. The code is Latin, as the server writes it.
  ///
  /// In en, this message translates to:
  /// **'Invite with the code {code}'**
  String peopleInviteCode(String code);

  /// P2: after Let in; the person's row is highlighted in their section.
  ///
  /// In en, this message translates to:
  /// **'{name} is in, as {pass}.'**
  String peopleLetInDone(String name, String pass);

  /// LV1: how many earlier versions a file has (a fact about the file, not a quality signal, review 67).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 older version} other{{count} older versions}}'**
  String libraryOlderVersions(int count);

  /// LV1: the quiet last row (with a + icon) for people who may add files; opens the Work tab's writing card as a Document for receipt (review 69 1b).
  ///
  /// In en, this message translates to:
  /// **'Add a file'**
  String get libraryAddFile;

  /// LV2: the label above a file's versions.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get libraryVersions;

  /// LV2: the version in use, with an orange dot (Rev D · in use).
  ///
  /// In en, this message translates to:
  /// **'{rev} · in use'**
  String libraryInUse(String rev);

  /// LV2: a version with no revision written on it.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get libraryVersion;

  /// LV2: opens an older version full screen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get libraryOpen;

  /// LV2: under the versions (with a + icon), for people who may add files; opens the writing card with Replaces set.
  ///
  /// In en, this message translates to:
  /// **'Add a new version'**
  String get libraryAddVersion;

  /// LV2: what a screen reader says for the ⋯ button (Share in chat, Download).
  ///
  /// In en, this message translates to:
  /// **'More for this file'**
  String get libraryFileMenu;

  /// LV2: what a screen reader says for the preview, which opens the drawing table.
  ///
  /// In en, this message translates to:
  /// **'Open full screen'**
  String get libraryOpenFull;

  /// The Space menu's first item (MN1): opens Search inside the Space.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchMenu;

  /// S: the field's placeholder. It searches after 2 characters.
  ///
  /// In en, this message translates to:
  /// **'Search this Space'**
  String get searchHint;

  /// S: what a screen reader says for the ✕ in the field.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClear;

  /// S: the group of posts and checklist points.
  ///
  /// In en, this message translates to:
  /// **'Work items'**
  String get searchWorkItems;

  /// S: the group of Library files (only the version in use).
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get searchFiles;

  /// S: the group of chat messages.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get searchChat;

  /// S: no results. Never a count (rule 3).
  ///
  /// In en, this message translates to:
  /// **'Nothing found for “{query}”'**
  String searchNothing(String query);

  /// S: a chat message's words, in quotes.
  ///
  /// In en, this message translates to:
  /// **'“{text}”'**
  String searchMessage(String text);

  /// Slice 5: the quiet grey line on a card whose page holds more than the card (with a forward caret). No count.
  ///
  /// In en, this message translates to:
  /// **'Open the page'**
  String get pageOpen;

  /// Slice 5: the author's item in the card's menu, and the page's head while reading.
  ///
  /// In en, this message translates to:
  /// **'Edit page'**
  String get pageEdit;

  /// N2: ends editing the page and saves it.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get pageDone;

  /// N1: what a screen reader says for the ✕.
  ///
  /// In en, this message translates to:
  /// **'Close the page'**
  String get pageClose;

  /// N1: the label over the work items under this one.
  ///
  /// In en, this message translates to:
  /// **'Work items under this one'**
  String get pageUnder;

  /// N1: this item's own work items, how many are checked: a fact about this item, not a quality signal.
  ///
  /// In en, this message translates to:
  /// **'{checked} of {total} checked'**
  String pageUnderChecked(int checked, int total);

  /// N2: the last line of the page while its author edits it.
  ///
  /// In en, this message translates to:
  /// **'Type / to add a block'**
  String get pageAddBlock;

  /// N3: what a screen reader says for the block menu.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get pageMenuTitle;

  /// N3: the block menu; N4: Turn into.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get pageText;

  /// N3: the block menu.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get pageHeading;

  /// N3: the block menu.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get pageChecklist;

  /// N3: the block menu (a line that opens to show more).
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get pageToggle;

  /// N3: the block menu.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get pageTable;

  /// N3: the block menu.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get pagePhoto;

  /// N3: the block menu.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get pageFile;

  /// N3: the block menu; N4: Turn into.
  ///
  /// In en, this message translates to:
  /// **'Work item under this one'**
  String get pageItemUnder;

  /// N4: Turn into.
  ///
  /// In en, this message translates to:
  /// **'Checklist point'**
  String get pagePoint;

  /// N4: the title over the choices.
  ///
  /// In en, this message translates to:
  /// **'Turn into'**
  String get pageTurnInto;

  /// N4: why a ticked point can't be turned into something else.
  ///
  /// In en, this message translates to:
  /// **'A ticked point stays as it is.'**
  String get pageTickedStays;

  /// N2: a block's action.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get pageDelete;

  /// N2: after a block is deleted, with Undo.
  ///
  /// In en, this message translates to:
  /// **'Block deleted.'**
  String get pageDeleted;

  /// N2: what a screen reader says for a block's ⋮⋮ handle (hold to drag).
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get pageMove;

  /// N4: what a screen reader says for a block's menu.
  ///
  /// In en, this message translates to:
  /// **'More for this block'**
  String get pageBlockMenu;

  /// A table's + at the bottom.
  ///
  /// In en, this message translates to:
  /// **'Add a row'**
  String get pageAddRow;

  /// A table's + at the end side.
  ///
  /// In en, this message translates to:
  /// **'Add a column'**
  String get pageAddColumn;

  /// A long press on a table cell.
  ///
  /// In en, this message translates to:
  /// **'Delete row'**
  String get pageDeleteRow;

  /// A long press on a table cell.
  ///
  /// In en, this message translates to:
  /// **'Delete column'**
  String get pageDeleteColumn;

  /// N2: the save found a newer page saved by the author's other phone.
  ///
  /// In en, this message translates to:
  /// **'This page changed on another phone. Yours is kept here.'**
  String get pageStale;

  /// N2: after a newer page: save this phone's copy over it.
  ///
  /// In en, this message translates to:
  /// **'Use mine'**
  String get pageUseMine;

  /// N2: after a newer page: drop this phone's edit.
  ///
  /// In en, this message translates to:
  /// **'Use the newer one'**
  String get pageUseNewer;

  /// N3: no more photos or files on this post.
  ///
  /// In en, this message translates to:
  /// **'A page holds up to 10 photos and files.'**
  String get pageFull;

  /// N3: the placeholder for a new work item under this one.
  ///
  /// In en, this message translates to:
  /// **'What needs doing'**
  String get pageItemTitle;

  /// N4: a point too long to be a work item's title.
  ///
  /// In en, this message translates to:
  /// **'Shorten it to 140 characters to make it a work item.'**
  String get pageTooLongForItem;

  /// N2: a photo block's caption, while the page is edited (up to 300 characters).
  ///
  /// In en, this message translates to:
  /// **'Add a caption'**
  String get pagePhotoCaption;

  /// The Space menu: walk mode, one photo and one line per thing to fix (slice 6). Says no "site": BuildVibes is for the whole industry.
  ///
  /// In en, this message translates to:
  /// **'Walk mode'**
  String get walkMenu;

  /// R1: the walk screen's chip, before the walk's name (Walk · Level 4 corridor).
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get walkTitle;

  /// R1: the walk's name before the first photo (Walk, level 4 corridor).
  ///
  /// In en, this message translates to:
  /// **'Name this walk'**
  String get walkNameHint;

  /// R1: starts the walk with the camera.
  ///
  /// In en, this message translates to:
  /// **'Take the first photo'**
  String get walkStart;

  /// R1: the line for the photo just taken (2 to 140 characters). The keyboard's mic types it.
  ///
  /// In en, this message translates to:
  /// **'What needs doing here'**
  String get walkLineHint;

  /// R1: the owner chip before one is chosen.
  ///
  /// In en, this message translates to:
  /// **'Who does it'**
  String get walkOwner;

  /// R1: the shutter's label once this photo has its line and owner.
  ///
  /// In en, this message translates to:
  /// **'Next photo'**
  String get walkNext;

  /// R1: how many photos so far, beside the shutter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String walkPhotos(int count);

  /// R1: posts the walk, one work item per photo.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get walkFinish;

  /// R1: the photo has no line yet.
  ///
  /// In en, this message translates to:
  /// **'Write what needs doing, then the next photo.'**
  String get walkNeedsLine;

  /// R1: the photo has no owner yet.
  ///
  /// In en, this message translates to:
  /// **'Choose who does it, then the next photo.'**
  String get walkNeedsOwner;

  /// R1: the 30th photo was taken.
  ///
  /// In en, this message translates to:
  /// **'A walk holds 30 photos. Finish it, then start another.'**
  String get walkFull;

  /// R1: ✕ once there is a photo.
  ///
  /// In en, this message translates to:
  /// **'Throw this walk away?'**
  String get walkDiscardTitle;

  /// R1: under the question.
  ///
  /// In en, this message translates to:
  /// **'Its photos aren\'t sent.'**
  String get walkDiscardBody;

  /// R1: keeps the walk.
  ///
  /// In en, this message translates to:
  /// **'Keep walking'**
  String get walkKeep;

  /// R1: drops the walk and its photos.
  ///
  /// In en, this message translates to:
  /// **'Throw away'**
  String get walkDiscard;

  /// R1: a thumbnail's action.
  ///
  /// In en, this message translates to:
  /// **'Take this photo out'**
  String get walkRemovePhoto;

  /// R1b: under a walk's title: a fact about this post.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo, a work item} other{{count} photos, each one a work item}}'**
  String walkEachItem(int count);

  /// R1b: more rows than the card shows; opens the page.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get walkShowAll;

  /// Opening a Space with a walk kept on the phone (the app was closed while walking, review 79 P1). The body is the walk's name and its photos.
  ///
  /// In en, this message translates to:
  /// **'You have a walk in progress'**
  String get walkInProgress;

  /// The walk in progress: opens walk mode where it stopped (review 79 P1).
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get walkContinue;

  /// The walk in progress: drops it and its photos, after asking (review 79 P1).
  ///
  /// In en, this message translates to:
  /// **'Throw away'**
  String get walkThrowAway;

  /// F78: the people search field's hint.
  ///
  /// In en, this message translates to:
  /// **'Name, role or company'**
  String get peopleSearchHint;

  /// F78: before typing, the people you share a Space with.
  ///
  /// In en, this message translates to:
  /// **'People in your Spaces'**
  String get peopleInYourSpaces;

  /// F78: a people search with no result.
  ///
  /// In en, this message translates to:
  /// **'Nobody found for “{query}”'**
  String peopleSearchNothing(String query);

  /// F78: before typing, when you share no Space with anyone.
  ///
  /// In en, this message translates to:
  /// **'Type a name to find someone.'**
  String get peopleSearchStart;

  /// F73: a post on its way to the server, with a signal.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get daybookSending;

  /// F73: a file uploading, how much of it went (MB, one decimal).
  ///
  /// In en, this message translates to:
  /// **'Sending · {sent} of {total} MB'**
  String daybookSendingBytes(String sent, String total);

  /// F79: the Space admin's row on a person's sheet that changes their pass (Lead / Crew / Viewer).
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get peoplePassRow;

  /// F71: one of the single choice for a file from the phone.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get daybookNewFile;

  /// F71: the other choice; opens a searchable list of the Library's files.
  ///
  /// In en, this message translates to:
  /// **'New version of a file'**
  String get daybookNewVersion;

  /// F71: the title of the file picker for a new version.
  ///
  /// In en, this message translates to:
  /// **'A new version of which file?'**
  String get daybookPickVersionTitle;

  /// F75: a version's number given by the app (V1, V2…); kept in Latin like a ref.
  ///
  /// In en, this message translates to:
  /// **'V{version}'**
  String libraryVersionNo(int version);

  /// F71: the ✕ on 'Replaces …' (screen readers).
  ///
  /// In en, this message translates to:
  /// **'Not a new version'**
  String get daybookNotNewVersion;

  /// F72: the paper clip's row for a PDF or photo from the phone's files (it goes to the Library too).
  ///
  /// In en, this message translates to:
  /// **'File from the phone'**
  String get daybookAttachFiles;

  /// F72: the paper clip's row for a file already in the Space's Library.
  ///
  /// In en, this message translates to:
  /// **'From the Library'**
  String get daybookAttachLibrary;

  /// F72: why To: Everyone can't be changed on a file post.
  ///
  /// In en, this message translates to:
  /// **'A file goes to the whole Space. To send it to one person, use a direct message.'**
  String get daybookFileToEveryone;

  /// F72: under Take a photo on the paper clip's sheet.
  ///
  /// In en, this message translates to:
  /// **'With the phone\'s camera'**
  String get daybookAttachCameraNote;

  /// F72: under From the Library on the paper clip's sheet.
  ///
  /// In en, this message translates to:
  /// **'A file already in this Space'**
  String get daybookAttachLibraryNote;

  /// F75: the stamp on a new version's post, with its number (V2).
  ///
  /// In en, this message translates to:
  /// **'NEW VERSION · {version}'**
  String daybookStampNewVersionNo(String version);

  /// F76: the grey line on an older version's post; a tap opens the newer one's post.
  ///
  /// In en, this message translates to:
  /// **'Replaced by {version} · {when}'**
  String daybookReplacedBy(String version, String when);

  /// F75/F80: the version in use on the versions list (V2 · in use; the revision follows when given).
  ///
  /// In en, this message translates to:
  /// **'{version} · in use'**
  String libraryInUseNo(String version);

  /// F80: an older version's line on the versions list.
  ///
  /// In en, this message translates to:
  /// **'replaced {day}, kept in the record'**
  String libraryReplacedOn(String day);

  /// F90: the hint of the empty line ready to type at the end of an open toggle.
  ///
  /// In en, this message translates to:
  /// **'Type inside'**
  String get pageTypeInside;

  /// F91/F93: one history line for the reader's own edit session of a post's page.
  ///
  /// In en, this message translates to:
  /// **'You edited the page'**
  String get daybookLineYouEditedPage;

  /// F91/F93: one history line for someone's edit session of a post's page.
  ///
  /// In en, this message translates to:
  /// **'{name} edited the page'**
  String daybookLineEditedPage(String name);

  /// A pinned announcement's end with its time, on its facts line (F82, F85): "Until Friday 23 Oct · 2:00 pm".
  ///
  /// In en, this message translates to:
  /// **'Until {day} · {time}'**
  String daybookPinnedUntilAt(String day, String time);

  /// The end of a pinned announcement at the end of its folded line (F85): "until Fri".
  ///
  /// In en, this message translates to:
  /// **'until {day}'**
  String daybookPinnedLineUntil(String day);

  /// Adds a time to an announcement's pin on the writing card (F82).
  ///
  /// In en, this message translates to:
  /// **'+ Time'**
  String get daybookPinAddTime;

  /// Takes the time off an announcement's pin; it then ends with its day (F82).
  ///
  /// In en, this message translates to:
  /// **'Remove the time'**
  String get daybookPinRemoveTime;

  /// The time picker's heading for an announcement's pin (F82).
  ///
  /// In en, this message translates to:
  /// **'Pinned until what time?'**
  String get daybookPinTimeHelp;

  /// A pin's time that has already passed is refused (F82).
  ///
  /// In en, this message translates to:
  /// **'Choose a later time'**
  String get daybookPinLater;

  /// The daily report as a kind of post (slice 7, R2).
  ///
  /// In en, this message translates to:
  /// **'Daily report'**
  String get daybookKindReport;

  /// A daily report's header after its author (R2).
  ///
  /// In en, this message translates to:
  /// **'· daily report'**
  String get daybookKindReportWord;

  /// Space menu: write today's daily report (Lead and Crew).
  ///
  /// In en, this message translates to:
  /// **'Daily report'**
  String get dailyReportMenu;

  /// The daily report's first heading (R2).
  ///
  /// In en, this message translates to:
  /// **'On site'**
  String get dailyReportOnSite;

  /// The daily report's second heading: work checked today (R2).
  ///
  /// In en, this message translates to:
  /// **'Done today'**
  String get dailyReportDoneToday;

  /// The daily report's third heading (R2).
  ///
  /// In en, this message translates to:
  /// **'Problems'**
  String get dailyReportProblems;

  /// Hint under On site while writing the daily report. Typed words only; the app never counts people (review 79 Q5).
  ///
  /// In en, this message translates to:
  /// **'Who was there, and what came in'**
  String get dailyReportOnSiteHint;

  /// Hint under Problems while writing the daily report.
  ///
  /// In en, this message translates to:
  /// **'Anything that held work up'**
  String get dailyReportProblemsHint;

  /// Done today, when no work item was checked today.
  ///
  /// In en, this message translates to:
  /// **'Nothing checked yet today'**
  String get dailyReportNothingChecked;

  /// The ✕ on a Done today line while writing (review 78).
  ///
  /// In en, this message translates to:
  /// **'Take it out of the report'**
  String get dailyReportTakeOut;

  /// While writing the daily report: the day's notes, each with Add, for On site.
  ///
  /// In en, this message translates to:
  /// **'Today\'s notes'**
  String get dailyReportNotes;

  /// Adds one of the day's notes to On site.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get dailyReportAddNote;

  /// The pill at the end of a daily report's card (R2).
  ///
  /// In en, this message translates to:
  /// **'Share as PDF'**
  String get dailyReportSharePdf;

  /// While the daily report's PDF is made on the phone.
  ///
  /// In en, this message translates to:
  /// **'Making the PDF…'**
  String get dailyReportMakingPdf;

  /// The daily report's PDF could not be made.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make the PDF. Try again.'**
  String get dailyReportPdfFailed;

  /// The PDF's line under the day: the author and when it was posted.
  ///
  /// In en, this message translates to:
  /// **'By {name} · {time}'**
  String dailyReportPdfBy(String name, String time);

  /// In the PDF, under a Done today line: when and by whom it was checked.
  ///
  /// In en, this message translates to:
  /// **'Checked {time} by {name}'**
  String dailyReportPdfChecked(String time, String name);

  /// The shared PDF's file name, before .pdf.
  ///
  /// In en, this message translates to:
  /// **'Daily report {day}'**
  String dailyReportPdfFile(String day);

  /// Opening the daily report after midnight with yesterday's draft: it is not kept (founder, question 4).
  ///
  /// In en, this message translates to:
  /// **'A daily report is for today. Yesterday\'s draft was put away.'**
  String get dailyReportTodayOnly;

  /// The writing card's More menu: start from a template (slice 7).
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get templateMenu;

  /// The template picker's title.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get templatePickTitle;

  /// The template list's heading over the Space's own, after the built-ins (review 79 §1).
  ///
  /// In en, this message translates to:
  /// **'This Space\'s templates'**
  String get templateSpaceOwn;

  /// The writing card's grey line once a template filled it (review 79 §1).
  ///
  /// In en, this message translates to:
  /// **'From: {name}'**
  String templateFrom(String name);

  /// The ✕ on the From line: drops the template, keeps what was written.
  ///
  /// In en, this message translates to:
  /// **'Not from a template'**
  String get templateDrop;

  /// A post's menu (Lead or Space admin): save its words as a template.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get templateSave;

  /// Save as template: the sheet's title.
  ///
  /// In en, this message translates to:
  /// **'Name this template'**
  String get templateNameTitle;

  /// Save as template: the name field's hint.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateNameHint;

  /// After Save as template.
  ///
  /// In en, this message translates to:
  /// **'Saved as a template'**
  String get templateSaved;

  /// Save as template refused at the Space's limit (review 78).
  ///
  /// In en, this message translates to:
  /// **'This Space has its {count} templates. Delete one in Space info › Templates to save another.'**
  String templateFull(int count);

  /// With templateFull: opens Space info › Templates.
  ///
  /// In en, this message translates to:
  /// **'Open Templates'**
  String get templateOpenList;

  /// Space info › Templates (Lead or Space admin).
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templatesTitle;

  /// Space info › Templates with none of the Space's own.
  ///
  /// In en, this message translates to:
  /// **'No templates saved in this Space yet. A Lead saves one from a post\'s menu.'**
  String get templatesNoneOwn;

  /// Space info › Templates: delete one of the Space's own.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get templateDelete;

  /// Asks before deleting a template.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? Posts made from it stay as they are.'**
  String templateDeleteAsk(String name);

  /// After a template is deleted.
  ///
  /// In en, this message translates to:
  /// **'Template deleted'**
  String get templateDeleted;

  /// The built-in Daily report template's name.
  ///
  /// In en, this message translates to:
  /// **'Daily report'**
  String get templateBuiltinDailyReport;

  /// Daily report while another kind of post is being written: that card opens instead.
  ///
  /// In en, this message translates to:
  /// **'Post or put away the card you\'re writing first.'**
  String get dailyReportDraftFirst;
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
