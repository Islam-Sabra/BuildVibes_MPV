import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../library/library_add.dart';
import '../../core/design/around_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/key_people.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/key_people_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_space_header.dart';
import '../../shared/widgets/bv_segmented.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_tab_swipe.dart';
import '../activity/activity_state.dart';
import '../profile/widgets/profile_parts.dart';
import '../chat/chat_tab.dart';
import '../home/home_screen.dart' show HomeScreen, homeTabProvider;
import '../work/work_places.dart' show workPlaceFilterProvider;
import '../work/daybook_composer.dart' show spaceComposingProvider;
import '../work/daybook_tab.dart';
import '../work/work_gestures.dart' show workSelectionProvider;
import '../work/daybook_target.dart';
import '../work/walk_saved.dart';
import '../work/work_outbox.dart';
import 'key_people.dart';
import 'need_you_sheet.dart' show NeedYouStrip;
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
  /// Review 113 (5): a thread or a card it was opened at says which tab;
  /// otherwise the tab this Space was last left on, Work the first time.
  late var _tab = widget.target != null || widget.open != null
      ? SpaceScreen.workTab
      : widget.onChat
      ? SpaceScreen.chatTab
      : ref.read(spaceLastTabProvider(widget.spaceId)) == SpaceLastTab.chat
      ? SpaceScreen.chatTab
      : SpaceScreen.workTab;

  /// The Space menu's Daily report (slice 7), opened once.
  DaybookReportStart? _reportStart;

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
    // Opened on its People, they come once the Space is on screen
    // ([_openPeople]).
    final onPeople =
        widget.open == SpaceOpen.invite || widget.open == SpaceOpen.people;
    if (!onPeople && !widget.onChat) {
      // Not over a thread opened on top of the Space.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_askWalk());
      });
    }
  }

  /// Its People, with the invite screen on top when just made (S5), after
  /// the Space's first frame (review 105 J3): never from initState, and
  /// only where there is a router to push them on.
  bool _peopleAsked = false;

  void _openPeople() {
    if (_peopleAsked ||
        (widget.open != SpaceOpen.invite && widget.open != SpaceOpen.people)) {
      return;
    }
    _peopleAsked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router == null) return;
      unawaited(router.push(AppRoutes.spacePeople(widget.spaceId)));
      if (widget.open == SpaceOpen.invite) {
        unawaited(router.push(AppRoutes.spaceInvite(widget.spaceId)));
      }
    });
  }

  /// Review 121 KP2: the first time after being let in, Who to call, once,
  /// when the Space has key people. Not over a thread opened on top.
  bool _welcomeAsked = false;

  void _welcome(SpaceDetail space) {
    if (_welcomeAsked || widget.onChat) return;
    _welcomeAsked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final KeyPeople people;
      try {
        people = await ref.read(spaceKeyPeopleProvider(space.id).future);
      } on Exception {
        // Not read: the Space opens as it is; the sheet comes next time.
        return;
      }
      if (!mounted || people.seen || !people.hasAnyone) return;
      await showKeyPeopleWelcome(context, ref, space: space, people: people);
    });
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
  /// back for a new version, which goes into its folder (libfix).
  Future<void> _openSearch() async {
    final replaces = await context.push<LibraryFile>(
      AppRoutes.spaceSearch(widget.spaceId),
    );
    if (replaces != null && mounted) {
      await addLibraryFileHere(
        context,
        ref,
        spaceId: widget.spaceId,
        replaces: replaces,
      );
    }
    if (!mounted) return;
    // Review 105C: a place found there shows Work for it.
    if (mounted && ref.read(workPlaceFilterProvider(widget.spaceId)) != null) {
      _show(SpaceScreen.workTab);
    }
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

  /// The Library: its files stay there (libfix).
  Future<void> _openLibrary() =>
      context.push<void>(AppRoutes.spaceLibrary(widget.spaceId));

  /// Back (SP1, review 105 J1) is always there: with nothing under the
  /// Space (a link, a notification), it goes to Home's Spaces.
  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      unawaited(navigator.maybePop());
      return;
    }
    ref.read(homeTabProvider.notifier).show(HomeScreen.spacesTab);
    context.go(AppRoutes.home);
  }

  void _show(int tab) {
    setState(() {
      ref.read(workSelectionProvider(widget.spaceId).notifier).clear();
      _tab = tab;
      _reportStart = null;
    });
    // Review 113 (5): the Space remembers the tab last used in it.
    unawaited(
      ref
          .read(spaceLastTabProvider(widget.spaceId).notifier)
          .show(
            tab == SpaceScreen.chatTab ? SpaceLastTab.chat : SpaceLastTab.work,
          ),
    );
  }

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

    _openPeople();
    _welcome(detail);
    final unread = spaceUnread(
      ref.watch(spaceThreadsProvider(widget.spaceId)).value ?? const [],
    );
    final waiting =
        detail.iAmAdmin &&
        joinWaiting(ref.watch(spacePeopleProvider(widget.spaceId)).value);
    final selected = _tab == SpaceScreen.workTab
        ? ref.watch(workSelectionProvider(widget.spaceId))
        : const <String>{};
    // Review 110 CP1: writing takes the whole screen. The tree stays the
    // same, so the Work tab keeps what is being written.
    final composing =
        _tab == SpaceScreen.workTab &&
        ref.watch(spaceComposingProvider(widget.spaceId));
    return Scaffold(
      backgroundColor: composing ? BvColors.surfaceElevated : null,
      appBar: composing
          ? null
          : BvSpaceHeader(
              selected: selected.isEmpty
                  ? null
                  : l10n.workSelected(selected.length),
              closeSelectionLabel: l10n.workCloseSelection,
              onCloseSelection: () => ref
                  .read(workSelectionProvider(widget.spaceId).notifier)
                  .clear(),
              name: detail.name,
              // As in the v13 frames, linked to a project or not (review 54 A4).
              line: l10n.spacesPrivateWork,
              backLabel: MaterialLocalizations.of(context).backButtonTooltip,
              onBack: _back,
              onOpen: () => unawaited(_openInfo()),
              searchLabel: l10n.searchMenu,
              onSearch: () => unawaited(_openSearch()),
              libraryLabel: l10n.spacesTabLibrary,
              onLibrary: () => unawaited(_openLibrary()),
              peopleLabel: l10n.spacesTabPeople,
              onPeople: () => unawaited(
                context.push(AppRoutes.spacePeople(widget.spaceId)),
              ),
              peopleWaiting: waiting,
              waitingLabel: l10n.spacesPeopleWaiting,
            ),
      body: SafeArea(
        top: composing,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Visibility(
              visible: !composing,
              child: Padding(
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
            ),
            // Review 113 (18): a call and its answer show here.
            if (!composing) NeedYouStrip(spaceId: widget.spaceId),
            // Review 115 (3): a sideways swipe moves between Work and
            // Chat; not while writing or choosing work items.
            Expanded(
              child: BvTabSwipe(
                index: _tab,
                count: SpaceScreen.chatTab + 1,
                onSelect: _show,
                enabled: !composing && selected.isEmpty,
                child: _body(detail),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(SpaceDetail detail) => switch (_tab) {
    SpaceScreen.workTab => DaybookTab(
      space: detail,
      startWriting: widget.open == SpaceOpen.write,
      target: widget.target,
      startReport: _reportStart,
    ),
    _ => ChatTab(space: detail),
  };
}
