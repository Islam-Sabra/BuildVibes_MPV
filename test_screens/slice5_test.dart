// Slice 5, opening a post in place (review 76), against Figma N1
// (2537:34046), N2 (2537:34235), N3 (2537:34497) and N4 (2537:34853). No
// Arabic frames: the Arabic shots are the English frames mirrored, for the
// lead to check.
// Run:
//   flutter test test_screens/slice5_test.dart --update-goldens
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/activity_repository.dart';
import 'package:buildvibes/data/repositories/chat_repository.dart';
import 'package:buildvibes/data/repositories/daybook_live.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/page_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/activity_fakes.dart';
import '../test/helpers/chat_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/page_fakes.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/work_fakes.dart';
import 'shot.dart';

const _folder = 'slice5';

const _post = '00000000-0000-4000-8000-000000000501';
const _text = '00000000-0000-4000-8000-0000000000b1';
const _toggle = '00000000-0000-4000-8000-0000000000b2';
const _inside = '00000000-0000-4000-8000-0000000000b3';
const _list = '00000000-0000-4000-8000-0000000000b4';
const _table = '00000000-0000-4000-8000-0000000000b5';
const _under1 = '00000000-0000-4000-8000-0000000000b6';
const _under2 = '00000000-0000-4000-8000-0000000000b7';
const _sized = '00000000-0000-4000-8000-0000000000c1';
const _photoPoint = '00000000-0000-4000-8000-0000000000c2';
const _core = '00000000-0000-4000-8000-0000000000d1';
const _collars = '00000000-0000-4000-8000-0000000000d2';

DaybookPost _item(DaybookSamples s) => DaybookPost(
  id: _post,
  kind: DaybookPost.workItemKind,
  createdAt: DateTime(2026, 10, 15, 8, 14),
  title: s.t(
    'Sleeves at grid C7 before the pour',
    'الأكمام عند المحور C7 قبل الصب',
  ),
  authorId: DaybookSamples.islam,
  authorName: s.islamName,
  place: s.t('Level 2, grid C7', 'الدور 2، المحور C7'),
  dueDate: DateTime(2026, 10, 15),
  item: DaybookItem(
    status: WorkStatus.open,
    ownerId: DaybookSamples.omar,
    ownerName: s.omarName,
    ref: 'KCT-021',
  ),
  pointsTotal: 2,
  hasPage: true,
);

/// N1 as drawn.
PostPage _page(DaybookSamples s) => PostPage(
  post: _item(s),
  version: 3,
  blocks: [
    PageText(
      _text,
      s.t(
        'Fix them before Thursday’s pour. Check the sizes against the '
            'drawing and send a photo of each.',
        'ثبّتها قبل صب الخميس. طابق المقاسات مع المخطط وأرسل صورة لكل كم.',
      ),
    ),
    PageToggle(_toggle, s.t('Why the sizes matter', 'لماذا تهم المقاسات'), [
      PageText(
        _inside,
        s.t(
          'The fire rating needs the right sleeve.',
          'مقاومة الحريق تحتاج الكم الصحيح.',
        ),
      ),
    ]),
    const PageChecklist(_list, [_sized, _photoPoint]),
    PageTable(_table, [
      [s.t('Grid', 'المحور'), s.t('Size', 'المقاس'), s.t('Qty', 'العدد')],
      const ['C7', '100 mm', '4'],
      const ['C8', '150 mm', '2'],
    ]),
    const PageChildItem(_under1, _core),
    const PageChildItem(_under2, _collars),
  ],
  points: [
    DaybookPoint(
      id: _sized,
      text: s.t('Sleeves sized as the drawing', 'الأكمام بمقاس المخطط'),
    ),
    DaybookPoint(
      id: _photoPoint,
      text: s.t('Photo of each sleeve', 'صورة لكل كم'),
    ),
  ],
  under: [
    PageUnder(
      id: _core,
      title: s.t('Core the slab at C8', 'ثقب البلاطة عند C8'),
      status: WorkStatus.checked,
      ownerId: DaybookSamples.sara,
      ownerName: s.saraName,
    ),
    PageUnder(
      id: _collars,
      title: s.t('Fire collars at C7', 'أطواق الحريق عند C7'),
      ownerId: DaybookSamples.omar,
      ownerName: s.omarName,
    ),
  ],
);

Future<List<Override>> _overrides(
  DaybookSamples s, {
  String me = DaybookSamples.islam,
}) async {
  // test_screens/ is a test folder the analyzer doesn't know.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final page = _page(s);
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    spaceRepositoryProvider.overrideWithValue(
      FakeSpaceRepository()
        ..details[DaybookSamples.space] = s.detail(
          pass: me == DaybookSamples.islam ? SpacePass.lead : SpacePass.crew,
          admin: me == DaybookSamples.islam,
        )
        ..spacePeople[DaybookSamples.space] = s.people(),
    ),
    activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
    chatRepositoryProvider.overrideWithValue(
      FakeChatRepository(now: DaybookSamples.thursday),
    ),
    authUserIdProvider.overrideWithValue(AsyncData(me)),
    clockProvider.overrideWithValue(() => DaybookSamples.thursday),
    workRepositoryProvider.overrideWithValue(FakeWorkRepository()),
    daybookLiveProvider.overrideWithValue(FakeDaybookLive()),
    daybookRepositoryProvider.overrideWithValue(
      FakeDaybookRepository()
        ..posts[DaybookSamples.space] = [
          DaybookCard(post: _item(s), lastActivityAt: page.post.createdAt),
        ]
        ..pointsByPost[_post] = page.points,
    ),
    pageRepositoryProvider.overrideWithValue(
      FakePageRepository()..pages[_post] = page,
    ),
    daybookPhotoProvider.overrideWith((ref, path) => samplePhoto),
  ];
}

Widget _space(BuildContext _) =>
    const SpaceScreen(spaceId: DaybookSamples.space);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _editPage(WidgetTester tester, String lang) async {
  await tester.longPress(
    find
        .descendant(
          of: find.byKey(const Key('daybook-card-$_post')),
          matching: find.byType(BvSlip),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await _tap(tester, find.text(lang == 'ar' ? 'تعديل الصفحة' : 'Edit page'));
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    testWidgets('the card: Open the page › [$lang]', (tester) async {
      await shoot(
        tester,
        'card-open-page',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(s, me: DaybookSamples.omar),
      );
    });

    testWidgets('N1 the page, read [$lang]', (tester) async {
      await shoot(
        tester,
        'N1-page',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(s, me: DaybookSamples.omar),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('card-open-page')));
          await _tap(tester, find.byKey(const Key('page-toggle-$_toggle')));
        },
      );
    });

    testWidgets('N1 the page, at its end [$lang]', (tester) async {
      await shoot(
        tester,
        'N1-page-end',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(s, me: DaybookSamples.omar),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('card-open-page')));
          await tester.drag(
            find.byKey(const Key('page-blocks')),
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('N2 the author edits the page [$lang]', (tester) async {
      await shoot(
        tester,
        'N2-edit',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(s),
        before: (tester) => _editPage(tester, lang),
      );
    });

    testWidgets('N3 / to pick a block [$lang]', (tester) async {
      await shoot(
        tester,
        'N3-add-block',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(s),
        before: (tester) async {
          await _editPage(tester, lang);
          await tester.scrollUntilVisible(
            find.byKey(const Key('page-add-field')),
            200,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('page-editor')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.enterText(
            find.descendant(
              of: find.byKey(const Key('page-add-field')),
              matching: find.byType(EditableText),
            ),
            '/',
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('N4 Turn into [$lang]', (tester) async {
      await shoot(
        tester,
        'N4-turn-into',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(s),
        before: (tester) async {
          await _editPage(tester, lang);
          await _tap(
            tester,
            find.byKey(const Key('page-point-menu-$_photoPoint')),
          );
        },
      );
    });
  }
}
