import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/months.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_pass_card.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart';
import 'pass_words.dart';
import 'space_errors.dart';

/// How the member pass opens: with a banner, right after confirming.
class MemberPassOpen {
  const MemberPassOpen({this.message});
  final String? message;
}

/// S17k · Member pass. The pass stamp, what the pass opens (Open / Lock
/// for each right that can change), Change pass, Teams, Make admin and
/// Remove from Space. Admins change it; members see it read-only.
class MemberPassScreen extends ConsumerStatefulWidget {
  const MemberPassScreen({
    super.key,
    required this.spaceId,
    required this.profileId,
    this.open,
  });

  final String spaceId;
  final String profileId;
  final MemberPassOpen? open;

  @override
  ConsumerState<MemberPassScreen> createState() => _MemberPassScreenState();
}

class _MemberPassScreenState extends ConsumerState<MemberPassScreen> {
  late String? _message = widget.open?.message;
  var _busy = false;

  ({String spaceId, String profileId}) get _key =>
      (spaceId: widget.spaceId, profileId: widget.profileId);

  /// Runs a change, then reloads and shows [done] in the banner.
  Future<void> _change(
    Future<void> Function(SpaceRepository repo) run, {
    required String done,
    String? onRule,
  }) async {
    setState(() => _busy = true);
    try {
      await run(ref.read(spaceRepositoryProvider));
      ref
        ..invalidate(spacePeopleProvider(widget.spaceId))
        ..invalidate(memberRightsProvider(_key))
        ..invalidate(spaceDetailProvider(widget.spaceId));
      if (mounted) setState(() => _message = done);
    } on SpaceException catch (e) {
      if (!mounted) return;
      if (e.failure == SpaceFailure.rule && onRule != null) {
        showSpaceMessage(context, onRule);
      } else {
        showSpaceError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(SpaceMember member) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showBvSheet<bool>(
      context: context,
      title: l10n.spacesRemoveTitle(inOwnDirection(member.person.fullName)),
      footer: BvSheetFooter(
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.spacesRemove,
        onConfirm: () => Navigator.of(context, rootNavigator: true).pop(true),
      ),
      builder: (sheetContext) => Text(
        l10n.spacesRemoveBody,
        style: BvType.of(
          sheetContext,
        ).bodyMd.copyWith(color: BvColors.textSecondary),
      ),
    );
    if (yes != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(spaceRepositoryProvider)
          .removeMember(widget.spaceId, widget.profileId);
      ref.invalidate(spacePeopleProvider(widget.spaceId));
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.spacesRemoved(inOwnDirection(member.person.fullName)),
          ),
        ),
      );
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final me = ref.watch(authUserIdProvider).value;
    final space = ref.watch(spaceDetailProvider(widget.spaceId)).value;
    final people = ref.watch(spacePeopleProvider(widget.spaceId)).value;
    final rights = ref.watch(memberRightsProvider(_key)).value;
    final member = people?.member(widget.profileId);

    final appBar = AppBar(
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.spacesMemberTitle, style: type.titleLg),
          if (space != null)
            Text(
              space.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
        ],
      ),
    );

    if (space == null || people == null || rights == null || member == null) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final editable = space.iAmAdmin && !_busy;
    final name = member.person.firstName.isEmpty
        ? member.person.fullName
        : member.person.firstName;
    final teams = people.teamsOf(member.person.id);
    final isMe = member.person.id == me;

    void toggle(String right, String label, bool open) => _change(
      (repo) => repo.setMemberPass(
        widget.spaceId,
        widget.profileId,
        member.pass,
        custom: {...member.custom, right: open},
      ),
      done: open
          ? l10n.spacesRightOpened(label, inOwnDirection(name))
          : l10n.spacesRightLocked(label, inOwnDirection(name)),
    );

    // Admins have every right; their pass rights can't be changed.
    final canChangeRights = editable && !member.isAdmin;
    Widget right(String label, bool on, {String? key, String? fixed}) =>
        _RightRow(
          id: key ?? (fixed == null ? 'mark_done' : 'chat'),
          label: label,
          on: on,
          fixed: fixed,
          onToggle: key == null || !canChangeRights
              ? null
              : () => toggle(key, label, !on),
        );

    return Scaffold(
      appBar: appBar,
      // A short page: built all at once, so the banner and the stamp at the
      // top stay current while the admin works further down.
      body: SingleChildScrollView(
        key: const Key('member-pass'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          BvSpace.gutter,
          BvSpace.s8,
          BvSpace.gutter,
          BvSpace.s32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_message != null) ...[
              _Banner(_message!),
              const SizedBox(height: BvSpace.s12),
            ],
            _PassHeader(
              stamp: member.isCustom
                  ? l10n.spacesPassCustom(passStamp(l10n, member.pass))
                  : passStamp(l10n, member.pass),
              band: member.isCustom
                  ? BvColors.brandInk
                  : BvPassCard.bandColor(passKind(member.pass)),
              spaceName: space.name,
              name: member.person.fullName,
              role: joinMeta([
                ?member.person.roleLabel(lang),
                ?member.person.companyLabel,
              ]),
              confirmed: joinMeta([
                if (member.confirmedById == me)
                  l10n.spacesConfirmedByYou
                else if (member.confirmedByName != null)
                  l10n.spacesConfirmedBy(
                    inOwnDirection(member.confirmedByName!),
                  ),
                formatDay(member.confirmedAt.toLocal(), locale),
                for (final t in teams) t.name,
              ]),
            ),
            const SizedBox(height: BvSpace.s16),
            _Overline(l10n.spacesPassOpens),
            ProfileCard(
              padding: false,
              child: DividedColumn(
                children: [
                  right(l10n.spacesRightChat, true, fixed: l10n.spacesAlways),
                  right(l10n.spacesRightMarkDone, rights.markDone),
                  right(
                    l10n.spacesRightFiles,
                    rights.addFiles,
                    key: SpaceRight.addFiles,
                  ),
                  right(
                    l10n.spacesRightCreate,
                    rights.createItems,
                    key: SpaceRight.createItems,
                  ),
                  right(
                    l10n.spacesRightCheck,
                    rights.checkItems,
                    key: SpaceRight.checkItems,
                  ),
                  right(
                    l10n.spacesRightInvite,
                    rights.invite,
                    key: SpaceRight.invite,
                  ),
                ],
              ),
            ),
            if (member.isAdmin) ...[
              const SizedBox(height: BvSpace.s8),
              Text(
                l10n.spacesAdminRights,
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
            ],
            const SizedBox(height: BvSpace.s16),
            _Overline(l10n.spacesChangePass),
            Wrap(
              spacing: BvSpace.s8,
              runSpacing: BvSpace.s8,
              children: [
                for (final p in SpacePass.values)
                  BvChip(
                    key: Key('pass-chip-${p.name}'),
                    label: passName(l10n, p),
                    selected: p == member.pass,
                    // A new pass starts from its preset (no custom rights).
                    onTap: !editable || p == member.pass
                        ? null
                        : () => _change(
                            (repo) => repo.setMemberPass(
                              widget.spaceId,
                              widget.profileId,
                              p,
                            ),
                            done: l10n.spacesPassChanged(
                              name,
                              passName(l10n, p),
                            ),
                          ),
                  ),
              ],
            ),
            if (people.teams.isNotEmpty) ...[
              const SizedBox(height: BvSpace.s16),
              _Overline(l10n.spacesTeamsLabel),
              Wrap(
                spacing: BvSpace.s8,
                runSpacing: BvSpace.s8,
                children: [
                  for (final t in people.teams)
                    BvChip(
                      key: Key('team-chip-${t.id}'),
                      label: t.name,
                      selected: t.memberIds.contains(member.person.id),
                      onTap: !editable
                          ? null
                          : () {
                              final ids = {for (final x in teams) x.id};
                              if (!ids.remove(t.id)) ids.add(t.id);
                              _change(
                                (repo) => repo.setMemberTeams(
                                  widget.spaceId,
                                  widget.profileId,
                                  ids.toList(),
                                ),
                                done: l10n.spacesTeamsSaved,
                              );
                            },
                    ),
                ],
              ),
            ],
            if (space.iAmAdmin) ...[
              const SizedBox(height: BvSpace.s16),
              ProfileCard(
                padding: false,
                child: BvListRow(
                  key: const Key('member-make-admin'),
                  title: l10n.spacesMakeAdmin,
                  subtitle: l10n.spacesMakeAdminHelp,
                  trailing: BvRowTrailing.toggle(
                    value: member.isAdmin,
                    onChanged: !editable
                        ? null
                        : (v) => _change(
                            (repo) => repo.setMemberAdmin(
                              widget.spaceId,
                              widget.profileId,
                              v,
                            ),
                            done: v
                                ? l10n.spacesAdminOn(inOwnDirection(name))
                                : l10n.spacesAdminOff(inOwnDirection(name)),
                            onRule: l10n.spacesNeedsAdmin,
                          ),
                  ),
                ),
              ),
              if (!isMe) ...[
                const SizedBox(height: BvSpace.s16),
                BvButton(
                  key: const Key('member-remove'),
                  label: l10n.spacesRemove,
                  style: BvButtonStyle.destructive,
                  expand: true,
                  onPressed: editable ? () => _remove(member) : null,
                ),
                const SizedBox(height: BvSpace.s8),
                Text(
                  l10n.spacesRemoveBody,
                  textAlign: TextAlign.center,
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s8),
    child: Text(
      text,
      style: BvType.of(
        context,
      ).overline.copyWith(color: BvColors.textSecondary),
    ),
  );
}

/// What just changed, in green on the subtle band (S17k).
class _Banner extends StatelessWidget {
  const _Banner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('member-banner'),
    decoration: const BoxDecoration(
      color: BvColors.surfaceSubtle,
      borderRadius: BvRadius.controlAll,
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSpace.s12,
        vertical: BvSpace.s8,
      ),
      child: Text(
        text,
        style: BvType.of(context).bodySm.copyWith(color: BvColors.textPositive),
      ),
    ),
  );
}

/// The pass card at the top: a coloured band with the pass stamp and the
/// Space, then the member.
class _PassHeader extends StatelessWidget {
  const _PassHeader({
    required this.stamp,
    required this.band,
    required this.spaceName,
    required this.name,
    required this.role,
    required this.confirmed,
  });

  final String stamp;
  final Color band;
  final String spaceName;
  final String name;
  final String role;
  final String confirmed;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return ProfileCard(
      padding: false,
      child: Column(
        key: const Key('member-pass-header'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: band,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.s16,
                vertical: BvSpace.s12,
              ),
              child: Row(
                spacing: BvSpace.s8,
                children: [
                  Flexible(
                    child: Text(
                      stamp,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.overline.copyWith(
                        color: BvColors.textInverse,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      spaceName.toUpperCase(),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.overline.copyWith(
                        color: BvColors.textInverse,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(BvSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvSpace.s4,
              children: [
                Text(name, style: type.titleLg),
                if (role.isNotEmpty)
                  Text(
                    role,
                    style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                  ),
                if (confirmed.isNotEmpty)
                  Text(
                    confirmed,
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One right: a check when it's open, a lock when it isn't, and Open /
/// Lock for the admin ([onToggle]), or a [fixed] word ("Always").
class _RightRow extends StatelessWidget {
  const _RightRow({
    required this.id,
    required this.label,
    required this.on,
    this.fixed,
    this.onToggle,
  });

  /// The right's key (create_items, …), for tests.
  final String id;
  final String label;
  final bool on;
  final String? fixed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return ConstrainedBox(
      key: Key('right-$id-${on ? 'on' : 'off'}'),
      constraints: const BoxConstraints(minHeight: BvListRowSpec.minHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvListRowSpec.paddingHorizontal,
        ),
        child: Row(
          spacing: BvListRowSpec.gap,
          children: [
            Icon(
              on ? BvIcons.check : BvIcons.lock,
              size: BvSize.iconMd,
              color: on ? BvColors.textPositive : BvColors.iconSecondary,
            ),
            Expanded(
              child: Text(
                label,
                style: type.bodyMd.copyWith(
                  color: on ? BvColors.textPrimary : BvColors.textSecondary,
                ),
              ),
            ),
            if (fixed != null)
              Text(
                fixed!,
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              )
            else if (onToggle != null)
              BvButton(
                key: Key('right-toggle-$id'),
                label: on ? l10n.spacesLockRight : l10n.spacesOpenRight,
                style: BvButtonStyle.tertiary,
                size: BvButtonSize.medium,
                padded: false,
                onPressed: onToggle,
              ),
          ],
        ),
      ),
    );
  }
}
