import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/activity/activity_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_target.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

/// Slice 10 (review 87): the six Activity kinds about a daybook post.
void main() {
  Map<String, dynamic> json(String kind) => {
    'id': 'n-$kind',
    'kind': kind,
    'created_at': '2026-10-11T07:00:00Z',
    'space_id': 'space-1',
    'space_name': 'Tower B — Site team',
    'work_item_id': null,
    'work_item_title': 'Friday is a half day',
    'actor_id': 'p-sara',
    'actor_name': 'Sara Ali',
    'space_post_id': 'post-$kind',
    'post_kind': 'announcement',
  };

  const kinds = [
    'item_edited',
    'item_cancelled',
    'announcement_new',
    'checklist_for_you',
    'activity_invited',
    'file_new_version',
  ];

  test('the six kinds are read, with the post they open', () {
    for (final k in kinds) {
      final row = ActivityRow.fromJson(json(k));
      expect(row.kind.json, k);
      expect(row.spacePostId, 'post-$k');
      expect(row.postKind, 'announcement');
      expect(row.cardId, 'post-$k', reason: 'no work item: the post');
    }
    // A work item still opens itself.
    final item = ActivityRow.fromJson({
      ...json('item_edited'),
      'work_item_id': 'item-1',
    });
    expect(item.cardId, 'item-1');
  });

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    test('each row says who and what, with the title [$lang]', () {
      final seen = <String>{};
      for (final k in kinds) {
        final w = activityWords(l10n, ActivityRow.fromJson(json(k)));
        expect(w.text, contains('Sara Ali'), reason: k);
        expect(w.text, contains('Friday is a half day'), reason: k);
        expect(w.name, contains('Sara Ali'));
        expect(w.where, contains('Tower B'));
        seen.add(w.text);
      }
      expect(seen, hasLength(kinds.length), reason: 'six different lines');
      expect(
        activityWords(
          l10n,
          ActivityRow.fromJson(json('announcement_new')),
        ).text,
        lang == 'en'
            ? contains('posted an announcement')
            : contains('إعلان من'),
      );
    });

    testWidgets('an announcement row opens the post at its card [$lang]', (
      tester,
    ) async {
      final spaces = FakeSpaceRepository(now: testNow)
        ..spaces.add(
          const SpaceSummary(
            id: 'space-1',
            name: 'Tower B — Site team',
            pass: SpacePass.crew,
            isAdmin: false,
          ),
        );
      await pumpApp(
        tester,
        language: lang,
        spaces: spaces,
        activity: FakeActivityRepository(
          rows: [ActivityRow.fromJson(json('announcement_new'))],
        ),
      );
      await tester.tap(find.byKey(const Key('nav-activity')));
      await tester.pumpAndSettle();
      final row = find.byKey(const Key('activity-row-n-announcement_new'));
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      final space = tester.widget<SpaceScreen>(find.byType(SpaceScreen));
      expect(space.spaceId, 'space-1');
      expect(space.target, const DaybookTarget('post-announcement_new'));
    });
  }
}
