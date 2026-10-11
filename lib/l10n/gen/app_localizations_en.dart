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

  @override
  String entryStartingIn(String country) {
    return 'Starting in $country';
  }

  @override
  String get entryWelcomeTitle => 'The construction community around you.';

  @override
  String get entryWelcomeBody =>
      'Meet engineers, foremen, trades and suppliers. Set up your presence when you\'re ready.';

  @override
  String entryBuiltFor(String country) {
    return 'Built for $country construction';
  }

  @override
  String get entryAudience1Title => 'Engineers';

  @override
  String get entryAudience1Body =>
      'Share your projects. Get your work confirmed.';

  @override
  String get entryAudience2Title => 'Site crews and trades';

  @override
  String get entryAudience2Body => 'Show your work. Find the next job.';

  @override
  String get entryAudience3Title => 'Foremen and supervisors';

  @override
  String get entryAudience3Body => 'Run the day\'s work from your phone.';

  @override
  String get entryAudience4Title => 'Subcontractors';

  @override
  String get entryAudience4Body => 'Get work checked and signed off on time.';

  @override
  String get entryAudience5Title => 'Suppliers and traders';

  @override
  String get entryAudience5Body => 'Be found by the people who build.';

  @override
  String get entryAudience6Title => 'BIM and design';

  @override
  String get entryAudience6Body => 'Connect the model to the work on site.';

  @override
  String get entryBrowseFirstNote =>
      'Browse first. Set up your presence when you\'re ready.';

  @override
  String get entryCreateAccount => 'Create account';

  @override
  String get entrySignIn => 'Sign in';

  @override
  String get entrySkipToHome => 'Skip to Home';

  @override
  String get entryJoinTitle =>
      'Your work, confirmed by the people who built it.';

  @override
  String get entryJoinBody =>
      'Join with the number you already use. It takes about a minute.';

  @override
  String get entrySampleName => 'Sami Al-Mansour';

  @override
  String get entrySampleRole => 'BIM Manager · Harbour Tower';

  @override
  String get entrySampleBadge => 'Confirmed by teammates';

  @override
  String get entryContinuePhone => 'Continue with phone number';

  @override
  String get entryOrContinueWith => 'or continue with';

  @override
  String get entryGoogle => 'Google';

  @override
  String get entryApple => 'Apple';

  @override
  String get entryLinkedIn => 'LinkedIn';

  @override
  String get entryUseEmail => 'Use email instead';

  @override
  String get entryNoPassword =>
      'No password. We never post for you or read your contacts.';

  @override
  String get entryTerms =>
      'By continuing you agree to the Terms and Privacy Policy.';

  @override
  String get entryJustLooking => 'Just looking? Browse first';

  @override
  String get phoneTitle => 'Your phone number';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneHelpWhatsapp =>
      'We send a 6-digit code on WhatsApp. No password needed.';

  @override
  String get phoneHelpSms =>
      'We send a 6-digit code by SMS. No password needed.';

  @override
  String get phoneSendSms => 'Send the code by SMS instead';

  @override
  String get phoneUseEmail => 'Use your email instead';

  @override
  String get sendCode => 'Send code';

  @override
  String phoneErrorMarket(String country, int digits) {
    return 'Enter a $country mobile number with $digits digits.';
  }

  @override
  String get phoneErrorOther => 'Enter your full mobile number.';

  @override
  String get dialCodeTitle => 'Country code';

  @override
  String get dialCodeOther => 'Other country code';

  @override
  String get dialCodeOtherHelp => 'Type the code, for example +91.';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get notOpenTitle => 'New accounts aren\'t open for this number yet';

  @override
  String notOpenSoon(String country) {
    return 'We\'re coming to $country soon. If someone invited you to a Space, open their invite link to join now.';
  }

  @override
  String notOpenOther(String countries) {
    return 'New accounts are open in $countries for now. If someone invited you to a Space, open their invite link to join now.';
  }

  @override
  String get commonOk => 'OK';

  @override
  String get emailTitle => 'Your email';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHelp => 'We send a 6-digit code. No password needed.';

  @override
  String get emailError => 'Check the email address.';

  @override
  String get emailUsePhone => 'Use your phone number instead';

  @override
  String get codeTitleWhatsapp => 'Check WhatsApp';

  @override
  String get codeTitleSms => 'Check your messages';

  @override
  String get codeTitleEmail => 'Check your email';

  @override
  String codeSentWhatsapp(String destination) {
    return 'We sent a 6-digit code to $destination on WhatsApp. It works for 10 minutes.';
  }

  @override
  String codeSentSms(String destination) {
    return 'We sent a 6-digit code to $destination by SMS. It works for 10 minutes.';
  }

  @override
  String codeSentEmail(String destination) {
    return 'We sent a 6-digit code to $destination. It works for 10 minutes. Check spam if you don\'t see it.';
  }

  @override
  String codeResendIn(String time) {
    return 'Resend code in $time';
  }

  @override
  String get codeResend => 'Send a new code';

  @override
  String get codeDifferentNumber => 'Use a different number';

  @override
  String get codeDifferentEmail => 'Use a different email';

  @override
  String get codeWrong => 'That code isn\'t right. Check it and try again.';

  @override
  String get codeExpired => 'This code has expired. Send a new one.';

  @override
  String get codeFieldLabel => '6-digit code';

  @override
  String get errorNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get errorTooMany => 'Too many tries. Wait a minute and try again.';

  @override
  String get errorGeneric => 'Something went wrong. Try again.';

  @override
  String get errorSendFailed =>
      'We couldn\'t send the code. Try again, or use email instead.';

  @override
  String get commonRetry => 'Try again';

  @override
  String get aboutTitle => 'About you';

  @override
  String get aboutIntro =>
      'Step 1 of 2. This is how people will find you. You can change it later.';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get country => 'Country';

  @override
  String get countryFromPhone =>
      'From your phone number. You can change it in Settings.';

  @override
  String get role => 'Role';

  @override
  String get rolePlaceholder => 'Choose your role';

  @override
  String get companyOptional => 'Company (optional)';

  @override
  String get companyPlaceholder => 'Search or type your company';

  @override
  String get recoveryEmail => 'Email for getting back in (optional)';

  @override
  String get recoveryEmailHelp =>
      'Helps you get back in if your number changes.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get firstNameRequired => 'Write your first name.';

  @override
  String get lastNameRequired => 'Write your last name.';

  @override
  String get roleRequired => 'Choose your role.';

  @override
  String get countryRequired => 'Choose your country.';

  @override
  String get companySheetTitle => 'Your company';

  @override
  String get companySearch => 'Search companies';

  @override
  String companyUseTyped(String name) {
    return 'Use “$name”';
  }

  @override
  String get companyUseTypedHelp =>
      'Saved as you typed it. It links to a company page only if one is registered.';

  @override
  String get companyNone => 'No company';

  @override
  String get roleTitle => 'Your role';

  @override
  String get roleIntro =>
      'What do you do on site or in the office? It shows under your name and decides which people and Spaces you see first.';

  @override
  String get roleSearch => 'Search trade or role';

  @override
  String rolePopularIn(String country) {
    return 'POPULAR IN $country';
  }

  @override
  String roleAddCustom(String text) {
    return 'Add “$text” as your role';
  }

  @override
  String get roleNotInList =>
      'Not in the list? Type it in search and add it as your role.';

  @override
  String get save => 'Save';

  @override
  String get peopleTitle => 'People to follow';

  @override
  String get skip => 'Skip';

  @override
  String stepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get peopleHeadline => 'Start with people you\'d work with';

  @override
  String peopleBody(String role, String country) {
    return 'Picked for a $role in $country. You can change this any time.';
  }

  @override
  String peopleFromCompany(String company) {
    return 'FROM $company';
  }

  @override
  String get peopleNearYou => 'WORKING NEAR YOU';

  @override
  String get reasonCompany => 'Your company';

  @override
  String reasonNear(String place) {
    return 'Near you · $place';
  }

  @override
  String reasonSameCountry(String country) {
    return 'Works in $country';
  }

  @override
  String get follow => 'Follow';

  @override
  String get following => 'Following';

  @override
  String get peopleEmpty =>
      'No suggestions yet. As your team joins BuildVibes, you\'ll see them here.';

  @override
  String get joinWallTitle => 'Join BuildVibes to do this';

  @override
  String get joinWallBody => 'It takes about a minute. No password.';

  @override
  String get guestProfileTitle => 'You\'re browsing as a guest';

  @override
  String get signOut => 'Sign out';
}
