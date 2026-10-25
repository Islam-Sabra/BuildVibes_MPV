// Review 95: every post in a Space has its number, shown where a work
// item's ref shows: the card header, before its kind word, and the
// "Discuss in chat" quote. In English and Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _card(String id) => find.byKey(Key('daybook-card-$id'));

Future<void> _open(
  WidgetTester tester,
  String lang,
  List<DaybookCard> posts,
) async {
  final s = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: SpacePass.lead,
        admin: true,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = posts,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
}

DaybookCard _plain(String id, String kind, String title, String ref) =>
    DaybookCard(
      post: DaybookPost(
        id: id,
        ownRef: ref,
        kind: kind,
        createdAt: DateTime(2026, 10, 15, 8),
        title: title,
        authorId: DaybookSamples.sara,
        authorName: 'Sara Al-Mutairi',
      ),
      lastActivityAt: DateTime(2026, 10, 15, 8),
    );

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    testWidgets('a note, a checklist, an announcement, an activity, a file '
        'and a report show their number, then their kind [$lang]', (
      tester,
    ) async {
      final cards = [
        _plain('post-note', DaybookPost.noteKind, 'Gate 2 closed', 'KCT-041'),
        s.handover(ref: 'KCT-042'),
        _plain(
          'post-notice',
          DaybookPost.announcementKind,
          'Hot works permit needed',
          'KCT-043',
        ),
        s.siteWalkCard(ref: 'KCT-044'),
        s.m201(ref: 'KCT-045'),
        _plain(
          'post-report',
          DaybookPost.reportKind,
          'Daily report',
          'KCT-046',
        ),
      ];
      await _open(tester, lang, cards);
      for (final (c, word) in [
        (cards[0], l10n.daybookKindNoteWord),
        (cards[1], l10n.daybookKindChecklistWord),
        (cards[2], l10n.daybookToEveryone),
        (cards[3], l10n.daybookKindActivityWord),
        (cards[4], l10n.daybookKindFileWord),
        (cards[5], l10n.daybookKindReportWord),
      ]) {
        final card = _card(c.id);
        await tester.scrollUntilVisible(
          card,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final header = find.descendant(
          of: card,
          matching: find.textContaining(c.post.ref!),
        );
        expect(header, findsOneWidget, reason: c.id);
        // "· KCT-041 · note": the number, then what it is.
        final text = tester.widget<Text>(header).data!;
        expect(
          text.indexOf(c.post.ref!),
          lessThan(text.indexOf(word.substring(2))),
        );
      }
    });

    testWidgets('a work item\'s ref is its post\'s; a post waiting on the '
        'phone has none yet [$lang]', (tester) async {
      final item = s.sleevesCard();
      expect(item.post.ref, 'KCT-014');
      final waiting = DaybookPost(
        id: 'waiting',
        kind: DaybookPost.noteKind,
        createdAt: DateTime(2026, 10, 15),
        title: 'On the phone',
      );
      expect(waiting.ref, isNull);
      expect(
        DaybookPost.fromJson({
          'id': 'n1',
          'kind': 'note',
          'created_at': '2026-10-15T08:00:00Z',
          'title': 'Gate 2',
          'ref': 'NST-033',
        }).ref,
        'NST-033',
      );
      // Shown as something else (a check made here), it keeps its number.
      expect(
        DaybookPost.fromJson({
          'id': 'n1',
          'kind': 'note',
          'created_at': '2026-10-15T08:00:00Z',
          'title': 'Gate 2',
          'ref': 'NST-033',
        }).shownAs(cancelled: true).ref,
        'NST-033',
      );
    });
  }
}
