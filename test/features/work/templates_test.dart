// Slice 7 (review 78 §1–3, review 79 §1): starting from a template, Save
// as template, and Space info › Templates.
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/template.dart';
import 'package:buildvibes/features/spaces/space_templates_screen.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_templates.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/template_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _pour = '00000000-0000-4000-8000-000000000701';
const _gate = '00000000-0000-4000-8000-000000000702';
const _mepNote = '00000000-0000-4000-8000-000000000703';
const _sleeves = '00000000-0000-4000-8000-000000000704';

PostTemplate _template(
  String id,
  String kind,
  String name, {
  String? teamId,
  String? title,
  String? body,
  List<String> points = const [],
  int day = 14,
}) => PostTemplate(
  id: id,
  kind: kind,
  name: name,
  teamId: teamId,
  title: title,
  body: body,
  points: points,
  createdAt: DateTime(2026, 10, day),
  blocks: const [
    {
      'id': '00000000-0000-4000-8000-0000000007b1',
      'type': 'text',
      'text': 'Check the formwork first.',
    },
  ],
);

FakeTemplateRepository _templates() => FakeTemplateRepository(
  kept: [
    dailyReportTemplate,
    _template(
      _pour,
      'checklist',
      'Concrete pour check',
      title: 'Pour check, level 3',
      points: ['Formwork oiled', 'Cover blocks in place'],
    ),
    _template(
      _gate,
      'announcement',
      'Gate closed',
      title: 'Gate 2 closed',
      day: 13,
    ),
    _template(
      _mepNote,
      'announcement',
      'MEP shutdown',
      teamId: 't-mep',
      title: 'Power off on level 4',
      day: 12,
    ),
    _template(
      _sleeves,
      'work_item',
      'Sleeves check',
      title: 'Sleeves before the pour',
      points: ['Sized as the drawing'],
    ),
  ],
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  bool admin = true,
  FakeTemplateRepository? templates,
  List<DaybookCard> posts = const [],
  String path = '/spaces/${DaybookSamples.space}',
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: pass, admin: admin)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = posts,
    templates: templates ?? _templates(),
    now: DaybookSamples.thursday,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
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

Future<void> _write(
  WidgetTester tester,
  AppLocalizations l10n,
  DaybookKind kind,
) async {
  await _tap(tester, _key('post-bar-notepad'));
  await _tap(tester, _key('writing-kind-chip'));
  await _tap(
    tester,
    find.descendant(
      of: _key('writing-kind-menu'),
      matching: find.text(kindName(l10n, kind)),
    ),
  );
}

Future<void> _more(WidgetTester tester, AppLocalizations l10n) =>
    _tap(tester, find.bySemanticsLabel(l10n.daybookMore));

void main() {
  test('only the Everyone templates of the kind, unless the card has an '
      'audience; with a Team chosen, that Team\'s and the Everyone ones', () {
    final all = _templates().kept;
    List<String> ids(DaybookKind k, {String? team}) => [
      for (final t in templatesFor(
        all,
        k,
        teamId: team,
        chosenTeam: team != null,
      ))
        t.id,
    ];
    expect(ids(DaybookKind.checklist), [_pour]);
    expect(ids(DaybookKind.announcement), [_gate, _mepNote]);
    expect(ids(DaybookKind.announcement, team: 't-site'), [_gate]);
    expect(ids(DaybookKind.announcement, team: 't-mep'), [_gate, _mepNote]);
    expect(ids(DaybookKind.note), isEmpty);
    expect(ids(DaybookKind.report), [PostTemplate.dailyReportId]);
  });

  test('a built-in\'s headings come in the reader\'s words, under new ids', () {
    final l10n = _l10n('ar');
    final page = templatePage(l10n, dailyReportTemplate);
    expect(
      [for (final b in page) b['text']],
      [
        l10n.dailyReportOnSite,
        l10n.dailyReportDoneToday,
        l10n.dailyReportProblems,
      ],
    );
    expect(page.every((b) => !b.containsKey('key')), isTrue);
    expect(
      {
        for (final b in page) b['id'],
      }.intersection({for (final b in dailyReportTemplate.blocks) b['id']}),
      isEmpty,
    );
  });

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('a checklist from a template: title, words, points and page; '
        '"From:" with ✕ [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.checklist);
      await _more(tester, l10n);
      await _tap(tester, find.text(l10n.templateMenu));
      final picker = _key('template-picker');
      expect(picker, findsOneWidget);
      // Only this kind's.
      expect(_key('template-$_pour'), findsOneWidget);
      expect(_key('template-$_gate'), findsNothing);
      expect(
        find.descendant(of: picker, matching: find.text(l10n.templateSpaceOwn)),
        findsOneWidget,
      );
      // A Space's own says who it is for; no count, no date.
      expect(
        find.descendant(
          of: _key('template-$_pour'),
          matching: find.text(l10n.daybookEveryone),
        ),
        findsOneWidget,
      );
      await _tap(tester, _key('template-$_pour'));
      expect(find.text('Pour check, level 3'), findsOneWidget);
      expect(find.text('Formwork oiled'), findsOneWidget);
      expect(find.text('Cover blocks in place'), findsOneWidget);
      final from = _key('writing-template');
      expect(
        find.descendant(
          of: from,
          matching: find.text(
            l10n.templateFrom(inOwnDirection('Concrete pour check')),
          ),
        ),
        findsOneWidget,
      );
      await _tap(tester, _key('writing-who'));
      await _tap(
        tester,
        find.descendant(
          of: find.byType(BvGiveToPicker),
          matching: find.text(s.omarName),
        ),
      );
      await _tap(tester, find.byKey(const Key('people-done')));
      await _tap(tester, _key('writing-post'));
      final sent = app.daybook.createdPosts.single;
      expect(sent.kind, DaybookPost.checklistKind);
      expect(sent.templateId, _pour);
      expect(
        [for (final p in sent.points) p.text],
        ['Formwork oiled', 'Cover blocks in place'],
      );
      final page = sent.toParams()['p_blocks']! as List;
      expect((page.single as Map)['text'], 'Check the formwork first.');
      expect(
        (page.single as Map)['id'],
        isNot('00000000-0000-4000-8000-0000000007b1'),
      );
    });

    testWidgets('✕ on "From:" keeps what was written and drops the template '
        '[$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.announcement);
      await _more(tester, l10n);
      await _tap(tester, find.text(l10n.templateMenu));
      await _tap(tester, _key('template-$_gate'));
      await _tap(
        tester,
        find.descendant(
          of: _key('writing-template'),
          matching: find.byKey(const Key('writing-property-remove')),
        ),
      );
      expect(_key('writing-template'), findsNothing);
      expect(find.text('Gate 2 closed'), findsOneWidget);
      await _tap(tester, _key('writing-post'));
      final sent = app.daybook.createdPosts.single;
      expect(sent.title, 'Gate 2 closed');
      expect(sent.templateId, isNull);
    });

    testWidgets('a Team\'s template sets the audience; with a Team chosen '
        'first, another Team\'s isn\'t offered [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.announcement);
      await _more(tester, l10n);
      await _tap(tester, find.text(l10n.templateMenu));
      expect(
        find.descendant(
          of: _key('template-$_mepNote'),
          matching: find.text(s.t('MEP', 'الكهروميكانيك')),
        ),
        findsOneWidget,
      );
      await _tap(tester, _key('template-$_mepNote'));
      expect(
        find.text(l10n.daybookToAudience(s.t('MEP', 'الكهروميكانيك'))),
        findsOneWidget,
      );
      await _tap(tester, _key('writing-post'));
      final sent = app.daybook.createdPosts.single;
      expect(sent.teamId, 't-mep');
      expect(sent.templateId, _mepNote);
    });

    testWidgets('a work item from a template: its points go with a page that '
        'shows them [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _tap(tester, _key('post-bar-notepad'));
      await _more(tester, l10n);
      await _tap(tester, find.text(l10n.templateMenu));
      await _tap(tester, _key('template-$_sleeves'));
      await _more(tester, l10n);
      await _tap(tester, find.text(l10n.daybookAssign));
      await _tap(
        tester,
        find.descendant(
          of: find.byType(BvGiveToPicker),
          matching: find.text(s.omarName),
        ),
      );
      await _tap(tester, _key('writing-post'));
      final sent = app.daybook.created.single;
      expect(sent.title, 'Sleeves before the pour');
      expect(sent.templateId, _sleeves);
      expect([for (final p in sent.points) p.text], ['Sized as the drawing']);
      final listed = sent.blocks!.last;
      expect(listed['type'], 'checklist_ref');
      expect(listed['point_ids'], [sent.points.single.id]);
    });

    testWidgets('no Template on a kind the Space has none of [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        templates: FakeTemplateRepository(kept: [dailyReportTemplate]),
      );
      await _write(tester, l10n, DaybookKind.checklist);
      await _more(tester, l10n);
      expect(find.text(l10n.templateMenu), findsNothing);
    });

    testWidgets('Save as template: a Lead names it; at the Space\'s 50 it '
        'says so and offers Templates [$lang]', (tester) async {
      final templates = _templates();
      final app = await _open(
        tester,
        lang,
        templates: templates,
        posts: [s.rebar()],
      );
      Future<void> save() async {
        await tester.longPress(
          find
              .descendant(
                of: _key('daybook-card-post-rebar'),
                matching: find.byType(BvSlip),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await _tap(
          tester,
          find.descendant(
            of: _key('slip-menu'),
            matching: find.text(l10n.templateSave),
          ),
        );
      }

      await save();
      expect(_key('template-name-sheet'), findsOneWidget);
      // Prefilled with the post's title.
      expect(find.text(s.rebarTitle), findsWidgets);
      await tester.enterText(_key('template-name'), 'Rebar check');
      await tester.pumpAndSettle();
      await _tap(tester, _key('template-name-save'));
      expect(app.templates.calls.last, 'save post-rebar Rebar check');
      expect(find.text(l10n.templateSaved), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      while (templates.own < PostTemplate.perSpace) {
        templates.kept.add(_template('t${templates.own}', 'work_item', 'More'));
      }
      await save();
      await _tap(tester, _key('template-name-save'));
      expect(_key('templates-full'), findsOneWidget);
      expect(
        find.text(l10n.templateFull(PostTemplate.perSpace)),
        findsOneWidget,
      );
      await _tap(tester, find.text(l10n.templateOpenList));
      expect(find.byType(SpaceTemplatesScreen), findsOneWidget);
    });

    testWidgets('a Crew member has no Save as template [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        admin: false,
        posts: [s.rebar()],
      );
      await tester.longPress(
        find
            .descendant(
              of: _key('daybook-card-post-rebar'),
              matching: find.byType(BvSlip),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.templateSave), findsNothing);
    });

    testWidgets('Space info › Templates: the built-in first and kept, the '
        'Space\'s own after a hairline; Delete asks first [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      // Review 105 Part 1: the Space's name opens Space info.
      await _tap(tester, _key('space-header'));
      await _tap(tester, _key('info-templates'));
      expect(find.byType(SpaceTemplatesScreen), findsOneWidget);
      expect(_key('template-${PostTemplate.dailyReportId}'), findsOneWidget);
      expect(
        _key('template-delete-${PostTemplate.dailyReportId}'),
        findsNothing,
      );
      expect(_key('templates-hairline'), findsOneWidget);
      final first = tester.getTopLeft(
        _key('template-${PostTemplate.dailyReportId}'),
      );
      expect(
        tester.getTopLeft(_key('template-$_pour')).dy,
        greaterThan(first.dy),
      );
      await _tap(tester, _key('template-delete-$_gate'));
      expect(find.text(l10n.templateDeleteAsk('Gate closed')), findsOneWidget);
      await _tap(tester, _key('bv-dialog-confirm'));
      expect(app.templates.calls, ['delete $_gate']);
      expect(_key('template-$_gate'), findsNothing);
    });

    testWidgets('a Crew member has no Templates in Space info [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        admin: false,
      );
      // Review 105 Part 1: the Space's name opens Space info.
      await _tap(tester, _key('space-header'));
      expect(_key('info-templates'), findsNothing);
    });
  }
}
