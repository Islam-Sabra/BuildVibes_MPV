import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_bottom_bar.dart';
import '../profile/widgets/profile_parts.dart';
import '../chat/chat_tab.dart';
import '../work/work_tab.dart';
import 'people_tab.dart';
import 'space_info_screen.dart';

/// How a Space opens: on its People tab, and with the invite screen on top
/// right after it was created (review 06, S5).
enum SpaceOpen { people, invite }

/// A Space: header (S10k top) and the tabs Work · Chat · People · Library
/// at the bottom (S7k). The Library comes in week 6 part 2.
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

  /// Space info (S15). "Members" there comes back to the People tab.
  Future<void> _openInfo() async {
    final result = await context.push<SpaceInfoResult>(
      AppRoutes.spaceInfo(widget.spaceId),
    );
    if (mounted && result == SpaceInfoResult.showPeople) {
      setState(() => _tab = SpaceScreen.peopleTab);
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
        actions: [
          IconButton(
            key: const Key('space-more'),
            tooltip: l10n.spacesInfoTitle,
            icon: const Icon(BvIcons.more),
            onPressed: _openInfo,
          ),
        ],
        title: GestureDetector(
          onTap: _openInfo,
          behavior: HitTestBehavior.opaque,
          child: Row(
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
                      style: type.bodySm.copyWith(
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
      body: switch (_tab) {
        SpaceScreen.workTab => WorkTab(space: detail),
        SpaceScreen.chatTab => ChatTab(space: detail),
        SpaceScreen.peopleTab => PeopleTab(space: detail),
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
