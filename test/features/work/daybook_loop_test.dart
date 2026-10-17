// Slice 1 part 1d: the work item loop on the daybook. Sign as done with
// the camera (O1–O3), check by double-tap with Undo (B3), the long-press
// menus (B1, X1), send back with a reason (B2, S1), an update by swiping
// (Y1, Y2), edit, give to someone else and cancel (X1–X3).
import 'dart:convert';

import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/proof_camera.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_paper_clip.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:buildvibes/shared/widgets/bv_post_bar.dart';
import 'package:buildvibes/shared/widgets/bv_send_back_card.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:buildvibes/shared/widgets/bv_undo_bar.dart';
import 'package:buildvibes/shared/widgets/bv_update_note.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/work_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

/// The undo bar's 5 seconds, and a little more.
const _undoGone = Duration(seconds: 6);

/// The Space's daybook as [me]: Islam (Lead, admin) or Omar (Crew).
Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookRecord> posts,
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  FakeWorkRepository? work,
  FakeDaybookRepository? daybook,
  PickedDue? due,
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
    work: work,
    daybook: fake,
    now: DaybookSamples.thursday,
    overrides: [
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async => due,
      ),
    ],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

Finder _entry(String id) => find.byKey(Key('daybook-entry-$id'));

Finder _in(String id, Finder f) => find.descendant(of: _entry(id), matching: f);

Future<void> _longPress(WidgetTester tester, String id) async {
  await tester.ensureVisible(_entry(id));
  await tester.pumpAndSettle();
  await tester.longPress(_in(id, find.byType(BvSlip)).first);
  await tester.pumpAndSettle();
}

List<String> _menu(WidgetTester tester) => [
  for (final i
      in tester
          .widget<BvSlipMenu<Object>>(find.byKey(const Key('slip-menu')))
          .items)
    i.label,
];

Future<void> _pick(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const Key('slip-menu')),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _doubleTapProof(WidgetTester tester) async {
  final photo = _in('event-sleeves-done', find.byKey(const Key('slip-photo')));
  await tester.ensureVisible(photo);
  await tester.pumpAndSettle();
  await tester.tap(photo);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(photo);
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);
    // The test phone keeps a 12-hour clock.
    final words = DaybookWords(l10n, lang, use24: false);

    // Omar's side.

    testWidgets('O1: the owner\'s open slip has Sign as done; the camera, '
        'then the proof with a note, sends sign_done [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      expect(
        _in('post-sleeves', find.text(l10n.daybookSignAsDone)),
        findsOneWidget,
      );
      expect(_in('post-sleeves', find.byType(BvPaperClip)), findsOneWidget);
      await tester.tap(_in('post-sleeves', find.text(l10n.daybookSignAsDone)));
      await tester.pumpAndSettle();
      // O2: the photo linked to its work item, labelled with the place.
      expect(find.byType(ProofCamera), findsOneWidget);
      expect(find.text(s.sleeves), findsOneWidget);
      final label = tester.widget<Text>(find.byKey(const Key('proof-label')));
      expect(label.data, contains(s.levelTwo));
      expect(label.data, contains(s.omarName));
      // Another photo, and a note.
      await tester.tap(find.byKey(const Key('proof-add-photo')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proof-note')),
        s.sleevesNote,
      );
      await tester.tap(find.byKey(const Key('proof-send')));
      await tester.pumpAndSettle();
      expect(find.byType(ProofCamera), findsNothing);
      expect(app.work.calls.single, 'done post-sleeves ${s.sleevesNote} 2');
      // Both photos went to the item's own folder first.
      expect(app.work.uploads, hasLength(2));
      expect(
        app.work.uploads.first,
        startsWith('${DaybookSamples.space}/post-sleeves/'),
      );
    });

    testWidgets('O1: holding the post bar\'s camera proves the item due '
        'first; × leaves without signing [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      final bar = tester.widget<BvPostBar>(find.byType(BvPostBar));
      expect(bar.cameraLabel, l10n.daybookHoldToProve);
      await tester.longPress(find.byKey(const Key('post-bar-camera')));
      await tester.pumpAndSettle();
      expect(find.byType(ProofCamera), findsOneWidget);
      // The sleeves are due today, the trays on Sunday.
      expect(find.text(s.sleeves), findsOneWidget);
      await tester.tap(find.byKey(const Key('proof-close')));
      await tester.pumpAndSettle();
      expect(find.byType(ProofCamera), findsNothing);
      expect(app.work.calls, isEmpty);
    });

    testWidgets('a proof sent with no signal waits on the page, DONE on '
        'the item, then sends [$lang]', (tester) async {
      final work = FakeWorkRepository()..failSendNext = 3;
      await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        work: work,
      );
      await tester.tap(_in('post-sleeves', find.text(l10n.daybookSignAsDone)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proof-send')));
      await tester.pumpAndSettle();
      expect(work.calls, isEmpty);
      expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);
      expect(
        _in('post-sleeves', find.text(l10n.daybookStampDone)),
        findsOneWidget,
      );
      expect(
        _in('post-sleeves', find.text(l10n.daybookSignAsDone)),
        findsNothing,
      );
      // The next try, while the daybook is open.
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(work.calls.single, startsWith('done post-sleeves'));
    });

    testWidgets('O3: the owner\'s proof says who checks it next [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        posts: [s.sleevesDone(), s.sleevesSignOff(needsMe: false)],
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      expect(
        _in(
          'event-sleeves-done',
          find.text(l10n.daybookChecksNext(s.islamName)),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.daybookDoubleTapToCheck), findsNothing);
    });

    testWidgets('S1: sent back: SENT BACK on the proof with the reason; the '
        'clip and Sign as done on the item [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: s.s1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      expect(
        _in('event-sleeves-done', find.text(l10n.daybookStampSentBack)),
        findsOneWidget,
      );
      expect(
        _in(
          'event-sleeves-done',
          find.text(
            l10n.daybookSentBackLineNote(
              words.clock(DateTime(2026, 10, 15, 10, 12)),
              l10n.daybookReasonNotAsAsked,
              inOwnDirection(s.sentBackNote),
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(_in('post-sleeves', find.byType(BvPaperClip)), findsOneWidget);
      expect(
        _in('post-sleeves', find.text(l10n.daybookSignAsDone)),
        findsOneWidget,
      );
    });

    testWidgets('Y1, Y2: swipe a slip to the end side, write an update; it '
        'hangs as a note quoting the item [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: [...s.o1(), s.sleevesUpdate()],
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      final update = _in('event-sleeves-update', find.byType(BvUpdateNote));
      expect(update, findsOneWidget);
      expect(
        find.descendant(of: update, matching: find.text(s.sleeves)),
        findsOneWidget,
      );
      await tester.ensureVisible(_entry('post-sleeves'));
      await tester.pumpAndSettle();
      // Towards the end side: right in English, left in Arabic.
      await tester.drag(
        _in('post-sleeves', find.byType(BvSlip)),
        Offset(lang == 'ar' ? -80 : 80, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        _in('post-sleeves', find.byKey(const Key('swipe-reveal-action'))),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('popover-field')),
        'Half done',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(app.work.calls.single, 'comment post-sleeves Half done');
    });

    // Your side.

    testWidgets('B3: double-tap the proof: CHECKED lands, "Checked · Undo", '
        'and check_item goes only after the 5 seconds [$lang]', (tester) async {
      final app = await _open(tester, lang, posts: s.d1());
      await _doubleTapProof(tester);
      expect(
        _in('event-sleeves-done', find.text(l10n.daybookStampChecked)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<BvInkStamp>(
              _in('event-sleeves-done', find.byType(BvInkStamp)),
            )
            .land,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(BvUndoBar),
          matching: find.text(l10n.daybookChecked),
        ),
        findsOneWidget,
      );
      expect(
        find.text(l10n.daybookYouChecked(words.clock(DaybookSamples.thursday))),
        findsOneWidget,
      );
      // Nothing has reached the server yet.
      expect(app.work.calls, isEmpty);
      await tester.pump(_undoGone);
      await tester.pumpAndSettle();
      expect(app.work.calls.single, 'check post-sleeves');
    });

    testWidgets('B3: Undo takes the check back: nothing reaches the server '
        '[$lang]', (tester) async {
      final app = await _open(tester, lang, posts: s.d1());
      await _doubleTapProof(tester);
      await tester.tap(find.byKey(const Key('undo-bar-action')));
      await tester.pumpAndSettle();
      await tester.pump(_undoGone);
      await tester.pumpAndSettle();
      expect(app.work.calls, isEmpty);
      expect(
        _in('event-sleeves-done', find.text(l10n.daybookStampDone)),
        findsOneWidget,
      );
      expect(
        _in('event-sleeves-done', find.text(l10n.daybookStampChecked)),
        findsNothing,
      );
    });

    testWidgets('B1: long-press the proof: the lifted slip and Check, Send '
        'back, Add update; Check checks [$lang]', (tester) async {
      final app = await _open(tester, lang, posts: s.d1());
      await _longPress(tester, 'event-sleeves-done');
      expect(find.byType(BvDim), findsOneWidget);
      // "Discuss in chat" can't quote the item in the chat yet: hidden.
      expect(_menu(tester), [
        l10n.daybookCheck,
        l10n.daybookSendBack,
        l10n.daybookAddUpdate,
      ]);
      await _pick(tester, l10n.daybookCheck);
      expect(find.byType(BvUndoBar), findsOneWidget);
      await tester.pump(_undoGone);
      await tester.pumpAndSettle();
      expect(app.work.calls.single, 'check post-sleeves');
    });

    testWidgets('B2: send back with one reason and a note; "Something else" '
        'needs the note [$lang]', (tester) async {
      final app = await _open(tester, lang, posts: s.d1());
      await _longPress(tester, 'event-sleeves-done');
      await _pick(tester, l10n.daybookSendBack);
      final card = find.byType(BvSendBackCard<SendBackReason>);
      expect(card, findsOneWidget);
      expect(
        find.text(l10n.daybookSendBackTo(s.omarName.split(' ').first)),
        findsOneWidget,
      );
      // No microphone: send_back takes no voice note.
      expect(find.byKey(const Key('send-back-microphone')), findsNothing);
      Finder send() =>
          find.descendant(of: card, matching: find.text(l10n.daybookSendBack));
      await tester.tap(find.text(l10n.daybookReasonOther));
      await tester.pumpAndSettle();
      await tester.tap(send());
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await tester.tap(find.text(l10n.daybookReasonNotAsAsked));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: card, matching: find.byType(TextField)),
        s.sentBackNote,
      );
      await tester.pumpAndSettle();
      await tester.tap(send());
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(
        app.work.calls.single,
        'back post-sleeves not_as_asked ${s.sentBackNote}',
      );
    });

    testWidgets('X1: long-press your own open item: Edit, Add update, Give to '
        'someone else, Cancel work item; someone else\'s: Add update '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [...s.d1(), s.traysForOmar(needsMe: false)],
      );
      await _longPress(tester, 'post-trays');
      expect(_menu(tester), [
        l10n.daybookEdit,
        l10n.daybookAddUpdate,
        l10n.daybookGiveTo,
        l10n.daybookCancelItem,
      ]);
      await tester.tap(find.byType(BvDim));
      await tester.pumpAndSettle();
      // Sara's item for me.
      await _longPress(tester, 'post-rebar');
      expect(_menu(tester), [l10n.daybookAddUpdate]);
    });

    testWidgets('a Viewer gets no long-press menu and no swipe [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        posts: s.d1(viewer: true),
        me: DaybookSamples.mona,
        pass: SpacePass.viewer,
      );
      await _longPress(tester, 'event-sleeves-done');
      expect(find.byKey(const Key('slip-menu')), findsNothing);
      expect(find.byKey(const Key('swipe-reveal')), findsNothing);
    });

    testWidgets('X2: give to someone else: Lead and Crew, the owner "now"; '
        'the pick sends reassign_work_item [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: [s.traysForOmar(needsMe: false)],
      );
      await _longPress(tester, 'post-trays');
      await _pick(tester, l10n.daybookGiveTo);
      final picker = tester.widget<BvGiveToPicker>(
        find.byKey(const Key('give-to')),
      );
      expect(picker.currentOwnerId, DaybookSamples.omar);
      expect(picker.searchPlaceholder, l10n.daybookGiveToSearch);
      expect(picker.people.map((p) => p.name), isNot(contains(s.monaName)));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('give-to')),
          matching: find.text(s.rakeshName),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        app.work.calls.single,
        'reassign post-trays ${DaybookSamples.rakesh}',
      );
    });

    testWidgets('X3: cancel: CANCELLED at once, "Cancelled · Undo", sent '
        'when the bar goes [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: [s.traysForOmar(needsMe: false)],
      );
      await _longPress(tester, 'post-trays');
      await _pick(tester, l10n.daybookCancelItem);
      expect(
        _in('post-trays', find.text(l10n.daybookStampCancelled)),
        findsOneWidget,
      );
      expect(
        _in('post-trays', find.byKey(const Key('slip-cancelled'))),
        findsOneWidget,
      );
      expect(find.text(l10n.daybookCancelled), findsOneWidget);
      expect(app.daybook.calls, isEmpty);
      await tester.pump(_undoGone);
      await tester.pumpAndSettle();
      expect(app.daybook.calls.single, 'cancel post-trays');
    });

    testWidgets('X3: a cancelled item of mine: "Cancelled by you" [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: [s.doorHardware()]);
      expect(
        _in(
          'post-door',
          find.text(
            l10n.daybookCancelledByYou(
              words.clock(DateTime(2026, 10, 15, 12, 5)),
            ),
          ),
        ),
        findsOneWidget,
      );
      await _longPress(tester, 'post-door');
      expect(find.byKey(const Key('slip-menu')), findsNothing);
    });

    testWidgets('Edit: the card at Now with the post; Save sends only what '
        'changed [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: [s.traysForOmar(needsMe: false)],
      );
      await _longPress(tester, 'post-trays');
      await _pick(tester, l10n.daybookEdit);
      final card = tester.widget<BvWritingCard>(find.byType(BvWritingCard));
      expect(card.titleController.text, s.cableTraysTitle);
      // The owner changes with Give to, not Edit: no Assign.
      await tester.tap(find.bySemanticsLabel(l10n.daybookMore));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BvPopoverMenu<Object>>(
              find.byKey(const Key('writing-more-menu')),
            )
            .items
            .map((i) => i.label),
        [l10n.daybookLocation, l10n.daybookDueDateMenu],
      );
      await tester.tap(find.byKey(const Key('writing-menu-away')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('writing-title')), 'Trays');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(app.daybook.calls.single, 'edit post-trays {"title":"Trays"}');
      expect(find.byType(BvWritingCard), findsNothing);
    });

    testWidgets('Edit: the due can be removed: "Edited: due removed" '
        '[$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: [s.traysForOmar(needsMe: false)],
        due: (day: null, at: null),
      );
      await _longPress(tester, 'post-trays');
      await _pick(tester, l10n.daybookEdit);
      await tester.tap(
        find.text(words.dueProperty(DateTime(2026, 10, 18), null)),
      );
      await tester.pumpAndSettle();
      final card = tester.widget<BvWritingCard>(find.byType(BvWritingCard));
      expect(card.properties.map((p) => p.label), [s.omarName]);
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(
        app.daybook.calls.single,
        'edit post-trays {"due":null,"due_at":null}',
      );
    });
  }

  test('a check held for its undo bar is sent on the next open if the app '
      'closed meanwhile (review 44, answer 4)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final work = FakeWorkRepository();
    ProviderContainer open() => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authUserIdProvider.overrideWithValue(
          const AsyncData(DaybookSamples.islam),
        ),
        workRepositoryProvider.overrideWithValue(work),
        daybookRepositoryProvider.overrideWithValue(FakeDaybookRepository()),
      ],
    );
    final first = open();
    await first
        .read(workOutboxProvider.notifier)
        .hold(
          const PendingItem(
            kind: PendingKind.check,
            id: 'post-sleeves',
            spaceId: DaybookSamples.space,
            title: 'Sleeves',
            ownerId: DaybookSamples.omar,
            ownerName: 'Omar Haddad',
          ),
          const Duration(seconds: 5),
        );
    // Closed within the 5 seconds: nothing was sent.
    first.dispose();
    expect(work.calls, isEmpty);
    final kept = jsonDecode(
      prefs.getString('work_outbox:${DaybookSamples.islam}')!,
    );
    expect((kept as List).single['kind'], 'check_item');

    final next = open();
    addTearDown(next.dispose);
    expect(next.read(workOutboxProvider), hasLength(1));
    await next.read(workOutboxProvider.notifier).flushAll();
    expect(work.calls.single, 'check post-sleeves');
    expect(next.read(workOutboxProvider), isEmpty);
  });

  test('undo: a held check never leaves the phone', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final work = FakeWorkRepository();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authUserIdProvider.overrideWithValue(
          const AsyncData(DaybookSamples.islam),
        ),
        workRepositoryProvider.overrideWithValue(work),
        daybookRepositoryProvider.overrideWithValue(FakeDaybookRepository()),
      ],
    );
    addTearDown(c.dispose);
    final outbox = c.read(workOutboxProvider.notifier);
    await outbox.hold(
      const PendingItem(
        kind: PendingKind.check,
        id: 'post-sleeves',
        spaceId: DaybookSamples.space,
        title: 'Sleeves',
        ownerId: DaybookSamples.omar,
        ownerName: 'Omar Haddad',
      ),
      Duration.zero,
    );
    expect(outbox.isHeld(PendingKind.check, 'post-sleeves'), isTrue);
    await outbox.undo(PendingKind.check, 'post-sleeves');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await outbox.flushAll();
    expect(work.calls, isEmpty);
    expect(c.read(workOutboxProvider), isEmpty);
  });
}
