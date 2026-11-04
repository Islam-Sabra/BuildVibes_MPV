// Review 116: Poll. The composer (PL1): the question, 2 to 6 options with
// ✕, Add an option, One answer · More than one, Closes; it goes as
// create_poll. The card (PL2): each option with a thin bar and the faces
// of who chose it, never a percentage, the reader's own ticked, Closes and
// "Not yet: …"; one tap chooses, again changes or takes back; More than
// one toggles. Closed (PL3): DECIDED · <option>, TIED with the creator's
// pick, or "Closed with no answers"; Close poll from the hold bar for its
// creator or a Space admin; Make it a work item. In English and Arabic.
import 'dart:async';

import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/features/work/composer_poll.dart' show PollRing;
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/poll.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/activity/activity_screen.dart';
import 'package:buildvibes/features/work/composer_kinds.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/features/work/poll_card.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));
Finder _entry(String id) => _key('daybook-card-$id');

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _poll = 'post-poll';

/// A poll by [author]: Thursday, Saturday, Sunday.
DaybookCard _pollCard(
  DaybookSamples s, {
  String author = DaybookSamples.islam,
  DaybookPoll? poll,
}) => s.card(
  DaybookPost(
    id: _poll,
    kind: DaybookPost.pollKind,
    createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 1)),
    title: s.t(
      'Which day for the L3 slab pour?',
      'أي يوم لصبّ بلاطة الطابق 3؟',
    ),
    authorId: author,
    authorName: author == DaybookSamples.islam ? s.islamName : s.saraName,
    poll:
        poll ??
        DaybookPoll(
          closesAt: DaybookSamples.thursday.add(const Duration(days: 1)),
          voted: true,
          options: [
            PollOption(
              id: 'opt-thu',
              label: s.t('Thursday', 'الخميس'),
              count: 2,
              voters: [
                DaybookPerson(id: DaybookSamples.omar, name: s.omarName),
                DaybookPerson(id: DaybookSamples.sara, name: s.saraName),
              ],
            ),
            PollOption(
              id: 'opt-sat',
              label: s.t('Saturday', 'السبت'),
              sort: 1,
              count: 1,
              voters: [
                DaybookPerson(id: DaybookSamples.rakesh, name: s.rakeshName),
              ],
            ),
            PollOption(id: 'opt-sun', label: s.t('Sunday', 'الأحد'), sort: 2),
          ],
          notYet: [s.t('Lina', 'لينا'), s.t('Tariq', 'طارق')],
          notYetMore: 2,
        ),
  ),
);

DaybookPoll _closed({String? decided, bool tied = false, bool voted = true}) =>
    DaybookPoll(
      closedAt: DaybookSamples.thursday.subtract(const Duration(minutes: 5)),
      closedByName: 'Omar Haddad',
      decidedOption: decided,
      tied: tied,
      voted: voted,
      options: [
        PollOption(id: 'opt-thu', label: 'Thursday', count: voted ? 1 : 0),
        PollOption(
          id: 'opt-sat',
          label: 'Saturday',
          sort: 1,
          count: voted && tied ? 1 : 0,
        ),
      ],
    );

Future<({TestApp app, FakeDaybookRepository daybook})> _open(
  WidgetTester tester,
  String lang, {
  List<DaybookCard> posts = const [],
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  String composerKind = 'poll',
}) async {
  final s = DaybookSamples(lang);
  final daybook = FakeDaybookRepository()..posts[DaybookSamples.space] = posts;
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    composerKind: composerKind,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: pass,
        admin: me == DaybookSamples.islam,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: daybook,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return (app: app, daybook: daybook);
}

DaybookPostDraft? _draft(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Navigator).first),
).read(daybookDraftProvider(DaybookSamples.space));

/// Review 116b V2: the card's Vote / Change vote / Take back my vote.
Future<void> _send(WidgetTester tester) => _tap(tester, _key('poll-vote'));

Future<void> _hold(WidgetTester tester, String id) async {
  await scrollToRow(tester, _entry(id));
  await tester.longPress(
    find.descendant(of: _entry(id), matching: find.byType(BvSlip)).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('PL1 composer [$lang]', () {
      testWidgets('a poll: the question, two options to start, then '
          'create_poll with the options in order', (tester) async {
        final (:app, :daybook) = await _open(tester, lang);
        await _tap(tester, _key('post-bar-notepad'));
        expect(find.text(l10n.cpNewPoll), findsOneWidget);
        expect(_key('poll-option-field-0'), findsOneWidget);
        expect(_key('poll-option-field-1'), findsOneWidget);
        expect(_key('poll-option-field-2'), findsNothing);
        await tester.enterText(_key('writing-title'), 'Which day?');
        await tester.enterText(_key('poll-option-field-0'), 'Thursday');
        await tester.pumpAndSettle();
        // One option is not a poll yet.
        await _tap(tester, _key('writing-post'));
        expect(daybook.createdPolls, isEmpty);
        await tester.enterText(_key('poll-option-field-1'), 'Saturday');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-post'));
        final made = daybook.createdPolls.single;
        expect(made.question, 'Which day?');
        expect(
          [for (final o in made.options) o.label],
          ['Thursday', 'Saturday'],
        );
        expect(made.multi, isFalse);
        expect(made.closesAt, isNull);
        expect(made.teamId, isNull);
        expect(made.spaceId, DaybookSamples.space);
        expect(app.pushes.calls, isNot(contains('poll')));
      });

      testWidgets('Add an option up to six, ✕ takes one off, More than one', (
        tester,
      ) async {
        final (app: _, :daybook) = await _open(tester, lang);
        await _tap(tester, _key('post-bar-notepad'));
        for (var i = 0; i < 4; i++) {
          await _tap(tester, _key('poll-add-option'));
        }
        expect(_key('poll-option-field-5'), findsOneWidget);
        expect(_key('poll-add-option'), findsNothing, reason: 'six at most');
        await _tap(tester, _key('poll-option-remove-5'));
        expect(_key('poll-option-field-5'), findsNothing);
        expect(_key('poll-add-option'), findsOneWidget);
        expect(find.text(l10n.pollOneAnswer), findsOneWidget);
        await _tap(tester, _key('poll-answers-more'));
        expect(_draft(tester)!.pollMulti, isTrue);
        await tester.enterText(_key('writing-title'), 'Gates?');
        await tester.enterText(_key('poll-option-field-0'), 'Gate 1');
        await tester.enterText(_key('poll-option-field-1'), 'Gate 2');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-post'));
        expect(daybook.createdPolls.single.multi, isTrue);
        expect(
          daybook.createdPolls.single.options,
          hasLength(2),
          reason: 'blank options are left out',
        );
      });

      testWidgets('a poll takes no photo and no voice note', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('post-bar-notepad'));
        expect(_key('writing-camera'), findsNothing);
        expect(_key('writing-mic'), findsNothing);
      });

      test('Lead and Crew post a poll; a Viewer doesn\'t', () {
        expect(
          composerKindsFor(s.detail(pass: SpacePass.crew, admin: false)),
          contains(DaybookKind.poll),
        );
        expect(
          composerKindsFor(s.detail(pass: SpacePass.viewer, admin: false)),
          isNot(contains(DaybookKind.poll)),
        );
      });
    });

    group('PL2 open poll [$lang]', () {
      testWidgets('each option with its bar and faces, never a percentage; '
          'Closes and Not yet', (tester) async {
        await _open(tester, lang, posts: [_pollCard(s)]);
        await scrollToRow(tester, _entry(_poll));
        expect(_key('poll-option-opt-thu'), findsOneWidget);
        expect(_key('poll-bar-opt-thu'), findsOneWidget);
        expect(find.textContaining('%'), findsNothing);
        expect(_key('poll-mine-opt-thu'), findsNothing);
        expect(
          find.text(
            l10n.pollNotYet(
              l10n.pollNamesMore(
                // Review 118 F1: each name isolated.
                '${textRun(s.t('Lina', 'لينا'))}${lang == 'en' ? ', ' : '، '}'
                '${textRun(s.t('Tariq', 'طارق'))}',
                2,
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(_key('poll-closes'), findsOneWidget);
      });

      // Review 116b V2: a tap picks, the button sends.
      testWidgets('V2: a tap picks and sends nothing; Vote sends once', (
        tester,
      ) async {
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          posts: [_pollCard(s)],
        );
        Iterable<String> votes() =>
            daybook.calls.where((c) => c.startsWith('vote'));
        await scrollToRow(tester, _entry(_poll));
        expect(_key('poll-vote'), findsNothing, reason: 'nothing picked yet');
        await _tap(tester, _key('poll-option-opt-sun'));
        expect(votes(), isEmpty, reason: 'a tap sends nothing');
        expect(_key('poll-picked-opt-sun'), findsOneWidget);
        expect(_key('poll-mine-opt-sun'), findsNothing);
        expect(
          find.descendant(
            of: _key('poll-vote'),
            matching: find.text(l10n.pollVote),
          ),
          findsOneWidget,
        );
        await _send(tester);
        expect(votes(), ['vote $_poll opt-sun'], reason: 'Vote sends once');
        expect(_key('poll-mine-opt-sun'), findsOneWidget);
        expect(_key('poll-vote'), findsNothing);
      });

      testWidgets('V2: Change vote, then Take back my vote', (tester) async {
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          posts: [_pollCard(s)],
        );
        Iterable<String> votes() =>
            daybook.calls.where((c) => c.startsWith('vote'));
        await scrollToRow(tester, _entry(_poll));
        await _tap(tester, _key('poll-option-opt-sun'));
        await _send(tester);
        await _tap(tester, _key('poll-option-opt-thu'));
        expect(
          find.descendant(
            of: _key('poll-vote'),
            matching: find.text(l10n.pollChangeVote),
          ),
          findsOneWidget,
        );
        expect(votes(), hasLength(1), reason: 'still nothing sent');
        await _send(tester);
        expect(votes().last, 'vote $_poll opt-thu');
        await _tap(tester, _key('poll-option-opt-thu'));
        expect(
          find.descendant(
            of: _key('poll-vote'),
            matching: find.text(l10n.pollTakeBack),
          ),
          findsOneWidget,
        );
        await _send(tester);
        expect(votes().last, 'vote $_poll ');
        expect(_key('poll-mine-opt-thu'), findsNothing);
      });

      testWidgets('V2: picking my own vote again needs no button', (
        tester,
      ) async {
        await _open(tester, lang, posts: [_pollCard(s)]);
        await scrollToRow(tester, _entry(_poll));
        await _tap(tester, _key('poll-option-opt-sun'));
        await _send(tester);
        await _tap(tester, _key('poll-option-opt-thu'));
        await _tap(tester, _key('poll-option-opt-sun'));
        expect(_key('poll-vote'), findsNothing, reason: 'back to what I sent');
      });

      testWidgets('more than one: each option toggles', (tester) async {
        final base = _pollCard(s).post.poll!;
        final multi = DaybookPoll(
          multi: true,
          options: base.options,
          notYet: base.notYet,
        );
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: multi)],
        );
        Iterable<String> votes() =>
            daybook.calls.where((c) => c.startsWith('vote'));
        await scrollToRow(tester, _entry(_poll));
        await _tap(tester, _key('poll-option-opt-thu'));
        await _tap(tester, _key('poll-option-opt-sun'));
        expect(votes(), isEmpty, reason: 'V2: picks, nothing sent');
        await _send(tester);
        expect(votes(), ['vote $_poll opt-thu,opt-sun'], reason: 'one Vote');
        await _tap(tester, _key('poll-option-opt-thu'));
        await _send(tester);
        expect(votes().last, 'vote $_poll opt-sun');
      });

      testWidgets('a Viewer votes', (tester) async {
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          posts: [_pollCard(s)],
          me: DaybookSamples.lina,
          pass: SpacePass.viewer,
        );
        await scrollToRow(tester, _entry(_poll));
        await _tap(tester, _key('poll-option-opt-sat'));
        await _send(tester);
        expect(daybook.calls.last, 'vote $_poll opt-sat');
      });

      testWidgets('its creator closes it from the hold bar, asked once', (
        tester,
      ) async {
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          posts: [_pollCard(s)],
        );
        await _hold(tester, _poll);
        await _tap(tester, _key('select-close-poll'));
        expect(find.text(l10n.pollCloseTitle), findsOneWidget);
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(daybook.calls, contains('close $_poll'));
      });

      testWidgets('Crew who didn\'t make it can\'t close it', (tester) async {
        await _open(
          tester,
          lang,
          posts: [_pollCard(s, author: DaybookSamples.sara)],
          me: DaybookSamples.omar,
          pass: SpacePass.crew,
        );
        await _hold(tester, _poll);
        expect(_key('select-close-poll'), findsNothing);
      });
    });

    group('the lead\'s check of 30009056 [$lang]', () {
      testWidgets('P2: votes go one at a time, only the latest waiting', (
        tester,
      ) async {
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          posts: [_pollCard(s)],
        );
        daybook.holdVote = Completer<void>();
        await scrollToRow(tester, _entry(_poll));
        for (final o in ['opt-sun', 'opt-sat', 'opt-thu']) {
          await _tap(tester, _key('poll-option-$o'));
          await _send(tester);
        }
        Iterable<String> votes() =>
            daybook.calls.where((c) => c.startsWith('vote'));
        expect(votes(), ['vote $_poll opt-sun'], reason: 'one at a time');
        expect(
          _key('poll-mine-opt-thu'),
          findsOneWidget,
          reason: 'shown at once',
        );
        daybook.holdVote!.complete();
        daybook.holdVote = null;
        await tester.pumpAndSettle();
        expect(votes(), [
          'vote $_poll opt-sun',
          'vote $_poll opt-thu',
        ], reason: 'then only the latest');
      });

      testWidgets('P3: the chosen and the decided in ink on white; DECIDED '
          'and TIED red', (tester) async {
        await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: _closed(decided: 'opt-thu'))],
        );
        await scrollToRow(tester, _entry(_poll));
        BoxDecoration row(String id) =>
            tester.widget<Container>(_key('poll-row-$id')).decoration!
                as BoxDecoration;
        Color fill(String id) =>
            tester.widget<ColoredBox>(_key('poll-fill-$id')).color;
        expect(row('opt-thu').color, BvColors.surfaceElevated);
        expect(
          (row('opt-thu').border! as Border).top.color,
          BvColors.textPrimary,
        );
        expect(fill('opt-thu'), BvColors.textPrimary);
        expect(row('opt-sat').color, BvColors.surfaceSubtle);
        expect(fill('opt-sat'), BvColors.iconSecondary, reason: 'a grey bar');
        expect(
          tester
              .widget<BvInkStamp>(
                find.descendant(
                  of: _key('poll-decided'),
                  matching: find.byType(BvInkStamp),
                ),
              )
              .tone,
          BvInkStampTone.action,
        );
      });

      testWidgets('P3: TIED is the same red stamp', (tester) async {
        await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: _closed(tied: true))],
        );
        await scrollToRow(tester, _entry(_poll));
        expect(
          tester
              .widget<BvInkStamp>(
                find.descendant(
                  of: _key('poll-tied'),
                  matching: find.byType(BvInkStamp),
                ),
              )
              .tone,
          BvInkStampTone.action,
        );
      });

      testWidgets('P3: my choice on an open poll in ink on white', (
        tester,
      ) async {
        await _open(tester, lang, posts: [_pollCard(s)]);
        await scrollToRow(tester, _entry(_poll));
        await _tap(tester, _key('poll-option-opt-sat'));
        await _send(tester);
        final mine =
            tester.widget<Container>(_key('poll-row-opt-sat')).decoration!
                as BoxDecoration;
        expect(mine.color, BvColors.surfaceElevated);
        expect(
          tester.widget<ColoredBox>(_key('poll-fill-opt-sat')).color,
          BvColors.textPrimary,
        );
        expect(
          tester.widget<ColoredBox>(_key('poll-fill-opt-thu')).color,
          BvColors.iconSecondary,
        );
      });

      testWidgets('P4: a Lead who didn\'t make it makes it a work item', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: _closed(decided: 'opt-thu'))],
          me: DaybookSamples.sara,
        );
        await scrollToRow(tester, _entry(_poll));
        expect(_key('poll-make-work-item'), findsOneWidget);
      });

      // Review 118 F1: a Latin question made a work item keeps its
      // direction in the composer's title, also in Arabic.
      testWidgets('F1: Make it a work item: the title in its own direction', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [
            _pollCard(s, poll: _closed(decided: 'opt-thu')).copyWith(
              post: _pollCard(
                s,
                poll: _closed(decided: 'opt-thu'),
              ).post.shownAs(),
            ),
          ],
          me: DaybookSamples.sara,
        );
        await scrollToRow(tester, _entry(_poll));
        await _tap(tester, _key('poll-make-work-item'));
        final field = tester.widget<TextField>(_key('writing-title'));
        expect(
          field.controller!.text,
          startsWith(lang == 'en' ? 'Which' : 'أي'),
        );
        expect(
          field.textDirection,
          lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
        );
      });

      testWidgets('F1: a Latin title in Arabic is written left to right', (
        tester,
      ) async {
        await _open(tester, lang, composerKind: 'note');
        await _tap(tester, _key('post-bar-notepad'));
        await tester.enterText(_key('writing-title'), 'Pour time on level 4?');
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_key('writing-title')).textDirection,
          TextDirection.ltr,
        );
      });

      testWidgets('P5: its creator edits it before the first vote', (
        tester,
      ) async {
        final base = _pollCard(s).post.poll!;
        final fresh = DaybookPoll(
          closesAt: base.closesAt,
          options: [
            for (final o in base.options)
              PollOption(id: o.id, label: o.label, sort: o.sort),
          ],
        );
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: fresh)],
          composerKind: 'note',
        );
        await _hold(tester, _poll);
        await _tap(tester, _key('select-edit-poll'));
        expect(
          tester
              .widget<TextField>(_key('poll-option-field-0'))
              .controller!
              .text,
          s.t('Thursday', 'الخميس'),
        );
        await tester.enterText(_key('writing-title'), 'Which day, then?');
        await tester.enterText(_key('poll-option-field-2'), 'Monday');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-post'));
        final edited = daybook.editedPolls.single;
        expect(edited.postId, _poll);
        expect(edited.question, 'Which day, then?');
        expect(
          [for (final o in edited.options) o.id],
          ['opt-thu', 'opt-sat', 'opt-sun'],
        );
        expect(edited.options.last.label, 'Monday');
        expect(edited.closesAt, base.closesAt);
      });

      testWidgets('P5: no Edit once someone voted', (tester) async {
        await _open(tester, lang, posts: [_pollCard(s)]);
        await _hold(tester, _poll);
        expect(_key('select-edit-poll'), findsNothing);
      });

      testWidgets('P5: nor for someone who didn\'t make it', (tester) async {
        final base = _pollCard(s).post.poll!;
        await _open(
          tester,
          lang,
          posts: [
            _pollCard(
              s,
              author: DaybookSamples.sara,
              poll: DaybookPoll(options: base.options),
            ),
          ],
        );
        await _hold(tester, _poll);
        expect(_key('select-edit-poll'), findsNothing);
      });
    });

    group('review 118 [$lang]', () {
      // F1: text in a poll keeps its own direction (shot 22 AR: «?Pour time
      // on level 4», «am 7»).
      DaybookCard latin({List<String> notYet = const ['Islam', 'smsm']}) =>
          s.card(
            DaybookPost(
              id: _poll,
              kind: DaybookPost.pollKind,
              createdAt: DaybookSamples.thursday,
              title: 'Pour time on level 4?',
              authorId: DaybookSamples.sara,
              authorName: s.saraName,
              poll: DaybookPoll(
                closesAt: DaybookSamples.thursday.add(const Duration(days: 1)),
                voted: true,
                options: [
                  const PollOption(id: 'opt-7', label: '7 am', count: 1),
                  const PollOption(id: 'opt-9', label: '9 am', sort: 1),
                ],
                notYet: notYet,
              ),
            ),
          );

      testWidgets('F1: a Latin question and options keep their direction', (
        tester,
      ) async {
        await _open(tester, lang, posts: [latin()], me: DaybookSamples.omar);
        await scrollToRow(tester, _entry(_poll));
        expect(find.text(textRun('Pour time on level 4?')), findsOneWidget);
        expect(find.text(textRun('7 am')), findsOneWidget);
        expect(find.text(textRun('9 am')), findsOneWidget);
      });

      testWidgets('F1: "Not chosen yet": each name isolated, joined by '
          'locale, no «و» glued to a Latin name', (tester) async {
        await _open(tester, lang, posts: [latin()], me: DaybookSamples.omar);
        await scrollToRow(tester, _entry(_poll));
        final line = tester.widget<Text>(_key('poll-not-yet')).data!;
        expect(line, contains(textRun('Islam')));
        expect(line, contains(textRun('smsm')));
        expect(
          line,
          contains(
            lang == 'ar'
                ? '${textRun('Islam')} و ${textRun('smsm')}'
                : '${textRun('Islam')} and ${textRun('smsm')}',
          ),
        );
        expect(line, isNot(contains('و${textRun('smsm')}')));
      });

      testWidgets('F1: an Arabic name last keeps «و» joined to it', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [
            latin(notYet: ['Islam', 'سارة']),
          ],
          me: DaybookSamples.omar,
        );
        await scrollToRow(tester, _entry(_poll));
        final line = tester.widget<Text>(_key('poll-not-yet')).data!;
        expect(line, contains(textRun('سارة')));
        if (lang == 'ar') expect(line, contains('و${textRun('سارة')}'));
      });

      // F4: after a decision, a check marks only my answer; the decided row
      // keeps its ink outline and its own small DECIDED stamp.
      DaybookPoll decided({String? mine}) => DaybookPoll(
        closedAt: DaybookSamples.thursday.subtract(const Duration(minutes: 5)),
        closedByName: 'Omar Haddad',
        decidedOption: 'opt-thu',
        voted: true,
        options: [
          PollOption(
            id: 'opt-thu',
            label: 'Thursday',
            count: 2,
            mine: mine == 'opt-thu',
          ),
          PollOption(
            id: 'opt-sat',
            label: 'Saturday',
            sort: 1,
            count: 1,
            mine: mine == 'opt-sat',
          ),
        ],
      );
      Finder checkIn(String id) => find.descendant(
        of: _key('poll-row-$id'),
        matching: find.byWidgetPredicate((w) => w is PollRing && w.on),
      );
      Finder stampIn(String id) => find.descendant(
        of: _key('poll-row-$id'),
        matching: find.byType(BvInkStamp),
      );

      testWidgets('F4: my answer lost: the check on mine, the stamp on the '
          'decided one, no check there', (tester) async {
        await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: decided(mine: 'opt-sat'))],
        );
        await scrollToRow(tester, _entry(_poll));
        expect(checkIn('opt-sat'), findsOneWidget);
        expect(checkIn('opt-thu'), findsNothing);
        expect(stampIn('opt-thu'), findsOneWidget);
        expect(stampIn('opt-sat'), findsNothing);
        expect(
          find.descendant(
            of: _key('poll-decided'),
            matching: find.byType(BvInkStamp),
          ),
          findsOneWidget,
          reason: 'the line above the options stays',
        );
      });

      testWidgets('F4: my answer won: that row has the check and the stamp', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: decided(mine: 'opt-thu'))],
        );
        await scrollToRow(tester, _entry(_poll));
        expect(checkIn('opt-thu'), findsOneWidget);
        expect(stampIn('opt-thu'), findsOneWidget);
        expect(checkIn('opt-sat'), findsNothing);
      });

      testWidgets("F4: I didn't vote: no check anywhere, the stamp on the "
          'decided row', (tester) async {
        await _open(tester, lang, posts: [_pollCard(s, poll: decided())]);
        await scrollToRow(tester, _entry(_poll));
        expect(checkIn('opt-thu'), findsNothing);
        expect(checkIn('opt-sat'), findsNothing);
        expect(stampIn('opt-thu'), findsOneWidget);
      });

      // F3: a vote is acting: once someone other than its creator voted,
      // holding the poll offers Archive, never Delete.
      testWidgets('F3: my poll others voted on: Archive, never Delete', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [
            _pollCard(
              s,
            ).copyWith(post: _pollCard(s).post.shownAs(hold: PostHold.delete)),
          ],
        );
        await _hold(tester, _poll);
        expect(_key('select-archive'), findsOneWidget);
        expect(_key('select-delete'), findsNothing);
      });
    });

    group('PL3 closed [$lang]', () {
      testWidgets('decided: the stamp with the winner, who closed it, and '
          'Make it a work item for its creator', (tester) async {
        await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: _closed(decided: 'opt-thu'))],
          composerKind: 'work_item',
        );
        await scrollToRow(tester, _entry(_poll));
        expect(_key('poll-decided'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('poll-decided'),
            matching: find.textContaining(l10n.pollDecided),
          ),
          findsOneWidget,
        );
        expect(_key('poll-closed-by'), findsOneWidget);
        await _tap(tester, _key('poll-make-work-item'));
        final d = _draft(tester)!;
        expect(d.kind, DaybookKind.workItem);
        expect(
          d.title,
          l10n.pollWorkItemTitle(
            s.t('Which day for the L3 slab pour', 'أي يوم لصبّ بلاطة الطابق 3'),
            'Thursday',
          ),
        );
      });

      testWidgets('no vote after it closes', (tester) async {
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: _closed(decided: 'opt-thu'))],
        );
        await scrollToRow(tester, _entry(_poll));
        await _tap(tester, _key('poll-option-opt-sat'));
        expect(daybook.calls.where((c) => c.startsWith('vote')), isEmpty);
      });

      testWidgets('tied: TIED, and its creator taps the winner', (
        tester,
      ) async {
        final (app: _, :daybook) = await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: _closed(tied: true))],
        );
        await scrollToRow(tester, _entry(_poll));
        expect(_key('poll-tied'), findsOneWidget);
        expect(find.text(l10n.pollPickWinner), findsOneWidget);
        await _tap(tester, _key('poll-option-opt-sat'));
        expect(daybook.calls.last, 'decide $_poll opt-sat');
      });

      testWidgets('nobody voted: Closed with no answers, no stamp', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [_pollCard(s, poll: _closed(voted: false))],
        );
        await scrollToRow(tester, _entry(_poll));
        expect(find.text(l10n.pollNoAnswers), findsOneWidget);
        expect(_key('poll-decided'), findsNothing);
        expect(_key('poll-make-work-item'), findsNothing);
      });

      testWidgets('Crew who didn\'t make it doesn\'t get Make it a work item', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [
            _pollCard(
              s,
              author: DaybookSamples.sara,
              poll: _closed(decided: 'opt-thu'),
            ),
          ],
          me: DaybookSamples.omar,
          pass: SpacePass.crew,
        );
        await scrollToRow(tester, _entry(_poll));
        expect(_key('poll-decided'), findsOneWidget);
        expect(_key('poll-make-work-item'), findsNothing);
      });
    });
  }

  for (final lang in ['en', 'ar']) {
    test('Activity: a new poll for you, and your poll closed [$lang]', () {
      final l10n = lookupAppLocalizations(Locale(lang));
      ActivityRow row(String kind) => ActivityRow.fromJson({
        'id': 'n-$kind',
        'kind': kind,
        'created_at': '2026-11-04T07:00:00Z',
        'space_id': 'space-1',
        'space_name': 'Tower B',
        'work_item_title': 'Which day?',
        'actor_id': 'p-sara',
        'actor_name': 'Sara Ali',
        'space_post_id': 'post-1',
        'post_kind': 'poll',
      });
      // Names and titles go in as their own runs (bidi), so: contains.
      final asked = activityWords(l10n, row('poll_new'));
      expect(asked.text, contains('Sara Ali'));
      expect(asked.text, contains('Which day?'));
      expect(asked.where, contains('Tower B'));
      // P7: a tie asks its creator to pick.
      final tied = activityWords(l10n, row('poll_tied'));
      expect(tied.text, contains('Which day?'));
      expect(tied.where, contains('Tower B'));
      final closed = activityWords(l10n, row('poll_closed'));
      expect(tied.text, isNot(closed.text));
      expect(closed.text, contains('Which day?'));
      expect(closed.text, isNot(contains('Sara Ali')), reason: 'their own');
      expect(closed.text, isNot(asked.text));
      expect(row('poll_closed').cardId, 'post-1');
    });
  }

  test("a poll's time is its time, never 'on now' or a countdown", () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final words = DaybookWords(l10n, 'en', use24: false);
    final now = DateTime(2026, 11, 4, 10, 30);
    final justClosed = words.pollWhen(
      now.subtract(const Duration(minutes: 5)),
      now,
    );
    expect(justClosed, isNot(contains('on now')));
    expect(
      words.pollWhen(now.add(const Duration(minutes: 20)), now),
      isNot(contains('min')),
    );
  });

  test('a note with photos turned into a poll says the photos go', () {
    const note = DaybookPostDraft(
      id: 'p',
      kind: DaybookKind.note,
      title: 'Which day?',
      photos: ['/a.jpg'],
    );
    final drops = composerDrops(note, DaybookKind.poll);
    expect(drops, contains(ComposerDrop.photos));
    final poll = composerSwitched(note, DaybookKind.poll, drops);
    expect(poll.photos, isEmpty);
    expect(poll.pollOptions, hasLength(2));
  });

  test('the work item title drops the question mark before the answer', () {
    for (final lang in ['en', 'ar']) {
      final l10n = lookupAppLocalizations(Locale(lang));
      expect(
        pollWorkItemTitle(l10n, 'Which day? ', 'Saturday'),
        l10n.pollWorkItemTitle('Which day', 'Saturday'),
      );
      expect(
        pollWorkItemTitle(l10n, 'أي يوم؟', 'السبت'),
        l10n.pollWorkItemTitle('أي يوم', 'السبت'),
      );
    }
  });

  test('the card JSON reads into a poll', () {
    final poll = DaybookPoll.fromJson({
      'multi': false,
      'closes_at': null,
      'closed_at': '2026-11-04T10:00:00Z',
      'closed_by_name': 'Omar Haddad',
      'decided_option': 'b',
      'tied': false,
      'voted': true,
      'options': [
        {
          'id': 'b',
          'label': 'Sat',
          'sort': 1,
          'count': 1,
          'mine': true,
          'voters': [
            {'id': 'u1', 'name': 'Omar Haddad', 'avatar': null},
          ],
        },
        {
          'id': 'a',
          'label': 'Thu',
          'sort': 0,
          'count': 0,
          'mine': false,
          'voters': [],
        },
      ],
      'not_yet': {
        'names': ['Lina'],
        'more': 0,
      },
    })!;
    expect([for (final o in poll.options) o.id], ['a', 'b']);
    expect(poll.decided!.label, 'Sat');
    expect(poll.mine, {'b'});
    expect(poll.isClosed(DateTime(2026, 11, 4, 12)), isTrue);
    expect(poll.notYet, ['Lina']);
    expect(DaybookPoll.fromJson(null), isNull);
  });
}
