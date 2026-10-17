// Slice 1 part 1e, around the daybook, against Figma: Space info SI1
// 2562:35576 (AR 2564:843), Needs you NY1 2544:35068, Home in Daybook H1
// v3 2555:35276 (AR 2564:184), Profile: proof of work R1 v4 2556:35424
// (AR 2564:366) and Proof on the profile PR1 2544:35381; part 1f's Write
// a post in place H2 2555:35388 (no AR frame: the AR Home 2564:184's
// words) with its draft, waiting and refused states. The Space menu MN1
// is in daybook_test.dart. Run:
//   flutter test test_screens/around_test.dart --update-goldens
import 'dart:async';
import 'dart:convert';

import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/core/push/push_state.dart';
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
import 'package:buildvibes/data/repositories/push_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/activity/activity_screen.dart';
import 'package:buildvibes/features/activity/activity_state.dart';
import 'package:buildvibes/features/activity/needs_you_screen.dart';
import 'package:buildvibes/features/create/create_sheet.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/feed/feed_state.dart';
import 'package:buildvibes/features/feed/post_card.dart';
import 'package:buildvibes/features/feed/post_draft.dart';
import 'package:buildvibes/features/feed/post_screen.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_days_specs.dart';
import 'package:buildvibes/features/home/home_screen.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/profile/person_profile_screen.dart';
import 'package:buildvibes/features/profile/profile_screen.dart';
import 'package:buildvibes/features/settings/notifications_screen.dart';
import 'package:buildvibes/features/settings/push_host.dart';
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
import '../test/helpers/push_fakes.dart';
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
  List<SpaceToday> today = const [],
  List<ActivityRow> rows = const [],
  FakeSpaceRepository? spaces,
  Map<String, Object> phone = const {},
  DateTime? now,
}) async {
  // test_screens/ is a test folder the analyzer doesn't know.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(phone);
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authUserIdProvider.overrideWithValue(AsyncData(me)),
    appGateProvider.overrideWithValue(AppGate.ready),
    clockProvider.overrideWithValue(() => now ?? DaybookSamples.thursday),
    activityRepositoryProvider.overrideWithValue(
      FakeActivityRepository(cards: needs, today: today, rows: rows),
    ),
    if (spaces != null) spaceRepositoryProvider.overrideWithValue(spaces),
    needsCardsProvider.overrideWith((ref) async => needs),
    daybookPhotoProvider.overrideWith((ref, path) => samplePhoto),
    postPhotoProvider.overrideWith((ref, path) => samplePhoto),
    localPhotoProvider.overrideWith((ref, path) => samplePhoto),
  ];
}

/// Pushes can't reach this phone (review 51 F9).
class _NotReaching extends PushHealthState {
  @override
  PushHealth build() => PushHealth.notReaching;
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

    Future<List<Override>> home({
      Map<String, Object> phone = const {},
      List<NeedsCard> needs = const [],
      List<SpaceToday> today = const [],
      FakeSpaceRepository? spaces,
      FakePostRepository? posts,
      DateTime? now,
    }) async => [
      ...await _base(
        me: DaybookSamples.islam,
        phone: phone,
        needs: needs,
        today: today,
        spaces: spaces,
        now: now,
      ),
      postRepositoryProvider.overrideWithValue(posts ?? homePosts()),
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

    // Review 50 F19 and F15, against H1 v3 2555:35276 (AR 2564:184): a
    // short post with no headline (the name centred with the avatar), a
    // long post and a short one, on a 12-hour phone, so the spine shows
    // "11:58" with "pm" (مساءً) under it.
    testWidgets('F19 Home feed cards, 12-hour spine [$lang]', (tester) async {
      TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .alwaysUse24HourFormatTestValue =
          false;
      // The 12-hour time fits the column in the app's fonts: the time on
      // its line, the part of the day on the smaller one under it.
      final type = lang == 'ar' ? BvType.arabic : BvType.latin;
      double width(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        return painter.width;
      }

      const room = BvSpineSpec.homeTimeColumn - BvSpineSpec.labelToSpine;
      expect(width('11:58', type.labelSm), lessThanOrEqualTo(room));
      expect(
        width(
          t('pm', 'مساءً'),
          type.metadata.copyWith(fontSize: BvSpineSpec.periodSize),
        ),
        lessThanOrEqualTo(room),
      );
      final posts = FakePostRepository(now: DaybookSamples.thursday)
        ..posts.addAll([
          Post(
            id: 'post-short-plain',
            authorId: DaybookSamples.lina,
            authorName: s.linaName,
            body: t(
              'Ducts on level 3 are in.',
              'تم تركيب مجاري الهواء في الطابق 3.',
            ),
            lang: lang,
            createdAt: DateTime(2026, 10, 15, 23, 58),
          ),
          Post(
            id: 'post-long',
            authorId: DaybookSamples.sara,
            authorName: s.saraName,
            authorHeadline: t(
              'Senior Structural Engineer',
              'مهندسة إنشائية أولى',
            ),
            authorCompany: t('Gulf Design Studio', 'جلف ديزاين ستوديو'),
            body: t(
              'Checked the transfer beams on the podium today with the team '
                  'and the BIM model side by side. Two openings for the '
                  'sleeves were 50 mm off; both are marked and the fix is in '
                  'the model now. Thanks to everyone who stayed late for it.',
              'راجعنا اليوم كمرات النقل في البوديوم مع الفريق والنموذج جنبًا '
                  'إلى جنب. فتحتان للأكمام كانتا منحرفتين 50 مم؛ تم تحديدهما '
                  'وأُضيف التعديل إلى النموذج. شكرًا لكل من بقي متأخرًا لأجل '
                  'ذلك.',
            ),
            lang: lang,
            createdAt: DateTime(2026, 10, 15, 21, 15),
          ),
          Post(
            id: 'post-short',
            authorId: DaybookSamples.omar,
            authorName: s.omarName,
            authorHeadline: t('MEP Foreman', 'رئيس عمال MEP'),
            authorCompany: t('Gulf Build Co.', 'جلف بيلد'),
            body: t(
              'Night shift starts at 8.',
              'الوردية الليلية تبدأ الساعة 8.',
            ),
            lang: lang,
            createdAt: DateTime(2026, 10, 15, 18, 40),
          ),
        ])
        ..home.addAll(['post-short-plain', 'post-long', 'post-short']);
      await shoot(
        tester,
        'F19-feed-cards',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(
          posts: posts,
          now: DateTime(2026, 10, 15, 23, 59),
        ),
      );
    });

    testWidgets('F19 the post page: three replies, one Replying to '
        '[$lang]', (tester) async {
      await warmSamplePhoto(tester);
      final posts = homePosts()
        ..repliesByPost['post-pour'] = [
          PostReply(
            id: 'reply-faisal',
            postId: 'post-pour',
            authorId: 'p-faisal',
            authorName: t('Faisal Al-Rashidi', 'فيصل الرشيدي'),
            body: t(
              'Great work. Was the slab cured with blankets overnight?',
              'عمل رائع. هل غُطّيت البلاطة بالبطانيات للمعالجة طوال الليل؟',
            ),
            createdAt: DateTime(2026, 10, 15, 7, 2),
          ),
          PostReply(
            id: 'reply-omar',
            postId: 'post-pour',
            authorId: DaybookSamples.omar,
            authorName: s.omarName,
            replyTo: 'reply-faisal',
            replyToPerson: 'p-faisal',
            body: t(
              'Yes, wet blankets until 6 this morning.',
              'نعم، بطانيات مبللة حتى السادسة صباحًا.',
            ),
            createdAt: DateTime(2026, 10, 15, 7, 40),
          ),
          PostReply(
            id: 'reply-mariam',
            postId: 'post-pour',
            authorId: 'p-mariam',
            authorName: t('Mariam Al-Sabah', 'مريم الصباح'),
            body: t('Thanks, team.', 'شكرًا للفريق.'),
            createdAt: DateTime(2026, 10, 15, 8, 15),
          ),
        ];
      await shoot(
        tester,
        'F19-post-page',
        lang,
        (_) => const Pushed(PostScreen(postId: 'post-pour')),
        overrides: await home(posts: posts),
        // The replies, under the post.
        before: (tester) async {
          await tester.scrollUntilVisible(
            find.byKey(const Key('reply-reply-reply-mariam')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
        },
      );
    });

    // Review 51 Part C (F3, F10, F1, F13). Home → Spaces has no v3 frame
    // of its own: the Needs you rows (2544:35068) and H1's header and tabs
    // (2555:35276, AR 2564:184) set its language.
    final khiran = t('Khiran villas — Finishing', 'فلل الخيران — التشطيبات');
    final salmiya = t('Salmiya Seafront', 'واجهة السالمية البحرية');
    FakeSpaceRepository mySpaces() {
      SpaceDetail detail(String id, String name, SpacePass pass) => SpaceDetail(
        id: id,
        name: name,
        myPass: pass,
        iAmAdmin: false,
        myRights: MemberRights(
          createItems: pass != SpacePass.viewer,
          markDone: pass != SpacePass.viewer,
        ),
      );
      return FakeSpaceRepository(now: DaybookSamples.thursday)
        ..spaces.addAll([
          SpaceSummary(
            id: DaybookSamples.space,
            name: s.spaceName,
            pass: SpacePass.lead,
            isAdmin: true,
            projectId: 'proj-kct',
            projectName: kct,
          ),
          SpaceSummary(
            id: 'space-khiran',
            name: khiran,
            pass: SpacePass.crew,
            isAdmin: false,
          ),
          SpaceSummary(
            id: 'space-salmiya',
            name: salmiya,
            pass: SpacePass.viewer,
            isAdmin: false,
          ),
        ])
        ..details[DaybookSamples.space] = s.detail()
        ..details['space-khiran'] = detail(
          'space-khiran',
          khiran,
          SpacePass.crew,
        )
        ..details['space-salmiya'] = detail(
          'space-salmiya',
          salmiya,
          SpacePass.viewer,
        );
    }

    final dayNeeds = [
      NeedsCard(
        kind: NeedsKind.youCheck,
        spaceId: DaybookSamples.space,
        spaceName: s.spaceName,
        at: DateTime(2026, 10, 15, 9, 40),
        workItemId: 'post-sleeves',
        workItemRef: 'KCT-021',
        workItemTitle: s.sleeves,
        actorName: s.omarName,
      ),
      NeedsCard(
        kind: NeedsKind.forYou,
        spaceId: DaybookSamples.space,
        spaceName: s.spaceName,
        at: DateTime(2026, 10, 15, 8),
        workItemId: 'post-rebar',
        workItemRef: 'KCT-024',
        workItemTitle: s.rebar().title,
        actorName: s.saraName,
        due: DateTime(2026, 10, 15),
      ),
    ];
    final dayNews = [
      // Already in Needs you: its Space shows only when.
      SpaceToday(
        spaceId: DaybookSamples.space,
        spaceName: s.spaceName,
        change: SpaceChange.workItem,
        at: DateTime(2026, 10, 15, 9, 40),
        workItemId: 'post-sleeves',
        workItemRef: 'KCT-021',
        workItemTitle: s.sleeves,
        eventKind: 'done',
        actorName: s.omarName,
      ),
      SpaceToday(
        spaceId: 'space-khiran',
        spaceName: khiran,
        change: SpaceChange.chat,
        at: DateTime(2026, 10, 15, 8, 25),
        threadId: 'thread-khiran',
        messageKind: 'text',
        messageBody: t(
          'Tiles for villa 3 arrive on Sunday morning.',
          'بلاط الفيلا 3 يصل صباح الأحد.',
        ),
        actorName: s.linaName,
      ),
    ];

    Future<void> spacesTab(WidgetTester tester) async {
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
    }

    testWidgets('C1 Home → Spaces: Needs you and Your Spaces [$lang]', (
      tester,
    ) async {
      await shoot(
        tester,
        'C1-home-spaces',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(
          needs: dayNeeds,
          today: dayNews,
          spaces: mySpaces(),
        ),
        before: spacesTab,
      );
    });

    testWidgets('C2 Home → Spaces with no Space yet [$lang]', (tester) async {
      await shoot(
        tester,
        'C2-home-spaces-empty',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(spaces: FakeSpaceRepository()),
        before: spacesTab,
      );
    });

    Future<void> create(WidgetTester tester) async {
      unawaited(
        showCreateChoice(
          tester.element(find.byType(HomeScreen)),
          onPost: () {},
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('C3 Create: Post to everyone or a work item [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'C3-create-choice',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(spaces: mySpaces()),
        before: create,
      );
    });

    testWidgets('C4 Create: which Space, the last one first [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'C4-create-pick-space',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: await home(
          spaces: mySpaces(),
          phone: {'last_space:${DaybookSamples.islam}': 'space-khiran'},
        ),
        before: (tester) async {
          await create(tester);
          await tester.tap(find.byKey(const Key('create-work-item')));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('C5 Activity: every row opens what it is about [$lang]', (
      tester,
    ) async {
      ActivityRow row(
        String id,
        ActivityKind kind,
        ActivityGroupKind group,
        DateTime at, {
        String? actor,
        String? actorId,
        String? item,
        String? ref,
        bool read = true,
        String? post,
        String? context,
      }) => ActivityRow(
        id: id,
        kind: kind,
        group: group,
        createdAt: at,
        spaceId: group == ActivityGroupKind.space ? DaybookSamples.space : null,
        spaceName: group == ActivityGroupKind.space ? s.spaceName : null,
        myPass: group == ActivityGroupKind.space ? 'lead' : null,
        workItemId: item == null ? null : 'post-$id',
        workItemRef: ref,
        workItemTitle: item,
        actorId: actorId,
        actorName: actor,
        read: read,
        postId: post,
        context: context,
      );
      final rows = [
        row(
          'done',
          ActivityKind.itemDone,
          ActivityGroupKind.space,
          DateTime(2026, 10, 15, 9, 40),
          actor: s.omarName,
          actorId: DaybookSamples.omar,
          item: s.sleeves,
          ref: 'KCT-021',
          read: false,
        ),
        row(
          'comment',
          ActivityKind.itemComment,
          ActivityGroupKind.space,
          DateTime(2026, 10, 15, 8, 10),
          actor: s.saraName,
          actorId: DaybookSamples.sara,
          item: s.rebar().title,
          ref: 'KCT-024',
        ),
        row(
          'follow',
          ActivityKind.follow,
          ActivityGroupKind.network,
          DateTime(2026, 10, 14, 18),
          actor: s.rakeshName,
          actorId: DaybookSamples.rakesh,
        ),
        row(
          'reply',
          ActivityKind.postReply,
          ActivityGroupKind.posts,
          DateTime(2026, 10, 14, 16),
          actor: s.linaName,
          actorId: DaybookSamples.lina,
          post: 'post-pour',
          context: t(
            'Great work on the night shift.',
            'عمل رائع في الوردية الليلية.',
          ),
        ),
      ];
      await shoot(
        tester,
        'C5-activity',
        lang,
        (context) => _withNav(context, 2, const ActivityScreen()),
        overrides: await _base(
          me: DaybookSamples.islam,
          needs: dayNeeds.take(1).toList(),
          rows: rows,
        ),
      );
    });

    // Review 51 F9: no Figma frame. The quiet line under Home's tabs when
    // pushes can't reach this phone, and in Settings → Notifications; on a
    // Xiaomi, Fix it's steps.
    final notReaching = [
      pushHealthProvider.overrideWith(_NotReaching.new),
      pushPermissionProvider.overrideWith(
        (ref) async => PushPermission.granted,
      ),
      pushMessagingProvider.overrideWithValue(
        FakePushMessaging(makers: const ['xiaomi', 'redmi']),
      ),
      pushRepositoryProvider.overrideWithValue(FakePushRepository()),
    ];

    testWidgets('F9 Home: notifications not reaching this phone [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'F9-home-not-reaching',
        lang,
        (context) => _withNav(context, 0, const HomeScreen()),
        overrides: [...await home(), ...notReaching],
      );
    });

    testWidgets('F9 Settings → Notifications: the same line [$lang]', (
      tester,
    ) async {
      await shoot(
        tester,
        'F9-settings-not-reaching',
        lang,
        (context) => const Pushed(NotificationsScreen()),
        overrides: [
          ...await _base(me: DaybookSamples.islam),
          ...notReaching,
        ],
      );
    });

    testWidgets('F9 Fix it on a Xiaomi: the steps [$lang]', (tester) async {
      await shoot(
        tester,
        'F9-fix-it-xiaomi',
        lang,
        (context) => const Pushed(NotificationsScreen()),
        overrides: [
          ...await _base(me: DaybookSamples.islam),
          ...notReaching,
        ],
        before: (tester) async {
          await tester.tap(
            find.descendant(
              of: find.byKey(const Key('push-not-reaching')),
              matching: find.byType(InkWell),
            ),
          );
          await tester.pumpAndSettle();
        },
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
