import 'dart:convert';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_writing.dart' show kindName;
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

typedef _App = ({
  FakeDaybookRepository daybook,
  FakeDaybookLive live,
  TestApp app,
});

Future<_App> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookCard> posts,
  Map<String, Object> stored = const {},
  bool offline = false,
}) async {
  final s = DaybookSamples(lang);
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = posts
    ..offline = offline;
  final live = FakeDaybookLive();
  final app = await pumpApp(
    tester,
    language: lang,
    stored: stored,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail()
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: daybook,
    live: live,
    library: FakeLibraryRepository(now: DaybookSamples.thursday)
      ..filesBySpace[DaybookSamples.space] = [
        LibraryFile(
          id: 'lib-m201-c',
          spaceId: DaybookSamples.space,
          name: 'M-201.pdf',
          path: '${DaybookSamples.space}/library/lib-m201-c/M-201.pdf',
          mime: 'application/pdf',
          createdAt: DateTime(2026, 10, 10),
          revLabel: 'Rev C',
        ),
      ],
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return (daybook: daybook, live: live, app: app);
}

Finder _card(String id) => find.byKey(Key('daybook-card-$id'));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('review 50 F47: live [$lang]', () {
      testWidgets('what someone else does reaches the open daybook at once: '
          'a new file post, then a Received', (tester) async {
        final (:daybook, :live, app: _) = await _open(
          tester,
          lang,
          posts: [s.rebar()],
        );
        expect(_card(DaybookSamples.m201Id), findsNothing);
        // Lina posts the file on her phone.
        daybook.put(DaybookSamples.space, s.m201());
        live.push(DaybookSamples.space, DaybookSamples.m201Id);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(_card(DaybookSamples.m201Id), findsOneWidget);
        // Omar's Received: the faces are read again.
        daybook.acksByPost[DaybookSamples.m201Id] = s.m201Received();
        live.push(DaybookSamples.space, DaybookSamples.m201Id);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('received-by')), findsOneWidget);
      });

      testWidgets('review 63 R3: a burst of signals reads the page at most '
          'once a second', (tester) async {
        final (:daybook, :live, app: _) = await _open(
          tester,
          lang,
          posts: [s.rebar()],
        );
        final before = daybook.pageCalls.length;
        // Ten signals over two seconds, one every 200 ms.
        for (var i = 0; i < 10; i++) {
          live.push(DaybookSamples.space, 'post-rebar');
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        // Not one per signal, and never held back while they keep coming.
        final reads = daybook.pageCalls.length - before;
        expect(reads, inInclusiveRange(2, 3));
      });

      testWidgets('F47 reopened: the phone sends nothing itself; the '
          'database broadcast reads the page again', (tester) async {
        final (:daybook, :live, app: _) = await _open(
          tester,
          lang,
          posts: [s.m201()],
        );
        await tester.tap(find.byKey(const Key('ack-received')));
        await tester.pumpAndSettle();
        // DaybookLive has no way to send any more (migration 42): the
        // database broadcasts the Received, and this daybook hears it too.
        final before = daybook.pageCalls.length;
        live.push(DaybookSamples.space, DaybookSamples.m201Id);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(daybook.pageCalls.length, greaterThan(before));
      });

      testWidgets('my own post of any kind is at Now at once, even with no '
          'signal', (tester) async {
        final drafts = [
          DaybookPostDraft(
            id: 'own-checklist',
            kind: DaybookKind.checklist,
            title: s.handoverTitle,
            people: [(id: DaybookSamples.sara, name: s.saraName)],
            points: const [(id: 'p1', text: 'Doors')],
          ),
          DaybookPostDraft(
            id: 'own-announcement',
            kind: DaybookKind.announcement,
            title: s.halfDay,
          ),
          DaybookPostDraft(
            id: 'own-activity',
            kind: DaybookKind.activity,
            title: s.siteWalk,
            startsAt: DateTime(2026, 10, 16, 7),
          ),
          const DaybookPostDraft(
            id: 'own-file',
            kind: DaybookKind.file,
            files: [
              DraftFile(
                libraryId: 'lib-m201-c',
                name: 'M-201.pdf',
                mime: 'application/pdf',
              ),
            ],
          ),
        ];
        final waiting = [
          for (final d in drafts)
            PendingItem(
              kind: PendingKind.post,
              id: d.id,
              spaceId: DaybookSamples.space,
              title: d.title,
              ownerId: '',
              ownerName: '',
              madeAt: DateTime(2026, 10, 15, 10, 29),
              draft: d,
              files: d.files,
            ).toJson(),
        ];
        await _open(
          tester,
          lang,
          offline: true,
          posts: [s.rebar()],
          stored: {'work_outbox:${DaybookSamples.islam}': jsonEncode(waiting)},
        );
        for (final d in drafts) {
          expect(_card(d.id), findsOneWidget, reason: d.kind.json);
          expect(
            find.descendant(
              of: _card(d.id),
              matching: find.text(l10n.daybookWaitingToSend),
            ),
            findsOneWidget,
          );
          // At Now: under the older card.
          expect(
            tester.getTopLeft(_card(d.id)).dy,
            greaterThan(tester.getTopLeft(_card('post-rebar')).dy),
          );
        }
      });

      testWidgets('a file post from the Library: its card at Now as soon as '
          'it is sent', (tester) async {
        await _open(tester, lang, offline: true, posts: [s.rebar()]);
        await tester.tap(find.byKey(const Key('post-bar-notepad')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('writing-kind-chip')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('writing-kind-menu')),
            matching: find.text(kindName(l10n, DaybookKind.file)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('file-lib-m201-c')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('writing-post')));
        await tester.pumpAndSettle();
        // The waiting card at Now, its title the file's name.
        expect(find.textContaining('M-201.pdf'), findsWidgets);
        expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);
      });
    });
  }
}
