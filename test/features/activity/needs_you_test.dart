// Slice 1 part 1e: Needs you, across all Spaces (2544:35068), the list
// only. Each Space's things under its name; a row opens the Space.
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/features/activity/needs_you_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_needs_row.dart';
import 'package:buildvibes/shared/widgets/bv_paper_clip.dart';
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

    List<NeedsCard> cards() => [
      NeedsCard(
        kind: NeedsKind.youCheck,
        spaceId: DaybookSamples.space,
        spaceName: s.spaceName,
        at: DateTime(2026, 10, 15, 9, 40),
        workItemId: 'post-sleeves',
        workItemTitle: s.sleeves,
        actorName: s.omarName,
        photoPath: 'proof.jpg',
      ),
      NeedsCard(
        kind: NeedsKind.forYou,
        spaceId: 'space-khiran',
        spaceName: 'Khiran villas — Finishing',
        at: DateTime(2026, 10, 15, 8),
        workItemId: 'post-tiles',
        workItemTitle: 'Tiles, villa 4',
        actorName: s.linaName,
      ),
      NeedsCard(
        kind: NeedsKind.forYou,
        spaceId: DaybookSamples.space,
        spaceName: s.spaceName,
        at: DateTime(2026, 10, 15, 7),
        workItemId: 'post-rebar',
        workItemTitle: s.rebar().title,
        actorName: s.saraName,
        due: DateTime(2026, 10, 15),
      ),
    ];

    testWidgets('grouped by Space, in order; each row says what to do, '
        'with the paper clip; a row opens its Space [$lang]', (tester) async {
      final spaces = FakeSpaceRepository()
        ..details[DaybookSamples.space] = s.detail()
        ..spacePeople[DaybookSamples.space] = s.people();
      await pumpApp(
        tester,
        language: lang,
        spaces: spaces,
        activity: FakeActivityRepository(cards: cards()),
        now: DaybookSamples.thursday,
      );
      GoRouter.of(tester.element(find.byType(Navigator).first)).push('/needs');
      await tester.pumpAndSettle();
      expect(find.byType(NeedsYouScreen), findsOneWidget);
      final groups = tester
          .widgetList<BvNeedsGroup>(find.byType(BvNeedsGroup))
          .toList();
      expect(
        [for (final g in groups) g.name],
        [s.spaceName, 'Khiran villas — Finishing'],
      );
      expect(groups.first.rows, hasLength(2));
      expect(find.byType(BvPaperClip), findsNWidgets(3));
      final labels = [
        for (final r in tester.widgetList<BvNeedsRow>(find.byType(BvNeedsRow)))
          r.label,
      ];
      expect(labels, [
        l10n.needsRowCheck,
        l10n.needsRowForYou,
        l10n.needsRowForYou,
      ]);
      await tester.tap(find.text(s.sleeves));
      await tester.pumpAndSettle();
      expect(find.byType(SpaceScreen), findsOneWidget);
    });

    testWidgets('nothing waiting says so [$lang]', (tester) async {
      await pumpApp(tester, language: lang, activity: FakeActivityRepository());
      GoRouter.of(tester.element(find.byType(Navigator).first)).push('/needs');
      await tester.pumpAndSettle();
      expect(find.text(l10n.needsNone), findsOneWidget);
    });
  }
}
