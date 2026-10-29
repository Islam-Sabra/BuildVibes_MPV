// Slice 7, templates and the daily report (review 78, review 79 §1),
// against R2 redrawn (EN 2607:36358, AR 2608:727). The template screens
// have no frames (review 79 §1: built from the sheet, BvListRow and the
// kind icons); the lead checks them here. English and Arabic, at 390 ×
// 844, in the app's fonts.
// Run:
//   flutter test test_screens/slice7_test.dart --update-goldens
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/template.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/template_fakes.dart';
import 'shot.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Saves the app as it is now, at 390 × 844 and twice the pixels, to
/// `docs/screens/slice7/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  debugDisableShadows = false;
  ContextMenuController.removeAny();
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/slice7/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

// R2's evening: the report posted at 17:00.
final _evening = DateTime(2026, 10, 15, 17, 5);

const _report = '00000000-0000-4000-8000-000000000721';
const _sleeves = '00000000-0000-4000-8000-000000000722';
const _paint = '00000000-0000-4000-8000-000000000723';
const _gate = '00000000-0000-4000-8000-000000000724';
const _pour = '00000000-0000-4000-8000-000000000725';
const _gateNote = '00000000-0000-4000-8000-000000000726';
const _mepNote = '00000000-0000-4000-8000-000000000727';
const _crane = '00000000-0000-4000-8000-000000000728';

/// R2's report, as Islam reads Sara's.
DaybookPost _posted(DaybookSamples s) {
  final heading = <String, String>{
    'on_site': s.t('On site', 'في الموقع'),
    'done': s.t('Done today', 'أنجز اليوم'),
    'problems': s.t('Problems', 'المشكلات'),
  };
  DaybookRef checked(String title, int h, int m) => DaybookRef(
    title: title,
    itemStatus: WorkStatus.checked,
    checkedAt: DateTime(2026, 10, 15, h, m),
    checkerName: s.saraName,
    photoPath: 'kct/posts/$title/1.jpg',
  );
  return DaybookPost(
    id: _report,
    kind: DaybookPost.reportKind,
    createdAt: DateTime(2026, 10, 15, 17),
    title: s.t('Thursday 15 October', 'الخميس 15 أكتوبر'),
    authorId: DaybookSamples.sara,
    authorName: s.saraName,
    coverPath: 'kct/posts/report/1.jpg',
    blocks: [
      {'id': 'h1', 'type': 'heading', 'text': heading['on_site']},
      {
        'id': 't1',
        'type': 'text',
        'text': s.t(
          'Steel fixers 12, electricians 6, plumbers 4',
          'حدادو تسليح 12، كهربائيون 6، سباكون 4',
        ),
      },
      {'id': 'h2', 'type': 'heading', 'text': heading['done']},
      {'id': 'r1', 'type': 'item_ref', 'post_id': _sleeves},
      {'id': 'r2', 'type': 'item_ref', 'post_id': _paint},
      {'id': 'r3', 'type': 'item_ref', 'post_id': _gate},
      {'id': 'h3', 'type': 'heading', 'text': heading['problems']},
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
      _sleeves: checked(
        s.t('Sleeves at grid C7', 'الأكمام عند المحور C7'),
        10,
        12,
      ),
      _paint: checked(
        s.t('Paint touch-up, corridor', 'لمسات دهان، الممر'),
        11,
        30,
      ),
      _gate: checked(
        s.t('Gate 3 access cleared', 'فتح مدخل البوابة 3'),
        16,
        20,
      ),
    },
  );
}

FakeTemplateRepository _templates(DaybookSamples s) {
  PostTemplate own(
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
  );
  return FakeTemplateRepository(
      kept: [
        dailyReportTemplate,
        own(
          _pour,
          'checklist',
          s.t('Concrete pour check', 'فحص صب الخرسانة'),
          title: s.t('Pour check, level 3', 'فحص الصب، الدور 3'),
          points: [
            s.t('Formwork oiled', 'تزييت القوالب'),
            s.t('Cover blocks in place', 'فواصل الغطاء في مكانها'),
            s.t('Pump booked', 'حجز المضخة'),
          ],
          day: 13,
        ),
        own(
          _gateNote,
          'announcement',
          s.t('Gate closed', 'إغلاق بوابة'),
          title: s.t('Gate 2 closed for the crane', 'البوابة 2 مغلقة للرافعة'),
          body: s.t(
            'Deliveries use gate 3 until it opens again.',
            'التوريدات من البوابة 3 حتى تُفتح من جديد.',
          ),
        ),
        own(
          _mepNote,
          'announcement',
          s.t('MEP shutdown', 'إيقاف الكهروميكانيك'),
          teamId: 't-mep',
          title: s.t('Power off on level 4', 'فصل الكهرباء في الدور 4'),
          day: 12,
        ),
      ],
    )
    ..checkedByTeam[null] = [
      ReportRef(
        postId: _sleeves,
        title: s.t('Sleeves at grid C7', 'الأكمام عند المحور C7'),
        at: DateTime(2026, 10, 15, 10, 12),
      ),
      ReportRef(
        postId: _paint,
        title: s.t('Paint touch-up, corridor', 'لمسات دهان، الممر'),
        at: DateTime(2026, 10, 15, 11, 30),
      ),
      ReportRef(
        postId: _gate,
        title: s.t('Gate 3 access cleared', 'فتح مدخل البوابة 3'),
        at: DateTime(2026, 10, 15, 16, 20),
      ),
    ]
    ..notesByTeam[null] = [
      ReportRef(
        postId: _crane,
        title: s.t('Crane arrived at gate 2', 'وصلت الرافعة إلى البوابة 2'),
        at: DateTime(2026, 10, 15, 7, 50),
        isNote: true,
      ),
    ];
}

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<DaybookCard> posts = const [],
  DateTime? now,
}) async {
  final s = DaybookSamples(lang);
  await warmSamplePhoto(tester);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(admin: true)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = posts,
    templates: _templates(s),
    now: now ?? _evening,
    overrides: [daybookPhotoProvider.overrideWith((ref, path) => samplePhoto)],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

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

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('R2 the daily report card [$lang]', (tester) async {
      final post = _posted(s);
      await _open(
        tester,
        lang,
        posts: [DaybookCard(post: post, lastActivityAt: post.createdAt)],
      );
      await _snap(tester, 'R2-daily-report', lang);
    });

    // Review 105 Part 1: the Space menu (⋯) is gone; MN1 has no shot.

    testWidgets('the daily report while writing [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, _key('space-header'));
      await _tap(tester, find.text(l10n.dailyReportMenu));
      await tester.enterText(
        _key('report-on-site'),
        s.t(
          'Steel fixers 12, electricians 6, plumbers 4',
          'حدادو تسليح 12، كهربائيون 6، سباكون 4',
        ),
      );
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'R2-writing', lang);
      await tester.drag(_key('report-writing'), const Offset(0, -300));
      await tester.pumpAndSettle();
      await _snap(tester, 'R2-writing-done-today', lang);
    });

    testWidgets('the template picker [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.announcement);
      await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
      await _snap(tester, 'T0-more-template', lang);
      await _tap(tester, find.text(l10n.templateMenu));
      await _snap(tester, 'T1-template-picker', lang);
      await _tap(tester, _key('template-$_gateNote'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'T2-from-template', lang);
    });

    testWidgets('a checklist from a template [$lang]', (tester) async {
      await _open(tester, lang);
      await _write(tester, l10n, DaybookKind.checklist);
      await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
      await _tap(tester, find.text(l10n.templateMenu));
      await _tap(tester, _key('template-$_pour'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'T2-checklist-from-template', lang);
    });

    testWidgets('Save as template [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [s.rebar()],
        now: DaybookSamples.thursday,
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
      await _snap(tester, 'T3-menu-save-as-template', lang);
      await _tap(
        tester,
        find.descendant(
          of: _key('slip-menu'),
          matching: find.text(l10n.templateSave),
        ),
      );
      await _snap(tester, 'T3-name-template', lang);
    });

    testWidgets('Space info › Templates [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, _key('space-header'));
      await tester.scrollUntilVisible(_key('info-templates'), 200);
      await _snap(tester, 'SI1-templates-row', lang);
      await _tap(tester, _key('info-templates'));
      await _snap(tester, 'T4-space-templates', lang);
    });
  }
}
