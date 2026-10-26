import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/note.dart';
import '../../data/models/notebook_page.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_controls.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_undo_bar.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import '../work/daybook_words.dart';
import 'notebook_state.dart';

/// A page's icon (A1): one of the twelve.
IconData pageIconData(PageIcon icon) => switch (icon) {
  PageIcon.folder => BvIcons.pageFolder,
  PageIcon.hardHat => BvIcons.pageHardHat,
  PageIcon.building => BvIcons.pageBuilding,
  PageIcon.phone => BvIcons.pagePhone,
  PageIcon.list => BvIcons.pageList,
  PageIcon.calendar => BvIcons.calendar,
  PageIcon.camera => BvIcons.camera,
  PageIcon.warning => BvIcons.warning,
  PageIcon.star => BvIcons.pageStar,
  PageIcon.wrench => BvIcons.pageWrench,
  PageIcon.ruler => BvIcons.ruler,
  PageIcon.notebook => BvIcons.notebook,
};

/// A page's icon, read out.
String pageIconLabel(AppLocalizations l10n, PageIcon icon) => switch (icon) {
  PageIcon.folder => l10n.notebookIconFolder,
  PageIcon.hardHat => l10n.notebookIconHardHat,
  PageIcon.building => l10n.notebookIconBuilding,
  PageIcon.phone => l10n.notebookIconPhone,
  PageIcon.list => l10n.notebookIconList,
  PageIcon.calendar => l10n.notebookIconCalendar,
  PageIcon.camera => l10n.notebookIconCamera,
  PageIcon.warning => l10n.notebookIconWarning,
  PageIcon.star => l10n.notebookIconStar,
  PageIcon.wrench => l10n.notebookIconWrench,
  PageIcon.ruler => l10n.notebookIconRuler,
  PageIcon.notebook => l10n.notebookIconNotebook,
};

/// A page's name: its title, "My notes" (A6), or "Untitled".
String pageName(AppLocalizations l10n, NotebookPage page) {
  final title = page.title.trim();
  if (title.isNotEmpty) return title;
  return page.myNotes ? l10n.notebookMyNotes : l10n.notebookUntitled;
}

/// A row's date (PG1): "Today", "Yesterday", else "Mon 12 Oct".
String pageRowDate(
  AppLocalizations l10n,
  DaybookWords words,
  DateTime at,
  DateTime now,
) {
  final day = dayOf(at);
  final today = dayOf(now);
  if (day == today) return l10n.notebookToday;
  if (day == today.subtract(const Duration(days: 1))) {
    return l10n.notebookYesterday;
  }
  return words.shortDate(day);
}

/// A page's icon on its box: 40 (a row), 32 (the picker); on the
/// brand-soft surface in the action colour while the page is new.
class PageIconBox extends StatelessWidget {
  const PageIconBox({
    super.key,
    required this.icon,
    this.size = BvNotebookPagesSpec.box,
    this.glyph = BvNotebookPagesSpec.boxGlyph,
    this.brand = false,
  });

  final IconData icon;
  final double size;
  final double glyph;
  final bool brand;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: brand ? BvColors.surfaceBrandSoft : BvColors.surfaceSubtle,
      borderRadius: BvNotebookPagesSpec.boxRadius,
    ),
    child: Icon(
      icon,
      size: glyph,
      color: brand ? BvColors.iconAction : BvColors.iconPrimary,
    ),
  );
}

/// A list's label (PG1 "Pinned", "Pages"; PG4 a day).
class NotebookLabel extends StatelessWidget {
  const NotebookLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(
      top: BvNotebookPagesSpec.labelTop,
      bottom: BvNotebookPagesSpec.labelBottom,
    ),
    child: Text(
      text,
      style: BvType.of(
        context,
      ).metadata.copyWith(color: BvColors.textSecondary),
    ),
  );
}

/// A page's row (PG1, PG4's sub-pages, PG5): its icon, its name with a pin
/// or the new dot, the date and first line of its latest entry (or "new
/// page"), its open to-dos only when there are any, and ›. While
/// [selecting], a checkbox at its start; [selected] tints it.
class NotebookPageRow extends StatelessWidget {
  const NotebookPageRow({
    super.key,
    required this.page,
    required this.line,
    required this.openTodos,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  final NotebookPage page;

  /// "Today · Before the pour, level 3"; null: none.
  final String? line;
  final int openTodos;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final name = pageName(l10n, page);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    return Semantics(
      selected: selecting ? selected : null,
      button: true,
      child: Material(
        key: Key('page-${page.id}'),
        color: selected ? BvColors.surfaceBrandSoft : Colors.transparent,
        borderRadius: BvNotebookPagesSpec.rowRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvNotebookPagesSpec.rowPaddingStart,
              BvNotebookPagesSpec.rowPaddingVertical,
              BvNotebookPagesSpec.rowPaddingEnd,
              BvNotebookPagesSpec.rowPaddingVertical,
            ),
            child: Row(
              spacing: BvNotebookPagesSpec.rowGap,
              children: [
                if (selecting)
                  IgnorePointer(
                    child: BvCheckbox(value: selected, onChanged: (_) {}),
                  ),
                PageIconBox(icon: pageIconData(page.icon), brand: page.isNew),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvNotebookPagesSpec.linesGap,
                    children: [
                      Row(
                        spacing: BvNotebookPagesSpec.titleMarkGap,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: directionOf(name),
                              style: type.emphasis.copyWith(
                                color: BvColors.textPrimary,
                              ),
                            ),
                          ),
                          if (page.pinned)
                            const Icon(
                              BvIcons.pin,
                              key: Key('page-pinned'),
                              size: BvNotebookPagesSpec.pin,
                              color: BvColors.iconSecondary,
                            ),
                          if (page.isNew)
                            Semantics(
                              label: l10n.notebookNewMark,
                              child: Container(
                                key: const Key('page-new-dot'),
                                width: BvNotebookPagesSpec.newDot,
                                height: BvNotebookPagesSpec.newDot,
                                decoration: const BoxDecoration(
                                  color: BvColors.iconAction,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (line case final line?)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: quiet,
                        ),
                      if (openTodos > 0)
                        Row(
                          key: const Key('page-todos'),
                          spacing: BvNotebookPagesSpec.todosGap,
                          children: [
                            const Icon(
                              BvIcons.openTodos,
                              size: BvNotebookPagesSpec.todosIcon,
                              color: BvColors.textAction,
                            ),
                            Flexible(
                              child: Text(
                                l10n.notebookTodosOpen(openTodos),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.metadata.copyWith(
                                  color: BvColors.textAction,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const Icon(
                  BvIcons.caretForward,
                  size: BvNotebookPagesSpec.caret,
                  color: BvColors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A page's row for [page] in [data]: the latest entry's date and first
/// line (with its sub-pages'), or "new page".
NotebookPageRow pageRowFor(
  BuildContext context,
  NotebookData data,
  NotebookPage page, {
  required DaybookWords words,
  required DateTime now,
  required VoidCallback onTap,
  VoidCallback? onLongPress,
  bool selecting = false,
  bool selected = false,
}) {
  final l10n = AppLocalizations.of(context);
  final latest = data.latestIn(page.id);
  final at = latest?.createdAt ?? page.lastActivityAt;
  final first = latest == null ? '' : entryFirstLine(latest);
  final date = pageRowDate(l10n, words, at, now);
  return NotebookPageRow(
    page: page,
    line: page.isNew
        ? l10n.notebookPageLine(date, l10n.notebookNewPageMark)
        : first.isEmpty
        ? date
        : l10n.notebookPageLine(date, first),
    openTodos: data.openTodos(page.id),
    onTap: onTap,
    onLongPress: onLongPress,
    selecting: selecting,
    selected: selected,
  );
}

/// "+ New page" (PG1): the plus on the brand-soft box, in the action
/// colour.
class NewPageRow extends StatelessWidget {
  const NewPageRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      child: Material(
        key: const Key('notebook-new-page'),
        color: Colors.transparent,
        borderRadius: BvNotebookPagesSpec.rowRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvNotebookPagesSpec.rowPaddingStart,
              BvNotebookPagesSpec.rowPaddingVertical,
              BvNotebookPagesSpec.rowPaddingEnd,
              BvNotebookPagesSpec.rowPaddingVertical,
            ),
            child: Row(
              spacing: BvNotebookPagesSpec.rowGap,
              children: [
                const PageIconBox(icon: BvIcons.add, brand: true),
                Text(
                  l10n.notebookNewPage,
                  style: BvType.of(
                    context,
                  ).labelMd.copyWith(color: BvColors.textAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The first line of an entry: its title, or its first words.
String entryFirstLine(Note note) {
  final title = note.title.trim();
  if (title.isNotEmpty) return title;
  return note.body.trim().split('\n').first.trim();
}

/// Words as the picker compares them: lower case, Arabic letter forms and
/// digits folded as the server's search_fold does.
String foldForSearch(String text) {
  const from = 'أإآٱىیةؤئک٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
  const to = 'ااااييهءءك01234567890123456789';
  final out = StringBuffer();
  for (final c in text.trim().toLowerCase().characters) {
    final i = from.indexOf(c);
    out.write(i < 0 || c.length != 1 ? c : to[i]);
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// What a page picker chose (A2, A4).
enum PagePickKind { page, newPage, top }

@immutable
class PagePick {
  const PagePick.page(String this.id) : kind = PagePickKind.page;
  const PagePick.newPage() : kind = PagePickKind.newPage, id = null;
  const PagePick.top() : kind = PagePickKind.top, id = null;

  final PagePickKind kind;
  final String? id;
}

/// The page picker (PG3): search, the recent pages (or those found), then
/// "+ New page"; [top] adds "Top of My notebook" first (Move into…).
/// [current] is ticked ([newPageChosen]: "New page" is); [hidden] never
/// shows (a page can't go into itself).
class PagePicker extends StatefulWidget {
  const PagePicker({
    super.key,
    required this.data,
    required this.onPick,
    this.current,
    this.newPageChosen = false,
    this.hidden = const {},
    this.newPage = true,
    this.top = false,
  });

  final NotebookData data;
  final ValueChanged<PagePick> onPick;
  final String? current;
  final bool newPageChosen;
  final Set<String> hidden;
  final bool newPage;
  final bool top;

  @override
  State<PagePicker> createState() => _PagePickerState();
}

class _PagePickerState extends State<PagePicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final q = foldForSearch(_query.text);
    final pages = [
      for (final p in widget.data.pages)
        if (!widget.hidden.contains(p.id) &&
            (q.isEmpty || foldForSearch(pageName(l10n, p)).contains(q)))
          p,
    ]..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    final shown = pages.take(BvNotebookPagesSpec.pickerMostRows - 1);
    Widget row({
      required Key key,
      required Widget box,
      required String label,
      required VoidCallback onTap,
      bool selected = false,
      bool action = false,
    }) => Semantics(
      button: true,
      selected: selected,
      child: Material(
        key: key,
        color: selected ? BvColors.surfaceBrandSoft : Colors.transparent,
        borderRadius: BvRadius.controlAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: BvNotebookPagesSpec.pickerRow,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvNotebookPagesSpec.pickerRowPadding,
              ),
              child: Row(
                spacing: BvNotebookPagesSpec.pickerRowGap,
                children: [
                  box,
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: directionOf(label),
                      style: (action ? type.labelMd : type.bodyMd).copyWith(
                        color: action
                            ? BvColors.textAction
                            : BvColors.textPrimary,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      BvIcons.check,
                      size: BvNotebookPagesSpec.pickGlyph,
                      color: BvColors.iconAction,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      key: const Key('page-picker'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: BvNotebookPagesSpec.pickerSearchHeight,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSpace.s12,
          ),
          decoration: const BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvRadius.controlAll,
          ),
          child: Row(
            spacing: BvSpace.s8,
            children: [
              const Icon(
                BvIcons.search,
                size: BvNotebookPagesSpec.pickGlyph,
                color: BvColors.iconSecondary,
              ),
              Expanded(
                child: TextField(
                  key: const Key('page-picker-search'),
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                  decoration: bvBareField(
                    hint: l10n.notebookFindPage,
                    style: type.bodyMd,
                  ),
                ),
              ),
            ],
          ),
        ),
        NotebookLabel(l10n.notebookRecent),
        if (widget.top)
          row(
            key: const Key('page-pick-top'),
            box: const PageIconBox(
              icon: BvIcons.notebook,
              size: BvNotebookPagesSpec.pickBox,
              glyph: BvNotebookPagesSpec.pickGlyph,
            ),
            label: l10n.notebookTopOfNotebook,
            onTap: () => widget.onPick(const PagePick.top()),
          ),
        for (final p in shown)
          row(
            key: Key('page-pick-${p.id}'),
            box: PageIconBox(
              icon: pageIconData(p.icon),
              size: BvNotebookPagesSpec.pickBox,
              glyph: BvNotebookPagesSpec.pickGlyph,
              brand: p.isNew,
            ),
            label: pageName(l10n, p),
            selected: p.id == widget.current,
            onTap: () => widget.onPick(PagePick.page(p.id)),
          ),
        if (pages.isEmpty && q.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.all(BvSpace.s8),
            child: Text(
              l10n.notebookNoPageFound,
              style: type.bodyMd.copyWith(color: BvColors.textSecondary),
            ),
          ),
        if (widget.newPage)
          row(
            key: const Key('page-pick-new'),
            box: const PageIconBox(
              icon: BvIcons.add,
              size: BvNotebookPagesSpec.pickBox,
              glyph: BvNotebookPagesSpec.pickGlyph,
              brand: true,
            ),
            label: l10n.notebookNewPage,
            selected: widget.newPageChosen,
            action: true,
            onTap: () => widget.onPick(const PagePick.newPage()),
          ),
      ],
    );
  }
}

/// The picker as a floating card (PG3): white, 300 wide.
class PagePickerCard extends StatelessWidget {
  const PagePickerCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      width: BvNotebookPagesSpec.pickerWidth,
      padding: const EdgeInsetsDirectional.all(
        BvNotebookPagesSpec.pickerPadding,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvNotebookPagesSpec.pickerRadius,
        boxShadow: BvShadow.menu,
      ),
      child: child,
    ),
  );
}

/// Move to page… or Move into… (A4): the picker on a sheet.
Future<PagePick?> showPagePickerSheet(
  BuildContext context, {
  required NotebookData data,
  required String title,
  String? current,
  Set<String> hidden = const {},
  bool newPage = true,
  bool top = false,
}) => showBvSheet<PagePick>(
  context: context,
  title: title,
  builder: (sheet) => PagePicker(
    data: data,
    current: current,
    hidden: hidden,
    newPage: newPage,
    top: top,
    onPick: (pick) => Navigator.of(sheet).pop(pick),
  ),
);

/// A page's icon (A3): the twelve, four to a row.
Future<PageIcon?> showPageIconSheet(BuildContext context, PageIcon current) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<PageIcon>(
    context: context,
    title: l10n.notebookPageIcon,
    builder: (sheet) => GridView.count(
      key: const Key('page-icons'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: BvNotebookPagesSpec.iconColumns,
      mainAxisSpacing: BvSpace.s8,
      crossAxisSpacing: BvSpace.s8,
      children: [
        for (final icon in PageIcon.values)
          Semantics(
            button: true,
            selected: icon == current,
            label: pageIconLabel(l10n, icon),
            excludeSemantics: true,
            child: Material(
              key: Key('page-icon-${icon.json}'),
              color: icon == current
                  ? BvColors.surfaceBrandSoft
                  : BvColors.surfaceSubtle,
              borderRadius: BvRadius.controlAll,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(sheet).pop(icon),
                child: Icon(
                  pageIconData(icon),
                  size: BvNotebookPagesSpec.iconGlyph,
                  color: icon == current
                      ? BvColors.iconAction
                      : BvColors.iconPrimary,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The merge sheet (PG5b): the page that stays, or a new page; then
/// Merge. Null: cancelled.
Future<PagePick?> showMergeSheet(
  BuildContext context, {
  required List<NotebookPage> pages,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<PagePick>(
    context: context,
    title: l10n.notebookMergeTitle(pages.length),
    subtitle: l10n.notebookMergeBody,
    builder: (sheet) => _MergeChoices(pages: pages),
  );
}

class _MergeChoices extends StatefulWidget {
  const _MergeChoices({required this.pages});

  final List<NotebookPage> pages;

  @override
  State<_MergeChoices> createState() => _MergeChoicesState();
}

class _MergeChoicesState extends State<_MergeChoices> {
  late PagePick _pick = PagePick.page(widget.pages.first.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    Widget choice(Key key, String label, PagePick pick) {
      final on = pick.kind == _pick.kind && pick.id == _pick.id;
      return Semantics(
        button: true,
        selected: on,
        child: InkWell(
          key: key,
          onTap: () => setState(() => _pick = pick),
          child: SizedBox(
            height: BvNotebookPagesSpec.choiceHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                  ),
                ),
                ExcludeSemantics(child: BvRadio(selected: on)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      key: const Key('merge-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        for (final p in widget.pages)
          choice(
            Key('merge-into-${p.id}'),
            l10n.notebookMergeInto(pageName(l10n, p)),
            PagePick.page(p.id),
          ),
        choice(
          const Key('merge-into-new'),
          l10n.notebookMergeNew,
          const PagePick.newPage(),
        ),
        BvButton(
          key: const Key('merge-go'),
          label: l10n.notebookMerge,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_pick),
        ),
      ],
    );
  }
}

/// One action of the selection bar (PG5): its icon over its word.
@immutable
class SelectionAction {
  const SelectionAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
}

/// The bar while selecting (PG5): its actions spread across, Delete in red.
class SelectionBar extends StatelessWidget {
  const SelectionBar({super.key, required this.actions});

  final List<SelectionAction> actions;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Material(
      key: const Key('selection-bar'),
      color: BvColors.surfaceElevated,
      child: SafeArea(
        top: false,
        child: Container(
          height: BvNotebookPagesSpec.barHeight,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: BvColors.borderSubtle,
                width: BvStroke.thin,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in actions)
                Expanded(
                  child: Semantics(
                    button: true,
                    enabled: a.onTap != null,
                    child: InkWell(
                      key: a.key,
                      onTap: a.onTap,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: BvNotebookPagesSpec.barTop,
                        ),
                        child: Column(
                          spacing: BvNotebookPagesSpec.barGap,
                          children: [
                            Icon(
                              a.icon,
                              size: BvNotebookPagesSpec.barIcon,
                              color: a.onTap == null
                                  ? BvColors.actionDisabledForeground
                                  : a.destructive
                                  ? BvColors.textDestructive
                                  : BvColors.iconPrimary,
                            ),
                            Text(
                              a.label,
                              style: type.metadata.copyWith(
                                color: a.onTap == null
                                    ? BvColors.actionDisabledForeground
                                    : a.destructive
                                    ? BvColors.textDestructive
                                    : BvColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [change] (a merge, pages deleted) shows at once, with Undo for 5 s
/// (A4); it goes when the bar closes, unless Undo took it back.
Future<void> holdWithUndo(
  BuildContext context,
  WidgetRef ref,
  NoteChange change,
  String message,
) async {
  final notebook = ref.read(notebookProvider.notifier);
  await notebook.hold(change);
  if (!context.mounted) {
    await notebook.releaseHeld();
    return;
  }
  final bar = showBvUndoBar(
    context,
    message: message,
    actionLabel: AppLocalizations.of(context).daybookUndo,
    onAction: notebook.undoHeld,
    bottom: 0,
  );
  unawaited(
    bar.closed.then((why) {
      if (why != SnackBarClosedReason.action) unawaited(notebook.releaseHeld());
    }),
  );
}

/// The page chip under the entry being written (PG2): "Page: Site A –
/// Tower ▾", the page's icon first; a tap opens the picker (PG3).
class NotePageChip extends StatelessWidget {
  const NotePageChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Semantics(
      button: true,
      child: Material(
        key: const Key('note-page-chip'),
        color: BvColors.surfaceSubtle,
        borderRadius: BvRadius.roundAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: BvNotebookPagesSpec.chipHeight,
            padding: const EdgeInsetsDirectional.only(
              start: BvNotebookPagesSpec.chipPaddingStart,
              end: BvNotebookPagesSpec.chipPaddingEnd,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: BvNotebookPagesSpec.chipGap,
              children: [
                Icon(
                  icon,
                  size: BvNotebookPagesSpec.chipIcon,
                  color: BvColors.iconPrimary,
                ),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BvType.of(
                      context,
                    ).labelSm.copyWith(color: BvColors.textPrimary),
                  ),
                ),
                const Icon(
                  BvIcons.caretDown,
                  size: BvNotebookPagesSpec.chipCaret,
                  color: BvColors.iconPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Write in this page" (PG4): the action colour on a round pill, the
/// pencil first.
class WriteHereButton extends StatelessWidget {
  const WriteHereButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      key: const Key('page-write'),
      color: BvColors.actionPrimary,
      borderRadius: BvRadius.roundAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: BvNotebookPagesSpec.writeHereHeight,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvNotebookPagesSpec.writeHerePadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvNotebookPagesSpec.writeHereGap,
            children: [
              const Icon(
                BvIcons.edit,
                size: BvNotebookPagesSpec.writeHereIcon,
                color: BvColors.actionPrimaryForeground,
              ),
              Flexible(
                child: Text(
                  AppLocalizations.of(context).notebookWriteHere,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BvType.of(
                    context,
                  ).button.copyWith(color: BvColors.actionPrimaryForeground),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
