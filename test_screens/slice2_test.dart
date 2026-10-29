// Slice 2 in Daybook v13 (review 56): the other kinds of post, against
// Figma K1 v13 (EN 2594:35942, AR 2595:471), K2 v13 (2594:36161, 2595:657),
// K3 v13 (2594:77364, 2595:838), K4 v13 (2594:77482, 2595:77670) and the
// kind menu E6 (2535:34221), with each kind's writing card (E1–E6 at the
// two text sizes). Run:
//   flutter test test_screens/slice2_test.dart --update-goldens
import 'dart:convert';

import 'dart:io';
import 'dart:typed_data';

import 'package:buildvibes/data/repositories/page_repository.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/repositories/chat_repository.dart';
import 'package:buildvibes/core/photo_privacy.dart'
    show photosPreparingProvider;
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/activity_repository.dart';
import 'package:buildvibes/data/repositories/daybook_live.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/library_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/account/account_parts.dart';
import 'package:buildvibes/features/chat/chat_state.dart' show keepFileProvider;
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/library/file_preview_screen.dart';
import 'package:buildvibes/features/library/library_parts.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/chat/thread_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_pinned_note.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:buildvibes/features/spaces/team_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/page_fakes.dart';
import '../test/helpers/activity_fakes.dart';
import '../test/helpers/chat_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/library_fakes.dart';
import '../test/helpers/opened_item.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/work_fakes.dart';
import 'shot.dart';
import 'work_gestures.dart';

const _folder = 'slice2';
const _review72 = 'review72';

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
  Map<String, Uint8List> bytes = const {},
  Map<String, List<DaybookPostFile>> files = const {},
  List<CalendarWorkItem> calendar = const [],
  List<ChatThread> threads = const [],
  Map<String, List<ChatMessage>> messages = const {},
  Map<String, Object> saved = const {},
  bool addFiles = false,
}) async {
  // test_screens/ is a test folder the analyzer doesn't know.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    spaceRepositoryProvider.overrideWithValue(
      FakeSpaceRepository()
        ..details[DaybookSamples.space] = s.detail(addFiles: addFiles)
        ..spacePeople[DaybookSamples.space] = s.people(),
    ),
    activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
    chatRepositoryProvider.overrideWithValue(
      FakeChatRepository(now: now)
        ..threadsBySpace[DaybookSamples.space] = threads
        ..messagesByThread.addAll(messages),
    ),
    authUserIdProvider.overrideWithValue(AsyncData(me)),
    myMarketProvider.overrideWithValue(kuwait),
    clockProvider.overrideWithValue(() => now),
    // Review 105 J2: an opened item reads its page; the shots have no
    // Supabase, so the fake answers (a post with no page reads as its card).
    pageRepositoryProvider.overrideWithValue(FakePageRepository()),
    workRepositoryProvider.overrideWithValue(FakeWorkRepository()),
    daybookLiveProvider.overrideWithValue(FakeDaybookLive()),
    daybookRepositoryProvider.overrideWithValue(
      FakeDaybookRepository()
        ..posts[DaybookSamples.space] = posts
        ..extrasBySpace[DaybookSamples.space] = extras
        ..pointsByPost[DaybookSamples.handoverId] = s.handoverPoints()
        ..acksByPost.addAll(acks)
        ..filesByPost.addAll(files)
        ..calendar.addAll(calendar),
    ),
    libraryRepositoryProvider.overrideWithValue(
      FakeLibraryRepository(now: now)
        ..filesBySpace[DaybookSamples.space] = library
        ..bytesByPath.addAll(bytes),
    ),
    // Every photo, and the drawing's first page, is the prototype's site
    // photo (the only picture the app bundles for shots).
    daybookPhotoProvider.overrideWith((ref, path) => samplePhoto),
    localPhotoProvider.overrideWith((ref, path) => samplePhoto),
    filePreviewProvider.overrideWith((ref, file) async => samplePhoto),
    pickPhotoProvider.overrideWithValue(
      ({required camera, onPreparing}) async =>
          (photos: [XFile('camera.jpg')], refused: 0),
    ),
    pickPhotosProvider.overrideWithValue(
      ({required max, onPreparing}) async =>
          (photos: [XFile('a.jpg'), XFile('b.jpg')], refused: 0),
    ),
    keepPhotoProvider.overrideWithValue((photo) async => photo.path),
    pickDocumentProvider.overrideWithValue(
      ({bool pdfOnly = false}) async => (
        file: const PhoneFile(
          local: 'M-201.pdf',
          name: 'M-201.pdf',
          mime: 'application/pdf',
          bytes: 2516582,
        ),
        refused: false,
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

/// The Space with its Library's route: a file post starts there (review
/// 105 SP2).
Widget _routedSpace(BuildContext _) => const RoutedSpace(DaybookSamples.space);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// Opens a card at Now and picks [kind] from its kind chips (review 105
/// SP2: the kind menu became one row of chips). A file post starts from
/// the Library's Add a file, its file chooser open.
Future<void> _writeKind(
  WidgetTester tester,
  AppLocalizations l10n,
  DaybookKind kind,
) async {
  if (kind == DaybookKind.file) {
    await _tap(tester, find.byKey(const Key('space-library')));
    await _tap(tester, find.byKey(const Key('library-add-file')));
    return;
  }
  await _tap(tester, find.byKey(const Key('post-bar-notepad')));
  final chip = find.byKey(Key('kind-chip-$kind'));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await _tap(tester, chip);
}

Future<void> _more(
  WidgetTester tester,
  AppLocalizations l10n,
  String item,
) async {
  // Review 105 SP2: the card's rows, or ⋯ for what isn't a row.
  await writingSet(tester, l10n, item);
}

Future<void> _pick(WidgetTester tester, String name) async {
  final row = find.descendant(
    of: find.byKey(const Key('writing-people')),
    matching: find.text(name),
  );
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await _tap(tester, row);
}

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
        // Review 61 G1: in the app's fonts, the checklist's header sits
        // fully below the pinned announcement.
        before: (tester) async {
          final note = tester.getRect(find.byType(BvPinnedNote));
          final header = tester.getRect(
            find.descendant(
              of: find.byKey(const Key('daybook-card-post-handover')),
              matching: find.byType(BvSlipHeader),
            ),
          );
          expect(header.top, greaterThanOrEqualTo(note.bottom));
          expect(header.bottom, lessThanOrEqualTo(shotSize.height));
        },
      );
    });

    testWidgets('K1 the announcement folded after Got it (review 61 G1) '
        '[$lang]', (tester) async {
      final pinned = s.halfDayPost(myAcks: const {DaybookAck.gotIt});
      await shoot(
        tester,
        'K1-announcement-folded',
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

    testWidgets('F34 the facts line: who it is for, the due today [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'F34-facts-line',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: s.v13(),
        ),
      );
    });

    testWidgets('G4 a model view in the Library viewer (review 61) [$lang]', (
      tester,
    ) async {
      final photo = (await tester.runAsync(
        () => File('assets/dev/site_sample.jpg').readAsBytes(),
      ))!;
      const path = '${DaybookSamples.space}/library/mv-supply-air/view.jpg';
      final view = LibraryFile(
        id: 'mv-supply-air',
        spaceId: DaybookSamples.space,
        name: 'Supply Air',
        path: path,
        mime: 'image/jpeg',
        createdAt: DateTime(2026, 10, 19, 18, 6),
        bytes: 101376,
        revLabel: 'V1',
        source: LibrarySource.modelView,
        uploadedById: DaybookSamples.islam,
        uploadedByName: s.islamName,
      );
      await shoot(
        tester,
        'G4-model-view',
        lang,
        (_) => const Pushed(
          FilePreviewScreen(
            spaceId: DaybookSamples.space,
            fileId: 'mv-supply-air',
          ),
        ),
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DateTime(2026, 10, 19, 18, 10),
          posts: const [],
          library: [view],
          bytes: {path: photo},
        ),
        before: (tester) async {
          // Draws the picture's bytes for real.
          await tester.runAsync(
            () => precacheImage(
              MemoryImage(photo),
              tester.element(find.byType(FilePreviewScreen)),
            ),
          );
          await tester.pumpAndSettle();
        },
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
        // Review 105 SP2: the kind menu became the writing card's row of
        // kind chips; the shot shows the card open with its chips.
        before: (tester) =>
            _tap(tester, find.byKey(const Key('post-bar-notepad'))),
      );
    });

    testWidgets('F50 the kind menu: Document for receipt (review 50) '
        '[$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'F50-kind-menu',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: s.v13(),
        ),
        // Review 105 SP2: the kind menu became the writing card's row of
        // kind chips; the shot shows the card open with its chips.
        before: (tester) =>
            _tap(tester, find.byKey(const Key('post-bar-notepad'))),
      );
    });

    testWidgets('F45 the people sheet with Done (review 50) [$lang]', (
      tester,
    ) async {
      await shoot(
        tester,
        'F45-people-picker-done',
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
          await _more(tester, l10n, l10n.daybookPeople);
          await _pick(tester, s.saraName);
          await _pick(tester, s.omarName);
        },
      );
    });

    testWidgets('F48 who received the file, with the times (review 50) '
        '[$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'F48-received-sheet',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: _k2,
          posts: [s.m201()],
          acks: {DaybookSamples.m201Id: s.m201Received()},
        ),
        before: (tester) => _tap(tester, find.byKey(const Key('received-by'))),
      );
    });

    testWidgets('F51 a checklist with two photos (review 50) [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      final h = s.handover();
      const id = DaybookSamples.handoverId;
      final post = DaybookPost(
        id: id,
        kind: DaybookPost.checklistKind,
        createdAt: h.post.createdAt,
        title: h.post.title,
        authorId: h.post.authorId,
        authorName: h.post.authorName,
        dueDate: h.post.dueDate,
        people: h.post.people,
        pointsTotal: h.post.pointsTotal,
        pointsTicked: h.post.pointsTicked,
        coverPath: '${DaybookSamples.space}/posts/$id/0.jpg',
      );
      await shoot(
        tester,
        'F51-two-photos',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: _k1,
          posts: [
            DaybookCard(
              post: post,
              lastActivityAt: h.lastActivityAt,
              history: h.history,
            ),
          ],
          files: {
            id: [
              for (var i = 0; i < 2; i++)
                DaybookPostFile(
                  mime: 'image/jpeg',
                  path: '${DaybookSamples.space}/posts/$id/$i.jpg',
                ),
            ],
          },
        ),
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
            await _type(tester, _emptyPoint(), p.text);
          }
          await _more(tester, l10n, l10n.daybookPeople);
          await _pick(tester, s.saraName);
          await _pick(tester, s.omarName);
          await _tap(tester, find.byKey(const Key('people-done')));
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
          await _tap(tester, find.byKey(const Key('people-done')));
        },
      );
    });

    testWidgets('W writing a file post, a new version [$lang]', (tester) async {
      await shoot(
        tester,
        'W-file',
        lang,
        _routedSpace,
        folder: _folder,
        overrides: await _overrides(
          s,
          addFiles: true,
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
          // F71: one single choice, then the file it replaces.
          await _tap(tester, find.byKey(const Key('replaces-version')));
          await _tap(tester, find.byKey(const Key('version-lib-m201-c')));
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
        _routedSpace,
        folder: _folder,
        overrides: await _overrides(
          s,
          addFiles: true,
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

    testWidgets('K5 v13 a note, for information (F58, 2598:36260) [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      const id = 'post-pour-note';
      final post = DaybookPost(
        id: id,
        kind: DaybookPost.noteKind,
        createdAt: DateTime(2026, 10, 15, 11, 45),
        title: s.t('Pour finished, level 3 slab', 'انتهى الصب، بلاطة الطابق 3'),
        body: s.t(
          'Pump left at 11:40. Curing starts tomorrow, 7 am.',
          'غادرت المضخة 11:40. تبدأ المعالجة غدًا 7 صباحًا.',
        ),
        authorId: DaybookSamples.islam,
        authorName: s.islamName,
        coverPath: '${DaybookSamples.space}/posts/$id/0.jpg',
      );
      await shoot(
        tester,
        'K5-note',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DateTime(2026, 10, 15, 11, 50),
          posts: [DaybookCard(post: post, lastActivityAt: post.createdAt)],
          files: {
            id: [
              for (var i = 0; i < 3; i++)
                DaybookPostFile(
                  mime: 'image/jpeg',
                  path: '${DaybookSamples.space}/posts/$id/$i.jpg',
                ),
            ],
          },
        ),
      );
    });

    testWidgets('F56 a work item: the who row from the start [$lang]', (
      tester,
    ) async {
      await shoot(
        tester,
        'F56-who-row',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [s.rebar()],
        ),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('post-bar-notepad')));
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.cableTraysTitle,
          );
        },
      );
    });

    testWidgets('F56 Post with nobody chosen: the who row asks [$lang]', (
      tester,
    ) async {
      await shoot(
        tester,
        'F56-who-asks',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [s.rebar()],
        ),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('post-bar-notepad')));
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.cableTraysTitle,
          );
          await tester.tap(find.byKey(const Key('writing-post')));
          // Mid-pulse.
          await tester.pump(const Duration(milliseconds: 400));
        },
      );
    });

    testWidgets('F56 an announcement goes To: Everyone or a Team [$lang]', (
      tester,
    ) async {
      await shoot(
        tester,
        'F56-to-menu',
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
          // Review 105 SP2: the Team row opens the To menu.
          final to = find.byKey(const Key('writing-to'));
          await tester.ensureVisible(to);
          await tester.pumpAndSettle();
          await _tap(tester, to);
        },
      );
    });

    testWidgets('F57 the Due today strip with an earlier day, and a passed '
        'due as a reminder [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'F57-due-strip',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          now: DaybookSamples.friday,
          me: DaybookSamples.omar,
          posts: s.l1(),
          calendar: [
            s.cableTraysDue(),
            CalendarWorkItem(
              postId: 'post-rebar-spacers',
              spaceId: DaybookSamples.space,
              title: s.t('Rebar spacers, level 2', 'فواصل الحديد، الطابق 2'),
              day: DateTime(2026, 10, 14),
              status: WorkStatus.open,
              needsMe: true,
            ),
          ],
        ),
      );
    });

    testWidgets('T1 a Team: "Members" over its people, never how many '
        '(sweep) [$lang]', (tester) async {
      await shoot(
        tester,
        'T1-team',
        lang,
        (_) => const TeamScreen(spaceId: DaybookSamples.space, teamId: 't-mep'),
        folder: 'slice3',
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: const [],
        ),
      );
    });

    testWidgets('S7 v4 Chat with New chat, and S7-N (slice 3) [$lang]', (
      tester,
    ) async {
      final threads = [
        ChatThread(
          id: 'th-everyone',
          lastKind: ChatKind.text,
          lastBody: s.t(
            'Friday site walk is on. Gate office at 9.',
            'جولة الموقع يوم الجمعة قائمة. مكتب البوابة الساعة 9.',
          ),
          lastAuthorId: DaybookSamples.omar,
          lastAt: DateTime(2026, 10, 15, 10, 20),
          unread: 2,
        ),
        ChatThread(
          id: 'th-mep',
          teamId: 't-mep',
          teamName: s.t('MEP', 'الكهروميكانيك'),
          lastKind: ChatKind.text,
          lastBody: s.t(
            'Photos of the upstand before sealing',
            'صور القاعدة قبل الإغلاق',
          ),
          lastAuthorId: DaybookSamples.rakesh,
          lastAt: DateTime(2026, 10, 15, 10, 18),
        ),
      ];
      for (final sheet in [false, true]) {
        await shoot(
          tester,
          sheet ? 'S7N-new-chat' : 'S7-chat',
          lang,
          _space,
          folder: 'slice3',
          overrides: await _overrides(
            s,
            now: DaybookSamples.thursday,
            posts: [s.rebar()],
            threads: threads,
          ),
          before: (tester) async {
            await _tap(tester, find.byKey(const Key('space-switch-chat')));
            if (sheet) await _tap(tester, find.byKey(const Key('chat-new')));
          },
        );
      }
    });

    // Review 72 (F59, F62, F63): for the lead.
    testWidgets('F59 at Now with yesterday\'s cards on top [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      final wednesday = DateTime(2026, 10, 14);
      await shoot(
        tester,
        'F59-masthead-today',
        lang,
        _space,
        folder: _review72,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [
            for (var i = 0; i < 3; i++)
              s.card(
                s.item(
                  id: 'post-wed-$i',
                  at: DateTime(2026, 10, 14, 9 + i),
                  title: [s.rebarTitle, s.sleeves, s.cableTraysTitle][i],
                  authorId: DaybookSamples.sara,
                  ownerId: DaybookSamples.omar,
                  due: wednesday,
                ),
              ),
          ],
        ),
      );
    });

    // Review 50 F68b: the To do docket, with 1, 2 and 12 items.
    for (final n in [1, 2, 12]) {
      testWidgets('F68b the To do docket with $n [$lang]', (tester) async {
        await warmSamplePhoto(tester);
        final titles = [
          s.t('Paint Room 3', 'دهان الغرفة 3'),
          s.t('Fix socket in room 4', 'إصلاح المقبس في الغرفة 4'),
          for (var i = 0; i < 10; i++)
            s.t('Snag $i, level 2', 'ملاحظة $i، الدور 2'),
        ];
        await shoot(
          tester,
          'F68b-docket-$n',
          lang,
          _space,
          folder: 'f68b',
          overrides: await _overrides(
            s,
            now: DaybookSamples.friday,
            me: DaybookSamples.omar,
            posts: s.l1(),
            calendar: [
              if (n == 1)
                s.cableTraysDue()
              else
                for (var i = 0; i < n; i++)
                  CalendarWorkItem(
                    postId: 'post-docket-$i',
                    spaceId: DaybookSamples.space,
                    title: titles[i],
                    // The oldest on Sunday, the rest later.
                    day: DateTime(2026, 10, 11 + (i == 0 ? 0 : 3)),
                    status: WorkStatus.open,
                    needsMe: true,
                  ),
            ],
          ),
        );
      });
    }

    // Review 50 F69: the picker lists me once, first, as You.
    testWidgets('F69 the picker with You first [$lang]', (tester) async {
      await shoot(
        tester,
        'F69-picker-you-first',
        lang,
        _space,
        folder: 'f68b',
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [s.rebar()],
        ),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('post-bar-notepad')));
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.cableTraysTitle,
          );
          await _tap(tester, find.byKey(const Key('writing-who')));
        },
      );
    });

    testWidgets('F62 the send-back sheet with the new date [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'F62-send-back-date',
        lang,
        _space,
        folder: _review72,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: s.v13(),
        ),
        before: (tester) async {
          // Review 105 Part 2: a tap opens the item; Send back is on it.
          await openCard(tester, 'post-sleeves');
          await openedPick(tester, l10n.daybookSendBack);
          await _tap(tester, find.text(l10n.daybookReasonPhotoMissing));
          await _tap(tester, find.byKey(const Key('send-back-due-pick')));
        },
      );
    });

    testWidgets('F62 a sent-back card with its new date [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      final sentAt = DateTime(2026, 10, 15, 10, 12);
      final card = s.card(
        s.item(
          id: 'post-sleeves',
          at: DateTime(2026, 10, 14, 15, 50),
          title: s.sleeves,
          ref: 'KCT-014',
          authorId: DaybookSamples.islam,
          ownerId: DaybookSamples.omar,
          due: DateTime(2026, 10, 17),
          place: s.levelTwo,
        ),
        events: [
          s.event(
            'ev-back',
            DaybookEventKind.sentBack,
            sentAt,
            DaybookSamples.islam,
            reason: SendBackReason.photoMissing,
            newDue: DaybookNewDue(day: DateTime(2026, 10, 17)),
          ),
          s.event(
            'ev-done',
            DaybookEventKind.done,
            DateTime(2026, 10, 15, 9, 40),
            DaybookSamples.omar,
            note: s.sleevesFirstNote,
          ),
        ],
      );
      await shoot(
        tester,
        'F62-sent-back-new-date',
        lang,
        _space,
        folder: _review72,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [card],
        ),
      );
    });

    // Review 74 H2: two photos still being prepared on the card.
    testWidgets('H2 photos being prepared [$lang]', (tester) async {
      await shoot(
        tester,
        'H2-photos-preparing',
        lang,
        _space,
        folder: 'f60',
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [s.rebar()],
        ),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('post-bar-notepad')));
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.cableTraysTitle,
          );
          ProviderScope.containerOf(tester.element(find.byType(BvWritingCard)))
              .read(
                photosPreparingProvider(
                  'daybook:${DaybookSamples.space}',
                ).notifier,
              )
              .set(2);
          // The spinners turn: built, then a frame later, never settled.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
        },
      );
    });

    // Review 64 (slice 3): a message quoted in a work item.
    final rakeshSays = s.t(
      'Gate 2 is blocked by the crane. Use gate 3.',
      'البوابة 2 مغلقة بسبب الرافعة. استخدموا البوابة 3.',
    );
    DaybookQuote quoteOf() => DaybookQuote(
      text: rakeshSays,
      authorName: s.rakeshName,
      at: DateTime(2026, 10, 15, 10, 15),
    );

    testWidgets('DM5 the work item being written, quoting the message '
        '[$lang]', (tester) async {
      final draft = DaybookPostDraft(id: 'post-dm5', quote: quoteOf());
      await shoot(
        tester,
        'DM5-writing-quote',
        lang,
        (_) => const SpaceScreen(
          spaceId: DaybookSamples.space,
          open: SpaceOpen.write,
        ),
        folder: 'slice3',
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [s.rebar()],
          saved: {
            'daybook_draft:${DaybookSamples.islam}:${DaybookSamples.space}':
                jsonEncode(draft.toJson()),
          },
        ),
        before: (tester) async {
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.t(
              'Clear gate 2 for the pump truck',
              'إخلاء البوابة 2 لشاحنة المضخة',
            ),
          );
        },
      );
    });

    testWidgets('S8m hold a chat message: Turn into a work item [$lang]', (
      tester,
    ) async {
      await shoot(
        tester,
        'S8m-turn-into-work-item',
        lang,
        (_) => const ThreadScreen(
          spaceId: DaybookSamples.space,
          threadId: 'th-everyone',
        ),
        folder: 'slice3',
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: const [],
          threads: [
            ChatThread(
              id: 'th-everyone',
              lastKind: ChatKind.text,
              lastBody: rakeshSays,
              lastAuthorId: DaybookSamples.rakesh,
              lastAt: DateTime(2026, 10, 15, 10, 15),
            ),
          ],
          messages: {
            'th-everyone': [
              ChatMessage(
                id: 'msg-gate',
                threadId: 'th-everyone',
                kind: ChatKind.text,
                createdAt: DateTime(2026, 10, 15, 10, 15),
                authorId: DaybookSamples.rakesh,
                authorName: s.rakeshName,
                body: rakeshSays,
              ),
            ],
          },
        ),
        before: (tester) async {
          await tester.longPress(
            find.byKey(const Key('chat-message-msg-gate')),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('S8m the posted card keeps the quote [$lang]', (tester) async {
      await shoot(
        tester,
        'S8m-card-quote',
        lang,
        _space,
        folder: 'slice3',
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: [
            s.card(
              DaybookPost(
                id: 'post-gate',
                kind: DaybookPost.workItemKind,
                createdAt: DateTime(2026, 10, 15, 10, 20),
                title: s.t(
                  'Clear gate 2 for the pump truck',
                  'إخلاء البوابة 2 لشاحنة المضخة',
                ),
                authorId: DaybookSamples.islam,
                authorName: s.islamName,
                dueDate: DateTime(2026, 10, 16),
                item: DaybookItem(
                  status: WorkStatus.open,
                  ownerId: DaybookSamples.rakesh,
                  ownerName: s.rakeshName,
                  ref: 'KCT-021',
                ),
                quote: quoteOf(),
              ),
            ),
          ],
        ),
      );
    });

    // Review 50 F66: the who row once a person is chosen.
    testWidgets('F66 the who row reads For and the name [$lang]', (
      tester,
    ) async {
      await shoot(
        tester,
        'F66-who-row-chosen',
        lang,
        _space,
        folder: _review72,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          // Omar raises it for Islam, as on the founder's test.
          me: DaybookSamples.omar,
          posts: [s.rebar()],
        ),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('post-bar-notepad')));
          await _type(
            tester,
            find.byKey(const Key('writing-title')),
            s.cableTraysTitle,
          );
          await _tap(tester, find.byKey(const Key('writing-who')));
          await _tap(
            tester,
            find.descendant(
              of: find.byType(BvGiveToPicker),
              matching: find.text(s.islamName),
            ),
          );
        },
      );
    });

    testWidgets('F63 the kind menu, no description lines [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'F63-kind-menu',
        lang,
        _space,
        folder: _review72,
        overrides: await _overrides(
          s,
          now: DaybookSamples.thursday,
          posts: s.v13(),
        ),
        // Review 105 SP2: the kind menu became the writing card's row of
        // kind chips; the shot shows the card open with its chips.
        before: (tester) =>
            _tap(tester, find.byKey(const Key('post-bar-notepad'))),
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

/// The checklist's empty last line ("Add a point").
Finder _emptyPoint() => find
    .descendant(
      of: find.byKey(const Key('writing-points')),
      matching: find.byType(TextField),
    )
    .last;
