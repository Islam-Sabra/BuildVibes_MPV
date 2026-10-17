// Slice 1 part 1e, around the daybook, against Figma: Space info SI1
// 2562:35576 (AR 2564:843), Needs you NY1 2544:35068, Home in Daybook H1
// v3 2555:35276 (AR 2564:184), Profile: proof of work R1 v4 2556:35424
// (AR 2564:366) and Proof on the profile PR1 2544:35381; part 1f's Write
// a post in place H2 2555:35388 (no AR frame: the AR Home 2564:184's
// words) with its draft, waiting and refused states. The Space menu MN1
// is in daybook_test.dart. Run:
//   flutter test test_screens/around_test.dart --update-goldens
import 'dart:convert';

import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/data/models/people.dart';
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
import 'package:buildvibes/features/feed/feed_state.dart';
import 'package:buildvibes/features/feed/post_card.dart';
import 'package:buildvibes/features/feed/post_draft.dart';
import 'package:buildvibes/features/home/home_screen.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/profile/person_profile_screen.dart';
import 'package:buildvibes/features/profile/profile_screen.dart';
import 'package:buildvibes/features/spaces/space_info_screen.dart';
import 'package:buildvibes/features/work/daybook_entry.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
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
  Map<String, Object> phone = const {},
}) async {
  // test_screens/ is a test folder the analyzer doesn't know.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(phone);
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
    localPhotoProvider.overrideWith((ref, path) => samplePhoto),
  ];
}

/// Opens Home's card at Now, as Create does.
Future<void> _write(WidgetTester tester) async {
  ProviderScope.containerOf(
    tester.element(find.byType(HomeScreen)),
  ).read(postWritingProvider.notifier).write();
  await tester.pumpAndSettle();
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
    final l10n = lookupAppLocalizations(Locale(lang));
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

    FakePostRepository
    homePosts() => FakePostRepository(now: DaybookSamples.thursday)
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
        s.rakeshName,
      ];

    final kctTag = PostProject(id: 'proj-kct', name: kct, placeName: sharq);
    final clash = t(
      'Clash between the duct and the beam at D4 solved by raising the duct '
          '150 mm.',
      'حُلّ التعارض بين مجرى الهواء والكمرة عند D4 برفع المجرى 150 مم.',
    );
    final islamMe = MyProfile(
      id: DaybookSamples.islam,
      firstName: t('Islam', 'إسلام'),
      lastName: t('Ahmed', 'أحمد'),
      locale: lang,
    );

    Future<List<Override>> home({Map<String, Object> phone = const {}}) async =>
        [
          ...await _base(me: DaybookSamples.islam, phone: phone),
          postRepositoryProvider.overrideWithValue(homePosts()),
          myProfileProvider.overrideWith((ref) async => islamMe),
          marketsProvider.overrideWith((ref) async => const <Market>[]),
          newPostIdProvider.overrideWithValue(() => 'post-clash'),
          pickPhotoProvider.overrideWithValue(
            ({required camera}) async => XFile('camera.jpg'),
          ),
          keepPhotoProvider.overrideWithValue((photo) async => 'kept.jpg'),
          // Islam's profile: Kuwait City Tower, with a confirmed role.
          profileViewProvider.overrideWith(
            (ref, id) async => ProfileView(
              id: DaybookSamples.islam,
              firstName: islamMe.firstName,
              lastName: islamMe.lastName,
              followerCount: 0,
              followingCount: 0,
              projects: [
                CvProjectEntry(
                  id: 'cv-kct-islam',
                  projectId: 'proj-kct',
                  projectName: kct,
                  role: t('BIM Manager', 'مدير BIM'),
                  showOnProfile: true,
                  confirmed: true,
                  placeName: sharq,
                ),
              ],
            ),
          ),
        ];

    /// The post at Now: its text, the photo and the project tag.
    String draftJson({bool couldNotSend = false}) => jsonEncode(
      PostDraft(
        id: 'post-clash',
        body: clash,
        lang: PostLang.of(lang),
        project: kctTag,
        photos: const ['kept.jpg'],
      ).toJson()..['could_not_send'] = couldNotSend,
    );

    testWidgets('H1 Home in Daybook [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'H1-home',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(),
      );
    });

    testWidgets('H2 Write a post in place, empty [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'H2-write-post',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(),
        before: _write,
      );
    });

    testWidgets('H3 the post filled: a photo and the project tag [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'H3-write-post-filled',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(),
        // Written as on site: the text, a photo, then the project.
        before: (tester) async {
          await _write(tester);
          await tester.enterText(find.byKey(const Key('writing-body')), clash);
          await tester.tap(find.bySemanticsLabel(l10n.daybookCamera));
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel(l10n.daybookMore));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.postWritingProject));
          await tester.pumpAndSettle();
          await tester.tap(find.text(kct));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('H4 the post left as a Draft [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'H4-post-draft',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(
          phone: {'post_draft:${DaybookSamples.islam}': draftJson()},
        ),
      );
    });

    testWidgets('H5 no signal: the post waits to send [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      final waiting = PendingPost(
        id: 'post-clash',
        body: clash,
        lang: lang,
        madeAt: DateTime(2026, 10, 15, 9, 41),
        project: kctTag,
        photos: const [PendingPostPhoto(local: 'kept.jpg')],
      );
      await shoot(
        tester,
        'H5-post-waiting',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(
          phone: {
            'post_outbox:${DaybookSamples.islam}': jsonEncode([
              waiting.toJson(),
            ]),
          },
        ),
      );
    });

    testWidgets('H6 refused: back to its Draft, "Couldn\'t send" [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'H6-post-could-not-send',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(
          phone: {
            'post_draft:${DaybookSamples.islam}': draftJson(couldNotSend: true),
          },
        ),
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
        // The daybook's own title (review 48).
        title: s.sleeves,
        projectName: kct,
        checkedByName: s.islamName,
        checkedAt: DateTime(2026, 10, 15, 10, 12),
        shown: true,
        photoPath: 'w1.jpg',
      ),
      DeliveredWork(
        id: 'w-rebar',
        title: s.rebar().title,
        projectName: kct,
        checkedByName: s.saraName,
        checkedAt: DateTime(2026, 10, 14, 15),
        shown: true,
        photoPath: 'w2.jpg',
      ),
      DeliveredWork(
        id: 'w-trays',
        title: s.cableTraysTitle,
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
