// Review 110 D: steps on the composer, shared by the tests that write in a
// Space. # picks the kind (CP2), + adds an extra (CP3).
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'daybook_samples.dart';

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// # → [kind] (its json: 'note', 'work_item', 'announcement', 'activity',
/// or 'walk').
Future<void> chooseKind(WidgetTester tester, String kind) async {
  await _tap(tester, find.byKey(const Key('writing-kind')));
  await _tap(tester, find.byKey(Key('composer-kind-$kind')));
}

/// + → [extra] (its key: 'place', 'due', 'photos', 'file', 'bullets',
/// 'table', 'task_table', 'pin', 'template').
Future<void> addExtra(WidgetTester tester, String extra) async {
  await _tap(tester, find.byKey(const Key('writing-add')));
  await _tap(tester, find.byKey(Key('composer-extra-$extra')));
}

/// The composer's draft in [spaceId].
DaybookPostDraft? composerDraft(
  WidgetTester tester, [
  String spaceId = DaybookSamples.space,
]) => ProviderScope.containerOf(
  tester.element(find.byType(Navigator).first),
).read(daybookDraftProvider(spaceId));

/// A checklist is no longer a kind to start from # (review 110 F); one
/// still comes as a draft from a notebook share or a template. With the
/// composer open, its draft becomes a checklist, as those do.
Future<void> makeChecklist(
  WidgetTester tester, [
  String spaceId = DaybookSamples.space,
]) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Navigator).first),
  );
  final notifier = container.read(daybookDraftProvider(spaceId).notifier);
  final draft = container.read(daybookDraftProvider(spaceId))!;
  await notifier.put(draft.copyWith(kind: DaybookKind.checklist));
  await tester.pumpAndSettle();
}
