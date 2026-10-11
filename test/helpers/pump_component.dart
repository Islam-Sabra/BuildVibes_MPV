import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/theme/bv_theme.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const languages = ['en', 'ar'];

/// Runs [body] once in English and once in Arabic.
void testBoth(
  String description,
  Future<void> Function(WidgetTester tester, String lang) body,
) {
  for (final lang in languages) {
    testWidgets('$description [$lang]', (tester) => body(tester, lang));
  }
}

/// Pumps [child] on a 390×844 phone with the app theme and localisation.
Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  required String lang,
  bool scroll = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = Locale(lang);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: BvTheme.forLocale(locale),
      home: Scaffold(
        body: scroll
            ? SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                child: child,
              )
            : child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool isRtl(String lang) => lang == 'ar';

/// The fill of the nearest [Material] above [finder].
Color? materialColor(WidgetTester tester, Finder finder) => tester
    .widget<Material>(
      find.ancestor(of: finder, matching: find.byType(Material)).first,
    )
    .color;

/// The [BoxDecoration] of a keyed [Container] or [DecoratedBox].
BoxDecoration decorationOf(WidgetTester tester, Finder finder) {
  final widget = tester.widget(finder);
  return switch (widget) {
        Container(:final decoration, :final color) =>
          decoration ?? BoxDecoration(color: color),
        DecoratedBox(:final decoration) => decoration,
        _ => throw StateError('No decoration on $widget'),
      }
      as BoxDecoration;
}

TextStyle textStyle(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;
