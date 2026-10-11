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

  /// E9 helper.
  ///
  /// In en, this message translates to:
  /// **'From your phone number. You can change it in Settings.'**
  String get countryFromPhone;

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

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Email for getting back in (optional)'**
  String get recoveryEmail;

  /// Field helper.
  ///
  /// In en, this message translates to:
  /// **'Helps you get back in if your number changes.'**
  String get recoveryEmailHelp;

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

  /// Proof card label. Capitals in English.
  ///
  /// In en, this message translates to:
  /// **'PROOF · WHERE IT\'S CONFIRMED'**
  String get proofLabel;

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

  /// Own profile section.
  ///
  /// In en, this message translates to:
  /// **'Work you delivered'**
  String get workDeliveredTitle;

  /// Visitor profile section.
  ///
  /// In en, this message translates to:
  /// **'Work delivered'**
  String get workDeliveredVisitorTitle;

  /// Own profile section.
  ///
  /// In en, this message translates to:
  /// **'You choose what shows. Only items checked and closed in a Space.'**
  String get workDeliveredBody;

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
  /// **'You won\'t see each other\'s profiles, and follows between you are removed. They aren\'t told.'**
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
  /// **'City or area'**
  String get placeLabel;

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

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Write the project name.'**
  String get projectNameRequired;

  /// Validation.
  ///
  /// In en, this message translates to:
  /// **'Choose the type.'**
  String get projectTypeRequired;

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
