// Text sizes v2 (review 53 Part C) and the Arabic font Almarai (F33).
import 'dart:io';

import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Size, line height and weight of [s].
(double, double, FontWeight) _spec(TextStyle s) =>
    (s.fontSize!, s.fontSize! * s.height!, s.fontWeight!);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('two sizes on working screens', () {
    const bold = FontWeight.w700;
    const semi = FontWeight.w600;
    const medium = FontWeight.w500;
    const regular = FontWeight.w400;

    test('Latin: main 15/22, small 12/16', () {
      final t = BvType.latin;
      expect(_spec(t.headingMd), (15, 22, bold));
      expect(_spec(t.titleLg), (15, 22, bold));
      expect(_spec(t.titleMd), (15, 22, semi));
      expect(_spec(t.labelLg), (15, 22, semi));
      expect(_spec(t.button), (15, 22, semi));
      expect(_spec(t.labelMd), (15, 22, medium));
      expect(_spec(t.bodyLg), (15, 22, regular));
      expect(_spec(t.bodyMd), (15, 22, regular));
      expect(_spec(t.bodySm), (15, 22, regular));
      expect(_spec(t.labelSm), (12, 16, medium));
      expect(_spec(t.overline), (12, 16, semi));
      expect(_spec(t.metadata), (12, 16, regular));
    });

    test('Arabic: main 16/26, small 13/18, Regular and Bold only', () {
      final t = BvType.arabic;
      expect(_spec(t.headingMd), (16, 26, bold));
      expect(_spec(t.titleLg), (16, 26, bold));
      expect(_spec(t.titleMd), (16, 26, bold));
      expect(_spec(t.labelLg), (16, 26, bold));
      expect(_spec(t.button), (16, 26, bold));
      expect(_spec(t.labelMd), (16, 26, regular));
      expect(_spec(t.bodyLg), (16, 26, regular));
      expect(_spec(t.bodyMd), (16, 26, regular));
      expect(_spec(t.bodySm), (16, 26, regular));
      expect(_spec(t.labelSm), (13, 18, regular));
      expect(_spec(t.overline), (13, 18, bold));
      expect(_spec(t.metadata), (13, 18, regular));
    });

    test('the large three keep their values', () {
      expect(_spec(BvType.latin.displayBrand), (28, 34, bold));
      expect(_spec(BvType.latin.headingXl), (24, 30, bold));
      expect(_spec(BvType.latin.headingLg), (20, 26, bold));
      expect(_spec(BvType.arabic.displayBrand), (32, 40, bold));
      expect(_spec(BvType.arabic.headingXl), (28, 36, bold));
      expect(_spec(BvType.arabic.headingLg), (20, 28, bold));
    });
  });

  group('the Arabic font', () {
    List<TextStyle> all(BvTypeSet t) => [
      t.displayBrand, t.headingXl, t.headingLg, t.headingMd, t.titleLg, //
      t.titleMd, t.bodyLg, t.bodyMd, t.bodySm, t.labelLg, t.labelMd,
      t.labelSm, t.metadata, t.button, t.overline,
    ];

    test('Arabic styles are Almarai, falling back to Plus Jakarta Sans', () {
      expect(BvFonts.arabic, 'Almarai');
      for (final s in all(BvType.arabic)) {
        expect(s.fontFamily, BvFonts.arabic);
        expect(s.fontFamilyFallback, [BvFonts.latin]);
        expect(s.fontWeight, anyOf(FontWeight.w400, FontWeight.w700));
        expect(s.letterSpacing ?? 0, lessThanOrEqualTo(0));
      }
      for (final s in all(BvType.latin)) {
        expect(s.fontFamily, BvFonts.latin);
        expect(s.fontFamilyFallback, [BvFonts.arabic]);
      }
    });

    test('Latin words and digits in Arabic text render in Plus Jakarta '
        'Sans, Arabic in Almarai', () async {
      Future<void> family(String name, List<String> files) async {
        final loader = FontLoader(name);
        for (final f in files) {
          loader.addFont(rootBundle.load('assets/fonts/$f'));
        }
        await loader.load();
      }

      await family(BvFonts.latin, [
        'PlusJakartaSans-Regular.ttf',
        'PlusJakartaSans-Bold.ttf',
      ]);
      await family(BvFonts.arabic, ['Almarai-Regular.ttf', 'Almarai-Bold.ttf']);

      double width(String text, TextStyle style) {
        final p = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final w = p.width;
        p.dispose();
        return w;
      }

      final arabic = BvType.arabic.bodyMd;
      final latinOnly = arabic.copyWith(
        fontFamily: BvFonts.latin,
        fontFamilyFallback: const <String>[],
      );
      final arabicOnly = arabic.copyWith(fontFamilyFallback: const <String>[]);

      // Latin words and digits inside an Arabic style measure exactly as
      // Plus Jakarta Sans: Almarai is subset, so it has no Latin or digits.
      for (final run in ['KCT-014', 'BIM', '10:56', 'C7']) {
        expect(width(run, arabic), width(run, latinOnly), reason: run);
      }

      // Arabic letters (and the space between them) come from Almarai.
      const arabicRun = 'وقّع كمنجز';
      expect(width(arabicRun, arabic), width(arabicRun, arabicOnly));
      expect(width(arabicRun, arabic), isNot(width(arabicRun, latinOnly)));
    });

    test('pubspec bundles Almarai Regular and Bold, and no Noto', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: Almarai'));
      expect(pubspec, contains('assets/fonts/Almarai-Regular.ttf'));
      expect(pubspec, contains('assets/fonts/Almarai-Bold.ttf'));
      expect(pubspec, isNot(contains('Noto')));
    });
  });

  test('displayBrand, headingXl and headingLg are used only on the entry '
      'screens and the three named exceptions', () {
    const allowed = {
      'lib/core/design/bv_tokens.dart', // where they are defined
      'lib/shared/widgets/bv_avatar.dart', // xl initials
      'lib/shared/widgets/bv_code_tag.dart', // the invite code
      'lib/shared/widgets/bv_code_field.dart',
    };
    final large = RegExp(r'\b(displayBrand|headingXl|headingLg)\b');
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/features/entry/')) continue;
      if (path.startsWith('lib/l10n/gen/')) continue;
      if (allowed.contains(path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (large.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
