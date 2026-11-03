// Review 115 (5): some keyboards' "font" feature types Unicode mathematical
// letters (𝑥𝑑𝑓𝑔ℎ) instead of plain ones, and the phone draws them in its
// maths font. Saved text turns them, and fullwidth Latin, back into plain
// letters and digits; nothing site work writes (m², 25°C, ½, µ, ±, ×,
// Arabic) changes. No general NFKC: it would turn m² into m2.
import 'dart:convert';

import 'package:buildvibes/core/text/plain_letters.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/repositories/notebook_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('mathematical italic, bold, script and fullwidth letters go plain', () {
    expect(plainLetters('𝑥𝑑𝑓𝑔ℎ'), 'xdfgh');
    expect(plainLetters('𝑓𝑓𝑑𝑠'), 'ffds');
    expect(plainLetters('𝐁𝐨𝐥𝐝 𝐀𝟏'), 'Bold A1');
    expect(plainLetters('𝓢𝓬𝓻𝓲𝓹𝓽'), 'Script');
    expect(plainLetters('𝒮𝒸𝓇𝒾𝓅𝓉 ℬℰℳ ℯℊℴ'), 'Script BEM ego');
    expect(plainLetters('𝔉𝔯𝔞𝔨𝔱𝔲𝔯 ℭℌℑℜℨ'), 'Fraktur CHIRZ');
    expect(plainLetters('𝕯𝖔𝖚𝖇𝖑𝖊 ℂℍℕℙℚℝℤ 𝟘𝟙𝟡'), 'Double CHNPQRZ 019');
    expect(
      plainLetters('𝖲𝖺𝗇𝗌 𝘐𝘵𝘢𝘭𝘪𝘤 𝙼𝚘𝚗𝚘 𝟶𝟽'),
      'Sans Italic Mono 07',
    );
    expect(plainLetters('ｆｕｌｌｗｉｄｔｈ ＡＢＣ'), 'fullwidth ABC');
    expect(plainLetters('𝚤𝚥'), 'ij');
    expect(plainLetters('𝛂𝛃 𝜴'), 'αβ Ω');
  });

  test('what site work writes stays as it is', () {
    for (final s in [
      'Slab 120 m² at 25°C',
      '½ bag, ± 2 mm, 3 × 4, 5 µm',
      '«النص العربي» ٣ أمتار',
      'Rebar Ø12 @ 150, 10³ kg',
      'A-501 Rev D: done ✓',
      '',
    ]) {
      expect(plainLetters(s), s, reason: s);
    }
  });

  test('a saved notebook entry goes to the server in plain letters', () async {
    final sent = <String>[];
    final client = SupabaseClient(
      'https://test.supabase.co',
      'anon-key',
      httpClient: PlainLettersClient(
        MockClient((request) async {
          sent.add(request.body);
          return http.Response(
            jsonEncode('note-1'),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      ),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    await SupabaseNotebookRepository(client).save(
      Note(
        id: 'note-1',
        kind: NoteKind.text,
        createdAt: DateTime(2026, 11, 3),
        body: '𝑥𝑑𝑓𝑔ℎ 120 m²',
      ),
    );
    expect(sent.join(), contains('xdfgh 120 m²'));
    expect(sent.join(), isNot(contains('𝑥')));
  });

  test('uploads and reads pass through untouched', () async {
    final seen = <http.BaseRequest>[];
    final client = PlainLettersClient(
      MockClient((request) async {
        seen.add(request);
        return http.Response('[]', 200);
      }),
    );
    final get = http.Request(
      'GET',
      Uri.parse('https://test.supabase.co/rest/v1/notes?q=𝑥'),
    );
    await client.send(get);
    expect(Uri.decodeComponent(seen.single.url.query), contains('𝑥'));
  });
}
