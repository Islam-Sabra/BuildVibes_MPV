// Review 105 Part 2: Work's gestures for the screenshot drivers. A tap
// on a card's slip opens the item (the old hold menu's rows are on the
// opened item, see test/helpers/opened_item.dart); a hold selects it.
import 'package:buildvibes/core/routing/app_routes.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/spaces/space_sections.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The slip inside Work's card for post [id].
Finder cardSlip(String id) => find.descendant(
  of: find.byKey(Key('daybook-card-$id')),
  matching: find.byType(BvSlip),
);

/// Opens post [id] from its Work card (a tap on its slip).
Future<void> openCard(WidgetTester tester, String id) async {
  final slip = cardSlip(id);
  await tester.ensureVisible(slip.first);
  await tester.pumpAndSettle();
  await tester.tap(slip.first);
  await tester.pumpAndSettle();
}

/// Selects post [id]'s Work card (a hold on its slip).
Future<void> selectCard(WidgetTester tester, String id) async {
  final slip = cardSlip(id);
  await tester.ensureVisible(slip.first);
  await tester.pumpAndSettle();
  await tester.longPress(slip.first);
  await tester.pumpAndSettle();
}

/// Review 105 SP2: what the writing card's ⋯ menu set is now a row on the
/// card (For · Place · Due · When); ⋯ (`writing-add`) keeps the rest (Pin
/// until, a template). Does what the old ⋯ row [label] did.
Future<void> writingSet(
  WidgetTester tester,
  AppLocalizations l10n,
  String label,
) async {
  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  final row = {
    l10n.daybookPeople: 'writing-who',
    l10n.daybookAssign: 'writing-who',
    l10n.daybookLocation: 'writing-place-row',
    l10n.daybookDueDateMenu: 'writing-due-row',
    l10n.daybookActivityTime: 'writing-when-row',
  }[label];
  if (row != null && find.byKey(Key(row)).evaluate().isNotEmpty) {
    final rowFinder = find.byKey(Key(row));
    await tester.ensureVisible(rowFinder);
    await tester.pumpAndSettle();
    // Its icon: the title's selection handle can sit over its middle.
    final icon = find.descendant(of: rowFinder, matching: find.byType(Icon));
    await tester.tap(icon.evaluate().isEmpty ? rowFinder : icon.first);
    await tester.pumpAndSettle();
    return;
  }
  await tap(find.byKey(const Key('writing-add')));
  await tap(find.text(label));
}

/// The Space with its Library at the app's own route, for a shot drawn
/// by [shoot] (no app router): review 105 SP2 starts a file post from the
/// Library's Add a file, which comes back to Work writing it.
class RoutedSpace extends StatefulWidget {
  const RoutedSpace(this.spaceId, {super.key});

  final String spaceId;

  @override
  State<RoutedSpace> createState() => _RoutedSpaceState();
}

class _RoutedSpaceState extends State<RoutedSpace> {
  late final GoRouter _router = GoRouter(
    initialLocation: AppRoutes.space(widget.spaceId),
    routes: [
      GoRoute(
        path: AppRoutes.space(widget.spaceId),
        builder: (_, _) => SpaceScreen(spaceId: widget.spaceId),
      ),
      GoRoute(
        path: AppRoutes.spaceLibrary(widget.spaceId),
        builder: (_, _) => SpaceLibraryScreen(spaceId: widget.spaceId),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}
