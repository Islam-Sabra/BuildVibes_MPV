// Slice 4, People and Library (review 67, review 69 §1), against Figma P1
// (2542:34824), P2 (2542:34982), V1 (2542:35109), LV1 (2543:34980), LV2
// (2543:35101) and S (2543:35148). No Arabic frames: the Arabic shots are
// the English frames mirrored, for the lead to check.
// Run:
//   flutter test test_screens/slice4_test.dart --update-goldens
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/space_search.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/activity_repository.dart';
import 'package:buildvibes/data/repositories/chat_repository.dart';
import 'package:buildvibes/data/repositories/daybook_live.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/library_repository.dart';
import 'package:buildvibes/data/repositories/search_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/library/library_file_screen.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/spaces/space_search_screen.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/activity_fakes.dart';
import '../test/helpers/chat_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/library_fakes.dart';
import '../test/helpers/search_fakes.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/work_fakes.dart';
import 'shot.dart';

const _folder = 'slice4';
const _space = 'space-kct';
const _islam = 'user-1';

/// Thursday 15 October, 11:20.
final _now = DateTime(2026, 10, 15, 11, 20);

String _t(String lang, String en, String ar) => lang == 'ar' ? ar : en;

SpacePerson _person(String id, String name, String role, {String? company}) {
  final parts = name.split(' ');
  return SpacePerson(
    id: id,
    firstName: parts.first,
    lastName: parts.skip(1).join(' '),
    headline: role,
    companyLabel: company,
  );
}

SpaceDetail _detail(
  String lang, {
  SpacePass pass = SpacePass.lead,
  bool admin = true,
  bool createItems = true,
}) => SpaceDetail(
  id: _space,
  name: _t(
    lang,
    'Kuwait City Tower — Site team',
    'برج مدينة الكويت — فريق الموقع',
  ),
  projectId: 'proj-kct',
  myPass: pass,
  iAmAdmin: admin,
  myRights: MemberRights(
    createItems: createItems,
    addFiles: createItems,
    invite: admin,
    markDone: pass != SpacePass.viewer,
  ),
);

/// P1 as drawn: Yousef asks to join; two Leads, three Crew, a Viewer, two
/// Teams.
SpacePeople _people(String lang) {
  SpaceMember member(SpacePerson p, SpacePass pass, {bool admin = false}) =>
      SpaceMember(
        person: p,
        pass: pass,
        isAdmin: admin,
        confirmedAt: DateTime(2026, 9, 5),
      );
  return SpacePeople(
    requests: [
      SpaceJoinRequest(
        id: 'req-yousef',
        person: _person(
          'p-yousef',
          _t(lang, 'Yousef Karam', 'يوسف كرم'),
          _t(lang, 'Foreman', 'مراقب عمال'),
          company: _t(lang, 'Gulf Build Co.', 'شركة الخليج للبناء'),
        ),
        createdAt: _now.subtract(const Duration(hours: 1)),
      ),
    ],
    members: [
      member(
        _person(
          _islam,
          _t(lang, 'Islam Ahmed', 'إسلام أحمد'),
          _t(lang, 'BIM Manager', 'مدير BIM'),
        ),
        SpacePass.lead,
        admin: true,
      ),
      member(
        _person(
          'p-sara',
          _t(lang, 'Sara Al-Mutairi', 'سارة المطيري'),
          _t(lang, 'Site Engineer', 'مهندسة موقع'),
        ),
        SpacePass.lead,
      ),
      member(
        _person(
          'p-omar',
          _t(lang, 'Omar Haddad', 'عمر حداد'),
          _t(lang, 'MEP Foreman', 'مراقب كهروميكانيك'),
        ),
        SpacePass.crew,
      ),
      member(
        _person(
          'p-rakesh',
          _t(lang, 'Rakesh Nair', 'راكيش ناير'),
          _t(lang, 'Electrician', 'كهربائي'),
        ),
        SpacePass.crew,
      ),
      member(
        _person(
          'p-lina',
          _t(lang, 'Lina Khalil', 'لينا خليل'),
          _t(lang, 'Architect', 'معمارية'),
        ),
        SpacePass.crew,
      ),
      member(
        _person(
          'p-mona',
          _t(lang, 'Mona Adel', 'منى عادل'),
          _t(lang, 'Client representative', 'ممثلة المالك'),
        ),
        SpacePass.viewer,
      ),
    ],
    teams: [
      SpaceTeam(
        id: 't-mep',
        name: _t(lang, 'MEP team', 'فريق الكهروميكانيك'),
        memberIds: const {'p-omar', 'p-rakesh'},
      ),
      SpaceTeam(
        id: 't-structure',
        name: _t(lang, 'Structure team', 'فريق الإنشاءات'),
        memberIds: const {'p-sara'},
      ),
    ],
  );
}

LibraryFile _file(
  String id,
  String name, {
  String? rev,
  String? supersedes,
  required DateTime at,
  String mime = 'application/pdf',
  String by = 'p-lina',
  String byName = 'Lina Khalil',
}) => LibraryFile(
  id: id,
  spaceId: _space,
  name: name,
  path: '$_space/library/$id/x.pdf',
  mime: mime,
  createdAt: at,
  bytes: 2516582,
  revLabel: rev,
  supersedesId: supersedes,
  uploadedById: by,
  uploadedByName: byName,
);

/// LV1 and LV2 as drawn.
FakeLibraryRepository _library(String lang) {
  final lina = _t(lang, 'Lina Khalil', 'لينا خليل');
  LibraryReceipt got(String id, String en, String ar, int hours) =>
      LibraryReceipt(
        profileId: id,
        name: _t(lang, en, ar),
        at: _now.subtract(Duration(hours: hours)),
      );
  final islam = got(_islam, 'Islam Ahmed', 'إسلام أحمد', 1);
  final omar = got('p-omar', 'Omar Haddad', 'عمر حداد', 2);
  return FakeLibraryRepository(now: _now)
    ..filesBySpace[_space] = [
      _file(
        'a501-d',
        'A-501 Rev D.pdf',
        rev: 'Rev D',
        supersedes: 'a501-c',
        at: DateTime(2026, 10, 15, 11, 5),
        byName: lina,
      ),
      _file(
        'm201-c',
        'M-201 Rev C.pdf',
        rev: 'Rev C',
        supersedes: 'm201-b',
        at: DateTime(2026, 10, 9),
        byName: lina,
      ),
      _file(
        'pour4',
        'Pour 4 delivery note.pdf',
        mime: 'image/jpeg',
        at: DateTime(2026, 10, 14),
        byName: lina,
      ),
      _file(
        'ms',
        'Method statement, sleeves.pdf',
        at: DateTime(2026, 10, 2),
        byName: lina,
      ),
      _file(
        'a501-c',
        'A-501 Rev C.pdf',
        rev: 'Rev C',
        supersedes: 'a501-b',
        at: DateTime(2026, 10, 2),
        byName: lina,
      ),
      _file(
        'a501-b',
        'A-501 Rev B.pdf',
        rev: 'Rev B',
        at: DateTime(2026, 9, 20),
        byName: lina,
      ),
      _file(
        'm201-b',
        'M-201 Rev B.pdf',
        rev: 'Rev B',
        at: DateTime(2026, 9, 28),
        byName: lina,
      ),
    ]
    ..overviewBySpace[_space] = {
      'a501-d': LibraryOverview(
        fileId: 'a501-d',
        newForMe: true,
        received: [islam, omar],
      ),
      'm201-c': LibraryOverview(
        fileId: 'm201-c',
        received: [
          omar,
          got('p-sara', 'Sara Al-Mutairi', 'سارة المطيري', 5),
          got('p-rakesh', 'Rakesh Nair', 'راكيش ناير', 6),
        ],
      ),
      'pour4': LibraryOverview(
        fileId: 'pour4',
        received: [got('p-sara', 'Ahmed Saeed', 'أحمد سعيد', 20)],
      ),
      'ms': LibraryOverview(
        fileId: 'ms',
        received: [
          islam,
          omar,
          got('p-sara', 'Sara Al-Mutairi', 'سارة المطيري', 30),
        ],
      ),
    }
    ..receiptsByFile['a501-d'] = [omar, islam]
    ..postByFile['a501-d'] = 'post-a501';
}

/// S as drawn: "sleeves".
FakeSearchRepository _search(String lang) => FakeSearchRepository()
  ..matchAll = true
  ..hits.addAll([
    SpaceSearchHit(
      kind: SpaceSearchKind.post,
      id: 'post-c7',
      postId: 'post-c7',
      ref: 'KCT-021',
      title: _t(
        lang,
        'Sleeves at grid C7 before the pour',
        'الأكمام عند المحور C7 قبل الصب',
      ),
      authorName: _t(lang, 'Islam Ahmed', 'إسلام أحمد'),
      createdAt: DateTime(2026, 10, 15, 8),
      status: WorkStatus.done,
    ),
    SpaceSearchHit(
      kind: SpaceSearchKind.point,
      id: 'point-b',
      postId: 'post-walk',
      title: _t(lang, 'Walk, level 4', 'جولة، الدور 4'),
      snippet: _t(
        lang,
        'Sleeve not sealed at wall B',
        'كم غير مُحكم عند الجدار B',
      ),
      createdAt: DateTime(2026, 10, 15, 7),
    ),
    SpaceSearchHit(
      kind: SpaceSearchKind.post,
      id: 'post-order',
      postId: 'post-order',
      ref: 'KCT-024',
      title: _t(
        lang,
        'Order 40 more sleeves, 100 mm',
        'اطلب 40 كمًا إضافيًا، 100 مم',
      ),
      authorName: _t(lang, 'Sara Al-Mutairi', 'سارة المطيري'),
      createdAt: DateTime(2026, 10, 15, 6),
    ),
    SpaceSearchHit(
      kind: SpaceSearchKind.file,
      id: 'ms',
      title: 'Method statement, sleeves.pdf',
      createdAt: DateTime(2026, 10, 2),
    ),
    SpaceSearchHit(
      kind: SpaceSearchKind.message,
      id: 'msg-1',
      threadId: 'thread-1',
      snippet: _t(
        lang,
        'Sleeves arrive tomorrow morning',
        'الأكمام تصل صباح الغد',
      ),
      authorName: _t(lang, 'Omar Haddad', 'عمر حداد'),
      createdAt: DateTime(2026, 10, 14),
    ),
  ]);

Future<List<Override>> _overrides(String lang, {SpaceDetail? detail}) async {
  // test_screens/ is a test folder the analyzer doesn't know.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    spaceRepositoryProvider.overrideWithValue(
      FakeSpaceRepository(now: _now)
        ..details[_space] = detail ?? _detail(lang)
        ..spacePeople[_space] = _people(lang)
        ..codes[_space] = SpaceInvite(
          code: 'K7Q4MD',
          expiresAt: _now.add(const Duration(days: 7)),
        ),
    ),
    activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
    chatRepositoryProvider.overrideWithValue(FakeChatRepository(now: _now)),
    authUserIdProvider.overrideWithValue(const AsyncData(_islam)),
    clockProvider.overrideWithValue(() => _now),
    workRepositoryProvider.overrideWithValue(FakeWorkRepository()),
    daybookLiveProvider.overrideWithValue(FakeDaybookLive()),
    daybookRepositoryProvider.overrideWithValue(FakeDaybookRepository()),
    libraryRepositoryProvider.overrideWithValue(_library(lang)),
    searchRepositoryProvider.overrideWithValue(_search(lang)),
    // The drawing's first page is the prototype's site photo (the only
    // picture the app bundles for shots).
    filePreviewProvider.overrideWith((ref, file) async => samplePhoto),
  ];
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    testWidgets('P1 People [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'P1-people',
        lang,
        (_) => const SpaceScreen(spaceId: _space, open: SpaceOpen.people),
        folder: _folder,
        overrides: await _overrides(lang),
      );
    });

    testWidgets('P1 People, the end of the list [$lang]', (tester) async {
      await shoot(
        tester,
        'P1-people-end',
        lang,
        (_) => const SpaceScreen(spaceId: _space, open: SpaceOpen.people),
        folder: _folder,
        overrides: await _overrides(lang),
        before: (tester) async {
          await tester.drag(
            find.byKey(const Key('space-people')),
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('P2 Let in, nothing chosen [$lang]', (tester) async {
      await shoot(
        tester,
        'P2-let-in-choose',
        lang,
        (_) => const SpaceScreen(spaceId: _space, open: SpaceOpen.people),
        folder: _folder,
        overrides: await _overrides(lang),
        before: (tester) => _tap(tester, 'request-let-in-req-yousef'),
      );
    });

    testWidgets('P2 Let in as Crew [$lang]', (tester) async {
      await shoot(
        tester,
        'P2-let-in-crew',
        lang,
        (_) => const SpaceScreen(spaceId: _space, open: SpaceOpen.people),
        folder: _folder,
        overrides: await _overrides(lang),
        before: (tester) async {
          await _tap(tester, 'request-let-in-req-yousef');
          await _tap(tester, 'request-pass-crew');
        },
      );
    });

    testWidgets('LV1 Library [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'LV1-library',
        lang,
        (_) => const SpaceScreen(spaceId: _space),
        folder: _folder,
        overrides: await _overrides(lang),
        before: (tester) => _tap(tester, 'space-tab-library'),
      );
    });

    testWidgets('LV2 A file and its versions [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'LV2-file',
        lang,
        (_) =>
            const Pushed(LibraryFileScreen(spaceId: _space, fileId: 'a501-d')),
        folder: _folder,
        overrides: await _overrides(lang),
      );
    });

    testWidgets('S Search [$lang]', (tester) async {
      await shoot(
        tester,
        'S-search',
        lang,
        (_) => const SpaceSearchScreen(spaceId: _space),
        folder: _folder,
        overrides: await _overrides(lang),
        before: (tester) async {
          await tester.enterText(
            find.descendant(
              of: find.byKey(const Key('search-field')),
              matching: find.byType(TextField),
            ),
            lang == 'ar' ? 'الأكمام' : 'sleeves',
          );
          await tester.pump(BvMotion.searchWait);
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('V1 a Crew pass with posting locked [$lang]', (tester) async {
      await shoot(
        tester,
        'V1-crew-locked',
        lang,
        (_) => const SpaceScreen(spaceId: _space),
        folder: _folder,
        overrides: await _overrides(
          lang,
          detail: _detail(
            lang,
            pass: SpacePass.crew,
            admin: false,
            createItems: false,
          ),
        ),
      );
    });
  }
}
