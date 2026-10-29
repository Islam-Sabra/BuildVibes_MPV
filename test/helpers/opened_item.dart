import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Review 105 Part 2: a tap opens an item, and what the old long-press
/// menu held is on the opened item. These read and use it in the old
/// menu's words and order: Send back, Add update, Edit, Edit page, Give
/// to, then ⋯'s rows (Unpin, Save as template, Cancel).

Finder _key(String k) => find.byKey(Key(k));

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(_key('daybook-page')));

/// What the opened item offers; ⋯ is opened to read it, then closed.
Future<List<String>> openedActions(WidgetTester tester) async {
  final l10n = _l10n(tester);
  final page = [
    if (_key('page-send-back').evaluate().isNotEmpty) l10n.daybookSendBack,
    if (_key('page-update').evaluate().isNotEmpty) l10n.daybookAddUpdate,
    if (_key('page-title').evaluate().isNotEmpty) l10n.daybookEdit,
    if (_key('page-edit').evaluate().isNotEmpty) l10n.pageEdit,
    if (_key('page-for').evaluate().isNotEmpty) l10n.daybookGiveTo,
  ];
  if (_key('page-more').evaluate().isEmpty) return page;
  await tester.tap(_key('page-more'));
  await tester.pumpAndSettle();
  final menu = tester.widget<BvPopoverMenu<int>>(_key('page-more-menu'));
  final more = [for (final i in menu.items) i.label];
  await tester.tapAt(const Offset(1, 1));
  await tester.pumpAndSettle();
  return [...page, ...more];
}

/// Does what the old menu's [label] did, from the opened item.
Future<void> openedPick(WidgetTester tester, String label) async {
  final l10n = _l10n(tester);
  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  if (label == l10n.daybookSendBack) return tap(_key('page-send-back'));
  if (label == l10n.daybookAddUpdate) return tap(_key('page-update'));
  if (label == l10n.daybookEdit) return tap(_key('page-title'));
  if (label == l10n.pageEdit) return tap(_key('page-edit'));
  if (label == l10n.daybookGiveTo) return tap(_key('page-for'));
  await tap(_key('page-more'));
  await tap(
    find.descendant(of: _key('page-more-menu'), matching: find.text(label)),
  );
}

/// Closes an opened item, if one is open.
Future<void> closeOpened(WidgetTester tester) async {
  while (_key('daybook-page').evaluate().isNotEmpty) {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }
}
