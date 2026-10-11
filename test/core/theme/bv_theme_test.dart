import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/theme/bv_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BvTheme', () {
    test('English uses the Latin font and type scale', () {
      final theme = BvTheme.forLocale(const Locale('en'));
      expect(theme.textTheme.bodyMedium?.fontFamily, BvFonts.latin);
      final body = theme.textTheme.bodyMedium!;
      expect(body.fontSize, BvType.latin.bodyMd.fontSize);
      expect(body.fontWeight, BvType.latin.bodyMd.fontWeight);
      expect(body.height, BvType.latin.bodyMd.height);
    });

    test('Arabic uses the Arabic font and type scale', () {
      final theme = BvTheme.forLocale(const Locale('ar'));
      expect(theme.textTheme.bodyMedium?.fontFamily, BvFonts.arabic);
      final body = theme.textTheme.bodyMedium!;
      expect(body.fontSize, BvType.arabic.bodyMd.fontSize);
      expect(body.fontWeight, BvType.arabic.bodyMd.fontWeight);
      expect(body.height, BvType.arabic.bodyMd.height);
    });

    test('colours come from the semantic tokens', () {
      final theme = BvTheme.light(BvType.latin);
      expect(theme.scaffoldBackgroundColor, BvColors.surfaceApp);
      expect(theme.colorScheme.primary, BvColors.actionPrimary);
      expect(theme.colorScheme.surface, BvColors.surfaceElevated);
      expect(theme.colorScheme.error, BvColors.feedbackError);
      expect(theme.brightness, Brightness.light);
    });
  });
}
