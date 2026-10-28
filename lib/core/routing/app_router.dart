import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/activity_screen.dart';
import '../../data/models/dm.dart';
import '../../data/models/library.dart';
import '../../features/activity/needs_you_screen.dart';
import '../../data/models/chat.dart';
import '../../features/chat/meeting_notes_screen.dart';
import '../../features/messages/dm_thread_screen.dart';
import '../../features/spaces/week_report_screen.dart';
import '../../features/notebook/calendar_screen.dart';
import '../../features/notebook/deleted_items_screen.dart';
import '../../features/notebook/notebook_page_screen.dart';
import '../../features/notebook/notebook_screen.dart';
import '../../features/notebook/notebook_search_screen.dart';
import '../../features/messages/messages_screen.dart';
import '../../features/messages/people_search_screen.dart';
import '../../features/dev/components_gallery_screen.dart';
import '../../features/entry/code_screen.dart';
import '../../features/entry/email_screen.dart';
import '../../features/entry/entry_state.dart';
import '../../features/entry/join_screen.dart';
import '../../features/entry/loading_screen.dart';
import '../../features/entry/phone_screen.dart';
import '../../features/entry/welcome_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/about_you_screen.dart';
import '../../features/onboarding/people_screen.dart';
import '../../features/onboarding/role_picker_screen.dart';
import '../../data/models/profile.dart';
import '../../features/profile/delivered_work.dart';
import '../../features/profile/edit/about_screen.dart';
import '../../features/profile/edit/basics_screen.dart';
import '../../features/profile/edit/cv_projects_screen.dart';
import '../../features/profile/edit/edit_profile_screen.dart';
import '../../features/profile/edit/experience_screens.dart';
import '../../features/profile/edit/open_to_screen.dart';
import '../../features/profile/person_profile_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/account/account_screens.dart';
import '../../features/account/delete_screens.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/safety/blocked_screen.dart';
import '../../features/safety/removed_screen.dart';
import '../../features/settings/notifications_screen.dart';
import '../../features/projects/add_project_screen.dart';
import '../../features/projects/new_project_screen.dart';
import '../../features/projects/project_sheet_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/spaces/invite_screen.dart';
import '../../features/spaces/member_pass_screen.dart';
import '../../features/spaces/my_spaces_screen.dart';
import '../../features/spaces/new_space_screen.dart';
import '../../features/spaces/new_team_screen.dart';
import '../../features/spaces/space_info_screen.dart';
import '../../features/spaces/space_screen.dart';
import '../../features/work/daybook_target.dart';
import '../../features/chat/thread_screen.dart';
import '../../features/feed/post_screen.dart';
import '../../features/library/library_file_screen.dart';
import '../../features/spaces/space_search_screen.dart';
import '../../features/spaces/space_templates_screen.dart';
import '../../features/work/walk_screen.dart';
import '../../features/library/file_preview_screen.dart';
import '../../features/spaces/team_screen.dart';
import '../../features/spaces/transfer_screen.dart';
import 'app_routes.dart';

export 'app_routes.dart';

/// Where [gate] allows the app to be. Returns the path to go to instead of
/// [location], or null when [location] is fine.
String? redirectForGate(AppGate gate, String location) {
  bool under(String path) => location == path || location.startsWith('$path/');
  final inEntry = under(AppRoutes.welcome) || under(AppRoutes.join);
  final inOnboarding = under(AppRoutes.onboarding);
  final atLoading = location == AppRoutes.loading;
  final atScheduled = location == AppRoutes.scheduled;

  return switch (gate) {
    AppGate.loading ||
    AppGate.profileError => atLoading ? null : AppRoutes.loading,
    AppGate.signedOut => inEntry ? null : AppRoutes.welcome,
    AppGate.scheduled => atScheduled ? null : AppRoutes.scheduled,
    // Guests browse the tabs and may start joining at any time; people,
    // projects, Spaces and editing need an account.
    AppGate.guest =>
      inOnboarding ||
              atLoading ||
              atScheduled ||
              under(AppRoutes.people) ||
              under(AppRoutes.projects) ||
              under(AppRoutes.posts) ||
              under(AppRoutes.spaces) ||
              under(AppRoutes.needs) ||
              under(AppRoutes.notebook) ||
              under(AppRoutes.messages) ||
              under(AppRoutes.removals) ||
              under(AppRoutes.profileEdit)
          ? AppRoutes.home
          : null,
    // Step 1 must be done before anything else; step 2 needs step 1.
    AppGate.onboarding =>
      under(AppRoutes.onboardingAbout) || under(AppRoutes.onboardingRole)
          ? null
          : AppRoutes.onboardingAbout,
    // Done with onboarding: step 2 and the role picker (used by Edit
    // profile) stay open; step 1 sends Home.
    AppGate.ready =>
      inEntry || atLoading || atScheduled || under(AppRoutes.onboardingAbout)
          ? AppRoutes.home
          : null,
  };
}

/// Entry and onboarding sit outside the tabs. Each tab keeps its own
/// history (an indexed stack of branches). Create is not a tab: it writes
/// a post in place on Home.
/// A screen (review 100 B6): its [builder] is Flutter's [MaterialPage].
/// go_router looks for its own `material_ui` MaterialApp, another class
/// than the app's, so left to itself it built every screen with no
/// transition at all: no predictive back on Android, no edge swipe on an
/// iPhone. As a MaterialPage, a screen moves with the theme's transitions.
class _Screen extends GoRoute {
  _Screen({
    required super.path,
    GoRouterWidgetBuilder? builder,
    super.redirect,
    super.routes,
  }) : super(
         pageBuilder: builder == null
             ? null
             : (context, state) => MaterialPage<void>(
                 key: state.pageKey,
                 name: state.name ?? state.path,
                 arguments: <String, String>{
                   ...state.pathParameters,
                   ...state.uri.queryParameters,
                 },
                 restorationId: state.pageKey.value,
                 child: builder(context, state),
               ),
       );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // The router re-checks where it may be whenever the gate changes.
  final gate = ValueNotifier<AppGate>(ref.read(appGateProvider));
  ref.listen(appGateProvider, (_, next) => gate.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.loading,
    refreshListenable: gate,
    redirect: (context, state) =>
        redirectForGate(gate.value, state.matchedLocation),
    routes: [
      _Screen(
        path: AppRoutes.loading,
        builder: (context, state) => const LoadingScreen(),
      ),
      _Screen(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      _Screen(
        path: AppRoutes.scheduled,
        builder: (context, state) => const DeletionScheduledScreen(),
      ),
      _Screen(
        path: AppRoutes.join,
        builder: (context, state) => const JoinScreen(),
        routes: [
          _Screen(
            path: 'phone',
            redirect: (context, state) =>
                ref.read(phoneSignInProvider) ? null : AppRoutes.joinEmail,
            builder: (context, state) => const PhoneScreen(),
          ),
          _Screen(
            path: 'email',
            builder: (context, state) => const EmailScreen(),
          ),
          _Screen(
            path: 'code',
            builder: (context, state) => const CodeScreen(),
          ),
        ],
      ),
      _Screen(
        path: AppRoutes.onboardingAbout,
        builder: (context, state) => const AboutYouScreen(),
      ),
      _Screen(
        path: AppRoutes.onboardingRole,
        builder: (context, state) =>
            RolePickerScreen(args: state.extra! as RolePickerArgs),
      ),
      _Screen(
        path: AppRoutes.onboardingPeople,
        builder: (context, state) => const PeopleScreen(),
      ),
      // Before ":id" (F78).
      _Screen(
        path: AppRoutes.peopleSearch,
        builder: (context, state) =>
            const PeopleSearchScreen(purpose: PeopleSearchFor.profile),
      ),
      _Screen(
        path: '${AppRoutes.people}/:id',
        builder: (context, state) =>
            PersonProfileScreen(profileId: state.pathParameters['id']!),
        routes: [
          _Screen(
            path: 'work/:itemId',
            builder: (context, state) => DeliveredPublicScreen(
              profileId: state.pathParameters['id']!,
              itemId: state.pathParameters['itemId']!,
            ),
          ),
        ],
      ),
      // "add" and "new" before ":id".
      _Screen(
        path: AppRoutes.projectsAdd,
        builder: (context, state) => const AddProjectScreen(),
      ),
      _Screen(
        path: AppRoutes.projectsNew,
        builder: (context, state) =>
            NewProjectScreen(initialName: state.extra as String?),
      ),
      _Screen(
        path: '${AppRoutes.posts}/:id',
        builder: (context, state) => PostScreen(
          postId: state.pathParameters['id']!,
          replyId: state.uri.queryParameters['reply'],
        ),
      ),
      _Screen(
        path: '${AppRoutes.projects}/:id',
        builder: (context, state) =>
            ProjectSheetScreen(projectId: state.pathParameters['id']!),
      ),
      _Screen(
        path: AppRoutes.spaces,
        builder: (context, state) => const MySpacesScreen(),
      ),
      _Screen(
        path: AppRoutes.needs,
        builder: (context, state) => const NeedsYouScreen(),
      ),
      _Screen(
        path: AppRoutes.notebook,
        builder: (context, state) => const NotebookScreen(),
        routes: [
          _Screen(
            path: 'calendar',
            builder: (context, state) => const CalendarScreen(),
          ),
          _Screen(
            path: 'write',
            builder: (context, state) => const NotebookPageScreen.write(),
          ),
          _Screen(
            path: 'pages/:id/archived',
            builder: (context, state) => NotebookPageScreen.archived(
              key: ValueKey(('archived', state.pathParameters['id'])),
              pageId: state.pathParameters['id']!,
            ),
          ),
          _Screen(
            path: 'pages/:id',
            builder: (context, state) => NotebookPageScreen(
              key: ValueKey(state.pathParameters['id']),
              pageId: state.pathParameters['id']!,
              entry: state.uri.queryParameters['entry'],
            ),
          ),
          _Screen(
            path: 'deleted',
            builder: (context, state) => const DeletedItemsScreen(),
          ),
          _Screen(
            path: 'search',
            builder: (context, state) => NotebookSearchScreen(
              kind: state.uri.queryParameters['kind'],
              page: state.uri.queryParameters['page'],
            ),
          ),
        ],
      ),
      _Screen(
        path: AppRoutes.messages,
        builder: (context, state) => const MessagesScreen(),
        routes: [
          // "requests", "new" and "with" before ":thread".
          _Screen(
            path: 'new',
            builder: (context, state) =>
                const PeopleSearchScreen(purpose: PeopleSearchFor.message),
          ),
          _Screen(
            path: 'requests',
            builder: (context, state) => const MessageRequestsScreen(),
          ),
          _Screen(
            path: 'with/:profileId',
            builder: (context, state) => DmThreadScreen.withPerson(
              profileId: state.pathParameters['profileId']!,
              person: state.extra as DmPerson?,
            ),
          ),
          _Screen(
            path: ':thread',
            builder: (context, state) =>
                DmThreadScreen(threadId: state.pathParameters['thread']!),
          ),
        ],
      ),
      _Screen(
        path: '${AppRoutes.removals}/:id',
        builder: (context, state) =>
            RemovedScreen(removalId: state.pathParameters['id']!),
        routes: [
          _Screen(
            path: 'appeal',
            builder: (context, state) =>
                AppealScreen(removalId: state.pathParameters['id']!),
          ),
        ],
      ),
      // "new" before ":id".
      _Screen(
        path: AppRoutes.spacesNew,
        builder: (context, state) => const NewSpaceScreen(),
      ),
      _Screen(
        path: '${AppRoutes.spaces}/:id',
        builder: (context, state) => SpaceScreen(
          spaceId: state.pathParameters['id']!,
          open: state.extra as SpaceOpen?,
          target: DaybookTarget.fromQuery(state.uri.queryParameters),
          onChat:
              state.uri.queryParameters[AppRoutes.spaceTabParam] ==
              AppRoutes.spaceChatTab,
        ),
        routes: [
          _Screen(
            path: 'invite',
            builder: (context, state) =>
                InviteScreen(spaceId: state.pathParameters['id']!),
          ),
          _Screen(
            path: 'info',
            builder: (context, state) =>
                SpaceInfoScreen(spaceId: state.pathParameters['id']!),
          ),
          _Screen(
            path: 'transfer',
            builder: (context, state) =>
                TransferScreen(spaceId: state.pathParameters['id']!),
          ),
          _Screen(
            path: 'library/:fileId/page',
            builder: (context, state) => LibraryFileScreen(
              spaceId: state.pathParameters['id']!,
              fileId: state.pathParameters['fileId']!,
            ),
          ),
          _Screen(
            path: 'library/:fileId',
            builder: (context, state) => FilePreviewScreen(
              spaceId: state.pathParameters['id']!,
              fileId: state.pathParameters['fileId']!,
            ),
          ),
          _Screen(
            path: 'week',
            builder: (context, state) => WeekReportScreen(
              spaceId: state.pathParameters['id']!,
              week: DateTime.tryParse(
                state.uri.queryParameters[AppRoutes.weekParam] ?? '',
              ),
            ),
          ),
          _Screen(
            path: 'chat/:threadId',
            builder: (context, state) => ThreadScreen(
              spaceId: state.pathParameters['id']!,
              threadId: state.pathParameters['threadId']!,
              atMessage:
                  state.uri.queryParameters[AppRoutes.threadMessageParam],
              // F77: Share in chat's file, in the message box.
              shareFile: state.extra is LibraryFile
                  ? state.extra! as LibraryFile
                  : null,
            ),
            routes: [
              _Screen(
                path: 'meeting',
                redirect: (context, state) =>
                    state.extra is ChatMessage ? null : AppRoutes.home,
                builder: (context, state) => MeetingNotesScreen(
                  spaceId: state.pathParameters['id']!,
                  threadId: state.pathParameters['threadId']!,
                  message: state.extra! as ChatMessage,
                ),
              ),
            ],
          ),
          _Screen(
            path: 'walk',
            builder: (context, state) =>
                WalkScreen(spaceId: state.pathParameters['id']!),
          ),
          _Screen(
            path: 'search',
            builder: (context, state) =>
                SpaceSearchScreen(spaceId: state.pathParameters['id']!),
          ),
          _Screen(
            path: 'templates',
            builder: (context, state) =>
                SpaceTemplatesScreen(spaceId: state.pathParameters['id']!),
          ),
          // "new" before ":teamId".
          _Screen(
            path: 'teams/new',
            builder: (context, state) =>
                NewTeamScreen(spaceId: state.pathParameters['id']!),
          ),
          _Screen(
            path: 'teams/:teamId',
            builder: (context, state) => TeamScreen(
              spaceId: state.pathParameters['id']!,
              teamId: state.pathParameters['teamId']!,
            ),
          ),
          _Screen(
            path: 'members/:profileId',
            builder: (context, state) => MemberPassScreen(
              spaceId: state.pathParameters['id']!,
              profileId: state.pathParameters['profileId']!,
              open: state.extra as MemberPassOpen?,
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              _Screen(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _Screen(
                path: AppRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _Screen(
                path: AppRoutes.activity,
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _Screen(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  _Screen(
                    path: 'delivered',
                    builder: (context, state) => const DeliveredScreen(),
                  ),
                  _Screen(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      _Screen(
                        path: 'notifications',
                        builder: (context, state) =>
                            const NotificationsScreen(),
                      ),
                      _Screen(
                        path: 'blocked',
                        builder: (context, state) => const BlockedScreen(),
                      ),
                      _Screen(
                        path: 'privacy',
                        builder: (context, state) =>
                            const PrivacySafetyScreen(),
                      ),
                      _Screen(
                        path: 'region',
                        builder: (context, state) =>
                            const LanguageRegionScreen(),
                      ),
                      _Screen(
                        path: 'account',
                        builder: (context, state) =>
                            const AccountSecurityScreen(),
                        routes: [
                          _Screen(
                            path: 'download',
                            builder: (context, state) =>
                                const DownloadDataScreen(),
                          ),
                          _Screen(
                            path: 'delete',
                            builder: (context, state) =>
                                const DeleteAccountScreen(),
                            routes: [
                              _Screen(
                                path: 'blocked',
                                builder: (context, state) =>
                                    const DeleteBlockedScreen(),
                              ),
                              _Screen(
                                path: 'confirm',
                                builder: (context, state) =>
                                    const DeleteConfirmScreen(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (kDebugMode)
                        _Screen(
                          path: 'components',
                          builder: (context, state) =>
                              const ComponentsGalleryScreen(),
                        ),
                    ],
                  ),
                  _Screen(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                    routes: [
                      _Screen(
                        path: 'basics',
                        builder: (context, state) => const BasicsScreen(),
                      ),
                      _Screen(
                        path: 'about',
                        builder: (context, state) => const AboutScreen(),
                      ),
                      _Screen(
                        path: 'experience',
                        builder: (context, state) =>
                            const ExperienceListScreen(),
                        routes: [
                          _Screen(
                            path: 'form',
                            builder: (context, state) => ExperienceFormScreen(
                              entry: state.extra as ExperienceEntry?,
                            ),
                          ),
                        ],
                      ),
                      _Screen(
                        path: 'open-to',
                        builder: (context, state) => const OpenToScreen(),
                      ),
                      _Screen(
                        path: 'projects',
                        builder: (context, state) => const CvProjectsScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    gate.dispose();
  });
  return router;
});
