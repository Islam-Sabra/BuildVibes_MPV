import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/library.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_space_header.dart';
import '../../shared/widgets/bv_bottom_bar.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../activity/activity_state.dart';
import '../profile/widgets/profile_parts.dart';
import '../chat/chat_tab.dart';
import '../library/library_tab.dart';
import '../work/daybook_tab.dart';
import '../work/daybook_target.dart';
import '../work/walk_saved.dart';
import 'people_tab.dart';
import 'spaces_state.dart';

/// What the Space menu offers now (MN1).
enum _SpaceMenu { walk, search, info }

/// How a Space opens: on its People tab, with the invite screen on top
/// right after it was created (review 06, S5), or on its daybook with the
/// work item card open, from Create (review 50 F1).
enum SpaceOpen { people, invite, write }

/// A Space: the Space header (MN1) and the tabs Work · Chat · People ·
/// Library at the bottom.
class SpaceScreen extends ConsumerStatefulWidget {
  const SpaceScreen({super.key, required this.spaceId, this.open, this.target});

  final String spaceId;
  final SpaceOpen? open;

  /// Opened at a work item's card (F20): the Work tab, at that card.
  final DaybookTarget? target;

  static const workTab = 0;
  static const chatTab = 1;
  static const peopleTab = 2;
  static const libraryTab = 3;

  @override
  ConsumerState<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends ConsumerState<SpaceScreen> {
  late var _tab = widget.target != null
      ? SpaceScreen.workTab
      : switch (widget.open) {
          SpaceOpen.people || SpaceOpen.invite => SpaceScreen.peopleTab,
          SpaceOpen.write || null => SpaceScreen.workTab,
        };

  /// The Library asked for a file post (review 69 1b); a tab tap clears
  /// it, so it opens once.
  DaybookFileStart? _fileStart;

  void _addFile({LibraryFile? replaces}) => setState(() {
    _fileStart = DaybookFileStart(replaces: replaces);
    _tab = SpaceScreen.workTab;
  });

  @override
  void initState() {
    super.initState();
    _markSeen();
    // Create lists this Space first next time (F1); after the first
    // frame, as a provider can't change while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(lastSpaceProvider.notifier).opened(widget.spaceId));
      }
    });
    if (widget.open == SpaceOpen.invite) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push(AppRoutes.spaceInvite(widget.spaceId));
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_askWalk());
      });
    }
  }

  /// A walk kept on the phone, left when the app was closed (review 79
  /// P1): Continue opens it where it stopped; Throw away asks first.
  Future<void> _askWalk() async {
    final walk = ref.read(walkSavedProvider(widget.spaceId));
    if (walk == null) return;
    final l10n = AppLocalizations.of(context);
    final carryOn = await showBvChoiceDialog(
      context: context,
      title: l10n.walkInProgress,
      body: joinMeta([
        walk.name.trim(),
        if (walk.shots.isNotEmpty) l10n.walkPhotos(walk.shots.length),
      ]),
      cancelLabel: l10n.walkThrowAway,
      confirmLabel: l10n.walkContinue,
    );
    if (!mounted || carryOn == null) return;
    // "Keep walking" in the question goes on with it too.
    final away =
        !carryOn &&
        await showBvDialog(
          context: context,
          title: l10n.walkDiscardTitle,
          body: l10n.walkDiscardBody,
          cancelLabel: l10n.walkKeep,
          confirmLabel: l10n.walkDiscard,
          destructive: true,
        );
    if (!mounted) return;
    if (away) {
      await ref
          .read(walkSavedProvider(widget.spaceId).notifier)
          .clear(photos: true);
    } else {
      await context.push(AppRoutes.spaceWalk(widget.spaceId));
    }
  }

  /// Opening a Space marks it seen: Home's "Today in your Spaces" counts
  /// from here. A failure only leaves it marked as new.
  Future<void> _markSeen() async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await ref.read(activityRepositoryProvider).markSpaceSeen(widget.spaceId);
    } on Exception {
      return;
    }
    refreshDay(container.invalidate);
  }

  /// The Space menu (MN1 2566:35619): only what works now, Search and
  /// Space info. Daily report (slice 7) and Week report (slice 9) join it
  /// when they are built; nothing says "coming soon" (review 43).
  Future<void> _openMenu() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showBvScreenMenu<_SpaceMenu>(
      context,
      key: const Key('space-menu'),
      items: [
        // Walk mode: for people who may post work (slice 6).
        if (ref
                .read(spaceDetailProvider(widget.spaceId))
                .value
                ?.myRights
                .createItems ??
            false)
          BvMenuItem(
            value: _SpaceMenu.walk,
            label: l10n.walkMenu,
            icon: BvIcons.camera,
          ),
        BvMenuItem(
          value: _SpaceMenu.search,
          label: l10n.searchMenu,
          icon: BvIcons.search,
        ),
        BvMenuItem(
          value: _SpaceMenu.info,
          label: l10n.spacesInfoTitle,
          icon: BvIcons.info,
        ),
      ],
    );
    if (!mounted) return;
    switch (picked) {
      case _SpaceMenu.walk:
        await context.push(AppRoutes.spaceWalk(widget.spaceId));
      case _SpaceMenu.search:
        final replaces = await context.push<LibraryFile>(
          AppRoutes.spaceSearch(widget.spaceId),
        );
        if (replaces != null && mounted) _addFile(replaces: replaces);
      case _SpaceMenu.info:
        await _openInfo();
      case null:
        break;
    }
  }

  /// Space info (SI1).
  Future<void> _openInfo() => context.push(AppRoutes.spaceInfo(widget.spaceId));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      appBar: BvSpaceHeader(
        name: detail.name,
        // As in the v13 frames, linked to a project or not (review 54 A4).
        line: l10n.spacesPrivateWork,
        backLabel: MaterialLocalizations.of(context).backButtonTooltip,
        moreLabel: l10n.spacesMenu,
        onOpen: _openInfo,
        onMore: _openMenu,
      ),
      body: switch (_tab) {
        SpaceScreen.workTab => DaybookTab(
          space: detail,
          startWriting: widget.open == SpaceOpen.write,
          target: widget.target,
          startFile: _fileStart,
        ),
        SpaceScreen.chatTab => ChatTab(space: detail),
        SpaceScreen.libraryTab => LibraryTab(
          space: detail,
          onAddFile: _addFile,
        ),
        SpaceScreen.peopleTab => PeopleTab(space: detail),
        _ => Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: EmptyNote(l10n.placeholderBody),
        ),
      },
      bottomNavigationBar: BvBottomBar(
        selectedIndex: _tab,
        onSelect: (i) => setState(() {
          _tab = i;
          _fileStart = null;
        }),
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
            icon: BvIcons.team,
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
