// F102 (review 50): the mute sheet ("For how long?") and muted rows with
// Phosphor's bell-slash, in Messages and in Home → Spaces. No Figma frame
// (a founder request, 24 Oct): built from the sheet and row components.
// English and Arabic, at 390 × 844, in the app's fonts.
// Run:
//   flutter test test_screens/f102_test.dart --update-goldens
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/dm_fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Saves the app as it is now to `docs/screens/f102/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/f102/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

final _now = DateTime(2026, 10, 15, 11);

DmRow _row(
  String thread,
  String name,
  String text, {
  required DateTime at,
  bool muted = false,
  bool unread = false,
}) => DmRow(
  threadId: thread,
  person: DmPerson(id: 'p-$thread', name: name),
  lastMessageAt: at,
  muted: muted,
  unread: unread,
  last: DmPreview(fromMe: false, kind: ChatKind.text, at: at, text: text),
);

FakeDmRepository _dm(String lang) {
  final ar = lang == 'ar';
  return FakeDmRepository()
    ..inboxValue = DmInbox(
      threads: [
        _row(
          't-omar',
          ar ? 'عمر حداد' : 'Omar Haddad',
          ar ? 'المضخة متأخرة' : 'Pump is late',
          at: DateTime(2026, 10, 15, 10, 42),
          muted: true,
          unread: true,
        ),
        _row(
          't-sara',
          ar ? 'سارة علي' : 'Sara Ali',
          ar ? 'الصور في المكتبة' : 'The photos are in the Library',
          at: DateTime(2026, 10, 15, 9, 20),
        ),
        _row(
          't-rakesh',
          'Rakesh Nair',
          ar ? 'تم' : 'Done',
          at: DateTime(2026, 10, 15, 8, 5),
          muted: true,
        ),
      ],
    )
    ..pages['t-sara'] = DmThreadPage(
      threadId: 't-sara',
      person: DmPerson(id: 'p-t-sara', name: ar ? 'سارة علي' : 'Sara Ali'),
    );
}

FakeSpaceRepository _spaces(String lang) {
  final ar = lang == 'ar';
  return FakeSpaceRepository(now: testNow)
    ..spaces.addAll([
      SpaceSummary(
        id: 'space-1',
        name: ar ? 'برج ب — فريق الموقع' : 'Tower B — Site team',
        pass: SpacePass.crew,
        isAdmin: false,
        notify: SpaceNotify.off,
        lastActivityAt: testNow.subtract(const Duration(hours: 2)),
      ),
      SpaceSummary(
        id: 'space-2',
        name: ar ? 'فلل الخيران' : 'Khiran villas',
        pass: SpacePass.lead,
        isAdmin: true,
        lastActivityAt: testNow.subtract(const Duration(days: 1)),
      ),
    ]);
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('the mute sheet: For how long? [$lang]', (tester) async {
      await pumpApp(tester, language: lang, dm: _dm(lang), now: _now);
      await _go(tester, '/messages/t-sara');
      await _tap(tester, find.byKey(const Key('dm-more')));
      await _tap(tester, find.byKey(const Key('dm-menu-mute')));
      expect(find.text(l10n.muteForHowLong), findsOneWidget);
      await _snap(tester, 'mute_sheet', lang);
    });

    testWidgets('Messages: muted rows with the bell-slash, the unread dot '
        'kept [$lang]', (tester) async {
      await pumpApp(tester, language: lang, dm: _dm(lang), now: _now);
      await _go(tester, '/messages');
      expect(find.byKey(const Key('messages-muted-t-omar')), findsOneWidget);
      await _snap(tester, 'messages_muted', lang);
    });

    testWidgets('Home → Spaces: a muted Space [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _spaces(lang));
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-space-muted-space-1')), findsOneWidget);
      await _snap(tester, 'spaces_muted', lang);
    });

    testWidgets('Long-press a Space: Mute [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _spaces(lang));
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('home-space-space-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mute-menu-mute')), findsOneWidget);
      await _snap(tester, 'space_long_press', lang);
    });
  }
}
