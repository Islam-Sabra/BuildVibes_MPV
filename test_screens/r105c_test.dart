// Review 105C: the shots it adds, in English and Arabic at 390 × 844 in the
// app's fonts. P1: the Place picker, a name typed that the Space hasn't
// got ("Add place …"). P2: a card with its site tag. P3: Work filtered by
// a place (the chip). BA1: before / after on a Checked item. SP4: the +
// sheet inside a work item. SP3: a table of tasks, one row ticked. SP9:
// the removal sheet. Run:
//   flutter test test_screens/r105c_test.dart --update-goldens
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/page_fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r105c/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r105c/${name}_$lang.png'),
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

const _l3 = SpacePlace(id: 'place-l3', name: 'L3 · Grid B4');
const _l2 = SpacePlace(id: 'place-l2', name: 'L2 · Grid C7');
const _gate = SpacePlace(id: 'place-gate', name: 'Gate 2');

const _post = '00000000-0000-4000-8000-000000000601';
const _table = '00000000-0000-4000-8000-0000000006b1';

/// The Space's Work, as [me] with [pass], its places listed.
Future<void> _openWork(
  WidgetTester tester,
  String lang,
  List<DaybookCard> posts, {
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  FakePageRepository? pages,
}) async {
  final s = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: pass,
        admin: me == DaybookSamples.islam,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = posts
      ..placesBySpace[DaybookSamples.space] = [_l3, _gate, _l2],
    postPages: pages,
    now: DaybookSamples.thursday,
    overrides: [daybookPhotoProvider.overrideWith((ref, path) => samplePhoto)],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    /// A work item for Omar at [place], raised at [h]:00 on Thursday.
    DaybookCard tagged(String id, String title, SpacePlace? place, int h) =>
        s.card(
          s.item(
            id: id,
            at: DateTime(2026, 10, 15, h),
            title: title,
            authorId: DaybookSamples.islam,
            ownerId: DaybookSamples.omar,
            placeId: place?.id,
            place: place?.name,
          ),
        );

    final rebar = tagged(
      'post-a',
      s.t('Rebar spacing, slab edge', 'تباعد حديد التسليح عند حافة البلاطة'),
      _l3,
      10,
    );
    final formwork = tagged(
      'post-b',
      s.t('Formwork check', 'فحص القوالب'),
      _l2,
      9,
    );
    final pour = tagged(
      'post-c',
      s.t('Pour sequence', 'تسلسل الصب'),
      _l3,
      8,
    );

    testWidgets('P1 the Place picker: "Add place …" [$lang]', (tester) async {
      await _openWork(tester, lang, [rebar]);
      await _tap(tester, _key('post-bar-notepad'));
      await _tap(tester, _key('writing-place-row'));
      await tester.enterText(
        find.descendant(
          of: _key('place-search'),
          matching: find.byType(TextField),
        ),
        s.t('Roof', 'السطح'),
      );
      await tester.pumpAndSettle();
      await _snap(tester, 'P1-place-picker', lang);
    });

    testWidgets('P2 a card with its site tag [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await _openWork(tester, lang, [rebar]);
      await _snap(tester, 'P2-site-tag', lang);
    });

    testWidgets('P3 Work filtered by a place: the chip [$lang]', (
      tester,
    ) async {
      await _openWork(tester, lang, [rebar, formwork, pour]);
      // The tag's words: the tag is as wide as the card, its chip at the
      // start.
      await _tap(
        tester,
        find.descendant(
          of: _key('site-tag-post-a'),
          matching: find.text(_l3.name),
        ),
      );
      await _snap(tester, 'P3-place-filter', lang);
    });

    testWidgets('BA1 before / after on a Checked item [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      final sleeves = s.card(
        s.item(
          id: 'post-ba',
          at: DateTime(2026, 10, 15, 8, 10),
          title: s.sleeves,
          authorId: DaybookSamples.islam,
          ownerId: DaybookSamples.omar,
          status: WorkStatus.checked,
          cover: '${DaybookSamples.space}/post-ba/before.jpg',
          placeId: _l3.id,
          place: _l3.name,
        ),
        events: [
          s.event(
            'ev-ba-done',
            DaybookEventKind.done,
            DateTime(2026, 10, 15, 9, 56),
            DaybookSamples.omar,
            photos: const [
              WorkPhoto(path: '${DaybookSamples.space}/ba/after.jpg'),
            ],
          ),
          s.event(
            'ev-ba-checked',
            DaybookEventKind.checked,
            DateTime(2026, 10, 15, 10, 20),
            DaybookSamples.islam,
          ),
        ],
      );
      await _openWork(tester, lang, [sleeves]);
      await tester.ensureVisible(_key('before-after'));
      await tester.pumpAndSettle();
      await _snap(tester, 'BA1-before-after', lang);
    });

    /// "Snags, level 1 lobby", Islam's, for Omar, with a page.
    DaybookPost snags() => DaybookPost(
      id: _post,
      kind: DaybookPost.workItemKind,
      createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 2)),
      title: s.t('Snags, level 1 lobby', 'ملاحظات التشطيب، ردهة الطابق 1'),
      authorId: DaybookSamples.islam,
      authorName: s.islamName,
      item: DaybookItem(
        status: WorkStatus.open,
        ownerId: DaybookSamples.omar,
        ownerName: s.omarName,
        ref: 'KCT-021',
      ),
      hasPage: true,
    );

    testWidgets('SP4 the + sheet inside a work item [$lang]', (tester) async {
      final post = snags();
      final pages = FakePageRepository()
        ..pages[_post] = PostPage(post: post, version: 2);
      await _openWork(
        tester,
        lang,
        [DaybookCard(post: post, lastActivityAt: post.createdAt)],
        pages: pages,
      );
      await _tap(
        tester,
        find.descendant(
          of: _key('daybook-card-$_post'),
          matching: find.byType(BvSlipTitle),
        ),
      );
      await _tap(tester, _key('page-edit'));
      await _tap(tester, _key('page-add-button'));
      await _snap(tester, 'SP4-add-sheet', lang);
    });

    testWidgets('SP3 a table of tasks, one row ticked [$lang]', (
      tester,
    ) async {
      final post = snags();
      final pages = FakePageRepository()
        ..pages[_post] = PostPage(
          post: post,
          version: 2,
          blocks: [
            PageTaskTable(_table, [
              TaskRow(
                '00000000-0000-4000-8000-0000000006c1',
                s.t('Cracked tile at the stair', 'بلاطة مكسورة عند الدرج'),
                note: s.t('2 tiles', 'بلاطتان'),
                ticked: true,
              ),
              TaskRow(
                '00000000-0000-4000-8000-0000000006c2',
                s.t('Grout gap at the lift door', 'فراغ الترويب عند باب المصعد'),
                note: s.t('Grey grout', 'ترويب رمادي'),
              ),
              TaskRow(
                '00000000-0000-4000-8000-0000000006c3',
                s.t('Skirting loose, grid A3', 'وزرة مفكوكة، محور A3'),
              ),
            ]),
          ],
        );
      await _openWork(
        tester,
        lang,
        [
          DaybookCard(
            post: post,
            lastActivityAt: post.createdAt,
            need: DaybookNeed.toSign,
          ),
        ],
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        pages: pages,
      );
      await _snap(tester, 'SP3-task-table', lang);
    });

    testWidgets('SP9 the removal sheet [$lang]', (tester) async {
      final spaces = FakeSpaceRepository(now: DaybookSamples.thursday)
        ..details[DaybookSamples.space] = s.detail()
        ..spacePeople[DaybookSamples.space] = s.people()
        ..openWorkBy[DaybookSamples.omar] = [
          OpenWorkItem(
            id: 'item-022',
            ref: 'KCT-022',
            title: s.t(
              'Sleeves at grid D2 before the pour',
              'جلبات عند المحور D2 قبل الصب',
            ),
            makerId: DaybookSamples.sara,
            makerName: s.saraName,
            makerMayOwn: true,
          ),
          OpenWorkItem(
            id: 'item-025',
            ref: 'KCT-025',
            title: s.t('Test the fire pump', 'اختبار مضخة الحريق'),
            makerId: DaybookSamples.mona,
            makerName: s.monaName,
          ),
        ];
      await pumpApp(
        tester,
        language: lang,
        spaces: spaces,
        now: DaybookSamples.thursday,
      );
      GoRouter.of(tester.element(find.byType(Navigator).first)).push(
        '/spaces/${DaybookSamples.space}/members/${DaybookSamples.omar}',
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('member-remove'));
      await _snap(tester, 'SP9-removal-sheet', lang);
    });
  }
}
