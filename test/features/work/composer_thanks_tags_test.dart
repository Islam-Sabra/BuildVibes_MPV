// Review 110 E in the composer: a Thanks (TH1 2715:39559) to a person or a
// Team, for an optional work item, its words in the title line and
// Details (optional) under them (W6); Post later for it too (W7); a
// Viewer may thank, and only thank (founder, 1 Nov); a work
// item's one tag from + → Tag (TG1 2715:39661), Safety red; Work filtered
// by a card's tag; and + → Checklist on a work item (step 5). In English
// and Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/schedule_repository.dart';
import 'package:buildvibes/features/work/daybook_composer.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_chip.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/composer_steps.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/later_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

final _now = DaybookSamples.thursday;

const _tags = [
  DaybookTag(
    id: 'safety',
    name: {'en': 'Safety', 'ar': 'السلامة'},
    danger: true,
  ),
  DaybookTag(id: 'quality', name: {'en': 'Quality', 'ar': 'الجودة'}),
  DaybookTag(id: 'design', name: {'en': 'Design', 'ar': 'التصميم'}),
];

/// Islam (Lead, or another [pass]) writing in the sample Space, the
/// composer open on [kind].
Future<FakeDaybookRepository> _open(
  WidgetTester tester,
  String lang, {
  String kind = 'work_item',
  List<DaybookCard>? posts,
  bool write = true,
  SpacePass pass = SpacePass.lead,
  FakeScheduleRepository? schedule,
}) async {
  final s = DaybookSamples(lang);
  final fake = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = posts ?? s.d1()
    ..tagsBySpace[DaybookSamples.space] = _tags;
  await pumpApp(
    tester,
    language: lang,
    composerKind: kind,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: pass,
        admin: pass == SpacePass.lead,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: fake,
    schedule: schedule,
    now: _now,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  if (write) await _tap(tester, _key('post-bar-notepad'));
  return fake;
}

void main() {
  test('a draft keeps its Thanks, its tag and its points', () {
    const draft = DaybookPostDraft(
      id: 'p1',
      kind: DaybookKind.thanks,
      title: 'Thank you',
      thanksToId: DaybookSamples.omar,
      thanksToName: 'Omar Haddad',
      thanksForId: 'post-rebar',
      thanksForLabel: 'KCT-016 · Rebar',
      tag: DaybookTag(id: 'safety', name: {'en': 'Safety'}, danger: true),
      refusal: 'self',
    );
    final back = DaybookPostDraft.fromJson(draft.toJson());
    expect(back.kind, DaybookKind.thanks);
    expect(back.thanksToId, DaybookSamples.omar);
    expect(back.thanksToName, 'Omar Haddad');
    expect(back.thanksToTeam, isFalse);
    expect(back.thanksForId, 'post-rebar');
    expect(back.thanksForLabel, 'KCT-016 · Rebar');
    expect(back.tag?.id, 'safety');
    expect(back.tag?.danger, isTrue);
    expect(back.tag?.nameIn('en'), 'Safety');
    expect(back.refusal, 'self');
    expect(draft.missing(_now), isNull);
    expect(
      DaybookPostDraft(
        id: 'p2',
        kind: DaybookKind.thanks,
        title: 'x',
      ).missing(_now),
      DaybookMissing.to,
    );
  });

  test('a work item sends its tag as p_tag, and Post later keeps it', () {
    const item = NewWorkItem(
      id: 'p1',
      spaceId: 's1',
      title: 'Edge guard',
      ownerId: 'o1',
      tagId: 'safety',
    );
    expect(item.toParams()['p_tag'], 'safety');
    expect(
      const NewWorkItem(
        id: 'p1',
        spaceId: 's1',
        title: 'Edge guard',
        ownerId: 'o1',
      ).toParams().containsKey('p_tag'),
      isFalse,
    );
  });

  test('create_thanks takes the words, who, what for and the photos', () {
    const t = NewThanks(
      id: 'p1',
      spaceId: 's1',
      words: ' Thank you ',
      toTeamId: 't-mep',
      forId: 'post-rebar',
      photoPaths: ['s1/posts/p1/0.jpg'],
    );
    expect(t.toParams(), {
      'p_id': 'p1',
      'p_space': 's1',
      'p_body': 'Thank you',
      'p_to_person': null,
      'p_to_team': 't-mep',
      'p_for': 'post-rebar',
      'p_files': [
        {'path': 's1/posts/p1/0.jpg', 'mime': 'image/jpeg'},
      ],
    });
  });

  test('W7: a Thanks is one of the calls Post later keeps', () {
    expect(ScheduledCall.thanks, 'create_thanks');
  });

  test('W11: the kind it opens on is one this person may post: a Viewer '
      'thanks only; a kind kept from before falls back to Note', () async {
    SharedPreferences.setMockInitialValues({
      composerKindKey('s1'): 'work_item',
      composerKindKey('s2'): 'announcement',
    });
    final prefs = await SharedPreferences.getInstance();
    final lead = DaybookSamples('en').detail();
    final viewer = DaybookSamples('en').detail(pass: SpacePass.viewer);
    expect(composerKindsFor(lead), composerKinds);
    expect(composerKindsFor(viewer), const [DaybookKind.thanks]);
    expect(
      composerStartKind(prefs, 's1', composerKindsFor(lead)),
      DaybookKind.workItem,
    );
    expect(
      composerStartKind(prefs, 's1', composerKindsFor(viewer)),
      DaybookKind.thanks,
    );
    expect(composerStartKind(prefs, 'new', composerKinds), DaybookKind.note);
    expect(
      composerStartKind(prefs, 's2', const [
        DaybookKind.note,
        DaybookKind.thanks,
      ]),
      DaybookKind.note,
    );
  });

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('TH1 a Thanks [$lang]', () {
      testWidgets('# offers Thanks after Scheduled activity, before Walk', (
        tester,
      ) async {
        await _open(tester, lang);
        await _tap(tester, _key('writing-kind'));
        expect(
          find.descendant(
            of: _key('composer-kind-thanks'),
            matching: find.text(l10n.daybookKindThanks),
          ),
          findsOneWidget,
        );
        double x(String k) => tester.getTopLeft(_key('composer-kind-$k')).dx;
        double y(String k) => tester.getTopLeft(_key('composer-kind-$k')).dy;
        // The second row: Thanks before Walk (rows start at the start).
        expect(y('thanks'), greaterThan(y('note')));
        expect(y('thanks'), y('walk'));
        expect(
          lang == 'ar' ? x('thanks') > x('walk') : x('thanks') < x('walk'),
          isTrue,
        );
      });

      testWidgets('top "Thanks"; the words in the title line, Details '
          '(optional) under them; To, with its one quiet line, and For; no '
          'Team; + offers Photos only', (tester) async {
        await _open(tester, lang, kind: 'thanks');
        expect(
          find.descendant(
            of: _key('composer-top'),
            matching: find.text(l10n.cpNewThanks),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(_key('writing-title')).decoration?.hintText,
          l10n.thanksWordsHint,
        );
        expect(
          tester.widget<TextField>(_key('writing-body')).decoration?.hintText,
          l10n.cpDetails,
        );
        expect(
          tester.getTopLeft(_key('writing-body')).dy,
          greaterThan(tester.getTopLeft(_key('writing-title')).dy),
        );
        expect(_key('writing-thanks-to'), findsOneWidget);
        // The founder's line (1 Nov), just above the pinned lines (CV3).
        final note = _key('writing-thanks-profile-note');
        expect(tester.widget<Text>(note).data, l10n.thanksProfileNote);
        expect(
          tester.getTopLeft(note).dy,
          lessThan(tester.getTopLeft(_key('writing-thanks-to')).dy),
        );
        expect(_key('writing-thanks-for'), findsOneWidget);
        expect(_key('writing-to'), findsNothing);
        expect(_key('writing-who'), findsNothing);
        await _tap(tester, _key('writing-add'));
        final shown = {
          for (final e in ComposerExtra.values)
            if (_key('composer-extra-${e.key}').evaluate().isNotEmpty) e.key,
        };
        expect(shown, {'photos'});
      });

      testWidgets('Send asks for To first; To lists Teams then people, not '
          'me; For an open work item, × clears; Send posts create_thanks', (
        tester,
      ) async {
        final fake = await _open(tester, lang, kind: 'thanks');
        final words = s.t('Thank you for the fast fix', 'شكرًا على الإصلاح');
        await tester.enterText(_key('writing-title'), words);
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-post'));
        // Nothing went: To is asked for, on its pill.
        expect(fake.createdThanks, isEmpty);
        expect(_key('composer'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('writing-thanks-to'),
            matching: find.text(l10n.daybookChooseWho),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('writing-thanks-to'));
        expect(_key('thanks-to-sheet'), findsOneWidget);
        expect(_key('thanks-to-team-t-mep'), findsOneWidget);
        expect(
          tester.getTopLeft(_key('thanks-to-team-t-arch')).dy,
          lessThan(tester.getTopLeft(find.text(s.omarName).last).dy),
        );
        expect(
          find.descendant(
            of: _key('thanks-to-sheet'),
            matching: find.text(s.islamName),
          ),
          findsNothing,
        );
        await _tap(tester, find.text(s.omarName).last);
        expect(_key('thanks-to-sheet'), findsNothing);
        expect(
          find.descendant(
            of: _key('writing-thanks-to'),
            matching: find.text(s.omarName),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('writing-thanks-for'));
        expect(_key('thanks-for-sheet'), findsOneWidget);
        await _tap(tester, _key('thanks-for-post-rebar'));
        expect(
          find.descendant(
            of: _key('writing-thanks-for'),
            matching: find.textContaining('KCT-016'),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('writing-thanks-for-clear'));
        expect(composerDraft(tester)?.thanksForId, isNull);
        await _tap(tester, _key('writing-thanks-for'));
        await _tap(tester, _key('thanks-for-post-rebar'));
        await _tap(tester, _key('writing-post'));
        expect(_key('composer'), findsNothing);
        expect(fake.createdThanks, hasLength(1));
        final made = fake.createdThanks.single;
        expect(made.words, words);
        expect(made.toPersonId, DaybookSamples.omar);
        expect(made.toTeamId, isNull);
        expect(made.forId, 'post-rebar');
      });

      testWidgets('a Team', (tester) async {
        final fake = await _open(tester, lang, kind: 'thanks');
        await tester.enterText(_key('writing-title'), 'Great week');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-thanks-to'));
        await _tap(tester, _key('thanks-to-team-t-mep'));
        await _tap(tester, _key('writing-post'));
        expect(fake.createdThanks.single.toTeamId, 't-mep');
        expect(fake.createdThanks.single.toPersonId, isNull);
      });

      testWidgets('W6: the words and the details go as one body: the '
          'words, a blank line, then the details', (tester) async {
        final fake = await _open(tester, lang, kind: 'thanks');
        final details = s.t('The pour went well.', 'سار الصب جيدًا.');
        await tester.enterText(_key('writing-title'), 'Great week');
        await tester.enterText(_key('writing-body'), details);
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-thanks-to'));
        await _tap(tester, _key('thanks-to-team-t-mep'));
        await _tap(tester, _key('writing-post'));
        expect(fake.createdThanks.single.words, 'Great week\n\n$details');
      });

      testWidgets('W7: hold Send offers Post later; it sends create_thanks '
          'through schedule_post with its params, nothing now, and '
          'Scheduled lists it', (tester) async {
        final schedule = FakeScheduleRepository();
        final fake = await _open(
          tester,
          lang,
          kind: 'thanks',
          schedule: schedule,
        );
        await tester.enterText(_key('writing-title'), 'Great week');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-thanks-to'));
        await _tap(tester, _key('thanks-to-team-t-mep'));
        final bar = tester.widget<BvWritingToolbar>(
          find.byType(BvWritingToolbar),
        );
        expect(bar.laterReady, isTrue);
        await openPostLater(tester);
        await _tap(tester, _key('later-schedule'));
        final sent = schedule.scheduled.single;
        expect(sent.call, ScheduledCall.thanks);
        expect(sent.params, {
          'p_id': sent.id,
          'p_space': DaybookSamples.space,
          'p_body': 'Great week',
          'p_to_person': null,
          'p_to_team': 't-mep',
          'p_for': null,
          'p_files': <Object>[],
        });
        expect(fake.createdThanks, isEmpty);
        expect(_key('composer'), findsNothing);
        expect(schedule.posts.single.title, 'Great week');
        expect(
          find.descendant(
            of: _key('space-scheduled'),
            matching: find.text(l10n.plCount(1)),
          ),
          findsOneWidget,
        );
      });

      testWidgets('W7: what Scheduled shows is the first line of the words, '
          'cut to what it keeps', (tester) async {
        final schedule = FakeScheduleRepository();
        await _open(tester, lang, kind: 'thanks', schedule: schedule);
        final long = List.filled(60, 'thanks').join(' ');
        await tester.enterText(_key('writing-title'), '$long\nsecond line');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-thanks-to'));
        await _tap(tester, _key('thanks-to-team-t-mep'));
        await openPostLater(tester);
        await _tap(tester, _key('later-schedule'));
        final title = schedule.posts.single.title;
        expect(title.length, lessThanOrEqualTo(ScheduledCall.titleMax));
        expect(long.startsWith(title.substring(0, title.length - 1)), isTrue);
        expect(title, isNot(contains('\n')));
      });

      testWidgets('another kind drops To and For, in one line', (tester) async {
        await _open(tester, lang, kind: 'thanks');
        await tester.enterText(_key('writing-title'), 'Great week');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-thanks-to'));
        await _tap(tester, _key('thanks-to-team-t-mep'));
        await chooseKind(tester, 'note');
        final draft = composerDraft(tester)!;
        expect(draft.title, 'Great week');
        expect(draft.thanksToId, isNull);
        expect(
          find.text(
            l10n.cpRemoved(l10n.thanksTo, kindName(l10n, DaybookKind.note)),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a refusal comes back as the draft, with its plain line', (
        tester,
      ) async {
        final fake = await _open(tester, lang, kind: 'thanks');
        fake.refuseThanksWith = const SpaceException(
          SpaceFailure.badInput,
          'thank someone else',
        );
        await tester.enterText(_key('writing-title'), 'Great week');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-thanks-to'));
        await _tap(tester, find.text(s.omarName).last);
        await _tap(tester, _key('writing-post'));
        await _tap(tester, _key('daybook-draft'));
        expect(find.text(l10n.thanksRefusedSelf), findsOneWidget);
        expect(find.text(l10n.daybookCouldNotSend), findsNothing);
      });
    });

    group('A Viewer may thank (founder, 1 Nov) [$lang]', () {
      testWidgets('the post bar keeps Viewer and Read only, and has Thank '
          'someone with the heart', (tester) async {
        await _open(tester, lang, pass: SpacePass.viewer, write: false);
        expect(find.text(l10n.daybookReadOnly), findsOneWidget);
        expect(_key('post-bar-notepad'), findsNothing);
        expect(_key('post-bar-camera'), findsNothing);
        final thank = _key('post-bar-thank');
        expect(
          find.descendant(of: thank, matching: find.text(l10n.thanksSomeone)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: thank, matching: find.byIcon(BvIcons.thanks)),
          findsOneWidget,
        );
      });

      testWidgets('it opens the composer on Thanks only, whatever was kept: '
          'no #, + Photos only; Send posts create_thanks', (tester) async {
        final fake = await _open(
          tester,
          lang,
          pass: SpacePass.viewer,
          write: false,
        );
        await _tap(tester, _key('post-bar-thank'));
        expect(_key('composer'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('composer-top'),
            matching: find.text(l10n.cpNewThanks),
          ),
          findsOneWidget,
        );
        expect(_key('writing-kind'), findsNothing);
        await _tap(tester, _key('writing-add'));
        final shown = {
          for (final e in ComposerExtra.values)
            if (_key('composer-extra-${e.key}').evaluate().isNotEmpty) e.key,
        };
        expect(shown, {'photos'});
        await _tap(tester, _key('writing-add'));
        await tester.enterText(_key('writing-title'), 'Great week');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-thanks-to'));
        await _tap(tester, find.text(s.omarName).last);
        await _tap(tester, _key('writing-post'));
        expect(fake.createdThanks.single.toPersonId, DaybookSamples.omar);
        expect(_key('composer'), findsNothing);
        expect(_key('post-bar-thank'), findsOneWidget);
      });

      testWidgets('a draft of another kind kept from before opens as a '
          'Thanks', (tester) async {
        await _open(tester, lang, pass: SpacePass.viewer, write: false);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(Navigator).first),
        );
        await container
            .read(daybookDraftProvider(DaybookSamples.space).notifier)
            .put(
              const DaybookPostDraft(
                id: 'kept',
                kind: DaybookKind.workItem,
                title: 'Edge guard',
              ),
            );
        await tester.pumpAndSettle();
        await _tap(tester, _key('daybook-draft'));
        expect(composerDraft(tester)?.kind, DaybookKind.thanks);
        expect(composerDraft(tester)?.title, 'Edge guard');
      });
    });

    group('TG1 a tag on a work item [$lang]', () {
      testWidgets('+ → Tag: the market\'s list in place of the keyboard; '
          'one choice, Safety red; tap again removes', (tester) async {
        await _open(tester, lang);
        await addExtra(tester, 'tag');
        expect(_key('composer-tags'), findsOneWidget);
        expect(find.text(l10n.cpTagPanel), findsOneWidget);
        expect(find.text(l10n.cpTagNote), findsOneWidget);
        expect(
          find.descendant(
            of: _key('tag-option-quality'),
            matching: find.text(_tags[1].nameIn(lang)),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('tag-option-safety'));
        expect(tester.widget<BvChip>(_key('tag-option-safety')).selected, true);
        expect(tester.widget<BvChip>(_key('tag-option-safety')).danger, true);
        final chip = tester.widget<BvFilterChip>(_key('writing-tag-chip'));
        expect(chip.label, _tags[0].nameIn(lang));
        expect(chip.danger, isTrue);
        expect(
          tester.getTopLeft(_key('writing-tag-chip')).dy,
          lessThan(tester.getTopLeft(_key('writing-to')).dy),
        );
        // One choice: another replaces it.
        await _tap(tester, _key('tag-option-quality'));
        expect(composerDraft(tester)?.tag?.id, 'quality');
        expect(
          tester.widget<BvFilterChip>(_key('writing-tag-chip')).danger,
          isFalse,
        );
        await _tap(tester, _key('tag-option-quality'));
        expect(composerDraft(tester)?.tag, isNull);
        expect(_key('writing-tag-chip'), findsNothing);
      });

      testWidgets('the chip\'s × takes it off; Send sends it', (tester) async {
        final fake = await _open(tester, lang);
        await tester.enterText(_key('writing-title'), 'Edge guard');
        await tester.pumpAndSettle();
        await addExtra(tester, 'tag');
        await _tap(tester, _key('tag-option-design'));
        await _tap(tester, _key('writing-tag-chip-clear'));
        expect(composerDraft(tester)?.tag, isNull);
        await addExtra(tester, 'tag');
        await _tap(tester, _key('tag-option-safety'));
        await _tap(tester, _key('writing-who'));
        await _tap(tester, find.text(s.omarName).last);
        await _tap(tester, _key('writing-post'));
        expect(fake.created.single.tagId, 'safety');
      });

      testWidgets('a kind with no tag drops it, in one line', (tester) async {
        await _open(tester, lang);
        await addExtra(tester, 'tag');
        await _tap(tester, _key('tag-option-safety'));
        await chooseKind(tester, 'announcement');
        expect(composerDraft(tester)?.tag, isNull);
        expect(
          find.text(
            l10n.cpRemoved(
              l10n.cpTag,
              kindName(l10n, DaybookKind.announcement),
            ),
          ),
          findsOneWidget,
        );
      });
    });

    group('TG1 Work by tag [$lang]', () {
      DaybookCard tagged() => s.card(
        DaybookPost.fromJson({
          'id': 'post-guard',
          'kind': 'work_item',
          'created_at': _now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'title': s.t('Missing edge guard', 'حاجز الحافة مفقود'),
          'author_id': DaybookSamples.islam,
          'author_name': s.nameOf(DaybookSamples.islam),
          'item': {'status': 'open', 'owner_id': DaybookSamples.omar},
          'tag': {
            'id': 'safety',
            'name': {'en': 'Safety', 'ar': 'السلامة'},
            'danger': true,
          },
        }),
      );

      testWidgets('a tap on a card\'s tag shows only that tag\'s work; × '
          'shows all again', (tester) async {
        await _open(tester, lang, posts: [tagged(), s.rebar()], write: false);
        await scrollToRow(tester, _key('card-tag-post-guard'));
        await _tap(tester, _key('card-tag-post-guard'));
        final chip = tester.widget<BvFilterChip>(_key('tag-filter'));
        expect(chip.label, _tags[0].nameIn(lang));
        expect(find.text(s.rebarTitle), findsNothing);
        await _tap(tester, _key('tag-filter-clear'));
        expect(_key('tag-filter'), findsNothing);
        await scrollToRow(tester, find.text(s.rebarTitle));
        expect(find.text(s.rebarTitle), findsWidgets);
      });
    });

    group('+ → Checklist on a work item [$lang]', () {
      testWidgets('one point a line; Done puts the points on it with their '
          'block; the chip says how many, a tap edits, × takes them off', (
        tester,
      ) async {
        final fake = await _open(tester, lang);
        await tester.enterText(_key('writing-title'), 'Pour check');
        await tester.pumpAndSettle();
        await addExtra(tester, 'checklist');
        expect(_key('composer-lines-sheet'), findsOneWidget);
        await tester.enterText(_key('line-0'), s.t('Formwork', 'القوالب'));
        await _tap(tester, _key('line-add'));
        await tester.enterText(_key('line-1'), s.t('Rebar', 'الحديد'));
        await _tap(tester, _key('lines-done'));
        expect(
          find.descendant(
            of: _key('writing-checklist-chip'),
            matching: find.text(l10n.cpChecklistChip(2)),
          ),
          findsOneWidget,
        );
        var draft = composerDraft(tester)!;
        expect(draft.points.map((p) => p.text), [
          s.t('Formwork', 'القوالب'),
          s.t('Rebar', 'الحديد'),
        ]);
        final block = draft.blocks.singleWhere(
          (b) => b['type'] == PageChecklist.kind,
        );
        expect(block['point_ids'], [for (final p in draft.points) p.id]);
        // A tap edits: the lines come back.
        await _tap(tester, _key('writing-checklist-chip'));
        expect(
          tester.widget<TextField>(_key('line-1')).controller?.text,
          s.t('Rebar', 'الحديد'),
        );
        await tester.enterText(_key('line-1'), '');
        await _tap(tester, _key('lines-done'));
        draft = composerDraft(tester)!;
        expect(draft.points, hasLength(1));
        expect(
          find.descendant(
            of: _key('writing-checklist-chip'),
            matching: find.text(l10n.cpChecklistChip(1)),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('writing-who'));
        await _tap(tester, find.text(s.omarName).last);
        await _tap(tester, _key('writing-post'));
        final made = fake.created.single;
        expect(made.points.map((p) => p.text), [s.t('Formwork', 'القوالب')]);
        expect(
          made.blocks?.where((b) => b['type'] == PageChecklist.kind),
          hasLength(1),
        );
      });

      testWidgets('× takes the points and their block off', (tester) async {
        await _open(tester, lang);
        await addExtra(tester, 'checklist');
        await tester.enterText(_key('line-0'), 'Formwork');
        await _tap(tester, _key('lines-done'));
        await _tap(tester, _key('writing-checklist-chip-clear'));
        final draft = composerDraft(tester)!;
        expect(draft.points, isEmpty);
        expect(
          draft.blocks.where((b) => b['type'] == PageChecklist.kind),
          isEmpty,
        );
        expect(_key('writing-checklist-chip'), findsNothing);
      });
    });
  }
}
