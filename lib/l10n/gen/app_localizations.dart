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

  /// Card status.
  ///
  /// In en, this message translates to:
  /// **'OPEN'**
  String get workStatusOpen;

  /// Card status.
  ///
  /// In en, this message translates to:
  /// **'OPEN · DUE {date}'**
  String workStatusOpenDue(String date);

  /// Card status, past the due date.
  ///
  /// In en, this message translates to:
  /// **'OPEN · WAS DUE {date}'**
  String workStatusOverdue(String date);

  /// Card status.
  ///
  /// In en, this message translates to:
  /// **'DONE · YOU CHECK IT'**
  String get workStatusDoneYouCheck;

  /// Card status.
  ///
  /// In en, this message translates to:
  /// **'DONE · WAITING FOR A CHECK'**
  String get workStatusDoneWaiting;

  /// Card status.
  ///
  /// In en, this message translates to:
  /// **'CHECKED · {date}'**
  String workStatusChecked(String date);

  /// Card people line.
  ///
  /// In en, this message translates to:
  /// **'Owner: you'**
  String get workOwnerYou;

  /// Card people line.
  ///
  /// In en, this message translates to:
  /// **'Owner: {name}'**
  String workOwner(String name);

  /// Card people line.
  ///
  /// In en, this message translates to:
  /// **'from you'**
  String get workFromYou;

  /// Card people line.
  ///
  /// In en, this message translates to:
  /// **'from {name}'**
  String workFrom(String name);

  /// Card people line, Checked.
  ///
  /// In en, this message translates to:
  /// **'checked by {name}'**
  String workCheckedByLine(String name);

  /// Card evidence, Checked.
  ///
  /// In en, this message translates to:
  /// **'Checked by {name}'**
  String workCheckedBy(String name);

  /// Card evidence.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{No photo} =1{1 photo} other{{n} photos}}'**
  String workPhotos(int n);

  /// Card action (glossary).
  ///
  /// In en, this message translates to:
  /// **'Sign as done'**
  String get workSignAsDone;

  /// Card action.
  ///
  /// In en, this message translates to:
  /// **'Check it'**
  String get workCheckIt;

  /// Card status: the owner left the Space (review 09).
  ///
  /// In en, this message translates to:
  /// **'OWNER LEFT · REASSIGN'**
  String get workStatusOwnerLeft;

  /// Card action.
  ///
  /// In en, this message translates to:
  /// **'Reassign'**
  String get workReassign;

  /// W2 fallback.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get workFromGallery;

  /// Outbox card.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get workRetry;

  /// Outbox card.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone. Retry when the signal is back.'**
  String get workNotSentNote;

  /// W3 section (glossary).
  ///
  /// In en, this message translates to:
  /// **'SIGN-OFF'**
  String get workSignOff;

  /// W3 section (glossary).
  ///
  /// In en, this message translates to:
  /// **'EVIDENCE'**
  String get workEvidence;

  /// W3 section: photos from when it was raised.
  ///
  /// In en, this message translates to:
  /// **'PHOTOS'**
  String get workPhotosLabel;

  /// W3 section.
  ///
  /// In en, this message translates to:
  /// **'DISCUSSION'**
  String get workDiscussion;

  /// W3 field.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get workAddComment;

  /// W3 comment button.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get workSendComment;

  /// W3 empty discussion.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get workNoComments;

  /// W3b banner.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to check'**
  String workWaitingCheckBy(String name);

  /// W3b banner.
  ///
  /// In en, this message translates to:
  /// **'It can be accepted or sent back with a reason.'**
  String get workWaitingCheckBody;

  /// W3c banner.
  ///
  /// In en, this message translates to:
  /// **'{name} marked this done. Check it.'**
  String workCheckBannerTitle(String name);

  /// W3c banner.
  ///
  /// In en, this message translates to:
  /// **'Look at the photo, then accept it or send it back with a reason.'**
  String get workCheckBannerBody;

  /// W3 banner for others.
  ///
  /// In en, this message translates to:
  /// **'Done. Waiting for a check.'**
  String get workDoneWaiting;

  /// W3d banner (review 08 wording).
  ///
  /// In en, this message translates to:
  /// **'Closed. It stays in the Space record.'**
  String get workClosed;

  /// W3d banner line.
  ///
  /// In en, this message translates to:
  /// **'{name} can show it on their profile as work they delivered.'**
  String workClosedCanShow(String name);

  /// W3g banner.
  ///
  /// In en, this message translates to:
  /// **'Closed by {name}'**
  String workClosedBy(String name);

  /// W3g banner line.
  ///
  /// In en, this message translates to:
  /// **'It stays in the Space record.'**
  String get workClosedStays;

  /// W3 banner after a send-back.
  ///
  /// In en, this message translates to:
  /// **'Sent back: {reason}'**
  String workSentBackTitle(String reason);

  /// Send back reason.
  ///
  /// In en, this message translates to:
  /// **'Photo missing'**
  String get workReasonPhotoMissing;

  /// Send back reason.
  ///
  /// In en, this message translates to:
  /// **'Not as asked'**
  String get workReasonNotAsAsked;

  /// Send back reason.
  ///
  /// In en, this message translates to:
  /// **'Not finished'**
  String get workReasonNotFinished;

  /// Send back reason.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get workReasonOther;

  /// W3 banner.
  ///
  /// In en, this message translates to:
  /// **'The owner left the Space'**
  String get workOwnerLeftTitle;

  /// W3 banner.
  ///
  /// In en, this message translates to:
  /// **'Give it to someone else to finish.'**
  String get workOwnerLeftBody;

  /// W3d tilted stamp.
  ///
  /// In en, this message translates to:
  /// **'CHECKED · {date} · {name}'**
  String workCheckedStamp(String date, String name);

  /// Sign-off strip.
  ///
  /// In en, this message translates to:
  /// **'You check it'**
  String get workYouCheckIt;

  /// W3c button.
  ///
  /// In en, this message translates to:
  /// **'Check and close'**
  String get workCheckAndClose;

  /// W3c button (glossary).
  ///
  /// In en, this message translates to:
  /// **'Send back'**
  String get workSendBack;

  /// Reassign sheet title.
  ///
  /// In en, this message translates to:
  /// **'Reassign to'**
  String get workReassignTitle;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'{name} owns it now.'**
  String workReassigned(String name);

  /// W3 when gone or not a member.
  ///
  /// In en, this message translates to:
  /// **'This item isn\'t available.'**
  String get workItemGone;

  /// Sign-off time today.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String workTodayAt(String time);

  /// W4 sheet title.
  ///
  /// In en, this message translates to:
  /// **'Sign DONE on {ref}'**
  String workSignTitle(String ref);

  /// W4 sheet body.
  ///
  /// In en, this message translates to:
  /// **'Your name and the time go on the sign-off. Add a photo or a note so {name} can check it.'**
  String workSignBody(String name);

  /// W4 photo tile.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get workAddPhoto;

  /// W4 field.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get workNote;

  /// W4 note placeholder.
  ///
  /// In en, this message translates to:
  /// **'What was done'**
  String get workNoteHint;

  /// W4 error.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or a note.'**
  String get workSignNeedsSomething;

  /// Toast after W4.
  ///
  /// In en, this message translates to:
  /// **'Signed as done. It\'s waiting for a check.'**
  String get workSigned;

  /// Outbox: a sign-off waiting.
  ///
  /// In en, this message translates to:
  /// **'Sign-off not sent yet'**
  String get workPendingSignOff;

  /// W5 sheet title.
  ///
  /// In en, this message translates to:
  /// **'Send {ref} back to {name}'**
  String workSendBackTitle(String ref, String name);

  /// W5 sheet body.
  ///
  /// In en, this message translates to:
  /// **'The tag goes back to Open with your reason written on it, and into {name}\'s Needs you.'**
  String workSendBackBody(String name);

  /// W5 label.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get workReason;

  /// W5 field.
  ///
  /// In en, this message translates to:
  /// **'Note for {name}'**
  String workNoteFor(String name);

  /// W5 button.
  ///
  /// In en, this message translates to:
  /// **'Send back to {name}'**
  String workSendBackTo(String name);

  /// W5 error.
  ///
  /// In en, this message translates to:
  /// **'Choose a reason.'**
  String get workReasonRequired;

  /// W5 error for Other.
  ///
  /// In en, this message translates to:
  /// **'Say what is wrong.'**
  String get workOtherNeedsNote;

  /// Toast after W5.
  ///
  /// In en, this message translates to:
  /// **'Sent back to {name}.'**
  String workSentBack(String name);

  /// Check dialog title.
  ///
  /// In en, this message translates to:
  /// **'Check and close {ref}?'**
  String workCheckTitle(String ref);

  /// Check dialog body.
  ///
  /// In en, this message translates to:
  /// **'Your name and the time go on the sign-off. It closes and stays in the Space record.'**
  String get workCheckBody;

  /// Owner switch on a Checked item (review 08 wording).
  ///
  /// In en, this message translates to:
  /// **'Show on my profile'**
  String get workShowOnProfile;

  /// Switch helper.
  ///
  /// In en, this message translates to:
  /// **'Only the title, one photo, the place and who checked it. Never the Space or the discussion.'**
  String get workShowOnProfileHelp;

  /// Discussion line for a reassigned event.
  ///
  /// In en, this message translates to:
  /// **'Reassigned from {from} to {to}'**
  String workReassignedLine(String from, String to);

  /// A person whose account was deleted.
  ///
  /// In en, this message translates to:
  /// **'someone'**
  String get workSomeone;

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

  /// Check dialog confirm button; short so it fits.
  ///
  /// In en, this message translates to:
  /// **'Close it'**
  String get workCheckConfirm;

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

  /// Wrong file type.
  ///
  /// In en, this message translates to:
  /// **'Only PDF files and photos.'**
  String get chatFileNotAllowed;

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

  /// S13k search.
  ///
  /// In en, this message translates to:
  /// **'Search titles and file names'**
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

  /// W2-A title.
  ///
  /// In en, this message translates to:
  /// **'Attach to {ref}'**
  String workAttachTitle(String ref);

  /// W2-A option.
  ///
  /// In en, this message translates to:
  /// **'From the Space Library'**
  String get workAttachLibrary;

  /// W2-A option helper.
  ///
  /// In en, this message translates to:
  /// **'Drawings and files already shared in this Space'**
  String get workAttachLibraryHelp;

  /// W2-A option.
  ///
  /// In en, this message translates to:
  /// **'From your phone'**
  String get workAttachPhone;

  /// W2-A option helper.
  ///
  /// In en, this message translates to:
  /// **'PDF or image · saved to the Space Library too'**
  String get workAttachPhoneHelp;

  /// W3 section label.
  ///
  /// In en, this message translates to:
  /// **'ATTACHED'**
  String get workAttached;

  /// W3 attached file line.
  ///
  /// In en, this message translates to:
  /// **'From the Space Library'**
  String get workAttachedFromLibrary;

  /// W2 / W3 button.
  ///
  /// In en, this message translates to:
  /// **'Attach a drawing or file'**
  String get workAttach;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Attached.'**
  String get workAttachedToast;

  /// W3 Discussion label suffix (opens the Team thread).
  ///
  /// In en, this message translates to:
  /// **'ALSO IN THE TEAM CHAT'**
  String get workAlsoInTeamChat;

  /// Library picker title.
  ///
  /// In en, this message translates to:
  /// **'Choose from the Library'**
  String get libraryPickTitle;

  /// Library picker helper on a Team item.
  ///
  /// In en, this message translates to:
  /// **'Only files for Everyone and for {team} can go on this item.'**
  String libraryPickTeamNote(String team);

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
  /// **'No posts yet. Share what happened on site today.'**
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

  /// Photo tap tooltip.
  ///
  /// In en, this message translates to:
  /// **'Open photo'**
  String get postOpenPhoto;

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

  /// Composer hint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get postAddComment;

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

  /// P3.
  ///
  /// In en, this message translates to:
  /// **'Posting to your network…'**
  String get postPosting;

  /// P3b / C14.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t post. Saved as a draft.'**
  String get postFailed;

  /// P3b.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get postFailedHint;

  /// P3b secondary action.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get postDiscardDraft;

  /// C1 overline.
  ///
  /// In en, this message translates to:
  /// **'POSTING TO'**
  String get composerPostingTo;

  /// C1 audience.
  ///
  /// In en, this message translates to:
  /// **'Your network'**
  String get composerYourNetwork;

  /// C1 audience line.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get composerEveryone;

  /// C1 audience line.
  ///
  /// In en, this message translates to:
  /// **'tagged {project}'**
  String composerTagged(String project);

  /// C1 placeholder.
  ///
  /// In en, this message translates to:
  /// **'What happened on site today?'**
  String get composerHint;

  /// C1 overline.
  ///
  /// In en, this message translates to:
  /// **'START FROM'**
  String get composerStartFrom;

  /// Template.
  ///
  /// In en, this message translates to:
  /// **'Progress update'**
  String get tplProgress;

  /// Template.
  ///
  /// In en, this message translates to:
  /// **'Done today · Next · Holding us up'**
  String get tplProgressHelp;

  /// Template lines put in the post.
  ///
  /// In en, this message translates to:
  /// **'Done today:\nNext:\nHolding us up:'**
  String get tplProgressLines;

  /// Template.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get tplMilestone;

  /// Template.
  ///
  /// In en, this message translates to:
  /// **'What · When · Who did it'**
  String get tplMilestoneHelp;

  /// Template lines.
  ///
  /// In en, this message translates to:
  /// **'What:\nWhen:\nWho did it:'**
  String get tplMilestoneLines;

  /// Template.
  ///
  /// In en, this message translates to:
  /// **'Site visit'**
  String get tplVisit;

  /// Template.
  ///
  /// In en, this message translates to:
  /// **'Where · What we found · Actions'**
  String get tplVisitHelp;

  /// Template lines.
  ///
  /// In en, this message translates to:
  /// **'Where:\nWhat we found:\nActions:'**
  String get tplVisitLines;

  /// Template.
  ///
  /// In en, this message translates to:
  /// **'Ask the community'**
  String get tplAsk;

  /// Template.
  ///
  /// In en, this message translates to:
  /// **'Question · Who knows'**
  String get tplAskHelp;

  /// Template lines.
  ///
  /// In en, this message translates to:
  /// **'Question:\nWho knows:'**
  String get tplAskLines;

  /// Footer tool.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get composerMedia;

  /// Footer tool.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get composerProject;

  /// Post button.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get composerPost;

  /// Edit post button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get composerSave;

  /// Footer hint.
  ///
  /// In en, this message translates to:
  /// **'Choose how to start, or just write'**
  String get composerChooseHint;

  /// Footer hint when tagged.
  ///
  /// In en, this message translates to:
  /// **'Posting to {project}'**
  String composerPostingToProject(String project);

  /// Audience line (review 16: replaces the member count).
  ///
  /// In en, this message translates to:
  /// **'Everyone on BuildVibes can see this.'**
  String get composerAudience;

  /// Audience line with a project.
  ///
  /// In en, this message translates to:
  /// **'Everyone on BuildVibes can see this. It also shows on the project\'s page.'**
  String get composerAudienceProject;

  /// L5. The language code of the post.
  ///
  /// In en, this message translates to:
  /// **'Written in {lang, select, ar{Arabic} other{English}}'**
  String composerWrittenIn(String lang);

  /// L5 link.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get composerChange;

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

  /// L6 option.
  ///
  /// In en, this message translates to:
  /// **'Detected automatically'**
  String get langAuto;

  /// L6 title.
  ///
  /// In en, this message translates to:
  /// **'Language of this post'**
  String get composerLangTitle;

  /// L6 line under the title.
  ///
  /// In en, this message translates to:
  /// **'We use this to offer Translate to readers who don\'t read it.'**
  String get composerLangWhy;

  /// A language's name in the app's language (L6).
  ///
  /// In en, this message translates to:
  /// **'{lang, select, ar{Arabic} other{English}}'**
  String langName(String lang);

  /// Too many photos.
  ///
  /// In en, this message translates to:
  /// **'Up to 4 photos.'**
  String get composerPhotosMax;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get composerRemovePhoto;

  /// C3 title.
  ///
  /// In en, this message translates to:
  /// **'Post to'**
  String get postToTitle;

  /// C3 overline.
  ///
  /// In en, this message translates to:
  /// **'WHO SEES IT'**
  String get postToWho;

  /// C3 row.
  ///
  /// In en, this message translates to:
  /// **'Followers and Explore · anyone can see'**
  String get postToNetworkHelp;

  /// C3 note.
  ///
  /// In en, this message translates to:
  /// **'Posts are public and can be tagged to a project. Work for your team goes in the project\'s Space as a work item.'**
  String get postToNote;

  /// C10 title.
  ///
  /// In en, this message translates to:
  /// **'Link a project'**
  String get tagTitle;

  /// C10.
  ///
  /// In en, this message translates to:
  /// **'Only projects where you have a confirmed role.'**
  String get tagHelp;

  /// C10 empty.
  ///
  /// In en, this message translates to:
  /// **'Add a project on your profile first'**
  String get tagEmpty;

  /// C10 line.
  ///
  /// In en, this message translates to:
  /// **'Work for your team goes in the project\'s Space as a work item'**
  String get tagSpaceNote;

  /// C10: remove the tag.
  ///
  /// In en, this message translates to:
  /// **'No project'**
  String get tagNone;

  /// C13.
  ///
  /// In en, this message translates to:
  /// **'Discard this post?'**
  String get discardTitle;

  /// C13.
  ///
  /// In en, this message translates to:
  /// **'Your text, photo and project link will be lost.'**
  String get discardBody;

  /// C13.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardConfirm;

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

  /// Short time on cards.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNowShort;

  /// Short minutes on cards.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String timeMinutesShort(int n);

  /// Short hours on cards.
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String timeHoursShort(int n);

  /// C13 cancel.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get discardKeep;

  /// H1b title.
  ///
  /// In en, this message translates to:
  /// **'Your day on site'**
  String get homeDayTitle;

  /// H1b summary, first part (orange).
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 thing needs you} other{{n} things need you}}'**
  String homeDayNeedsYou(int n);

  /// H1b summary: Spaces with something new today.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 Space active} other{{n} Spaces active}}'**
  String homeDaySpacesActive(int n);

  /// H1b summary: replies today to your chat messages.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 reply} other{{n} replies}}'**
  String homeDayReplies(int n);

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

  /// H1b section.
  ///
  /// In en, this message translates to:
  /// **'TODAY IN YOUR SPACES'**
  String get homeTodayInSpaces;

  /// H1b end, when nothing needs you.
  ///
  /// In en, this message translates to:
  /// **'That\'s your day'**
  String get homeThatsYourDay;

  /// H1b end line.
  ///
  /// In en, this message translates to:
  /// **'Nothing else needs you right now'**
  String get homeNothingElse;

  /// H1b row: the Space is linked to a project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get homeProject;

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

  /// A1 overline.
  ///
  /// In en, this message translates to:
  /// **'WORK ITEM · FOR YOU'**
  String get needsOverForYou;

  /// A1 overline.
  ///
  /// In en, this message translates to:
  /// **'WORK ITEM · YOU CHECK IT'**
  String get needsOverCheck;

  /// A1 overline.
  ///
  /// In en, this message translates to:
  /// **'WORK ITEM · SENT BACK'**
  String get needsOverSentBack;

  /// A1 overline.
  ///
  /// In en, this message translates to:
  /// **'WORK ITEM · OWNER LEFT'**
  String get needsOverOwnerLeft;

  /// A1 overline.
  ///
  /// In en, this message translates to:
  /// **'SPACE · REQUEST TO JOIN'**
  String get needsOverJoin;

  /// Needs-you button.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get needsOpen;

  /// A1 button for an item to check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get needsCheck;

  /// A1 button for a join request.
  ///
  /// In en, this message translates to:
  /// **'Review request'**
  String get needsReview;

  /// H1b row: a work item event.
  ///
  /// In en, this message translates to:
  /// **'{event, select, done{{name} signed {ref} as done} checked{{name} checked {ref}} sent_back{{name} sent {ref} back} comment{{name} commented on {ref}} reassigned{{name} reassigned {ref}} other{{name} raised {ref}}}: {title}'**
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

  /// A1 section: your own count.
  ///
  /// In en, this message translates to:
  /// **'NEEDS YOU · {n}'**
  String activityNeedsHeader(int n);

  /// A1 section.
  ///
  /// In en, this message translates to:
  /// **'CHANGES TO YOUR RECORD'**
  String get activityChanges;

  /// A1 section line.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get activityLast7;

  /// A1 group line.
  ///
  /// In en, this message translates to:
  /// **'Space · your pass: {pass}'**
  String activitySpaceLine(String pass);

  /// A1 group.
  ///
  /// In en, this message translates to:
  /// **'Your record'**
  String get activityGroupRecord;

  /// A1 group.
  ///
  /// In en, this message translates to:
  /// **'Your network'**
  String get activityGroupNetwork;

  /// A1 group.
  ///
  /// In en, this message translates to:
  /// **'Your posts'**
  String get activityGroupPosts;

  /// A1 group stamp; letters stay Latin.
  ///
  /// In en, this message translates to:
  /// **'REV {letter}'**
  String activityRev(String letter);

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'{name} gave you {ref}'**
  String activityAssigned(String name, String ref);

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'{name} signed {ref} as done'**
  String activityDone(String name, String ref);

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'{name} checked {ref}'**
  String activityChecked(String name, String ref);

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'{name} sent {ref} back'**
  String activitySentBack(String name, String ref);

  /// A1 row.
  ///
  /// In en, this message translates to:
  /// **'{name} commented on {ref}'**
  String activityComment(String name, String ref);

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
  /// **'New follower: {name}'**
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

  /// A1 status chip.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get chipAssigned;

  /// A1 status chip (glossary).
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get chipDone;

  /// A1 status chip (glossary).
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get chipChecked;

  /// A1 status chip.
  ///
  /// In en, this message translates to:
  /// **'Sent back'**
  String get chipSentBack;

  /// A1 status chip.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get chipComment;

  /// A1 status chip: a request to join confirmed.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get chipApproved;

  /// A1 status chip: a role confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get chipConfirmed;

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

  /// H1b row time, on its own.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get rowJustNow;

  /// H1b row time.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 min ago} other{{n} min ago}}'**
  String rowMinutesAgo(int n);

  /// H1b row time, as drawn ("3h ago" / "قبل 3 ساعات").
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String rowHoursAgo(int n);

  /// H1b row time.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get rowYesterday;

  /// H1b row time.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day ago} other{{n} days ago}}'**
  String rowDaysAgo(int n);

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

  /// R1 title. kind: post, reply, message, profile.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, post{Report this post} reply{Report this reply} message{Report this message} other{Report this account}}'**
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

  /// A1 chip.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get chipRemoved;

  /// A1 chip.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get chipRestored;

  /// S1 header link.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get settingsViewProfile;

  /// S1 section.
  ///
  /// In en, this message translates to:
  /// **'YOUR SETTINGS, IN WORDS'**
  String get settingsInWords;

  /// S1 words row label.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get settingsPrivacyLabel;

  /// S1 words row label.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get settingsNotificationsLabel;

  /// S1 words row label; S8 section.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsLanguageLabel;

  /// S1 privacy words: your own count.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 blocked account} other{{n} blocked accounts}}'**
  String wordsBlocked(int n);

  /// S1 privacy words; {what} is highlighted.
  ///
  /// In en, this message translates to:
  /// **'{what}. Work items, chat and the Library stay inside each Space.'**
  String wordsPrivacy(String what);

  /// S1 notification words; the three values are highlighted.
  ///
  /// In en, this message translates to:
  /// **'New followers: {followers}. Replies: {replies}. Message text on the lock screen: {lockText}.'**
  String wordsNotifications(String followers, String replies, String lockText);

  /// S1: a switch that is on.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get wordsOn;

  /// S1: a switch that is off.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get wordsOff;

  /// S1: message text shown on the lock screen.
  ///
  /// In en, this message translates to:
  /// **'shown'**
  String get wordsShown;

  /// S1: message text hidden on the lock screen.
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get wordsHidden;

  /// S1 language words, all from the market pack; {language} is highlighted.
  ///
  /// In en, this message translates to:
  /// **'{language}. The week starts on {weekday}, in {country} time.'**
  String wordsLanguage(String language, String weekday, String country);

  /// S1 language words with no home market.
  ///
  /// In en, this message translates to:
  /// **'{language}.'**
  String wordsLanguageOnly(String language);

  /// S1 section.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get settingsAccountSection;

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

  /// S1 section.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get supportSection;

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
  /// **'Transfer ownership first'**
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

  /// Masthead date line when the Space has an On site since date (D1).
  ///
  /// In en, this message translates to:
  /// **'{date}, day {day} on site'**
  String daybookDateLine(String date, int day);

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
  /// **'{who}, {due}'**
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

  /// Late line on an open item past its due (L1). 0: late today, after its time.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{Late} =1{Late by 1 day} other{Late by {n} days}}'**
  String daybookLate(int n);

  /// Strip under the masthead (L1): items due today for you or by you.
  ///
  /// In en, this message translates to:
  /// **'Due today: {titles}'**
  String daybookDueTodayStrip(String titles);

  /// Slip chip: checklist points on a work item.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 point} other{{n} points}}'**
  String daybookPoints(int n);

  /// Slip history line after the due was edited.
  ///
  /// In en, this message translates to:
  /// **'Edited: due moved from {from} to {to}'**
  String daybookEditedDue(String from, String to);

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

  /// Meta line of a cancelled work item.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by {name} at {time}'**
  String daybookCancelledBy(String name, String time);

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
