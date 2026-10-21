// Slice 1 part 1d: the work item loop on the daybook, on v13's one card
// per work item (review 53 Part B). Sign as done with the camera (O1–O3),
// check by double-tap with Undo (B3), the menu (B1, X1), send back with a
// reason (B2, S1), an update by swiping (Y1), edit, give to someone else
// and cancel (X1–X3). What happens is a line in the card's history.
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/core/sound/sent_chime.dart';
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
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/daybook_live.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/shared/widgets/bv_chip.dart';
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
  required List<DaybookCard> posts,
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

/// The Sign as done pills (in Arabic the header's "signed as done" has
/// the same words).
Finder _signPills(AppLocalizations l10n) => find.byWidgetPredicate(
  (w) => w is BvSlipPill && w.icon != null && w.label == l10n.daybookSignAsDone,
);

Finder _entry(String id) => find.byKey(Key('daybook-card-$id'));

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
  final photo = _in('post-sleeves', find.byKey(const Key('slip-photo')));
  await tester.ensureVisible(photo);
  await tester.pumpAndSettle();
  // Clear of the stamp in the middle of the photo.
  final at = tester.getTopLeft(photo) + const Offset(20, 20);
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tapAt(at);
  await tester.pumpAndSettle();
}

/// A history line of card [id], as its plain text.
Finder _line(String id, String text) =>
    _in(id, find.text(text, findRichText: true));

/// F6: the proof screen opens with the camera one tap away.
Future<void> _takePhoto(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('proof-take-photo')));
  await tester.pumpAndSettle();
}

/// Send as done, then the undo bar's 5 seconds: only then is it sent (F7).
Future<void> _sendDone(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('proof-send')));
  await tester.pumpAndSettle();
  await tester.pump(_undoGone);
  await tester.pumpAndSettle();
}

/// Taps one of the send-back sheet's new dates (F62).
Future<void> _newDue(WidgetTester tester, String name) async {
  final chip = find.byKey(Key('send-back-due-$name'));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
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
      await _takePhoto(tester);
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
      await _sendDone(tester);
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

    testWidgets('review 47, answer 3: the item name lists your other open '
        'items; picking one proves it instead. Camera only [$lang]', (
      tester,
    ) async {
      final app = await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      await tester.longPress(find.byKey(const Key('post-bar-camera')));
      await tester.pumpAndSettle();
      expect(find.text(s.sleeves), findsOneWidget);
      await tester.tap(find.byKey(const Key('proof-switch-open')));
      await tester.pumpAndSettle();
      final menu = tester.widget<BvPopoverMenu<String>>(
        find.byKey(const Key('proof-switch')),
      );
      // Due soonest first; the one shown is chosen.
      expect(
        [for (final i in menu.items) i.value],
        ['post-sleeves', 'post-trays'],
      );
      expect(menu.selected, 'post-sleeves');
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('proof-switch')),
          matching: find.text(s.cableTraysTitle),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proof-switch')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('proof-item'))).data,
        s.cableTraysTitle,
      );
      await tester.tap(find.byKey(const Key('proof-take-photo')));
      await tester.pumpAndSettle();
      await _sendDone(tester);
      expect(app.work.calls.single, startsWith('done post-trays'));
      // Proof photos come from the camera only (founder, review 47).
      expect(app.cameraAsks, [true]);
    });

    testWidgets('review 47, answer 5: a refused sign-off keeps its photos: '
        '"Couldn\'t send. Tap to fix" on the proof; the tap reopens it; x '
        'asks before deleting [$lang]', (tester) async {
      final work = FakeWorkRepository()
        ..refuse = const SpaceException(
          SpaceFailure.rule,
          'this work item was cancelled',
        );
      final app = await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        work: work,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BvPostBar)),
      );
      await tester.tap(_in('post-sleeves', find.text(l10n.daybookSignAsDone)));
      await tester.pumpAndSettle();
      await _takePhoto(tester);
      await tester.enterText(
        find.byKey(const Key('proof-note')),
        s.sleevesNote,
      );
      await _sendDone(tester);
      expect(work.calls, isEmpty);
      final kept = container.read(workOutboxProvider).single;
      expect(kept.refused, isTrue);
      expect(kept.photos, hasLength(1));
      expect(File(kept.photos.single.local).existsSync(), isTrue);
      expect(find.text(l10n.daybookCouldNotSend), findsOneWidget);
      // Not DONE on the item: the server didn't take it.
      expect(
        _in('post-sleeves', find.text(l10n.daybookStampDone)),
        findsNothing,
      );

      // Tap to fix: the proof again, with the note.
      await tester.tap(find.text(l10n.daybookCouldNotSend));
      await tester.pumpAndSettle();
      expect(find.byType(ProofCamera), findsOneWidget);
      expect(find.text(s.sleevesNote), findsOneWidget);
      // x asks; Keep keeps it on the phone.
      await tester.tap(find.byKey(const Key('proof-close')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookDiscardProofTitle), findsOneWidget);
      await tester.tap(find.text(l10n.daybookDiscardProofKeep));
      await tester.pumpAndSettle();
      expect(find.byType(ProofCamera), findsNothing);
      expect(container.read(workOutboxProvider), hasLength(1));

      // Fixed: sent for the other item, with the same photo.
      work.refuse = null;
      await tester.tap(find.text(l10n.daybookCouldNotSend));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proof-switch-open')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('proof-switch')),
          matching: find.text(s.cableTraysTitle),
        ),
      );
      await tester.pumpAndSettle();
      await _sendDone(tester);
      expect(work.calls.single, 'done post-trays ${s.sleevesNote} 1');
      expect(container.read(workOutboxProvider), isEmpty);
      expect(app.work.uploads.last, contains('/post-trays/'));
    });

    testWidgets('review 47, answer 5: x on a refused proof, then Delete: '
        'the photos go [$lang]', (tester) async {
      final work = FakeWorkRepository()
        ..refuse = const SpaceException(SpaceFailure.notAllowed);
      await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        work: work,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BvPostBar)),
      );
      await tester.tap(_in('post-sleeves', find.text(l10n.daybookSignAsDone)));
      await tester.pumpAndSettle();
      await _takePhoto(tester);
      await _sendDone(tester);
      final photo = container.read(workOutboxProvider).single.photos.single;
      await tester.tap(find.text(l10n.daybookCouldNotSend));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proof-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.daybookDiscardProofDelete));
      await tester.pumpAndSettle();
      expect(container.read(workOutboxProvider), isEmpty);
      expect(find.text(l10n.daybookCouldNotSend), findsNothing);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(File(photo.local).existsSync(), isFalse);
    });

    testWidgets('review 47, answer 5: a refused check says why in plain '
        'words, then the page reads again [$lang]', (tester) async {
      final work = FakeWorkRepository()
        ..refuse = const SpaceException(
          SpaceFailure.rule,
          'only a done item can be checked',
        );
      final daybook = FakeDaybookRepository();
      await _open(tester, lang, posts: s.d1(), work: work, daybook: daybook);
      // Meanwhile the author cancelled it.
      daybook.posts[DaybookSamples.space] = [
        for (final c in s.d1())
          c.id == 'post-sleeves'
              ? c.copyWith(post: c.post.shownAs(cancelled: true))
              : c,
      ];
      await _doubleTapProof(tester);
      await tester.pump(_undoGone);
      await tester.pumpAndSettle();
      expect(
        find.text(
          l10n.daybookRefusedBecause(
            l10n.daybookCouldNotCheck,
            l10n.daybookWhyCancelled,
          ),
        ),
        findsOneWidget,
      );
      expect(work.calls, isEmpty);
    });

    testWidgets('review 47, answer 5: a refused send-back says why [$lang]', (
      tester,
    ) async {
      final work = FakeWorkRepository()
        ..refuse = const SpaceException(SpaceFailure.notAllowed);
      await _open(tester, lang, posts: s.d1(), work: work);
      await _longPress(tester, 'post-sleeves');
      await _pick(tester, l10n.daybookSendBack);
      await tester.tap(find.text(l10n.daybookReasonNotFinished));
      await tester.pumpAndSettle();
      await _newDue(tester, 'tomorrow');
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('send-back-card')),
          matching: find.text(l10n.daybookSendBack),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          l10n.daybookRefusedBecause(
            l10n.daybookCouldNotSendBack,
            l10n.daybookWhyNotAllowed,
          ),
        ),
        findsOneWidget,
      );
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
      await _takePhoto(tester);
      await _sendDone(tester);
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

    testWidgets('O3: the owner\'s signed card: DONE on the photo, nothing '
        'left for the owner to do [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [
          s.sleevesCard(
            me: DaybookSamples.omar,
            upTo: DaybookSamples.sleevesFirstDoneAt,
          ),
        ],
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      expect(
        _in('post-sleeves', find.text(l10n.daybookStampDone)),
        findsOneWidget,
      );
      expect(find.byType(BvPaperClip), findsNothing);
      expect(find.text(l10n.daybookDoubleTapToCheck), findsNothing);
      expect(_signPills(l10n), findsNothing);
      expect(
        _in(
          'post-sleeves',
          find.textContaining(l10n.daybookLineYouSigned, findRichText: true),
        ),
        findsOneWidget,
      );
    });

    testWidgets('S1: sent back: SENT BACK on the photo, the send-back a line '
        'with its reason, the clip and the only Sign as done on the one '
        'card [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [
          s.sleevesCard(
            me: DaybookSamples.omar,
            upTo: DaybookSamples.sleevesSentBackAt,
          ),
        ],
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      expect(
        _in('post-sleeves', find.text(l10n.daybookStampSentBack)),
        findsOneWidget,
      );
      expect(
        _line(
          'post-sleeves',
          '${l10n.daybookHistoryLead(l10n.daybookLineSentBack(s.islamName))} '
              '${words.reason(SendBackReason.photoMissing)}',
        ),
        findsOneWidget,
      );
      expect(find.byType(BvSlip), findsOneWidget);
      expect(_in('post-sleeves', find.byType(BvPaperClip)), findsOneWidget);
      expect(_signPills(l10n), findsOneWidget);
    });

    testWidgets('S1: Sign as done after a send-back proves the item; signed '
        'again, the clip and the pill go [$lang]', (tester) async {
      final work = FakeWorkRepository();
      final daybook = FakeDaybookRepository();
      await _open(
        tester,
        lang,
        posts: [
          s.sleevesCard(
            me: DaybookSamples.omar,
            upTo: DaybookSamples.sleevesSentBackAt,
          ),
        ],
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        work: work,
        daybook: daybook,
      );
      await tester.tap(_in('post-sleeves', _signPills(l10n)));
      await tester.pumpAndSettle();
      expect(find.byType(ProofCamera), findsOneWidget);
      await _takePhoto(tester);
      // The server after the second sign-off: Done, for Islam to check.
      daybook.posts[DaybookSamples.space] = [
        s.sleevesCard(me: DaybookSamples.omar),
      ];
      await _sendDone(tester);
      expect(work.calls, contains(startsWith('done post-sleeves')));
      expect(_in('post-sleeves', find.byType(BvPaperClip)), findsNothing);
      expect(_signPills(l10n), findsNothing);
    });

    testWidgets('a never-signed item keeps Sign as done on its own slip '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [s.o1().first],
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      final id = s.o1().first.id;
      expect(_in(id, _signPills(l10n)), findsOneWidget);
    });

    // Part D of review 51: signing without a photo (F6), no accidental
    // done (F7) and the sound (F5).

    testWidgets('F6: Sign as done opens the proof with the camera one tap '
        'away and "Without a photo"; without one the note is needed, and '
        'the proof shows it with no photo [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      await tester.tap(_in('post-sleeves', find.text(l10n.daybookSignAsDone)));
      await tester.pumpAndSettle();
      expect(find.byType(ProofCamera), findsOneWidget);
      // Nothing asked of the camera yet, and nothing to send.
      expect(app.cameraAsks, isEmpty);
      expect(find.byKey(const Key('proof-take-photo')), findsOneWidget);
      expect(find.text(l10n.daybookCamera), findsOneWidget);
      expect(find.byKey(const Key('proof-send')), findsNothing);
      await tester.tap(find.text(l10n.daybookWithoutPhoto));
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookWhatWasDone), findsOneWidget);
      // No note yet: Send as done does nothing.
      await tester.tap(find.byKey(const Key('proof-send')));
      await tester.pumpAndSettle();
      expect(find.byType(ProofCamera), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('proof-note')),
        s.sleevesNote,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('proof-send')));
      await tester.pumpAndSettle();
      expect(find.byType(ProofCamera), findsNothing);
      // The proof on the card: the note and DONE, no photo, no frame.
      const proof = 'post-sleeves';
      expect(_entry(proof), findsOneWidget);
      expect(_in(proof, find.text(s.sleevesNote)), findsOneWidget);
      expect(_in(proof, find.text(l10n.daybookStampDone)), findsOneWidget);
      expect(_in(proof, find.byType(BvSlipPhoto)), findsNothing);
      await tester.pump(_undoGone);
      await tester.pumpAndSettle();
      expect(app.work.calls.single, 'done post-sleeves ${s.sleevesNote} 0');
      expect(app.work.uploads, isEmpty);
      expect(app.cameraAsks, isEmpty);
    });

    testWidgets('F6: a proof with no photo shows the note and DONE with no '
        'empty frame; the checker can send it back with "Photo missing" '
        '[$lang]', (tester) async {
      final work = FakeWorkRepository();
      await _open(
        tester,
        lang,
        posts: [s.sleevesCard(photos: const [])],
        work: work,
      );
      const proof = 'post-sleeves';
      expect(_in(proof, find.text(s.sleevesNote)), findsOneWidget);
      expect(_in(proof, find.text(l10n.daybookStampDone)), findsOneWidget);
      expect(_in(proof, find.byType(BvSlipPhoto)), findsNothing);
      expect(_in(proof, find.byType(BvPaperClip)), findsOneWidget);
      await _longPress(tester, proof);
      await _pick(tester, l10n.daybookSendBack);
      await tester.tap(find.text(l10n.daybookReasonPhotoMissing));
      await tester.pumpAndSettle();
      await _newDue(tester, 'none');
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('send-back-card')),
          matching: find.text(l10n.daybookSendBack),
        ),
      );
      await tester.pumpAndSettle();
      expect(work.calls.single, 'back post-sleeves photo_missing  due none');
    });

    testWidgets('F7: a tap on Sign as done never signs; Send as done shows '
        '"Signed as done · Undo", and sign_done goes only when it closes, '
        'with the sound (F5) [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BvPostBar)),
      );
      await tester.tap(_in('post-sleeves', find.text(l10n.daybookSignAsDone)));
      await tester.pumpAndSettle();
      expect(container.read(workOutboxProvider), isEmpty);
      await _takePhoto(tester);
      expect(container.read(workOutboxProvider), isEmpty);
      await tester.tap(find.byKey(const Key('proof-send')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookSignedUndo), findsOneWidget);
      expect(find.byKey(const Key('undo-bar-action')), findsOneWidget);
      // Held on the phone: DONE on the item, not "Waiting to send".
      expect(
        container.read(workOutboxProvider).single.kind,
        PendingKind.signOff,
      );
      expect(
        _in('post-sleeves', find.text(l10n.daybookStampDone)),
        findsOneWidget,
      );
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      expect(app.work.calls, isEmpty);
      expect(app.work.uploads, isEmpty);
      expect(app.chimes, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(app.work.calls.single, 'done post-sleeves  1');
      expect(app.chimes, ['haptic', 'sound']);
    });

    testWidgets('F7: Undo: nothing reaches the server, and the proof opens '
        'again with its photo and note [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BvPostBar)),
      );
      await tester.tap(_in('post-sleeves', find.text(l10n.daybookSignAsDone)));
      await tester.pumpAndSettle();
      await _takePhoto(tester);
      await tester.enterText(
        find.byKey(const Key('proof-note')),
        s.sleevesNote,
      );
      await tester.tap(find.byKey(const Key('proof-send')));
      await tester.pumpAndSettle();
      final photo = container.read(workOutboxProvider).single.photos.single;
      await tester.tap(find.byKey(const Key('undo-bar-action')));
      await tester.pumpAndSettle();
      expect(container.read(workOutboxProvider), isEmpty);
      expect(find.byType(ProofCamera), findsOneWidget);
      expect(find.text(s.sleevesNote), findsOneWidget);
      expect(find.byKey(const Key('proof-label')), findsOneWidget);
      expect(File(photo.local).existsSync(), isTrue);
      await tester.pump(_undoGone);
      await tester.pumpAndSettle();
      expect(app.work.calls, isEmpty);
      expect(app.chimes, isEmpty);
      // Sent again from here, it goes with the same photo.
      await _sendDone(tester);
      expect(app.work.calls.single, 'done post-sleeves ${s.sleevesNote} 1');
    });

    testWidgets('F7: a scroll that starts on Sign as done or on the post '
        'bar camera opens nothing [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      final pill = _in(
        'post-sleeves',
        find.byKey(const Key('slip-pill-action')),
      );
      for (final dy in [200.0, -200.0]) {
        await tester.ensureVisible(pill);
        await tester.pumpAndSettle();
        await tester.drag(pill, Offset(0, dy));
        await tester.pumpAndSettle();
        expect(find.byType(ProofCamera), findsNothing);
      }
      // Pressed and moved for a second: neither a tap nor a hold.
      await tester.timedDrag(
        find.byKey(const Key('post-bar-camera')),
        const Offset(0, -150),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProofCamera), findsNothing);
      expect(find.byType(BvWritingCard), findsNothing);
      expect(app.cameraAsks, isEmpty);
      expect(app.work.calls, isEmpty);
    });

    testWidgets('F5: no sound while a proof only waits for a signal; the '
        'sound when it is sent; none for a check [$lang]', (tester) async {
      final work = FakeWorkRepository()..failSendNext = 3;
      final app = await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        work: work,
      );
      await tester.tap(_in('post-sleeves', find.text(l10n.daybookSignAsDone)));
      await tester.pumpAndSettle();
      await _takePhoto(tester);
      await _sendDone(tester);
      expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);
      expect(app.chimes, isEmpty);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(work.calls.single, startsWith('done post-sleeves'));
      expect(app.chimes, ['haptic', 'sound']);
    });

    testWidgets('F5: a check is not a post: no sound [$lang]', (tester) async {
      final app = await _open(tester, lang, posts: s.d1());
      await _doubleTapProof(tester);
      await tester.pump(_undoGone);
      await tester.pumpAndSettle();
      expect(app.work.calls.single, 'check post-sleeves');
      expect(app.chimes, isEmpty);
    });

    testWidgets('Y1: swipe a card to the end side, write an update; an '
        'update is a line in the card\'s history [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      expect(
        _in(
          'post-sleeves',
          find.textContaining(s.sleevesUpdate, findRichText: true),
        ),
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
        find.byKey(const Key('bv-send-field')),
        'Half done',
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(app.work.calls.single, 'comment post-sleeves Half done');
    });

    // Your side.

    testWidgets('B3: double-tap the proof: CHECKED lands, "Checked · Undo", '
        'and check_item goes only after the 5 seconds [$lang]', (tester) async {
      final app = await _open(tester, lang, posts: s.d1());
      await _doubleTapProof(tester);
      expect(
        _in('post-sleeves', find.text(l10n.daybookStampChecked)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<BvInkStamp>(_in('post-sleeves', find.byType(BvInkStamp)))
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
      // At once, a line in the history, and nothing to do any more.
      expect(_line('post-sleeves', l10n.daybookLineYouChecked), findsOneWidget);
      expect(find.text(l10n.daybookDoubleTapToCheck), findsNothing);
      expect(_in('post-sleeves', find.byType(BvPaperClip)), findsNothing);
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
        _in('post-sleeves', find.text(l10n.daybookStampDone)),
        findsOneWidget,
      );
      expect(
        _in('post-sleeves', find.text(l10n.daybookStampChecked)),
        findsNothing,
      );
      expect(_line('post-sleeves', l10n.daybookLineYouChecked), findsNothing);
    });

    testWidgets('B1: long-press the card to check: the lifted card and '
        'Check, Send back, Add update, Cancel; Check checks [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang, posts: s.d1());
      await _longPress(tester, 'post-sleeves');
      expect(find.byType(BvDim), findsOneWidget);
      // "Discuss in chat" can't quote the item in the chat yet: hidden.
      expect(_menu(tester), [
        l10n.daybookCheck,
        l10n.daybookSendBack,
        l10n.daybookAddUpdate,
        l10n.daybookCancelItem,
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
      await _longPress(tester, 'post-sleeves');
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
      // F62: a new date is chosen too, nothing chosen first.
      await tester.tap(send());
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      await _newDue(tester, 'today');
      await tester.tap(send());
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      final today = dayOf(DaybookSamples.thursday);
      expect(
        app.work.calls.single,
        'back post-sleeves not_as_asked ${s.sentBackNote} due '
        '${today.year}-${today.month}-${today.day}',
      );
    });

    testWidgets('F62: the new date is one choice, nothing chosen first: '
        'Tomorrow, a picked day, or none [$lang]', (tester) async {
      final app = await _open(tester, lang, posts: s.d1());
      await _longPress(tester, 'post-sleeves');
      await _pick(tester, l10n.daybookSendBack);
      final card = find.byType(BvSendBackCard<SendBackReason>);
      for (final word in [
        l10n.daybookSendBackNewDate,
        l10n.daybookSendBackToday,
        l10n.daybookSendBackTomorrow,
        l10n.daybookSendBackPickDate,
        l10n.daybookSendBackNoNewDate,
      ]) {
        expect(find.descendant(of: card, matching: find.text(word)), findsOne);
      }
      final chips = tester.widgetList<BvChip>(
        find.descendant(of: card, matching: find.byType(BvChip)),
      );
      expect(chips.where((c) => c.selected), isEmpty);
      await tester.tap(find.text(l10n.daybookReasonNotFinished));
      await tester.pumpAndSettle();
      await _newDue(tester, 'tomorrow');
      await _newDue(tester, 'none');
      // One choice: the last one tapped.
      expect(
        tester
            .widgetList<BvChip>(
              find.descendant(of: card, matching: find.byType(BvChip)),
            )
            .where((c) => c.selected)
            .map((c) => c.label),
        [l10n.daybookSendBackNoNewDate],
      );
      await _newDue(tester, 'tomorrow');
      await tester.tap(
        find.descendant(of: card, matching: find.text(l10n.daybookSendBack)),
      );
      await tester.pumpAndSettle();
      final tomorrow = dayOf(
        DaybookSamples.thursday,
      ).add(const Duration(days: 1));
      expect(
        app.work.calls.single,
        'back post-sleeves not_finished  due '
        '${tomorrow.year}-${tomorrow.month}-${tomorrow.day}',
      );
    });

    testWidgets('X1: long-press your own open item: Add update, Edit, Give '
        'to someone else, Cancel work item; someone else\'s: Add update '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [...s.d1(), s.traysForOmar(needsMe: false)],
      );
      await _longPress(tester, 'post-trays');
      expect(_menu(tester), [
        l10n.daybookAddUpdate,
        l10n.daybookEdit,
        l10n.daybookGiveTo,
        l10n.daybookCancelItem,
      ]);
      // A tap on the dim, clear of the menu, closes it.
      await tester.tapAt(
        tester.getTopLeft(find.byType(BvDim)) + const Offset(8, 8),
      );
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
      await _longPress(tester, 'post-sleeves');
      expect(find.byKey(const Key('slip-menu')), findsNothing);
      expect(find.byKey(const Key('swipe-reveal')), findsNothing);
    });

    testWidgets("F16: Crew on someone else's card: long-press, or a short "
        'press, shows Add update [$lang]', (tester) async {
      // Rakesh (Crew) neither wrote nor owns the sleeves item.
      final app = await _open(
        tester,
        lang,
        posts: [
          s.sleevesCard(
            me: DaybookSamples.rakesh,
            upTo: DaybookSamples.sleevesSentBackAt,
          ),
        ],
        me: DaybookSamples.rakesh,
        pass: SpacePass.crew,
      );
      await _longPress(tester, 'post-sleeves');
      expect(_menu(tester), [l10n.daybookAddUpdate]);
      // Off the menu and the lifted card: the dim's corner.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      // A short press: the same menu (until the card's page, slice 5).
      await tester.ensureVisible(_in('post-sleeves', find.text(s.sleeves)));
      await tester.pumpAndSettle();
      await tester.tap(_in('post-sleeves', find.text(s.sleeves)));
      await tester.pumpAndSettle();
      expect(_menu(tester), [l10n.daybookAddUpdate]);
      await _pick(tester, l10n.daybookAddUpdate);
      await tester.enterText(find.byKey(const Key('bv-send-field')), 'Seen');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(app.work.calls.single, 'comment post-sleeves Seen');
    });

    testWidgets("F16: a Viewer's short press does nothing either [$lang]", (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        posts: s.d1(viewer: true),
        me: DaybookSamples.mona,
        pass: SpacePass.viewer,
      );
      await tester.ensureVisible(_entry('post-rebar'));
      await tester.pumpAndSettle();
      await tester.tap(_in('post-rebar', find.byType(BvSlip)).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('slip-menu')), findsNothing);
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
      expect(_line('post-trays', l10n.daybookLineYouCancelled), findsOneWidget);
      expect(app.daybook.calls, isEmpty);
      await tester.pump(_undoGone);
      await tester.pumpAndSettle();
      expect(app.daybook.calls.single, 'cancel post-trays');
    });

    testWidgets('X3: a cancelled item of mine: "You cancelled it" [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: [s.doorHardware()]);
      expect(_line('post-door', l10n.daybookLineYouCancelled), findsOneWidget);
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
      expect(card.titleController!.text, s.cableTraysTitle);
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

    testWidgets('Edit: the due can be removed [$lang]', (tester) async {
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
        daybookLiveProvider.overrideWithValue(FakeDaybookLive()),
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

  test('a sign-off held for its undo bar is sent on the next open if the '
      'app closed meanwhile (F7)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final work = FakeWorkRepository();
    final heard = <String>[];
    ProviderContainer open() => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authUserIdProvider.overrideWithValue(
          const AsyncData(DaybookSamples.omar),
        ),
        workRepositoryProvider.overrideWithValue(work),
        daybookRepositoryProvider.overrideWithValue(FakeDaybookRepository()),
        daybookLiveProvider.overrideWithValue(FakeDaybookLive()),
        sentChimeProvider.overrideWithValue(
          SentChime(
            soundOn: () async => true,
            playSound: () async => heard.add('sound'),
            haptic: () async => heard.add('haptic'),
          ),
        ),
      ],
    );
    final first = open();
    await first
        .read(workOutboxProvider.notifier)
        .hold(
          const PendingItem(
            id: 'post-sleeves',
            spaceId: DaybookSamples.space,
            title: 'Sleeves',
            ownerId: DaybookSamples.omar,
            ownerName: 'Omar Haddad',
            note: 'Sleeves fixed',
          ),
          const Duration(seconds: 5),
        );
    first.dispose();
    expect(work.calls, isEmpty);

    final next = open();
    addTearDown(next.dispose);
    await next.read(workOutboxProvider.notifier).flushAll();
    expect(work.calls.single, 'done post-sleeves Sleeves fixed 0');
    expect(next.read(workOutboxProvider), isEmpty);
    expect(heard, ['haptic', 'sound']);
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
        daybookLiveProvider.overrideWithValue(FakeDaybookLive()),
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
