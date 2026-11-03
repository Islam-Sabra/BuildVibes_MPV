// B4 (review 114): an upload with a progress bar goes to storage as the
// signed-in person, with the token as it is at send time, refreshed first
// when it has run out. Without it storage sees an anonymous upload and
// answers 400.
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/data/supabase/upload_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'https://test.supabase.co';
const _anonKey = 'anon-key';

/// A token that runs out at [exp] (what the session reads its expiry from).
String _jwt(String name, DateTime exp) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': 'user-1', 'exp': exp.millisecondsSinceEpoch ~/ 1000, 'name': name})}'
      '.sig';
}

Map<String, Object> _session(String token, String refresh) => {
  'access_token': token,
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': refresh,
  'user': {
    'id': 'user-1',
    'aud': 'authenticated',
    'app_metadata': <String, Object>{},
    'user_metadata': <String, Object>{},
    'created_at': '2026-11-01T00:00:00Z',
  },
};

void main() {
  late Directory dir;
  late File file;
  final requests = <http.BaseRequest>[];
  late String fresh;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('bv_upload');
    file = File('${dir.path}/drawing.pdf')
      ..writeAsBytesSync(List.filled(3000, 7));
    requests.clear();
    fresh = _jwt('fresh', DateTime.now().add(const Duration(hours: 1)));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  final server = MockClient((request) async {
    requests.add(request);
    if (request.url.path == '/auth/v1/token') {
      return http.Response(jsonEncode(_session(fresh, 'refresh-2')), 200);
    }
    return http.Response(jsonEncode({'Key': 'space-files/x'}), 200);
  });

  Future<SupabaseClient> signedIn(String token) async {
    final client = SupabaseClient(
      _url,
      _anonKey,
      httpClient: server,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.setInitialSession(
      jsonEncode(_session(token, 'refresh-1')),
    );
    addTearDown(client.dispose);
    return client;
  }

  Future<void> upload(SupabaseClient client) => uploadWithProgress(
    client,
    bucket: 'space-files',
    path: 'space-1/library/f1/a.pdf',
    file: file,
    contentType: 'application/pdf',
    onProgress: (_, _) {},
  );

  http.BaseRequest storageRequest() =>
      requests.singleWhere((r) => r.url.path.startsWith('/storage/'));

  test('the upload carries the signed-in token, and the public key', () async {
    final token = _jwt('now', DateTime.now().add(const Duration(hours: 1)));
    await upload(await signedIn(token));
    final r = storageRequest();
    expect(
      r.url.path,
      '/storage/v1/object/space-files/space-1/library/f1/a.pdf',
    );
    expect(r.headers['Authorization'], 'Bearer $token');
    expect(r.headers['apikey'], _anonKey);
    expect(
      requests.where((r) => r.url.path == '/auth/v1/token'),
      isEmpty,
      reason: 'a token still good is not refreshed',
    );
  });

  test('an expired session is refreshed first; the upload carries the new '
      'token', () async {
    final old = _jwt(
      'old',
      DateTime.now().subtract(const Duration(minutes: 5)),
    );
    await upload(await signedIn(old));
    final refresh = requests.indexWhere((r) => r.url.path == '/auth/v1/token');
    final store = requests.indexOf(storageRequest());
    expect(refresh, isNonNegative, reason: 'the session was refreshed');
    expect(refresh, lessThan(store), reason: 'before the upload');
    expect(storageRequest().headers['Authorization'], 'Bearer $fresh');
  });
}
