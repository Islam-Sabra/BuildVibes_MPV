// Review 105 Part 2 (SP5 2668:38625, SP6 2668:38752; the lead's rulings
// Q1–Q3): one product language on the Space's Work. A tap opens the item;
// what the old long-press menu held is there (tap the title to edit, the
// For line to give it, "Add an update" at the bottom, Send back for the
// checker, ⋯ for Unpin · Save as template · Cancel). A hold selects, and
// the bottom bar offers Pin · Reminder, then Delete or Archive (review
// 113; the lead's check of 115: cards have no sideways swipe of their own,
// so a sideways swipe is always the page's). Archive is also a Lead's on a
// Checked item (from 105B). Signatures are never on a swipe or a hold. In
// English and Arabic.
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/push/reminders.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_tab.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/proof_camera.dart';
import 'package:buildvibes/features/work/work_gestures.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_swipe_card.dart';
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
/// As the server says (review 113 "hold"): what holding it offers me.
DaybookCard _held(DaybookCard c, PostHold hold) =>
    c.copyWith(post: c.post.shownAs(hold: hold));

DaybookCard _openSleeves(DaybookSamples s) => _held(
  s.sleevesCard(upTo: DaybookSamples.sleevesSentBackAt),
  PostHold.delete,
);

Future<void> _pinNothing(DaybookPost post, {required bool on}) async {}

Future<void> _archiveNothing(DaybookPost post) async {}

/// The hold bar's actions, in reading order (mirrored in Arabic).
List<String> _order(WidgetTester tester, String lang) {
  final keys = [
    for (final k in [
      'select-pin',
      'select-unpin',
      'select-remind',
      'select-stop',
      'select-archive',
      'select-delete',
    ])
      if (_key(k).evaluate().isNotEmpty) k,
  ];
  double x(String k) => tester.getCenter(_key(k)).dx;
  return keys..sort(
    (a, b) => lang == 'ar' ? x(b).compareTo(x(a)) : x(a).compareTo(x(b)),
  );
}

/// The colour of a hold bar action's icon.
Color? _ink(WidgetTester tester, String k) => tester
    .widget<Icon>(find.descendant(of: _key(k), matching: find.byType(Icon)))
    .color;

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
        // Review 110: the composer, filled with the post.
        expect(_key('composer'), findsOneWidget);
        expect(
          tester.widget<TextField>(_key('writing-title')).controller!.text,
          s.sleeves,
        );
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
      testWidgets('a hold selects: "1 selected" with ✕ up top, Delete at '
          'the bottom; no Share, no Duplicate and no Move (review 113)', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [_openSleeves(s), _held(s.gate(), PostHold.delete)],
        );
        await _holdCard(tester, 'post-sleeves');
        expect(_key('space-selection-header'), findsOneWidget);
        expect(find.text(l10n.workSelected(1)), findsOneWidget);
        expect(_key('selection-bar'), findsOneWidget);
        expect(_key('select-delete'), findsOneWidget);
        expect(_key('select-archive'), findsNothing);
        expect(_key('select-duplicate'), findsNothing);
        expect(_key('select-share'), findsNothing);
        expect(_key('select-move'), findsNothing);
        expect(tester.widget<BvSlip>(_slip('post-sleeves')).selected, isTrue);
        // A tap now adds one; ✕ ends it.
        await _tapCard(tester, 'post-gate');
        expect(find.text(l10n.workSelected(2)), findsOneWidget);
        expect(_key('daybook-page'), findsNothing);
        await _tap(tester, _key('selection-close'));
        expect(_key('space-selection-header'), findsNothing);
        expect(_key('selection-bar'), findsNothing);
      });

      testWidgets('review 113: no Delete or Archive on someone else\'s '
          'post, or a Checked one ("hold" null); its Reminder still', (
        tester,
      ) async {
        await _open(tester, lang, posts: [s.gate()]);
        await _holdCard(tester, 'post-gate');
        expect(_key('selection-bar'), findsOneWidget);
        expect(_key('select-remind'), findsOneWidget);
        expect(_key('select-delete'), findsNothing);
        expect(_key('select-archive'), findsNothing);
      });

      testWidgets('review 113: Delete and Archive show only when every '
          'held post offers it', (tester) async {
        await _open(
          tester,
          lang,
          posts: [_openSleeves(s), _held(s.gate(), PostHold.archive)],
        );
        await _holdCard(tester, 'post-gate');
        expect(_key('select-archive'), findsOneWidget);
        expect(_key('select-delete'), findsNothing);
        await _tapCard(tester, 'post-sleeves');
        expect(_key('select-archive'), findsNothing);
        expect(_key('select-delete'), findsNothing);
      });

      testWidgets('review 113: Archive of an open work item says what it '
          'does first, then archives it, with Undo', (tester) async {
        final daybook = FakeDaybookRepository();
        await _open(
          tester,
          lang,
          posts: [_held(s.rebar(), PostHold.archive)],
          daybook: daybook,
        );
        await _holdCard(tester, 'post-rebar');
        await _tap(tester, _key('select-archive'));
        expect(find.text(l10n.holdArchiveOpenTitle), findsOneWidget);
        expect(daybook.calls, isNot(contains('archive post-rebar')));
        await _tap(tester, find.text(l10n.workArchive).last);
        expect(daybook.calls, contains('archive post-rebar'));
        expect(find.text(l10n.workArchived), findsOneWidget);
        expect(_entry('post-rebar'), findsNothing);
      });

      testWidgets('review 113: Archive of a post that isn\'t an open work '
          'item goes without asking', (tester) async {
        final daybook = FakeDaybookRepository();
        await _open(
          tester,
          lang,
          posts: [_held(s.gate(), PostHold.archive)],
          daybook: daybook,
        );
        await _holdCard(tester, 'post-gate');
        await _tap(tester, _key('select-archive'));
        expect(find.text(l10n.holdArchiveOpenTitle), findsNothing);
        expect(daybook.calls, contains('archive post-gate'));
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

      testWidgets('one someone has acted on stays, and says so (review 113)', (
        tester,
      ) async {
        final daybook = FakeDaybookRepository()..actedOn.add('post-sleeves');
        await _open(tester, lang, posts: [_openSleeves(s)], daybook: daybook);
        await _holdCard(tester, 'post-sleeves');
        await _tap(tester, _key('select-delete'));
        await _tap(tester, find.text(l10n.delete).last);
        expect(find.text(l10n.holdDeleteActed), findsOneWidget);
        expect(_entry('post-sleeves'), findsOneWidget);
      });

      testWidgets('H5: Delete of several tries each one; one that fails '
          'doesn\'t stop the rest, and it is named after', (tester) async {
        final daybook = FakeDaybookRepository()
          ..deleteFails.add('post-sleeves');
        await _open(
          tester,
          lang,
          posts: [_openSleeves(s), _held(s.traysForOmar(), PostHold.delete)],
          daybook: daybook,
        );
        await _holdCard(tester, 'post-sleeves');
        await _tapCard(tester, 'post-trays');
        await _tap(tester, _key('select-delete'));
        expect(find.text(l10n.daybookDeleteTitle(2)), findsOneWidget);
        await _tap(tester, find.text(l10n.delete).last);
        expect(daybook.calls, contains('delete post-trays'));
        expect(
          find.text(
            l10n.daybookDeleteFailed(joinMeta([s.sleevesCard().post.title])),
          ),
          findsOneWidget,
        );
        expect(_entry('post-sleeves'), findsOneWidget);
      });

      testWidgets('a Viewer\'s hold: their own Pin · Reminder only, as the '
          'swipe gave them', (tester) async {
        await _open(
          tester,
          lang,
          posts: [s.sleevesCard(me: DaybookSamples.lina, viewer: true)],
          me: DaybookSamples.lina,
          pass: SpacePass.viewer,
          later: const WorkLater(pin: _pinNothing, archive: _archiveNothing),
        );
        await _holdCard(tester, 'post-sleeves');
        expect(_order(tester, lang), ['select-pin', 'select-remind']);
      });

      testWidgets('no signature on a hold: the owner\'s hold selects, and '
          'never opens the proof', (tester) async {
        await _open(tester, lang, posts: [_held(s.rebar(), PostHold.delete)]);
        await _holdCard(tester, 'post-rebar');
        expect(find.byType(ProofCamera), findsNothing);
        expect(_key('selection-bar'), findsOneWidget);
      });
    });

    // The lead's check of 115: one gesture model. A hold is a card's
    // actions; it has no sideways swipe of its own any more. The hold bar
    // holds only what I may do there: Pin · Reminder, then Archive or
    // Delete last, in red.
    group('115 hold bar [$lang]', () {
      const pinAndArchive = WorkLater(
        pin: _pinNothing,
        archive: _archiveNothing,
      );

      testWidgets('a Lead on a Checked item: Pin · Reminder · Archive, in '
          'that order, Archive last in red', (tester) async {
        await _open(tester, lang, posts: [s.gate()], later: pinAndArchive);
        await _holdCard(tester, 'post-gate');
        expect(_order(tester, lang), [
          'select-pin',
          'select-remind',
          'select-archive',
        ]);
        expect(_key('select-delete'), findsNothing);
        expect(_ink(tester, 'select-archive'), BvColors.textDestructive);
        expect(_ink(tester, 'select-pin'), BvColors.iconPrimary);
        expect(
          find.descendant(
            of: _key('select-pin'),
            matching: find.text(l10n.workPin),
          ),
          findsOneWidget,
        );
      });

      testWidgets('my post nobody acted on: Pin · Reminder · Delete, Delete '
          'last in red', (tester) async {
        await _open(
          tester,
          lang,
          posts: [_openSleeves(s)],
          later: pinAndArchive,
        );
        await _holdCard(tester, 'post-sleeves');
        expect(_order(tester, lang), [
          'select-pin',
          'select-remind',
          'select-delete',
        ]);
        expect(_ink(tester, 'select-delete'), BvColors.textDestructive);
      });

      testWidgets('Crew may not archive a Checked item: Pin · Reminder only', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [s.gate()],
          me: DaybookSamples.omar,
          pass: SpacePass.crew,
          later: pinAndArchive,
        );
        await _holdCard(tester, 'post-gate');
        expect(_order(tester, lang), ['select-pin', 'select-remind']);
      });

      testWidgets('no Archive for a Lead before 105B brings it, nor Pin: '
          'Reminder only', (tester) async {
        await _open(tester, lang, posts: [s.gate()]);
        await _holdCard(tester, 'post-gate');
        expect(_order(tester, lang), ['select-remind']);
      });

      testWidgets('a Lead archives a Checked item from the hold bar', (
        tester,
      ) async {
        final daybook = FakeDaybookRepository();
        await _open(
          tester,
          lang,
          posts: [s.gate(), s.rebar()],
          daybook: daybook,
          later: pinAndArchive,
        );
        await _holdCard(tester, 'post-gate');
        await _tap(tester, _key('select-archive'));
        expect(find.text(l10n.holdArchiveOpenTitle), findsNothing);
        expect(daybook.calls, contains('archive post-gate'));
        expect(find.text(l10n.workArchived), findsOneWidget);
        expect(_entry('post-gate'), findsNothing);
      });

      testWidgets('Reminder sets a phone notification for me only, then '
          'reads Change reminder', (tester) async {
        final at = DateTime(2026, 10, 15, 13, 30);
        final app = await _open(
          tester,
          lang,
          posts: [s.rebar()],
          due: (day: DateTime(2026, 10, 15), at: at),
        );
        await _holdCard(tester, 'post-rebar');
        await _tap(tester, _key('select-remind'));
        expect(_key('selection-bar'), findsNothing);
        // Review 108 RM1: the Reminder sheet, Me first; Pick… then Set.
        expect(_key('reminder-sheet'), findsOneWidget);
        await _tap(tester, _key('reminder-pick'));
        await _tap(tester, _key('reminder-set'));
        final id = spaceReminderId(DaybookSamples.space, 'post-rebar');
        expect(app.reminders.onPhone[id]?.at, at);
        expect(app.reminders.onPhone[id]?.title, s.rebar().post.title);
        await _holdCard(tester, 'post-rebar');
        expect(
          find.descendant(
            of: _key('select-remind'),
            matching: find.text(l10n.workChangeReminder),
          ),
          findsOneWidget,
        );
      });

      testWidgets('Reminder is for one held card only', (tester) async {
        await _open(tester, lang, posts: [s.rebar(), s.gate()]);
        await _holdCard(tester, 'post-rebar');
        expect(_key('select-remind'), findsOneWidget);
        await _tapCard(tester, 'post-gate');
        expect(find.text(l10n.workSelected(2)), findsOneWidget);
        expect(_key('select-remind'), findsNothing);
      });

      testWidgets('a card has no sideways swipe: no Pin, Reminder or '
          'Archive behind it, and no signature', (tester) async {
        await _open(
          tester,
          lang,
          posts: [s.rebar(), s.gate(), s.sleevesCard()],
          later: pinAndArchive,
        );
        expect(find.byType(BvSwipeCard), findsNothing);
        // Toward the end, where Pin · Reminder were (toward the start is
        // the page's: space_swipe_test).
        for (final id in ['post-rebar', 'post-gate', 'post-sleeves']) {
          await _swipe(tester, id, lang, toEnd: true);
          for (final k in ['swipe-pin', 'swipe-remind', 'swipe-archive']) {
            expect(_key('$k-$id'), findsNothing, reason: '$k-$id');
          }
        }
        expect(_key('selection-bar'), findsNothing);
        expect(find.byType(ProofCamera), findsNothing);
        expect(_key('hold-sheet'), findsNothing);
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
