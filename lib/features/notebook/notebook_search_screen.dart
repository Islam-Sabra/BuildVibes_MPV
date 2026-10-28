import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/notebook_page.dart';
import '../../data/models/space.dart' show SpaceException;
import '../../data/repositories/notebook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../work/daybook_words.dart';
import 'notebook_page_parts.dart';
import 'notebook_state.dart';

/// Search in My notebook (review 99 A5): one field over every page, its
/// title, its entries' titles and the words of their lines (search_notebook:
/// Arabic letter forms and digits folded, as in Space search). Each hit
/// shows its page and date; a tap opens the entry in its page.
class NotebookSearchScreen extends ConsumerStatefulWidget {
  const NotebookSearchScreen({super.key, this.kind, this.page});

  /// The Filter that is on (review 100 Part 8): search keeps it.
  final String? kind;
  final String? page;

  @override
  ConsumerState<NotebookSearchScreen> createState() =>
      _NotebookSearchScreenState();
}

class _NotebookSearchScreenState extends ConsumerState<NotebookSearchScreen> {
  final _query = TextEditingController();
  Timer? _timer;
  List<NotebookHit>? _hits;
  bool _failed = false;

  /// The query each answer was for, so a late one is dropped.
  String _asked = '';

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _timer?.cancel();
    _timer = Timer(BvMotion.searchWait, () => unawaited(_search(text.trim())));
  }

  Future<void> _search(String q) async {
    _asked = q;
    if (q.isEmpty) {
      setState(() {
        _hits = null;
        _failed = false;
      });
      return;
    }
    try {
      final hits = await ref
          .read(notebookRepositoryProvider)
          .search(q, kind: widget.kind, page: widget.page);
      if (!mounted || _asked != q) return;
      setState(() {
        _hits = hits;
        _failed = false;
      });
    } on SpaceException {
      if (!mounted || _asked != q) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final now = ref.watch(clockProvider)();
    final data = ref.watch(notebookProvider).value ?? NotebookData();
    final hits = _hits;
    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        backgroundColor: BvColors.surfaceApp,
        title: BvSearchField(
          key: const Key('notebook-search-field'),
          placeholder: l10n.notebookSearchHint,
          controller: _query,
          autofocus: true,
          onChanged: _changed,
          onSubmitted: (q) => unawaited(_search(q.trim())),
        ),
      ),
      body: _failed
          ? Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: EmptyNote(l10n.notebookSearchFailed),
            )
          : hits == null
          ? const SizedBox.shrink()
          : hits.isEmpty
          ? Padding(
              key: const Key('notebook-search-none'),
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: EmptyNote(l10n.notebookSearchNone),
            )
          : ListView(
              key: const Key('notebook-search-hits'),
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              children: [
                for (final h in hits)
                  if (data.page(h.pageId) case final page?)
                    _Hit(
                      hit: h,
                      page: page,
                      line: l10n.notebookPageLine(
                        h.isPage ? l10n.notebookTitle : pageName(l10n, page),
                        pageRowDate(l10n, words, h.at, now),
                      ),
                      type: type,
                      onTap: () => context.push(
                        AppRoutes.notebookPage(page.id, entry: h.noteId),
                      ),
                    ),
              ],
            ),
    );
  }
}

/// A hit: the page's icon, the page or the entry's title (else its words),
/// then where it is and when.
class _Hit extends StatelessWidget {
  const _Hit({
    required this.hit,
    required this.page,
    required this.line,
    required this.type,
    required this.onTap,
  });

  final NotebookHit hit;
  final NotebookPage page;
  final String line;
  final BvTypeSet type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = hit.isPage
        ? pageName(l10n, page)
        : hit.title.trim().isNotEmpty
        ? hit.title.trim()
        : (hit.snippet ?? '').trim();
    final snippet = hit.isPage || hit.title.trim().isEmpty
        ? null
        : hit.snippet?.trim();
    return Material(
      key: Key('notebook-hit-${hit.noteId ?? hit.pageId}'),
      color: Colors.transparent,
      borderRadius: BvNotebookPagesSpec.rowRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: BvNotebookPagesSpec.rowPaddingVertical,
            horizontal: BvNotebookPagesSpec.rowPaddingStart,
          ),
          child: Row(
            spacing: BvNotebookPagesSpec.rowGap,
            children: [
              PageIconBox(icon: pageIconData(page.icon)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvNotebookPagesSpec.linesGap,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: directionOf(title),
                      style: type.labelMd.copyWith(color: BvColors.textPrimary),
                    ),
                    if (snippet != null && snippet.isNotEmpty)
                      Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: directionOf(snippet),
                        style: type.bodyMd.copyWith(
                          color: BvColors.textPrimary,
                        ),
                      ),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
