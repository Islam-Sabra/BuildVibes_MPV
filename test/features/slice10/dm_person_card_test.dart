import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/features/profile/person_profile_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/dm_fakes.dart';
import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 10, 15, 11);

DmThreadPage _page(
  int count, {
  DmState state = DmState.open,
  bool former = false,
}) => DmThreadPage(
  threadId: 't-omar',
  person: DmPerson(
    id: 'p-omar',
    name: 'Omar Haddad',
    headline: 'Site Engineer',
    company: 'Al Hamra Contracting',
    former: former,
  ),
  state: state,
  sharedSpaceId: 's-kct',
  sharedSpaceName: 'Kuwait City Tower',
  messages: [
    for (var i = 0; i < count; i++)
      DmMessage(
        id: 'm$i',
        fromMe: i.isOdd,
        kind: ChatKind.text,
        createdAt: _now.subtract(Duration(minutes: 10 + i)),
        body: 'Message $i',
      ),
  ],
);

Future<void> _open(WidgetTester tester) async {
  GoRouter.of(
    tester.element(find.byType(Scaffold).first),
  ).push('/messages/t-omar');
  await tester.pumpAndSettle();
}

/// F98 (review 50, review 87): who a conversation is with, at its start.
void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final about = 'Site Engineer · ${inOwnDirection('Al Hamra Contracting')}';

    testWidgets('F98: a new conversation starts with the person card above '
        'the first message; View profile opens them [$lang]', (tester) async {
      final dm = FakeDmRepository()..pages['t-omar'] = _page(1);
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _open(tester);
      final card = find.byKey(const Key('dm-person-card'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(about)),
        findsOneWidget,
      );
      expect(find.text(l10n.dmStartLine), findsOneWidget);
      // Above the first message, which stays down by the typing box.
      final first = find.byKey(const Key('chat-message-m0'));
      expect(
        tester.getBottomLeft(card).dy,
        lessThanOrEqualTo(tester.getTopLeft(first).dy),
      );
      expect(
        tester.getBottomLeft(first).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('chat-input'))).dy - 200,
        ),
      );
      // The Space you share stays in DM2's pill, once.
      expect(
        find.text(l10n.dmBothIn(inOwnDirection('Kuwait City Tower'))),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('dm-view-profile')));
      await tester.pumpAndSettle();
      expect(find.byType(PersonProfileScreen), findsOneWidget);
    });

    testWidgets('F98: with 30 messages it is at the top, scrolled away '
        '[$lang]', (tester) async {
      final dm = FakeDmRepository()..pages['t-omar'] = _page(30);
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _open(tester);
      expect(find.byKey(const Key('dm-person-card')), findsNothing);
      await tester.drag(
        find.byKey(const Key('dm-messages')),
        const Offset(0, 4000),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-person-card')), findsOneWidget);
    });

    testWidgets('F98: a full page reaches back past the start: no card '
        '[$lang]', (tester) async {
      final dm = FakeDmRepository()..pages['t-omar'] = _page(50);
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _open(tester);
      await tester.drag(
        find.byKey(const Key('dm-messages')),
        const Offset(0, 8000),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-person-card')), findsNothing);
    });

    testWidgets('F98: a request shows the card with its strip [$lang]', (
      tester,
    ) async {
      final dm = FakeDmRepository()
        ..pages['t-omar'] = _page(1, state: DmState.request);
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _open(tester);
      expect(find.byKey(const Key('dm-person-card')), findsOneWidget);
      expect(find.byKey(const Key('dm-request-strip')), findsOneWidget);
    });

    testWidgets('F98: a deleted account has no View profile [$lang]', (
      tester,
    ) async {
      final dm = FakeDmRepository()..pages['t-omar'] = _page(1, former: true);
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _open(tester);
      expect(find.byKey(const Key('dm-person-card')), findsOneWidget);
      expect(find.byKey(const Key('dm-view-profile')), findsNothing);
    });
  }
}
