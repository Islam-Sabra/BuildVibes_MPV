import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_provider.dart';

/// Why the server didn't send a test alert.
enum AlertTestFailure {
  /// 22023 "at most 3 an hour".
  tooMany,
  network,
  other,
}

class AlertTestException implements Exception {
  const AlertTestException(this.failure, [this.message]);

  final AlertTestFailure failure;
  final String? message;

  @override
  String toString() => 'AlertTestException($failure, $message)';
}

/// Review 114 "Send me a test": the server sends this person one
/// `need_you_test` push on the strong channel (send_test_alert, to the
/// caller only, at most 3 an hour). With no push token on the server it
/// queues nothing, so the phone registers its token first.
abstract class AlertTestRepository {
  Future<void> send();
}

/// The failure a refusal of send_test_alert stands for.
AlertTestFailure alertTestFailureFor(String? code, String? message) =>
    code == '22023' && (message ?? '').contains('at most 3')
    ? AlertTestFailure.tooMany
    : AlertTestFailure.other;

class SupabaseAlertTestRepository implements AlertTestRepository {
  const SupabaseAlertTestRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> send() async {
    try {
      await _client.rpc<void>('send_test_alert');
    } on PostgrestException catch (e) {
      throw AlertTestException(
        alertTestFailureFor(e.code, e.message),
        e.message,
      );
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw AlertTestException(
        network ? AlertTestFailure.network : AlertTestFailure.other,
        '$e',
      );
    }
  }
}

final alertTestRepositoryProvider = Provider<AlertTestRepository>(
  (ref) => SupabaseAlertTestRepository(ref.watch(supabaseClientProvider)),
);
