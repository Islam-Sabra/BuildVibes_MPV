// Slice 2 in Daybook v13 (review 56): the other kinds of post, against
// Figma K1 v13 (EN 2594:35942, AR 2595:471), K2 v13 (2594:36161, 2595:657),
// K3 v13 (2594:77364, 2595:838), K4 v13 (2594:77482, 2595:77670) and the
// kind menu E6 (2535:34221), with each kind's writing card (E1–E6 at the
// two text sizes). Run:
//   flutter test test_screens/slice2_test.dart --update-goldens
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/activity_repository.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/library_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/account/account_parts.dart';
import 'package:buildvibes/features/chat/chat_state.dart' show keepFileProvider;
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/library/library_parts.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/activity_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/library_fakes.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/work_fakes.dart';
import 'shot.dart';

const _folder = 'slice2';

/// K1: Thursday 10:41, after Omar's tick at 10:40.
final _k1 = DateTime(2026, 10, 15, 10, 41);

/// K2: Thursday 11:10, after Lina's file at 11:05.
final _k2 = DateTime(2026, 10, 15, 11, 10);

/// K3: Friday 6:30, the walk starts at 7:00.
final _k3 = DateTime(2026, 10, 16, 6, 30);

Future<List<Override>> _overrides(
  DaybookSamples s, {
  required List<DaybookCard> posts,
  required DateTime now,
  String me = DaybookSamples.islam,
  DaybookExtras extras = const DaybookExtras(),
  Map<String, List<DaybookAckFace>> acks = const {},
  List<LibraryFile> library = const [],
}) async {
  // test_screens/ is a test folder the analyzer doesn't know.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    spaceRepositoryProvider.overrideWithValue(
      FakeSpaceRepository()
        ..details[DaybookSamples.space] = s.detail()
        ..spacePeople[DaybookSamples.space] = s.people(),
    ),
    activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
    authUserIdProvider.overrideWithValue(AsyncData(me)),
    myMarketProvider.overrideWithValue(kuwait),
    clockProvider.overrideWithValue(() => now),
    workRepositoryProvider.overrideWithValue(FakeWorkRepository()),
    daybookRepositoryProvider.overrideWithValue(
      FakeDaybookRepository()
        ..posts[DaybookSamples.space] = posts
        ..extrasBySpace[DaybookSamples.space] = extras
        ..pointsByPost[DaybookSamples.handoverId] = s.handoverPoints()
        ..acksByPost.addAll(acks),
    ),
    libraryRepositoryProvider.overrideWithValue(
      FakeLibraryRepository(now: now)
        ..filesBySpace[DaybookSamples.space] = library,
    ),
    // Every photo, and the drawing's first page, is the prototype's site
    // photo (the only picture the app bundles for shots).
    daybookPhotoProvider.overrideWith((ref, path) => samplePhoto),
    localPhotoProvider.overrideWith((ref, path) => samplePhoto),
    filePreviewProvider.overrideWith((ref, file) async => samplePhoto),
    pickPhotoProvider.overrideWithValue(
      ({required camera}) async => XFile('camera.jpg'),
    ),
    pickPhotosProvider.overrideWithValue(
      ({required max}) async => [XFile('a.jpg'), XFile('b.jpg')],
    ),
    keepPhotoProvider.overrideWithValue((photo) async => photo.path),
    pickDocumentProvider.overrideWithValue(
      ({bool pdfOnly = false}) async => const PhoneFile(
        local: 'M-201.pdf',
        name: 'M-201.pdf',
        mime: 'application/pdf',
        bytes: 2516582,
      ),
    ),
    keepFileProvider.overrideWithValue((path, extension) async => path),
    pickDueProvider.overrideWithValue(
      (context, {required now, day, at}) async =>
          (day: DateTime(2026, 10, 18), at: null),
    ),
    pickPinProvider.overrideWithValue(
      (context, {required now, until}) async => (until: DateTime(2026, 10, 17)),
    ),
    pickStartProvider.overrideWithValue(
      (context, {required now, start, end}) async =>
          (start: DateTime(2026, 10, 16, 7), end: DateTime(2026, 10, 16, 8)),
    ),
    outboxRetryDelaysProvider.overrideWithValue(const []),
    newPostIdProvider.overrideWithValue(() => 'post-slice2-new'),
  ];
}

Widget _space(BuildContext _) =>
    const SpaceScreen(spaceId: DaybookSamples.space);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// Opens a card at Now and picks [kind] from its chip (E6).
Future<void> _writeKind(
  WidgetTester tester,
  AppLocalizations l10n,
  DaybookKind kind,
) async {
  await _tap(tester, find.byKey(const Key('post-bar-notepad')));
  await _tap(tester, find.byKey(const Key('writing-kind-chip')));
  await _tap(
    tester,
    find.descendant(
      of: find.byKey(const Key('writing-kind-menu')),
      matching: find.text(kindName(l10n, kind)),
    ),
  );
}

Future<void> _more(
  WidgetTester tester,
  AppLocalizations l10n,
  String item,
) async {
  await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
  await _tap(tester, find.text(item));
}

Future<void> _pick(WidgetTester tester, String name) => _tap(
  tester,
  find.descendant(of: find.byType(BvGiveToPicker), matching: find.text(name)),
);

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    // One clock on the screen, as the prototype's 24-hour times.
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .alwaysUse24HourFormatTestValue =
        true;
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAlwaysUse24HourTestValue(),
  );

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('K1 v13 a pinned announcement and a checklist [$lang]', (
      tester,
    ) async {
      final pinned = s.halfDayPost();
      await shoot(
        tester,
        'K1-announcement-checklist',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: _k1,
          posts: [
            s.handover(),
            DaybookCard(post: pinned, lastActivityAt: pinned.createdAt),
          ],
          extras: DaybookExtras(pinned: [pinned]),
        ),
      );
    });

    testWidgets('K2 v13 a scheduled activity and a new file version '
        '[$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'K2-activity-file',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: _k2,
          posts: [s.siteWalkCard(), s.m201()],
          acks: {DaybookSamples.m201Id: s.m201Received()},
        ),
      );
    });

    testWidgets('K3 v13 the activity on its day [$lang]', (tester) async {
      final walk = s.siteWalkCard(
        onTheWay: [
          (DaybookSamples.omar, DateTime(2026, 10, 16, 6, 22)),
          (DaybookSamples.sara, DateTime(2026, 10, 16, 6, 25)),
        ],
      );
      await shoot(
        tester,
        'K3-activity-on-its-day',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: _k3,
          posts: [walk],
          extras: DaybookExtras(activities: [walk.post]),
        ),
      );
    });

    testWidgets('K4 v13 attach: a photo or a file [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'K4-attach',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: s.v13(),
        ),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('post-bar-notepad')));
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.cableTraysTitle,
          );
          await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
        },
      );
    });

    testWidgets('E6 the kind menu [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'E6-kind-menu',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: s.v13(),
        ),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('post-bar-notepad')));
          await _tap(tester, find.byKey(const Key('writing-kind-chip')));
        },
      );
    });

    testWidgets('W writing a checklist [$lang]', (tester) async {
      await shoot(
        tester,
        'W-checklist',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [s.rebar()],
        ),
        before: (tester) async {
          await _writeKind(tester, l10n, DaybookKind.checklist);
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.handoverTitle,
          );
          for (final p in s.handoverPoints().take(3)) {
            await _type(
              tester,
              find.byKey(const Key('writing-point-field-new')),
              p.text,
            );
          }
          await _more(tester, l10n, l10n.daybookPeople);
          await _pick(tester, s.saraName);
          await _pick(tester, s.omarName);
          await _away(tester);
          await _more(tester, l10n, l10n.daybookDueDateMenu);
        },
      );
    });

    testWidgets('W writing an announcement [$lang]', (tester) async {
      await shoot(
        tester,
        'W-announcement',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [s.rebar()],
        ),
        before: (tester) async {
          await _writeKind(tester, l10n, DaybookKind.announcement);
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.halfDay,
          );
          await _more(tester, l10n, l10n.daybookPinUntil);
        },
      );
    });

    testWidgets('W writing a scheduled activity [$lang]', (tester) async {
      await shoot(
        tester,
        'W-activity',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [s.rebar()],
        ),
        before: (tester) async {
          await _writeKind(tester, l10n, DaybookKind.activity);
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.siteWalk,
          );
          await _more(tester, l10n, l10n.daybookActivityTime);
          await _more(tester, l10n, l10n.daybookLocation);
          await _type(
            tester,
            find.byKey(const Key('popover-field')),
            s.t('Gate office', 'مكتب البوابة'),
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          await _more(tester, l10n, l10n.daybookPeople);
          await _pick(tester, s.omarName);
          await _pick(tester, s.saraName);
          await _away(tester);
        },
      );
    });

    testWidgets('W writing a file post, a new version [$lang]', (tester) async {
      await shoot(
        tester,
        'W-file',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [s.rebar()],
          library: [
            LibraryFile(
              id: 'lib-m201-c',
              spaceId: DaybookSamples.space,
              name: 'M-201.pdf',
              path: '${DaybookSamples.space}/library/lib-m201-c/M-201.pdf',
              mime: 'application/pdf',
              createdAt: DateTime(2026, 10, 10),
              bytes: 2400000,
              revLabel: 'Rev C',
            ),
          ],
        ),
        before: (tester) async {
          await _writeKind(tester, l10n, DaybookKind.file);
          await _tap(tester, find.byKey(const Key('file-from-phone')));
          await _tap(tester, find.byKey(const Key('replaces-lib-m201-c')));
          await _tap(tester, find.byKey(const Key('replaces-done')));
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.t('M-201 Ground floor plan', 'M-201 مخطط الدور الأرضي'),
          );
        },
      );
    });

    testWidgets('W the file chooser [$lang]', (tester) async {
      await shoot(
        tester,
        'W-file-chooser',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [s.rebar()],
          library: [
            LibraryFile(
              id: 'lib-m201-c',
              spaceId: DaybookSamples.space,
              name: 'M-201.pdf',
              path: '${DaybookSamples.space}/library/lib-m201-c/M-201.pdf',
              mime: 'application/pdf',
              createdAt: DateTime(2026, 10, 10),
              bytes: 2400000,
              revLabel: 'Rev C',
            ),
          ],
        ),
        before: (tester) => _writeKind(tester, l10n, DaybookKind.file),
      );
    });

    // Not a frame: K1 as Sara, one of the checklist's people, with the
    // paper clip and her points to tick.
    testWidgets('K1 as one of the checklist\'s people [$lang]', (tester) async {
      await shoot(
        tester,
        'K1-checklist-for-sara',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: _k1,
          me: DaybookSamples.sara,
          posts: [s.handover(need: DaybookNeed.toTick)],
        ),
      );
    });
  }

  test('the shots\' people are the prototype\'s', () {
    expect(SpacePass.values, contains(SpacePass.crew));
  });
}

/// A tap off the open picker, in the page's top corner, closes it.
Future<void> _away(WidgetTester tester) async {
  await tester.tapAt(
    tester.getTopLeft(find.byKey(const Key('writing-menu-away'))) +
        const Offset(8, 8),
  );
  await tester.pumpAndSettle();
}
