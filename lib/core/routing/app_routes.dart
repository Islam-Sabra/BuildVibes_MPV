/// Route paths. Entry and onboarding sit outside the tab shell.
abstract final class AppRoutes {
  // Tabs
  static const home = '/home';
  static const explore = '/explore';
  static const activity = '/activity';
  static const profile = '/profile';

  // Profile (inside the Profile tab)
  static const profileSettings = '/profile/settings';
  static const profileNotifications = '/profile/settings/notifications';
  static const profileBlocked = '/profile/settings/blocked';
  static const profileAccount = '/profile/settings/account';
  static const profileDownload = '/profile/settings/account/download';
  static const profileDelete = '/profile/settings/account/delete';
  static const profileDeleteBlocked =
      '/profile/settings/account/delete/blocked';
  static const profileDeleteConfirm =
      '/profile/settings/account/delete/confirm';
  static const profilePrivacy = '/profile/settings/privacy';
  static const profileRegion = '/profile/settings/region';
  static const profileEdit = '/profile/edit';
  static const profileEditBasics = '/profile/edit/basics';
  static const profileEditAbout = '/profile/edit/about';
  static const profileEditExperience = '/profile/edit/experience';
  static const profileEditExperienceForm = '/profile/edit/experience/form';
  static const profileEditOpenTo = '/profile/edit/open-to';
  static const profileEditProjects = '/profile/edit/projects';
  static const profileDelivered = '/profile/delivered';

  /// Debug builds only.
  static const components = '/profile/settings/components';

  // Full screens over the tabs
  static const people = '/people';
  static String personWork(String profileId, String itemId) =>
      '/people/$profileId/work/$itemId';
  static const projects = '/projects';

  // R3 and R4: something of yours that was removed, and its appeal.
  static const removals = '/removals';
  static String removal(String id) => '/removals/$id';
  static String removalAppeal(String id) => '/removals/$id/appeal';

  // Posts. "new" before ":id".
  static const posts = '/posts';
  static const postNew = '/posts/new';
  static String post(String id) => '/posts/$id';
  static String postEdit(String id) => '/posts/$id/edit';
  static const projectsAdd = '/projects/add';
  static const projectsNew = '/projects/new';

  // Spaces (full screens over the tabs). "new" before ":id".
  static const spaces = '/spaces';
  static const spacesNew = '/spaces/new';
  static String space(String id) => '/spaces/$id';
  static String spaceInvite(String id) => '/spaces/$id/invite';
  static String spaceMember(String id, String profileId) =>
      '/spaces/$id/members/$profileId';
  static String spaceInfo(String id) => '/spaces/$id/info';
  static String spaceTransfer(String id) => '/spaces/$id/transfer';
  static String spaceTeamNew(String id) => '/spaces/$id/teams/new';
  static String spaceTeam(String id, String teamId) =>
      '/spaces/$id/teams/$teamId';
  static String spaceThread(String id, String threadId) =>
      '/spaces/$id/chat/$threadId';
  static String libraryFile(String id, String fileId) =>
      '/spaces/$id/library/$fileId';

  /// Add a file, or a new revision of [supersedes].
  static String libraryAdd(String id, {String? supersedes}) =>
      '/spaces/$id/library/new'
      '${supersedes == null ? '' : '?supersedes=$supersedes'}';

  // Entry (signed out)
  static const loading = '/loading';

  /// S14: deletion scheduled. The only screen until restored.
  static const scheduled = '/scheduled';
  static const welcome = '/welcome';
  static const join = '/join';
  static const joinPhone = '/join/phone';
  static const joinEmail = '/join/email';
  static const joinCode = '/join/code';

  // Onboarding (signed in, profile not finished)
  static const onboarding = '/onboarding';
  static const onboardingAbout = '/onboarding/about';
  static const onboardingRole = '/onboarding/role';
  static const onboardingPeople = '/onboarding/people';
}
