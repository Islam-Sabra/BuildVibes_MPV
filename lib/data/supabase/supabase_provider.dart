import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

/// Starts Supabase once, before the app runs.
Future<void> initSupabase() async {
  AppConfig.requireSupabase();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // Accepts the legacy anon key or the newer publishable key.
    publishableKey: AppConfig.supabaseAnonKey,
  );
}

/// The Supabase client. Tests override this provider.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
