import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/notebook_page.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_line_popover.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../work/daybook_words.dart';
import 'notebook_page_parts.dart';
import 'notebook_state.dart';

/// What the Filter shows (review 100 Part 8): one single choice (rule 6).
enum NoteFilter {
  todosOpen('todos_open'),
  photos('photos'),
  files('files'),
  voice('voice'),
  reminders('reminders'),
  archived('archived');

  const NoteFilter(this.json);

  /// search_notebook's p_kind.
  final String json;

  String label(AppLocalizations l10n) => switch (this) {
    todosOpen => l10n.notebookFilterTodos,
    photos => l10n.notebookFilterPhotos,
    files => l10n.notebookFilterFiles,
    voice => l10n.notebookFilterVoice,
    reminders => l10n.notebookFilterReminders,
    archived => l10n.notebookFilterArchived,
  };

  IconData get icon => switch (this) {
    todosOpen => BvIcons.openTodos,
    photos => BvIcons.image,
    files => BvIcons.document,
    voice => BvIcons.microphone,
    reminders => BvIcons.remind,
    archived => BvIcons.archive,
  };
}

/// A Filter as it is on a screen: what it shows, and in which page (null:
/// all pages). On once [kind] is chosen.
@immutable
class NoteFilterState {
  const NoteFilterState({this.kind, this.page});

  final NoteFilter? kind;
  final String? page;

  bool get on => kind != null;

  NoteFilterState copyWith({NoteFilter? kind, String? Function()? page}) =>
      NoteFilterState(
        kind: kind ?? this.kind,
        page: page == null ? this.page : page(),
      );

  @override
  bool operator ==(Object other) =>
      other is NoteFilterState && other.kind == kind && other.page == page;

  @override
  int get hashCode => Object.hash(kind, page);
}

/// The entries a Filter finds (search_notebook with its kind and page),
/// newest first.
final noteFilterHitsProvider = FutureProvider.autoDispose
    .family<List<NotebookHit>, NoteFilterState>(
      (ref, f) => ref
          .watch(notebookRepositoryProvider)
          .search('', kind: f.kind!.json, page: f.page),
    );

/// The Filter's card (review 100 BH9), from the top bar: SHOW, one choice;
/// IN, All pages ›, which turns the same card into the page list.
/// [onChanged] gets the Filter picked; the card closes once it is on.
class NoteFilterCard extends StatefulWidget {
  const NoteFilterCard({
    super.key,
    required this.data,
    required this.filter,
    required this.onChanged,
    this.pages = false,
  });

  final NotebookData data;
  final NoteFilterState filter;
  final ValueChanged<NoteFilterState> onChanged;

  /// Opens on the page list (the page chip).
  final bool pages;

  @override
  State<NoteFilterCard> createState() => _NoteFilterCardState();
}

class _NoteFilterCardState extends State<NoteFilterCard> {
  late var _filter = widget.filter;
  late var _pages = widget.pages;

  /// Every page, those pinned first, then by latest activity.
  List<NotebookPage> get _all =>
      [...widget.data.pages]..sort(NotebookData.byPinThenActivity);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_pages) {
      return BvPopoverMenu<String?>.line(
        key: const Key('notebook-filter-menu'),
        scrolls: true,
        back: l10n.notebookFilterIn,
        onBack: () => setState(() => _pages = false),
        checked: _filter.page,
        items: [
          BvMenuItem(
            key: const Key('filter-page-all'),
            value: null,
            label: l10n.notebookAllPages,
            icon: BvIcons.pageFolder,
          ),
          for (final p in _all)
            BvMenuItem(
              key: Key('filter-page-${p.id}'),
              value: p.id,
              label: pageName(l10n, p),
              icon: pageIconData(p.icon),
            ),
        ],
        onSelected: (page) {
          final next = _filter.copyWith(page: () => page);
          setState(() {
            _filter = next;
            _pages = false;
          });
          if (next.on) widget.onChanged(next);
        },
      );
    }
    final page = widget.data.page(_filter.page);
    return BvPopoverMenu<Object>.line(
      key: const Key('notebook-filter-menu'),
      checked: _filter.kind,
      items: [
        for (final k in NoteFilter.values)
          BvMenuItem(
            key: Key('filter-show-${k.json}'),
            value: k,
            label: k.label(l10n),
            icon: k.icon,
            group: l10n.notebookFilterShow,
          ),
        BvMenuItem(
          key: const Key('filter-in'),
          value: #pages,
          label: page == null ? l10n.notebookAllPages : pageName(l10n, page),
          icon: BvIcons.pageFolder,
          group: l10n.notebookFilterIn,
          more: true,
        ),
      ],
      onSelected: (v) {
        if (v is NoteFilter) {
          widget.onChanged(_filter.copyWith(kind: v));
        } else {
          setState(() => _pages = true);
        }
      },
    );
  }
}

/// Opens [NoteFilterCard] under the Filter button [anchor].
void showNoteFilter(
  BuildContext context,
  BvLinePopover card, {
  required BuildContext? Function() anchor,
  required NotebookData data,
  required NoteFilterState filter,
  required ValueChanged<NoteFilterState> onChanged,
  bool pages = false,
}) => card.show(
  context,
  anchor: anchor,
  atEnd: true,
  barrier: true,
  onDismiss: card.hide,
  builder: (_) => NoteFilterCard(
    data: data,
    filter: filter,
    pages: pages,
    onChanged: (f) {
      card.hide();
      onChanged(f);
    },
  ),
);

/// The Filter in the top bar: highlighted while on (review 100 BH11).
class NoteFilterButton extends StatelessWidget {
  const NoteFilterButton({
    super.key,
    required this.on,
    required this.onPressed,
  });

  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).notebookFilter,
    style: on
        ? IconButton.styleFrom(backgroundColor: BvColors.surfaceBrandSoft)
        : null,
    icon: Icon(
      BvIcons.filter,
      key: on ? const Key('notebook-filter-on') : null,
    ),
    onPressed: onPressed,
  );
}

/// Under the top bar while a Filter is on (BH11): what it shows, with ✕
/// to turn it off, then the page ("All pages ▾"), which opens the page list.
class NoteFilterChips extends StatelessWidget {
  const NoteFilterChips({
    super.key,
    required this.data,
    required this.filter,
    required this.onClear,
    required this.onPage,
  });

  final NotebookData data;
  final NoteFilterState filter;
  final VoidCallback onClear;
  final VoidCallback onPage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final kind = filter.kind!;
    final page = data.page(filter.page);
    final label = page == null ? l10n.notebookAllPages : pageName(l10n, page);
    Widget chip({
      required Key key,
      required IconData icon,
      required String text,
      required bool active,
      required Widget end,
      VoidCallback? onTap,
    }) => Material(
      key: key,
      color: active ? BvColors.surfaceBrandSoft : BvColors.surfaceSubtle,
      shape: StadiumBorder(
        side: BorderSide(
          color: active ? BvColors.borderSelected : BvColors.borderSubtle,
          width: BvStroke.thin,
        ),
      ),
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
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.labelSm.copyWith(color: BvColors.textPrimary),
                ),
              ),
              end,
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s4,
        BvSpace.gutter,
        BvSpace.s8,
      ),
      child: Row(
        spacing: BvSpace.s8,
        children: [
          Flexible(
            child: chip(
              key: const Key('filter-chip-kind'),
              icon: kind.icon,
              text: kind.label(l10n),
              active: true,
              end: Semantics(
                button: true,
                label: l10n.notebookFilterOff,
                excludeSemantics: true,
                child: InkResponse(
                  key: const Key('filter-clear'),
                  onTap: onClear,
                  radius: BvNotebookPagesSpec.chipCaret,
                  child: const Icon(
                    BvIcons.close,
                    size: BvNotebookPagesSpec.chipCaret,
                    color: BvColors.iconPrimary,
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: chip(
              key: const Key('filter-chip-page'),
              icon: BvIcons.pageFolder,
              text: label,
              active: false,
              onTap: onPage,
              end: const Icon(
                BvIcons.caretDown,
                size: BvNotebookPagesSpec.chipCaret,
                color: BvColors.iconPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The entries a Filter found (BH11), grouped by page, newest first: the
/// page's icon and name over its entries, each its title and when.
class NoteFilterResults extends ConsumerWidget {
  const NoteFilterResults({
    super.key,
    required this.data,
    required this.filter,
  });

  final NotebookData data;
  final NoteFilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final now = ref.watch(clockProvider)();
    final found = ref.watch(noteFilterHitsProvider(filter));
    final hits = [
      for (final h in found.value ?? const <NotebookHit>[])
        if (!h.isPage) h,
    ]..sort((a, b) => b.at.compareTo(a.at));
    if (found.isLoading && !found.hasValue) return const SizedBox.shrink();
    if (found.hasError && !found.hasValue) {
      return Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: EmptyNote(l10n.notebookCouldntLoad),
      );
    }
    if (hits.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: EmptyNote(l10n.notebookFilterNone),
      );
    }
    final byPage = <String, List<NotebookHit>>{};
    for (final h in hits) {
      byPage.putIfAbsent(h.pageId, () => []).add(h);
    }
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    return ListView(
      key: const Key('filter-results'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        0,
        BvSpace.gutter,
        BvSpace.s32,
      ),
      children: [
        for (final MapEntry(key: id, value: list) in byPage.entries) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: BvNotebookPagesSpec.labelTop,
              bottom: BvNotebookPagesSpec.labelBottom,
            ),
            child: Row(
              spacing: BvSpace.s6,
              children: [
                Icon(
                  data.page(id) == null
                      ? BvIcons.pageFolder
                      : pageIconData(data.page(id)!.icon),
                  size: BvNotebookPagesSpec.chipIcon,
                  color: BvColors.iconSecondary,
                ),
                Flexible(
                  child: Text(
                    data.page(id) == null
                        ? l10n.notebookUntitled
                        : pageName(l10n, data.page(id)!),
                    style: quiet,
                  ),
                ),
              ],
            ),
          ),
          for (final h in list)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: BvNotebookPagesSpec.entryGap,
              ),
              child: Material(
                key: Key('filter-hit-${h.noteId}'),
                color: BvColors.surfaceElevated,
                borderRadius: BvNotebookPagesSpec.entryRadius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push(
                    AppRoutes.notebookPage(h.pageId, entry: h.noteId),
                  ),
                  child: Padding(
                    padding: BvNotebookPagesSpec.entryPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: BvNotebookPagesSpec.linesGap,
                      children: [
                        Text(
                          h.title.isEmpty ? (h.snippet ?? '') : h.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: directionOf(h.title),
                          style: type.emphasis.copyWith(
                            color: BvColors.textPrimary,
                          ),
                        ),
                        Text(
                          l10n.notebookPageLine(
                            pageRowDate(l10n, words, h.at, now),
                            words.time.clock(h.at),
                          ),
                          style: quiet,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
