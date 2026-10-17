// Slice 1 part 1e, around the daybook, against Figma: Space info SI1
// 2562:35576 (AR 2564:843), Needs you NY1 2544:35068, Home in Daybook H1
// v3 2555:35276 (AR 2564:184), Profile: proof of work R1 v4 2556:35424
// (AR 2564:366) and Proof on the profile PR1 2544:35381. The Space menu
// MN1 is in daybook_test.dart. Run:
//   flutter test test_screens/around_test.dart --update-goldens
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/data/models/post.dart';
import 'package:buildvibes/data/models/profile.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/activity_repository.dart';
import 'package:buildvibes/data/repositories/market_repository.dart';
import 'package:buildvibes/data/repositories/post_repository.dart';
import 'package:buildvibes/data/repositories/profile_page_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/activity/activity_state.dart';
import 'package:buildvibes/features/activity/needs_you_screen.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/feed/post_card.dart';
import 'package:buildvibes/features/home/home_screen.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/profile/person_profile_screen.dart';
import 'package:buildvibes/features/profile/profile_screen.dart';
import 'package:buildvibes/features/spaces/space_info_screen.dart';
import 'package:buildvibes/features/work/daybook_entry.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/activity_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/post_fakes.dart';
import '../test/helpers/profile_fakes.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/work_fakes.dart';
import 'shot.dart';

/// The app's bottom bar under a tab, as the shell draws it (H1, R1).
Widget _withNav(BuildContext context, int tab, Widget child) {
  final l10n = AppLocalizations.of(context);
  return Scaffold(
    body: child,
    bottomNavigationBar: BvBottomBar(
      selectedIndex: tab,
      onSelect: (_) {},
      createLabel: l10n.navCreate,
      onCreate: () {},
      items: [
        BvBottomBarItem(
          key: const Key('nav-home'),
          icon: BvIcons.home,
          label: l10n.navHome,
        ),
        BvBottomBarItem(
          key: const Key('nav-explore'),
          icon: BvIcons.explore,
          label: l10n.navExplore,
        ),
        BvBottomBarItem(
          key: const Key('nav-activity'),
          icon: BvIcons.activity,
          label: l10n.navActivity,
        ),
        BvBottomBarItem(
          key: const Key('nav-profile'),
          icon: BvIcons.profile,
          label: l10n.navProfile,
        ),
      ],
    ),
  );
}

Future<List<Override>> _base({
  required String me,
  List<NeedsCard> needs = const [],
}) async {
  // test_screens/ is a test folder the analyzer doesn't know.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authUserIdProvider.overrideWithValue(AsyncData(me)),
    appGateProvider.overrideWithValue(AppGate.ready),
    clockProvider.overrideWithValue(() => DaybookSamples.thursday),
    activityRepositoryProvider.overrideWithValue(
      FakeActivityRepository(cards: needs),
    ),
    needsCardsProvider.overrideWith((ref) async => needs),
    daybookPhotoProvider.overrideWith((ref, path) => samplePhoto),
    postPhotoProvider.overrideWith((ref, path) => samplePhoto),
  ];
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
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
    String t(String en, String ar) => lang == 'ar' ? ar : en;
    final kct = t('Kuwait City Tower', 'برج مدينة الكويت');
    final sharq = const LocalizedText(en: 'Sharq', ar: 'شرق');

    testWidgets('SI1 Space info [$lang]', (tester) async {
      final spaces = FakeSpaceRepository(now: DaybookSamples.thursday)
        ..details[DaybookSamples.space] = SpaceDetail(
          id: DaybookSamples.space,
          name: s.spaceName,
          projectId: 'proj-kct',
          projectName: kct,
          projectPlace: sharq,
          myPass: SpacePass.lead,
          iAmAdmin: true,
          myRights: const MemberRights(
            createItems: true,
            invite: true,
            markDone: true,
          ),
          whoCanInvite: SpaceInviters.adminsAndLeads,
          myNotify: SpaceNotify.needsYou,
          siteStartDate: DaybookSamples.siteStart,
        )
        ..spacePeople[DaybookSamples.space] = s.people();
      await shoot(
        tester,
        'SI1-space-info',
        lang,
        (_) => const Pushed(SpaceInfoScreen(spaceId: DaybookSamples.space)),
        overrides: [
          ...await _base(me: DaybookSamples.islam),
          spaceRepositoryProvider.overrideWithValue(spaces),
        ],
      );
    });

    testWidgets('NY1 Needs you, across Spaces [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      final needs = [
        NeedsCard(
          kind: NeedsKind.youCheck,
          spaceId: DaybookSamples.space,
          spaceName: s.spaceName,
          at: DateTime(2026, 10, 15, 9, 40),
          workItemId: 'post-sleeves',
          workItemTitle: s.sleeves,
          actorName: s.omarName,
          photoPath: 'proof.jpg',
        ),
        NeedsCard(
          kind: NeedsKind.forYou,
          spaceId: DaybookSamples.space,
          spaceName: s.spaceName,
          at: DateTime(2026, 10, 15, 8),
          workItemId: 'post-rebar',
          workItemTitle: s.rebar().title,
          actorName: s.saraName,
          due: DateTime(2026, 10, 15),
          dueAt: DateTime(2026, 10, 15, 14),
          photoPath: 'cover.jpg',
        ),
        NeedsCard(
          kind: NeedsKind.forYou,
          spaceId: 'space-khiran',
          spaceName: t('Khiran villas — Finishing', 'فلل الخيران — التشطيبات'),
          at: DateTime(2026, 10, 14, 16),
          workItemId: 'post-a501',
          workItemTitle: 'A-501 Rev D',
          actorName: s.linaName,
          due: DateTime(2026, 10, 16),
        ),
      ];
      await shoot(
        tester,
        'NY1-needs-you',
        lang,
        (_) => const Pushed(NeedsYouScreen()),
        overrides: await _base(me: DaybookSamples.islam, needs: needs),
      );
    });

    testWidgets('H1 Home in Daybook [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      final posts = FakePostRepository(now: DaybookSamples.thursday)
        ..posts.add(
          Post(
            id: 'post-pour',
            authorId: DaybookSamples.omar,
            authorName: s.omarName,
            authorHeadline: t('MEP Foreman', 'رئيس عمال MEP'),
            authorCompany: t('Gulf Build Co.', 'جلف بيلد'),
            body: t(
              'First pour on the podium slab is done. Thanks to the concrete '
                  'crew for a clean night shift.',
              'انتهت أول صبّة لبلاطة البوديوم. شكراً لفريق الخرسانة على وردية '
                  'ليلية نظيفة.',
            ),
            lang: lang,
            project: PostProject(id: 'proj-kct', name: kct, placeName: sharq),
            createdAt: DateTime(2026, 10, 15, 6, 10),
            photos: const [PostPhoto(path: 'pour.jpg')],
          ),
        )
        ..home.add('post-pour')
        ..useful['post-pour'] = [
          t('Mariam Al-Sabah', 'مريم الصباح'),
          t('Rakesh Nair', 'راكش ناير'),
        ];
      await shoot(
        tester,
        'H1-home',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: [
          ...await _base(me: DaybookSamples.islam),
          postRepositoryProvider.overrideWithValue(posts),
          myProfileProvider.overrideWith((ref) async => null),
          marketsProvider.overrideWith((ref) async => const <Market>[]),
        ],
      );
    });

    ProfileView omar() => ProfileView(
      id: DaybookSamples.omar,
      firstName: t('Omar', 'عمر'),
      lastName: t('Haddad', 'حداد'),
      followerCount: 312,
      followingCount: 180,
      headline: t('MEP Foreman', 'رئيس عمال MEP'),
      companyName: t('Gulf Build Co.', 'جلف بيلد'),
      projects: [
        CvProjectEntry(
          id: 'cv-kct',
          projectId: 'proj-kct',
          projectName: kct,
          role: t('MEP Foreman', 'رئيس عمال MEP'),
          showOnProfile: true,
          confirmed: true,
          placeName: sharq,
          start: DateTime(2023),
        ),
        CvProjectEntry(
          id: 'cv-salmiya',
          projectId: 'proj-salmiya',
          projectName: t('Salmiya Seafront', 'واجهة السالمية البحرية'),
          role: t('MEP Foreman', 'رئيس عمال MEP'),
          showOnProfile: true,
          confirmed: false,
          placeName: const LocalizedText(en: 'Salmiya', ar: 'السالمية'),
          start: DateTime(2021),
          end: DateTime(2023),
        ),
      ],
    );

    List<DeliveredWork> shown() => [
      DeliveredWork(
        id: 'w-sleeves',
        title: t(
          'Sleeves at grid C7 before the pour',
          'جلب الأنابيب عند المحور C7 قبل الصب',
        ),
        projectName: kct,
        checkedByName: s.islamName,
        checkedAt: DateTime(2026, 10, 15, 10, 12),
        shown: true,
        photoPath: 'w1.jpg',
      ),
      DeliveredWork(
        id: 'w-rebar',
        title: t(
          'Rebar spacing, level 3 slab',
          'تباعد حديد التسليح، بلاطة الدور 3',
        ),
        projectName: kct,
        checkedByName: s.saraName,
        checkedAt: DateTime(2026, 10, 14, 15),
        shown: true,
        photoPath: 'w2.jpg',
      ),
      DeliveredWork(
        id: 'w-trays',
        title: t(
          'Cable tray hangers, level 4',
          'علّاقات حوامل الكابلات، الدور 4',
        ),
        projectName: kct,
        checkedByName: s.islamName,
        checkedAt: DateTime(2026, 10, 12, 11),
        shown: true,
        photoPath: 'w3.jpg',
      ),
    ];

    Future<List<Override>> profile(String me) async => [
      ...await _base(me: me),
      profileViewProvider.overrideWith((ref, id) async => omar()),
      shownWorkProvider.overrideWith((ref, id) async => shown()),
      myDeliveredWorkProvider.overrideWith((ref) async => shown()),
      workRepositoryProvider.overrideWithValue(FakeWorkRepository()),
      profilePageRepositoryProvider.overrideWithValue(
        FakeProfilePageRepository(FakeProfileRepository()),
      ),
    ];

    testWidgets('R1 Profile: proof of work [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'R1-profile',
        lang,
        (context) => _withNav(context, 3, const ProfileScreen()),
        overrides: await profile(DaybookSamples.omar),
      );
    });

    testWidgets('PR1 Proof on the profile, as Islam sees it [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'PR1-proof-on-profile',
        lang,
        (_) =>
            const Pushed(PersonProfileScreen(profileId: DaybookSamples.omar)),
        overrides: await profile(DaybookSamples.islam),
      );
    });
  }
}
