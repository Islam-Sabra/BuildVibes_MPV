import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/profile_page_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../core/design/around_specs.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_proof_card.dart';
import '../../shared/widgets/bv_site_photo.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/widgets/entry_scaffold.dart';
import '../work/daybook_photos.dart' show daybookPhotoProvider;
import '../spaces/space_errors.dart';
import 'widgets/profile_parts.dart';

String _day(BuildContext context, DateTime d) =>
    BvWesternDigitsFormatter.normalise(
      DateFormat(
        'd MMM',
        Localizations.localeOf(context).toLanguageTag(),
      ).format(d.toLocal()),
    );

/// One delivered item: the photo with its place, the title, the project,
/// who checked it and when. [footer] says whether it is shown (RE2).
class DeliveredCard extends ConsumerWidget {
  const DeliveredCard({
    super.key,
    required this.work,
    this.footer,
    this.selected = false,
    this.onTap,
  });

  final DeliveredWork work;
  final Widget? footer;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final url = work.photoPath == null
        ? null
        : ref.watch(workPhotoUrlProvider(work.photoPath!)).value;
    return Material(
      color: BvColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BvRadius.cardAll,
        side: BorderSide(
          color: selected ? BvColors.borderSelected : BvColors.borderDefault,
          width: selected ? BvStroke.thick : BvStroke.thin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('delivered-${work.id}'),
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s4,
            children: [
              BvSitePhoto(
                photo: url == null ? null : NetworkImage(url),
                stamp: work.place ?? '',
              ),
              const SizedBox(height: BvSpace.s4),
              Text(
                work.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: type.labelLg,
              ),
              if (work.projectName != null)
                Text(
                  work.projectName!,
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
              // No name across a block: still Checked (review 11).
              if (work.checkedAt != null)
                Text(
                  work.checkedByName == null
                      ? l10n.deliveredCheckedOn(_day(context, work.checkedAt!))
                      : l10n.deliveredCheckedBy(
                          work.checkedByName!,
                          _day(context, work.checkedAt!),
                        ),
                  style: type.bodySm.copyWith(color: BvColors.textPositive),
                ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// Two cards a row.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: BvSpace.s12,
      children: [
        for (var i = 0; i < children.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s12,
              children: [
                Expanded(child: children[i]),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Proof of work on a profile (R1 v4 2556:35424, 2544:35381): what the
/// person chose to show, each as a proof card (the Done photo with
/// CHECKED, the title, the project, who checked it and when). For
/// yourself, "Choose what shows" opens RE2. No counts (rule 3).
class ProofOfWork extends ConsumerWidget {
  const ProofOfWork({super.key, required this.profileId, required this.own});

  final String profileId;
  final bool own;

  /// The most shown on the profile; the rest is a tap away.
  static const shownMax = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final shown = ref.watch(shownWorkProvider(profileId)).value ?? const [];
    final mine = own
        ? ref.watch(myDeliveredWorkProvider).value ?? const <DeliveredWork>[]
        : const <DeliveredWork>[];
    final stamp = arabic
        ? l10n.signOffChecked
        : l10n.signOffChecked.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvProofCardSpec.listGap,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.profileProofOfWork,
                style: BvType.of(context).titleLg,
              ),
            ),
            // For yourself: show or hide each item (RE2).
            if (own && mine.isNotEmpty)
              BvButton(
                key: const Key('delivered-see-all'),
                label: l10n.proofChooseShown,
                style: BvButtonStyle.tertiary,
                size: BvButtonSize.medium,
                padded: false,
                onPressed: () => context.push(AppRoutes.profileDelivered),
              ),
          ],
        ),
        if (shown.isEmpty)
          EmptyNote(
            mine.isEmpty ? l10n.workDeliveredEmpty : l10n.deliveredNoneShown,
          )
        else
          for (final w in shown.take(shownMax))
            BvProofCard(
              key: Key('delivered-${w.id}'),
              id: w.id,
              title: w.title,
              stamp: stamp,
              project: w.projectName,
              checkerName: w.checkedByName,
              checkedLine: w.checkedAt == null
                  ? null
                  // No name across a block: still Checked (review 11).
                  : w.checkedByName == null
                  ? l10n.deliveredCheckedOn(_day(context, w.checkedAt!))
                  : l10n.deliveredCheckedBy(
                      w.checkedByName!,
                      _day(context, w.checkedAt!),
                    ),
              photo: w.photoPath == null
                  ? null
                  : ref.watch(daybookPhotoProvider(w.photoPath!)),
              onTap: () => context.push(AppRoutes.personWork(profileId, w.id)),
            ),
      ],
    );
  }
}

/// RE2 · Work you delivered: every Checked item you owned, each hidden
/// until you switch it on. Tap a card to show or hide it.
class DeliveredScreen extends ConsumerWidget {
  const DeliveredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final work = ref.watch(myDeliveredWorkProvider);
    final items = work.value;

    Future<void> toggle(DeliveredWork w) async {
      try {
        await ref.read(workRepositoryProvider).setShown(w.id, !w.shown);
        ref.invalidate(myDeliveredWorkProvider);
        ref.invalidate(shownWorkProvider);
      } on SpaceException catch (e) {
        if (context.mounted) showSpaceError(context, e);
      }
    }

    return EntryScaffold(
      title: l10n.deliveredTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          Text(
            l10n.deliveredIntro,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
          if (items == null)
            const Center(child: CircularProgressIndicator())
          else if (items.isEmpty)
            EmptyNote(l10n.deliveredEmpty)
          else
            _Grid(
              children: [
                for (final w in items)
                  DeliveredCard(
                    work: w,
                    selected: w.shown,
                    onTap: () => toggle(w),
                    footer: w.shown
                        ? Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: BvSpace.s4,
                            ),
                            child: BvStamp(
                              key: Key('delivered-shown-${w.id}'),
                              label: l10n.deliveredShown,
                              tilted: true,
                            ),
                          )
                        : Text(
                            l10n.deliveredHidden,
                            key: Key('delivered-hidden-${w.id}'),
                            style: type.bodySm.copyWith(
                              color: BvColors.textSecondary,
                            ),
                          ),
                  ),
              ],
            ),
          Text(
            l10n.deliveredFooter,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// RE1 · Delivered work, as anyone signed in sees it: only the title, the
/// photo, the place, the project and who checked it (rule 10).
class DeliveredPublicScreen extends ConsumerWidget {
  const DeliveredPublicScreen({
    super.key,
    required this.profileId,
    required this.itemId,
  });

  final String profileId;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final person = ref.watch(profileViewProvider(profileId)).value;
    final name = person == null
        ? ''
        : '${person.firstName} ${person.lastName}'.trim();
    final work = ref
        .watch(shownWorkProvider(profileId))
        .value
        ?.where((w) => w.id == itemId)
        .firstOrNull;
    final url = work?.photoPath == null
        ? null
        : ref.watch(workPhotoUrlProvider(work!.photoPath!)).value;

    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSpace.s16,
        vertical: BvSpace.s12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: BvDeliveredSpec.labelWidth,
            child: Text(
              label,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: type.bodyMd.copyWith(color: color ?? BvColors.textPrimary),
            ),
          ),
        ],
      ),
    );

    return EntryScaffold(
      title: l10n.deliveredPublicTitle,
      body: work == null
          ? EmptyNote(l10n.workItemGone)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s16,
              children: [
                if (name.isNotEmpty)
                  Text(
                    l10n.deliveredShownBy(name),
                    textAlign: TextAlign.center,
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  ),
                BvSitePhoto(
                  key: const Key('delivered-photo'),
                  photo: url == null ? null : NetworkImage(url),
                  stamp: joinMeta([?work.place, if (name.isNotEmpty) name]),
                ),
                if (work.checkedAt != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: BvInkStamp(
                      key: const Key('delivered-stamp'),
                      // The Daybook's proof stamp: the word, then the day.
                      label: l10n.signOffChecked,
                      subline:
                          Localizations.localeOf(context).languageCode == 'ar'
                          ? _day(context, work.checkedAt!)
                          : _day(context, work.checkedAt!).toUpperCase(),
                      size: BvInkStampSize.lg,
                      tone: BvInkStampTone.positive,
                    ),
                  ),
                Text(work.title, style: type.titleLg),
                ProfileCard(
                  padding: false,
                  child: DividedColumn(
                    children: [
                      if (work.projectName != null)
                        row(
                          l10n.deliveredProject,
                          work.projectName!,
                          color: BvColors.textAction,
                        ),
                      if (work.place != null)
                        row(l10n.deliveredPlace, work.place!),
                      if (work.checkedByName != null || work.checkedAt != null)
                        row(
                          work.checkedByName == null
                              ? l10n.deliveredCheckedRowNoName
                              : l10n.deliveredCheckedRow,
                          joinMeta([
                            ?work.checkedByName,
                            if (work.checkedAt != null)
                              _day(context, work.checkedAt!),
                          ]),
                          color: BvColors.textPositive,
                        ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: BvColors.surfaceSubtle,
                    borderRadius: BvRadius.controlAll,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(BvSpace.s12),
                    child: Text(
                      l10n.deliveredPrivacy(person?.firstName ?? name),
                      style: type.bodySm.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
