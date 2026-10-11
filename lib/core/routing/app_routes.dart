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

  /// Debug builds only.
  static const components = '/profile/settings/components';

  // Full screens over the tabs
  static const people = '/people';
  static const projects = '/projects';
  static const projectsAdd = '/projects/add';
  static const projectsNew = '/projects/new';

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
