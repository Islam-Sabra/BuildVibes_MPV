/// Route paths. Entry and onboarding sit outside the tab shell.
abstract final class AppRoutes {
  // Tabs
  static const home = '/home';
  static const explore = '/explore';
  static const activity = '/activity';
  static const profile = '/profile';

  // Profile (inside the Profile tab)
  static const profileSettings = '/profile/settings';
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
  static String workNew(String id) => '/spaces/$id/items/new';
  static String workItem(String id, String itemId) =>
      '/spaces/$id/items/$itemId';
  static String spaceTeam(String id, String teamId) =>
      '/spaces/$id/teams/$teamId';
  static String spaceThread(String id, String threadId) =>
      '/spaces/$id/chat/$threadId';

  // Entry (signed out)
  static const loading = '/loading';
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
