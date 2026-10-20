import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/activity.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_marked_text.dart';
import '../../shared/widgets/bv_needs_row.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/former_member.dart';
import '../work/daybook_photos.dart' show daybookPhotoProvider;
import '../work/daybook_words.dart';
import 'activity_state.dart';
import 'needs_card.dart' show openNeeds;

/// Needs you, across all your Spaces (2544:35068), the list only: each
/// Space's things under its name, from needs_you(). A row opens the
/// Space's daybook (a join request, its People tab); opening the exact
/// slip comes with pushes in slice 10.
///
/// A checklist with points left for you (needs_you's checklist_for_you)
/// has its paper clip on its daybook card (slice 2); it joins this list
/// with Needs you across Spaces (slice 10).
class NeedsYouScreen extends ConsumerWidget {
  const NeedsYouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final cards = ref.watch(needsCardsProvider);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final now = ref.watch(clockProvider)();

    // Each Space once, in the order its first thing came.
    final bySpace = <String, List<NeedsCard>>{};
    for (final c in cards.value ?? const <NeedsCard>[]) {
      bySpace.putIfAbsent(c.spaceId, () => []).add(c);
    }

    String label(NeedsKind k) => switch (k) {
      NeedsKind.youCheck => l10n.needsRowCheck,
      NeedsKind.forYou => l10n.needsRowForYou,
      NeedsKind.sentBack => l10n.needsRowSentBack,
      NeedsKind.ownerLeft => l10n.needsRowOwnerLeft,
      NeedsKind.joinRequest => l10n.needsRowJoin,
    };

    // Who and when; F34: the name stands out, and a due is grey, the
    // primary colour today or red when late.
    ({String? text, List<BvMark> marks}) meta(NeedsCard c) {
      final name = c.actorName == null
          ? null
          : inOwnDirection(personName(l10n, c.actorName));
      final due = c.due;
      final late =
          due != null &&
          (c.dueAt != null ? now.isAfter(c.dueAt!) : dayOf(now).isAfter(due));
      final dueText =
          due != null &&
              (c.kind == NeedsKind.forYou || c.kind == NeedsKind.ownerLeft)
          ? words.due(due, c.dueAt, now: now, late: late)
          : null;
      final detail =
          dueText ??
          (c.kind == NeedsKind.youCheck || c.kind == NeedsKind.sentBack
              ? words.time.clock(c.at)
              : null);
      final parts = [?name, ?detail];
      return (
        text: parts.isEmpty ? null : joinMeta(parts),
        marks: [
          if (name != null)
            (
              part: name,
              style: type.emphasisSm.copyWith(color: BvColors.textPrimary),
            ),
          if (dueText != null)
            (
              part: dueText,
              style: type.metadata.copyWith(
                color: bvDueColor(
                  late
                      ? BvDueTone.late
                      : due == dayOf(now)
                      ? BvDueTone.today
                      : BvDueTone.quiet,
                ),
              ),
            ),
        ],
      );
    }

    Widget row(NeedsCard c) {
      final path = c.photoPath;
      return BvNeedsRow(
        key: Key('needs-row-${c.workItemId ?? c.requestId ?? c.spaceId}'),
        label: label(c.kind),
        title: c.kind == NeedsKind.joinRequest
            ? personName(l10n, c.actorName)
            : c.workItemTitle ?? '',
        meta: c.kind == NeedsKind.joinRequest ? null : meta(c).text,
        metaMarks: c.kind == NeedsKind.joinRequest ? const [] : meta(c).marks,
        photo: path == null ? null : ref.watch(daybookPhotoProvider(path)),
        onTap: () => openNeeds(context, c),
      );
    }

    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(backgroundColor: BvColors.surfaceApp),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(needsCardsProvider.future),
        child: ListView(
          key: const Key('needs-you'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvNeedsSpec.titlePaddingHorizontal,
                BvNeedsSpec.titlePaddingTop,
                BvNeedsSpec.titlePaddingHorizontal,
                BvNeedsSpec.titlePaddingBottom,
              ),
              child: Text(l10n.needsTitle, style: type.headingMd),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
              ),
              child: switch (cards) {
                AsyncData() when bySpace.isEmpty => EmptyNote(l10n.needsNone),
                AsyncData() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BvNeedsSpec.groupGap,
                  children: [
                    for (final group in bySpace.values)
                      BvNeedsGroup(
                        name: group.first.spaceName,
                        rows: [for (final c in group) row(c)],
                      ),
                  ],
                ),
                AsyncError() => EmptyNote(l10n.errorGeneric),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}
