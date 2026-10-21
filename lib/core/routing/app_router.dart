import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/activity_screen.dart';
import '../../data/models/dm.dart';
import '../../features/activity/needs_you_screen.dart';
import '../../features/messages/dm_thread_screen.dart';
import '../../features/messages/messages_screen.dart';
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
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.scheduled,
        builder: (context, state) => const DeletionScheduledScreen(),
      ),
      GoRoute(
        path: AppRoutes.join,
        builder: (context, state) => const JoinScreen(),
        routes: [
          GoRoute(
            path: 'phone',
            redirect: (context, state) =>
                ref.read(phoneSignInProvider) ? null : AppRoutes.joinEmail,
            builder: (context, state) => const PhoneScreen(),
          ),
          GoRoute(
            path: 'email',
            builder: (context, state) => const EmailScreen(),
          ),
          GoRoute(
            path: 'code',
            builder: (context, state) => const CodeScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.onboardingAbout,
        builder: (context, state) => const AboutYouScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingRole,
        builder: (context, state) =>
            RolePickerScreen(args: state.extra! as RolePickerArgs),
      ),
      GoRoute(
        path: AppRoutes.onboardingPeople,
        builder: (context, state) => const PeopleScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.people}/:id',
        builder: (context, state) =>
            PersonProfileScreen(profileId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'work/:itemId',
            builder: (context, state) => DeliveredPublicScreen(
              profileId: state.pathParameters['id']!,
              itemId: state.pathParameters['itemId']!,
            ),
          ),
        ],
      ),
      // "add" and "new" before ":id".
      GoRoute(
        path: AppRoutes.projectsAdd,
        builder: (context, state) => const AddProjectScreen(),
      ),
      GoRoute(
        path: AppRoutes.projectsNew,
        builder: (context, state) =>
            NewProjectScreen(initialName: state.extra as String?),
      ),
      GoRoute(
        path: '${AppRoutes.posts}/:id',
        builder: (context, state) => PostScreen(
          postId: state.pathParameters['id']!,
          replyId: state.uri.queryParameters['reply'],
        ),
      ),
      GoRoute(
        path: '${AppRoutes.projects}/:id',
        builder: (context, state) =>
            ProjectSheetScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.spaces,
        builder: (context, state) => const MySpacesScreen(),
      ),
      GoRoute(
        path: AppRoutes.needs,
        builder: (context, state) => const NeedsYouScreen(),
      ),
      GoRoute(
        path: AppRoutes.messages,
        builder: (context, state) => const MessagesScreen(),
        routes: [
          // "requests" and "with" before ":thread".
          GoRoute(
            path: 'requests',
            builder: (context, state) => const MessageRequestsScreen(),
          ),
          GoRoute(
            path: 'with/:profileId',
            builder: (context, state) => DmThreadScreen.withPerson(
              profileId: state.pathParameters['profileId']!,
              person: state.extra as DmPerson?,
            ),
          ),
          GoRoute(
            path: ':thread',
            builder: (context, state) =>
                DmThreadScreen(threadId: state.pathParameters['thread']!),
          ),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.removals}/:id',
        builder: (context, state) =>
            RemovedScreen(removalId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'appeal',
            builder: (context, state) =>
                AppealScreen(removalId: state.pathParameters['id']!),
          ),
        ],
      ),
      // "new" before ":id".
      GoRoute(
        path: AppRoutes.spacesNew,
        builder: (context, state) => const NewSpaceScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.spaces}/:id',
        builder: (context, state) => SpaceScreen(
          spaceId: state.pathParameters['id']!,
          open: state.extra as SpaceOpen?,
          target: DaybookTarget.fromQuery(state.uri.queryParameters),
        ),
        routes: [
          GoRoute(
            path: 'invite',
            builder: (context, state) =>
                InviteScreen(spaceId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'info',
            builder: (context, state) =>
                SpaceInfoScreen(spaceId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'transfer',
            builder: (context, state) =>
                TransferScreen(spaceId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'library/:fileId/page',
            builder: (context, state) => LibraryFileScreen(
              spaceId: state.pathParameters['id']!,
              fileId: state.pathParameters['fileId']!,
            ),
          ),
          GoRoute(
            path: 'library/:fileId',
            builder: (context, state) => FilePreviewScreen(
              spaceId: state.pathParameters['id']!,
              fileId: state.pathParameters['fileId']!,
            ),
          ),
          GoRoute(
            path: 'chat/:threadId',
            builder: (context, state) => ThreadScreen(
              spaceId: state.pathParameters['id']!,
              threadId: state.pathParameters['threadId']!,
            ),
          ),
          // "new" before ":teamId".
          GoRoute(
            path: 'teams/new',
            builder: (context, state) =>
                NewTeamScreen(spaceId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'teams/:teamId',
            builder: (context, state) => TeamScreen(
              spaceId: state.pathParameters['id']!,
              teamId: state.pathParameters['teamId']!,
            ),
          ),
          GoRoute(
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
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.activity,
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'delivered',
                    builder: (context, state) => const DeliveredScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'notifications',
                        builder: (context, state) =>
                            const NotificationsScreen(),
                      ),
                      GoRoute(
                        path: 'blocked',
                        builder: (context, state) => const BlockedScreen(),
                      ),
                      GoRoute(
                        path: 'privacy',
                        builder: (context, state) =>
                            const PrivacySafetyScreen(),
                      ),
                      GoRoute(
                        path: 'region',
                        builder: (context, state) =>
                            const LanguageRegionScreen(),
                      ),
                      GoRoute(
                        path: 'account',
                        builder: (context, state) =>
                            const AccountSecurityScreen(),
                        routes: [
                          GoRoute(
                            path: 'download',
                            builder: (context, state) =>
                                const DownloadDataScreen(),
                          ),
                          GoRoute(
                            path: 'delete',
                            builder: (context, state) =>
                                const DeleteAccountScreen(),
                            routes: [
                              GoRoute(
                                path: 'blocked',
                                builder: (context, state) =>
                                    const DeleteBlockedScreen(),
                              ),
                              GoRoute(
                                path: 'confirm',
                                builder: (context, state) =>
                                    const DeleteConfirmScreen(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (kDebugMode)
                        GoRoute(
                          path: 'components',
                          builder: (context, state) =>
                              const ComponentsGalleryScreen(),
                        ),
                    ],
                  ),
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                    routes: [
                      GoRoute(
                        path: 'basics',
                        builder: (context, state) => const BasicsScreen(),
                      ),
                      GoRoute(
                        path: 'about',
                        builder: (context, state) => const AboutScreen(),
                      ),
                      GoRoute(
                        path: 'experience',
                        builder: (context, state) =>
                            const ExperienceListScreen(),
                        routes: [
                          GoRoute(
                            path: 'form',
                            builder: (context, state) => ExperienceFormScreen(
                              entry: state.extra as ExperienceEntry?,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'open-to',
                        builder: (context, state) => const OpenToScreen(),
                      ),
                      GoRoute(
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
