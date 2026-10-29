import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_space_header.dart';
import '../../shared/widgets/bv_segmented.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../activity/activity_state.dart';
import '../profile/widgets/profile_parts.dart';
import '../chat/chat_tab.dart';
import '../work/daybook_tab.dart';
import '../work/work_gestures.dart' show workSelectionProvider;
import '../work/daybook_target.dart';
import '../work/walk_saved.dart';
import '../work/work_outbox.dart';
import 'space_sections.dart';
import 'spaces_state.dart';

/// How a Space opens: on its People tab, with the invite screen on top
/// right after it was created (review 06, S5), or on its daybook with the
/// work item card open, from Create (review 50 F1).
enum SpaceOpen { people, invite, write }

/// A Space (review 105 Part 1, SP1 2666:38461): the Space header with
/// Search, Library and People, a Work · Chat switch under it, and the work
/// down to the post bar at the bottom: no tab bar. People and Library
/// open as screens of their own.
class SpaceScreen extends ConsumerStatefulWidget {
  const SpaceScreen({
    super.key,
    required this.spaceId,
    this.open,
    this.target,
    this.onChat = false,
  });

  final String spaceId;
  final SpaceOpen? open;

  /// Opened at a work item's card (F20): the Work tab, at that card.
  final DaybookTarget? target;

  /// Opened on the Chat tab, under one of its threads (F105).
  final bool onChat;

  static const workTab = 0;
  static const chatTab = 1;

  @override
  ConsumerState<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends ConsumerState<SpaceScreen> {
  late var _tab = widget.onChat && widget.target == null
      ? SpaceScreen.chatTab
      : SpaceScreen.workTab;

  /// The Library asked for a file post (review 69 1b); a tab tap clears
  /// it, so it opens once.
  DaybookFileStart? _fileStart;

  /// The Space menu's Daily report (slice 7), opened once.
  DaybookReportStart? _reportStart;

  void _addFile({LibraryFile? replaces}) => setState(() {
    _fileStart = DaybookFileStart(replaces: replaces);
    _tab = SpaceScreen.workTab;
  });

  /// Review 94: a Check, a Cancel or a Remove whose undo bar still shows
  /// goes at once when the Space or the app is left; it was confirmed by
  /// the hold.
  late final _outbox = ref.read(workOutboxProvider.notifier);
  late final _life = AppLifecycleListener(onHide: _outbox.releaseHeld);
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _life.dispose();
    // Its Undo would no longer take anything back.
    if (_outbox.releaseHeld(spaceId: widget.spaceId)) {
      _messenger?.hideCurrentSnackBar();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _life;
    _markSeen();
    // Create lists this Space first next time (F1); after the first
    // frame, as a provider can't change while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(lastSpaceProvider.notifier).opened(widget.spaceId));
      }
    });
    if (widget.open == SpaceOpen.invite || widget.open == SpaceOpen.people) {
      // Its People, with the invite screen on top when just made (S5).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(context.push(AppRoutes.spacePeople(widget.spaceId)));
        if (widget.open == SpaceOpen.invite) {
          unawaited(context.push(AppRoutes.spaceInvite(widget.spaceId)));
        }
      });
    } else if (!widget.onChat) {
      // Not over a thread opened on top of the Space.
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

  /// Search (review 95: in the header). A Library file found there can come
  /// back to be replaced by a file post.
  Future<void> _openSearch() async {
    final replaces = await context.push<LibraryFile>(
      AppRoutes.spaceSearch(widget.spaceId),
    );
    if (replaces != null && mounted) _addFile(replaces: replaces);
  }

  /// Space info (SI1), which holds what ⋯ held (review 105 Part 1): the
  /// daily report it hands back opens on Work.
  Future<void> _openInfo() async {
    final asked = await context.push<SpaceInfoAction>(
      AppRoutes.spaceInfo(widget.spaceId),
    );
    if (!mounted) return;
    switch (asked) {
      case SpaceInfoAction.dailyReport:
        setState(() {
          _reportStart = DaybookReportStart();
          _tab = SpaceScreen.workTab;
        });
      case null:
        break;
    }
  }

  /// The Library: a file it asks for comes back as a file post on Work.
  Future<void> _openLibrary() async {
    final ask = await context.push<SpaceFileAsk>(
      AppRoutes.spaceLibrary(widget.spaceId),
    );
    if (ask != null && mounted) _addFile(replaces: ask.replaces);
  }

  void _show(int tab) => setState(() {
    ref.read(workSelectionProvider(widget.spaceId).notifier).clear();
    _tab = tab;
    _fileStart = null;
    _reportStart = null;
  });

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

    final unread = spaceUnread(
      ref.watch(spaceThreadsProvider(widget.spaceId)).value ?? const [],
    );
    final waiting =
        detail.iAmAdmin &&
        joinWaiting(ref.watch(spacePeopleProvider(widget.spaceId)).value);
    final selected = _tab == SpaceScreen.workTab
        ? ref.watch(workSelectionProvider(widget.spaceId))
        : const <String>{};
    return Scaffold(
      appBar: BvSpaceHeader(
        selected: selected.isEmpty ? null : l10n.workSelected(selected.length),
        closeSelectionLabel: l10n.workCloseSelection,
        onCloseSelection: () =>
            ref.read(workSelectionProvider(widget.spaceId).notifier).clear(),
        name: detail.name,
        // As in the v13 frames, linked to a project or not (review 54 A4).
        line: l10n.spacesPrivateWork,
        backLabel: MaterialLocalizations.of(context).backButtonTooltip,
        onOpen: () => unawaited(_openInfo()),
        searchLabel: l10n.searchMenu,
        onSearch: () => unawaited(_openSearch()),
        libraryLabel: l10n.spacesTabLibrary,
        onLibrary: () => unawaited(_openLibrary()),
        peopleLabel: l10n.spacesTabPeople,
        onPeople: () =>
            unawaited(context.push(AppRoutes.spacePeople(widget.spaceId))),
        peopleWaiting: waiting,
        waitingLabel: l10n.spacesPeopleWaiting,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: BvSpaceHeaderSpec.switchPadding,
            child: BvSegmented<int>(
              key: const Key('space-switch'),
              value: _tab,
              onChanged: _show,
              segments: [
                BvSegment(
                  key: const Key('space-switch-work'),
                  value: SpaceScreen.workTab,
                  label: l10n.spacesTabWork,
                ),
                BvSegment(
                  key: const Key('space-switch-chat'),
                  value: SpaceScreen.chatTab,
                  label: l10n.spacesTabChat,
                  badge: unread,
                  badgeKey: const Key('space-chat-unread'),
                ),
              ],
            ),
          ),
          Expanded(child: _body(detail)),
        ],
      ),
    );
  }

  Widget _body(SpaceDetail detail) => switch (_tab) {
    SpaceScreen.workTab => DaybookTab(
      space: detail,
      startWriting: widget.open == SpaceOpen.write,
      target: widget.target,
      startFile: _fileStart,
      startReport: _reportStart,
    ),
    _ => ChatTab(space: detail),
  };
}
