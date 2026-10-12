import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_specs.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../core/l10n/bidi.dart';
import '../../../core/l10n/months.dart';
import '../../../data/models/profile.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_avatar.dart';
import '../../../shared/widgets/bv_badge.dart';
import '../../../shared/widgets/bv_chip.dart';

/// The top of a profile (R1, R5): photo or initials, name, role line,
/// trade and place, and follower counts (the only counts allowed).
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    required this.showFollowing,
    required this.actions,
  });

  final ProfileView profile;

  /// Own profile shows "· N following"; a visitor sees followers only.
  final bool showFollowing;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final roleLine = joinMeta(
      [profile.roleLabel(lang), profile.companyLabel].whereType<String>(),
    );
    final trade = profile.tradeName?.of(Localizations.localeOf(context));
    final place = profile.placeName?.of(Localizations.localeOf(context));
    final metaLine = joinMeta([
      if (trade != null && trade != profile.roleLabel(lang)) trade,
      ?place,
    ]);
    final counts = [
      l10n.profileFollowers(profile.followerCount),
      if (showFollowing) l10n.profileFollowing(profile.followingCount),
    ].join(' · ');

    return Container(
      color: BvColors.surfaceSubtle,
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s8,
        BvSpace.gutter,
        BvSpace.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          Row(
            spacing: BvProfileSpec.avatarGap,
            children: [
              BvAvatar(
                key: const Key('profile-avatar'),
                name: profile.fullName,
                size: BvAvatarSize.xl,
                image: profile.photoUrl == null
                    ? null
                    : NetworkImage(profile.photoUrl!),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s2,
                  children: [
                    Text(
                      profile.fullName,
                      key: const Key('profile-name'),
                      style: type.headingLg,
                    ),
                    if (roleLine.isNotEmpty)
                      Text(
                        roleLine,
                        key: const Key('profile-role-line'),
                        style: type.bodyMd,
                      ),
                    if (metaLine.isNotEmpty)
                      Text(
                        metaLine,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            counts,
            key: const Key('profile-counts'),
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
          actions,
        ],
      ),
    );
  }
}

/// A section title with an optional action at the end.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: BvType.of(context).headingMd)),
        ?action,
      ],
    );
  }
}

/// A white card with the standard padding and border.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.child, this.padding = true});

  final Widget child;
  final bool padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding
          ? const EdgeInsetsDirectional.all(BvProfileSpec.cardPadding)
          : null,
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: child,
    );
  }
}

/// One project on a CV: icon tile, name, role and dates, and the proof
/// badge (Confirmed / Waiting) when [showProof]. Opens the project sheet.
/// "Omar Haddad", "Omar Haddad and Sara Ali", or the first two "and
/// others": names, never a count (rule 3).
String confirmerNames(AppLocalizations l10n, List<String> names) {
  if (names.length == 1) return names.first;
  final two = l10n.listAnd(names[0], names[1]);
  return names.length == 2
      ? two
      : l10n.listAndOthers(
          '${names[0]}${l10n.localeName == 'ar' ? '، ' : ', '}${names[1]}',
        );
}

class CvProjectRow extends StatelessWidget {
  const CvProjectRow({super.key, required this.entry, this.showProof = false});

  final CvProjectEntry entry;
  final bool showProof;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dates = formatMonthRange(
      l10n,
      locale,
      start: entry.start,
      end: entry.end,
    );
    return InkWell(
      key: Key('cv-project-${entry.projectId}'),
      onTap: () => context.push('/projects/${entry.projectId}'),
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s12),
        child: Row(
          spacing: BvSpace.s12,
          children: [
            Container(
              width: BvSize.avatarMd,
              height: BvSize.avatarMd,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: BvColors.brandEnergySoft,
                borderRadius: BvRadius.controlAll,
              ),
              child: const Icon(
                BvIcons.crane,
                size: BvSize.iconMd,
                color: BvColors.iconAction,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvSpace.s2,
                children: [
                  Text(entry.projectName, style: type.titleMd),
                  Text(
                    joinMeta([entry.role, dates]),
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  ),
                  if (showProof && entry.confirmedBy.isNotEmpty)
                    Text(
                      l10n.proofConfirmedBy(
                        confirmerNames(l10n, entry.confirmedBy),
                      ),
                      key: Key('proof-by-${entry.projectId}'),
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (showProof)
              BvBadge(
                key: Key('proof-${entry.projectId}'),
                label: entry.confirmed
                    ? l10n.proofConfirmed
                    : l10n.proofWaiting,
                tone: entry.confirmed
                    ? BvBadgeTone.positive
                    : BvBadgeTone.neutral,
              ),
          ],
        ),
      ),
    );
  }
}

/// A list of rows with dividers between them.
class DividedColumn extends StatelessWidget {
  const DividedColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(
              height: BvStroke.thin,
              thickness: BvStroke.thin,
              color: BvColors.borderDefault,
            ),
          children[i],
        ],
      ],
    );
  }
}

class ExperienceRow extends StatelessWidget {
  const ExperienceRow({super.key, required this.entry, this.onTap});

  final ExperienceEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hiddenIcon = switch (entry.visibility) {
      ShowTo.everyone => null,
      ShowTo.connections => BvIcons.people,
      ShowTo.onlyMe => BvIcons.lock,
    };
    return InkWell(
      key: Key('experience-${entry.id}'),
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s12),
        child: Row(
          spacing: BvSpace.s12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvSpace.s2,
                children: [
                  Text(entry.title, style: type.titleMd),
                  if (entry.companyLabel != null)
                    Text(entry.companyLabel!, style: type.bodySm),
                  Text(
                    formatMonthRange(
                      l10n,
                      locale,
                      start: entry.start,
                      end: entry.end,
                    ),
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (hiddenIcon != null)
              Icon(
                hiddenIcon,
                size: BvSize.iconSm,
                color: BvColors.iconSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

/// The label of an "Open to" option id.
String openToLabel(AppLocalizations l10n, String id) => switch (id) {
  'contract' => l10n.openToContract,
  'consulting' => l10n.openToConsulting,
  'full_time' => l10n.openToFullTime,
  'part_time' => l10n.openToPartTime,
  'mentoring' => l10n.openToMentoring,
  _ => id,
};

/// "Open to" chips, the note, and (own profile) who sees it.
class OpenToSection extends StatelessWidget {
  const OpenToSection({super.key, required this.openTo, required this.own});

  final OpenTo openTo;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final note = switch (openTo.visibility) {
      ShowTo.everyone => null,
      ShowTo.connections => l10n.openToConnectionsOnly,
      ShowTo.onlyMe => l10n.openToOnlyYou,
    };
    return Column(
      key: const Key('open-to'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvSpace.s12,
      children: [
        SectionTitle(l10n.openToTitle),
        Wrap(
          spacing: BvSpace.s8,
          runSpacing: BvSpace.s8,
          children: [
            for (final o in openTo.options) BvChip(label: openToLabel(l10n, o)),
          ],
        ),
        if ((openTo.note ?? '').isNotEmpty)
          UserText(openTo.note!, style: type.bodyMd),
        if (own && note != null)
          Text(
            note,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
      ],
    );
  }
}

/// A calm empty line inside a section.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: BvType.of(context).bodyMd.copyWith(color: BvColors.textSecondary),
    );
  }
}

/// Text the person wrote (About, an Open to note): shown in its own
/// direction, so an English paragraph in the Arabic app keeps its full
/// stop at the end, but aligned with the page.
class UserText extends StatelessWidget {
  const UserText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final rtlPage = Directionality.of(context) == TextDirection.rtl;
    return Text(
      text,
      style: style,
      textDirection: Bidi.startsWithRtl(text)
          ? TextDirection.rtl
          : Bidi.startsWithLtr(text)
          ? TextDirection.ltr
          : null,
      textAlign: rtlPage ? TextAlign.right : TextAlign.left,
    );
  }
}
