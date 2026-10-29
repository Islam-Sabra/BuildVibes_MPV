// Review 105 Part 2 (SP5 2668:38625, SP6 2668:38752; the lead's rulings
// Q1–Q3): one product language on the Space's Work. A tap opens the item;
// what the old long-press menu held is there (tap the title to edit, the
// For line to give it, "Add an update" at the bottom, Send back for the
// checker, ⋯ for Unpin · Save as template · Cancel). A hold selects, and
// the bottom bar offers Duplicate · Delete (Share from 105B). Swipe toward
// the end: Reminder (Pin from 105B); toward the start: Archive for a Lead
// on a Checked item (from 105B), round like the others. Signatures are
// never on a swipe or a hold. In English and Arabic.
import 'package:buildvibes/core/push/reminders.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_tab.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/proof_camera.dart';
import 'package:buildvibes/features/work/work_gestures.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/reminder_fakes.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));
Finder _entry(String id) => _key('daybook-card-$id');

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookCard> posts,
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  FakeDaybookRepository? daybook,
  PickedDue? due,
  WorkLater later = const WorkLater(),
}) async {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(
      pass: pass,
      admin: me == DaybookSamples.islam,
    )
    ..spacePeople[DaybookSamples.space] = s.people();
  final fake = daybook ?? FakeDaybookRepository();
  fake.posts[DaybookSamples.space] = posts;
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: spaces,
    daybook: fake,
    now: DaybookSamples.thursday,
    overrides: [
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async => due,
      ),
      workLaterProvider.overrideWithValue(later),
    ],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _show(WidgetTester tester, String id) async {
  await scrollToRow(tester, _entry(id));
  await tester.ensureVisible(_entry(id));
  await tester.pumpAndSettle();
}

Finder _slip(String id) =>
    find.descendant(of: _entry(id), matching: find.byType(BvSlip)).first;

Future<void> _tapCard(WidgetTester tester, String id) async {
  await _show(tester, id);
  await tester.tap(_slip(id));
  await tester.pumpAndSettle();
}

Future<void> _holdCard(WidgetTester tester, String id) async {
  await _show(tester, id);
  await tester.longPress(_slip(id));
  await tester.pumpAndSettle();
}

/// Toward the end of the reading direction (right in English, left in
/// Arabic), or toward the start.
Future<void> _swipe(
  WidgetTester tester,
  String id,
  String lang, {
  required bool toEnd,
}) async {
  await _show(tester, id);
  final ltr = lang != 'ar';
  final dx = (toEnd == ltr) ? 160.0 : -160.0;
  await tester.drag(_slip(id), Offset(dx, 0));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// The sleeves, sent back and Open again: Islam's own, for Omar.
DaybookCard _openSleeves(DaybookSamples s) =>
    s.sleevesCard(upTo: DaybookSamples.sleevesSentBackAt);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('Part 2 tap opens [$lang]', () {
      testWidgets('a tap opens the item; no long-press menu any more', (
        tester,
      ) async {
        await _open(tester, lang, posts: [_openSleeves(s)]);
        await _tapCard(tester, 'post-sleeves');
        expect(_key('daybook-page'), findsOneWidget);
        expect(_key('slip-menu'), findsNothing);
      });

      testWidgets('the opened item: the title edits, the For line gives it, '
          '"Add an update" at the bottom, ⋯ holds Save as template and '
          'Cancel', (tester) async {
        await _open(tester, lang, posts: [_openSleeves(s)]);
        await _tapCard(tester, 'post-sleeves');
        expect(_key('page-title'), findsOneWidget);
        expect(_key('page-update'), findsOneWidget);
        expect(_key('page-send-back'), findsNothing);
        // For: Give to on a sheet.
        await _tap(tester, _key('page-for'));
        expect(_key('give-to'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        // Add an update.
        await _tap(tester, _key('page-update'));
        expect(_key('update-field'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        // ⋯
        await _tap(tester, _key('page-more'));
        expect(_key('page-more-template'), findsOneWidget);
        expect(_key('page-more-cancel'), findsOneWidget);
        expect(_key('page-more-unpin'), findsNothing);
        // Cancel work item is held (review 94), and the page closes first.
        await _tap(tester, _key('page-more-cancel'));
        expect(_key('daybook-page'), findsNothing);
        expect(_key('hold-sheet'), findsOneWidget);
      });

      testWidgets('a tap on the title closes the page and edits in place', (
        tester,
      ) async {
        await _open(tester, lang, posts: [_openSleeves(s)]);
        await _tapCard(tester, 'post-sleeves');
        await _tap(tester, _key('page-title'));
        expect(_key('daybook-page'), findsNothing);
        final card = tester.widget<BvWritingCard>(find.byType(BvWritingCard));
        expect(card.titleController!.text, s.sleeves);
      });

      testWidgets('whoever checks it gets Send back as a deliberate button '
          'on the opened item', (tester) async {
        await _open(tester, lang, posts: [s.sleevesCard()]);
        await _tapCard(tester, 'post-sleeves');
        await _tap(tester, _key('page-send-back'));
        expect(_key('send-back-card'), findsOneWidget);
      });

      testWidgets('someone else\'s item: no edit, no give to, no ⋯ Cancel', (
        tester,
      ) async {
        await _open(tester, lang, posts: [s.rebar()]);
        await _tapCard(tester, 'post-rebar');
        expect(_key('page-title'), findsNothing);
        expect(_key('page-for'), findsNothing);
        expect(_key('page-update'), findsOneWidget);
      });

      testWidgets('a Viewer opens it and reads: nothing to do there', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [s.sleevesCard(me: DaybookSamples.lina, viewer: true)],
          me: DaybookSamples.lina,
          pass: SpacePass.viewer,
        );
        await _tapCard(tester, 'post-sleeves');
        expect(_key('daybook-page'), findsOneWidget);
        for (final k in ['page-update', 'page-more', 'page-for']) {
          expect(_key(k), findsNothing, reason: k);
        }
      });
    });

    group('Part 2 hold selects [$lang]', () {
      testWidgets('a hold selects: "1 selected" with ✕ up top, Duplicate · '
          'Delete at the bottom, no Share and no Move', (tester) async {
        await _open(tester, lang, posts: [_openSleeves(s), s.gate()]);
        await _holdCard(tester, 'post-sleeves');
        expect(_key('space-selection-header'), findsOneWidget);
        expect(find.text(l10n.notebookSelected(1)), findsOneWidget);
        expect(_key('selection-bar'), findsOneWidget);
        expect(_key('select-duplicate'), findsOneWidget);
        expect(_key('select-delete'), findsOneWidget);
        expect(_key('select-share'), findsNothing);
        expect(_key('select-move'), findsNothing);
        expect(tester.widget<BvSlip>(_slip('post-sleeves')).selected, isTrue);
        // A tap now adds one; ✕ ends it.
        await _tapCard(tester, 'post-gate');
        expect(find.text(l10n.notebookSelected(2)), findsOneWidget);
        expect(_key('daybook-page'), findsNothing);
        await _tap(tester, _key('selection-close'));
        expect(_key('space-selection-header'), findsNothing);
        expect(_key('selection-bar'), findsNothing);
      });

      testWidgets('Duplicate only for one card; Delete never on a Checked '
          'one', (tester) async {
        await _open(tester, lang, posts: [_openSleeves(s), s.gate()]);
        await _holdCard(tester, 'post-gate');
        InkWell bar(String k) => tester.widget<InkWell>(_key(k));
        expect(bar('select-delete').onTap, isNull);
        expect(bar('select-duplicate').onTap, isNotNull);
        await _tapCard(tester, 'post-sleeves');
        expect(bar('select-duplicate').onTap, isNull);
        expect(bar('select-delete').onTap, isNull);
      });

      testWidgets('Delete my item asks, then deletes it on the server', (
        tester,
      ) async {
        final daybook = FakeDaybookRepository();
        await _open(tester, lang, posts: [_openSleeves(s)], daybook: daybook);
        await _holdCard(tester, 'post-sleeves');
        await _tap(tester, _key('select-delete'));
        expect(find.text(l10n.daybookDeleteTitle(1)), findsOneWidget);
        await _tap(tester, find.text(l10n.delete).last);
        expect(daybook.calls, contains('delete post-sleeves'));
        expect(_key('selection-bar'), findsNothing);
      });

      testWidgets('one someone else added to stays, and says so', (
        tester,
      ) async {
        final daybook = FakeDaybookRepository()
          ..othersAdded.add('post-sleeves');
        await _open(tester, lang, posts: [_openSleeves(s)], daybook: daybook);
        await _holdCard(tester, 'post-sleeves');
        await _tap(tester, _key('select-delete'));
        await _tap(tester, find.text(l10n.delete).last);
        expect(find.text(l10n.daybookDeleteKept(1)), findsOneWidget);
        expect(_entry('post-sleeves'), findsOneWidget);
      });

      testWidgets('Duplicate writes a new card with the same words', (
        tester,
      ) async {
        await _open(tester, lang, posts: [s.gate()]);
        await _holdCard(tester, 'post-gate');
        await _tap(tester, _key('select-duplicate'));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        );
        final draft = container.read(
          daybookDraftProvider(DaybookSamples.space),
        );
        expect(draft, isNotNull);
        expect(draft!.id, isNot('post-gate'));
        expect(draft.title, s.gate().post.title);
        expect(draft.dueDate, isNull);
        expect(_key('selection-bar'), findsNothing);
      });

      testWidgets('Share shows once 105B brings it', (tester) async {
        await _open(
          tester,
          lang,
          posts: [_openSleeves(s)],
          later: WorkLater(share: (context, posts) async {}),
        );
        await _holdCard(tester, 'post-sleeves');
        expect(_key('select-share'), findsOneWidget);
      });

      testWidgets('a Viewer\'s hold selects nothing', (tester) async {
        await _open(
          tester,
          lang,
          posts: [s.sleevesCard(me: DaybookSamples.lina, viewer: true)],
          me: DaybookSamples.lina,
          pass: SpacePass.viewer,
        );
        await _holdCard(tester, 'post-sleeves');
        expect(_key('selection-bar'), findsNothing);
      });

      testWidgets('no signature on a hold: the owner\'s hold selects, and '
          'never opens the proof', (tester) async {
        await _open(tester, lang, posts: [s.rebar()]);
        await _holdCard(tester, 'post-rebar');
        expect(find.byType(ProofCamera), findsNothing);
        expect(_key('selection-bar'), findsOneWidget);
      });
    });

    group('Part 2 swipes [$lang]', () {
      testWidgets('toward the end: Reminder; Pin waits for 105B', (
        tester,
      ) async {
        await _open(tester, lang, posts: [s.rebar()]);
        await _swipe(tester, 'post-rebar', lang, toEnd: true);
        expect(_key('swipe-remind-post-rebar'), findsOneWidget);
        expect(_key('swipe-pin-post-rebar'), findsNothing);
      });

      testWidgets('with 105B: Pin and Reminder', (tester) async {
        await _open(
          tester,
          lang,
          posts: [s.rebar()],
          later: WorkLater(pin: (post, {required on}) async {}),
        );
        await _swipe(tester, 'post-rebar', lang, toEnd: true);
        expect(_key('swipe-pin-post-rebar'), findsOneWidget);
        expect(_key('swipe-remind-post-rebar'), findsOneWidget);
      });

      testWidgets('Reminder sets a phone notification for me only', (
        tester,
      ) async {
        final at = DateTime(2026, 10, 15, 13, 30);
        final app = await _open(
          tester,
          lang,
          posts: [s.rebar()],
          due: (day: DateTime(2026, 10, 15), at: at),
        );
        await _swipe(tester, 'post-rebar', lang, toEnd: true);
        await _tap(tester, _key('swipe-remind-post-rebar'));
        final id = spaceReminderId(DaybookSamples.space, 'post-rebar');
        expect(app.reminders.onPhone[id]?.at, at);
        expect(app.reminders.onPhone[id]?.title, s.rebar().post.title);
        // It shows as set, and can change.
        await _swipe(tester, 'post-rebar', lang, toEnd: true);
        expect(
          find.descendant(
            of: _key('swipe-remind-post-rebar'),
            matching: find.text(l10n.notebookChangeReminder),
          ),
          findsOneWidget,
        );
      });

      testWidgets('toward the start: Archive only for a Lead on a Checked '
          'item, once 105B brings it, a round button', (tester) async {
        await _open(
          tester,
          lang,
          posts: [s.gate(), _openSleeves(s)],
          later: WorkLater(archive: (post) async {}),
        );
        await _swipe(tester, 'post-gate', lang, toEnd: false);
        expect(_key('swipe-archive-post-gate'), findsOneWidget);
        final size = tester.getSize(
          find
              .descendant(
                of: _key('swipe-archive-post-gate'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(size.width, size.height);
        await _swipe(tester, 'post-sleeves', lang, toEnd: false);
        expect(_key('swipe-archive-post-sleeves'), findsNothing);
      });

      testWidgets('no Archive before 105B, nor for Crew', (tester) async {
        await _open(tester, lang, posts: [s.gate()]);
        await _swipe(tester, 'post-gate', lang, toEnd: false);
        expect(_key('swipe-archive-post-gate'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await _open(
          tester,
          lang,
          posts: [s.gate()],
          me: DaybookSamples.omar,
          pass: SpacePass.crew,
          later: WorkLater(archive: (post) async {}),
        );
        await _swipe(tester, 'post-gate', lang, toEnd: false);
        expect(_key('swipe-archive-post-gate'), findsNothing);
      });

      testWidgets('no swipe while cards are held', (tester) async {
        await _open(tester, lang, posts: [s.rebar(), s.gate()]);
        await _holdCard(tester, 'post-gate');
        await _swipe(tester, 'post-rebar', lang, toEnd: true);
        expect(_key('swipe-remind-post-rebar'), findsNothing);
      });

      testWidgets('no signature on a swipe', (tester) async {
        await _open(tester, lang, posts: [s.rebar(), s.sleevesCard()]);
        await _swipe(tester, 'post-rebar', lang, toEnd: true);
        await _swipe(tester, 'post-rebar', lang, toEnd: false);
        await _swipe(tester, 'post-sleeves', lang, toEnd: true);
        expect(find.byType(ProofCamera), findsNothing);
        expect(_key('hold-sheet'), findsNothing);
        expect(find.textContaining(l10n.daybookChecked), findsNothing);
      });
    });
  }

  group('a Space item\'s reminder', () {
    test('its tap goes to the Space, a note\'s to My notebook', () async {
      final phone = FakePhoneReminders();
      final items = <SpaceReminder>[];
      final notes = <String>[];
      final routed = RoutedReminders(phone, onSpaceItem: items.add);
      await routed.init(channel: 'c', channelAbout: 'a', onTap: notes.add);
      phone.tap(spaceReminderId('space-1', 'post-1'));
      phone.tap('note-1');
      expect(items, [(spaceId: 'space-1', postId: 'post-1')]);
      expect(notes, ['note-1']);
    });

    test('opening the app from one: the Space, not My notebook', () async {
      final phone = FakePhoneReminders()
        ..launched = spaceReminderId('space-1', 'post-1');
      final items = <SpaceReminder>[];
      final routed = RoutedReminders(phone, onSpaceItem: items.add);
      expect(await routed.launchedBy(), isNull);
      expect(items, hasLength(1));
      phone.launched = 'note-1';
      expect(await routed.launchedBy(), 'note-1');
    });

    test('a note id is never read as a Space item', () {
      expect(spaceReminderOf('note-1'), isNull);
      expect(spaceReminderOf('space-item:only'), isNull);
    });

    testWidgets('a tap on one opens its card', (tester) async {
      await _open(tester, 'en', posts: [DaybookSamples('en').rebar()]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DaybookTab), findsNothing);
      container.read(spaceReminderTapsProvider).add((
        spaceId: DaybookSamples.space,
        postId: 'post-rebar',
      ));
      await tester.pumpAndSettle();
      expect(find.byType(DaybookTab), findsOneWidget);
      expect(_entry('post-rebar'), findsOneWidget);
    });
  });
}
