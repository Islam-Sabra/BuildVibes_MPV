import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/planning_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/note.dart';
import '../../data/models/notebook_page.dart';
import '../../data/models/post_page.dart';
import '../../data/models/space.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_segmented.dart';
import '../../shared/widgets/bv_swipe_card.dart';
import '../chat/voice.dart' show voiceTime;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../spaces/space_errors.dart';
import 'notebook_page_parts.dart';
import 'notebook_state.dart';

/// My Deleted items, newest first (my_deleted_items).
final deletedItemsProvider = FutureProvider.autoDispose<List<DeletedItem>>(
  (ref) => ref.watch(notebookRepositoryProvider).deletedItems(),
);

/// How many days they are kept (7, 30 or 90).
final keepDaysProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(notebookRepositoryProvider).keepDays(),
);

/// The days Deleted items may be kept (99B B3).
const _keepChoices = [7, 30, 90];

/// Deleted items (review 99B B3, PG8 2635:38668), from the pages list's
/// end. One single choice keeps them 7 · 30 · 90 days (rule 6; no Settings
/// entry, rule 7), then each item by the day it was deleted: what it was
/// and where it came from, with Restore. Swiped toward the start, Delete
/// forever; Empty now under them; both after one confirm. A daily job on
/// the server removes what is past its time, with its files.
class DeletedItemsScreen extends ConsumerStatefulWidget {
  const DeletedItemsScreen({super.key});

  @override
  ConsumerState<DeletedItemsScreen> createState() => _DeletedItemsScreenState();
}

class _DeletedItemsScreenState extends ConsumerState<DeletedItemsScreen> {
  /// The days chosen here, shown before the server's answer comes back.
  int? _keep;

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(Future<void> Function(NotebookRepository repo) call) async {
    try {
      await call(ref.read(notebookRepositoryProvider));
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
    ref
      ..invalidate(deletedItemsProvider)
      ..invalidate(notebookProvider);
  }

  Future<void> _setKeep(int days) async {
    setState(() => _keep = days);
    await _run((repo) => repo.setKeepDays(days));
    ref.invalidate(keepDaysProvider);
  }

  Future<void> _restore(DeletedItem item) async {
    final l10n = AppLocalizations.of(context);
    await _run((repo) => repo.restore([item.id]));
    if (mounted) _toast(l10n.notebookRestoredTo(_from(l10n, item)));
  }

  /// Delete forever's one confirm, asked before the card moves (H8).
  Future<bool> _sureForever() {
    final l10n = AppLocalizations.of(context);
    return showBvDialog(
      context: context,
      title: l10n.notebookDeleteForeverTitle,
      body: l10n.notebookCantUndo,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.notebookDeleteForever,
      destructive: true,
    );
  }

  Future<void> _forever(DeletedItem item) =>
      _run((repo) => repo.deleteForever([item.id]));

  Future<void> _empty() async {
    final l10n = AppLocalizations.of(context);
    final yes = await showBvDialog(
      context: context,
      title: l10n.notebookEmptyNowTitle,
      body: l10n.notebookCantUndo,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.notebookEmptyNow,
      destructive: true,
    );
    if (yes && mounted) await _run((repo) => repo.emptyDeleted());
  }

  /// The page it came from, as it was named.
  static String _from(AppLocalizations l10n, DeletedItem item) =>
      item.pageTitle.trim().isEmpty ? l10n.notebookUntitled : item.pageTitle;

  /// A day's label: Today, Yesterday, then "3 days ago".
  static String _day(AppLocalizations l10n, DateTime at, DateTime now) {
    final days = dayOf(now).difference(dayOf(at)).inDays;
    if (days <= 0) return l10n.notebookToday;
    if (days == 1) return l10n.notebookYesterday;
    return l10n.notebookDaysAgo(days);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final now = ref.watch(clockProvider)();
    final keep = _keep ?? ref.watch(keepDaysProvider).value ?? 30;
    final loaded = ref.watch(deletedItemsProvider);
    // The phone holds the deleted entries too (99B ruling 5): what each
    // one is made of (H21: a voice note shows the voice icon).
    final held = {
      for (final n in ref.watch(notebookProvider).value?.all ?? const <Note>[])
        if (n.deletedAt != null) n.id: n,
    };
    final items = loaded.value ?? const <DeletedItem>[];
    final byDay = <String, List<DeletedItem>>{};
    for (final i in items) {
      byDay.putIfAbsent(_day(l10n, i.deletedAt, now), () => []).add(i);
    }

    Widget row(DeletedItem i) {
      final from = _from(l10n, i);
      final blocks = held[i.id]?.pageBlocks ?? const <PageBlock>[];
      final voice = blocks.isNotEmpty && blocks.every((b) => b is PageVoice);
      final title = i.title.trim().isNotEmpty || !voice
          ? i.title
          : l10n.notebookVoiceTitle(
              voiceTime((blocks.first as PageVoice).duration),
            );
      final what = switch (i.kind) {
        DeletedKind.entry => l10n.notebookDeletedEntry(from),
        DeletedKind.part => l10n.notebookDeletedPart(from),
        DeletedKind.page =>
          i.pageTitle.trim().isEmpty
              ? l10n.notebookDeletedPageTop
              : l10n.notebookDeletedPage(from),
      };
      return Padding(
        padding: const EdgeInsetsDirectional.only(
          bottom: BvNotebookPagesSpec.rowsGap,
        ),
        child: BvSwipeCard(
          key: ValueKey(('deleted', i.id)),
          id: i.id,
          startAction: BvSwipeAction(
            key: Key('swipe-archive-${i.id}'),
            icon: BvIcons.delete,
            label: l10n.notebookDeleteForever,
            color: BvColors.textDestructive,
            confirm: _sureForever,
            onTap: () => unawaited(_forever(i)),
          ),
          child: ColoredBox(
            key: Key('deleted-${i.id}'),
            color: BvColors.surfaceApp,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: BvNotebookPagesSpec.rowPaddingVertical,
              ),
              child: Row(
                spacing: BvNotebookPagesSpec.rowGap,
                children: [
                  PageIconBox(
                    icon: voice
                        ? BvIcons.microphone
                        : switch (i.kind) {
                            DeletedKind.entry => BvIcons.pageList,
                            DeletedKind.part => BvIcons.textBlock,
                            DeletedKind.page => BvIcons.pageFolder,
                          },
                  ),
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
                          style: type.emphasis.copyWith(
                            color: BvColors.textPrimary,
                          ),
                        ),
                        Text(
                          what,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: quiet,
                        ),
                      ],
                    ),
                  ),
                  BvButton(
                    key: Key('deleted-restore-${i.id}'),
                    label: l10n.notebookRestore,
                    icon: BvIcons.sendBack,
                    // J4: words with an icon, no box (PG8, BH5).
                    style: BvButtonStyle.quiet,
                    size: BvButtonSize.medium,
                    onPressed: () => unawaited(_restore(i)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        backgroundColor: BvColors.surfaceApp,
        title: Text(l10n.notebookDeletedItems),
      ),
      body: BvSwipeGroup(
        child: ListView(
          key: const Key('deleted-items'),
          padding: const EdgeInsetsDirectional.fromSTEB(
            BvSpace.gutter,
            BvSpace.s8,
            BvSpace.gutter,
            BvSpace.s32,
          ),
          children: [
            Text(l10n.notebookKeepFor, style: quiet),
            const SizedBox(height: BvSpace.s8),
            BvSegmented<int>(
              segments: [
                for (final d in _keepChoices)
                  BvSegment(
                    key: Key('keep-$d'),
                    value: d,
                    label: l10n.notebookKeepDays(d),
                  ),
              ],
              value: keep,
              onChanged: (d) => unawaited(_setKeep(d)),
            ),
            const SizedBox(height: BvSpace.s8),
            Text(l10n.notebookKeepNote(keep), style: quiet),
            if (loaded.hasValue && items.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: BvSpace.s24,
                ),
                child: EmptyNote(l10n.notebookDeletedNone),
              ),
            for (final MapEntry(key: day, value: list) in byDay.entries) ...[
              NotebookLabel(day),
              for (final i in list) row(i),
            ],
            if (items.isNotEmpty)
              Center(
                child: TextButton(
                  key: const Key('deleted-empty-now'),
                  onPressed: () => unawaited(_empty()),
                  child: Text(
                    l10n.notebookEmptyNow,
                    style: type.labelMd.copyWith(
                      color: BvColors.textDestructive,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Deleted items ›" at the pages list's end (99B B3): a quiet row.
class DeletedItemsRow extends StatelessWidget {
  const DeletedItemsRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      key: const Key('notebook-deleted'),
      onTap: onTap,
      borderRadius: BvNotebookPagesSpec.rowRadius,
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
            const Icon(
              BvIcons.delete,
              size: BvSize.iconMd,
              color: BvColors.iconSecondary,
            ),
            Expanded(
              child: Text(
                AppLocalizations.of(context).notebookDeletedItems,
                style: BvType.of(
                  context,
                ).bodyMd.copyWith(color: BvColors.textSecondary),
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
  );
}
