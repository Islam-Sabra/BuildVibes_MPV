// Review 110: the new screens, in English and Arabic at 390 × 844 in the
// app's fonts. B the Reminder sheet on an announcement (Me only) and a
// refusal's own line; C the picked time alone with ×; CP1–CP5 the
// composer; HV1 the short cards; HV2 See more; TH2 a Thanks card; A the
// share card's Space list loading and failing. Run:
//   flutter test test_screens/r110_test.dart --update-goldens
import 'dart:async';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/composer_steps.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_rows.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/later_fakes.dart';
import '../test/helpers/notebook_page_samples.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r110/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r110/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

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
  DaybookTag(id: 'material', name: {'en': 'Material', 'ar': 'المواد'}),
  DaybookTag(id: 'admin', name: {'en': 'Admin', 'ar': 'إداري'}),
];

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);
    final long = s.t(
      'Membrane torn along the parapet on the north side, about 6 m. Check '
          'the upstand too and lap the new sheet 150 mm over the old one.',
      'الغشاء ممزق على طول الدروة في الجهة الشمالية بطول 6 م تقريبًا. افحص '
          'القائم أيضًا وركّب اللوح الجديد بتراكب 150 مم فوق القديم.',
    );

    DaybookPost terrace() => DaybookPost(
      id: 'post-terrace',
      kind: DaybookPost.workItemKind,
      createdAt: DateTime(2026, 10, 15, 8, 40),
      title: s.t(
        'Replace the damaged waterproofing at the L4 terrace before the '
            'screed',
        'استبدال العزل المائي التالف في تراس الدور 4 قبل اللياسة',
      ),
      body: long,
      authorId: DaybookSamples.islam,
      authorName: s.nameOf(DaybookSamples.islam),
      item: DaybookItem(
        status: WorkStatus.open,
        ownerId: DaybookSamples.omar,
        ownerName: s.nameOf(DaybookSamples.omar),
        ref: 'KCT-031',
      ),
      dueDate: DateTime(2026, 10, 16),
      dueAt: DateTime(2026, 10, 16, 14),
      tableCount: 1,
      tag: const DaybookTag(
        id: 'quality',
        name: {'en': 'Quality', 'ar': 'جودة'},
      ),
      attachments: const [
        DaybookAttachment(name: 'Terrace-detail-D12.pdf'),
        DaybookAttachment(name: 'Membrane-datasheet.pdf'),
      ],
    );

    DaybookPost thanks({bool mine = false}) => DaybookPost.fromJson({
      'id': 'post-thanks',
      'kind': 'thanks',
      'created_at': DateTime(2026, 10, 15, 7, 55).toIso8601String(),
      'title': '',
      'body': s.t(
        'Great work finishing level 3 a day early. Clean and safe all week.',
        'عمل رائع بإنهاء الدور 3 قبل موعده بيوم. نظافة وسلامة طوال الأسبوع.',
      ),
      'author_id': DaybookSamples.islam,
      'author_name': s.nameOf(DaybookSamples.islam),
      'thanks': {
        'to_kind': 'person',
        'to_profile_id': DaybookSamples.omar,
        'to_profile_name': s.omarName,
        'for': {
          'id': 'post-tile',
          'title': s.t('Fix the cracked tile', 'إصلاح البلاطة المكسورة'),
          'ref': 'KCT-016',
        },
        'show_on_profile': false,
        'mine': mine,
      },
    });

    /// The Space as [me] (Islam, Lead, by default).
    Future<TestApp> space(
      WidgetTester tester, {
      List<DaybookCard>? posts,
      String me = DaybookSamples.islam,
      FakeWorkReminderRepository? reminders,
      String? composerKind = 'work_item',
      SpacePass pass = SpacePass.lead,
      List<SpacePlace> places = const [],
    }) async {
      final app = await pumpApp(
        tester,
        language: lang,
        auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
        composerKind: composerKind,
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(pass: pass)
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = posts ?? s.d1()
          ..pointsByPost[DaybookSamples.handoverId] = s.handoverPoints()
          ..tagsBySpace[DaybookSamples.space] = _tags
          ..placesBySpace[DaybookSamples.space] = [...places],
        workReminders: reminders,
        now: _now,
        overrides: [
          pickDueProvider.overrideWithValue(
            (context, {required now, day, at}) async =>
                (day: DateTime(2026, 10, 16), at: DateTime(2026, 10, 16, 14)),
          ),
        ],
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      return app;
    }

    Future<void> swipeRemind(WidgetTester tester, String id) async {
      final card = _key('daybook-card-$id');
      await scrollToRow(tester, card);
      await tester.drag(
        find.descendant(of: card, matching: find.byType(BvSlip)).first,
        Offset(lang == 'ar' ? -160 : 160, 0),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('swipe-remind-$id'));
    }

    testWidgets('B1 Reminder on an announcement: Me only [$lang]', (
      tester,
    ) async {
      await space(
        tester,
        posts: [
          s.card(
            DaybookPost(
              id: 'post-gate',
              kind: DaybookPost.announcementKind,
              createdAt: DateTime(2026, 10, 15, 8),
              title: s.t('Gate 3 closed today', 'البوابة 3 مغلقة اليوم'),
              authorId: DaybookSamples.islam,
              authorName: s.nameOf(DaybookSamples.islam),
            ),
          ),
        ],
      );
      await swipeRemind(tester, 'post-gate');
      await _snap(tester, 'B1-reminder-me-only', lang);
    });

    testWidgets('B2 a refusal says why [$lang]', (tester) async {
      await space(
        tester,
        posts: [s.card(terrace())],
        reminders: FakeWorkReminderRepository()
          ..failure = SpaceFailure.notAllowed
          ..failureMessage = 'not allowed',
      );
      await swipeRemind(tester, 'post-terrace');
      await _tap(tester, _key('reminder-someone'));
      await _tap(tester, _key('reminder-set'));
      await _snap(tester, 'B2-reminder-refused', lang);
    });

    testWidgets('C RM1d a picked time alone, with × [$lang]', (tester) async {
      await space(tester, posts: [s.card(terrace())]);
      await swipeRemind(tester, 'post-terrace');
      await _tap(tester, _key('reminder-someone'));
      await _tap(tester, _key('reminder-pick'));
      await _snap(tester, 'RM1d-picked', lang);
    });

    testWidgets('C RM1d in Post later [$lang]', (tester) async {
      await space(tester);
      await _tap(tester, _key('post-bar-notepad'));
      await tester.enterText(
        _key('writing-title'),
        s.t('Morning brief', 'إحاطة الصباح'),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-who'));
      await _tap(tester, find.text(s.omarName));
      await openPostLater(tester);
      await _tap(tester, _key('later-pick'));
      await _snap(tester, 'RM1d-later-picked', lang);
    });

    Future<void> writeItem(WidgetTester tester) async {
      await _tap(tester, _key('post-bar-notepad'));
      await tester.enterText(
        _key('writing-title'),
        s.t(
          'Fix the cracked tile at the stair',
          'إصلاح البلاطة المكسورة عند الدرج',
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-who'));
      await _tap(tester, find.text(s.omarName));
    }

    testWidgets('CP1 the composer over the whole screen [$lang]', (
      tester,
    ) async {
      await space(tester);
      await writeItem(tester);
      await _snap(tester, 'CP1-composer', lang);
    });

    testWidgets('CP2 # the kinds [$lang]', (tester) async {
      await space(tester);
      await writeItem(tester);
      await _tap(tester, _key('writing-kind'));
      await _snap(tester, 'CP2-kinds', lang);
    });

    testWidgets('CP3 + the extras [$lang]', (tester) async {
      await space(tester);
      await writeItem(tester);
      await _tap(tester, _key('writing-add'));
      await _snap(tester, 'CP3-extras', lang);
    });

    testWidgets('CP4 what was added: a due, a table [$lang]', (tester) async {
      await space(tester);
      await writeItem(tester);
      await addExtra(tester, 'due');
      await addExtra(tester, 'table');
      await tester.enterText(_key('table-cell-0-0'), s.t('Bay', 'الجزء'));
      await tester.enterText(_key('table-cell-0-1'), s.t('Status', 'الحالة'));
      await _tap(tester, _key('table-done'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'CP4-added', lang);
    });

    testWidgets('CP5 hold Send: Post later [$lang]', (tester) async {
      await space(tester);
      await writeItem(tester);
      await tester.longPress(_key('writing-post'));
      await tester.pumpAndSettle();
      await _snap(tester, 'CP5-hold-send', lang);
    });

    testWidgets('HV1 the short cards [$lang]', (tester) async {
      await space(
        tester,
        posts: [s.card(thanks()), s.handover(), s.card(terrace())],
      );
      await _snap(tester, 'HV1-short-cards', lang);
    });

    testWidgets('HV2 See more opens the whole post [$lang]', (tester) async {
      await space(tester, posts: [s.card(terrace())]);
      await scrollToRow(tester, _key('card-see-more-post-terrace'));
      await _tap(tester, _key('card-see-more-post-terrace'));
      await _snap(tester, 'HV2-see-more', lang);
    });

    testWidgets('TH2 a Thanks, for the person thanked [$lang]', (tester) async {
      await space(
        tester,
        posts: [s.card(thanks(mine: true))],
        me: DaybookSamples.omar,
      );
      await _snap(tester, 'TH2-thanks-card', lang);
    });

    testWidgets('TH1 Thanks: To and For [$lang]', (tester) async {
      await space(tester, composerKind: 'thanks');
      await _tap(tester, _key('post-bar-notepad'));
      await tester.enterText(
        _key('writing-title'),
        s.t(
          'Thank you for the fast fix on the stair, before the client visit.',
          'شكرًا على الإصلاح السريع للدرج قبل زيارة العميل.',
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-thanks-to'));
      await _tap(tester, find.text(s.omarName).last);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'TH1-thanks-composer', lang);
    });

    testWidgets('TG1 + → Tag: Safety chosen [$lang]', (tester) async {
      await space(tester);
      await writeItem(tester);
      await addExtra(tester, 'tag');
      await _tap(tester, _key('tag-option-safety'));
      await _snap(tester, 'TG1-tag', lang);
    });

    testWidgets('TG1b Work by tag [$lang]', (tester) async {
      await space(tester, posts: [s.card(terrace()), s.rebar()]);
      await scrollToRow(tester, _key('card-tag-post-terrace'));
      await _tap(tester, _key('card-tag-post-terrace'));
      await _snap(tester, 'TG1b-work-by-tag', lang);
    });

    testWidgets('S5 + → Checklist on a work item [$lang]', (tester) async {
      await space(tester);
      await writeItem(tester);
      await addExtra(tester, 'checklist');
      await tester.enterText(_key('line-0'), s.t('Formwork', 'القوالب'));
      await _tap(tester, _key('line-add'));
      await tester.enterText(_key('line-1'), s.t('Rebar', 'الحديد'));
      await _tap(tester, _key('lines-done'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'S5-checklist-chip', lang);
    });

    testWidgets('ACT an activity: When · Team; + → People [$lang]', (
      tester,
    ) async {
      await space(tester, composerKind: 'activity');
      await _tap(tester, _key('post-bar-notepad'));
      await tester.enterText(
        _key('writing-title'),
        s.t('Concrete pour, level 4', 'صب الخرسانة، الدور 4'),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-add'));
      await _snap(tester, 'ACT-activity-extras', lang);
    });

    testWidgets('V1 a Viewer may thank [$lang]', (tester) async {
      await space(tester, pass: SpacePass.viewer, me: DaybookSamples.omar);
      await _snap(tester, 'V1-viewer-thank', lang);
    });

    testWidgets('W10 the place and the tag on one line: +1 [$lang]', (
      tester,
    ) async {
      final longPlace = SpacePlace(
        id: 'place-long',
        name: s.t(
          'North stair core, between grids C and D, level 4 landing',
          'درج القلب الشمالي بين المحورين C و D، بسطة الدور 4',
        ),
      );
      final post = terrace();
      await space(
        tester,
        places: [longPlace],
        posts: [
          s.card(
            DaybookPost(
              id: post.id,
              kind: post.kind,
              createdAt: post.createdAt,
              title: post.title,
              body: post.body,
              authorId: post.authorId,
              authorName: post.authorName,
              item: post.item,
              placeId: longPlace.id,
              tag: post.tag,
              attachments: post.attachments,
              tableCount: post.tableCount,
            ),
          ),
        ],
      );
      await _snap(tester, 'W10-tags-more', lang);
    });

    Future<void> shareSpace(
      WidgetTester tester,
      FakeSpaceRepository spaces,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        now: NotebookPageSamples.now,
        notebook: NotebookPageSamples(lang).repository(),
        spaces: spaces,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/${NotebookPageSamples.siteA}');
      await tester.pumpAndSettle();
      await tester.longPress(_key('note-entry-pour'));
      await tester.pumpAndSettle();
      await tester.tap(_key('note-status-entry-pour-space'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('W8 the notebook share: Note · Work item [$lang]', (
      tester,
    ) async {
      await shareSpace(
        tester,
        FakeSpaceRepository()
          ..spaces.add(
            SpaceSummary(
              id: DaybookSamples.space,
              name: s.spaceName,
              pass: SpacePass.lead,
              isAdmin: true,
            ),
          )
          ..details[DaybookSamples.space] = s.detail()
          ..spacePeople[DaybookSamples.space] = s.people(),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('share-space-${DaybookSamples.space}'));
      await _snap(tester, 'W8-share-kinds', lang);
    });

    testWidgets('A1 the Space list loading [$lang]', (tester) async {
      await shareSpace(
        tester,
        FakeSpaceRepository()..postableGate = Completer<void>().future,
      );
      await _snap(tester, 'A1-spaces-loading', lang);
      await tester.pump(const Duration(seconds: 16));
    });

    testWidgets('A2 the Space list failing, with its diagnostic [$lang]', (
      tester,
    ) async {
      await shareSpace(
        tester,
        FakeSpaceRepository()
          ..spaces.add(
            SpaceSummary(
              id: DaybookSamples.space,
              name: s.spaceName,
              pass: SpacePass.lead,
              isAdmin: true,
            ),
          )
          // Review 112: the list is one call; it fails.
          ..spacesError = TypeError(),
      );
      await tester.pumpAndSettle();
      await _snap(tester, 'A2-spaces-error', lang);
    });
  }
}
