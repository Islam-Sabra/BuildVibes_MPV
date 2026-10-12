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

  /// Header line of a Space linked to a project.
  ///
  /// In en, this message translates to:
  /// **'Private work · project Space'**
  String get spacesProjectSpaceLine;

  /// H1e card title.
  ///
  /// In en, this message translates to:
  /// **'Join your first Space'**
  String get spacesEmptyTitle;

  /// H1e card body (work Spaces only in the MVP).
  ///
  /// In en, this message translates to:
  /// **'A Space is where a project team runs its daily work. Once you join one, your daily report appears here: replies, site updates and anything waiting for you.'**
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
  /// **'e.g. Tower B — Site team'**
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
  /// **'Send the code on WhatsApp or read it out on site. The Space admin confirms each person before they join.'**
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

  /// S10k section: the Space admins.
  ///
  /// In en, this message translates to:
  /// **'Owners'**
  String get spacesOwners;

  /// Tag under an admin's name.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get spacesOwnerTag;

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
  /// **'Check and close items'**
  String get spacesRightCheck;

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

  /// "Owners: Omar Haddad and you".
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get youLower;

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

  /// S15 row, read-only.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get spacesAccess;

  /// S15 Access row.
  ///
  /// In en, this message translates to:
  /// **'Private work · linked to {project}'**
  String spacesAccessLinked(String project);

  /// S15 Invite people row.
  ///
  /// In en, this message translates to:
  /// **'Share the invite code'**
  String get spacesInviteRowSub;

  /// S15 Members row.
  ///
  /// In en, this message translates to:
  /// **'Owners: {names}'**
  String spacesOwnersLine(String names);

  /// S15 row and S15k-I title.
  ///
  /// In en, this message translates to:
  /// **'Who can invite'**
  String get spacesWhoCanInvite;

  /// S15k-I subtitle.
  ///
  /// In en, this message translates to:
  /// **'Every invite still needs a Space admin to confirm the join.'**
  String get spacesWhoCanInviteNote;

  /// Who can invite option.
  ///
  /// In en, this message translates to:
  /// **'Space admins'**
  String get spacesInviteAdmins;

  /// Option help.
  ///
  /// In en, this message translates to:
  /// **'Only admins share the invite code.'**
  String get spacesInviteAdminsHelp;

  /// Option.
  ///
  /// In en, this message translates to:
  /// **'Admins and Leads'**
  String get spacesInviteLeads;

  /// Option help.
  ///
  /// In en, this message translates to:
  /// **'People with a Lead pass can invite their own crews.'**
  String get spacesInviteLeadsHelp;

  /// Option.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the Space'**
  String get spacesInviteEveryone;

  /// Option help.
  ///
  /// In en, this message translates to:
  /// **'Anyone can share the code. Admins still confirm each join.'**
  String get spacesInviteEveryoneHelp;

  /// S15 row and S15k-N title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get spacesNotifications;

  /// S15k-N subtitle.
  ///
  /// In en, this message translates to:
  /// **'For this Space only.'**
  String get spacesNotificationsNote;

  /// Option.
  ///
  /// In en, this message translates to:
  /// **'Everyone posts and my Teams'**
  String get spacesNotifyAll;

  /// Option help.
  ///
  /// In en, this message translates to:
  /// **'Messages in Everyone and in your Teams, plus anything that needs you.'**
  String get spacesNotifyAllHelp;

  /// Option.
  ///
  /// In en, this message translates to:
  /// **'Needs you only'**
  String get spacesNotifyNeedsYou;

  /// Option help.
  ///
  /// In en, this message translates to:
  /// **'Items you own, items to check and people asking to join.'**
  String get spacesNotifyNeedsYouHelp;

  /// Option.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get spacesNotifyOff;

  /// Option help.
  ///
  /// In en, this message translates to:
  /// **'No alerts. Needs you still shows on your Home.'**
  String get spacesNotifyOffHelp;

  /// S15 row and S15d title.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get spacesTransfer;

  /// S15 row.
  ///
  /// In en, this message translates to:
  /// **'Delete Space'**
  String get spacesDeleteSpace;

  /// S15 row.
  ///
  /// In en, this message translates to:
  /// **'Owners only. Removes it for everyone.'**
  String get spacesDeleteSpaceHelp;

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

  /// S15 header action, admins.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get spacesEdit;

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
  /// **'Transfer to {name}'**
  String spacesTransferTo(String name);

  /// S15e title.
  ///
  /// In en, this message translates to:
  /// **'Transfer to {name}?'**
  String spacesTransferTitle(String name);

  /// S15e body. Neutral.
  ///
  /// In en, this message translates to:
  /// **'{name} becomes an admin of {space} and you become a member.'**
  String spacesTransferBody(String name, String space);

  /// S15e button.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
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
