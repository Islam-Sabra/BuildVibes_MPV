import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/library.dart';
import '../../data/models/space_search.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/search_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../library/library_parts.dart' show libraryDay;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import 'former_member.dart';

/// S · Search inside the Space (2543:35148): the field with ✕ and
/// Cancel; after 2 characters and a short pause, what the reader may see,
/// in three groups: Work items (a checklist point under its post), Files
/// (the version in use only) and Chat, each row with its date. A row opens
/// the card in the daybook, the file's page or the thread at that
/// message. Never a result count (rule 3).
class SpaceSearchScreen extends ConsumerStatefulWidget {
  const SpaceSearchScreen({super.key, required this.spaceId});

  final String spaceId;

  /// The pause after the last key before it searches.
  static const pause = Duration(milliseconds: 300);

  @override
  ConsumerState<SpaceSearchScreen> createState() => _SpaceSearchScreenState();
}

class _SpaceSearchScreenState extends ConsumerState<SpaceSearchScreen> {
  final _field = TextEditingController();
  Timer? _wait;
  var _query = '';

  @override
  void dispose() {
    _wait?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _wait?.cancel();
    // The server refuses more than maxLength; a long paste searches its
    // start.
    final q = text
        .trim()
        .characters
        .take(SearchRepository.maxLength)
        .toString();
    if (q.length < SearchRepository.minLength) {
      setState(() => _query = '');
      return;
    }
    _wait = Timer(SpaceSearchScreen.pause, () {
      if (mounted) setState(() => _query = q);
    });
    // The ✕ shows as soon as there is text.
    setState(() {});
  }

  void _clear() {
    _wait?.cancel();
    _field.clear();
    setState(() => _query = '');
  }

  Future<void> _open(SpaceSearchHit h) async {
    final space = widget.spaceId;
    switch (h.kind) {
      case SpaceSearchKind.post || SpaceSearchKind.point:
        context.push(AppRoutes.spaceCard(space, h.postId!));
      case SpaceSearchKind.file:
        // "Add a new version" hands the file back; the Space opens the
        // writing card replacing it, as from the Library.
        final replaces = await context.push<LibraryFile>(
          AppRoutes.libraryFilePage(space, h.id),
        );
        if (replaces != null && mounted) context.pop(replaces);
      case SpaceSearchKind.message:
        context.push(AppRoutes.spaceThread(space, h.threadId!, message: h.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final q = _query;
    final results = q.isEmpty
        ? null
        : ref.watch(spaceSearchProvider((spaceId: widget.spaceId, query: q)));

    final Widget body;
    if (results == null) {
      body = const SizedBox.shrink();
    } else if (results.value case final hits?) {
      body = hits.isEmpty
          ? Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: EmptyNote(l10n.searchNothing(inOwnDirection(q))),
            )
          : _Results(hits: hits, onOpen: _open);
    } else if (results.hasError) {
      body = Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: EmptyNote(l10n.errorGeneric),
      );
    } else {
      body = const Padding(
        padding: EdgeInsetsDirectional.all(BvSpace.s32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSearchSpec.paddingStart,
                BvSpace.s8,
                BvSearchSpec.paddingEnd,
                BvSpace.s8,
              ),
              child: Row(
                spacing: BvSearchSpec.cancelGap,
                children: [
                  Expanded(
                    child: Stack(
                      alignment: AlignmentDirectional.centerEnd,
                      children: [
                        BvSearchField(
                          key: const Key('search-field'),
                          controller: _field,
                          placeholder: l10n.searchHint,
                          autofocus: true,
                          onChanged: _changed,
                        ),
                        if (_field.text.isNotEmpty)
                          IconButton(
                            key: const Key('search-clear'),
                            tooltip: l10n.searchClear,
                            icon: const Icon(
                              BvIcons.close,
                              size: BvSize.iconMd,
                              color: BvColors.iconSecondary,
                            ),
                            onPressed: _clear,
                          ),
                      ],
                    ),
                  ),
                  BvTapTarget(
                    child: Semantics(
                      button: true,
                      child: GestureDetector(
                        key: const Key('search-cancel'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Text(
                          l10n.commonCancel,
                          style: type.bodyMd.copyWith(
                            color: BvColors.textAction,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The three groups, in the frame's order, each newest first.
class _Results extends ConsumerWidget {
  const _Results({required this.hits, required this.onOpen});

  final List<SpaceSearchHit> hits;
  final ValueChanged<SpaceSearchHit> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final groups = [
      (
        l10n.searchWorkItems,
        [
          for (final h in hits)
            if (h.isWork) h,
        ],
      ),
      (
        l10n.searchFiles,
        [
          for (final h in hits)
            if (h.kind == SpaceSearchKind.file) h,
        ],
      ),
      (
        l10n.searchChat,
        [
          for (final h in hits)
            if (h.kind == SpaceSearchKind.message) h,
        ],
      ),
    ];
    return ListView(
      key: const Key('search-results'),
      padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
      children: [
        for (final (label, rows) in groups)
          if (rows.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvSearchSpec.groupTop,
                BvSpace.gutter,
                BvSpace.s4,
              ),
              child: Text(
                label,
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
            ),
            for (final h in rows)
              _HitRow(
                key: Key('search-${h.kind.name}-${h.id}'),
                hit: h,
                onTap: () => onOpen(h),
              ),
          ],
      ],
    );
  }
}

class _HitRow extends ConsumerWidget {
  const _HitRow({super.key, required this.hit, required this.onTap});

  final SpaceSearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = ref.watch(clockProvider)();
    final day = libraryDay(l10n, locale, hit.createdAt.toLocal(), now);
    final who = inOwnDirection(personName(l10n, hit.authorName));
    final snippet = (hit.snippet ?? '').trim();
    final title = (hit.title ?? '').trim();

    final (IconData icon, String main, String line) = switch (hit.kind) {
      SpaceSearchKind.post => (
        BvIcons.workItems,
        title.isEmpty ? snippet : title,
        joinMeta([who, day]),
      ),
      // A point, under its post.
      SpaceSearchKind.point => (
        BvIcons.check,
        snippet,
        joinMeta([if (title.isNotEmpty) title, day]),
      ),
      SpaceSearchKind.file => (
        BvIcons.document,
        inOwnDirection(title),
        joinMeta([if (snippet.isNotEmpty) snippet, day]),
      ),
      SpaceSearchKind.message => (
        BvIcons.chat,
        l10n.searchMessage(snippet),
        joinMeta([who, day]),
      ),
    };

    final stamp = !hit.isWork
        ? null
        : hit.cancelled
        ? BvInkStamp(
            label: l10n.daybookStampCancelled,
            size: BvInkStampSize.xs,
            tone: BvInkStampTone.muted,
          )
        : switch (hit.status) {
            WorkStatus.done => BvInkStamp(
              label: l10n.daybookStampDone,
              size: BvInkStampSize.xs,
            ),
            WorkStatus.checked => BvInkStamp(
              label: l10n.daybookStampChecked,
              size: BvInkStampSize.xs,
              tone: BvInkStampTone.positive,
            ),
            _ => null,
          };

    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.gutter,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: BvColors.borderDefault,
                width: BvStroke.thin,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: BvSearchSpec.rowPaddingVertical,
            ),
            child: Row(
              spacing: BvSearchSpec.rowGap,
              children: [
                Container(
                  width: BvSearchSpec.tile,
                  height: BvSearchSpec.tile,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: BvColors.surfaceSubtle,
                    borderRadius: BvRadius.controlAll,
                  ),
                  child: Icon(
                    icon,
                    size: BvSearchSpec.tileIcon,
                    color: BvColors.iconPrimary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvSpace.s2,
                    children: [
                      Text(
                        main,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: directionOf(main),
                        style: type.bodyMd,
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
                ?stamp,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
