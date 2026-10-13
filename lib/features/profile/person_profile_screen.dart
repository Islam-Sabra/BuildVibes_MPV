import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/repositories/profile_page_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/safety_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../activity/activity_state.dart';
import '../entry/entry_state.dart';
import '../feed/feed_state.dart';
import '../safety/report_flow.dart';
import 'widgets/profile_body.dart';
import 'widgets/profile_parts.dart';

/// R5 · Someone else's profile, as a visitor sees it: Follow, and only what
/// they chose to show. "Message" is not in the MVP.
class PersonProfileScreen extends ConsumerStatefulWidget {
  const PersonProfileScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<PersonProfileScreen> createState() =>
      _PersonProfileScreenState();
}

class _PersonProfileScreenState extends ConsumerState<PersonProfileScreen> {
  bool? _following;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    final me = ref.read(authUserIdProvider).value;
    if (me == null) return;
    final following = await ref
        .read(profilePageRepositoryProvider)
        .isFollowing(me, widget.profileId);
    if (mounted) setState(() => _following = following);
  }

  Future<void> _toggleFollow() async {
    final me = ref.read(authUserIdProvider).value;
    if (me == null || _following == null) return;
    final follow = !_following!;
    setState(() {
      _busy = true;
      _following = follow;
    });
    final repo = ref.read(profileRepositoryProvider);
    try {
      follow
          ? await repo.follow(me, widget.profileId)
          : await repo.unfollow(me, widget.profileId);
      ref.invalidate(profileViewProvider(widget.profileId));
    } on Exception {
      if (mounted) setState(() => _following = !follow);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The ••• menu: Report account (R1) and Block (the block dialog).
  Future<void> _more(String name) async {
    final l10n = AppLocalizations.of(context);
    // Undo may run after this screen closed.
    final container = ProviderScope.containerOf(context, listen: false);
    final choice = await showBvSheet<_More>(
      context: context,
      builder: (sheetContext) => ClipRRect(
        borderRadius: BvRadius.cardAll,
        child: BvListGroup(
          rows: [
            BvListRow(
              key: const Key('profile-report'),
              leading: const BvRowIcon(BvIcons.report),
              title: l10n.profileReport,
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheetContext).pop(_More.report),
            ),
            BvListRow(
              key: const Key('profile-block'),
              leading: const BvRowIcon(BvIcons.block, destructive: true),
              title: l10n.blockPerson(inOwnDirection(name)),
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheetContext).pop(_More.block),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    // Blocked: the profile closes, and the feed and Activity read again.
    void changed(bool blocked) {
      container
        ..invalidate(feedProvider)
        ..invalidate(activityProvider)
        ..invalidate(profileViewProvider(widget.profileId));
      if (blocked && mounted) context.pop();
    }

    switch (choice) {
      case _More.report:
        await startReport(
          context,
          kind: ReportKind.profile,
          id: widget.profileId,
          person: (id: widget.profileId, name: name),
          onBlocked: () => changed(true),
        );
      case _More.block:
        await confirmBlock(
          context,
          personId: widget.profileId,
          name: name,
          onChanged: changed,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileViewProvider(widget.profileId));

    return Scaffold(
      appBar: AppBar(backgroundColor: BvColors.surfaceSubtle),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: BvButton(
            label: l10n.commonRetry,
            style: BvButtonStyle.secondary,
            onPressed: () =>
                ref.invalidate(profileViewProvider(widget.profileId)),
          ),
        ),
        data: (p) => p == null
            ? Center(child: EmptyNote(l10n.profileNotFound))
            : ListView(
                key: const Key('person-profile'),
                children: [
                  ProfileHeader(
                    profile: p,
                    showFollowing: false,
                    actions: Row(
                      spacing: BvSpace.s8,
                      children: [
                        Expanded(
                          child: BvButton(
                            key: const Key('profile-follow'),
                            label: _following == true
                                ? l10n.following
                                : l10n.follow,
                            style: _following == true
                                ? BvButtonStyle.secondary
                                : BvButtonStyle.primary,
                            size: BvButtonSize.medium,
                            expand: true,
                            onPressed: _following == null || _busy
                                ? null
                                : _toggleFollow,
                          ),
                        ),
                        _MoreButton(
                          onTap: () =>
                              _more('${p.firstName} ${p.lastName}'.trim()),
                        ),
                      ],
                    ),
                  ),
                  ProfileBody(profile: p, own: false),
                ],
              ),
      ),
    );
  }
}

/// The "…" button next to Follow (report and block live here).
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).profileMore,
      child: Material(
        color: BvColors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BvRadius.controlAll,
          side: BorderSide(color: BvColors.borderInput, width: BvStroke.thin),
        ),
        child: InkWell(
          key: const Key('profile-more'),
          onTap: onTap,
          borderRadius: BvRadius.controlAll,
          splashFactory: NoSplash.splashFactory,
          child: const SizedBox.square(
            dimension: BvProfileSpec.iconButton,
            child: Icon(
              BvIcons.more,
              size: BvSize.iconMd,
              color: BvColors.iconPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

enum _More { report, block }
