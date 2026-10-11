/// Route paths. Entry and onboarding sit outside the tab shell.
abstract final class AppRoutes {
  // Tabs
  static const home = '/home';
  static const explore = '/explore';
  static const activity = '/activity';
  static const profile = '/profile';

  /// Debug builds only.
  static const components = '/profile/components';

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
