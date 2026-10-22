// Slice 8, My notebook and My calendar (review 83), against NB1 (EN
// 2557:35384, AR 2564:549), Put a note in a Space (2557:35481) and CAL1
// (EN 2557:35587, AR 2564:653). The notebook is on v13 paper, with no
// hour spine (review 83, question 1); the writer, the empty states and
// Delete have no prototype frames (N2, N7 and PL14 give their words).
// English and Arabic, at 390 × 844 on a 12-hour phone, in the app's fonts.
// Run:
//   flutter test test_screens/slice8_test.dart --update-goldens
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_samples.dart';
import '../test/helpers/dm_fakes.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/notebook_fakes.dart';
import '../test/helpers/notebook_samples.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Saves the app as it is now, at 390 × 844 and twice the pixels, to
/// `docs/screens/slice8/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  debugDisableShadows = false;
  ContextMenuController.removeAny();
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/slice8/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// The three Spaces of 2557:35481.
FakeSpaceRepository _spaces(DaybookSamples s, NotebookSamples n) =>
    FakeSpaceRepository()
      ..spaces.addAll([
        SpaceSummary(
          id: DaybookSamples.space,
          name: s.spaceName,
          pass: SpacePass.lead,
          isAdmin: true,
        ),
        SpaceSummary(
          id: NotebookSamples.khiran,
          name: n.t('Khiran villas — Finishing', 'فلل الخيران — التشطيبات'),
          pass: SpacePass.crew,
          isAdmin: false,
        ),
        SpaceSummary(
          id: 'space-office',
          name: n.t('Gulf Build Co. — Office', 'الخليج للبناء — المكتب'),
          pass: SpacePass.lead,
          isAdmin: true,
        ),
      ])
      ..details[DaybookSamples.space] = s.detail()
      ..details[NotebookSamples.khiran] = _detail(NotebookSamples.khiran, s)
      ..details['space-office'] = _detail('space-office', s)
      ..spacePeople[DaybookSamples.space] = s.people();

/// Another Space where I may write work items.
SpaceDetail _detail(String id, DaybookSamples s) => SpaceDetail(
  id: id,
  name: id,
  myPass: SpacePass.crew,
  iAmAdmin: false,
  myRights: s.detail().myRights,
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  bool empty = false,
  String path = '/notebook',
  FakeDmRepository? dm,
}) async {
  final s = DaybookSamples(lang);
  final n = NotebookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    notebook: FakeNotebookRepository(
      notes: empty ? const [] : n.notes(),
      rows: empty ? const [] : n.rows(),
    ),
    spaces: _spaces(s, n),
    dm: dm,
    overrides: [
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async =>
            (day: DateTime(2026, 10, 15), at: DateTime(2026, 10, 15, 16)),
      ),
    ],
  );
  if (path != '/home') {
    GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
    await tester.pumpAndSettle();
  }
  return app;
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final n = NotebookSamples(lang);

    testWidgets('H1: the list-checks icon in the app bar [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, path: '/home');
      await _snap(tester, 'H1-notebook-icon', lang);
    });

    testWidgets('NB1 My notebook [$lang]', (tester) async {
      await _open(tester, lang);
      await _snap(tester, 'NB1-notebook', lang);
      await tester.drag(_key('notebook-list'), const Offset(0, -400));
      await tester.pumpAndSettle();
      await _snap(tester, 'NB1-notebook-earlier', lang);
    });

    testWidgets('NB1 empty (N2\'s words) and Only you [$lang]', (tester) async {
      await _open(tester, lang, empty: true);
      await _tap(tester, _key('notebook-only-you'));
      await _snap(tester, 'NB1-empty', lang);
    });

    testWidgets('writing a checklist and a to-do [$lang]', (tester) async {
      await _open(tester, lang, empty: true);
      await _tap(tester, _key('post-bar-notepad'));
      await _tap(tester, _key('note-kind-checklist'));
      await tester.enterText(_key('note-body'), n.walkTitle);
      await tester.pumpAndSettle();
      await tester.enterText(_key('note-point-0'), n.walkPoints[0]);
      await tester.pumpAndSettle();
      await tester.enterText(_key('note-point-1'), n.walkPoints[1]);
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'NB-write-checklist', lang);
      await _tap(tester, _key('note-kind-todo'));
      await tester.enterText(_key('note-body'), n.sleevesTodo);
      await tester.pumpAndSettle();
      await _tap(tester, _key('note-when'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'NB-write-todo', lang);
    });

    testWidgets('the note\'s menu: Put in a Space, Pin, Edit, Delete; '
        'Delete asks first [$lang]', (tester) async {
      await _open(tester, lang);
      await tester.longPress(_key('note-note-sleeves'));
      await tester.pumpAndSettle();
      await _snap(tester, 'NB-menu', lang);
      await _tap(tester, _key('note-delete'));
      await _snap(tester, 'NB-delete', lang);
    });

    testWidgets('Put in a Space: the Space writing the to-do [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      await tester.longPress(_key('note-note-sleeves'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('note-space-${DaybookSamples.space}'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'NB-put-in-space', lang);
    });

    testWidgets('Save to my notebook on a held message [$lang]', (
      tester,
    ) async {
      final dm = FakeDmRepository()
        ..pages['t-omar'] = DmThreadPage(
          threadId: 't-omar',
          person: DmPerson(
            id: DaybookSamples.omar,
            name: DaybookSamples(lang).omarName,
          ),
          messages: [
            DmMessage(
              id: 'm1',
              fromMe: false,
              kind: ChatKind.text,
              createdAt: DateTime(2026, 10, 15, 10, 40),
              body: n.t('At the gate at 7?', 'عند البوابة الساعة 7؟'),
            ),
          ],
        );
      await _open(tester, lang, dm: dm, path: '/messages/t-omar');
      await tester.longPress(_key('chat-message-m1'));
      await tester.pumpAndSettle();
      await _snap(tester, 'DM3-save-to-notebook', lang);
    });

    testWidgets('CAL1 My calendar [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, _key('notebook-calendar'));
      await _snap(tester, 'CAL1-calendar', lang);
      await _tap(tester, _key('calendar-day-10-12'));
      await _snap(tester, 'CAL1-from-monday', lang);
    });

    testWidgets('My calendar: an empty week [$lang]', (tester) async {
      await _open(tester, lang, empty: true);
      await _tap(tester, _key('notebook-calendar'));
      expect(find.text(l10n.calendarEmpty), findsOneWidget);
      await _snap(tester, 'CAL-empty', lang);
    });
  }
}
