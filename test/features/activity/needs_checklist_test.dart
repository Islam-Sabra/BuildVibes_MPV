// Sweep (progress, slice 2 notes): a checklist given to you with points
// left (needs_you's checklist_for_you) is in Needs you, as My Spaces'
// count already has it: the list and the count are the same rows.
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/activity/needs_card.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_target.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_needs_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    NeedsCard checklist({String? author}) => NeedsCard(
      kind: NeedsKind.checklist,
      spaceId: DaybookSamples.space,
      spaceName: s.spaceName,
      at: DateTime(2026, 10, 15, 9),
      postId: DaybookSamples.handoverId,
      workItemTitle: s.handoverTitle,
      actorName: author,
      due: DateTime(2026, 10, 15),
    );

    test('its words: who gave it, or for you [$lang]', () {
      expect(
        needsTitle(l10n, checklist(author: s.saraName)),
        l10n.needsChecklist(
          inOwnDirection(s.saraName),
          inOwnDirection(s.handoverTitle),
        ),
      );
      expect(
        needsTitle(l10n, checklist()),
        l10n.needsChecklistSelf(inOwnDirection(s.handoverTitle)),
      );
      expect(checklist().cardId, DaybookSamples.handoverId);
    });

    testWidgets('Needs you lists it, "To tick", with its due; a tap opens '
        'its card [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail()
          ..spacePeople[DaybookSamples.space] = s.people(),
        activity: FakeActivityRepository(
          cards: [checklist(author: s.saraName)],
        ),
        now: DaybookSamples.thursday,
      );
      GoRouter.of(tester.element(find.byType(Navigator).first)).push('/needs');
      await tester.pumpAndSettle();
      final row = tester.widget<BvNeedsRow>(find.byType(BvNeedsRow));
      expect(row.label, l10n.needsRowChecklist);
      expect(row.title, s.handoverTitle);
      expect(row.meta, contains(s.saraName));
      await tester.tap(
        find.byKey(const Key('needs-row-${DaybookSamples.handoverId}')),
      );
      await tester.pumpAndSettle();
      final space = tester.widget<SpaceScreen>(find.byType(SpaceScreen));
      expect(space.target, const DaybookTarget(DaybookSamples.handoverId));
    });

    testWidgets("Home's Spaces tab lists it too [$lang]", (tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: FakeSpaceRepository()
          ..spaces.add(
            SpaceSummary(
              id: DaybookSamples.space,
              name: s.spaceName,
              pass: SpacePass.crew,
              isAdmin: false,
            ),
          )
          ..details[DaybookSamples.space] = s.detail()
          ..spacePeople[DaybookSamples.space] = s.people(),
        activity: FakeActivityRepository(
          cards: [checklist(author: s.saraName)],
        ),
        now: DaybookSamples.thursday,
      );
      await tester.tap(find.text(l10n.homeSpaces));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('needs-${DaybookSamples.handoverId}')),
        findsOneWidget,
      );
    });
  }
}
