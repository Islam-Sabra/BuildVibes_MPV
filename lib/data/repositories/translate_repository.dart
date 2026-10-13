import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_provider.dart';

/// A post in the other app language (L2, L4).
@immutable
class Translation {
  const Translation({required this.body});

  /// Until the translation key is set, the server's fixed test sentence.
  final String body;
}

enum TranslateFailure {
  /// 100 new translations today already.
  limit,
  failed,
}

class TranslateException implements Exception {
  const TranslateException(this.failure);
  final TranslateFailure failure;

  @override
  String toString() => 'TranslateException($failure)';
}

/// The translate Edge Function (migration 17). It reads the post with your
/// own sign-in, so you can only translate what you can see.
abstract class TranslateRepository {
  /// [target] is 'en' or 'ar'.
  Future<Translation> translate(String postId, String target);
}

class SupabaseTranslateRepository implements TranslateRepository {
  const SupabaseTranslateRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Translation> translate(String postId, String target) async {
    try {
      final res = await _client.functions.invoke(
        'translate',
        body: {'post_id': postId, 'target': target},
      );
      final data = res.data;
      if (data is Map && data['body'] is String) {
        return Translation(body: data['body'] as String);
      }
      throw const TranslateException(TranslateFailure.failed);
    } on FunctionException catch (e) {
      throw TranslateException(
        e.status == 429 ? TranslateFailure.limit : TranslateFailure.failed,
      );
    } on TranslateException {
      rethrow;
    } on Exception {
      throw const TranslateException(TranslateFailure.failed);
    }
  }
}

final translateRepositoryProvider = Provider<TranslateRepository>(
  (ref) => SupabaseTranslateRepository(ref.watch(supabaseClientProvider)),
);
