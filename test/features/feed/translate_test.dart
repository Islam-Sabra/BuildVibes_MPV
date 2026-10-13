import 'package:buildvibes/data/models/post.dart';
import 'package:buildvibes/data/repositories/translate_repository.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/post_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/translate_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

const _en = 'First pour on the podium transfer slab is done.';
const _ar = 'تم صب بلاطة المنصة الانتقالية للمستوى الثالث.';

FakePostRepository _posts() => FakePostRepository(now: testNow)
  ..posts.addAll([
    Post(
      id: 'p-en',
      authorId: 'p-omar2',
      authorName: 'Omar Haddad',
      authorHeadline: 'Site Engineer',
      body: _en,
      lang: 'en',
      createdAt: testNow.subtract(const Duration(hours: 3)),
    ),
    Post(
      id: 'p-ar',
      authorId: 'p-omar2',
      authorName: 'Omar Haddad',
      authorHeadline: 'Site Engineer',
      body: _ar,
      lang: 'ar',
      createdAt: testNow.subtract(const Duration(hours: 4)),
    ),
  ])
  ..home.addAll(['p-en', 'p-ar']);

String? _words(WidgetTester tester, String postId) =>
    tester.widget<Text>(find.byKey(Key('post-body-$postId'))).data;

TextDirection? _direction(WidgetTester tester, String postId) =>
    tester.widget<Text>(find.byKey(Key('post-body-$postId'))).textDirection;

void main() {
  testWidgets('L1 → L2: an English post in the Arabic app', (tester) async {
    final l10n = _l10n('ar');
    final app = await pumpApp(
      tester,
      language: 'ar',
      posts: _posts(),
      translate: FakeTranslateRepository(texts: {'p-en:ar': _ar}),
    );
    // Only the post in the other language offers Translate.
    expect(find.byKey(const Key('post-translate-p-en')), findsOneWidget);
    expect(find.byKey(const Key('post-translate-p-ar')), findsNothing);
    expect(find.text(l10n.translate), findsOneWidget);

    await _tap(tester, 'post-translate-p-en');
    expect(app.translate.calls, ['p-en ar']);
    expect(_words(tester, 'p-en'), _ar);
    // The translation keeps its own direction.
    expect(_direction(tester, 'p-en'), TextDirection.rtl);
    expect(
      find.text(l10n.translatedFrom(l10n.languageNameEnglish)),
      findsOneWidget,
    );

    // Show original, then Translate again without asking the server.
    await _tap(tester, 'post-show-original-p-en');
    expect(_words(tester, 'p-en'), _en);
    expect(_direction(tester, 'p-en'), TextDirection.ltr);
    await _tap(tester, 'post-translate-p-en');
    expect(app.translate.calls, ['p-en ar']);
    expect(_words(tester, 'p-en'), _ar);
  });

  testWidgets('L3 → L4: an Arabic post in the English app', (tester) async {
    final l10n = _l10n('en');
    await pumpApp(
      tester,
      language: 'en',
      posts: _posts(),
      translate: FakeTranslateRepository(texts: {'p-ar:en': _en}),
    );
    expect(find.byKey(const Key('post-translate-p-en')), findsNothing);
    await _tap(tester, 'post-translate-p-ar');
    expect(_words(tester, 'p-ar'), _en);
    expect(_direction(tester, 'p-ar'), TextDirection.ltr);
    expect(
      find.text(l10n.translatedFrom(l10n.languageNameArabic)),
      findsOneWidget,
    );
    expect(find.text(l10n.showOriginal), findsOneWidget);
  });

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final other = lang == 'en' ? 'p-ar' : 'p-en';
    final original = lang == 'en' ? _ar : _en;

    testWidgets('a failure keeps the original, and trying again works '
        '[$lang]', (tester) async {
      final translate = FakeTranslateRepository(
        texts: {'p-ar:en': _en, 'p-en:ar': _ar},
      )..failNext = TranslateFailure.failed;
      final app = await pumpApp(
        tester,
        language: lang,
        posts: _posts(),
        translate: translate,
      );
      await _tap(tester, 'post-translate-$other');
      expect(find.text(l10n.translateFailed), findsOneWidget);
      expect(_words(tester, other), original);
      await _tap(tester, 'post-translate-$other');
      expect(app.translate.calls.length, 2);
      expect(find.text(l10n.showOriginal), findsOneWidget);
    });

    testWidgets('after 100 in a day, it says so [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        posts: _posts(),
        translate: FakeTranslateRepository()..failNext = TranslateFailure.limit,
      );
      await _tap(tester, 'post-translate-$other');
      expect(find.text(l10n.translateLimit), findsOneWidget);
      expect(find.byKey(Key('post-translate-$other')), findsNothing);
      expect(_words(tester, other), original);
    });
  }
}
