import 'dart:io';

import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const all = [
    BvIcons.home,
    BvIcons.explore,
    BvIcons.create,
    BvIcons.activity,
    BvIcons.profile,
    BvIcons.search,
    BvIcons.close,
    BvIcons.check,
    BvIcons.language,
    BvIcons.caretForward,
    BvIcons.caretBack,
    BvIcons.arrowForward,
    BvIcons.arrowBack,
  ];

  test('icons use the bundled Phosphor regular font', () {
    for (final icon in all) {
      expect(icon.fontFamily, 'PhosphorRegular');
      expect(icon.fontPackage, isNull);
    }
    expect(File('assets/fonts/Phosphor-Regular.ttf').existsSync(), isTrue);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('PhosphorRegular'),
    );
  });

  test('only arrows and carets mirror in right to left', () {
    for (final icon in [
      BvIcons.caretForward,
      BvIcons.caretBack,
      BvIcons.arrowForward,
      BvIcons.arrowBack,
    ]) {
      expect(icon.matchTextDirection, isTrue);
    }
    for (final icon in [
      BvIcons.home,
      BvIcons.explore,
      BvIcons.create,
      BvIcons.activity,
      BvIcons.profile,
      BvIcons.search,
      BvIcons.close,
      BvIcons.check,
      BvIcons.language,
    ]) {
      expect(icon.matchTextDirection, isFalse);
    }
  });

  test('no Material icons in lib/', () {
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            RegExp(
              r'(^|[^A-Za-z])Icons\.',
            ).hasMatch(f.readAsStringSync().replaceAll(RegExp(r'//.*'), '')))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
