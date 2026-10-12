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
  String get entryAudience2Body =>
      'Show your work. Get it confirmed by your team.';

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
  String get role => 'Role';

  @override
  String get rolePlaceholder => 'Choose your role';

  @override
  String get companyOptional => 'Company (optional)';

  @override
  String get companyPlaceholder => 'Search or type your company';

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

  @override
  String profileFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count followers',
      one: '1 follower',
    );
    return '$_temp0';
  }

  @override
  String profileFollowing(int count) {
    return '$count following';
  }

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileTabOverview => 'Overview';

  @override
  String get profileTabPosts => 'Posts';

  @override
  String get profileTabProjects => 'Projects';

  @override
  String get profileTabExperience => 'Experience';

  @override
  String get proofLabel => 'PROOF · WHERE IT\'S CONFIRMED';

  @override
  String get proofConfirmed => 'Confirmed';

  @override
  String get proofWaiting => 'Waiting';

  @override
  String get proofEmptyTitle => 'Add a project to start your proof';

  @override
  String get proofEmptyBody =>
      'Projects on your CV show here. Teammates in your Spaces confirm them.';

  @override
  String get finishProfileTitle => 'Finish your profile';

  @override
  String finishProfileProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get openToTitle => 'Open to';

  @override
  String get openToContract => 'Contract';

  @override
  String get openToConsulting => 'Consulting';

  @override
  String get openToFullTime => 'Full-time role';

  @override
  String get openToPartTime => 'Part-time';

  @override
  String get openToMentoring => 'Mentoring';

  @override
  String get openToOnlyYou => 'Only you see this.';

  @override
  String get openToConnectionsOnly => 'Only your connections see this.';

  @override
  String get profileAbout => 'About';

  @override
  String get profileSeeAllProjects => 'See all projects';

  @override
  String get workDeliveredTitle => 'Work you delivered';

  @override
  String get workDeliveredVisitorTitle => 'Work delivered';

  @override
  String get workDeliveredBody =>
      'You choose what shows. Only items checked and closed in a Space.';

  @override
  String get workDeliveredEmpty => 'Nothing checked yet.';

  @override
  String get experienceEmpty => 'No experience added yet.';

  @override
  String get projectsEmpty => 'No projects on the CV yet.';

  @override
  String get postsEmpty => 'No posts yet.';

  @override
  String get present => 'Present';

  @override
  String expectedMonth(String month) {
    return 'Expected $month';
  }

  @override
  String dateRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get profileMore => 'More';

  @override
  String blockPerson(String name) {
    return 'Block $name';
  }

  @override
  String blockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockConfirmBody =>
      'You won\'t see each other\'s profiles, and follows between you are removed. They aren\'t told.';

  @override
  String get block => 'Block';

  @override
  String get profileNotFound => 'This profile isn\'t available.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get saved => 'Saved';

  @override
  String get editBasics => 'Name, photo and headline';

  @override
  String get editAboutEmpty => 'Add a few lines about your work';

  @override
  String get editProjectsSub => 'Visibility per project';

  @override
  String get editOpenToEmpty => 'Say what you\'re open to';

  @override
  String get headline => 'Headline';

  @override
  String get headlineHint => 'e.g. BIM Manager';

  @override
  String get addPhoto => 'Add a photo';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get placeLabel => 'City or area';

  @override
  String get placeOptional => 'City or area (optional)';

  @override
  String get aboutHint => 'What do you do, and on which kind of projects?';

  @override
  String get experienceAdd => 'Add experience';

  @override
  String get experienceEdit => 'Edit experience';

  @override
  String get titleLabel => 'Title';

  @override
  String get titleRequired => 'Write the title.';

  @override
  String get startedLabel => 'Started';

  @override
  String get endedLabel => 'Ended';

  @override
  String get startRequired => 'Choose when it started.';

  @override
  String get whoCanSee => 'Who can see this';

  @override
  String get visibilityEveryone => 'Everyone';

  @override
  String get visibilityEveryoneSub => 'Anyone signed in to BuildVibes.';

  @override
  String get visibilityConnections => 'Connections only';

  @override
  String get visibilityConnectionsSub =>
      'People you follow who follow you back.';

  @override
  String get visibilityOnlyMe => 'Only me';

  @override
  String get visibilityOnlyMeSub => 'Nobody else can see it.';

  @override
  String get delete => 'Delete';

  @override
  String get openToNote => 'A short note (optional)';

  @override
  String get openToNoteHint => 'e.g. Available from next month';

  @override
  String get cvShowOnProfile => 'Show on my profile';

  @override
  String get addProject => 'Add a project';

  @override
  String get projectSearchHint => 'Project name';

  @override
  String get addProjectIntro =>
      'One record per project, so everyone who worked on it shows up in one place.';

  @override
  String get matchSameName => 'SAME NAME';

  @override
  String get matchSameSite => 'SAME SITE';

  @override
  String get thisIsIt => 'This is it · add to my CV';

  @override
  String get startNewRecord => 'None of these? Start a new record';

  @override
  String get startNewRecordSub =>
      'Name, type, dates and your role. About a minute.';

  @override
  String get onYourCvBadge => 'On your CV';

  @override
  String cvEntryTitle(String project) {
    return 'Your role on $project';
  }

  @override
  String get yourRole => 'Your role';

  @override
  String get roleTitleRequired => 'Write your role.';

  @override
  String get addToCv => 'Add to my CV';

  @override
  String get newProjectTitle => 'New project';

  @override
  String get projectRecordLabel => 'PROJECT RECORD';

  @override
  String get draftStamp => 'REV A · DRAFT';

  @override
  String get sharedRecordStamp => 'SHARED RECORD · NO OWNER';

  @override
  String get cellProjectName => 'PROJECT NAME';

  @override
  String get cellType => 'TYPE';

  @override
  String get cellLocation => 'LOCATION';

  @override
  String get cellStarted => 'STARTED';

  @override
  String get cellEnded => 'ENDED';

  @override
  String get cellYourRole => 'YOUR ROLE';

  @override
  String get choose => 'Choose';

  @override
  String get newProjectNote =>
      'This defines the project and puts it on your CV with your role. Nobody owns a project; anyone who worked on it can add it to their own CV.';

  @override
  String get projectNameRequired => 'Write the project name.';

  @override
  String get projectTypeRequired => 'Choose the type.';

  @override
  String get projectNameHint => 'e.g. Al Kout Mall Phase 2';

  @override
  String get projectTitle => 'Project';

  @override
  String get projectNoOwnerNote =>
      'Anyone can put this project on their CV. Nobody owns it; corrections are checked by BuildVibes.';

  @override
  String get suggestEdit => 'Suggest an edit';

  @override
  String get onYourCv => 'ON YOUR CV';

  @override
  String get peopleOnProject => 'PEOPLE WHO PUT IT ON THEIR CV';

  @override
  String get peopleOnProjectNote =>
      'Only people who chose to show it on their profile.';

  @override
  String get peopleOnProjectEmpty => 'Nobody else has shown it yet.';

  @override
  String suggestTitle(String project) {
    return 'Suggest an edit to $project';
  }

  @override
  String get suggestBody =>
      'Nobody owns this record, so BuildVibes checks every change. People who listed it are told when it changes.';

  @override
  String get whatsWrong => 'WHAT\'S WRONG';

  @override
  String get wrongName => 'Name';

  @override
  String get wrongType => 'Type';

  @override
  String get wrongLocation => 'Location';

  @override
  String get wrongDates => 'Dates';

  @override
  String get wrongDuplicate => 'It\'s a duplicate';

  @override
  String get correctValue => 'Correct value';

  @override
  String get correctValueHelp =>
      'Add a source if you have one, such as a site board photo.';

  @override
  String get correctValueRequired => 'Write the correct value.';

  @override
  String get sendForReview => 'Send for review';

  @override
  String get suggestionSent => 'Thanks. We\'ll check it.';

  @override
  String get monthPickerPresent => 'Still going';

  @override
  String get entryContinueEmail => 'Continue with email';

  @override
  String get entryJoinBodyEmail =>
      'Join with your email. It takes about a minute.';

  @override
  String get countryChangeLater => 'You can change it in Settings.';

  @override
  String get mobileOptional => 'Mobile number (optional)';

  @override
  String get mobileHelp =>
      'Private: only you see it. It\'s never shown on your profile.';

  @override
  String get homeFeed => 'Feed';

  @override
  String get homeSpaces => 'Spaces';

  @override
  String get spacesProjectSpaces => 'PROJECT SPACES';

  @override
  String spacesNeedsYou(int count) {
    return '$count needs you';
  }

  @override
  String get spacesPrivateWork => 'Private work';

  @override
  String get spacesProjectSpaceLine => 'Private work · project Space';

  @override
  String get spacesEmptyTitle => 'Join your first Space';

  @override
  String get spacesEmptyBody =>
      'A Space is where a project team runs its daily work. Once you join one, your daily report appears here: replies, site updates and anything waiting for you.';

  @override
  String get spacesEmptyFeedNote =>
      'Your feed still shows posts, announcements and celebrations from your network.';

  @override
  String get spacesEnterCode => 'Enter an invite code';

  @override
  String get spacesCodeHint =>
      '6 letters and numbers, from the person who invited you';

  @override
  String spacesInvitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String get spacesAskToJoin => 'Ask to join';

  @override
  String get spacesCodeNotValid =>
      'This code isn\'t valid. Check it with the person who sent it.';

  @override
  String get spacesTooManyTries => 'Too many tries. Try again in an hour.';

  @override
  String get spacesAlreadyMember => 'You\'re already in this Space.';

  @override
  String get spacesDeclinedWait => 'You can ask again tomorrow.';

  @override
  String get spacesRequestSent =>
      'Request sent. The Space admin will confirm you.';

  @override
  String get spacesAlreadyWaiting =>
      'You already asked. Waiting for the Space admin.';

  @override
  String get spacesWaiting => 'Waiting for the Space admin to confirm you';

  @override
  String get spacesCancelRequest => 'Cancel request';

  @override
  String get spacesNotConfirmed => 'Not confirmed';

  @override
  String get spacesDismiss => 'Dismiss';

  @override
  String get spacesNewTitle => 'New Space';

  @override
  String get spacesPreviewLabel => 'HOW IT WILL APPEAR TO MEMBERS';

  @override
  String get spacesNameLabel => 'Name';

  @override
  String get spacesNameHint => 'e.g. Tower B — Site team';

  @override
  String get spacesNameRequired => 'Write a name with at least 2 letters.';

  @override
  String get spacesAboutLabel => 'About (optional)';

  @override
  String get spacesAboutHelp => 'Shown to people you invite.';

  @override
  String get spacesLinkLabel => 'Link to a project (optional)';

  @override
  String get spacesLinkPlaceholder => 'Choose a project';

  @override
  String get spacesLinkHelp =>
      'Linking a project makes this its project Space. Members you confirm get that project confirmed on their profile.';

  @override
  String get spacesCreateButton => 'Create Space';

  @override
  String get spacesLinkTitle => 'Link a project';

  @override
  String get spacesLinkSearch => 'Search your projects';

  @override
  String spacesYourRole(String role) {
    return 'Your role: $role';
  }

  @override
  String get spacesTabWork => 'Work';

  @override
  String get spacesTabChat => 'Chat';

  @override
  String get spacesTabPeople => 'People';

  @override
  String get spacesTabLibrary => 'Library';

  @override
  String get spacesInvitePeople => 'Invite people';

  @override
  String spacesInviteTitle(String space) {
    return 'Invite to $space';
  }

  @override
  String get spacesInviteCode => 'Invite code';

  @override
  String spacesCodeWorksUntil(String date) {
    return 'Works until $date';
  }

  @override
  String get spacesShareCode => 'Share code';

  @override
  String get spacesNewCode => 'New code';

  @override
  String get spacesNewCodeTitle => 'Make a new code?';

  @override
  String get spacesNewCodeNote => 'The old code stops working.';

  @override
  String get spacesInviteHow =>
      'Send the code on WhatsApp or read it out on site. The Space admin confirms each person before they join.';

  @override
  String spacesShareText(String space, String code) {
    return 'Join $space on BuildVibes. Invite code: $code';
  }

  @override
  String get spacesNotFound => 'This Space isn\'t available.';

  @override
  String get spacesNotAllowed => 'You can\'t do that in this Space.';

  @override
  String get spacesTooManyToday =>
      'You made many Spaces today. Try again tomorrow.';

  @override
  String get spacesInviteCodeTag => 'INVITE CODE';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int n) {
    return '${n}h ago';
  }

  @override
  String get timeYesterday => 'yesterday';

  @override
  String timeDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get spacesSearchMembers => 'Search members';

  @override
  String get spacesRequestsTitle => 'REQUESTS TO JOIN · YOU CONFIRM';

  @override
  String spacesAsked(String when) {
    return 'Asked $when';
  }

  @override
  String spacesViaCodeFrom(String name) {
    return 'invite code shared by $name';
  }

  @override
  String get spacesViaCode => 'invite code';

  @override
  String get spacesDecline => 'Decline';

  @override
  String get spacesConfirm => 'Confirm';

  @override
  String get spacesOwners => 'Owners';

  @override
  String get spacesOwnerTag => 'Owner';

  @override
  String get spacesMembers => 'Members';

  @override
  String get spacesYouTag => 'You';

  @override
  String get spacesNoMatch => 'No one matches.';

  @override
  String get spacesPassLead => 'Lead';

  @override
  String get spacesPassCrew => 'Crew';

  @override
  String get spacesPassViewer => 'Viewer';

  @override
  String spacesPassLine(String pass) {
    return '$pass pass';
  }

  @override
  String get spacesGivePass => 'GIVE A PASS FOR THIS SPACE';

  @override
  String get spacesLeadOpens =>
      'Opens: create items · check and close · files · invite';

  @override
  String get spacesLeadFor => 'Engineers, supervisors';

  @override
  String get spacesCrewOpens =>
      'Opens: chat · mark own items done with a photo · files';

  @override
  String get spacesCrewFor => 'Foremen, technicians, subcontractors';

  @override
  String get spacesViewerOpens => 'Opens: read and chat only';

  @override
  String get spacesViewerFor => 'Client, supplier';

  @override
  String spacesConfirmAs(String pass) {
    return 'Confirm as $pass';
  }

  @override
  String spacesJoinedAs(String name, String pass) {
    return '$name joined as $pass. The Space is open to them now.';
  }

  @override
  String spacesDeclined(String name) {
    return '$name\'s request declined. They aren\'t told why.';
  }

  @override
  String get spacesUndo => 'Undo';

  @override
  String get spacesAlreadyAnswered => 'This request was already answered.';

  @override
  String get spacesMemberTitle => 'Member';

  @override
  String get spacesPassOpens => 'THIS PASS OPENS';

  @override
  String spacesPassCustom(String pass) {
    return '$pass · CUSTOM';
  }

  @override
  String spacesConfirmedBy(String name) {
    return 'Confirmed by $name';
  }

  @override
  String get spacesConfirmedByYou => 'Confirmed by you';

  @override
  String get spacesRightChat => 'Chat in Everyone and their Teams';

  @override
  String get spacesRightMarkDone => 'Mark own items done';

  @override
  String get spacesRightFiles => 'Add files to the Library';

  @override
  String get spacesRightCreate => 'Create work items';

  @override
  String get spacesRightCheck => 'Check and close items';

  @override
  String get spacesRightInvite => 'Invite people';

  @override
  String get spacesAlways => 'Always';

  @override
  String get spacesOpenRight => 'Open';

  @override
  String get spacesLockRight => 'Lock';

  @override
  String get spacesChangePass => 'CHANGE PASS';

  @override
  String get spacesTeamsLabel => 'TEAMS';

  @override
  String get spacesMakeAdmin => 'Make admin';

  @override
  String get spacesMakeAdminHelp =>
      'Admins confirm people, give passes and manage the Space.';

  @override
  String get spacesRemove => 'Remove from Space';

  @override
  String spacesRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get spacesRemoveBody => 'Their closed work items stay in the record.';

  @override
  String spacesRightOpened(String right, String name) {
    return '$right: open for $name. The pass shows as Custom.';
  }

  @override
  String spacesRightLocked(String right, String name) {
    return '$right: locked for $name.';
  }

  @override
  String spacesPassChanged(String name, String pass) {
    return '$name now has a $pass pass.';
  }

  @override
  String spacesAdminOn(String name) {
    return '$name is now a Space admin.';
  }

  @override
  String spacesAdminOff(String name) {
    return '$name is no longer a Space admin.';
  }

  @override
  String get spacesTeamsSaved => 'Teams saved.';

  @override
  String get spacesNeedsAdmin =>
      'A Space needs an admin. Make someone else an admin first.';

  @override
  String spacesRemoved(String name) {
    return '$name was removed from the Space.';
  }

  @override
  String get spacesAdminRights => 'Admins have every right in the Space.';

  @override
  String listAnd(String a, String b) {
    return '$a and $b';
  }

  @override
  String listAndOthers(String names) {
    return '$names and others';
  }

  @override
  String get youLower => 'you';

  @override
  String proofConfirmedBy(String names) {
    return 'Confirmed by $names';
  }

  @override
  String get spacesInfoTitle => 'Space info';

  @override
  String get spacesAccess => 'Access';

  @override
  String spacesAccessLinked(String project) {
    return 'Private work · linked to $project';
  }

  @override
  String get spacesInviteRowSub => 'Share the invite code';

  @override
  String spacesOwnersLine(String names) {
    return 'Owners: $names';
  }

  @override
  String get spacesWhoCanInvite => 'Who can invite';

  @override
  String get spacesWhoCanInviteNote =>
      'Every invite still needs a Space admin to confirm the join.';

  @override
  String get spacesInviteAdmins => 'Space admins';

  @override
  String get spacesInviteAdminsHelp => 'Only admins share the invite code.';

  @override
  String get spacesInviteLeads => 'Admins and Leads';

  @override
  String get spacesInviteLeadsHelp =>
      'People with a Lead pass can invite their own crews.';

  @override
  String get spacesInviteEveryone => 'Everyone in the Space';

  @override
  String get spacesInviteEveryoneHelp =>
      'Anyone can share the code. Admins still confirm each join.';

  @override
  String get spacesNotifications => 'Notifications';

  @override
  String get spacesNotificationsNote => 'For this Space only.';

  @override
  String get spacesNotifyAll => 'Everyone posts and my Teams';

  @override
  String get spacesNotifyAllHelp =>
      'Messages in Everyone and in your Teams, plus anything that needs you.';

  @override
  String get spacesNotifyNeedsYou => 'Needs you only';

  @override
  String get spacesNotifyNeedsYouHelp =>
      'Items you own, items to check and people asking to join.';

  @override
  String get spacesNotifyOff => 'Off';

  @override
  String get spacesNotifyOffHelp =>
      'No alerts. Needs you still shows on your Home.';

  @override
  String get spacesTransfer => 'Transfer ownership';

  @override
  String get spacesDeleteSpace => 'Delete Space';

  @override
  String get spacesDeleteSpaceHelp => 'Owners only. Removes it for everyone.';

  @override
  String get spacesDeleteButton => 'Delete';

  @override
  String spacesDeleted(String space) {
    return '$space was deleted.';
  }

  @override
  String get spacesLeave => 'Leave Space';

  @override
  String spacesLeaveTitle(String space) {
    return 'Leave $space?';
  }

  @override
  String get spacesLeaveButton => 'Leave';

  @override
  String spacesLeft(String space) {
    return 'You left $space.';
  }

  @override
  String get spacesEdit => 'Edit';

  @override
  String get spacesEditTitle => 'Edit Space';

  @override
  String get spacesTransferIntro =>
      'Choose a member to become a Space admin. You will stay in the Space as a member.';

  @override
  String spacesTransferTo(String name) {
    return 'Transfer to $name';
  }

  @override
  String spacesTransferTitle(String name) {
    return 'Transfer to $name?';
  }

  @override
  String spacesTransferBody(String name, String space) {
    return '$name becomes an admin of $space and you become a member.';
  }

  @override
  String get spacesTransferButton => 'Transfer';

  @override
  String spacesTransferred(String name) {
    return '$name is now a Space admin. You\'re a member.';
  }

  @override
  String get spacesNoOneToTransfer => 'Confirm someone into the Space first.';

  @override
  String get spacesTeams => 'Teams';

  @override
  String spacesTeamMembers(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n members',
      one: '1 member',
      zero: 'No members yet',
    );
    return '$_temp0';
  }

  @override
  String get spacesInTeam => 'you\'re in it';

  @override
  String get spacesNewTeam => 'New Team';

  @override
  String get spacesTeamName => 'Team name';

  @override
  String get spacesTeamNameHint => 'e.g. MEP Team';

  @override
  String get spacesTeamHelp =>
      'Everyone in the Space can see Team names and members. Only members see its chat.';

  @override
  String get spacesAddMembers => 'Add members';

  @override
  String spacesCreateTeam(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Create Team · $n people',
      one: 'Create Team · 1 person',
      zero: 'Create Team',
    );
    return '$_temp0';
  }

  @override
  String get spacesTeamNameRequired => 'Write a Team name.';

  @override
  String get spacesTeamDuplicate => 'There\'s already a Team with this name.';

  @override
  String spacesTeamIntro(String space) {
    return 'A Team in $space. Posts and threads for this Team are seen only by its members.';
  }

  @override
  String get spacesAddPeople => 'Add people';

  @override
  String get spacesTeamPeopleTitle => 'People in this Team';

  @override
  String get spacesRenameTeam => 'Rename Team';

  @override
  String get spacesDeleteTeam => 'Delete Team';

  @override
  String spacesDeleteTeamTitle(String team) {
    return 'Delete $team?';
  }

  @override
  String get spacesDeleteTeamBody => 'Its members stay in the Space.';

  @override
  String get spacesNoTeamMembers => 'No one in this Team yet.';

  @override
  String spacesDeleteTitle(String space) {
    return 'Delete $space?';
  }

  @override
  String get spacesDeleteBody => 'It\'s removed for everyone.';

  @override
  String get spacesLeaveBodyPrivate =>
      'You will stop seeing its chats and work. To come back, you need a new invite.';

  @override
  String get spacesLastAdmin =>
      'Make someone else an admin first, or delete the Space.';

  @override
  String get workPrivacyLine =>
      'Members are people the Space admin confirmed. Nothing here is visible outside the Space.';

  @override
  String get workFilterAll => 'All';

  @override
  String get workFilterMine => 'Mine';

  @override
  String get workFilterOpen => 'Open';

  @override
  String get workFilterToCheck => 'To check';

  @override
  String get workFilterChecked => 'Checked';

  @override
  String get workSectionNeedsYou => 'NEEDS YOU';

  @override
  String get workSectionOpen => 'OPEN';

  @override
  String get workSectionWaitingCheck => 'WAITING FOR A CHECK';

  @override
  String get workSectionCheckedWeek => 'CHECKED THIS WEEK';

  @override
  String get workSectionCheckedEarlier => 'CHECKED EARLIER';

  @override
  String get workStatusOpen => 'OPEN';

  @override
  String workStatusOpenDue(String date) {
    return 'OPEN · DUE $date';
  }

  @override
  String workStatusOverdue(String date) {
    return 'OPEN · WAS DUE $date';
  }

  @override
  String get workStatusDoneYouCheck => 'DONE · YOU CHECK IT';

  @override
  String get workStatusDoneWaiting => 'DONE · WAITING FOR A CHECK';

  @override
  String workStatusChecked(String date) {
    return 'CHECKED · $date';
  }

  @override
  String get workOwnerYou => 'Owner: you';

  @override
  String workOwner(String name) {
    return 'Owner: $name';
  }

  @override
  String get workFromYou => 'from you';

  @override
  String workFrom(String name) {
    return 'from $name';
  }

  @override
  String workCheckedByLine(String name) {
    return 'checked by $name';
  }

  @override
  String workCheckedBy(String name) {
    return 'Checked by $name';
  }

  @override
  String workPhotos(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos',
      one: '1 photo',
      zero: 'No photo',
    );
    return '$_temp0';
  }

  @override
  String get workSignAsDone => 'Sign as done';

  @override
  String get workCheckIt => 'Check it';

  @override
  String get workNewItem => 'New item';

  @override
  String get workEmptyTitle => 'No work items yet';

  @override
  String get workEmptyCanCreate =>
      'Raise the first one with New item. The owner signs it as done, then it\'s checked.';

  @override
  String get workEmptyCannot =>
      'Items appear here when someone raises one for the team.';

  @override
  String get workNothingNeedsYou => 'Nothing needs you right now.';

  @override
  String get workFilterEmpty => 'Nothing here.';

  @override
  String get workStatusOwnerLeft => 'OWNER LEFT · REASSIGN';

  @override
  String get workReassign => 'Reassign';

  @override
  String get workNewTitle => 'New work item';

  @override
  String get workTakePhoto => 'Take a photo';

  @override
  String get workFromGallery => 'Choose from gallery';

  @override
  String get workRetake => 'Retake';

  @override
  String get workPhotoFirst => 'Start with a photo of the spot.';

  @override
  String workNewStamp(String ref) {
    return 'NEW · $ref';
  }

  @override
  String get workNewStampPlain => 'NEW';

  @override
  String get workTitleHint => 'What needs doing · one line is enough';

  @override
  String get workTitleRequired => 'Write what needs doing.';

  @override
  String get workCellOwner => 'OWNER · ONE PERSON';

  @override
  String get workCellDue => 'DUE';

  @override
  String get workCellPlace => 'PLACE ON SITE';

  @override
  String get workCellTeam => 'TEAM';

  @override
  String get workChoose => 'Choose';

  @override
  String get workOwnerRequired => 'Choose who does it.';

  @override
  String get workNoDue => 'No due date';

  @override
  String get workToday => 'Today';

  @override
  String get workTomorrow => 'Tomorrow';

  @override
  String get workPickDate => 'Pick a date';

  @override
  String get workNoTeam => 'No Team';

  @override
  String get workPlaceHint => 'e.g. Level 2 · Grid C7';

  @override
  String workNewFooter(String owner) {
    return '$owner gets it in Needs you. When it\'s marked done, you check it.';
  }

  @override
  String get workNewFooterNoOwner =>
      'The owner gets it in Needs you. When it\'s marked done, you check it.';

  @override
  String get workCreate => 'Create item';

  @override
  String get workNotSent => 'Not sent yet';

  @override
  String get workRetry => 'Retry';

  @override
  String get workNotSentNote =>
      'Saved on this phone. Retry when the signal is back.';

  @override
  String get workSent => 'Sent.';

  @override
  String get workSignOff => 'SIGN-OFF';

  @override
  String get workEvidence => 'EVIDENCE';

  @override
  String get workPhotosLabel => 'PHOTOS';

  @override
  String get workDiscussion => 'DISCUSSION';

  @override
  String get workAddComment => 'Add a comment';

  @override
  String get workSendComment => 'Send';

  @override
  String get workNoComments => 'No comments yet.';

  @override
  String workWaitingCheckBy(String name) {
    return 'Waiting for $name to check';
  }

  @override
  String get workWaitingCheckBody =>
      'It can be accepted or sent back with a reason.';

  @override
  String workCheckBannerTitle(String name) {
    return '$name marked this done. Check it.';
  }

  @override
  String get workCheckBannerBody =>
      'Look at the photo, then accept it or send it back with a reason.';

  @override
  String get workDoneWaiting => 'Done. Waiting for a check.';

  @override
  String get workClosed => 'Closed. It stays in the Space record.';

  @override
  String workClosedCanShow(String name) {
    return '$name can show it on their profile as work they delivered.';
  }

  @override
  String workClosedBy(String name) {
    return 'Closed by $name';
  }

  @override
  String get workClosedStays => 'It stays in the Space record.';

  @override
  String workSentBackTitle(String reason) {
    return 'Sent back: $reason';
  }

  @override
  String get workReasonPhotoMissing => 'Photo missing';

  @override
  String get workReasonNotAsDrawing => 'Not as per drawing';

  @override
  String get workReasonNotFinished => 'Not finished';

  @override
  String get workReasonOther => 'Other';

  @override
  String get workOwnerLeftTitle => 'The owner left the Space';

  @override
  String get workOwnerLeftBody => 'Give it to someone else to finish.';

  @override
  String workCheckedStamp(String date, String name) {
    return 'CHECKED · $date · $name';
  }

  @override
  String get workYouCheckIt => 'You check it';

  @override
  String get workCheckAndClose => 'Check and close';

  @override
  String get workSendBack => 'Send back';

  @override
  String get workReassignTitle => 'Reassign to';

  @override
  String workReassigned(String name) {
    return '$name owns it now.';
  }

  @override
  String get workItemGone => 'This item isn\'t available.';

  @override
  String workTodayAt(String time) {
    return 'Today $time';
  }

  @override
  String workSignTitle(String ref) {
    return 'Sign DONE on $ref';
  }

  @override
  String workSignBody(String name) {
    return 'Your name and the time go on the sign-off. Add a photo or a note so $name can check it.';
  }

  @override
  String get workAddPhoto => 'Add photo';

  @override
  String get workNote => 'Note';

  @override
  String get workNoteHint => 'What was done';

  @override
  String get workSignNeedsSomething => 'Add a photo or a note.';

  @override
  String get workSigned => 'Signed as done. It\'s waiting for a check.';

  @override
  String get workPendingSignOff => 'Sign-off not sent yet';

  @override
  String workSendBackTitle(String ref, String name) {
    return 'Send $ref back to $name';
  }

  @override
  String workSendBackBody(String name) {
    return 'The tag goes back to Open with your reason written on it, and into $name\'s Needs you.';
  }

  @override
  String get workReason => 'Reason';

  @override
  String workNoteFor(String name) {
    return 'Note for $name';
  }

  @override
  String workSendBackTo(String name) {
    return 'Send back to $name';
  }

  @override
  String get workReasonRequired => 'Choose a reason.';

  @override
  String get workOtherNeedsNote => 'Say what is wrong.';

  @override
  String workSentBack(String name) {
    return 'Sent back to $name.';
  }

  @override
  String workCheckTitle(String ref) {
    return 'Check and close $ref?';
  }

  @override
  String get workCheckBody =>
      'Your name and the time go on the sign-off. It closes and stays in the Space record.';

  @override
  String get workShowOnProfile => 'Show on my profile';

  @override
  String get workShowOnProfileHelp =>
      'Only the title, one photo, the place and who checked it. Never the Space or the discussion.';

  @override
  String workReassignedLine(String from, String to) {
    return 'Reassigned from $from to $to';
  }

  @override
  String get workSomeone => 'someone';

  @override
  String get deliveredTitle => 'Work you delivered';

  @override
  String get deliveredIntro =>
      'Only work items that were checked and closed in a Space. Everything is hidden until you switch it on. Shown items appear on your profile.';

  @override
  String get deliveredShown => 'SHOWN ON PROFILE';

  @override
  String get deliveredHidden => 'Hidden · tap to show';

  @override
  String deliveredCheckedBy(String name, String date) {
    return 'Checked by $name · $date';
  }

  @override
  String get deliveredFooter =>
      'People see who checked each item. Items from a Space you left stay yours to show or hide.';

  @override
  String get deliveredEmpty =>
      'Nothing yet. Work items you own appear here once they\'re checked.';

  @override
  String get deliveredSeeAll => 'See all';

  @override
  String get deliveredPublicTitle => 'Delivered work';

  @override
  String deliveredShownBy(String name) {
    return 'Shown by $name';
  }

  @override
  String get deliveredProject => 'Project';

  @override
  String get deliveredPlace => 'Place';

  @override
  String get deliveredCheckedRow => 'Checked by';

  @override
  String deliveredPrivacy(String name) {
    return '$name chose to show this. The discussion, files and the Space stay private. Only the title, photo, place and who checked it are shown.';
  }

  @override
  String deliveredStamp(String date) {
    return 'CHECKED · $date';
  }
}
