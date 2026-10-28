import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/notebook_page.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_back_swipe.dart';
import '../../shared/widgets/bv_line_popover.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../work/daybook_words.dart';
import '../work/daybook_writing.dart' show newPostIdProvider;
import 'deleted_items_screen.dart' show DeletedItemsRow;
import 'note_filter.dart';
import 'notebook_page_parts.dart';
import 'notebook_state.dart';

/// My notebook (review 99A, PG1 2635:37785; review 100 BH1): the pages
/// list. Filter, Search and My calendar in the top bar; pinned pages first,
/// then by latest activity, each with "{n} entries · {when}"; "+ New page"
/// under the list; "New entry", a round button at the bottom end. With the
/// Filter on (BH9, BH11), its chips and the entries it finds, by page.
/// Only its owner reads it.
///
/// Long-press a page, then tap others (PG5): Merge (PG5b), Move into…, Pin
/// and Delete; a merge or a delete has Undo for 5 s.
class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  /// Pages selected, in the order they were picked.
  final List<String> _selected = [];

  /// The page a Filter starts with: none here (all pages).
  String? get _filterHome => null;

  /// The Filter (review 100 Part 8), its card and its button.
  NoteFilterState _filter = const NoteFilterState();
  final _filterCard = BvLinePopover();
  final _filterKey = GlobalKey();

  void _openFilter(NotebookData data, {bool pages = false}) {
    if (_filterCard.isOpen) return _filterCard.hide();
    showNoteFilter(
      context,
      _filterCard,
      anchor: () => _filterKey.currentContext,
      data: data,
      filter: _filter,
      pages: pages,
      onChanged: (f) => setState(() => _filter = f),
    );
  }

  Widget _filterButton(NotebookData data, String key) => KeyedSubtree(
    key: _filterKey,
    child: NoteFilterButton(
      key: Key(key),
      on: _filter.on,
      onPressed: () => _openFilter(data),
    ),
  );

  /// The chips and the entries found, while the Filter is on.
  Widget _filtered(NotebookData data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      NoteFilterChips(
        data: data,
        filter: _filter,
        onClear: () =>
            setState(() => _filter = NoteFilterState(page: _filterHome)),
        onPage: () => _openFilter(data, pages: true),
      ),
      Expanded(
        child: NoteFilterResults(data: data, filter: _filter),
      ),
    ],
  );

  @override
  void dispose() {
    _filterCard.hide();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // F107 B8: the notebook opening sends what waits.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(notebookProvider.notifier).retry());
    });
  }

  DaybookWords _words() => DaybookWords(
    AppLocalizations.of(context),
    Localizations.localeOf(context).toLanguageTag(),
    use24: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  void _toggle(NotebookPage page) => setState(() {
    if (!_selected.remove(page.id)) _selected.add(page.id);
  });

  /// "+ New page": an empty page, opened.
  Future<void> _newPage() async {
    final at = ref.read(clockProvider)();
    final id = ref.read(newPostIdProvider)();
    await ref
        .read(notebookProvider.notifier)
        .newPage(NotebookPage(id: id, createdAt: at, lastActivityAt: at));
    if (mounted) unawaited(context.push(AppRoutes.notebookPage(id)));
  }

  /// Merge (PG5b): the page that stays, or a new one; Undo for 5 s.
  Future<void> _merge(NotebookData data) async {
    final l10n = AppLocalizations.of(context);
    final pages = [for (final id in _selected) ?data.page(id)];
    final pick = await showMergeSheet(context, pages: pages);
    if (pick == null || !mounted) return;
    NotebookPage? made;
    if (pick.kind == PagePickKind.newPage) {
      final at = ref.read(clockProvider)();
      made = NotebookPage(
        id: ref.read(newPostIdProvider)(),
        createdAt: at,
        lastActivityAt: at,
      );
    }
    final into = made?.id ?? pick.id!;
    setState(_selected.clear);
    await holdWithUndo(
      context,
      ref,
      NoteChange.merge(
        [for (final p in pages) p.id],
        const [],
        into,
        page: made,
      ),
      l10n.notebookMerged,
    );
  }

  /// Move into… (A4): the top of My notebook or another page, never one of
  /// the selected or a page under them.
  Future<void> _moveInto(NotebookData data) async {
    final l10n = AppLocalizations.of(context);
    final pick = await showPagePickerSheet(
      context,
      data: data,
      title: l10n.notebookMoveInto,
      hidden: {for (final id in _selected) ...data.tree(id)},
      newPage: false,
      top: true,
    );
    if (pick == null || !mounted) return;
    final ids = [..._selected];
    setState(_selected.clear);
    await ref.read(notebookProvider.notifier).movePages(ids, pick.id);
  }

  Future<void> _pin(bool on) async {
    final ids = [..._selected];
    setState(_selected.clear);
    await ref.read(notebookProvider.notifier).pinPages(ids, on: on);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ids = [..._selected];
    setState(_selected.clear);
    await holdWithUndo(
      context,
      ref,
      NoteChange.deletePages(ids),
      l10n.notebookPagesDeleted(ids.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = _words();
    final now = ref.watch(clockProvider)();
    final notebook = ref.watch(notebookProvider);
    final data = notebook.value ?? NotebookData();
    // A page merged or deleted elsewhere is no longer selected.
    _selected.removeWhere((id) => data.page(id) == null);
    final selecting = _selected.isNotEmpty;
    final top = data.children(null);
    final pinned = [
      for (final p in top)
        if (p.pinned) p,
    ];
    final others = [
      for (final p in top)
        if (!p.pinned) p,
    ];
    final allPinned = _selected.every((id) => data.page(id)?.pinned ?? false);

    Widget row(NotebookPage p) => Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: BvNotebookPagesSpec.rowsGap,
      ),
      child: pageRowFor(
        context,
        data,
        p,
        words: words,
        now: now,
        selecting: selecting,
        selected: _selected.contains(p.id),
        onTap: selecting
            ? () => _toggle(p)
            : () => context.push(AppRoutes.notebookPage(p.id)),
        onLongPress: () => _toggle(p),
      ),
    );

    // Review 100 B6: an iPhone's swipe from the edge does what ← does,
    // also while this screen holds Back for itself.
    return BvBackSwipe(
      holding: selecting,
      child: PopScope(
        canPop: !selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(_selected.clear);
        },
        child: Scaffold(
          backgroundColor: BvColors.surfaceApp,
          appBar: AppBar(
            backgroundColor: BvColors.surfaceApp,
            leading: selecting
                ? IconButton(
                    key: const Key('selection-close'),
                    tooltip: l10n.notebookCloseSelection,
                    icon: const Icon(BvIcons.close),
                    onPressed: () => setState(_selected.clear),
                  )
                : null,
            title: Text(
              selecting
                  ? l10n.notebookSelected(_selected.length)
                  : l10n.notebookTitle,
            ),
            actions: selecting
                ? null
                : [
                    _filterButton(data, 'notebook-filter'),
                    IconButton(
                      key: const Key('notebook-search'),
                      tooltip: l10n.notebookSearchTip,
                      icon: const Icon(BvIcons.search),
                      // Search keeps the Filter that is on (Part 8).
                      onPressed: () => context.push(
                        AppRoutes.notebookSearchIn(
                          kind: _filter.kind?.json,
                          page: _filter.on ? _filter.page : null,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('notebook-calendar'),
                      tooltip: l10n.calendarTitle,
                      icon: const Icon(BvIcons.calendar),
                      onPressed: () => context.push(AppRoutes.calendar),
                    ),
                  ],
          ),
          floatingActionButton: selecting || _filter.on
              ? null
              : NewEntryButton(
                  onTap: () => context.push(AppRoutes.notebookWrite),
                ),
          body: _filter.on
              ? _filtered(data)
              : notebook.hasError && data.pages.isEmpty
              ? Padding(
                  padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                  child: EmptyNote(l10n.notebookCouldntLoad),
                )
              : ListView(
                  key: const Key('notebook-pages'),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    BvSpace.gutter,
                    BvNotebookPagesSpec.actionTop,
                    BvSpace.gutter,
                    BvSpace.s32,
                  ),
                  children: [
                    if (pinned.isNotEmpty) ...[
                      NotebookLabel(l10n.notebookPinnedLabel),
                      for (final p in pinned) row(p),
                    ],
                    if (others.isNotEmpty) ...[
                      NotebookLabel(l10n.notebookPagesLabel),
                      for (final p in others) row(p),
                    ],
                    if (top.isEmpty && notebook.hasValue)
                      Padding(
                        key: const Key('notebook-empty'),
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: BvSpace.s24,
                        ),
                        child: Column(
                          spacing: BvSpace.s8,
                          children: [
                            const Icon(
                              BvIcons.notebook,
                              size: BvNotebookSpec.emptyIcon,
                              color: BvColors.iconSecondary,
                            ),
                            Text(
                              l10n.notebookEmptyTitle,
                              textAlign: TextAlign.center,
                              style: type.titleMd.copyWith(
                                color: BvColors.textPrimary,
                              ),
                            ),
                            Text(
                              l10n.notebookEmptyBody,
                              textAlign: TextAlign.center,
                              style: type.bodyMd.copyWith(
                                color: BvColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!selecting) NewPageRow(onTap: _newPage),
                    // Review 99B B3: Deleted items, at the list's end.
                    if (!selecting)
                      DeletedItemsRow(
                        onTap: () => context.push(AppRoutes.notebookDeleted),
                      ),
                  ],
                ),
          bottomNavigationBar: selecting
              ? SelectionBar(
                  actions: [
                    SelectionAction(
                      key: const Key('select-merge'),
                      icon: BvIcons.merge,
                      label: l10n.notebookMerge,
                      onTap: _selected.length > 1 ? () => _merge(data) : null,
                    ),
                    SelectionAction(
                      key: const Key('select-move'),
                      icon: BvIcons.moveInto,
                      label: l10n.notebookMoveInto,
                      onTap: () => _moveInto(data),
                    ),
                    SelectionAction(
                      key: const Key('select-pin'),
                      icon: BvIcons.pin,
                      label: allPinned ? l10n.daybookUnpin : l10n.notebookPin,
                      onTap: () => _pin(!allPinned),
                    ),
                    SelectionAction(
                      key: const Key('select-delete'),
                      icon: BvIcons.delete,
                      label: l10n.delete,
                      destructive: true,
                      onTap: _delete,
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}
