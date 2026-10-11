/// Build-time settings, passed with `--dart-define-from-file=env/dev.json`.
/// The keys are documented in `env/example.json`. Secrets are never
/// committed; the anon key is public by design and protected by RLS.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Google and Apple sign-in. Off until the founder provides the provider
  /// keys; switch on with "SOCIAL_SIGN_IN": "true" in env/dev.json.
  static const socialSignIn = bool.fromEnvironment('SOCIAL_SIGN_IN');

  /// Phone sign-in (WhatsApp or SMS code). Off in the MVP: sign-in is by
  /// email code only (decision 04). The phone screens stay in the app.
  static const phoneSignIn = bool.fromEnvironment('PHONE_SIGN_IN');

  /// LinkedIn is not in the MVP; the E2 layout keeps room for it.
  static const linkedInSignIn = false;

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Fails early with a clear message instead of a confusing network error.
  static void requireSupabase() {
    if (!hasSupabase) {
      throw StateError(
        'Supabase is not configured. Run with '
        '--dart-define-from-file=env/dev.json (see env/example.json).',
      );
    }
  }
}
