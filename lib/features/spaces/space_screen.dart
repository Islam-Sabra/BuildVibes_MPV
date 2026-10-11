import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_bottom_bar.dart';
import '../../shared/widgets/bv_button.dart';
import '../profile/widgets/profile_parts.dart';

/// How a Space opens: on its People tab, and with the invite screen on top
/// right after it was created (review 06, S5).
enum SpaceOpen { people, invite }

/// A Space: header (S10k top) and the tabs Work · Chat · People · Library
/// at the bottom (S7k). Work, Chat and Library come in weeks 5–6.
class SpaceScreen extends ConsumerStatefulWidget {
  const SpaceScreen({super.key, required this.spaceId, this.open});

  final String spaceId;
  final SpaceOpen? open;

  static const workTab = 0;
  static const chatTab = 1;
  static const peopleTab = 2;
  static const libraryTab = 3;

  @override
  ConsumerState<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends ConsumerState<SpaceScreen> {
  late var _tab = widget.open == null
      ? SpaceScreen.workTab
      : SpaceScreen.peopleTab;

  @override
  void initState() {
    super.initState();
    if (widget.open == SpaceOpen.invite) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push(AppRoutes.spaceInvite(widget.spaceId));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final space = ref.watch(spaceDetailProvider(widget.spaceId));
    final detail = space.value;

    if (space.isLoading && !space.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: EmptyNote(
            space.hasError ? l10n.errorGeneric : l10n.spacesNotFound,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          key: const Key('space-header'),
          spacing: BvSpace.s12,
          children: [
            BvProjectAvatar(
              id: detail.id,
              icon: BvIcons.crane,
              size: BvAvatarSize.sm,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    detail.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.titleMd,
                  ),
                  Text(
                    detail.projectId == null
                        ? l10n.spacesPrivateWork
                        : l10n.spacesProjectSpaceLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: switch (_tab) {
        SpaceScreen.peopleTab => _PeopleTab(space: detail),
        _ => Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: EmptyNote(l10n.placeholderBody),
        ),
      },
      bottomNavigationBar: BvBottomBar(
        selectedIndex: _tab,
        onSelect: (i) => setState(() => _tab = i),
        items: [
          BvBottomBarItem(
            key: const Key('space-tab-work'),
            icon: BvIcons.workItems,
            label: l10n.spacesTabWork,
          ),
          BvBottomBarItem(
            key: const Key('space-tab-chat'),
            icon: BvIcons.chat,
            label: l10n.spacesTabChat,
          ),
          BvBottomBarItem(
            key: const Key('space-tab-people'),
            icon: BvIcons.people,
            label: l10n.spacesTabPeople,
          ),
          BvBottomBarItem(
            key: const Key('space-tab-library'),
            icon: BvIcons.library,
            label: l10n.spacesTabLibrary,
          ),
        ],
      ),
    );
  }
}

/// People (S10k) arrives in part 2; for now, Invite people.
class _PeopleTab extends StatelessWidget {
  const _PeopleTab({required this.space});

  final SpaceDetail space;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
      children: [
        if (space.canInvite) ...[
          BvButton(
            key: const Key('space-invite'),
            label: l10n.spacesInvitePeople,
            icon: BvIcons.people,
            style: BvButtonStyle.secondary,
            expand: true,
            onPressed: () => context.push(AppRoutes.spaceInvite(space.id)),
          ),
          const SizedBox(height: BvSpace.s16),
        ],
        EmptyNote(l10n.placeholderBody),
      ],
    );
  }
}
