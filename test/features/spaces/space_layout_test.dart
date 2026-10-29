// Review 105 Part 1 (SP1 2666:38461, AR 2666:38593): the Space's bottom
// tab bar goes. A Work · Chat switch sits under the header, Chat with its
// unread count; Library and People are icons in the header beside Search,
// People with a dot while join requests wait. The ⋯ goes: the Space's name
// opens Space info, which holds what ⋯ held. The post bar is the bottom
// of the screen. Arabic mirrors: the back arrow on the right, Work at the
// right. In English and Arabic.
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/chat/chat_tab.dart';
import 'package:buildvibes/features/home/home_screen.dart';
import 'package:buildvibes/features/library/library_tab.dart';
import 'package:buildvibes/features/spaces/people_tab.dart';
import 'package:buildvibes/features/spaces/space_info_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_tab.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_bottom_bar.dart';
import 'package:buildvibes/shared/widgets/bv_post_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _space = 'space-1';
const _omar = SpacePerson(id: 'user-1', firstName: 'Omar', lastName: 'Haddad');
const _anil = SpacePerson(id: 'p-anil', firstName: 'Anil', lastName: 'Menon');

FakeSpaceRepository _spaces({bool admin = true, bool waiting = false}) {
  final spaces = FakeSpaceRepository(now: testNow);
  spaces.details[_space] = SpaceDetail(
    id: _space,
    name: 'Kuwait City Tower',
    myPass: SpacePass.lead,
    iAmAdmin: admin,
    myRights: MemberRights(invite: admin, createItems: true),
  );
  spaces.spaces.add(
    const SpaceSummary(
      id: _space,
      name: 'Kuwait City Tower',
      pass: SpacePass.lead,
      isAdmin: true,
    ),
  );
  spaces.spacePeople[_space] = SpacePeople(
    requests: [
      if (waiting)
        SpaceJoinRequest(id: 'req-1', person: _anil, createdAt: testNow),
    ],
    members: [
      SpaceMember(
        person: _omar,
        pass: SpacePass.lead,
        isAdmin: admin,
        confirmedAt: testNow,
      ),
    ],
  );
  return spaces;
}

Future<void> _open(
  WidgetTester tester,
  String lang, {
  FakeSpaceRepository? spaces,
  int unread = 0,
}) async {
  await pumpApp(
    tester,
    language: lang,
    spaces: spaces ?? _spaces(),
    chat: FakeChatRepository(now: testNow)
      ..threadsBySpace[_space] = [
        ChatThread(id: 'thread-all', unread: unread),
        ChatThread(id: 'thread-mep', teamId: 'team-mep', unread: unread),
      ],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space');
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    group('Part 1 the Space\'s layout [$lang]', () {
      testWidgets('no tab bar and no ⋯; Search, Library and People in the '
          'header; the Work · Chat switch under it, on Work', (tester) async {
        await _open(tester, lang);
        expect(find.byType(BvBottomBar), findsNothing);
        expect(_key('space-more'), findsNothing);
        for (final k in ['space-search', 'space-library', 'space-people']) {
          expect(_key(k), findsOneWidget, reason: k);
        }
        expect(_key('space-switch'), findsOneWidget);
        expect(
          tester.getRect(_key('space-switch')).top,
          greaterThanOrEqualTo(tester.getRect(_key('space-header')).bottom),
        );
        expect(find.byType(DaybookTab), findsOneWidget);
        expect(find.byType(ChatTab), findsNothing);
      });

      testWidgets('Chat shows its unread count; tapping it shows Chat, and '
          'Work goes back', (tester) async {
        await _open(tester, lang, unread: 1);
        expect(
          find.descendant(
            of: _key('space-chat-unread'),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('space-switch-chat'));
        expect(find.byType(ChatTab), findsOneWidget);
        expect(find.byType(DaybookTab), findsNothing);
        await _tap(tester, _key('space-switch-work'));
        expect(find.byType(DaybookTab), findsOneWidget);
      });

      testWidgets('nothing unread: no count', (tester) async {
        await _open(tester, lang);
        expect(_key('space-chat-unread'), findsNothing);
      });

      testWidgets('People opens the Space\'s people; Library its Library', (
        tester,
      ) async {
        await _open(tester, lang);
        await _tap(tester, _key('space-people'));
        expect(find.byType(PeopleTab), findsOneWidget);
        expect(find.text(l10n.spacesTabPeople), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await _tap(tester, _key('space-library'));
        expect(find.byType(LibraryTab), findsOneWidget);
        expect(find.text(l10n.spacesTabLibrary), findsOneWidget);
      });

      testWidgets('People carries a dot while join requests wait', (
        tester,
      ) async {
        await _open(tester, lang, spaces: _spaces(waiting: true));
        expect(_key('space-people-dot'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await _open(tester, lang);
        expect(_key('space-people-dot'), findsNothing);
      });

      testWidgets('the name opens Space info, which holds what ⋯ held: '
          'the week report and the daily report (Walk is in the camera)', (
        tester,
      ) async {
        await _open(tester, lang);
        await _tap(tester, _key('space-header'));
        expect(find.byType(SpaceInfoScreen), findsOneWidget);
        for (final k in ['info-week', 'info-report']) {
          expect(_key(k), findsOneWidget, reason: k);
        }
        expect(_key('info-walk'), findsNothing);
        // The daily report opens on Work, writing it.
        await _tap(tester, _key('info-report'));
        expect(find.byType(SpaceInfoScreen), findsNothing);
        expect(find.byType(DaybookTab), findsOneWidget);
        expect(_key('report-writing'), findsOneWidget);
      });

      testWidgets('the post bar is the bottom of the screen', (tester) async {
        await _open(tester, lang);
        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        final bar = tester.getRect(find.byType(BvPostBar));
        final pad = MediaQuery.of(
          tester.element(find.byType(BvPostBar)),
        ).padding.bottom;
        expect(bar.bottom, closeTo(size.height - pad, 1));
      });

      testWidgets('J1: opened with nothing under it (a link, a '
          'notification), back is still there and goes to Home\'s Spaces', (
        tester,
      ) async {
        await pumpApp(tester, language: lang, spaces: _spaces());
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).go('/spaces/$_space');
        await tester.pumpAndSettle();
        expect(_key('space-back'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('space-back'),
            matching: find.byIcon(BvIcons.arrowBack),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('space-back'));
        expect(find.byType(SpaceScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(
          ProviderScope.containerOf(
            tester.element(find.byType(HomeScreen)),
          ).read(homeTabProvider),
          HomeScreen.spacesTab,
        );
      });

      testWidgets('it mirrors in Arabic: the back arrow, then Work first in '
          'the reading direction', (tester) async {
        await _open(tester, lang);
        final width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final back = tester.getCenter(_key('space-back')).dx;
        final work = tester.getCenter(_key('space-switch-work')).dx;
        final chat = tester.getCenter(_key('space-switch-chat')).dx;
        if (lang == 'ar') {
          expect(back, greaterThan(width / 2));
          expect(work, greaterThan(chat));
        } else {
          expect(back, lessThan(width / 2));
          expect(work, lessThan(chat));
        }
      });
    });
  }
}
