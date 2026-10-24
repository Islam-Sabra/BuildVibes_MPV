// F104 (review 50): the author of a pinned announcement sees, on its folded
// slim line too, the faces of who tapped Got it: up to 3, then "+N", and
// live. Nobody else sees others' faces. EN and AR.
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_pinned_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _people = [
  DaybookSamples.omar,
  DaybookSamples.mona,
  DaybookSamples.rakesh,
  DaybookSamples.lina,
  DaybookSamples.islam,
];

List<DaybookAckFace> _gotIt(DaybookSamples s, int n) => [
  for (final (i, id) in _people.take(n).indexed)
    DaybookAckFace(
      profileId: id,
      name: s.nameOf(id),
      kind: DaybookAck.gotIt,
      at: DateTime(2026, 10, 15, 9, i),
    ),
];

Future<({FakeDaybookRepository daybook, FakeDaybookLive live})> _open(
  WidgetTester tester,
  String lang, {
  required String me,
  required int gotIt,
}) async {
  final s = DaybookSamples(lang);
  final post = s.halfDayPost(
    myAcks: me == DaybookSamples.sara ? const {} : const {DaybookAck.gotIt},
  );
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = [
      DaybookCard(post: post, lastActivityAt: post.createdAt),
    ]
    ..extrasBySpace[DaybookSamples.space] = DaybookExtras(pinned: [post])
    ..acksByPost[DaybookSamples.halfDayId] = _gotIt(s, gotIt);
  final live = FakeDaybookLive();
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail()
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: daybook,
    live: live,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return (daybook: daybook, live: live);
}

Finder _line() => find.byType(BvPinnedLine);
Finder _faces() =>
    find.descendant(of: _line(), matching: find.byType(BvAvatar));
Finder _more() =>
    find.descendant(of: _line(), matching: find.byKey(const Key('faces-more')));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    group('F104: the folded line\'s faces [$lang]', () {
      for (final (n, faces, more) in [(1, 1, null), (3, 3, null), (5, 3, 2)]) {
        testWidgets('its author, $n Got it: $faces faces'
            '${more == null ? '' : ' and +$more'}', (tester) async {
          await _open(tester, lang, me: DaybookSamples.sara, gotIt: n);
          expect(_line(), findsOneWidget);
          expect(_faces(), findsNWidgets(faces));
          if (more == null) {
            expect(_more(), findsNothing);
          } else {
            final text = tester.widget<Text>(_more()).data!;
            expect(text, ltrRun(l10n.daybookFacesMore(more)));
            // Western digits in Arabic too.
            expect(text, contains('+$more'));
          }
        });
      }

      testWidgets('off its pin, its card shows the same: 3 faces and +2', (
        tester,
      ) async {
        final s = DaybookSamples(lang);
        final post = DaybookPost(
          id: 'post-crane',
          kind: DaybookPost.announcementKind,
          createdAt: DateTime(2026, 10, 15, 8),
          title: 'Crane closed today',
          authorId: DaybookSamples.sara,
          authorName: s.saraName,
        );
        final daybook = FakeDaybookRepository()
          ..posts[DaybookSamples.space] = [
            DaybookCard(post: post, lastActivityAt: post.createdAt),
          ]
          ..acksByPost[post.id] = _gotIt(s, 5);
        await pumpApp(
          tester,
          language: lang,
          auth: FakeAuthRepository(
            userId: DaybookSamples.sara,
            phone: '+96550000001',
          ),
          spaces: FakeSpaceRepository()
            ..details[DaybookSamples.space] = s.detail()
            ..spacePeople[DaybookSamples.space] = s.people(),
          daybook: daybook,
          now: DaybookSamples.thursday,
        );
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).push('/spaces/${DaybookSamples.space}');
        await tester.pumpAndSettle();
        final by = find.byKey(const Key('got-it-by'));
        expect(
          find.descendant(of: by, matching: find.byType(BvAvatar)),
          findsNWidgets(3),
        );
        expect(
          find.descendant(
            of: by,
            matching: find.byKey(const Key('faces-more')),
          ),
          findsOneWidget,
        );
      });

      testWidgets('someone else\'s folded line shows no faces', (tester) async {
        await _open(tester, lang, me: DaybookSamples.omar, gotIt: 3);
        expect(_line(), findsOneWidget);
        expect(_faces(), findsNothing);
        expect(_more(), findsNothing);
      });

      testWidgets('a new Got it arrives live, without reopening', (
        tester,
      ) async {
        final (:daybook, :live) = await _open(
          tester,
          lang,
          me: DaybookSamples.sara,
          gotIt: 1,
        );
        expect(_faces(), findsOneWidget);
        daybook.acksByPost[DaybookSamples.halfDayId] = _gotIt(
          DaybookSamples(lang),
          2,
        );
        live.push(DaybookSamples.space, DaybookSamples.halfDayId);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(_line(), findsOneWidget, reason: 'still folded');
        expect(_faces(), findsNWidgets(2));
      });
    });
  }
}
