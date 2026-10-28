// Review 101 B: every search waits the same 300 ms after typing, from one
// token, BvMotion.searchWait. No search keeps a 300 of its own.
import 'dart:io';

import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// The five searches that wait after typing.
const _searches = [
  'lib/features/messages/people_search_screen.dart',
  'lib/features/spaces/space_search_screen.dart',
  'lib/features/notebook/notebook_search_screen.dart',
  'lib/features/onboarding/company_sheet.dart',
  'lib/features/projects/add_project_screen.dart',
];

/// A 300 ms wait named as a search's, or a timer started with a bare 300.
final _ownWait = RegExp(
  r'((search|pause|wait|debounce)\w*\s*=\s*Duration\(\s*milliseconds:\s*300\s*\))'
  r'|(Timer\(\s*Duration\(\s*milliseconds:\s*300\s*\))',
  caseSensitive: false,
);

void main() {
  test('the token is 300 ms', () {
    expect(BvMotion.searchWait, const Duration(milliseconds: 300));
  });

  test('all five searches wait with it', () {
    for (final path in _searches) {
      expect(
        File(path).readAsStringSync(),
        contains('BvMotion.searchWait'),
        reason: path,
      );
    }
  });

  test('no search wait of its own is left outside the token', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('core/design/bv_tokens.dart')) continue;
      final text = f.readAsStringSync();
      if (_ownWait.hasMatch(text) || text.contains('searchDebounce')) {
        found.add(path);
      }
    }
    expect(found, isEmpty);
  });
}
