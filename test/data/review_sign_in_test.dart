// The store reviewer's sign-in (review 69 §6, D4; review 73 B3, B4): only
// the build's reviewer email goes to the review-sign-in function, no email
// code is sent to it, and the session it gives takes the same path as an
// email-code sign-in.
import 'dart:convert';

import 'package:buildvibes/data/models/people.dart';
import 'package:buildvibes/data/repositories/auth_repository.dart';
import 'package:buildvibes/data/repositories/profile_repository.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fakes.dart';

const _reviewEmail = 'reviewer@example.com';
const _reviewerId = '11111111-1111-4111-8111-111111111111';

int _inAnHour() => DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

/// An unsigned JWT that is good for an hour; the client only reads it.
String _accessToken() {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': _reviewerId, 'exp': _inAnHour(), 'role': 'authenticated'})}.sig';
}

Map<String, Object> _session() => {
  'access_token': _accessToken(),
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': _inAnHour(),
  'refresh_token': 'refresh-1',
  'user': {
    'id': _reviewerId,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': _reviewEmail,
    'app_metadata': {'review': true},
    'user_metadata': <String, Object>{},
    'created_at': '2026-12-01T10:00:00Z',
  },
};

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

/// A stand-in for Supabase: records every request, and answers the
/// function, the refresh-token exchange and the email-code check.
class _Server {
  final requests = <http.Request>[];

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/functions/v1/review-sign-in')) {
      return _json({
        'access_token': _accessToken(),
        'refresh_token': 'refresh-1',
      });
    }
    if (path.endsWith('/auth/v1/token') || path.endsWith('/auth/v1/verify')) {
      return _json(_session());
    }
    return _json(<String, Object>{});
  });

  Iterable<String> get paths => requests.map((r) => r.url.path);
}

SupabaseAuthRepository _repo(
  _Server server, {
  String reviewEmail = _reviewEmail,
}) => SupabaseAuthRepository(
  SupabaseClient(
    'http://supabase.test',
    'anon-key',
    httpClient: server.client,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  ),
  reviewEmail: reviewEmail,
);

/// The app's gate on [auth], where the account is scheduled for deletion.
ProviderContainer _gate(AuthRepository auth) {
  final base = completeProfile(_reviewerId);
  final profiles = FakeProfileRepository();
  profiles.profiles[_reviewerId] = MyProfile(
    id: base.id,
    firstName: base.firstName,
    lastName: base.lastName,
    locale: base.locale,
    tradeId: base.tradeId,
    homeMarketId: base.homeMarketId,
    deletionScheduled: true,
  );
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profiles),
    ],
  );
}

/// The gate once it has settled (it loads the user, then the profile).
Future<AppGate> _settledGate(ProviderContainer container) async {
  final sub = container.listen(appGateProvider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 50; i++) {
    final gate = container.read(appGateProvider);
    if (gate != AppGate.loading) return gate;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return container.read(appGateProvider);
}

void main() {
  test('only the reviewer email, in any case, uses the fixed code', () {
    expect(
      isReviewerEmail('Reviewer@Example.com ', 'reviewer@example.com'),
      isTrue,
    );
    expect(
      isReviewerEmail('omar@example.com', 'reviewer@example.com'),
      isFalse,
    );
  });

  test('no reviewer email in the build: everyone signs in by email code', () {
    expect(isReviewerEmail('reviewer@example.com', ''), isFalse);
    expect(isReviewerEmail('', ''), isFalse);
  });

  test('the function\'s answer, in the code screen\'s words', () {
    expect(reviewFailure(401), AuthFailure.wrongCode);
    expect(reviewFailure(429), AuthFailure.tooManyRequests);
    expect(reviewFailure(500), AuthFailure.unknown);
  });

  group('B3: no email code to the reviewer address', () {
    test('sending the code to the reviewer email sends nothing, so the '
        'code screen comes straight away', () async {
      final server = _Server();
      final repo = _repo(server);
      await repo.sendEmailCode(
        email: ' Reviewer@Example.com',
        signUpData: const {},
      );
      await repo.sendConfirmCode(_reviewEmail);
      expect(server.requests, isEmpty);
    });

    test('every other email still gets its code', () async {
      final server = _Server();
      final repo = _repo(server);
      await repo.sendEmailCode(email: 'omar@example.com', signUpData: const {});
      await repo.sendConfirmCode('omar@example.com');
      expect(server.requests, hasLength(2));
      expect(server.paths, everyElement(endsWith('/auth/v1/otp')));
    });

    test('a build without a reviewer email sends to that address as to '
        'anyone', () async {
      final server = _Server();
      final repo = _repo(server, reviewEmail: '');
      await repo.sendEmailCode(email: _reviewEmail, signUpData: const {});
      expect(server.paths.single, endsWith('/auth/v1/otp'));
    });
  });

  group('B4: an account scheduled for deletion', () {
    test('after the function\'s sign-in, the gate asks to restore the '
        'account', () async {
      final server = _Server();
      final repo = _repo(server);
      final container = _gate(repo);
      addTearDown(container.dispose);
      expect(await _settledGate(container), AppGate.signedOut);

      await repo.verifyEmailCode(email: _reviewEmail, code: '480913');
      expect(server.paths.first, endsWith('/functions/v1/review-sign-in'));
      expect(repo.currentUserId, _reviewerId);
      await Future<void>.delayed(Duration.zero);
      expect(await _settledGate(container), AppGate.scheduled);
    });

    test('the same as after an email-code sign-in', () async {
      final server = _Server();
      final repo = _repo(server, reviewEmail: '');
      final container = _gate(repo);
      addTearDown(container.dispose);
      expect(await _settledGate(container), AppGate.signedOut);

      await repo.verifyEmailCode(email: _reviewEmail, code: '480913');
      expect(server.paths.first, endsWith('/auth/v1/verify'));
      await Future<void>.delayed(Duration.zero);
      expect(await _settledGate(container), AppGate.scheduled);
    });
  });
}
