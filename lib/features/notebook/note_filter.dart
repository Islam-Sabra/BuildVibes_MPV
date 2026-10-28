import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/note.dart';
import '../../data/models/notebook_page.dart';
import '../../data/models/post_page.dart';
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

/// A sort of the Filter card's SORT (review 102 N5).
abstract interface class NoteSort {
  /// How the phone keeps it.
  String get json;
  String label(AppLocalizations l10n);
  IconData get icon;
}

/// How the pages list is sorted (N5, review 104 N7), one single choice;
/// pinned pages stay on top in each.
enum PageSort implements NoteSort {
  activity('activity'),
  name('name'),
  created('created'),
  oldestCreated('oldest_created');

  const PageSort(this.json);

  @override
  final String json;

  static PageSort of(String? json) =>
      values.firstWhere((s) => s.json == json, orElse: () => activity);

  @override
  String label(AppLocalizations l10n) => switch (this) {
    activity => l10n.notebookSortActivity,
    name => l10n.notebookSortName,
    created => l10n.notebookSortCreated,
    oldestCreated => l10n.notebookSortOldestCreated,
  };

  @override
  IconData get icon => switch (this) {
    activity => BvIcons.sortActivity,
    name => BvIcons.sortName,
    created => BvIcons.sortCreated,
    oldestCreated => BvIcons.sortOldestCreated,
  };

  /// The pages in this sort, those pinned first; [name] is each page's
  /// name as shown, in [lang].
  Comparator<NotebookPage> order(
    String lang,
    String Function(NotebookPage) name,
  ) => (a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return switch (this) {
      activity => b.lastActivityAt.compareTo(a.lastActivityAt),
      PageSort.name => byName(lang)(name(a), name(b)),
      created => b.createdAt.compareTo(a.createdAt),
      oldestCreated => a.createdAt.compareTo(b.createdAt),
    };
  };
}

/// How a page's entries are sorted (N5, review 104 N7), one single choice.
/// Day headers and the hand order (N3) are only in the two date sorts.
enum EntrySort implements NoteSort {
  newest('newest'),
  oldest('oldest'),
  name('name'),
  type('type');

  const EntrySort(this.json);

  @override
  final String json;

  static EntrySort of(String? json) =>
      values.firstWhere((s) => s.json == json, orElse: () => newest);

  @override
  String label(AppLocalizations l10n) => switch (this) {
    newest => l10n.notebookSortNewest,
    oldest => l10n.notebookSortOldest,
    EntrySort.name => l10n.notebookSortName,
    type => l10n.notebookSortType,
  };

  @override
  IconData get icon => switch (this) {
    newest => BvIcons.sortNewest,
    oldest => BvIcons.sortOldest,
    EntrySort.name => BvIcons.sortName,
    type => BvIcons.sortType,
  };

  /// Newest first or Oldest first: by day, with the hand order.
  bool get byDate => this == newest || this == oldest;

  /// [notes] (newest first, as the page keeps them) in this sort; [lang]
  /// for Name A–Z. Type keeps newest first inside each group.
  List<Note> sorted(List<Note> notes, String lang) => switch (this) {
    newest => notes,
    oldest => notes.reversed.toList(),
    EntrySort.name =>
      [...notes]..sort((a, b) {
        final by = byName(lang)(entryName(a), entryName(b));
        return by != 0 ? by : b.createdAt.compareTo(a.createdAt);
      }),
    type => [
      for (final t in EntryType.values)
        for (final n in notes)
          if (EntryType.of(n) == t) n,
    ],
  };
}

/// An entry's name for Name A–Z (N7): its title, or its first line when
/// it has none.
String entryName(Note n) {
  final title = n.title.trim();
  if (title.isNotEmpty) return title;
  for (final b in n.blocks ?? const <PageBlock>[]) {
    final words = blockWords(b);
    if (words.isNotEmpty) return words.first;
  }
  return n.body.trim().split('\n').first;
}

/// The groups of the Type sort (N7), in their order: an entry goes under
/// the first it has.
enum EntryType {
  todos,
  checklists,
  photos,
  files,
  voice,
  text;

  String label(AppLocalizations l10n) => switch (this) {
    todos => l10n.notebookTypeTodos,
    checklists => l10n.notebookTypeChecklists,
    photos => l10n.notebookTypePhotos,
    files => l10n.notebookTypeFiles,
    voice => l10n.notebookTypeVoice,
    text => l10n.notebookTypeText,
  };

  static EntryType of(Note n) {
    final blocks = <PageBlock>[];
    void walk(List<PageBlock> list) {
      for (final b in list) {
        blocks.add(b);
        if (b case PageToggle(:final children)) walk(children);
      }
    }

    walk(n.blocks ?? const []);
    bool has<T>() => blocks.any((b) => b is T);
    if (n.kind == NoteKind.todo || has<PageTodo>()) return todos;
    if (n.kind == NoteKind.checklist) return checklists;
    if (n.photos.isNotEmpty || has<PagePhoto>()) return photos;
    if (n.files.isNotEmpty || has<PageFile>()) return files;
    if (n.kind == NoteKind.voice || has<PageVoice>()) return voice;
    return text;
  }
}

/// Where the phone keeps the pages list's sort, and each page's (N5).
const pageSortKey = 'notebook_sort_pages';
String entrySortKey(String page) => 'notebook_sort_page:$page';

/// Name A–Z (N5): the titles of each alphabet together, [lang]'s own
/// first; Arabic by its letters (the forms of alef as alef), Latin with no
/// regard to case.
Comparator<String> byName(String lang) {
  final letter = RegExp(r'[A-Za-z\u00C0-\u024F\u0600-\u06FF]');
  final arabic = RegExp(r'[\u0600-\u06FF]');
  bool isArabic(String t) {
    final first = letter.firstMatch(t);
    return first != null && arabic.hasMatch(first.group(0)!);
  }

  String plain(String t) => t
      .toLowerCase()
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
  int group(String t) => isArabic(t) == (lang == 'ar') ? 0 : 1;
  return (a, b) {
    final g = group(a).compareTo(group(b));
    if (g != 0) return g;
    final p = plain(a).compareTo(plain(b));
    return p != 0 ? p : a.compareTo(b);
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
/// IN, All pages ›, which turns the same card into the page list; SORT,
/// one choice of [sorts] (review 102 N5). [onChanged] gets the Filter
/// picked; the card closes once it is on. [onSort] gets the sort picked.
class NoteFilterCard extends StatefulWidget {
  const NoteFilterCard({
    super.key,
    required this.data,
    required this.filter,
    required this.onChanged,
    this.pages = false,
    this.sorts = const [],
    this.sort,
    this.onSort,
  });

  final NotebookData data;
  final NoteFilterState filter;
  final ValueChanged<NoteFilterState> onChanged;
  final List<NoteSort> sorts;
  final NoteSort? sort;
  final ValueChanged<NoteSort>? onSort;

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
        tiles: false,
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
      tiles: false,
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
        for (final s in widget.sorts)
          BvMenuItem(
            key: Key('sort-${s.json}'),
            value: s,
            label: s.label(l10n),
            icon: s.icon,
            group: l10n.notebookSortLabel,
            checked: s == widget.sort,
          ),
      ],
      onSelected: (v) {
        if (v is NoteFilter) {
          widget.onChanged(_filter.copyWith(kind: v));
        } else if (v is NoteSort) {
          widget.onSort?.call(v);
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
  List<NoteSort> sorts = const [],
  NoteSort? sort,
  ValueChanged<NoteSort>? onSort,
}) => card.show(
  context,
  anchor: anchor,
  atEnd: true,
  barrier: true,
  dim: true,
  onDismiss: card.hide,
  builder: (_) => NoteFilterCard(
    data: data,
    filter: filter,
    pages: pages,
    onChanged: (f) {
      card.hide();
      onChanged(f);
    },
    sorts: sorts,
    sort: sort,
    onSort: onSort == null
        ? null
        : (s) {
            card.hide();
            onSort(s);
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
    final kind = filter.kind!;
    final page = data.page(filter.page);
    final label = page == null ? l10n.notebookAllPages : pageName(l10n, page);
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
            child: _chip(
              context,
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
            child: _chip(
              context,
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

/// A chip under the top bar (BH11): its icon, words and what ends it.
Widget _chip(
  BuildContext context, {
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
              style: BvType.of(
                context,
              ).labelSm.copyWith(color: BvColors.textPrimary),
            ),
          ),
          end,
        ],
      ),
    ),
  ),
);

/// Under the top bar while a sort isn't the default (review 102 N5): its
/// name, with ✕ to put the default back.
class NoteSortChip extends StatelessWidget {
  const NoteSortChip({super.key, required this.sort, required this.onClear});

  final NoteSort sort;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s4,
        BvSpace.gutter,
        BvSpace.s8,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _chip(
          context,
          key: const Key('sort-chip'),
          icon: sort.icon,
          text: sort.label(l10n),
          active: true,
          end: Semantics(
            button: true,
            label: l10n.notebookSortOff,
            excludeSemantics: true,
            child: InkResponse(
              key: const Key('sort-clear'),
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
    // H4: checked against what the phone holds: an entry deleted or
    // archived here (its Undo still showing, or no signal) leaves the
    // results; an Archived hit brought back leaves them too.
    final archived = filter.kind == NoteFilter.archived;
    bool still(NotebookHit h) {
      final here = data.all.where((n) => n.id == h.noteId).firstOrNull;
      if (here == null) return true;
      if (here.deletedAt != null) return false;
      return archived == (here.archivedAt != null);
    }

    final hits = [
      for (final h in found.value ?? const <NotebookHit>[])
        if (!h.isPage && still(h)) h,
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
                  // An Archived hit opens its page's archived list on it.
                  onTap: () => context.push(
                    archived
                        ? AppRoutes.notebookArchived(h.pageId, entry: h.noteId)
                        : AppRoutes.notebookPage(h.pageId, entry: h.noteId),
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
