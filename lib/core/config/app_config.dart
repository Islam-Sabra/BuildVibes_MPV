/// Build-time settings, passed with `--dart-define-from-file=env/dev.json`.
/// The keys are documented in `env/example.json`. Secrets are never
/// committed; the anon key is public by design and protected by RLS.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

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
