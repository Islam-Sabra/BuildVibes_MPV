import 'dart:convert';

import 'package:buildvibes/core/design/bv_icons.dart';
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
import 'package:buildvibes/shared/widgets/bv_post_bar.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:buildvibes/shared/widgets/bv_writing_rows.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
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

/// Assign through the For row (review 105 SP2; picking from Post would
/// post at once).
Future<void> _assign(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('writing-who')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(BvGiveToPicker), matching: find.text(name)),
  );
  await tester.pumpAndSettle();
}

BvWritingRow _row(WidgetTester tester, String key) => tester
    .widget<BvWritingRows>(find.byType(BvWritingRows))
    .rows
    .firstWhere((r) => r.key == Key(key));

T _read<T>(WidgetTester tester, ProviderListenable<T> provider) =>
    ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    ).read(provider);

BvWritingToolbar _toolbar(WidgetTester tester) =>
    tester.widget<BvWritingToolbar>(find.byType(BvWritingToolbar));

/// The cable trays' place in the Space's list (review 105C).
const _traysPlaceId = 'place-l4-corridor';
SpacePlace _traysPlace(DaybookSamples s) =>
    SpacePlace(id: _traysPlaceId, name: s.traysPlace);

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
      // Review 105 SP2: a work item first, among the kind chips.
      expect(
        tester
            .widget<BvKindChips<Object>>(find.byKey(const Key('writing-kinds')))
            .selected,
        DaybookKind.workItem,
      );
      expect(find.byKey(const Key('writing-kind-chip')), findsNothing);
      // Post is off with no title.
      expect(_toolbar(tester).onPost, isNull);
    });

    testWidgets('F69: the picker lists me once, first, as You, then a '
        'hairline and the others; a search shows You only for my name; '
        'choosing You reads For you [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester);
      await tester.tap(find.byKey(const Key('writing-who')));
      await tester.pumpAndSettle();
      final picker = find.byType(BvGiveToPicker);
      final me = find.byKey(const Key('give-to-me'));
      expect(me, findsOneWidget);
      expect(
        find.descendant(of: me, matching: find.text(l10n.daybookYou)),
        findsOneWidget,
      );
      // My name isn't listed again.
      expect(
        find.descendant(of: picker, matching: find.text(s.islamName)),
        findsNothing,
      );
      final hairline = find.byKey(const Key('give-to-me-hairline'));
      expect(hairline, findsOneWidget);
      final omar = find.descendant(of: picker, matching: find.text(s.omarName));
      expect(
        tester.getTopLeft(me).dy,
        lessThan(tester.getTopLeft(hairline).dy),
      );
      expect(
        tester.getTopLeft(hairline).dy,
        lessThan(tester.getTopLeft(omar).dy),
      );
      // A search: You only when my own name matches.
      final search = find.descendant(
        of: find.byKey(const Key('give-to-search')),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, s.omarName.split(' ').first);
      await tester.pumpAndSettle();
      expect(me, findsNothing);
      await tester.enterText(search, s.islamName.split(' ').first);
      await tester.pumpAndSettle();
      expect(me, findsOneWidget);
      expect(find.byKey(const Key('give-to-me-hairline')), findsNothing);
      await tester.tap(me);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('writing-who')),
          matching: find.text(l10n.daybookYou),
        ),
        findsOneWidget,
      );
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
          matching: find.text(l10n.daybookRowChoose),
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
        tester
            .widget<BvKindChips<Object>>(find.byKey(const Key('writing-kinds')))
            .selected,
        DaybookKind.note,
      );
      expect(find.byKey(const Key('writing-who')), findsNothing);
      expect(_toolbar(tester).postReady, isTrue);
    });

    testWidgets('the For row only sets the owner [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _write(tester);
      await _title(tester, s.cableTraysTitle);
      await _assign(tester, s.omarName);
      expect(app.daybook.created, isEmpty);
      expect(_row(tester, 'writing-who').value, s.omarName);
    });

    testWidgets('F66, review 105 SP2: once chosen, the For row shows the '
        'face and the name, with a mirrored caret; a tap opens the picker '
        'again [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester);
      await _title(tester, s.cableTraysTitle);
      await _assign(tester, s.omarName);
      final who = _row(tester, 'writing-who');
      expect(who.value, s.omarName);
      expect(who.person, s.omarName);
      expect(who.onTap, isNotNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('writing-who')),
          matching: find.byIcon(BvIcons.caretForward),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('writing-who')),
          matching: find.byType(BvAvatar),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BvGiveToPicker), findsOneWidget);
    });

    testWidgets('E2, review 105 SP2: For, Place and Due are rows; + holds '
        'nothing for a work item with no template [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester);
      expect(
        tester
            .widget<BvWritingRows>(find.byType(BvWritingRows))
            .rows
            .map((r) => r.key),
        const [
          Key('writing-who'),
          Key('writing-place-row'),
          Key('writing-due-row'),
          Key('writing-to'),
        ],
      );
      expect(_toolbar(tester).tools!.first.onTap, isNull);
    });

    testWidgets('E3: owner, due date with a time, place and the cover; Post '
        'sends create_work_item with the card\'s id [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        due: (day: _sunday, at: _twoPm),
        daybook: FakeDaybookRepository()
          ..placesBySpace[DaybookSamples.space] = [_traysPlace(s)]
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
      // Review 105 SP2: the Due and Place rows.
      await tester.tap(find.byKey(const Key('writing-due-row')));
      await tester.pumpAndSettle();
      // Review 105C: one of the Space's places, from the picker.
      await tester.tap(find.byKey(const Key('writing-place-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('place-row-$_traysPlaceId')));
      await tester.pumpAndSettle();
      // The cover, from the camera.
      await tester.tap(find.bySemanticsLabel(l10n.daybookCamera));
      await tester.pumpAndSettle();
      final card = tester.widget<BvWritingCard>(find.byType(BvWritingCard));
      expect(
        tester
            .widget<BvWritingRows>(find.byType(BvWritingRows))
            .rows
            .map((r) => r.value),
        [
          s.omarName,
          s.traysPlace,
          words.dueProperty(_sunday, _twoPm),
          l10n.daybookWholeSpace,
        ],
      );
      expect(card.photos, hasLength(1));

      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      final sent = app.daybook.created.single;
      expect(sent.id, id);
      expect(sent.spaceId, DaybookSamples.space);
      expect(sent.title, s.cableTraysTitle);
      expect(sent.body, s.traysBody);
      expect(sent.ownerId, DaybookSamples.omar);
      // The place goes by its id (set_post_place), and its name as
      // place_text, kept if the id is refused (the lead's check M1).
      expect(sent.place, s.traysPlace);
      expect(app.daybook.calls, contains('set-place $id $_traysPlaceId'));
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
      expect(
        await readPage<Widget>(tester, find.byKey(Key('daybook-card-$id'))),
        hasLength(1),
      );
      expect(
        await readPage<Widget>(tester, find.text(l10n.daybookWaitingToSend)),
        isEmpty,
      );
      expect(_read(tester, workOutboxProvider), isEmpty);
    });

    testWidgets('F88: a kept card made from a quoted message is the Draft '
        'when the Space is opened again [$lang]', (tester) async {
      final draft = jsonEncode(
        DaybookPostDraft(
          id: 'draft-q',
          quote: const DaybookQuote(text: 'At the gate at 7?'),
        ).toJson(),
      );
      await _open(tester, lang, draft: draft);
      expect(find.byType(BvWritingCard), findsOneWidget);
      expect(find.text(l10n.daybookDraft), findsOneWidget);
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
      final daybook = FakeDaybookRepository()
        ..placesBySpace[DaybookSamples.space] = [_traysPlace(s)];
      final app = await _open(tester, lang, daybook: daybook);
      await _write(tester);
      await _title(tester, s.cableTraysTitle);
      await _assign(tester, s.omarName);
      // F29: the place, through its row (review 105 SP2).
      // Review 105C: one of the Space's places, from the picker.
      await tester.tap(find.byKey(const Key('writing-place-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('place-row-$_traysPlaceId')));
      await tester.pumpAndSettle();
      // No signal from here.
      daybook.offline = true;
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      // On the page at the time Post was tapped, waiting.
      expect(
        await readPage<Widget>(tester, find.text(s.cableTraysTitle)),
        hasLength(1),
      );
      expect(
        await readPage<Widget>(tester, find.text(l10n.daybookWaitingToSend)),
        hasLength(1),
      );
      expect(daybook.created, isEmpty);
      // F5: no sound while it only waits.
      expect(app.chimes, isEmpty);
      // Kept on the phone: it outlives the app being closed.
      final kept = app.prefs.getString('work_outbox:${DaybookSamples.islam}')!;
      expect(jsonDecode(kept), hasLength(1));
      final waitingId = (jsonDecode(kept) as List).single['id'];
      // The place waits on the phone with it.
      expect((jsonDecode(kept) as List).single['place'], s.traysPlace);
      expect((jsonDecode(kept) as List).single['place_id'], _traysPlaceId);

      // The signal is back: the next try sends it.
      daybook.offline = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(daybook.created.single.id, waitingId);
      expect(daybook.calls, contains('set-place $waitingId $_traysPlaceId'));
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
      // Put down with ←: the card with its photo fills the page.
      await tester.binding.handlePopRoute();
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
      // The Due row is empty again.
      expect(_row(tester, 'writing-due-row').empty, isTrue);
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
