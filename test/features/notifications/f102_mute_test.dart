// F102 (review 50): mute for a time, the bell-slash on muted rows, long-press
// Mute / Unmute, opening a conversation clears its phone notification, and
// what the in-app banner says for a push. EN and AR.
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/messages/dm_live.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_mute_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/dm_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

final _now = DateTime(2026, 10, 15, 11);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _hold(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.longPress(f.first);
  await tester.pumpAndSettle();
}

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
  await tester.pumpAndSettle();
}

DmRow _row(
  String thread,
  String name, {
  bool muted = false,
  bool unread = false,
}) => DmRow(
  threadId: thread,
  person: DmPerson(id: 'p-$thread', name: name),
  lastMessageAt: DateTime(2026, 10, 15, 10, 42),
  muted: muted,
  unread: unread,
  last: DmPreview(
    fromMe: false,
    kind: ChatKind.text,
    at: DateTime(2026, 10, 15, 10, 42),
    text: 'Pump is late',
  ),
);

FakeDmRepository _dm() => FakeDmRepository()
  ..inboxValue = DmInbox(
    threads: [
      _row('t-omar', 'Omar Haddad', muted: true, unread: true),
      _row('t-sara', 'Sara Ali'),
    ],
  )
  ..pages['t-omar'] = const DmThreadPage(
    threadId: 't-omar',
    person: DmPerson(id: 'p-t-omar', name: 'Omar Haddad'),
    muted: true,
  );

FakeSpaceRepository _spaces() =>
    FakeSpaceRepository(now: testNow)
      ..spaces.addAll(const [
        SpaceSummary(
          id: 'space-1',
          name: 'Tower B — Site team',
          pass: SpacePass.crew,
          isAdmin: false,
          notify: SpaceNotify.off,
        ),
        SpaceSummary(
          id: 'space-2',
          name: 'Khiran villas',
          pass: SpacePass.lead,
          isAdmin: true,
        ),
      ]);

void main() {
  group('the rules', () {
    test('8 hours, 1 week and Always end when they should', () {
      expect(
        MuteFor.eightHours.until(_now),
        _now.add(const Duration(hours: 8)),
      );
      expect(MuteFor.oneWeek.until(_now), _now.add(const Duration(days: 7)));
      expect(MuteFor.always.until(_now), isNull);
    });

    test('my_spaces gives the level in force: anything but All is muted', () {
      SpaceSummary row(String notify) => SpaceSummary.fromJson({
        'space_id': 's',
        'name': 'S',
        'pass': 'crew',
        'notify': notify,
      });
      expect(row('off').muted, isTrue);
      expect(row('needs_you').muted, isTrue);
      expect(row('all').muted, isFalse);
    });

    test('the bell-slash is Phosphor bell-slash, through BvIcons', () {
      expect(BvIcons.muted, BvIcons.notificationsOff);
      expect(BvIcons.muted.codePoint, 0xe0d4);
      expect(BvIcons.muted.fontFamily, 'PhosphorRegular');
    });
  });

  group('the in-app banner for a push (app open)', () {
    final l10n = _l10n('en');
    final ar = _l10n('ar');
    final name = inOwnDirection('Omar Haddad');

    test(
      'text on: "Message from Omar Haddad" over the newest words, no count',
      () {
        final b = dmPushBanner(
          {
            'kind': 'dm_message',
            'count': '3',
            'shown': '1',
            // Review 89 M3: the count is in the title.
            pushTitleKey: '$name · 3 new messages',
            pushBodyKey: 'Pump is late',
          },
          l10n,
          showText: true,
        );
        expect(b.title, l10n.dmBannerTitle(name));
        expect(b.body, 'Pump is late');
        expect(b.hidden, isFalse);
      },
    );

    test('text on, one message: the words as they are, even with a ·', () {
      final b = dmPushBanner(
        {
          'kind': 'dm_message',
          'count': '1',
          'shown': '1',
          pushTitleKey: name,
          pushBodyKey: 'Gate 3 · north side',
        },
        ar,
        showText: true,
      );
      expect(b.title, ar.dmBannerTitle(name));
      expect(b.body, 'Gate 3 · north side');
    });

    test(
      'text off: hidden, "New message", so the banner counts itself (F101)',
      () {
        final b = dmPushBanner(
          {
            'kind': 'dm_message',
            'count': '3',
            pushTitleKey: l10n.dmBannerTitle(name),
            pushBodyKey: '3 new messages',
          },
          l10n,
          showText: true,
        );
        expect(b.title, l10n.dmBannerTitle(name));
        expect(b.body, l10n.dmBannerHidden);
        expect(b.hidden, isTrue);
        expect(
          dmPushBanner(
            {
              'kind': 'dm_message',
              'count': '2',
              pushTitleKey: 'x',
              pushBodyKey: 'y',
            },
            ar,
            showText: false,
          ).body,
          ar.dmBannerHidden,
        );
      },
    );

    test(
      'a push from before migration 41 keeps its words, as the setting says',
      () {
        final b = dmPushBanner(
          {
            'kind': 'dm_message',
            pushTitleKey: 'Message from X',
            pushBodyKey: 'Hi',
          },
          l10n,
          showText: false,
        );
        expect((b.title, b.body, b.hidden), ('Message from X', 'Hi', true));
      },
    );
  });

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    group('[$lang]', () {
      testWidgets('the mute sheet: For how long? 8 hours, 1 week, Always', (
        tester,
      ) async {
        final dm = _dm()
          ..pages['t-sara'] = const DmThreadPage(
            threadId: 't-sara',
            person: DmPerson(id: 'p-t-sara', name: 'Sara Ali'),
          );
        await pumpApp(tester, language: lang, dm: dm, now: _now);
        await _go(tester, '/messages/t-sara');
        await _tap(tester, find.byKey(const Key('dm-more')));
        await _tap(tester, find.byKey(const Key('dm-menu-mute')));
        expect(find.byKey(const Key('mute-sheet')), findsOneWidget);
        expect(find.text(l10n.muteForHowLong), findsOneWidget);
        for (final (key, text) in [
          ('mute-for-eightHours', l10n.muteFor8Hours),
          ('mute-for-oneWeek', l10n.muteFor1Week),
          ('mute-for-always', l10n.muteForAlways),
        ]) {
          expect(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.text(text),
            ),
            findsOneWidget,
          );
        }
        // One single choice: a tap picks and closes.
        await _tap(tester, find.byKey(const Key('mute-for-always')));
        expect(find.byKey(const Key('mute-sheet')), findsNothing);
        expect(dm.calls, contains('mute t-sara true'));
      });

      testWidgets('a muted conversation: bell-slash beside the name, unread '
          'dot kept; long-press Unmute and Mute', (tester) async {
        final dm = _dm();
        await pumpApp(tester, language: lang, dm: dm, now: _now);
        await _go(tester, '/messages');
        final omar = find.byKey(const Key('messages-row-t-omar'));
        expect(
          find.descendant(
            of: omar,
            matching: find.byKey(const Key('messages-muted-t-omar')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: omar, matching: find.byIcon(BvIcons.muted)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: omar,
            matching: find.byKey(const Key('messages-unread-dot')),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('messages-muted-t-sara')), findsNothing);

        await _hold(tester, omar);
        expect(find.text(l10n.muteUnmute), findsOneWidget);
        await _tap(tester, find.byKey(const Key('mute-menu-unmute')));
        expect(find.byKey(const Key('mute-sheet')), findsNothing);
        expect(dm.calls, contains('mute t-omar false'));

        await _hold(tester, find.byKey(const Key('messages-row-t-sara')));
        expect(find.text(l10n.muteMute), findsOneWidget);
        await _tap(tester, find.byKey(const Key('mute-menu-mute')));
        await _tap(tester, find.byKey(const Key('mute-for-eightHours')));
        expect(
          dm.calls,
          contains(
            'mute t-sara true until '
            '${_now.add(const Duration(hours: 8)).toIso8601String()}',
          ),
        );
      });

      testWidgets('Home → Spaces: a muted Space shows the bell-slash; '
          'long-press Mute asks for how long', (tester) async {
        final spaces = _spaces();
        await pumpApp(tester, language: lang, spaces: spaces);
        await tester.tap(find.text(l10n.homeSpaces));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('home-space-muted-space-1')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('home-space-muted-space-2')), findsNothing);

        await _hold(tester, find.byKey(const Key('home-space-space-2')));
        await _tap(tester, find.byKey(const Key('mute-menu-mute')));
        expect(find.text(l10n.muteForHowLong), findsOneWidget);
        await _tap(tester, find.byKey(const Key('mute-for-oneWeek')));
        expect(
          spaces.calls.last,
          'notify off until '
          '${testNow.add(const Duration(days: 7)).toIso8601String()}',
        );
        // The list reads again: now both are muted.
        expect(
          find.byKey(const Key('home-space-muted-space-2')),
          findsOneWidget,
        );

        await _hold(tester, find.byKey(const Key('home-space-space-1')));
        await _tap(tester, find.byKey(const Key('mute-menu-unmute')));
        expect(spaces.calls.last, 'notify all');
        expect(find.byKey(const Key('home-space-muted-space-1')), findsNothing);
      });

      testWidgets('My Spaces: the bell-slash and long-press Mute too', (
        tester,
      ) async {
        final spaces = _spaces();
        await pumpApp(tester, language: lang, spaces: spaces);
        await _go(tester, '/spaces');
        expect(find.byKey(const Key('space-muted-space-1')), findsOneWidget);
        expect(find.byKey(const Key('space-muted-space-2')), findsNothing);
        await _hold(tester, find.byKey(const Key('space-row-space-2')));
        await _tap(tester, find.byKey(const Key('mute-menu-mute')));
        // Dismissed: nothing changes.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(spaces.calls.where((c) => c.startsWith('notify')), isEmpty);
      });

      testWidgets('opening a conversation clears its phone notification', (
        tester,
      ) async {
        final push = FakePushMessaging(current: PushPermission.granted);
        await pumpApp(tester, language: lang, dm: _dm(), push: push, now: _now);
        expect(push.cleared, isEmpty);
        await _go(tester, '/messages/t-omar');
        expect(push.cleared, contains('t-omar'));
      });
    });
  }
}
