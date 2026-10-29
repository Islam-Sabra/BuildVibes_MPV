// Slice 7 (review 78 §4–6, review 79 §1 and §5): the daily report, from
// the Space menu to its card (R2) and Share as PDF.
import 'dart:convert';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/template.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_report.dart';
import 'package:buildvibes/features/work/daybook_report_pdf.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/template_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _sleeves = '00000000-0000-4000-8000-000000000711';
const _paint = '00000000-0000-4000-8000-000000000712';
const _mepTray = '00000000-0000-4000-8000-000000000713';
const _note = '00000000-0000-4000-8000-000000000714';
const _report = '00000000-0000-4000-8000-000000000715';
const _hidden = '00000000-0000-4000-8000-000000000716';

final _today = DateTime(2026, 10, 15);

ReportRef _checked(String id, String title, int h, int m) => ReportRef(
  postId: id,
  title: title,
  at: DateTime(2026, 10, 15, h, m),
  ref: 'KCT-0${id.substring(id.length - 2)}',
  ownerName: 'Omar Haddad',
  checkerName: 'Sara Al-Mutairi',
  photoPath: 'kct/posts/$id/1.jpg',
);

FakeTemplateRepository _templates(DaybookSamples s) => FakeTemplateRepository()
  ..checkedByTeam[null] = [
    _checked(
      _sleeves,
      s.t('Sleeves at grid C7', 'الأكمام عند المحور C7'),
      10,
      12,
    ),
    _checked(
      _paint,
      s.t('Paint touch-up, corridor', 'لمسات دهان، الممر'),
      10,
      20,
    ),
  ]
  ..checkedByTeam['t-mep'] = [
    _checked(_mepTray, s.t('Tray earthed', 'تأريض الحامل'), 9, 40),
  ]
  ..notesByTeam[null] = [
    ReportRef(
      postId: _note,
      title: s.t('Crane arrived', 'وصلت الرافعة'),
      at: DateTime(2026, 10, 15, 7, 50),
      isNote: true,
      ownerName: 'Lina Khalil',
    ),
  ];

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  FakeTemplateRepository? templates,
  List<DaybookCard> posts = const [],
  Map<String, Object> stored = const {},
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: pass,
        admin: me == DaybookSamples.islam,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = posts,
    templates: templates ?? _templates(s),
    stored: stored,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(Key(k));

/// Review 105 Part 1: the daily report is in Space info, opened by the
/// Space's name; it opens on Work.
Future<void> _startReport(WidgetTester tester, AppLocalizations l10n) async {
  await _tap(tester, _key('space-header'));
  await _tap(tester, find.text(l10n.dailyReportMenu));
}

/// A posted report, as the server gives it: one of its work items is a
/// Team's the reader can't see, so it isn't in refs.
DaybookPost _posted(DaybookSamples s) => DaybookPost(
  id: _report,
  kind: DaybookPost.reportKind,
  createdAt: DateTime(2026, 10, 15, 17),
  title: s.t('Thursday 15 October', 'الخميس 15 أكتوبر'),
  authorId: DaybookSamples.sara,
  authorName: s.saraName,
  blocks: [
    {'id': 'h1', 'type': 'heading', 'text': s.t('On site', 'في الموقع')},
    {
      'id': 't1',
      'type': 'text',
      'text': s.t(
        'Steel fixers 12, electricians 6, plumbers 4',
        'حدادو تسليح 12، كهربائيون 6، سباكون 4',
      ),
    },
    {'id': 'h2', 'type': 'heading', 'text': s.t('Done today', 'أنجز اليوم')},
    {'id': 'r1', 'type': 'item_ref', 'post_id': _sleeves},
    {'id': 'r2', 'type': 'item_ref', 'post_id': _hidden},
    {'id': 'r3', 'type': 'item_ref', 'post_id': _paint},
    {'id': 'h3', 'type': 'heading', 'text': s.t('Problems', 'المشكلات')},
    {
      'id': 't2',
      'type': 'text',
      'text': s.t(
        'Pump booked only until 2 pm tomorrow',
        'المضخة محجوزة حتى 2 ظهرًا غدًا فقط',
      ),
    },
  ],
  refs: {
    _sleeves: DaybookRef(
      title: s.t('Sleeves at grid C7', 'الأكمام عند المحور C7'),
      itemStatus: WorkStatus.checked,
      checkedAt: DateTime(2026, 10, 15, 10, 12),
      checkerName: s.saraName,
      photoPath: 'kct/posts/sleeves/1.jpg',
    ),
    _paint: DaybookRef(
      title: s.t('Paint touch-up, corridor', 'لمسات دهان، الممر'),
      itemStatus: WorkStatus.checked,
      checkedAt: DateTime(2026, 10, 15, 11, 30),
      checkerName: s.saraName,
    ),
  },
);

void main() {
  test('the page a report posts: headings in words, its lines, the work '
      'checked today less what was taken out, the problems', () {
    final l10n = _l10n('en');
    final d = DaybookPostDraft(
      id: 'r',
      kind: DaybookKind.report,
      title: 'Thursday 15 October',
      onSite: 'Steel fixers 12',
      problems: '  ',
      refs: [
        _checked(_sleeves, 'Sleeves', 10, 12),
        _checked(_paint, 'Paint', 10, 20),
      ],
      refsOut: const [_paint],
      notes: [
        ReportRef(
          postId: _note,
          title: 'Crane',
          at: DateTime(2026, 10, 15, 8),
          isNote: true,
        ),
      ],
    );
    final page = reportPage(l10n, d);
    expect(
      [for (final b in page) b['type']],
      ['heading', 'text', 'item_ref', 'heading', 'item_ref', 'heading'],
    );
    expect(page[0]['text'], 'On site');
    expect(page[1]['text'], 'Steel fixers 12');
    expect(page[2]['post_id'], _note);
    expect(page[4]['post_id'], _sleeves);
    expect(page[5]['text'], 'Problems');
    // The writer's typed numbers are words: nothing is added up (Q5).
    expect(jsonEncode(page), isNot(contains('total')));
  });

  test('a report is kept once something is written, not for its day and '
      'checked work alone', () {
    final d = DaybookPostDraft(
      id: 'r',
      kind: DaybookKind.report,
      title: 'Thursday',
      reportDay: _today,
      refs: [_checked(_sleeves, 'Sleeves', 10, 12)],
    );
    expect(d.isEmpty, isTrue);
    expect(d.copyWith(onSite: 'Crane on site').isEmpty, isFalse);
    expect(d.copyWith(refsOut: const [_sleeves]).isEmpty, isFalse);
    final back = DaybookPostDraft.fromJson(
      jsonDecode(
            jsonEncode(
              d.copyWith(onSite: 'x', refsOut: const [_sleeves]).toJson(),
            ),
          )
          as Map<String, dynamic>,
    );
    expect(back.kind, DaybookKind.report);
    expect(back.reportDay, _today);
    expect(back.onSite, 'x');
    expect(back.refsIn, isEmpty);
    expect(back.refs.single.postId, _sleeves);
  });

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);
    final words = DaybookWords(l10n, lang, use24: false);

    testWidgets('Daily report is in Space info for a Lead and Crew, not '
        'a Viewer [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, _key('space-header'));
      expect(find.text(l10n.dailyReportMenu), findsOneWidget);
    });

    testWidgets('a Viewer has no Daily report [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        me: DaybookSamples.mona,
        pass: SpacePass.viewer,
      );
      await _tap(tester, _key('space-header'));
      expect(find.text(l10n.dailyReportMenu), findsNothing);
    });

    testWidgets('the report writes itself: the day, To Everyone, Done today '
        'from what was checked, the day\'s notes to add; ✕ takes one out; '
        'Post sends it from the built-in Daily report [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _startReport(tester, l10n);
      expect(_key('report-writing'), findsOneWidget);
      expect(find.text(words.compactDate(_today)), findsOneWidget);
      expect(
        find.text(l10n.daybookToAudience(l10n.daybookEveryone)),
        findsOneWidget,
      );
      expect(find.text(l10n.daybookKindReport), findsOneWidget);
      // No words box: the report's own sections.
      expect(_key('writing-body'), findsNothing);
      for (final t in [
        l10n.dailyReportOnSite,
        l10n.dailyReportDoneToday,
        l10n.dailyReportProblems,
      ]) {
        expect(find.text(t), findsOneWidget);
      }
      expect(_key('report-done-$_sleeves'), findsOneWidget);
      expect(_key('report-done-$_paint'), findsOneWidget);
      // An Everyone report never lists a Team's work.
      expect(_key('report-done-$_mepTray'), findsNothing);
      expect(
        find.descendant(
          of: _key('report-done-$_sleeves'),
          matching: find.byType(BvInkStamp),
        ),
        findsOneWidget,
      );
      // No "From:" line for the built-in.
      expect(_key('writing-template'), findsNothing);

      await tester.enterText(
        _key('report-on-site'),
        s.t('Steel fixers 12, electricians 6', 'حدادو تسليح 12، كهربائيون 6'),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('report-add-note'));
      expect(_key('report-note-$_note'), findsOneWidget);
      await _tap(
        tester,
        find.descendant(
          of: _key('report-done-$_paint'),
          matching: _key('report-line-remove'),
        ),
      );
      expect(_key('report-done-$_paint'), findsNothing);
      await tester.enterText(
        _key('report-problems'),
        s.t('Pump booked until 2 pm', 'المضخة محجوزة حتى 2'),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-post'));

      final sent = app.daybook.createdPosts.single;
      expect(sent.kind, DaybookPost.reportKind);
      expect(sent.title, words.compactDate(_today));
      expect(sent.templateId, PostTemplate.dailyReportId);
      expect(sent.teamId, isNull);
      final page = sent.blocks!;
      expect(
        [
          for (final b in page)
            if (b['type'] == 'item_ref') b['post_id'],
        ],
        [_note, _sleeves],
      );
      expect(page.first['text'], l10n.dailyReportOnSite);
      expect(sent.toParams()['p_body'], isNull);
    });

    testWidgets('To a Team: Done today is that Team\'s and the Everyone '
        'work, read again [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _startReport(tester, l10n);
      expect(app.templates.calls, contains('fill everyone'));
      await _tap(
        tester,
        find.descendant(
          of: _key('writing-to'),
          matching: find.text(l10n.daybookToAudience(l10n.daybookEveryone)),
        ),
      );
      await _tap(
        tester,
        find.descendant(
          of: _key('writing-to-menu'),
          matching: find.text(s.t('MEP', 'الكهروميكانيك')),
        ),
      );
      expect(app.templates.calls, contains('fill t-mep'));
      expect(_key('report-done-$_mepTray'), findsOneWidget);
    });

    testWidgets('today\'s own draft opens again from the menu, as the Draft '
        '[$lang]', (tester) async {
      final draft = DaybookPostDraft(
        id: 'draft-report',
        kind: DaybookKind.report,
        title: words.compactDate(_today),
        reportDay: _today,
        onSite: 'Crane on site',
        templateId: PostTemplate.dailyReportId,
      );
      await _open(
        tester,
        lang,
        stored: {
          'daybook_draft:${DaybookSamples.islam}:${DaybookSamples.space}':
              jsonEncode(draft.toJson()),
        },
      );
      await _startReport(tester, l10n);
      expect(find.text('Crane on site'), findsOneWidget);
      expect(find.text(l10n.daybookDraft), findsOneWidget);
    });

    testWidgets('yesterday\'s draft is put away: a report is for today '
        '[$lang]', (tester) async {
      final draft = DaybookPostDraft(
        id: 'draft-old',
        kind: DaybookKind.report,
        title: 'Wednesday 14 October',
        reportDay: DateTime(2026, 10, 14),
        onSite: 'Yesterday',
      );
      await _open(
        tester,
        lang,
        stored: {
          'daybook_draft:${DaybookSamples.islam}:${DaybookSamples.space}':
              jsonEncode(draft.toJson()),
        },
      );
      await _startReport(tester, l10n);
      expect(find.text(l10n.dailyReportTodayOnly), findsOneWidget);
      expect(find.text('Yesterday'), findsNothing);
      expect(find.text(words.compactDate(_today)), findsOneWidget);
    });

    testWidgets('a card of another kind being written opens instead [$lang]', (
      tester,
    ) async {
      final draft = DaybookPostDraft(
        id: 'draft-item',
        title: s.cableTraysTitle,
      );
      await _open(
        tester,
        lang,
        stored: {
          'daybook_draft:${DaybookSamples.islam}:${DaybookSamples.space}':
              jsonEncode(draft.toJson()),
        },
      );
      await _startReport(tester, l10n);
      expect(find.text(l10n.dailyReportDraftFirst), findsOneWidget);
      expect(find.text(s.cableTraysTitle), findsOneWidget);
      expect(_key('report-writing'), findsNothing);
    });

    testWidgets('R2: the report\'s card: its labels, each checked line with '
        'its time and stamp, a line the reader can\'t see left out, the '
        'photos, Share as PDF [$lang]', (tester) async {
      final post = _posted(s);
      final app = await _open(
        tester,
        lang,
        posts: [DaybookCard(post: post, lastActivityAt: post.createdAt)],
      );
      final card = _key('report-$_report');
      expect(card, findsOneWidget);
      expect(find.text(l10n.daybookKindReportWord), findsOneWidget);
      expect(_key('report-ref-$_sleeves'), findsOneWidget);
      expect(_key('report-ref-$_paint'), findsOneWidget);
      expect(_key('report-ref-$_hidden'), findsNothing);
      expect(
        find.descendant(
          of: _key('report-ref-$_sleeves'),
          matching: find.text(words.time.clock(DateTime(2026, 10, 15, 10, 12))),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(BvInkStamp)),
        findsNWidgets(2),
      );
      expect(_key('report-photos'), findsOneWidget);
      // No stamp of its own and no Sign as done: it is no work item.
      expect(find.text(l10n.daybookSignAsDone), findsNothing);

      await _tap(tester, _key('report-share-pdf'));
      expect(app.sharedFiles.single, endsWith('.pdf'));
      expect(app.sharedFiles.single, contains(post.title));
    });

    testWidgets('the PDF is made, with both fonts, in the reader\'s '
        'direction [$lang]', (tester) async {
      await tester.runAsync(() async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final fonts = await container.read(reportFontsProvider.future);
        final pdf = ReportPdf.of(
          l10n,
          words,
          spaceName: s.spaceName,
          post: _posted(s),
        );
        expect(pdf.rtl, lang == 'ar');
        // The hidden Team item isn't in it; the two checked lines are.
        expect(
          [
            for (final sec in pdf.sections)
              for (final l in sec.lines)
                if (l.checked) l.text,
          ],
          [
            s.t('Sleeves at grid C7', 'الأكمام عند المحور C7'),
            s.t('Paint touch-up, corridor', 'لمسات دهان، الممر'),
          ],
        );
        final bytes = await pdf.bytes(fonts);
        expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
      });
    });
  }
}
