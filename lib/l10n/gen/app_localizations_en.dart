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
  String get settingsLanguageRow => 'Language';

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
  String get signOffChecked => 'CHECKED';

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
      'You won\'t see each other\'s posts or profiles, and follows between you are removed. They aren\'t told.';

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
  String get spacesEmptyTitle => 'Join your first Space';

  @override
  String get spacesEmptyBody =>
      'A Space is where a project team runs its daily work. Once you join one, your daily report appears here: replies, updates and anything waiting for you.';

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
  String get spacesNameHint => 'e.g. Tower B — Design team';

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
      'Send the code on WhatsApp or read it out. The Space admin confirms each person before they join.';

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
  String get spacesDecline => 'Decline';

  @override
  String get spacesYouTag => 'You';

  @override
  String get spacesPassLead => 'Lead';

  @override
  String get spacesPassCrew => 'Crew';

  @override
  String get spacesPassViewer => 'Viewer';

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
  String proofConfirmedBy(String names) {
    return 'Confirmed by $names';
  }

  @override
  String get spacesInfoTitle => 'Space info';

  @override
  String get spacesWhoCanInvite => 'Who can invite';

  @override
  String get spacesNotifications => 'Notifications';

  @override
  String get spacesNotifyOff => 'Off';

  @override
  String get spacesTransfer => 'Hand over Space admin';

  @override
  String get spacesDeleteSpace => 'Delete Space';

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
  String get spacesEditTitle => 'Edit Space';

  @override
  String get spacesTransferIntro =>
      'Choose a member to become a Space admin. You will stay in the Space as a member.';

  @override
  String spacesTransferTo(String name) {
    return 'Hand over to $name';
  }

  @override
  String spacesTransferTitle(String name) {
    return 'Hand over to $name?';
  }

  @override
  String spacesTransferBody(String name, String space) {
    return '$name becomes an admin of $space and you become a member.';
  }

  @override
  String get spacesTransferButton => 'Hand over';

  @override
  String spacesTransferred(String name) {
    return '$name is now a Space admin. You\'re a member.';
  }

  @override
  String get spacesNoOneToTransfer => 'Confirm someone into the Space first.';

  @override
  String get spacesTeams => 'Teams';

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
  String get workItemGone => 'This item isn\'t available.';

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
  String get deliveredNoneShown =>
      'Nothing shown yet. Tap See all to choose what shows.';

  @override
  String deliveredCheckedOn(String date) {
    return 'Checked · $date';
  }

  @override
  String get deliveredCheckedRowNoName => 'Checked';

  @override
  String get chatEveryone => 'Everyone';

  @override
  String get chatTeam => 'Team';

  @override
  String get chatThreadsNote => 'You see threads for Everyone and your Teams.';

  @override
  String get chatThreadsNoteAdmin =>
      'As a Space admin, you see Everyone and every Team.';

  @override
  String get chatNoMessages => 'No messages yet.';

  @override
  String get chatYou => 'You';

  @override
  String chatLastLine(String name, String text) {
    return '$name: $text';
  }

  @override
  String get chatPhoto => 'Photo';

  @override
  String get chatFile => 'File';

  @override
  String get chatVoice => 'Voice note';

  @override
  String get chatWorkItemUpdate => 'Work item update';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String chatTeamPrivacy(String team) {
    return 'Only $team and the Space admins see this thread.';
  }

  @override
  String get chatMessageHint => 'Message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatDeleted => 'Message deleted';

  @override
  String get chatSending => 'Sending…';

  @override
  String get chatNotSent => 'Not sent';

  @override
  String get chatRetry => 'Retry';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatCopied => 'Copied.';

  @override
  String get chatDelete => 'Delete message';

  @override
  String get chatDeleteTitle => 'Delete this message?';

  @override
  String get chatDeleteBody =>
      'Everyone in this thread sees “Message deleted” instead.';

  @override
  String get chatDeleteConfirm => 'Delete';

  @override
  String chatReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get chatCancelReply => 'Cancel reply';

  @override
  String chatCardRaised(String name) {
    return '$name raised a work item';
  }

  @override
  String chatCardDone(String name) {
    return '$name marked a work item done';
  }

  @override
  String chatCardChecked(String name) {
    return '$name checked and closed a work item';
  }

  @override
  String chatCardSentBack(String name) {
    return '$name sent a work item back';
  }

  @override
  String chatCardReassigned(String name) {
    return '$name reassigned a work item';
  }

  @override
  String get chatCardHidden => 'Work item';

  @override
  String chatLastRaised(String name, String ref) {
    return '$name raised $ref';
  }

  @override
  String chatLastDone(String name, String ref) {
    return '$name marked $ref done';
  }

  @override
  String chatLastChecked(String name, String ref) {
    return '$name checked and closed $ref';
  }

  @override
  String chatLastSentBack(String name, String ref) {
    return '$name sent $ref back';
  }

  @override
  String chatLastReassigned(String name, String ref) {
    return '$name reassigned $ref';
  }

  @override
  String get chatAttach => 'Add a photo or file';

  @override
  String get chatAttachCamera => 'Take a photo';

  @override
  String get chatAttachGallery => 'Photo from your phone';

  @override
  String get chatAttachPdf => 'PDF from your phone';

  @override
  String get chatAttachPdfHelp => 'It goes to the Space Library too.';

  @override
  String get chatRemoveFile => 'Remove';

  @override
  String get chatFileTooBig => 'Files up to 25 MB.';

  @override
  String get chatOneDocument => 'One PDF per message.';

  @override
  String fileSizeMb(String size) {
    return '$size MB';
  }

  @override
  String fileSizeKb(String size) {
    return '$size KB';
  }

  @override
  String get librarySearch => 'Search files';

  @override
  String get libraryFiles => 'Files';

  @override
  String get libraryFromChat => 'From chat';

  @override
  String get libraryEmpty =>
      'No files yet. Drawings and photos shared in this Space appear here.';

  @override
  String get libraryNoMatch => 'Nothing matches.';

  @override
  String previewFrom(String name) {
    return 'from $name';
  }

  @override
  String previewCurrent(String rev) {
    return '$rev · CURRENT';
  }

  @override
  String get previewCurrentNoRev => 'CURRENT';

  @override
  String previewUploaded(String date) {
    return 'Uploaded $date';
  }

  @override
  String get previewUsedIn => 'Used in';

  @override
  String get previewSuperseded => 'superseded, kept in the record';

  @override
  String get previewReplaced => 'A newer revision replaced this one.';

  @override
  String get previewOpenCurrent => 'Open the current one';

  @override
  String get previewShare => 'Share in chat';

  @override
  String get previewDownload => 'Download';

  @override
  String get previewShareTo => 'Share in which thread?';

  @override
  String get previewShareTeamOnly =>
      'A Team file is shared in its Team\'s thread only.';

  @override
  String get previewSaved => 'Saved.';

  @override
  String get previewCantShow =>
      'This file can\'t be shown here. Download it to open it.';

  @override
  String get previewClose => 'Close';

  @override
  String get previewSendFile => 'Share the file';

  @override
  String get chatFileRemoved => 'File removed';

  @override
  String get chatRecord => 'Hold to record a voice note';

  @override
  String get chatSlideToCancel => 'Slide away to cancel';

  @override
  String get chatReleaseToCancel => 'Release to cancel';

  @override
  String get chatMicDenied =>
      'Allow the microphone in your phone\'s settings to record.';

  @override
  String get chatVoiceTooShort => 'Hold a little longer to record.';

  @override
  String get chatPlay => 'Play';

  @override
  String get chatPause => 'Pause';

  @override
  String feedBeyond(String market) {
    return 'Beyond $market';
  }

  @override
  String get feedEmpty => 'No posts yet. Share what happened at work today.';

  @override
  String get feedCouldntLoad => 'Couldn\'t load your Feed';

  @override
  String get feedCouldntLoadBody =>
      'Check your connection and try again. Nothing was lost.';

  @override
  String get feedOffline => 'You\'re offline. Showing what you already loaded.';

  @override
  String get feedNewPost => 'New post';

  @override
  String get postUseful => 'Useful';

  @override
  String get postReply => 'Reply';

  @override
  String postUsefulOne(String a) {
    return '$a found this useful';
  }

  @override
  String postUsefulTwo(String a, String b) {
    return '$a and $b found this useful';
  }

  @override
  String get postEdited => 'Edited';

  @override
  String get postMenu => 'Post options';

  @override
  String postMute(String name) {
    return 'Mute $name';
  }

  @override
  String postMuted(String name) {
    return 'Muted $name';
  }

  @override
  String get postUndo => 'Undo';

  @override
  String get postEdit => 'Edit post';

  @override
  String get postDelete => 'Delete post';

  @override
  String get postDeleteTitle => 'Delete this post?';

  @override
  String get postDeleteBody =>
      'It\'s removed from the Feed, your profile and the project\'s page.';

  @override
  String get postDeleted => 'Post deleted.';

  @override
  String get postTitle => 'Post';

  @override
  String get postReplies => 'Replies';

  @override
  String get postNoReplies => 'No replies yet.';

  @override
  String get postWriteReply => 'Write a reply';

  @override
  String postReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get postCancelReply => 'Cancel reply';

  @override
  String get postSendReply => 'Send';

  @override
  String get postReplyMenu => 'Comment options';

  @override
  String get postDeleteReply => 'Delete comment';

  @override
  String get postDeleteReplyTitle => 'Delete comment?';

  @override
  String get postDeleteReplyBody =>
      'It will be removed from this post for everyone.';

  @override
  String get postUnavailable => 'This post isn\'t available';

  @override
  String get postUnavailableBody =>
      'It may have been deleted, or you may not have access to it.';

  @override
  String get postBackHome => 'Back to Home';

  @override
  String get langEnglish => 'English';

  @override
  String get langArabic => 'العربية';

  @override
  String get tagEmpty => 'Add a project on your profile first';

  @override
  String get tagNone => 'No project';

  @override
  String get projectPosts => 'POSTS';

  @override
  String get projectPostsEmpty => 'No posts tagged with this project yet.';

  @override
  String homeDayNeedsYou(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n things need you',
      one: '1 thing needs you',
    );
    return '$_temp0';
  }

  @override
  String get homeNeedsYou => 'NEEDS YOU';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeJoinWithCode => 'Join with a code';

  @override
  String get homeSearch => 'Search people';

  @override
  String get homeMySpaces => 'My Spaces';

  @override
  String needsForYou(String name, String title) {
    return '$name gave you a work item: $title';
  }

  @override
  String needsForYouSelf(String title) {
    return 'A work item for you: $title';
  }

  @override
  String needsYouCheck(String name, String title) {
    return '$name signed a work item as done: $title';
  }

  @override
  String needsYouCheckSelf(String title) {
    return 'Signed as done. You check it: $title';
  }

  @override
  String needsSentBack(String name, String title) {
    return '$name sent a work item back: $title';
  }

  @override
  String needsSentBackSelf(String title) {
    return 'A work item came back to you: $title';
  }

  @override
  String needsOwnerLeft(String title) {
    return 'The owner left. Reassign it: $title';
  }

  @override
  String needsJoin(String name, String space) {
    return '$name asked to join $space';
  }

  @override
  String needsDue(String date) {
    return 'due $date';
  }

  @override
  String todayItem(String event, String name, String ref, String title) {
    String _temp0 = intl.Intl.selectLogic(event, {
      'done': '$name signed $ref as done',
      'checked': '$name checked $ref',
      'sent_back': '$name sent $ref back',
      'comment': '$name added an update · $ref',
      'reassigned': '$name reassigned $ref',
      'other': '$name raised $ref',
    });
    return '$_temp0: $title';
  }

  @override
  String todayFile(String name, String file) {
    return '$name added $file';
  }

  @override
  String todayChat(String name, String text) {
    return '$name: $text';
  }

  @override
  String todayChatKind(String kind, String name) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'photo': '$name sent a photo',
      'voice': '$name sent a voice note',
      'file': '$name sent a file',
      'other': '$name posted in chat',
    });
    return '$_temp0';
  }

  @override
  String get activitySomeone => 'Someone';

  @override
  String get activityGroupNetwork => 'Your network';

  @override
  String activityJoinRequest(String name) {
    return '$name asked to join';
  }

  @override
  String activityJoinConfirmed(String space) {
    return 'You\'re in $space';
  }

  @override
  String activityConfirmedBy(String name) {
    return 'Confirmed by $name';
  }

  @override
  String activityRoleConfirmed(String name) {
    return '$name confirmed your role';
  }

  @override
  String activityFollow(String name) {
    return '$name started following you';
  }

  @override
  String activityReplyPost(String name) {
    return '$name replied to your post';
  }

  @override
  String activityReplyReply(String name) {
    return '$name replied to you';
  }

  @override
  String activityUseful1(String a) {
    return '$a found your post useful';
  }

  @override
  String activityUseful2(String a, String b) {
    return '$a and $b found your post useful';
  }

  @override
  String get activityUseful0 => 'Your post was found useful';

  @override
  String activityItemDone(String name, String title) {
    return '$name signed as done: $title';
  }

  @override
  String activityItemChecked(String name, String title) {
    return '$name checked: $title';
  }

  @override
  String activityItemSentBack(String name, String title) {
    return '$name sent back: $title';
  }

  @override
  String activityItemUpdate(String name, String title) {
    return '$name added an update: $title';
  }

  @override
  String activityRoleConfirmedOn(String name, String project) {
    return '$name confirmed your role on $project';
  }

  @override
  String activityReplyPostText(String name, String text) {
    return '$name replied to your post: $text';
  }

  @override
  String activityReplyReplyText(String name, String text) {
    return '$name replied to you: $text';
  }

  @override
  String get activityWherePost => 'Your post';

  @override
  String get activityWhereProfile => 'Your profile';

  @override
  String get activityEmptyTitle => 'Nothing needs you right now.';

  @override
  String get activityEmptyBody =>
      'When someone needs an answer from you, it waits here. This is what will show up.';

  @override
  String get ledgerWork => 'WORK ITEMS';

  @override
  String get ledgerWorkLine =>
      'Someone gives you a work item, or one you raised is done.';

  @override
  String get ledgerRequests => 'SPACE REQUESTS';

  @override
  String get ledgerRequestsLine => 'Someone asks to join a Space you run.';

  @override
  String get ledgerPosts => 'YOUR POSTS';

  @override
  String get ledgerPostsLine => 'Someone replies to your post.';

  @override
  String get ledgerNetwork => 'YOUR NETWORK';

  @override
  String get ledgerNetworkLine => 'Someone follows you.';

  @override
  String get ledgerWait => 'WHILE YOU WAIT';

  @override
  String get ledgerAddProject => 'Add a project you worked on';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get notifPeople => 'PEOPLE';

  @override
  String get notifFollowers => 'New followers';

  @override
  String get notifPosts => 'YOUR POSTS';

  @override
  String get notifReplies => 'Replies';

  @override
  String get notifMessages => 'MESSAGES';

  @override
  String get notifLockText => 'Show message text on lock screen';

  @override
  String get notifSpaces => 'SPACES';

  @override
  String get notifSpacesLine =>
      'Set for each Space in Space info → Notifications';

  @override
  String get notifFooter =>
      'Notifications never name a project, a Space or a work item.';

  @override
  String get pushOffTitle => 'Push notifications are off';

  @override
  String get pushOffBody =>
      'You will miss work items and messages. Turn them on in your phone settings.';

  @override
  String get pushOpenSettings => 'Open phone settings';

  @override
  String get pushNotReaching => 'Notifications aren\'t reaching this phone';

  @override
  String get pushFixIt => 'Fix it';

  @override
  String get pushFixTitle => 'Let notifications reach this phone';

  @override
  String get pushFixAutostart => 'Autostart: on for BuildVibes.';

  @override
  String get pushFixBattery =>
      'Battery saver: \"No restrictions\" for BuildVibes.';

  @override
  String get pushFixPlayServices =>
      'The same battery setting for Google Play services.';

  @override
  String get pushFixRestart => 'Then restart the phone.';

  @override
  String get pushFixOpen => 'Open BuildVibes settings';

  @override
  String get feedNew => 'New';

  @override
  String get daybookNew => 'New';

  @override
  String reportTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'post': 'Report this post',
      'reply': 'Report this reply',
      'message': 'Report this message',
      'dm_message': 'Report this message',
      'other': 'Report this account',
    });
    return '$_temp0';
  }

  @override
  String get reportSubtitle =>
      'The person won\'t be told who reported. Choose what fits best.';

  @override
  String get reasonSpam => 'Spam or scam';

  @override
  String get reasonSpamHelp => 'Fake offers, unwanted promotion';

  @override
  String get reasonHarassment => 'Harassment or abuse';

  @override
  String get reasonHarassmentHelp => 'Insults, threats, targeting someone';

  @override
  String get reasonMisleading => 'Wrong or misleading';

  @override
  String get reasonMisleadingHelp => 'Claims that are false';

  @override
  String get reasonFake => 'This isn\'t real';

  @override
  String get reasonFakeHelp => 'A fake person, company or project';

  @override
  String get reasonPrivate => 'Shares private information';

  @override
  String get reasonPrivateHelp =>
      'Documents, plans or details not meant to be public';

  @override
  String get reasonOther => 'Something else';

  @override
  String get reasonOtherHelp => 'Tell us in a few words';

  @override
  String get reportNoteTitle => 'What\'s wrong?';

  @override
  String get reportNoteHint => 'A few words';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportSentTitle => 'Report sent';

  @override
  String get reportSentBody =>
      'We\'ll review it and may remove anything that breaks the rules. The person isn\'t told who reported.';

  @override
  String get reportDone => 'Done';

  @override
  String get reportBlock => 'Block this account';

  @override
  String get postReport => 'Report post';

  @override
  String get replyReport => 'Report reply';

  @override
  String get chatReport => 'Report message';

  @override
  String get profileReport => 'Report account';

  @override
  String blockDone(String name) {
    return '$name blocked';
  }

  @override
  String get blockedTitle => 'Blocked accounts';

  @override
  String blockedCount(int n) {
    return '$n BLOCKED';
  }

  @override
  String get blockedNone => 'Nobody blocked';

  @override
  String get unblock => 'Unblock';

  @override
  String unblocked(String name) {
    return '$name unblocked';
  }

  @override
  String get blockedNote =>
      'Blocked accounts can\'t follow you or see your posts. They are not told.';

  @override
  String removedTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'post': 'Removed post',
      'reply': 'Removed reply',
      'other': 'Removed message',
    });
    return '$_temp0';
  }

  @override
  String removedHeading(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'post': 'We removed your post',
      'reply': 'We removed your reply',
      'other': 'We removed your message',
    });
    return '$_temp0';
  }

  @override
  String removedBody(String reason) {
    return 'It was reported for $reason, and our review agreed. Only you can see this notice.';
  }

  @override
  String reasonPhrase(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'spam': 'spam or a scam',
      'harassment': 'harassment or abuse',
      'misleading': 'being wrong or misleading',
      'fake': 'not being real',
      'private_info': 'sharing private information',
      'other': 'something else',
    });
    return '$_temp0';
  }

  @override
  String removedYour(String kind, String date) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'post': 'Your post',
      'reply': 'Your reply',
      'other': 'Your message',
    });
    return '$_temp0 · $date';
  }

  @override
  String get removedAppealNote =>
      'You have 14 days to appeal. We\'ll look at it again.';

  @override
  String get removedAppeal => 'Appeal this decision';

  @override
  String removedAppealOpen(String date) {
    return 'You appealed on $date. We\'ll tell you the result in Activity.';
  }

  @override
  String get removedClosed => 'The 14 days to appeal have passed.';

  @override
  String get removedUpheld => 'We looked at it again: the removal stands.';

  @override
  String get removedReversed => 'We looked at it again and brought it back.';

  @override
  String get removedGone => 'This notice isn\'t available.';

  @override
  String get appealTitle => 'Appeal';

  @override
  String get appealHeading => 'Tell us why this was a mistake';

  @override
  String get appealHelp =>
      'Add anything that helps the reviewer. Don\'t include other people\'s private details.';

  @override
  String get appealLabel => 'Your explanation';

  @override
  String get appealLimit => 'Up to 500 characters';

  @override
  String get appealSend => 'Send appeal';

  @override
  String get appealReceived => 'Appeal received';

  @override
  String get appealReceivedBody =>
      'We\'ll look at it again. We\'ll tell you the result in Activity, usually within 3 days.';

  @override
  String activityRemoved(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'post': 'Your post was removed',
      'reply': 'Your reply was removed',
      'other': 'Your message was removed',
    });
    return '$_temp0';
  }

  @override
  String activityAppealResult(String result) {
    String _temp0 = intl.Intl.selectLogic(result, {
      'reversed': 'Your appeal: it\'s back',
      'other': 'Your appeal: the removal stands',
    });
    return '$_temp0';
  }

  @override
  String get settingsViewProfile => 'View profile';

  @override
  String get settingsLanguageLabel => 'LANGUAGE';

  @override
  String get accountSecurity => 'Account and security';

  @override
  String get accountSecuritySub => 'Download my data, delete account';

  @override
  String get privacySafety => 'Privacy and safety';

  @override
  String get languageRegion => 'Language and region';

  @override
  String get helpFeedback => 'Help and feedback';

  @override
  String get aboutLegal => 'About BuildVibes and legal';

  @override
  String get aboutLegalSub => 'Terms, privacy policy';

  @override
  String aboutBuild(String version, String build, String commit) {
    return 'Version $version · build $build · $commit';
  }

  @override
  String get legalTerms => 'Terms of use';

  @override
  String get legalPrivacy => 'Privacy policy';

  @override
  String get legalSoon =>
      'These pages are on their way. Write to us with any question.';

  @override
  String get linkFailed => 'This couldn\'t be opened on this phone.';

  @override
  String get signOutTitle => 'Sign out of BuildVibes?';

  @override
  String get signOutBody =>
      'You\'ll need a code sent to your email to sign in again.';

  @override
  String get accountYourData => 'YOUR DATA';

  @override
  String get downloadData => 'Download my data';

  @override
  String get downloadDataSub => 'We email you a copy within 7 days';

  @override
  String get dangerZone => 'DANGER ZONE';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountSub =>
      'Removed after 30 days. You can restore it until then.';

  @override
  String get privacySafetySection => 'SAFETY';

  @override
  String get privacyNote =>
      'Work items, chat and the Library stay inside each Space. Only its members see them.';

  @override
  String get languageEnglishDir => 'Left to right';

  @override
  String get languageArabicDir => 'Right to left';

  @override
  String get regionSection => 'REGION';

  @override
  String get regionCountry => 'Country';

  @override
  String get regionWeekStart => 'Week starts on';

  @override
  String get regionNote =>
      'Arabic switches the whole app to right-to-left. Your posts keep the language they were written in.';

  @override
  String get downloadHeading => 'Get a copy of your data';

  @override
  String get downloadBody =>
      'We email you a file with everything below, within 7 days.';

  @override
  String get downloadIncluded => 'WHAT IS INCLUDED';

  @override
  String get downloadProfile => 'Profile and settings';

  @override
  String get downloadPosts => 'Posts and replies';

  @override
  String get downloadMessages => 'Messages you sent';

  @override
  String get downloadWork => 'Your work items and notes';

  @override
  String get downloadRequest => 'Request my data';

  @override
  String downloadFoot(String email) {
    return 'We send it to $email.';
  }

  @override
  String get requestReceived => 'Request received';

  @override
  String requestReceivedBody(String email) {
    return 'We will email $email within 7 days.';
  }

  @override
  String get deleteHeading => 'Before you delete';

  @override
  String get deleteBody =>
      'Your profile is hidden right away. You have 30 days to change your mind.';

  @override
  String get deleteWhat => 'WHAT HAPPENS';

  @override
  String get deleteProfile => 'Profile, posts and replies are removed';

  @override
  String get deleteSpaceWork => 'Work and files in a Space stay there';

  @override
  String get deleteSpaceWorkSub => 'Shown as a former member';

  @override
  String get deleteMessages => 'Messages you sent stay in the Space\'s chat';

  @override
  String get deleteContinue => 'Continue';

  @override
  String get deleteKeep => 'Keep my account';

  @override
  String get transferFirst => 'Hand over Space admin first';

  @override
  String get transferFirstBody =>
      'You are the only admin of a Space that has other members. Make someone else its admin before you delete your account.';

  @override
  String get transferOnlyAdmin => 'ONLY ADMIN';

  @override
  String get confirmHeading => 'Confirm it\'s you';

  @override
  String confirmBody(String email) {
    return 'Enter the code we sent to $email.';
  }

  @override
  String get deleteMyAccount => 'Delete my account';

  @override
  String deleteFoot(String date) {
    return 'Your account will be removed on $date. Sign in before then to restore it.';
  }

  @override
  String get scheduledTitle => 'Deletion scheduled';

  @override
  String scheduledBody(String date) {
    return 'Your account will be deleted on $date. Your profile is hidden. Restore it any time before then.';
  }

  @override
  String get restoreAccount => 'Restore my account';

  @override
  String get formerMember => 'Former member';

  @override
  String get daybookYou => 'You';

  @override
  String get daybookForYou => 'For you';

  @override
  String daybookForPerson(String name) {
    return 'For $name';
  }

  @override
  String daybookMeta(String who, String due) {
    return '$who · $due';
  }

  @override
  String daybookDueDate(String date) {
    return 'by $date';
  }

  @override
  String get daybookDueToday => 'by today';

  @override
  String get daybookDueTomorrow => 'by tomorrow';

  @override
  String daybookDueDateAt(String date, String time) {
    return 'by $date $time';
  }

  @override
  String daybookDueTodayAt(String time) {
    return 'by today $time';
  }

  @override
  String daybookDueTomorrowAt(String time) {
    return 'by tomorrow $time';
  }

  @override
  String daybookWasDue(String date) {
    return 'was due $date';
  }

  @override
  String daybookWasDueAt(String date, String time) {
    return 'was due $date $time';
  }

  @override
  String daybookWasDueTodayAt(String time) {
    return 'was due today $time';
  }

  @override
  String get daybookToDo => 'To do';

  @override
  String daybookPoints(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String get daybookToday => 'today';

  @override
  String get daybookTomorrow => 'tomorrow';

  @override
  String get daybookStampDone => 'DONE';

  @override
  String get daybookStampChecked => 'CHECKED';

  @override
  String get daybookStampSentBack => 'SENT BACK';

  @override
  String get daybookStampCancelled => 'CANCELLED';

  @override
  String get daybookWorkItem => 'Work item';

  @override
  String get daybookReadOnly => 'Read only';

  @override
  String get daybookMonthPosts => 'Posts';

  @override
  String get daybookMonthDue => 'Something due';

  @override
  String get daybookFirstTitle => 'The first page of your daybook';

  @override
  String get daybookFirstBody =>
      'Everything your team posts will hang here, day by day.';

  @override
  String get daybookFirstPost => 'Post the first work item';

  @override
  String get daybookFirstInvite => 'Invite your team';

  @override
  String daybookStampBy(String name, String time) {
    return '$name · $time';
  }

  @override
  String timePeriod(String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'morning': 'am',
      'noon': 'pm',
      'afternoon': 'pm',
      'evening': 'pm',
      'other': 'pm',
    });
    return '$_temp0';
  }

  @override
  String timeClock12(String time, String period) {
    return '$time $period';
  }

  @override
  String daybookFileChip(String name, String revision) {
    return '$name $revision';
  }

  @override
  String get daybookWaitingToSend => 'Waiting to send';

  @override
  String get daybookDraft => 'Draft';

  @override
  String get daybookWritingTitle => 'Title';

  @override
  String get daybookWritingBody => 'Write what needs doing';

  @override
  String get daybookAssign => 'Assign';

  @override
  String get daybookLocation => 'Location';

  @override
  String get daybookDueDateMenu => 'Due date';

  @override
  String daybookDueProperty(String date, String time) {
    return '$date, $time';
  }

  @override
  String get daybookCamera => 'Take a photo';

  @override
  String get daybookAddPhoto => 'Add a photo';

  @override
  String get daybookMore => 'More';

  @override
  String get daybookPost => 'Post';

  @override
  String get daybookRemovePhoto => 'Remove photo';

  @override
  String get daybookGiveToSearch => 'Give to…';

  @override
  String get daybookOwnerNow => 'now';

  @override
  String get daybookPlaceHint => 'Where';

  @override
  String get daybookNoTime => 'No time';

  @override
  String get daybookDueTimeHelp => 'Due by a time?';

  @override
  String get daybookAssignSearch => 'Assign to…';

  @override
  String get daybookCouldNotSend => 'Couldn\'t send. Tap to fix';

  @override
  String get daybookRemoveDue => 'Remove';

  @override
  String get daybookSignAsDone => 'Sign as done';

  @override
  String get daybookHoldToProve => 'Hold to prove';

  @override
  String get daybookCheck => 'Check';

  @override
  String get daybookSendBack => 'Send back';

  @override
  String get daybookAddUpdate => 'Add update';

  @override
  String get daybookEdit => 'Edit';

  @override
  String get daybookGiveTo => 'Give to someone else';

  @override
  String get daybookCancelItem => 'Cancel work item';

  @override
  String daybookSendBackTo(String name) {
    return 'Send back to $name';
  }

  @override
  String get daybookReasonPhotoMissing => 'Photo missing';

  @override
  String get daybookReasonNotAsAsked => 'Not as asked';

  @override
  String get daybookReasonNotFinished => 'Not finished';

  @override
  String get daybookReasonOther => 'Something else';

  @override
  String get daybookNoteOptional => 'Add a note (optional)';

  @override
  String get daybookNoteNeeded => 'Say what is wrong';

  @override
  String get daybookChecked => 'Checked';

  @override
  String get daybookCancelled => 'Cancelled';

  @override
  String get daybookUndo => 'Undo';

  @override
  String get daybookUpdateHint => 'Write an update';

  @override
  String get daybookSendAsDone => 'Send as done';

  @override
  String get daybookAddAnotherPhoto => 'Add another photo';

  @override
  String get daybookWithoutPhoto => 'Without a photo';

  @override
  String get daybookWhatWasDone => 'What was done?';

  @override
  String get daybookSignedUndo => 'Signed as done';

  @override
  String get daybookCloseProof => 'Close';

  @override
  String get daybookSave => 'Save';

  @override
  String daybookSentBackText(String reason, String note) {
    return '$reason. $note';
  }

  @override
  String get daybookCouldNotCheck => 'Couldn\'t check';

  @override
  String get daybookCouldNotSendBack => 'Couldn\'t send back';

  @override
  String get daybookCouldNotCancel => 'Couldn\'t cancel';

  @override
  String get daybookCouldNotGiveTo => 'Couldn\'t give it to someone else';

  @override
  String get daybookCouldNotUpdate => 'Couldn\'t add the update';

  @override
  String daybookRefusedBecause(String action, String reason) {
    return '$action: $reason';
  }

  @override
  String daybookRefusedPlain(String action) {
    return '$action.';
  }

  @override
  String get daybookWhyCancelled => 'this item was cancelled';

  @override
  String get daybookWhyChecked => 'it was already checked';

  @override
  String get daybookWhyChanged => 'it changed in the meantime';

  @override
  String get daybookWhyRemoved => 'it was removed';

  @override
  String get daybookWhyNotAllowed => 'your pass doesn\'t allow it';

  @override
  String get daybookSwitchItem => 'Prove another work item';

  @override
  String get daybookDiscardProofTitle => 'Delete this proof?';

  @override
  String get daybookDiscardProofBody =>
      'The photos are only on this phone. Deleted, they are gone.';

  @override
  String get daybookDiscardProofKeep => 'Keep';

  @override
  String get daybookDiscardProofDelete => 'Delete';

  @override
  String get spacesMenu => 'Space menu';

  @override
  String get spacesInfoYou => 'You';

  @override
  String get spacesInfoInvite => 'Invite';

  @override
  String get spacesInfoSpace => 'Space';

  @override
  String get spacesYourPass => 'Your pass';

  @override
  String get spacesNotifyChoiceAll => 'Everything';

  @override
  String get spacesNotifyChoiceNeedsYou => 'Needs you';

  @override
  String get spacesInviteChoiceAdmins => 'Admins';

  @override
  String get spacesInviteChoiceLeads => 'Leads';

  @override
  String get spacesInviteChoiceEveryone => 'Everyone';

  @override
  String get spacesCopy => 'Copy';

  @override
  String get spacesCodeCopied => 'Invite code copied';

  @override
  String get spacesAdminRow => 'Space admin';

  @override
  String get spacesOnSiteSince => 'On site since';

  @override
  String get spacesOnSiteNotSet => 'Not set';

  @override
  String get spacesOnSiteChange => 'Choose another day';

  @override
  String get spacesOnSiteRemove => 'Remove the day';

  @override
  String get spacesOnSiteNote => 'Work counts \"day 1 on site\" from this day.';

  @override
  String get spacesEditNameAbout => 'Name and About';

  @override
  String get needsTitle => 'Needs you';

  @override
  String get needsRowCheck => 'Check it';

  @override
  String get needsRowForYou => 'For you';

  @override
  String get needsRowSentBack => 'Sent back';

  @override
  String get needsRowOwnerLeft => 'Give it to someone';

  @override
  String get needsRowJoin => 'Asks to join';

  @override
  String get needsNone => 'Nothing needs you now.';

  @override
  String get profileProofOfWork => 'Proof of work';

  @override
  String get profileProjectsConfirmed => 'Projects, confirmed by teammates';

  @override
  String get proofStampConfirmed => 'CONFIRMED';

  @override
  String get proofStampWaiting => 'WAITING';

  @override
  String get proofChooseShown => 'Choose what shows';

  @override
  String get postWritingAuthor => 'You · to everyone';

  @override
  String postLangAuto(String lang) {
    String _temp0 = intl.Intl.selectLogic(lang, {
      'ar': 'Arabic',
      'other': 'English',
    });
    return 'Detected: $_temp0';
  }

  @override
  String get postWritingHint => 'What happened at work today?';

  @override
  String get postWritingProject => 'Project';

  @override
  String postWritingLang(String lang) {
    String _temp0 = intl.Intl.selectLogic(lang, {
      'ar': 'Arabic',
      'other': 'English',
    });
    return 'Written in $_temp0';
  }

  @override
  String get postWritingPhotosMax => 'Up to 4 photos.';

  @override
  String get homeNothingNeedsYou => 'Nothing needs you';

  @override
  String get homeYourSpaces => 'YOUR SPACES';

  @override
  String get createPostToEveryone => 'Post to everyone';

  @override
  String get createPostToEveryoneLine => 'In the Home feed, for everyone';

  @override
  String get createWorkItem => 'Work item in a Space';

  @override
  String get createWorkItemLine => 'Only the Space\'s members see it';

  @override
  String get createPickSpace => 'Which Space?';

  @override
  String get createLastSpace => 'Last opened';

  @override
  String get createNoWorkSpaces =>
      'There\'s no Space yet where you can write work items. Join one with an invite code, or start a new Space.';

  @override
  String get daybookShowEarlier => 'Show earlier';

  @override
  String daybookHistoryLead(String lead) {
    return '$lead:';
  }

  @override
  String daybookCardRef(String ref) {
    return '· $ref';
  }

  @override
  String get daybookRemoved => 'This was removed';

  @override
  String daybookQuote(String ref, String title) {
    return '$ref · $title';
  }

  @override
  String get daybookSendUpdate => 'Send update';

  @override
  String daybookTrace(String what, String title) {
    return '$what · $title';
  }

  @override
  String get daybookTodayDivider => 'Today';

  @override
  String daybookLineSigned(String name) {
    return '$name signed as done';
  }

  @override
  String get daybookLineYouSigned => 'You signed as done';

  @override
  String daybookLineChecked(String name) {
    return '$name checked it';
  }

  @override
  String get daybookLineYouChecked => 'You checked it';

  @override
  String daybookLineSentBack(String name) {
    return '$name sent it back';
  }

  @override
  String get daybookLineYouSentBack => 'You sent it back';

  @override
  String daybookLineUpdate(String name) {
    return '$name added an update';
  }

  @override
  String get daybookLineYouUpdate => 'You added an update';

  @override
  String get daybookLineYouComment => 'You';

  @override
  String daybookLineComment(String name) {
    return '$name';
  }

  @override
  String daybookLineGave(String name, String to, String from) {
    return '$name gave it to $to instead of $from';
  }

  @override
  String daybookLineYouGave(String to, String from) {
    return 'You gave it to $to instead of $from';
  }

  @override
  String daybookLineEdited(String name) {
    return '$name edited it';
  }

  @override
  String get daybookLineYouEdited => 'You edited it';

  @override
  String daybookLineMovedDue(String name, String from, String to) {
    return '$name moved the due date from $from to $to';
  }

  @override
  String daybookLineYouMovedDue(String from, String to) {
    return 'You moved the due date from $from to $to';
  }

  @override
  String daybookLineRemovedDue(String name) {
    return '$name took the due date off';
  }

  @override
  String get daybookLineYouRemovedDue => 'You took the due date off';

  @override
  String daybookLineCancelled(String name) {
    return '$name cancelled it';
  }

  @override
  String get daybookLineYouCancelled => 'You cancelled it';

  @override
  String daybookLinePosted(String name) {
    return '$name posted it';
  }

  @override
  String get daybookLineYouPosted => 'You posted it';

  @override
  String get daybookKindChecklistWord => '· checklist';

  @override
  String get daybookKindActivityWord => '· scheduled';

  @override
  String get daybookKindFileWord => '· file';

  @override
  String get daybookToEveryone => '· to everyone';

  @override
  String daybookToTeam(String team) {
    return '· to $team';
  }

  @override
  String daybookTicked(int ticked, int total) {
    return '$ticked of $total ticked';
  }

  @override
  String get daybookGotIt => 'Got it';

  @override
  String get daybookReceived => 'Received';

  @override
  String get daybookOnMyWay => 'On my way';

  @override
  String get daybookAddToCalendar => 'Add to my calendar';

  @override
  String get daybookInMyCalendar => 'In my calendar';

  @override
  String daybookReceivedBy(String names) {
    return 'Received by $names';
  }

  @override
  String daybookFileTitle(String title, String revision) {
    return '$title · $revision';
  }

  @override
  String get daybookStampNewVersion => 'NEW VERSION';

  @override
  String daybookStampReplaces(String revision) {
    return 'REPLACES $revision';
  }

  @override
  String daybookPinnedUntil(String day) {
    return 'Until $day';
  }

  @override
  String daybookChecklistBy(String date) {
    return 'By $date';
  }

  @override
  String daybookChecklistByAt(String date, String time) {
    return 'By $date $time';
  }

  @override
  String daybookNamesAnd(String list, String last) {
    return '$list and $last';
  }

  @override
  String get daybookNamesComma => ', ';

  @override
  String daybookNamesOthers(String list) {
    return '$list and others';
  }

  @override
  String daybookForYouAnd(String names) {
    return 'For you and $names';
  }

  @override
  String get daybookTomorrowStart => 'Tomorrow';

  @override
  String daybookActivityWhen(String day, String time) {
    return '$day, $time';
  }

  @override
  String daybookStartsIn(String time, int minutes) {
    return '$time · starts in $minutes min';
  }

  @override
  String daybookOnNow(String time) {
    return '$time · on now';
  }

  @override
  String get daybookPdf => 'PDF';

  @override
  String get daybookPhoto => 'Photo';

  @override
  String timeRange(String from, String to) {
    return '$from to $to';
  }

  @override
  String daybookLineTicked(String name) {
    return '$name · ticked';
  }

  @override
  String get daybookLineYouTicked => 'You · ticked';

  @override
  String daybookLineUnticked(String name) {
    return '$name · unticked';
  }

  @override
  String get daybookLineYouUnticked => 'You · unticked';

  @override
  String daybookLineGotIt(String name) {
    return '$name · Got it';
  }

  @override
  String get daybookLineYouGotIt => 'You · Got it';

  @override
  String daybookLineReceived(String name) {
    return '$name · Received';
  }

  @override
  String get daybookLineYouReceived => 'You · Received';

  @override
  String daybookLineOnMyWay(String name) {
    return '$name · On my way';
  }

  @override
  String get daybookLineYouOnMyWay => 'You · On my way';

  @override
  String daybookLineInMyCalendar(String name) {
    return '$name · In my calendar';
  }

  @override
  String get daybookLineYouInMyCalendar => 'You · In my calendar';

  @override
  String daybookTraceTicked(String name) {
    return '$name ticked a point';
  }

  @override
  String get daybookTraceYouTicked => 'You ticked a point';

  @override
  String daybookTraceUnticked(String name) {
    return '$name unticked a point';
  }

  @override
  String get daybookTraceYouUnticked => 'You unticked a point';

  @override
  String get daybookCouldNotTick => 'Couldn\'t tick';

  @override
  String get daybookCouldNotAck => 'Couldn\'t save';

  @override
  String get daybookKindChecklist => 'Checklist';

  @override
  String get daybookKindAnnouncement => 'Announcement';

  @override
  String get daybookKindActivity => 'Scheduled activity';

  @override
  String get daybookBodyNote => 'Add a note';

  @override
  String get daybookBodyAnnouncement => 'Write the announcement';

  @override
  String get daybookBodyActivity => 'What it is about';

  @override
  String get daybookPointHint => 'Add a point';

  @override
  String get daybookPeople => 'Who it\'s for';

  @override
  String get daybookPeopleSearch => 'Who is it for…';

  @override
  String get daybookPinUntil => 'Pin until';

  @override
  String daybookPinnedProperty(String day) {
    return 'Pinned until $day';
  }

  @override
  String get daybookActivityTime => 'Time';

  @override
  String get daybookStartsAtHelp => 'Starts at';

  @override
  String get daybookEndsAtHelp => 'Ends at';

  @override
  String get daybookNoEndTime => 'No end time';

  @override
  String get daybookStartLater => 'Choose a time that has not come yet';

  @override
  String get daybookAttachTitle => 'Add to this post';

  @override
  String get daybookAttachPhotos => 'Photo from the gallery';

  @override
  String daybookAttachPhotosNote(int n) {
    return 'Up to $n photos';
  }

  @override
  String get daybookFileChooseTitle => 'Choose a file';

  @override
  String get daybookFileFromPhone => 'From the phone';

  @override
  String get daybookFileFromPhoneNote => 'It goes to the Library too';

  @override
  String get daybookFileInLibrary => 'In the Library';

  @override
  String get daybookReplacesTitle => 'Is it a new version of a file?';

  @override
  String daybookReplacesOption(String name) {
    return 'Replaces $name';
  }

  @override
  String get daybookReplacesDone => 'Done';

  @override
  String get daybookFilesFull => 'Up to 10 photos and files on a post';

  @override
  String get daybookRemovePoint => 'Remove point';

  @override
  String get daybookRemoveFile => 'Remove file';

  @override
  String get daybookCancelPost => 'Cancel post';

  @override
  String get previewModelViewVersions =>
      'New versions come from BuildVibes 360';

  @override
  String get daybookPeopleDone => 'Done';

  @override
  String daybookDayTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String get daybookKindDocument => 'File';

  @override
  String get daybookUnpin => 'Unpin';

  @override
  String get daybookKindNote => 'Note';

  @override
  String get daybookKindNoteWord => '· note';

  @override
  String get daybookForChoose => 'For: Choose';

  @override
  String get daybookComingChoose => 'Who\'s coming: Choose';

  @override
  String get daybookChooseWho => 'Choose who it\'s for';

  @override
  String get daybookPostAsNote => 'Just for information? Post as a Note';

  @override
  String daybookToAudience(String audience) {
    return 'To: $audience';
  }

  @override
  String get daybookEveryone => 'Everyone';

  @override
  String daybookMastheadToday(String date) {
    return '· $date';
  }

  @override
  String get daybookNothingYetToday => 'Nothing yet today';

  @override
  String get daybookSendBackNewDate => 'New date';

  @override
  String get daybookSendBackToday => 'Today';

  @override
  String get daybookSendBackTomorrow => 'Tomorrow';

  @override
  String get daybookSendBackPickDate => 'Pick a date';

  @override
  String daybookLineNewDate(String date) {
    return 'new date $date';
  }

  @override
  String get daybookLineNoNewDate => 'no new date';

  @override
  String needsDoneWaiting(String time) {
    return 'Done $time · waiting for your check';
  }

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messagesRequest => 'Message request';

  @override
  String get messagesRequests => 'Message requests';

  @override
  String get messagesToday => 'Today';

  @override
  String get messagesEarlier => 'Earlier';

  @override
  String messagesYou(String text) {
    return 'You: $text';
  }

  @override
  String messagesVoice(String length) {
    return 'Voice note · $length';
  }

  @override
  String get messagesEmpty => 'No messages yet. Start one with +.';

  @override
  String get messagesNew => 'New message';

  @override
  String get messagesSearch => 'Search names';

  @override
  String get messagesUnread => 'Unread';

  @override
  String dmBothIn(String space) {
    return 'Both in $space';
  }

  @override
  String get dmNotInSpaces => 'Not in your Spaces';

  @override
  String get dmDecline => 'Decline';

  @override
  String dmDeclined(String name) {
    return 'Declined. $name isn\'t told.';
  }

  @override
  String get dmTapToShow => 'Tap to show';

  @override
  String get dmMute => 'Mute';

  @override
  String get dmUnmute => 'Unmute';

  @override
  String dmReportPerson(String name) {
    return 'Report $name';
  }

  @override
  String dmPaused(String day) {
    return 'Many people you wrote to haven\'t answered. You can start new conversations again on $day.';
  }

  @override
  String get dmWarning => 'Many people you wrote to haven\'t answered yet.';

  @override
  String get dmPhoto => 'Photo';

  @override
  String get profileMessage => 'Message';

  @override
  String get chatNewChat => 'New chat';

  @override
  String get chatNewGroup => 'New group in this Space';

  @override
  String get chatNewGroupNote =>
      'Pick a name and members. The Space admin can do this.';

  @override
  String get chatOnePerson => 'Message one person';

  @override
  String chatOnePersonNote(String space) {
    return 'Opens in Messages, marked “From $space”';
  }

  @override
  String get chatWorkNote =>
      'Work is given in the Work tab. Chat is for talking.';

  @override
  String chatThreadsDmNote(String space) {
    return 'Messages to one person open in Messages, marked “From $space”.';
  }

  @override
  String get photoPreparing => 'Preparing…';

  @override
  String get photoCannotOpen => 'This photo can\'t be opened. Choose another.';

  @override
  String daybookDocketTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n work items for you',
      one: '1 work item for you',
    );
    return '$_temp0';
  }

  @override
  String daybookDocketFrom(String day) {
    return 'from $day';
  }

  @override
  String daybookDocketRest(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: ', and $n more',
      one: ', and 1 more',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String daybookQuoteFrom(String name, String when) {
    return 'From $name · $when';
  }

  @override
  String daybookQuoteFromName(String name) {
    return 'From $name';
  }

  @override
  String get dmPutInSpace => 'Put in a Space';

  @override
  String get dmPutInSpaceNone =>
      'You\'re not in a Space where you can add work yet.';

  @override
  String get chatTurnIntoWorkItem => 'Turn into a work item';

  @override
  String get peopleWantsToJoin => 'wants to join';

  @override
  String get peopleLetIn => 'Let in';

  @override
  String get peopleChoosePass => 'Choose a pass';

  @override
  String peopleLetInAs(String pass) {
    return 'Let in as $pass';
  }

  @override
  String get peopleLeads => 'Leads';

  @override
  String get peopleCrew => 'Crew';

  @override
  String get peopleViewers => 'Viewers';

  @override
  String get peopleAdmin => 'admin';

  @override
  String get peopleNewTeam => '+ New team';

  @override
  String peopleInviteCode(String code) {
    return 'Invite with the code $code';
  }

  @override
  String peopleLetInDone(String name, String pass) {
    return '$name is in, as $pass.';
  }

  @override
  String libraryOlderVersions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count older versions',
      one: '1 older version',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddFile => 'Add a file';

  @override
  String get libraryVersions => 'Versions';

  @override
  String libraryInUse(String rev) {
    return '$rev · in use';
  }

  @override
  String get libraryVersion => 'Version';

  @override
  String get libraryOpen => 'Open';

  @override
  String get libraryAddVersion => 'Add a new version';

  @override
  String get libraryFileMenu => 'More for this file';

  @override
  String get libraryOpenFull => 'Open full screen';

  @override
  String get searchMenu => 'Search';

  @override
  String get searchHint => 'Search words or a number, e.g. 23';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchPosts => 'Posts';

  @override
  String get searchFiles => 'Files';

  @override
  String get searchChat => 'Chat';

  @override
  String searchNothing(String query) {
    return 'Nothing found for “$query”';
  }

  @override
  String searchMessage(String text) {
    return '“$text”';
  }

  @override
  String get pageOpen => 'Open the page';

  @override
  String get pageEdit => 'Edit page';

  @override
  String get pageDone => 'Done';

  @override
  String get pageClose => 'Close the page';

  @override
  String get pageUnder => 'Work items under this one';

  @override
  String pageUnderChecked(int checked, int total) {
    return '$checked of $total checked';
  }

  @override
  String get pageAddBlock => 'Type / to add a block';

  @override
  String get pageMenuTitle => 'Add';

  @override
  String get pageText => 'Text';

  @override
  String get pageHeading => 'Heading';

  @override
  String get pageChecklist => 'Checklist';

  @override
  String get pageToggle => 'Toggle';

  @override
  String get pageTable => 'Table';

  @override
  String get pagePhoto => 'Photo';

  @override
  String get pageFile => 'File';

  @override
  String get pageItemUnder => 'Work item under this one';

  @override
  String get pagePoint => 'Checklist point';

  @override
  String get pageTurnInto => 'Turn into';

  @override
  String get pageTickedStays => 'A ticked point stays as it is.';

  @override
  String get pageDelete => 'Delete';

  @override
  String get pageDeleted => 'Block deleted.';

  @override
  String get pageMove => 'Move';

  @override
  String get pageBlockMenu => 'More for this block';

  @override
  String get pageAddRow => 'Add a row';

  @override
  String get pageAddColumn => 'Add a column';

  @override
  String get pageDeleteRow => 'Delete row';

  @override
  String get pageDeleteColumn => 'Delete column';

  @override
  String get pageStale =>
      'This page changed on another phone. Yours is kept here.';

  @override
  String get pageUseMine => 'Use mine';

  @override
  String get pageUseNewer => 'Use the newer one';

  @override
  String get pageFull => 'A page holds up to 10 photos and files.';

  @override
  String get pageItemTitle => 'What needs doing';

  @override
  String get pageTooLongForItem =>
      'Shorten it to 140 characters to make it a work item.';

  @override
  String get pagePhotoCaption => 'Add a caption';

  @override
  String get walkMenu => 'Walk mode';

  @override
  String get walkTitle => 'Walk';

  @override
  String get walkNameHint => 'Name this walk';

  @override
  String get walkStart => 'Take the first photo';

  @override
  String get walkLineHint => 'What needs doing here';

  @override
  String get walkOwner => 'Who does it';

  @override
  String get walkNext => 'Next photo';

  @override
  String walkPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get walkFinish => 'Finish';

  @override
  String get walkNeedsLine => 'Write what needs doing, then the next photo.';

  @override
  String get walkNeedsOwner => 'Choose who does it, then the next photo.';

  @override
  String get walkFull =>
      'A walk holds 30 photos. Finish it, then start another.';

  @override
  String get walkDiscardTitle => 'Throw this walk away?';

  @override
  String get walkDiscardBody => 'Its photos aren\'t sent.';

  @override
  String get walkKeep => 'Keep walking';

  @override
  String get walkDiscard => 'Throw away';

  @override
  String get walkRemovePhoto => 'Take this photo out';

  @override
  String walkEachItem(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos, each one a work item',
      one: '1 photo, a work item',
    );
    return '$_temp0';
  }

  @override
  String get walkShowAll => 'Show all';

  @override
  String get walkInProgress => 'You have a walk in progress';

  @override
  String get walkContinue => 'Continue';

  @override
  String get walkThrowAway => 'Throw away';

  @override
  String get peopleSearchHint => 'Name, role or company';

  @override
  String get peopleInYourSpaces => 'People in your Spaces';

  @override
  String peopleSearchNothing(String query) {
    return 'Nobody found for “$query”';
  }

  @override
  String get peopleSearchStart => 'Type a name to find someone.';

  @override
  String get daybookSending => 'Sending';

  @override
  String daybookSendingBytes(String sent, String total) {
    return 'Sending · $sent of $total MB';
  }

  @override
  String get peoplePassRow => 'Pass';

  @override
  String get daybookNewFile => 'New file';

  @override
  String get daybookNewVersion => 'New version of a file';

  @override
  String get daybookPickVersionTitle => 'A new version of which file?';

  @override
  String libraryVersionNo(int version) {
    return 'V$version';
  }

  @override
  String get daybookNotNewVersion => 'Not a new version';

  @override
  String get daybookAttachFiles => 'File from the phone';

  @override
  String get daybookAttachLibrary => 'From the Library';

  @override
  String get daybookFileToEveryone =>
      'A file goes to the whole Space. To send it to one person, use a direct message.';

  @override
  String get daybookAttachCameraNote => 'With the phone\'s camera';

  @override
  String get daybookAttachLibraryNote => 'A file already in this Space';

  @override
  String daybookStampNewVersionNo(String version) {
    return 'NEW VERSION · $version';
  }

  @override
  String daybookReplacedBy(String version, String when) {
    return 'Replaced by $version · $when';
  }

  @override
  String libraryInUseNo(String version) {
    return '$version · in use';
  }

  @override
  String libraryReplacedOn(String day) {
    return 'replaced $day, kept in the record';
  }

  @override
  String get pageTypeInside => 'Type inside';

  @override
  String get daybookLineYouEditedPage => 'You edited the page';

  @override
  String daybookLineEditedPage(String name) {
    return '$name edited the page';
  }

  @override
  String daybookPinnedUntilAt(String day, String time) {
    return 'Until $day · $time';
  }

  @override
  String daybookPinnedLineUntil(String day) {
    return 'until $day';
  }

  @override
  String get daybookPinAddTime => '+ Time';

  @override
  String get daybookPinRemoveTime => 'Remove the time';

  @override
  String get daybookPinTimeHelp => 'Pinned until what time?';

  @override
  String get daybookPinLater => 'Choose a later time';

  @override
  String get daybookKindReport => 'Daily report';

  @override
  String get daybookKindReportWord => '· daily report';

  @override
  String get dailyReportMenu => 'Daily report';

  @override
  String get dailyReportOnSite => 'On site';

  @override
  String get dailyReportDoneToday => 'Done today';

  @override
  String get dailyReportProblems => 'Problems';

  @override
  String get dailyReportOnSiteHint => 'Who was there, and what came in';

  @override
  String get dailyReportProblemsHint => 'Anything that held work up';

  @override
  String get dailyReportNothingChecked => 'Nothing checked yet today';

  @override
  String get dailyReportTakeOut => 'Take it out of the report';

  @override
  String get dailyReportNotes => 'Today\'s notes';

  @override
  String get dailyReportAddNote => 'Add';

  @override
  String get dailyReportSharePdf => 'Share as PDF';

  @override
  String get dailyReportMakingPdf => 'Making the PDF…';

  @override
  String get dailyReportPdfFailed => 'Couldn\'t make the PDF. Try again.';

  @override
  String dailyReportPdfBy(String name, String time) {
    return 'By $name · $time';
  }

  @override
  String dailyReportPdfChecked(String time, String name) {
    return 'Checked $time by $name';
  }

  @override
  String dailyReportPdfFile(String day) {
    return 'Daily report $day';
  }

  @override
  String get dailyReportTodayOnly =>
      'A daily report is for today. Yesterday\'s draft was put away.';

  @override
  String get templateMenu => 'Template';

  @override
  String get templatePickTitle => 'Start from a template';

  @override
  String get templateSpaceOwn => 'This Space\'s templates';

  @override
  String templateFrom(String name) {
    return 'From: $name';
  }

  @override
  String get templateDrop => 'Not from a template';

  @override
  String get templateSave => 'Save as template';

  @override
  String get templateNameTitle => 'Name this template';

  @override
  String get templateNameHint => 'Template name';

  @override
  String get templateSaved => 'Saved as a template';

  @override
  String templateFull(int count) {
    return 'This Space has its $count templates. Delete one in Space info › Templates to save another.';
  }

  @override
  String get templateOpenList => 'Open Templates';

  @override
  String get templatesTitle => 'Templates';

  @override
  String get templatesNoneOwn =>
      'No templates saved in this Space yet. A Lead saves one from a post\'s menu.';

  @override
  String get templateDelete => 'Delete template';

  @override
  String templateDeleteAsk(String name) {
    return 'Delete “$name”? Posts made from it stay as they are.';
  }

  @override
  String get templateDeleted => 'Template deleted';

  @override
  String get templateBuiltinDailyReport => 'Daily report';

  @override
  String get dailyReportDraftFirst =>
      'Post or put away the card you\'re writing first.';

  @override
  String get notebookTitle => 'My notebook';

  @override
  String get notebookNote => 'Entry';

  @override
  String get notebookTodo => 'To-do';

  @override
  String get notebookVoice => 'Voice note';

  @override
  String get notebookEmptyTitle => 'Your private working area';

  @override
  String get notebookEmptyBody =>
      'Keep entries, checklists and to-dos for your work. Only you can see them.';

  @override
  String get notebookDeleteTitle => 'Delete this entry?';

  @override
  String get notebookPut => 'Went into a Space';

  @override
  String get notebookSaved => 'Saved to your notebook';

  @override
  String get notebookSaveMessage => 'Save to my notebook';

  @override
  String get notebookTooShort => 'Hold longer to record';

  @override
  String get calendarTitle => 'My calendar';

  @override
  String get calendarSubtitle => 'Your Spaces and your notebook, together';

  @override
  String get calendarAllDay => 'All day';

  @override
  String get calendarDueForYou => 'Due for you';

  @override
  String get calendarDueToday => 'Due today';

  @override
  String get calendarDue => 'Due';

  @override
  String get calendarToCheck => 'Done, to check';

  @override
  String get calendarScheduled => 'Scheduled';

  @override
  String get calendarEmpty => 'Nothing planned this week';

  @override
  String get calendarEmptyBody =>
      'Work items, checklists and activities from your Spaces, and your to-dos, show here.';

  @override
  String get calendarWeekBefore => 'Week before';

  @override
  String get calendarWeekAfter => 'Week after';

  @override
  String get notebookCouldntLoad => 'Couldn\'t load your notebook';

  @override
  String get calendarCouldntLoad => 'Couldn\'t load your calendar';

  @override
  String get meetingTurn => 'Turn lines into work items';

  @override
  String meetingPost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Post $count work items',
      one: 'Post 1 work item',
      zero: 'Post work items',
    );
    return '$_temp0';
  }

  @override
  String meetingPosted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count work items posted',
      one: '1 work item posted',
    );
    return '$_temp0';
  }

  @override
  String get meetingNoSignal => 'No signal. Try again.';

  @override
  String get meetingChangeOwner => 'Change who does it';

  @override
  String get weekReportTitle => 'Week report';

  @override
  String get weekReportShare => 'Share in chat';

  @override
  String get weekReportShareWhere => 'Share in which chat?';

  @override
  String weekReportShared(String thread) {
    return 'Shared in $thread';
  }

  @override
  String weekReportRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get weekNeedsDecision => 'Needs a decision';

  @override
  String get weekChecked => 'Checked this week';

  @override
  String get weekTargets => 'Targets';

  @override
  String get weekComingUp => 'Coming up';

  @override
  String weekSignedDone(String when) {
    return 'signed as done $when';
  }

  @override
  String get weekFoot =>
      'Made from the daybook. Everyone sees only what they may read.';

  @override
  String get weekEmpty => 'Nothing to report this week.';

  @override
  String get weekCouldntLoad => 'Couldn\'t load the week report';

  @override
  String weekReportCard(String range) {
    return 'Week report · $range';
  }

  @override
  String activityItemEdited(String name, String title) {
    return '$name made a change to $title';
  }

  @override
  String activityItemCancelled(String name, String title) {
    return '$name cancelled $title';
  }

  @override
  String activityAnnouncement(String name, String title) {
    return '$name posted an announcement: $title';
  }

  @override
  String activityChecklist(String name, String title) {
    return '$name gave you a checklist: $title';
  }

  @override
  String activityInvited(String name, String title) {
    return '$name added you to a scheduled activity: $title';
  }

  @override
  String activityFileVersion(String name, String title) {
    return '$name shared a new version of $title';
  }

  @override
  String get pushNotYet =>
      'This phone isn\'t getting notifications yet. Restart the phone, then open BuildVibes.';

  @override
  String get dmViewProfile => 'View profile';

  @override
  String get dmStartLine => 'The start of your conversation';

  @override
  String notebookReminderLine(String when) {
    return 'Reminder · $when';
  }

  @override
  String notebookReminderWhen(String day, String time) {
    return '$day $time';
  }

  @override
  String get notebookRemindPast => 'Pick a time still to come.';

  @override
  String get notebookIndent => 'Indent';

  @override
  String get notebookOutdent => 'Outdent';

  @override
  String notebookContinueNumbering(int n) {
    return 'Continue numbering ($n)';
  }

  @override
  String get notebookFoldHide => 'Hide what\'s under it';

  @override
  String get notebookFoldShow => 'Show what\'s under it';

  @override
  String notebookDeleteLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete this and the $count under it?',
    );
    return '$_temp0';
  }

  @override
  String get notebookExactTitle => 'On-time reminders';

  @override
  String get notebookExactBody =>
      'To remind you on the minute, allow exact alarms for BuildVibes.';

  @override
  String get notebookExactOpen => 'Open settings';

  @override
  String get notebookExactNotNow => 'Not now';

  @override
  String get notebookNow => 'Now';

  @override
  String get notebookDraftKept => 'Kept as you left it. Tap to go on writing.';

  @override
  String get notebookRemoveReminder => 'Remove reminder';

  @override
  String get reminderTitle => 'Reminder';

  @override
  String get reminderChannel => 'Reminders';

  @override
  String get reminderChannelAbout => 'Reminders you set in My notebook.';

  @override
  String get noSignalStrip =>
      'No signal. Everything you post waits and sends by itself.';

  @override
  String get pageNoSignal =>
      'No signal. Your changes stay here. Press Done again when the signal is back.';

  @override
  String get pageLeaveTitle => 'Leave without saving?';

  @override
  String get pageLeaveBody => 'Your changes to this page aren\'t saved yet.';

  @override
  String get pageLeaveStay => 'Keep editing';

  @override
  String get pageLeaveGo => 'Leave';

  @override
  String dmBannerTitle(String name) {
    return 'Message from $name';
  }

  @override
  String get dmBannerHidden => 'New message';

  @override
  String dmBannerHiddenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: 'New message',
    );
    return '$_temp0';
  }

  @override
  String get spacesTeamMembersTitle => 'Members';

  @override
  String needsChecklist(String name, String title) {
    return '$name gave you a checklist: $title';
  }

  @override
  String needsChecklistSelf(String title) {
    return 'A checklist for you: $title';
  }

  @override
  String get needsRowChecklist => 'To tick';

  @override
  String get muteForHowLong => 'For how long?';

  @override
  String get muteFor8Hours => '8 hours';

  @override
  String get muteFor1Week => '1 week';

  @override
  String get muteForAlways => 'Always';

  @override
  String get muteMute => 'Mute';

  @override
  String get muteUnmute => 'Unmute';

  @override
  String get muteMutedLabel => 'Notifications muted';

  @override
  String daybookFacesMore(int count) {
    return '+$count';
  }

  @override
  String get notebookSubheading => 'Subheading';

  @override
  String get notebookTodoList => 'To-do list';

  @override
  String get notebookBullets => 'Bulleted list';

  @override
  String get notebookNumbers => 'Numbered list';

  @override
  String get notebookCallout => 'Callout';

  @override
  String get notebookQuote => 'Quote';

  @override
  String get notebookDivider => 'Divider';

  @override
  String get notebookTodoHint => 'To-do';

  @override
  String get notebookListHint => 'List';

  @override
  String get notebookCalloutHint => 'Something to stand out';

  @override
  String get notebookQuoteHint => 'Quote';

  @override
  String get notebookHoldVoice => 'Hold Voice on the bar to record.';

  @override
  String get notebookVoiceTool => 'Voice';

  @override
  String get notebookLocation => 'Location';

  @override
  String get notebookFile => 'File';

  @override
  String get notebookDate => 'Date';

  @override
  String get notebookWhereHint => 'Where';

  @override
  String get notebookAddGps => 'Add where I am on the map';

  @override
  String get notebookGpsAdded => 'Added on the map';

  @override
  String notebookGpsLine(String lat, String lng, String metres) {
    return '$lat, $lng · ±$metres m';
  }

  @override
  String get notebookGpsFinding => 'Finding your position…';

  @override
  String get notebookGpsDenied =>
      'Allow location for BuildVibes in your phone\'s settings to add your position.';

  @override
  String get notebookGpsOff =>
      'Turn on your phone\'s location to add your position.';

  @override
  String get notebookGpsFailed =>
      'Couldn\'t find your position. Try again outside.';

  @override
  String get notebookLocationHelp => 'Type where, put it on the map, or both.';

  @override
  String get notebookRemoveLocation => 'Remove location';

  @override
  String get notebookRemoveGps => 'Take it off the map';

  @override
  String get notebookRemoveFile => 'Remove file';

  @override
  String get notebookRemoveDate => 'Remove date';

  @override
  String get notebookFilesFull => 'An entry holds up to 10 files.';

  @override
  String get notebookPhotosFull => 'An entry holds up to 10 photos.';

  @override
  String notebookPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String notebookFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get notebookRemindTime => 'Remind me at…';

  @override
  String get notebookCouldntKeep =>
      'Couldn\'t keep this entry. It\'s back as a draft.';

  @override
  String get notebookReminderGone =>
      'The reminder\'s time had passed, so it was taken off.';

  @override
  String get notebookPhotosStay =>
      'The photos stay in your notebook: they couldn\'t be added.';

  @override
  String get notebookTitleHint => 'Title';

  @override
  String get holdToCheck => 'Hold to check';

  @override
  String get holdToCancel => 'Hold to cancel';

  @override
  String get holdToRemove => 'Hold to remove';

  @override
  String get holdKeepHolding => 'Keep holding to confirm';

  @override
  String get holdCheckTitle => 'Check this work item?';

  @override
  String get holdCheckBody => 'It can\'t be changed after.';

  @override
  String get holdNotNow => 'Not now';

  @override
  String get holdCancelTitle => 'Cancel this work item?';

  @override
  String get holdCancelBody =>
      'It stays on the daybook, marked cancelled, and can\'t be signed or checked.';

  @override
  String get spacesRemovedUndo => 'Removed';

  @override
  String get spacesCouldNotRemove => 'Couldn\'t remove';

  @override
  String daybookCardRefKind(String ref, String kind) {
    return '· $ref $kind';
  }

  @override
  String get searchExactNumber => 'Exact number';

  @override
  String get pageSlashTitle => 'Blocks';

  @override
  String get pageSlashEnter => 'Enter picks it';

  @override
  String get notebookMoveUp => 'Move up';

  @override
  String get notebookMoveDown => 'Move down';

  @override
  String get notebookLineIndent => 'Indent';

  @override
  String get notebookDuplicate => 'Duplicate';

  @override
  String get notebookLineRestart => 'Restart at 1';

  @override
  String get pageMenuDelete => 'Delete';

  @override
  String notebookUndoTurned(String kind) {
    return 'Turned into $kind';
  }

  @override
  String get notebookUndoMoved => 'Moved';

  @override
  String get notebookUndoIndented => 'Indented';

  @override
  String get notebookUndoOutdented => 'Outdented';

  @override
  String get notebookUndoDuplicated => 'Duplicated';

  @override
  String get notebookUndoDeleted => 'Deleted';

  @override
  String get notebookFindText => 'text plain paragraph';

  @override
  String get notebookFindHeading => 'heading title h1';

  @override
  String get notebookFindSubheading => 'subheading subtitle h2';

  @override
  String get notebookFindTodo => 'todo to-do task check checklist';

  @override
  String get notebookFindBullets => 'bullet bulleted list dot';

  @override
  String get notebookFindNumbers => 'num number numbered ordered list';

  @override
  String get notebookFindToggle => 'toggle fold collapse';

  @override
  String get notebookFindTable => 'table grid';

  @override
  String get notebookFindCallout => 'callout note info box';

  @override
  String get notebookFindQuote => 'quote quotation';

  @override
  String get notebookFindDivider => 'divider line separator';

  @override
  String get notebookNewEntry => 'New entry';

  @override
  String get notebookSearchTip => 'Search my notebook';

  @override
  String get notebookPinnedLabel => 'Pinned';

  @override
  String get notebookPagesLabel => 'Pages';

  @override
  String get notebookNewPage => 'New page';

  @override
  String get notebookMyNotes => 'My notes';

  @override
  String get notebookUntitled => 'Untitled';

  @override
  String get notebookToday => 'Today';

  @override
  String get notebookYesterday => 'Yesterday';

  @override
  String notebookPageLine(String date, String line) {
    return '$date · $line';
  }

  @override
  String get notebookNewMark => 'New';

  @override
  String notebookPageChip(String page) {
    return 'Page: $page';
  }

  @override
  String get notebookFindPage => 'Find a page';

  @override
  String get notebookRecent => 'Recent';

  @override
  String get notebookNoPageFound => 'No page by that name.';

  @override
  String get notebookWriteHere => 'Write in this page';

  @override
  String get notebookPageTitleHint => 'Page title';

  @override
  String get notebookPageIcon => 'Page icon';

  @override
  String get notebookNewSubPage => 'New page inside';

  @override
  String get notebookPinPage => 'Pin to the top';

  @override
  String get notebookDeletePage => 'Delete page';

  @override
  String notebookSelected(int count) {
    return '$count selected';
  }

  @override
  String get notebookCloseSelection => 'Stop selecting';

  @override
  String get notebookMerge => 'Merge';

  @override
  String get notebookMoveInto => 'Move into…';

  @override
  String get notebookPin => 'Pin';

  @override
  String notebookMergeTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Merge $count pages',
    );
    return '$_temp0';
  }

  @override
  String get notebookMergeBody =>
      'Every entry moves into one page, in date order. The emptied page goes to Deleted items.';

  @override
  String notebookMergeInto(String page) {
    return 'Into $page';
  }

  @override
  String get notebookMergeNew => 'Into a new page';

  @override
  String get notebookMerged => 'Pages merged';

  @override
  String notebookPagesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages deleted',
      one: 'Page deleted',
    );
    return '$_temp0';
  }

  @override
  String get notebookMoveToPage => 'Move to…';

  @override
  String notebookMovedTo(String page) {
    return 'Moved to $page';
  }

  @override
  String get notebookTopOfNotebook => 'Top of My notebook';

  @override
  String get notebookSearchHint => 'Search pages and entries';

  @override
  String get notebookSearchNone => 'Nothing found.';

  @override
  String get notebookSearchFailed =>
      'Couldn\'t search. Check your signal and try again.';

  @override
  String get notebookPageNotFound =>
      'This page isn\'t in your notebook any more.';

  @override
  String get notebookIconFolder => 'Folder';

  @override
  String get notebookIconHardHat => 'Hard hat';

  @override
  String get notebookIconBuilding => 'Building';

  @override
  String get notebookIconPhone => 'Phone';

  @override
  String get notebookIconList => 'List';

  @override
  String get notebookIconCalendar => 'Calendar';

  @override
  String get notebookIconCamera => 'Camera';

  @override
  String get notebookIconWarning => 'Warning';

  @override
  String get notebookIconStar => 'Star';

  @override
  String get notebookIconWrench => 'Wrench';

  @override
  String get notebookIconRuler => 'Ruler';

  @override
  String get notebookIconNotebook => 'Notebook';

  @override
  String notebookSavedIn(String page) {
    return 'Saved in $page';
  }

  @override
  String get notebookOpen => 'Open';

  @override
  String get notebookSavedEdit => 'Saved';

  @override
  String get notebookDiscardDraft => 'Discard';

  @override
  String get notebookDraftDiscarded => 'Draft discarded';

  @override
  String notebookLinesSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines selected',
      one: '1 line selected',
    );
    return '$_temp0';
  }

  @override
  String get notebookShare => 'Share';

  @override
  String get notebookMove => 'Move to…';

  @override
  String get notebookReminder => 'Reminder';

  @override
  String get notebookChangeReminder => 'Change reminder';

  @override
  String get notebookArchive => 'Archive';

  @override
  String get notebookUnarchive => 'Unarchive';

  @override
  String get notebookArchivedUndo => 'Archived';

  @override
  String get notebookUnarchivedUndo => 'Back in its page';

  @override
  String get notebookArchivedRow => 'Archived';

  @override
  String get notebookArchivedEmpty => 'Nothing archived in this page.';

  @override
  String get notebookGroupText => 'TEXT';

  @override
  String get notebookGroupLists => 'LISTS';

  @override
  String get notebookGroupInsert => 'INSERT';

  @override
  String get notebookAdd => 'Add';

  @override
  String get notebookPhoto => 'Photo';

  @override
  String get notebookBlocks => 'Add a block';

  @override
  String get notebookDiscarded => 'Discarded';

  @override
  String get notebookDone => 'Done';

  @override
  String get notebookRemove => 'Remove';

  @override
  String get notebookBack => 'Back';

  @override
  String notebookRowLine(int count, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries · $when',
      one: '1 entry · $when',
    );
    return '$_temp0';
  }

  @override
  String get notebookRowToday => 'today';

  @override
  String get notebookRowYesterday => 'yesterday';

  @override
  String get notebookFilter => 'Filter';

  @override
  String get notebookFilterOff => 'Turn the filter off';

  @override
  String get notebookFilterShow => 'SHOW';

  @override
  String get notebookFilterIn => 'IN';

  @override
  String get notebookAllPages => 'All pages';

  @override
  String get notebookFilterTodos => 'To-dos open';

  @override
  String get notebookFilterPhotos => 'Photos';

  @override
  String get notebookFilterFiles => 'Files';

  @override
  String get notebookFilterVoice => 'Voice notes';

  @override
  String get notebookFilterReminders => 'Reminders';

  @override
  String get notebookFilterArchived => 'Archived';

  @override
  String get notebookFilterNone => 'Nothing matches.';

  @override
  String get notebookShareFeed => 'Feed';

  @override
  String get notebookShareFeedNote => 'A public post on Home';

  @override
  String get notebookShareSpace => 'Space';

  @override
  String get notebookShareSpaceNote => 'A post, work item or checklist';

  @override
  String get notebookShareMessage => 'Message';

  @override
  String get notebookShareMessageNote => 'To one person';

  @override
  String get notebookShareFeedTitle => 'Post to the feed';

  @override
  String get notebookShareSpaceTitle => 'Put in a Space';

  @override
  String get notebookShareMessageTitle => 'Send entry';

  @override
  String get notebookShareTo => 'To';

  @override
  String notebookShareWhatSees(String name) {
    return 'What $name will see';
  }

  @override
  String get notebookShareWhatOthers => 'What others will see';

  @override
  String get notebookShareCheck =>
      'Check it has nothing your client or company wouldn\'t share.';

  @override
  String notebookShareLocation(String place, String map) {
    return '$place · $map';
  }

  @override
  String get notebookOnMap => 'on the map';

  @override
  String get notebookOnMapOnly => 'On the map';

  @override
  String get notebookShareLeaveOut => 'Leave the location out';

  @override
  String get notebookPost => 'Post';

  @override
  String get notebookShareKindPost => 'Post';

  @override
  String get notebookShareKindWork => 'Work item';

  @override
  String get notebookShareKindChecklist => 'Checklist';

  @override
  String get notebookShareFind => 'Find a person';

  @override
  String get notebookShareRecent => 'RECENT';

  @override
  String get notebookShareNoSpace => 'No Space where you can post.';

  @override
  String get notebookSharedFeed => 'Shared to the feed';

  @override
  String notebookSharedTo(String name) {
    return 'Shared to $name';
  }

  @override
  String notebookSentTo(String name) {
    return 'Sent to $name';
  }

  @override
  String notebookMarkFeed(String time) {
    return 'Shared to the feed · $time';
  }

  @override
  String notebookMarkTo(String name, String time) {
    return 'Shared to $name · $time';
  }

  @override
  String notebookMarkSent(String name, String time) {
    return 'Sent to $name · $time';
  }

  @override
  String get notebookDeletedItems => 'Deleted items';

  @override
  String get notebookKeepFor => 'Keep deleted items for';

  @override
  String notebookKeepDays(int days) {
    return '$days days';
  }

  @override
  String notebookKeepNote(int days) {
    return 'Items go for good after $days days. Until then you can restore them.';
  }

  @override
  String notebookDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String notebookDeletedEntry(String page) {
    return 'Entry · from $page';
  }

  @override
  String notebookDeletedPage(String page) {
    return 'Page and everything in it · from $page';
  }

  @override
  String get notebookDeletedPageTop => 'Page and everything in it';

  @override
  String notebookDeletedPart(String page) {
    return 'Part of an entry · from $page';
  }

  @override
  String get notebookRestore => 'Restore';

  @override
  String notebookRestoredTo(String page) {
    return 'Restored to $page';
  }

  @override
  String get notebookDeleteForever => 'Delete forever';

  @override
  String get notebookDeleteForeverTitle => 'Delete this for good?';

  @override
  String get notebookEmptyNow => 'Empty now';

  @override
  String get notebookEmptyNowTitle => 'Delete everything here for good?';

  @override
  String get notebookCantUndo => 'This can\'t be undone.';

  @override
  String get notebookDeletedNone => 'Pages and entries you delete show here.';

  @override
  String get notebookShareOffline =>
      'This entry hasn\'t reached the server yet. Share it once there\'s a signal.';

  @override
  String get notebookShareTeam => 'Team';

  @override
  String get notebookShareWholeSpace => 'Whole Space';

  @override
  String get notebookShareFor => 'For';

  @override
  String notebookShortWhen(String day, String time) {
    return '$day $time';
  }

  @override
  String get notebookTomorrow => 'Tomorrow';

  @override
  String get notebookChangedElsewhere => 'Changed on another phone';

  @override
  String get notebookHoldToRecord => 'Hold to record a voice note';

  @override
  String notebookVoiceTitle(String length) {
    return 'Voice note, $length';
  }

  @override
  String get notebookShareTooLong =>
      'Too long for a message: share it to a Space, or shorten it.';

  @override
  String get timeWheelHour => 'Hour';

  @override
  String get timeWheelMinutes => 'Minutes';

  @override
  String get timeWheelAm => 'AM';

  @override
  String get timeWheelPm => 'PM';

  @override
  String get notebookSortLabel => 'SORT';

  @override
  String get notebookSortActivity => 'Latest activity';

  @override
  String get notebookSortName => 'Name A–Z';

  @override
  String get notebookSortCreated => 'Newest created';

  @override
  String get notebookSortNewest => 'Newest first';

  @override
  String get notebookSortOldest => 'Oldest first';

  @override
  String get notebookSortOff => 'Back to the usual order';

  @override
  String get spacesPeopleWaiting => 'join requests waiting';

  @override
  String get spacesInfoWorkTools => 'Work';
}
