/// Route paths. Entry and onboarding sit outside the tab shell.
abstract final class AppRoutes {
  // Tabs
  static const home = '/home';
  static const explore = '/explore';
  static const activity = '/activity';
  static const profile = '/profile';

  // Profile (inside the Profile tab)
  static const profileSettings = '/profile/settings';
  static const profileNotifications = '/profile/settings/notifications';
  static const profileBlocked = '/profile/settings/blocked';
  static const profileAccount = '/profile/settings/account';
  static const profileDownload = '/profile/settings/account/download';
  static const profileDelete = '/profile/settings/account/delete';
  static const profileDeleteBlocked =
      '/profile/settings/account/delete/blocked';
  static const profileDeleteConfirm =
      '/profile/settings/account/delete/confirm';
  static const profilePrivacy = '/profile/settings/privacy';
  static const profileRegion = '/profile/settings/region';
  static const profileEdit = '/profile/edit';
  static const profileEditBasics = '/profile/edit/basics';
  static const profileEditAbout = '/profile/edit/about';
  static const profileEditExperience = '/profile/edit/experience';
  static const profileEditExperienceForm = '/profile/edit/experience/form';
  static const profileEditOpenTo = '/profile/edit/open-to';
  static const profileEditProjects = '/profile/edit/projects';
  static const profileDelivered = '/profile/delivered';

  /// Debug builds only.
  static const components = '/profile/settings/components';

  // Full screens over the tabs
  static const people = '/people';

  /// Needs you, across all Spaces (2544:35068).
  static const needs = '/needs';

  /// My notebook (slice 8, Home's notebook icon) and My calendar,
  /// opened from the notebook's header (review 83).
  static const notebook = '/notebook';
  static const calendar = '/notebook/calendar';

  /// Review 99A: "New entry" (its page chip under it), a page and the
  /// notebook's search.
  static const notebookWrite = '/notebook/write';
  static String notebookPage(String id, {String? entry}) => Uri(
    path: '/notebook/pages/$id',
    queryParameters: entry == null ? null : {'entry': entry},
  ).toString();
  static const notebookSearch = '/notebook/search';

  /// Deleted items (review 99B B3, PG8).
  static const notebookDeleted = '/notebook/deleted';

  /// Search with the Filter that is on (review 100 Part 8; its STATUS,
  /// review 106 T3).
  static String notebookSearchIn({
    String? kind,
    String? status,
    String? page,
  }) => Uri(
    path: notebookSearch,
    queryParameters: {'kind': ?kind, 'status': ?status, 'page': ?page},
  ).toString();

  /// Review 100 Part 3b: a page's archived entries ("Archived ›").
  static String notebookArchived(String id, {String? entry}) => Uri(
    path: '/notebook/pages/$id/archived',
    queryParameters: entry == null ? null : {'entry': entry},
  ).toString();

  /// Direct messages (slice 3): the list, the requests, a thread, and a
  /// new conversation with a person (its thread is made by the first
  /// message). A push opens `/messages/<thread>`.
  static const messages = '/messages';
  static const messagesRequests = '/messages/requests';
  static String messagesThread(String threadId) => '/messages/$threadId';
  static String messagesWith(String profileId) => '/messages/with/$profileId';

  /// F78: "New message", a people search; a tap writes to the person.
  static const messagesNew = '/messages/new';

  /// F78: Home's "Search people"; a tap opens the profile.
  static const peopleSearch = '/people/search';
  static String person(String profileId) => '/people/$profileId';

  static String personWork(String profileId, String itemId) =>
      '/people/$profileId/work/$itemId';
  static const projects = '/projects';

  // R3 and R4: something of yours that was removed, and its appeal.
  static const removals = '/removals';
  static String removal(String id) => '/removals/$id';
  static String removalAppeal(String id) => '/removals/$id/appeal';

  // Posts. "new" before ":id".
  static const posts = '/posts';

  /// A post; with [reply], scrolled to that reply (the feed card's latest
  /// reply line, review 50 F30).
  static String post(String id, {String? reply}) =>
      reply == null ? '/posts/$id' : '/posts/$id?reply=$reply';
  static const projectsAdd = '/projects/add';
  static const projectsNew = '/projects/new';

  // Spaces (full screens over the tabs). "new" before ":id".
  static const spaces = '/spaces';
  static const spacesNew = '/spaces/new';
  static String space(String id) => '/spaces/$id';

  /// The Space on its Chat tab: what lies under a Space thread (F105).
  static String spaceChat(String id) => Uri(
    path: space(id),
    queryParameters: {spaceTabParam: spaceChatTab},
  ).toString();
  static const spaceTabParam = 'tab';
  static const spaceChatTab = 'chat';

  /// The Space's daybook at one work item's card, and at one line of its
  /// history (F20): what an Activity row, a push and a Needs you card open.
  static String spaceCard(String id, String postId, {String? eventId}) => Uri(
    path: space(id),
    queryParameters: {
      spaceCardParam: postId,
      if (eventId != null && eventId.isNotEmpty) spaceEventParam: eventId,
    },
  ).toString();
  static const spaceCardParam = 'card';
  static const spaceEventParam = 'event';
  static String spaceInvite(String id) => '/spaces/$id/invite';
  static String spaceMember(String id, String profileId) =>
      '/spaces/$id/members/$profileId';
  static String spaceInfo(String id) => '/spaces/$id/info';

  /// Review 105 Part 1: the Space's People and Library, from its header.
  static String spacePeople(String id) => '/spaces/$id/people';
  static String spaceLibrary(String id) => '/spaces/$id/library';
  static String spaceTransfer(String id) => '/spaces/$id/transfer';
  static String spaceTeamNew(String id) => '/spaces/$id/teams/new';
  static String spaceTeam(String id, String teamId) =>
      '/spaces/$id/teams/$teamId';
  static String spaceThread(String id, String threadId, {String? message}) =>
      Uri(
        path: '/spaces/$id/chat/$threadId',
        queryParameters: message == null ? null : {threadMessageParam: message},
      ).toString();

  /// A thread opened at one message (S Search): scrolled to it,
  /// highlighted.
  static const threadMessageParam = 'message';

  /// R3 · a chat message's lines into work items (slice 9); the message
  /// goes as the route's extra.
  static String spaceMeeting(String id, String threadId) =>
      '/spaces/$id/chat/$threadId/meeting';

  /// MR1 · the week report (slice 9), at the week from [week] (its first
  /// day), or this week.
  static String spaceWeekReport(String id, {DateTime? week}) => Uri(
    path: '/spaces/$id/week',
    queryParameters: week == null
        ? null
        : {
            weekParam:
                '${week.year.toString().padLeft(4, '0')}-'
                '${week.month.toString().padLeft(2, '0')}-'
                '${week.day.toString().padLeft(2, '0')}',
          },
  ).toString();
  static const weekParam = 'week';

  /// R1 · Walk mode (slice 6).
  static String spaceWalk(String id) => '/spaces/$id/walk';

  /// S · Search inside a Space.
  static String spaceSearch(String id) => '/spaces/$id/search';

  /// Space info › Templates (slice 7): a Lead's or a Space admin's.
  static String spaceTemplates(String id) => '/spaces/$id/templates';

  /// F1: the file full screen, on the drawing table.
  static String libraryFile(String id, String fileId) =>
      '/spaces/$id/library/$fileId';

  /// LV2: a file's page, its versions and who received it. It pops the
  /// version in use when "Add a new version" is chosen.
  static String libraryFilePage(String id, String fileId) =>
      '/spaces/$id/library/$fileId/page';

  // Entry (signed out)
  static const loading = '/loading';

  /// S14: deletion scheduled. The only screen until restored.
  static const scheduled = '/scheduled';
  static const welcome = '/welcome';
  static const join = '/join';
  static const joinPhone = '/join/phone';
  static const joinEmail = '/join/email';
  static const joinCode = '/join/code';

  // Onboarding (review 107): your name (OB4), your work (OB5), then your
  // Space (OB6). The role picker stays for Edit profile.
  static const onboarding = '/onboarding';
  static const onboardingName = '/onboarding/name';
  static const onboardingWork = '/onboarding/work';
  static const onboardingSpace = '/onboarding/space';
  static const onboardingRole = '/onboarding/role';
}
