// Slice 6, walk mode and work items under one (review 77), against Figma
// R1 (2539:34353) and R1b (2539:34396), drawn on v13's card (R1b and N5
// still have the old hour spine). No Arabic frames: the Arabic shots are
// mirrored, for the lead to check.
// Run:
//   flutter test test_screens/slice6_test.dart --update-goldens
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/activity_repository.dart';
import 'package:buildvibes/data/repositories/chat_repository.dart';
import 'package:buildvibes/data/repositories/daybook_live.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:buildvibes/features/work/walk_screen.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/activity_fakes.dart';
import '../test/helpers/chat_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/work_fakes.dart';
import 'shot.dart';

const _folder = 'slice6';
const _walk = '00000000-0000-4000-8000-000000000601';

DaybookChild _row(
  String n,
  String title, {
  required String owner,
  required String ownerName,
  WorkStatus status = WorkStatus.open,
  DaybookNeed? need,
}) => DaybookChild(
  id: '00000000-0000-4000-8000-00000000061$n',
  title: title,
  status: status,
  ownerId: owner,
  ownerName: ownerName,
  need: need,
  coverPath: 'kct/posts/61$n/1.jpg',
);

DaybookPost _walkPost(DaybookSamples s) => DaybookPost(
  id: _walk,
  kind: DaybookPost.workItemKind,
  createdAt: DateTime(2026, 10, 15, 14, 10),
  title: s.t('Walk, level 4 corridor', 'جولة، ممر الدور 4'),
  authorId: DaybookSamples.islam,
  authorName: s.islamName,
  place: s.t('Level 4 corridor', 'ممر الدور 4'),
  item: DaybookItem(
    status: WorkStatus.open,
    ownerId: DaybookSamples.islam,
    ownerName: s.islamName,
    ref: 'KCT-030',
  ),
  children: DaybookChildren(
    total: 4,
    checked: 1,
    target: true,
    rows: [
      _row(
        '1',
        s.t('Hanger missing above door 4.12', 'علاقة مفقودة فوق الباب 4.12'),
        owner: DaybookSamples.omar,
        ownerName: s.omarName,
        need: DaybookNeed.toSign,
      ),
      _row(
        '2',
        s.t('Tray not earthed at riser', 'الحامل غير مؤرض عند الصاعد'),
        owner: DaybookSamples.omar,
        ownerName: s.omarName,
        need: DaybookNeed.toSign,
      ),
      _row(
        '3',
        s.t('Sleeve not sealed at wall B', 'كم غير مُحكم عند الجدار B'),
        owner: DaybookSamples.sara,
        ownerName: s.saraName,
        status: WorkStatus.done,
      ),
      _row(
        '4',
        s.t('Ladder left on the walkway', 'سلم متروك على الممشى'),
        owner: DaybookSamples.rakesh,
        ownerName: s.rakeshName,
        status: WorkStatus.checked,
      ),
    ],
  ),
);

Future<List<Override>> _overrides(
  DaybookSamples s, {
  String me = DaybookSamples.omar,
}) async {
  // test_screens/ is a test folder the analyzer doesn't know.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final walk = _walkPost(s);
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
    clockProvider.overrideWithValue(() => DateTime(2026, 10, 15, 14, 20)),
    workRepositoryProvider.overrideWithValue(FakeWorkRepository()),
    daybookLiveProvider.overrideWithValue(FakeDaybookLive()),
    daybookRepositoryProvider.overrideWithValue(
      FakeDaybookRepository()
        ..posts[DaybookSamples.space] = [
          DaybookCard(post: walk, lastActivityAt: walk.createdAt),
        ],
    ),
    daybookPhotoProvider.overrideWith((ref, path) => samplePhoto),
    localPhotoProvider.overrideWith((ref, path) => samplePhoto),
    pickPhotoProvider.overrideWithValue(
      ({required camera, onPreparing}) async =>
          (photos: [XFile('walk.jpg')], refused: 0),
    ),
    keepPhotoProvider.overrideWithValue((photo) async => photo.path),
  ];
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    testWidgets('R1b the walk, one card [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'R1b-walk-card',
        lang,
        (_) => const SpaceScreen(spaceId: DaybookSamples.space),
        folder: _folder,
        overrides: await _overrides(s),
      );
    });

    testWidgets('R1 name the walk [$lang]', (tester) async {
      await shoot(
        tester,
        'R1-walk-start',
        lang,
        (_) => const WalkScreen(spaceId: DaybookSamples.space),
        folder: _folder,
        overrides: await _overrides(s, me: DaybookSamples.islam),
        before: (tester) async {
          await tester.enterText(
            find.byKey(const Key('walk-name')),
            s.t('Walk, level 4 corridor', 'جولة، ممر الدور 4'),
          );
          await tester.enterText(
            find.byKey(const Key('walk-place')),
            s.t('Level 4 corridor', 'ممر الدور 4'),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('R1 a photo, its line and owner [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'R1-walk-photo',
        lang,
        (_) => const WalkScreen(spaceId: DaybookSamples.space),
        folder: _folder,
        overrides: await _overrides(s, me: DaybookSamples.islam),
        before: (tester) async {
          await tester.enterText(
            find.byKey(const Key('walk-name')),
            s.t('Walk, level 4 corridor', 'جولة، ممر الدور 4'),
          );
          await tester.enterText(
            find.byKey(const Key('walk-place')),
            s.t('Level 4 corridor', 'ممر الدور 4'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('walk-start')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('walk-line-0')),
            s.t(
              'Hanger missing above door 4.12',
              'علاقة مفقودة فوق الباب 4.12',
            ),
          );
          await tester.tap(find.byKey(const Key('walk-owner')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byKey(const Key('walk-owner-picker')),
              matching: find.text(s.omarName),
            ),
          );
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        },
      );
    });
  }
}
