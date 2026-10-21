import 'dart:convert';

import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_masthead.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:buildvibes/shared/widgets/bv_post_bar.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _draftKey =
    'daybook_draft:${DaybookSamples.islam}:${DaybookSamples.space}';

/// Sunday 18 October at 14:00, the prototype's due (E3).
final _sunday = DateTime(2026, 10, 18);
final _twoPm = DateTime(2026, 10, 18, 14);

/// The Space's daybook as Islam (Lead), with the prototype's people.
Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<DaybookCard>? posts,
  SpacePass pass = SpacePass.lead,
  FakeDaybookRepository? daybook,
  String? draft,
  PickedDue? due,
}) async {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(pass: pass)
    ..spacePeople[DaybookSamples.space] = s.people();
  final fake = daybook ?? FakeDaybookRepository();
  fake.posts[DaybookSamples.space] = posts ?? s.d1();
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: spaces,
    daybook: fake,
    now: DaybookSamples.thursday,
    overrides: [
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async => due,
      ),
    ],
  );
  // A draft left on the phone before the app was closed.
  if (draft != null) await app.prefs.setString(_draftKey, draft);
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _write(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('post-bar-notepad')));
  await tester.pumpAndSettle();
}

Future<void> _title(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('writing-title')), text);
  await tester.pumpAndSettle();
}

/// Assign through More (picking from Post would post at once).
Future<void> _assign(WidgetTester tester, String name) async {
  final l10n = AppLocalizations.of(tester.element(find.byType(BvWritingCard)));
  await tester.tap(find.bySemanticsLabel(l10n.daybookMore));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.daybookAssign));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(BvGiveToPicker), matching: find.text(name)),
  );
  await tester.pumpAndSettle();
}

T _read<T>(WidgetTester tester, ProviderListenable<T> provider) =>
    ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    ).read(provider);

BvWritingToolbar _toolbar(WidgetTester tester) =>
    tester.widget<BvWritingToolbar>(find.byType(BvWritingToolbar));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);
    final words = DaybookWords(l10n, lang, use24: false);

    testWidgets('E1: the notepad opens a card at Now; the toolbar takes the '
        'post bar\'s place [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester);
      expect(find.byKey(const Key('daybook-now')), findsOneWidget);
      expect(find.byType(BvWritingCard), findsOneWidget);
      expect(find.byType(BvWritingToolbar), findsOneWidget);
      expect(find.byType(BvPostBar), findsNothing);
      // At Now: under the newest card.
      expect(
        tester.getTopLeft(find.byKey(const Key('daybook-now'))).dy,
        greaterThan(
          tester
              .getTopLeft(find.byKey(const Key('daybook-card-post-sleeves')))
              .dy,
        ),
      );
      // The masthead stays on today.
      final masthead = tester.widget<BvDaybookMasthead>(
        find.byType(BvDaybookMasthead),
      );
      expect(masthead.weekday, l10n.daybookTodayDivider);
      expect(masthead.onTap, isNull);
      // A work item first; the chip opens the kind menu (E6, slice 2).
      expect(find.byKey(const Key('writing-kind-chip')), findsOneWidget);
      final card = tester.widget<BvWritingCard>(find.byType(BvWritingCard));
      expect(card.kindLabel, l10n.daybookWorkItem);
      expect(card.onKindTap, isNotNull);
      // Post is off with no title.
      expect(_toolbar(tester).onPost, isNull);
    });

    testWidgets('F56: Post turns on with a title of 2 or more but stays grey '
        'with nobody to do it; a tap asks on the who row, the picker only '
        'fills it, and only Post posts [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _write(tester);
      // The who row is there from the start.
      expect(
        find.descendant(
          of: find.byKey(const Key('writing-who')),
          matching: find.text(l10n.daybookForChoose),
        ),
        findsOneWidget,
      );
      await _title(tester, 'A');
      expect(_toolbar(tester).onPost, isNull);
      await _title(tester, s.cableTraysTitle);
      expect(_toolbar(tester).onPost, isNotNull);
      expect(_toolbar(tester).postReady, isFalse);
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(app.daybook.created, isEmpty);
      expect(find.byType(BvGiveToPicker), findsNothing);
      expect(find.text(l10n.daybookChooseWho), findsOneWidget);
      // The row opens the picker: Lead and Crew only, never the Viewer; me
      // last. It says "Assign to…" (review 46), with the way out to a Note.
      await tester.tap(find.byKey(const Key('writing-who')));
      await tester.pumpAndSettle();
      final picker = tester.widget<BvGiveToPicker>(find.byType(BvGiveToPicker));
      expect(picker.searchPlaceholder, l10n.daybookAssignSearch);
      expect(picker.people.map((p) => p.name), [
        s.omarName,
        s.rakeshName,
        s.saraName,
        s.linaName,
        s.islamName,
      ]);
      expect(picker.people.first.team, isNotNull);
      expect(find.text(l10n.daybookPostAsNote), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(BvGiveToPicker),
          matching: find.text(s.omarName),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BvGiveToPicker), findsNothing);
      expect(app.daybook.created, isEmpty);
      expect(find.byType(BvWritingCard), findsOneWidget);
      expect(_toolbar(tester).postReady, isTrue);
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(app.daybook.created.single.ownerId, DaybookSamples.omar);
      expect(find.byType(BvWritingCard), findsNothing);
    });

    testWidgets('F56: "Post as a Note" turns a work item with nobody to do it '
        'into a note [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester);
      await _title(tester, s.cableTraysTitle);
      await tester.tap(find.byKey(const Key('writing-who')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.daybookPostAsNote));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BvWritingCard>(find.byType(BvWritingCard)).kindLabel,
        l10n.daybookKindNote,
      );
      expect(find.byKey(const Key('writing-who')), findsNothing);
      expect(_toolbar(tester).postReady, isTrue);
    });

    testWidgets('Assign from More only sets the owner [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _write(tester);
      await _title(tester, s.cableTraysTitle);
      await _assign(tester, s.omarName);
      expect(app.daybook.created, isEmpty);
      final card = tester.widget<BvWritingCard>(find.byType(BvWritingCard));
      expect(
        card.properties.single.label,
        l10n.daybookForPersonChoose(s.omarName),
      );
    });

    testWidgets('F66: once chosen, the who row reads "For Omar Haddad ›" as '
        "the card's facts line, the name standing out; a tap opens the "
        'picker again [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester);
      await _title(tester, s.cableTraysTitle);
      await _assign(tester, s.omarName);
      final who = tester
          .widget<BvWritingCard>(find.byType(BvWritingCard))
          .properties
          .single;
      expect(who.label, l10n.daybookForPersonChoose(s.omarName));
      expect(who.name, s.omarName);
      final context = tester.element(find.byType(BvWritingCard));
      expect(who.marks, [
        (
          part: s.omarName,
          style: BvType.of(
            context,
          ).emphasisSm.copyWith(color: BvColors.textPrimary),
        ),
      ]);
      // Drawn as one line: the words grey, the name standing out.
      final line = tester.widget<RichText>(
        find
            .descendant(
              of: find.byKey(const Key('writing-who')),
              matching: find.byType(RichText),
            )
            .last,
      );
      expect(line.text.toPlainText(), l10n.daybookForPersonChoose(s.omarName));
      // On the face: the title's cursor handle can sit over the row's
      // middle.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('writing-who')),
          matching: find.byType(BvAvatar),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BvGiveToPicker), findsOneWidget);
    });

    testWidgets('E2: More has only what slice 1 does: Assign, Location, Due '
        'date [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester);
      await tester.tap(find.bySemanticsLabel(l10n.daybookMore));
      await tester.pumpAndSettle();
      final menu = tester.widget<BvPopoverMenu<Object>>(
        find.byKey(const Key('writing-more-menu')),
      );
      expect(menu.items.map((i) => i.label), [
        l10n.daybookAssign,
        l10n.daybookLocation,
        l10n.daybookDueDateMenu,
      ]);
      expect(_toolbar(tester).moreActive, isTrue);
      // A tap anywhere else closes it.
      await tester.tap(find.byKey(const Key('writing-menu-away')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('writing-more-menu')), findsNothing);
    });

    testWidgets('E3: owner, due date with a time, place and the cover; Post '
        'sends create_work_item with the card\'s id [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        due: (day: _sunday, at: _twoPm),
        daybook: FakeDaybookRepository()
          ..asPosted = (i) => s.posted(i, DateTime(2026, 10, 15, 10, 30)),
      );
      await _write(tester);
      final id = _read(tester, daybookDraftProvider(DaybookSamples.space))!.id;
      await _title(tester, s.cableTraysTitle);
      await tester.enterText(
        find.byKey(const Key('writing-body')),
        s.traysBody,
      );
      await _assign(tester, s.omarName);
      // Due date, through More.
      await tester.tap(find.bySemanticsLabel(l10n.daybookMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.daybookDueDateMenu));
      await tester.pumpAndSettle();
      // Location, through More.
      await tester.tap(find.bySemanticsLabel(l10n.daybookMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.daybookLocation));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('popover-field')),
        s.traysPlace,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // The cover, from the camera.
      await tester.tap(find.bySemanticsLabel(l10n.daybookCamera));
      await tester.pumpAndSettle();
      final card = tester.widget<BvWritingCard>(find.byType(BvWritingCard));
      expect(card.properties.map((p) => p.label), [
        l10n.daybookForPersonChoose(s.omarName),
        words.dueProperty(_sunday, _twoPm),
        s.traysPlace,
      ]);
      expect(card.photos, hasLength(1));

      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      final sent = app.daybook.created.single;
      expect(sent.id, id);
      expect(sent.spaceId, DaybookSamples.space);
      expect(sent.title, s.cableTraysTitle);
      expect(sent.body, s.traysBody);
      expect(sent.ownerId, DaybookSamples.omar);
      expect(sent.place, s.traysPlace);
      expect(sent.dueDate, _sunday);
      expect(sent.dueAt, _twoPm);
      // The photo went first, into the post's own folder.
      expect(
        app.daybook.uploads.single,
        startsWith('${DaybookSamples.space}/posts/$id/'),
      );
      expect(sent.photoPaths, app.daybook.uploads);
      // The card is gone, and no draft is left.
      expect(find.byType(BvWritingCard), findsNothing);
      expect(find.byType(BvPostBar), findsOneWidget);
      expect(app.prefs.getString(_draftKey), isNull);
      // The card became a normal slip at the posting time, sent.
      expect(find.byKey(Key('daybook-card-$id')), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(_read(tester, workOutboxProvider), isEmpty);
    });

    testWidgets('E4: a draft survives the app being closed and reopens in '
        'writing mode; only its author sees it [$lang]', (tester) async {
      final draft = jsonEncode(
        DaybookPostDraft(
          id: 'draft-1',
          title: s.cableTraysTitle,
          body: s.traysBody,
        ).toJson(),
      );
      await _open(tester, lang, draft: draft);
      expect(find.byType(BvWritingCard), findsOneWidget);
      expect(find.text(l10n.daybookDraft), findsOneWidget);
      expect(find.text(s.cableTraysTitle), findsOneWidget);
      // The Draft takes the post bar's place; it isn't being written yet.
      expect(find.byType(BvPostBar), findsNothing);
      expect(find.byType(BvWritingToolbar), findsNothing);
      expect(find.byType(BvDaybookMasthead), findsOneWidget);
      await tester.tap(find.byKey(const Key('daybook-draft')));
      await tester.pumpAndSettle();
      expect(find.byType(BvWritingToolbar), findsOneWidget);
      expect(find.text(l10n.daybookDraft), findsOneWidget);
      await _title(tester, '${s.cableTraysTitle}!');
      expect(
        _read(tester, daybookDraftProvider(DaybookSamples.space))!.id,
        'draft-1',
      );
    });

    testWidgets('another account on the phone never sees the draft [$lang]', (
      tester,
    ) async {
      final s2 = DaybookSamples(lang);
      final spaces = FakeSpaceRepository()
        ..details[DaybookSamples.space] = s2.detail()
        ..spacePeople[DaybookSamples.space] = s2.people();
      final app = await pumpApp(
        tester,
        language: lang,
        spaces: spaces,
        daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = s2.d1(),
        now: DaybookSamples.thursday,
      );
      await app.prefs.setString(
        'daybook_draft:someone-else:${DaybookSamples.space}',
        jsonEncode(
          const DaybookPostDraft(id: 'x', title: 'Not yours').toJson(),
        ),
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      expect(find.text('Not yours'), findsNothing);
      expect(find.byType(BvPostBar), findsOneWidget);
    });

    testWidgets('a card with text, put down, stays as the Draft; an empty one '
        'is gone [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _write(tester);
      // Empty: tapping off the card closes it.
      await tester.tapAt(const Offset(200, 260));
      await tester.pumpAndSettle();
      expect(find.byType(BvWritingCard), findsNothing);
      expect(find.byType(BvPostBar), findsOneWidget);
      // With a title: it stays, saved on the phone.
      await _write(tester);
      await _title(tester, s.cableTraysTitle);
      expect(
        jsonDecode(app.prefs.getString(_draftKey)!)['title'],
        s.cableTraysTitle,
      );
      await tester.tapAt(const Offset(200, 260));
      await tester.pumpAndSettle();
      expect(find.byType(BvWritingCard), findsOneWidget);
      expect(find.text(l10n.daybookDraft), findsOneWidget);
      expect(find.byType(BvWritingToolbar), findsNothing);
      // Emptied: no draft.
      await tester.tap(find.byKey(const Key('daybook-draft')));
      await tester.pumpAndSettle();
      await _title(tester, '');
      expect(app.prefs.getString(_draftKey), isNull);
    });

    testWidgets('no signal: the slip waits, then sends with the same id when '
        'the signal is back; a place set through ⋯ → Location goes with it '
        '(F29) [$lang]', (tester) async {
      final daybook = FakeDaybookRepository()..offline = true;
      final app = await _open(tester, lang, daybook: daybook);
      await _write(tester);
      await _title(tester, s.cableTraysTitle);
      await _assign(tester, s.omarName);
      // F29: the place, through More → Location.
      await tester.tap(find.bySemanticsLabel(l10n.daybookMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.daybookLocation));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('popover-field')),
        s.traysPlace,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      // On the page at the time Post was tapped, waiting.
      expect(find.text(s.cableTraysTitle), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);
      expect(daybook.created, isEmpty);
      // F5: no sound while it only waits.
      expect(app.chimes, isEmpty);
      // Kept on the phone: it outlives the app being closed.
      final kept = app.prefs.getString('work_outbox:${DaybookSamples.islam}')!;
      expect(jsonDecode(kept), hasLength(1));
      final waitingId = (jsonDecode(kept) as List).single['id'];
      // The place waits on the phone with it.
      expect((jsonDecode(kept) as List).single['place'], s.traysPlace);

      // The signal is back: the next try sends it.
      daybook.offline = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(daybook.created.single.id, waitingId);
      expect(daybook.created.single.place, s.traysPlace);
      expect(app.chimes, ['haptic', 'sound']);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(app.prefs.getString('work_outbox:${DaybookSamples.islam}'), '[]');
    });

    testWidgets('review 46: a photo alone keeps the Draft [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _write(tester);
      await tester.tap(find.bySemanticsLabel(l10n.daybookCamera));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 260));
      await tester.pumpAndSettle();
      expect(find.byType(BvWritingCard), findsOneWidget);
      expect(find.text(l10n.daybookDraft), findsOneWidget);
      expect(jsonDecode(app.prefs.getString(_draftKey)!)['photos'], isNotEmpty);
    });

    testWidgets('review 46: tapping the due while writing offers Remove; '
        'removing takes it off the card [$lang]', (tester) async {
      final draft = jsonEncode(
        DaybookPostDraft(
          id: 'draft-1',
          title: s.cableTraysTitle,
          dueDate: _sunday,
        ).toJson(),
      );
      await _open(tester, lang, draft: draft, due: (day: null, at: null));
      await tester.tap(find.byKey(const Key('daybook-draft')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(words.dueProperty(_sunday, null)));
      await tester.pumpAndSettle();
      final card = tester.widget<BvWritingCard>(find.byType(BvWritingCard));
      // Only the who row is left (F56).
      expect(
        [for (final p in card.properties) p.label],
        [l10n.daybookForChoose],
      );
      expect(
        _read(tester, daybookDraftProvider(DaybookSamples.space))!.dueDate,
        isNull,
      );
    });

    testWidgets("review 46: a post the server refuses comes back as the "
        "Draft, \"Couldn't send. Tap to fix\"; nothing is lost [$lang]", (
      tester,
    ) async {
      final daybook = FakeDaybookRepository()..refuse = true;
      final app = await _open(tester, lang, daybook: daybook);
      await _write(tester);
      await _title(tester, s.cableTraysTitle);
      await _assign(tester, s.omarName);
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(find.text(l10n.daybookCouldNotSend), findsOneWidget);
      expect(find.text(s.cableTraysTitle), findsOneWidget);
      expect(_read(tester, workOutboxProvider), isEmpty);
      expect(
        jsonDecode(app.prefs.getString(_draftKey)!)['could_not_send'],
        isTrue,
      );
      // Tapping reopens writing, with what was written.
      await tester.tap(find.byKey(const Key('daybook-draft')));
      await tester.pumpAndSettle();
      expect(find.byType(BvWritingToolbar), findsOneWidget);
      final draft = _read(tester, daybookDraftProvider(DaybookSamples.space))!;
      expect(draft.title, s.cableTraysTitle);
      expect(draft.ownerId, DaybookSamples.omar);
      // Fixed and posted: it goes.
      daybook.refuse = false;
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(daybook.created.single.title, s.cableTraysTitle);
      expect(find.text(l10n.daybookCouldNotSend), findsNothing);
    });

    testWidgets('a Viewer can\'t write [$lang]', (tester) async {
      await _open(tester, lang, pass: SpacePass.viewer);
      expect(find.byKey(const Key('post-bar-notepad')), findsNothing);
      expect(find.byType(BvWritingCard), findsNothing);
    });

    testWidgets('day one: Post the first work item writes in place [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, posts: const []);
      await tester.tap(find.text(l10n.daybookFirstPost));
      await tester.pumpAndSettle();
      expect(find.byType(BvWritingCard), findsOneWidget);
      expect(find.byType(BvWritingToolbar), findsOneWidget);
    });
  }

  test('review 46: a draft is kept as soon as anything is entered', () {
    const empty = DaybookPostDraft(id: 'd');
    expect(empty.isEmpty, isTrue);
    expect(empty.copyWith(title: ' ').isEmpty, isTrue);
    expect(empty.copyWith(photos: ['p.jpg']).isEmpty, isFalse);
    expect(empty.copyWith(ownerId: 'o').isEmpty, isFalse);
    expect(empty.copyWith(dueDate: () => _sunday).isEmpty, isFalse);
    expect(empty.copyWith(place: () => 'Gate 3').isEmpty, isFalse);
    expect(empty.copyWith(body: 'x').isEmpty, isFalse);
  });

  group('the outbox, for a new work item', () {
    test('kept and read back; the 0.9.0 "create" items are not', () {
      final item = PendingItem(
        kind: PendingKind.workItem,
        id: 'p1',
        spaceId: 's',
        title: 'Cable tray hangers, level 4',
        ownerId: 'o',
        ownerName: 'Omar Haddad',
        body: 'Fix the hangers.',
        place: 'Level 4 corridor',
        dueDate: _sunday,
        dueAt: _twoPm,
        madeAt: DateTime(2026, 10, 15, 11, 20),
      );
      final back = PendingItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      );
      expect(back.kind, PendingKind.workItem);
      expect(back.dueDate, _sunday);
      expect(back.dueAt, _twoPm);
      expect(back.madeAt, DateTime(2026, 10, 15, 11, 20));
      expect(back.place, 'Level 4 corridor');
      expect(PendingItem.isKnown({'kind': 'create'}), isFalse);
      expect(PendingItem.isKnown(item.toJson()), isTrue);
    });
  });
}
