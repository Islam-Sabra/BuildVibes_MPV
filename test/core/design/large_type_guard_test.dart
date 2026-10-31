import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two-size rule (review 53 Part C): displayBrand, headingXl and
/// headingLg are used only by the named exceptions below. Each names why;
/// a new one is added here on purpose.
void main() {
  final large = RegExp(r'\b(displayBrand|headingXl|headingLg)\b');

  /// The files that may use the large styles, and how many lines each.
  const allowed = {
    'lib/core/design/bv_tokens.dart': null, // where they are defined
    'lib/shared/widgets/bv_avatar.dart': null, // xl initials
    'lib/shared/widgets/bv_code_tag.dart': null, // the invite code
    'lib/shared/widgets/bv_code_field.dart': null, // the code boxes
    'lib/features/entry/loading_screen.dart': null, // the brand mark
    // Review 107 S1 (founder, 31 Oct): OB1's welcome title only.
    'lib/features/entry/welcome_screen.dart': 1,
  };

  test('displayBrand, headingXl and headingLg are used only by the named '
      'exceptions', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/l10n/gen/')) continue;
      if (allowed.containsKey(path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (large.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });

  test('review 107 S1: on OB1, only the welcome title is headingXl', () {
    final lines = File(
      'lib/features/entry/welcome_screen.dart',
    ).readAsLinesSync();
    final at = [
      for (var i = 0; i < lines.length; i++)
        if (large.hasMatch(lines[i])) i,
    ];
    expect(at, hasLength(allowed['lib/features/entry/welcome_screen.dart']));
    // Its style belongs to obWelcomeTitle's Text, a few lines above.
    final text = lines.sublist(at.single - 3, at.single + 1).join('\n');
    expect(text, contains('l10n.obWelcomeTitle'));
    expect(lines[at.single], contains('headingXl'));
  });
}
