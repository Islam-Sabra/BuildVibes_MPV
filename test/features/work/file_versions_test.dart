// Review 80 F75, F76: a file post's version number, NEW VERSION · V2 with
// REPLACES V1, and the older post's "Replaced by V2 · today ›" with no
// Received pill.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _v1 = '00000000-0000-4000-8000-0000000008a1';
const _v2 = '00000000-0000-4000-8000-0000000008a2';

DaybookPost _post(
  DaybookSamples s, {
  required String id,
  required DaybookFile file,
  bool newVersion = false,
  Duration ago = const Duration(hours: 1),
}) => DaybookPost(
  id: id,
  kind: DaybookPost.fileKind,
  createdAt: DaybookSamples.thursday.subtract(ago),
  title: 'A-501',
  authorId: DaybookSamples.sara,
  authorName: s.saraName,
  file: file,
  newVersion: newVersion,
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('F75, F76: the new version says its number and the one it '
        'replaces; the old post says which replaced it, opens it, and asks '
        'nobody for Received [$lang]', (tester) async {
      final old = _post(
        s,
        id: _v1,
        ago: const Duration(days: 1),
        file: DaybookFile(
          id: 'f1',
          name: 'A-501.pdf',
          mime: 'application/pdf',
          bytes: 2400000,
          versionNo: 1,
          hasNewer: true,
          newerVersionNo: 2,
          newerAt: DaybookSamples.thursday.subtract(const Duration(hours: 1)),
          newerPostId: _v2,
        ),
      );
      final now = _post(
        s,
        id: _v2,
        newVersion: true,
        file: const DaybookFile(
          id: 'f2',
          name: 'A-501.pdf',
          mime: 'application/pdf',
          bytes: 2500000,
          versionNo: 2,
          replacesVersionNo: 1,
        ),
      );
      await pumpApp(
        tester,
        language: lang,
        auth: FakeAuthRepository(
          userId: DaybookSamples.islam,
          phone: '+96550000001',
        ),
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail()
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = [
            DaybookCard(post: now, lastActivityAt: now.createdAt),
            DaybookCard(post: old, lastActivityAt: old.createdAt),
          ],
        now: DaybookSamples.thursday,
      );
      final router = GoRouter.of(tester.element(find.byType(Navigator).first));
      router.push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();

      final v2 = l10n.libraryVersionNo(2);
      expect(find.text(l10n.daybookStampNewVersionNo(v2)), findsOneWidget);
      expect(
        find.text(l10n.daybookStampReplaces(l10n.libraryVersionNo(1))),
        findsOneWidget,
      );
      final oldCard = find.byKey(const Key('daybook-card-$_v1'));
      await tester.ensureVisible(oldCard);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: oldCard,
          matching: find.text(l10n.daybookReplacedBy(v2, l10n.daybookToday)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: oldCard,
          matching: find.byKey(const Key('ack-received')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('daybook-card-$_v2')),
          matching: find.byKey(const Key('ack-received')),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: oldCard,
          matching: find.byKey(const Key('card-replaced-by-tap')),
        ),
      );
      await tester.pumpAndSettle();
      // The newer version's post opens, on its day.
      expect(find.byType(SpaceScreen, skipOffstage: false), findsNWidgets(2));
    });
  }
}
