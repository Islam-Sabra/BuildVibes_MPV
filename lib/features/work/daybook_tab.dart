import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/rendering.dart'
    show
        applyGrowthDirectionToAxisDirection,
        BoxHitTestResult,
        RenderSliverEdgeInsetsPadding,
        RenderSliver,
        RenderSliverList,
        RenderViewport,
        RevealedOffset,
        RenderSliverMainAxisGroup,
        SliverHitTestResult,
        SliverPhysicalParentData,
        ViewportOffset;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../library/library_folders.dart' show showFolderSheet;
import '../../core/design/daybook_loop_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../chat/voice.dart'
    show
        RecordingBar,
        VoiceRecorder,
        maxVoice,
        minVoice,
        voicePlayerProvider,
        voiceRecorderProvider,
        voiceTime;
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../core/design/daybook_paper_specs.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/push/push_state.dart';
import '../../core/push/reminders.dart' show spaceReminderId;
import '../../core/network/signal_state.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/first_run_tip.dart';
import '../../data/models/check_in.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/daybook_live.dart';
import '../../data/repositories/check_in_repository.dart';
import '../../data/repositories/daybook_repository.dart'
    show daybookRepositoryProvider;
import '../../data/models/template.dart';
import '../../data/models/post_page.dart' show PageTaskTable, taskCount;
import '../../data/repositories/page_repository.dart' show taskTablesProvider;
import '../../data/repositories/schedule_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/template_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_tip.dart';
import '../../shared/widgets/bv_back_swipe.dart';
import '../../shared/widgets/bv_day_divider.dart';
import '../../shared/widgets/bv_daybook_masthead.dart';
import '../../shared/widgets/bv_needs_you_line.dart';
import '../../shared/widgets/bv_no_signal_strip.dart';
import '../../shared/widgets/bv_first_page.dart';
import '../../shared/widgets/bv_highlight.dart';
import '../../shared/widgets/bv_month_dropdown.dart';
import '../../shared/widgets/bv_new_chip.dart';
import '../../shared/widgets/bv_pinned_note.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_quote_block.dart';
import '../../shared/widgets/bv_popover_menu.dart'
    show BvMenuItem, showBvScreenMenu;
import '../../shared/widgets/bv_post_bar.dart';
import '../../shared/widgets/bv_proof_moment.dart';
import '../../shared/widgets/bv_selection_bar.dart';
import '../../shared/widgets/bv_chip.dart' show BvFilterChip;
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_trace_row.dart';
import '../../shared/widgets/bv_undo_bar.dart';
import '../../shared/widgets/bv_writing_toolbar.dart';
import '../../shared/widgets/bv_time_wheel.dart'
    show nextFiveMinutesAfterAnHour;
import '../../shared/widgets/lazy_rows.dart';
import '../account/account_parts.dart' show myMarketProvider;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/who_sees_sheet.dart';
import '../spaces/former_member.dart';
import '../spaces/pass_words.dart';
import '../spaces/space_errors.dart';
import '../notebook/notebook_page_screen.dart' show reminderWhen;
import '../profile/scheduled_screen.dart' show ScheduledLine;
import 'check_in_words.dart' show checkInRefusalText;
import 'composer_check_in.dart';
import 'composer_thanks.dart';
import 'post_later_sheet.dart';
import 'reminder_sheet.dart';
import 'space_day.dart' show spaceWallNow;
import 'first_run_tips.dart';
import 'daybook_attach.dart';
import 'daybook_card.dart';
import 'daybook_composer.dart';
import 'daybook_draft.dart';
import 'daybook_kinds.dart';
import 'daybook_loop.dart';
import 'daybook_marks.dart';
import 'daybook_page.dart' show PageTaskTableView, showDaybookPage;
import 'daybook_report.dart';
import 'daybook_state.dart';
import 'daybook_target.dart';
import 'daybook_templates.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart';
import 'work_gestures.dart';
import 'work_outbox.dart';
import 'work_places.dart';

/// The Space's Work tab: the daybook (v13, review 53 Part B). The day on
/// one line at the top, and under it the announcements pinned now (K1
/// v13); one card per post, full width, newest activity at the bottom
/// ("Now"). A scheduled activity shows again on its day (K3 v13). A card
/// with new activity moves to Now;
/// each earlier day it had something happen keeps a one-line trace that
/// goes back to it. Scrolling up goes back through older days on the same
/// page, each after a day divider, and the masthead names the day at the
/// top. Tapping it drops down the month (DY2). An empty Space shows its
/// first page (DY3); a Viewer reads only (V1).
///
/// The post bar's notepad writes a post in place at "Now" (E1–E6): the
/// kind chip picks what it is, and the writing toolbar takes the post
/// bar's place, its 📎 adding photos from the gallery or a file (K4). A
/// card with anything in it stays as a Draft (E4).
///
/// The loop lives on the cards: Sign as done, double-tap to check, the
/// menu on a long-press or a tap, swipe to add an update ([DaybookLoop]).
class DaybookTab extends ConsumerStatefulWidget {
  const DaybookTab({
    super.key,
    required this.space,
    this.startWriting = false,
    this.target,
    this.startReport,
  });

  final SpaceDetail space;

  /// Opened from an Activity row, a push or a Needs you card (F20): the
  /// page loads down to that card, scrolls to it and highlights it, its
  /// history open at the event's line. Gone: "This was removed".
  final DaybookTarget? target;

  /// Opened from Create's "Work item in a Space" (F1): the card opens at
  /// Now, when the reader may write work items here.
  final bool startWriting;

  /// The Space menu's Daily report (slice 7): today's report opens.
  final DaybookReportStart? startReport;

  @override
  ConsumerState<DaybookTab> createState() => _DaybookTabState();
}

/// A card as the page shows it: with what waits on the phone, at its
/// latest activity.
class _Shown {
  const _Shown({
    required this.card,
    required this.at,
    this.waiting = false,
    this.changeWaiting = false,
    this.unsent,
    this.refusedProof,
    this.localPhoto,
    this.landing = false,
    this.dayAt,
  });

  final DaybookCard card;
  final DateTime at;

  /// Where it sits on the page when that isn't [at]: an activity on its
  /// day shows at that day's start (K3 v13).
  final DateTime? dayAt;
  DateTime get placedAt => dayAt ?? at;
  final bool waiting;

  /// A change on its way waits for a signal (slice 10).
  final bool changeWaiting;

  /// A new work item not on the server yet.
  final PendingItem? unsent;

  /// A sign-off the server refused: a tap reopens its proof.
  final PendingItem? refusedProof;
  final String? localPhoto;
  final bool landing;

  bool get refused => (unsent?.refused ?? false) || refusedProof != null;
}

/// A trace: on an earlier day, the latest thing that happened to a card
/// that has moved on.
typedef _Trace = ({DaybookCard card, DaybookEvent event});

class _DaybookTabState extends ConsumerState<DaybookTab> {
  /// Older cards load while this much is left to scroll back.
  static const _loadAhead = 600.0;

  final _scroll = ScrollController();
  final _mastheadKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _dayKeys = <DateTime, GlobalKey>{};
  final _cardKeys = <String, GlobalKey>{};
  final _lineKeys = <String, GlobalKey>{};

  /// The page's rows, built only on screen (review 101 A): those built now,
  /// each row's day, and where each card and each day's divider is.
  final _built = <int, BuildContext>{};
  var _rowDays = <DateTime>[];
  final _cardRow = <String, int>{};
  final _dayRow = <DateTime, int>{};

  /// Ends the highlight once its ring is gone, so a card built again on
  /// scrolling back doesn't flash again.
  Timer? _unflash;

  /// Cards whose whole history is open (Show earlier, or a trace).
  final _expanded = <String>{};

  /// Pinned announcements opened from their slim line (review 61 G1).
  final _openPinned = <String>{};

  /// The card to open at, until the page has it (F20).
  late DaybookTarget? _target = widget.target;
  var _revealing = false;

  /// The card highlighted last, and how many times one was (each reveal
  /// flashes again).
  String? _highlighted;
  var _flashes = 0;

  /// The loaded days, oldest first.
  var _days = <DateTime>[];

  /// The day the masthead names: the one at the top of the page (F23).
  /// Null with no days: today.
  DateTime? _shownDay;

  /// Writing in place: the card is open with the keyboard's toolbar.
  var _writing = false;

  /// Review 105 Part 6: Work shows only what waits on me (the Needs you
  /// line was tapped).
  var _needsMine = false;

  /// The card is a posted work item's, being edited (X1 Edit).
  var _editing = false;
  DaybookWritingMenu? _menu;

  /// Review 110 CP2, CP3: # or +'s grid, in place of the keyboard.
  ComposerPanel? _panel;

  /// Post was tapped with nobody to do it, or nobody it is for: each new
  /// value pulses the card's "who" row (F56). Choosing someone never posts.
  Object? _askWho;

  /// The card on the page was left from before: it says "Draft".
  late bool _fromBefore;

  late final DaybookWriter _writer = DaybookWriter(ref, _spaceId);
  late final DaybookWriter _editor = DaybookWriter(
    ref,
    _spaceId,
    editing: true,
  );
  late final AppLifecycleListener _life;

  /// What others change in this Space, live (F47), and the wait that
  /// gathers a burst of changes into one read: at most one a second.
  StreamSubscription<String>? _live;
  Timer? _liveRead;
  static const _liveGather = Duration(seconds: 1);

  /// New activity came in at Now while the reader was up in older days
  /// (F11): the "New" chip shows until they go to Now.
  var _newBelow = false;

  /// Whether this page was on screen at the last look ([TickerMode]): a
  /// page shown again reads again.
  bool? _shown;

  String get _spaceId => widget.space.id;
  DaybookWriter get _card => _editing ? _editor : _writer;

  /// The reader's open items on the page, for the proof screen's list.
  var _openItems = const <DaybookPost>[];

  DaybookLoop get _loop => DaybookLoop(
    ref,
    widget.space,
    onEdit: _startEdit,
    openItems: _openItems,
    onWorkItemFrom: _workItemFrom,
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Review 105C: Work for one place reads every page, as Needs you does,
    // so none of that place's posts is left out.
    ref.listenManual(workPlaceFilterProvider(_spaceId), (_, place) {
      if (place != null) unawaited(_readAllPages());
    }, fireImmediately: true);
    // Review 110 TG1: Work for one tag, the same way.
    ref.listenManual(workTagFilterProvider(_spaceId), (_, tag) {
      if (tag != null) unawaited(_readAllPages());
    });
    // A card that only quotes a message just put in this Space (review
    // 64, DM5), or one just made from a note, is new, not a Draft from
    // before. F88: any other kept card,
    // a quoted one too, is the Draft however the Space was reached (back
    // from Home, another Space, a restart).
    final kept = ref.read(daybookDraftProvider(_spaceId));
    final fromNote = ref
        .read(daybookDraftProvider(_spaceId).notifier)
        .takeFromNote();
    _fromBefore =
        kept != null &&
        !kept.isEmpty &&
        !(widget.startWriting && (kept.onlyQuote || fromNote));
    // What was made with no signal sends when it's back: on opening and
    // on coming back to the app (the outbox also tries by itself). The
    // page is never stale (F11): it reads the newest cards when it opens
    // (from a push too), when the app comes back to the front, and when a
    // push for this Space arrives (build).
    // At most one read per [_liveGather] however many signals come
    // (review 63 R3): a busy or noisy Space never hammers the server.
    _live = ref.read(daybookLiveProvider).changes(_spaceId).listen((_) {
      _liveRead ??= Timer(_liveGather, () {
        _liveRead = null;
        unawaited(_refresh());
      });
    });
    _life = AppLifecycleListener(
      onResume: () {
        _flush();
        unawaited(_refresh());
      },
    );
    // Review 105 Part 7: my item just Checked, once.
    ref.listenManual(daybookCardsProvider(_spaceId), (_, next) {
      final cards = next.value;
      if (cards != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _proofMoment(cards),
        );
      }
    }, fireImmediately: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.startWriting && widget.space.myRights.createItems) {
        // "Work item in a Space" (Create, a message): a new card is a work
        // item, whatever kind was posted here last.
        _startWriting(kind: DaybookKind.workItem);
      }
      if (mounted && widget.startReport != null) unawaited(_startReport());
      _flush();
      // Kept from an earlier visit (another page of this Space is open
      // underneath): read again. A first load is already reading.
      if (mounted && ref.read(daybookCardsProvider(_spaceId)).hasValue) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didUpdateWidget(DaybookTab old) {
    super.didUpdateWidget(old);
    if (widget.target != old.target) _target = widget.target;
    final report = widget.startReport;
    if (report != null && report != old.startReport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startReport());
      });
    }
  }

  /// Opens the page at [_target]'s card (F20), once the first page is in:
  /// loads down to it ([DaybookCards.find]), opens its history at the
  /// event's line (reading "Show earlier" if it is older), scrolls to it
  /// and highlights it. A post that was deleted, or can't be seen any
  /// more, says "This was removed".
  Future<void> _reveal() async {
    final target = _target;
    if (target == null || _revealing || !mounted) return;
    _revealing = true;
    _target = null;
    try {
      final l10n = AppLocalizations.of(context);
      final pages = ref.read(daybookCardsProvider(_spaceId).notifier);
      var found = false;
      // A walk's work item is a row on the walk's card (slice 6): the walk
      // opens, then the work item's own card over it.
      String? child;
      try {
        // Its own card first: a walk's work item is never a card of its
        // own, so looking for it would read the daybook back 50 pages.
        String? parent;
        try {
          final one = await ref
              .read(daybookRepositoryProvider)
              .card(target.postId);
          // Archived (review 105B L7): not on Work's pages, so it opens
          // by itself, with Unarchive for a Lead.
          if (one != null && one.post.archivedAt != null) {
            if (mounted) {
              await _openCard(one, me: ref.read(authUserIdProvider).value);
            }
            return;
          }
          parent = one?.post.parentId;
        } on SpaceException {
          // Not reachable now: look for it on the pages as before.
        }
        if (parent != null && await pages.find(parent)) {
          found = true;
          child = target.postId;
        } else {
          found = await pages.find(target.postId);
        }
      } on SpaceException catch (e) {
        if (mounted) showSpaceError(context, e);
        return;
      }
      if (!mounted) return;
      if (!found) {
        showSpaceMessage(context, l10n.daybookRemoved);
        return;
      }
      if (child != null) {
        final card = ref
            .read(daybookCardsProvider(_spaceId))
            .value
            ?.where(
              (c) => c.post.children?.rows.any((r) => r.id == child) ?? false,
            )
            .firstOrNull;
        final parentId = card?.id;
        if (parentId != null) {
          setState(() => _newBelow = false);
          await WidgetsBinding.instance.endOfFrame;
          await _buildCard(parentId);
          final at = _cardKeys[parentId]?.currentContext;
          if (at != null && at.mounted) {
            await Scrollable.ensureVisible(at, alignment: 0.5);
          }
          if (!mounted) return;
          _flash(parentId);
        }
        if (mounted) await _loop.openChild(context, child);
        return;
      }
      var line = target.eventId;
      if (line != null) {
        try {
          if (!await pages.findLine(target.postId, line)) line = null;
        } on SpaceException {
          // Opens at the card.
          line = null;
        }
        if (!mounted) return;
      }
      setState(() {
        if (line != null) _expanded.add(target.postId);
        _newBelow = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _buildCard(target.postId);
      if (!mounted) return;
      final at =
          (line == null ? null : _lineKeys[line]?.currentContext) ??
          _cardKeys[target.postId]?.currentContext;
      if (at != null && at.mounted) {
        await Scrollable.ensureVisible(at, alignment: 0.5);
        // Laid out where it scrolled to, for the masthead's day.
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) return;
      _flash(target.postId);
      _updateShownDay();
    } finally {
      _revealing = false;
    }
  }

  /// Takes the page to [postId]'s card until it is built (review 101 A).
  Future<void> _buildCard(String postId) async {
    final row = _cardRow[postId];
    if (row != null && _scroll.hasClients) {
      await scrollUntilBuilt(_scroll.position, _built, row, up: true);
    }
  }

  /// Highlights [postId]'s card (F20), for as long as its ring shows.
  void _flash(String postId) {
    setState(() {
      _highlighted = postId;
      _flashes++;
    });
    final flashes = _flashes;
    _unflash?.cancel();
    _unflash = Timer(BvCardHighlightSpec.hold + BvCardHighlightSpec.fade, () {
      if (mounted && _flashes == flashes) setState(() => _highlighted = null);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Back on screen after a page on top of it closed: read again.
    final shown = TickerMode.valuesOf(context).enabled;
    if (_shown == false && shown) unawaited(_refresh());
    _shown = shown;
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    if (_recording) unawaited(_recorder?.cancel());
    _unpin?.cancel();
    _unflash?.cancel();
    _liveRead?.cancel();
    unawaited(_live?.cancel());
    _life.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _flush() {
    if (!mounted) return;
    unawaited(ref.read(workOutboxProvider.notifier).flush(_spaceId));
  }

  /// Reads the newest cards again, quietly; with no signal the page stays
  /// as it was.
  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      await ref.read(daybookCardsProvider(_spaceId).notifier).refresh();
    } on SpaceException catch (e) {
      debugPrint('daybook refresh: $e');
    }
    // The points, the faces and what sits above the page, after the read
    // (never while the page is being built).
    if (mounted) {
      refreshMarks(ref, _spaceId);
      ref.invalidate(daybookDueTodayProvider(_spaceId));
    }
  }

  /// The reader is up in older days, away from Now.
  bool get _away =>
      _scroll.hasClients && -_scroll.offset > BvNewChipSpec.awayFromNow;

  /// [_away] as last drawn: the masthead says Today at Now, and the
  /// "Today ↓" chip shows away from it (F59).
  bool _wasAway = false;

  /// Cards moved to Now (new activity on the server, or something done
  /// here) while the reader is up in older days: the page stays where it
  /// is, held on a card that didn't move, and the "New" chip shows.
  void _keepPlace(Set<String> moved) {
    if (moved.isEmpty || !_away) return;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    String? anchor;
    double? anchorY;
    for (final e in _cardKeys.entries) {
      if (moved.contains(e.key)) continue;
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height < top || y > bottom) continue;
      if (anchorY == null || (y - top).abs() < (anchorY - top).abs()) {
        anchor = e.key;
        anchorY = y;
      }
    }
    setState(() => _newBelow = true);
    if (anchor == null) return;
    final was = anchorY!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final box =
          _cardKeys[anchor]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final shift = was - box.localToGlobal(Offset.zero).dy;
      if (shift == 0) return;
      final position = _scroll.position;
      _scroll.jumpTo(
        (_scroll.offset - shift).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  /// The cards with new activity since [before].
  static Set<String> _movedOn(
    List<DaybookCard>? before,
    List<DaybookCard> now,
  ) {
    if (before == null || before.isEmpty) return const {};
    final was = {for (final c in before) c.id: c.lastActivityAt};
    final newest = before
        .map((c) => c.lastActivityAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return {
      for (final c in now)
        if (DaybookPost.shownKinds.contains(c.post.kind) &&
            (was[c.id] == null
                ? !c.lastActivityAt.isBefore(newest)
                : c.lastActivityAt.isAfter(was[c.id]!)))
          c.id,
    };
  }

  void _toNow() {
    setState(() => _newBelow = false);
    if (_scroll.hasClients) {
      unawaited(
        _scroll.animateTo(0, duration: BvMotion.base, curve: BvMotion.standard),
      );
    }
  }

  void _onScroll() {
    if (_away != _wasAway) setState(() => _wasAway = _away);
    _shownDayAfterLayout();
    _loadOlderIfNear();
    if (_newBelow && !_away) setState(() => _newBelow = false);
  }

  /// Older days hang above today on the same page (review 45 B1): load
  /// them while the top is near, including when the page isn't full yet.
  void _loadOlderIfNear() {
    if (!_scroll.hasClients || _scroll.position.extentBefore >= _loadAhead) {
      return;
    }
    unawaited(ref.read(daybookCardsProvider(_spaceId).notifier).loadOlder());
  }

  /// [_updateShownDay] once the page is laid out where it now scrolls to:
  /// a row's place on screen is only known then (review 101 A).
  void _shownDayAfterLayout() {
    if (_shownDayQueued) return;
    _shownDayQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shownDayQueued = false;
      if (mounted) _updateShownDay();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  var _shownDayQueued = false;

  /// The masthead names the day of what is at the top of the page (F23),
  /// at Now too: the latest day whose divider has reached the reading line
  /// just under the top, else the first day on the page. That day's divider is then hidden, so the
  /// same day never shows twice in a row ([_dividerHidden]).
  void _updateShownDay() {
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    if (_days.isEmpty) {
      if (_shownDay != null) setState(() => _shownDay = null);
      return;
    }
    final line =
        viewport.localToGlobal(Offset.zero).dy + BvMastheadSpec.readingLine;
    // Review 101 A: only the rows on screen are built, so a day is read off
    // its rows: one at or above the reading line has its divider there too.
    // With none, the first day laid out is the top one, even below the top
    // edge.
    DateTime? reached;
    DateTime? first;
    for (final MapEntry(key: i, value: row) in _built.entries) {
      if (i >= _rowDays.length || !row.mounted) continue;
      final box = row.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final day = _rowDays[i];
      if (first == null || day.isBefore(first)) first = day;
      if (box.localToGlobal(Offset.zero).dy <= line &&
          (reached == null || day.isAfter(reached))) {
        reached = day;
      }
    }
    final shown = reached ?? first;
    if (shown != _shownDay) setState(() => _shownDay = shown);
  }

  /// Review 105 Part 7: when my work item is Checked, "Added to your proof
  /// of work · Checked by … · time · View" for 4 s, on my phone only and
  /// only once (the items it was shown for are kept on the phone, per
  /// account). A check from days ago doesn't show it.
  void _proofMoment(List<DaybookCard> cards) {
    if (!mounted) return;
    final me = ref.read(authUserIdProvider).value;
    if (me == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final key = '$_proofSeenKey:$me';
    final seen = <String>{...?prefs.getStringList(key)};
    final now = ref.read(clockProvider)();
    final fresh = [
      for (final c in cards)
        if (c.post.isWorkItem &&
            c.post.item?.ownerId == me &&
            c.post.item?.status == WorkStatus.checked &&
            !seen.contains(c.id))
          if (c.proof?.outcome case final o?
              when o.kind == DaybookOutcomeKind.checked &&
                  o.byId != me &&
                  o.at != null &&
                  now.difference(o.at!) < BvProofMomentSpec.recent)
            (card: c, outcome: o),
    ];
    if (fresh.isEmpty) return;
    fresh.sort((a, b) => b.outcome.at!.compareTo(a.outcome.at!));
    final latest = fresh.first;
    unawaited(
      prefs.setStringList(
        key,
        [
          ...seen,
          for (final f in fresh) f.card.id,
        ].reversed.take(_proofSeenMax).toList(),
      ),
    );
    final l10n = AppLocalizations.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    messenger.showSnackBar(
      SnackBar(
        duration: BvProofMomentSpec.duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        content: BvProofMoment(
          title: l10n.proofMomentTitle,
          by: l10n.proofMomentBy(
            personName(l10n, latest.outcome.byName),
            words.time.clock(latest.outcome.at!),
          ),
          viewLabel: l10n.proofMomentView,
          onView: () {
            messenger.hideCurrentSnackBar();
            // On the Profile tab: my proof of work there.
            router.go(AppRoutes.profileDelivered);
          },
        ),
      ),
    );
  }

  static const _proofSeenKey = 'proof_moment_seen';
  static const _proofSeenMax = 200;

  /// The Needs you line tapped (review 105 Part 6): only what waits on me,
  /// with older pages read until each of [waiting] is on the page (as the
  /// old To do sheet listed them all, review 73 A1); again, everything.
  Future<void> _toggleNeedsMine(Set<String> waiting) async {
    final on = !_needsMine;
    setState(() => _needsMine = on);
    if (!on) return;
    final provider = daybookCardsProvider(_spaceId);
    final pages = ref.read(provider.notifier);
    for (;;) {
      final onPage = {
        for (final c in ref.read(provider).value ?? const <DaybookCard>[]) c.id,
      };
      if (waiting.every(onPage.contains) ||
          !pages.hasOlder ||
          !await pages.loadOlder()) {
        break;
      }
      if (!mounted) return;
    }
  }

  /// The cards to show: those of [place] when Work is filtered to one,
  /// and of [waiting] when it shows what waits on me; both, together.
  /// Review 110 TG1: and of [tag] when Work is filtered to one tag.
  static Set<String>? _shownOnly(
    List<DaybookCard> cards,
    SpacePlace? place,
    Set<String>? waiting, {
    DaybookTag? tag,
  }) {
    Set<String>? only = waiting;
    Set<String> and(bool Function(DaybookPost p) keep) {
      final these = {
        for (final c in cards)
          if (keep(c.post)) c.id,
      };
      return only == null ? these : these.intersection(only);
    }

    if (place != null) only = and((p) => p.placeId == place.id);
    if (tag != null) only = and((p) => p.tag?.id == tag.id);
    return only;
  }

  /// Every page of Work, oldest last (a place's filter, review 105C).
  Future<void> _readAllPages() async {
    final pages = ref.read(daybookCardsProvider(_spaceId).notifier);
    while (pages.hasOlder && await pages.loadOlder()) {
      if (!mounted) return;
    }
  }

  /// The divider of the day the masthead names: the masthead says it.
  /// That is only away from Now: at Now the masthead says Today, so every
  /// day keeps its divider, and Today's always shows, right above the
  /// writing area (F59).
  bool _dividerHidden(DateTime day, DateTime today) =>
      !_writing && _wasAway && day == _shownDay && day != today;

  /// Shows [day]: loads older pages until it is reached, then puts the
  /// latest day on or before it at the top.
  Future<void> _jumpTo(DateTime day) async {
    final provider = daybookCardsProvider(_spaceId);
    final pages = ref.read(provider.notifier);
    for (;;) {
      final cards = ref.read(provider).value ?? const <DaybookCard>[];
      if (cards.isEmpty ||
          !dayOf(cards.last.lastActivityAt).isAfter(day) ||
          !pages.hasOlder ||
          !await pages.loadOlder()) {
        break;
      }
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _days.isEmpty) return;
    final target = _days.lastWhere(
      (d) => !d.isAfter(day),
      orElse: () => _days.first,
    );
    final row = _dayRow[target];
    if (row != null && _scroll.hasClients) {
      await scrollUntilBuilt(_scroll.position, _built, row, up: true);
    }
    if (!mounted) return;
    final context = _dayKeys[target]?.currentContext;
    if (context == null || !context.mounted) return;
    // 1 puts the day's top at the page's top ([_RenderNowViewport]).
    await Scrollable.ensureVisible(context, alignment: 1);
    _shownDayAfterLayout();
  }

  /// A trace's ›: the card, with its history open at that event.
  Future<void> _openAt(_Trace trace) async {
    setState(() => _expanded.add(trace.card.id));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _buildCard(trace.card.id);
    if (!mounted) return;
    final context =
        (trace.event.shown ? _lineKeys[trace.event.id] : null)
            ?.currentContext ??
        _cardKeys[trace.card.id]?.currentContext;
    if (context == null || !context.mounted) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: BvMotion.base,
      curve: BvMotion.standard,
    );
  }

  /// Show earlier: the rest of the loaded lines in place; past them, the
  /// next ones from the server.
  void _earlier(DaybookCard card) {
    final open = _expanded.contains(card.id);
    final lines = card.history.where((e) => e.shown).length;
    setState(() => _expanded.add(card.id));
    if (open || lines <= DaybookCardView.shownLines) {
      unawaited(_loadEarlier(card.id));
    }
  }

  Future<void> _loadEarlier(String postId) async {
    try {
      await ref
          .read(daybookCardsProvider(_spaceId).notifier)
          .loadEarlier(postId);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
  }

  Future<void> _openMonth(DateTime today, DateTime shown) async {
    final masthead =
        _mastheadKey.currentContext?.findRenderObject() as RenderBox?;
    if (masthead == null) return;
    final top = masthead.localToGlobal(Offset.zero).dy;
    final firstWeekday =
        ref.read(myMarketProvider)?.weekStart ??
        MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final container = ProviderScope.containerOf(context);
    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: BvColors.overlayDim,
      pageBuilder: (_, _, _) => UncontrolledProviderScope(
        container: container,
        child: Padding(
          padding: EdgeInsetsDirectional.only(top: top),
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: DaybookMonthDrop(
              spaceId: _spaceId,
              today: today,
              selected: shown,
              firstWeekday: firstWeekday,
            ),
          ),
        ),
      ),
    );
    if (picked != null && mounted) await _jumpTo(picked);
  }

  /// The post bar's camera: the phone's camera at once, for a photo post
  /// (the lead's ruling on H3, review 105). Walk is the writing card's
  /// last kind chip.
  Future<void> _camera() async {
    _startWriting();
    await _photos(_writer.addPhoto());
  }

  /// The Walk chip (H3): walk mode, as from the camera before. An empty
  /// card is put down first; one with words stays a Draft.
  Future<void> _walk() async {
    final kept = ref.read(daybookDraftProvider(_spaceId));
    if (kept == null || kept.isEmpty) _stopWriting();
    await context.push(AppRoutes.spaceWalk(_spaceId));
  }

  /// Opens the card at "Now", with a new post id (or the Draft's). A new
  /// one is [kind], else the last kind posted here (review 110 G1; Note
  /// the first time), if this person may post it (W11). Who may only
  /// thank (a Viewer) gets a Thanks, a Draft kept as another kind too.
  void _startWriting({DaybookKind? kind}) {
    final kinds = composerKindsFor(widget.space);
    ref
        .read(daybookDraftProvider(_spaceId).notifier)
        .open(
          ref.read(newPostIdProvider)(),
          kind:
              kind ??
              composerStartKind(
                ref.read(sharedPreferencesProvider),
                _spaceId,
                kinds,
              ),
        );
    final opened = ref.read(daybookDraftProvider(_spaceId))?.kind;
    if (!widget.space.myRights.createItems &&
        opened != null &&
        !kinds.contains(opened)) {
      unawaited(_writer.switchKind(kinds.first));
    }
    _composing(true);
    setState(() {
      _writing = true;
      _editing = false;
      _menu = null;
      _panel = null;
      _askWho = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /// Review 116 PL3: Make it a work item from a decided poll: a new work
  /// item card titled with the question and its answer. A card already
  /// being written opens instead, as for a daily report.
  void _workItemFrom(String title) {
    final kept = ref.read(daybookDraftProvider(_spaceId));
    if (kept != null && !kept.isEmpty) {
      showSpaceMessage(
        context,
        AppLocalizations.of(context).dailyReportDraftFirst,
      );
      _fromBefore = true;
      _startWriting();
      return;
    }
    _fromBefore = false;
    if (kept != null) unawaited(_writer.setKind(DaybookKind.workItem));
    _startWriting(kind: DaybookKind.workItem);
    unawaited(_writer.setTitle(title));
  }

  /// Review 113 bug 7: Link folder from Tap to fix, for a drawing too big
  /// for a Space.
  Future<void> _linkFolder() =>
      showFolderSheet(context, ref, space: widget.space, link: true);

  /// Daily report (slice 7, review 78 §4): today's own draft if there is
  /// one; otherwise a new report for today, titled with the day, from the
  /// built-in Daily report. A report is for today only: yesterday's draft
  /// is put away. A card of another kind being written opens instead.
  Future<void> _startReport() async {
    if (!widget.space.myRights.createItems) return;
    final l10n = AppLocalizations.of(context);
    final today = dayOf(ref.read(clockProvider)());
    final notifier = ref.read(daybookDraftProvider(_spaceId).notifier);
    final kept = ref.read(daybookDraftProvider(_spaceId));
    if (kept != null && kept.kind == DaybookKind.report) {
      if (kept.reportDay == today) {
        _fromBefore = !kept.isEmpty;
        _startWriting();
        return;
      }
      await notifier.discard();
      if (!mounted) return;
      if (!kept.isEmpty) showSpaceMessage(context, l10n.dailyReportTodayOnly);
    } else if (kept != null && !kept.isEmpty) {
      showSpaceMessage(context, l10n.dailyReportDraftFirst);
      _fromBefore = true;
      _startWriting();
      return;
    }
    _fromBefore = false;
    _startWriting();
    await _writer.startReport(
      today,
      title: DaybookWords(
        l10n,
        Localizations.localeOf(context).toLanguageTag(),
        use24: MediaQuery.alwaysUse24HourFormatOf(context),
      ).compactDate(today),
    );
  }

  /// Edit a posted work item: its card opens at "Now", filled (X1 Edit).
  void _startEdit(DaybookPost post) {
    ref.read(daybookEditProvider(_spaceId).notifier).start(post);
    _composing(true);
    setState(() {
      _writing = true;
      _editing = true;
      _menu = null;
      _panel = null;
      _askWho = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /// Puts the card down: with anything in it, it stays as the Draft;
  /// empty, it goes. An edit put down leaves the post as it was.
  void _stopWriting() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_editing) {
      ref.read(daybookEditProvider(_spaceId).notifier).stop();
    } else {
      final draft = ref.read(daybookDraftProvider(_spaceId));
      unawaited(ref.read(daybookDraftProvider(_spaceId).notifier).close());
      if (draft != null && !draft.isEmpty) _fromBefore = true;
    }
    _composing(false);
    setState(() {
      _writing = false;
      _editing = false;
      _menu = null;
      _panel = null;
      _askWho = null;
    });
  }

  /// Discard (review 113 (1)): the draft is gone, with its photos.
  Future<void> _discardDraft() async {
    await ref.read(daybookDraftProvider(_spaceId).notifier).discard();
    if (mounted) _stopWriting();
  }

  // Review 113 (11): hold the mic to record, as in WhatsApp: release
  // attaches it to the post, slide away cancels. As in Chat and the
  // notebook.
  bool _recording = false;
  bool _cancelling = false;
  bool _holding = false;
  Duration _elapsed = Duration.zero;
  Stopwatch? _watch;
  Timer? _recordTimer;

  /// Kept for dispose, when ref can no longer be read.
  VoiceRecorder? _recorder;

  Future<void> _startRecording() async {
    // B4 (review 114): the long-press menu goes when recording starts.
    ContextMenuController.removeAny();
    final l10n = AppLocalizations.of(context);
    final recorder = ref.read(voiceRecorderProvider);
    _recorder = recorder;
    _holding = true;
    await ref.read(voicePlayerProvider.notifier).pause();
    if (!await recorder.allowed()) {
      if (mounted) showSpaceMessage(context, l10n.chatMicDenied);
      return;
    }
    if (!_holding || !mounted) return;
    await recorder.start();
    if (!_holding || !mounted) {
      await recorder.cancel();
      return;
    }
    _watch = clock.stopwatch()..start();
    setState(() {
      _recording = true;
      _cancelling = false;
      _elapsed = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _watch!.elapsed);
      if (_elapsed >= maxVoice) unawaited(_endRecording());
    });
  }

  void _slide(Offset offset) {
    final cancelling = offset.distance > BvChatSpec.slideToCancel;
    if (cancelling != _cancelling) setState(() => _cancelling = cancelling);
  }

  Future<void> _endRecording() async {
    _holding = false;
    _recordTimer?.cancel();
    if (!_recording) return;
    final l10n = AppLocalizations.of(context);
    final recorder = ref.read(voiceRecorderProvider);
    final measured = _watch?.elapsed ?? _elapsed;
    final length = measured > maxVoice ? maxVoice : measured;
    final cancel = _cancelling;
    setState(() {
      _recording = false;
      _cancelling = false;
    });
    if (cancel) {
      await recorder.cancel();
      return;
    }
    final path = await recorder.stop();
    if (!mounted || path == null) return;
    if (length < minVoice) {
      showSpaceMessage(context, l10n.notebookTooShort);
      return;
    }
    await _writer.setVoice(path, length.inMilliseconds);
  }

  /// Review 110 CP1: the Space screen hides its header while writing.
  void _composing(bool on) =>
      ref.read(spaceComposingProvider(_spaceId).notifier).set(on);

  /// # or + (CP2, CP3): its grid in place of the keyboard, or back.
  void _setPanel(ComposerPanel? panel) => setState(() {
    _panel = panel;
    _menu = null;
  });

  /// A kind from # (CP2): what it doesn't take goes, in one line. Only a
  /// kind this person may post (W11).
  Future<void> _switchKind(DaybookKind kind) async {
    _setPanel(null);
    if (!composerKindsFor(widget.space).contains(kind)) return;
    final l10n = AppLocalizations.of(context);
    final drops = await _card.switchKind(kind);
    if (!mounted || drops.isEmpty) return;
    String name(ComposerDrop d) => switch (d) {
      ComposerDrop.owner || ComposerDrop.people => l10n.daybookRowFor,
      ComposerDrop.place => l10n.daybookRowPlace,
      ComposerDrop.due => l10n.daybookRowDue,
      ComposerDrop.start => l10n.daybookRowWhen,
      ComposerDrop.pin => l10n.cpPin,
      ComposerDrop.files => l10n.cpFiles,
      ComposerDrop.tables => l10n.cpTables,
      ComposerDrop.thanks => l10n.thanksTo,
      ComposerDrop.tag => l10n.cpTag,
      ComposerDrop.checklist => l10n.daybookKindChecklist,
      ComposerDrop.checkIn => l10n.checkInDropWhat,
      ComposerDrop.photos => l10n.cpPhotos,
    };
    showSpaceMessage(
      context,
      l10n.cpRemoved(
        {for (final d in drops) name(d)}.join(' · '),
        kindName(l10n, kind),
      ),
    );
  }

  /// An extra from + (CP3): each opens its own picker, as before.
  Future<void> _extra(ComposerExtra extra) async {
    switch (extra) {
      case ComposerExtra.place:
        await _pickPlace();
      case ComposerExtra.people:
        await _pickPeople();
      case ComposerExtra.due:
        await _pickDue();
      case ComposerExtra.photos:
        await _photos(_card.addPhotos());
      case ComposerExtra.file:
        await _attach();
      case ComposerExtra.pin:
        await _pickPin();
      case ComposerExtra.table:
        await editComposerTable(context, _card);
      case ComposerExtra.taskTable:
        await editComposerTasks(context, _card);
      // Review 110 step 5: the points to tick, on a sheet.
      case ComposerExtra.checklist:
        await editComposerChecklist(context, _card);
      // TG1: Tag's list in place of the keyboard.
      case ComposerExtra.tag:
        _setPanel(ComposerPanel.tags);
      // Bullets is the composer's own (a line in the details).
      case ComposerExtra.bullets:
        break;
      // Review 109 CI1b: a check-out's time and allowance; Every day.
      case ComposerExtra.checkOut:
        await _pickCheckOut();
      case ComposerExtra.everyDay:
        await _card.setDaily(true);
      case ComposerExtra.closes:
        await _pickPollCloses();
    }
  }

  /// Review 116: a poll's closing time: a day and, if chosen, its time
  /// (else the end of that day); Remove takes it off. One that has passed
  /// is refused before sending.
  Future<void> _pickPollCloses() async {
    _setMenu(null);
    final now = ref.read(clockProvider)();
    final closes = _card.draft?.pollClosesAt;
    final picked = await ref.read(pickDueProvider)(
      context,
      now: now,
      day: closes == null ? null : dayOf(closes),
      at: closes,
    );
    if (picked == null || !mounted) return;
    final day = picked.day;
    if (day == null) {
      await _card.setPollClosesAt(null);
      return;
    }
    final at =
        picked.at ?? dayOf(day).add(const Duration(days: 1, minutes: -1));
    if (!at.isAfter(now)) {
      showSpaceMessage(context, AppLocalizations.of(context).pollClosesLater);
      return;
    }
    await _card.setPollClosesAt(at);
  }

  /// Review 109 CI1: a Check-in's lines.
  Future<void> _checkIn(CheckInPick pick) async {
    _setMenu(null);
    switch (pick) {
      case CheckInPick.teams:
        final teams = audienceTeams(
          ref.read(spacePeopleProvider(_spaceId)).value,
          me: ref.read(authUserIdProvider).value,
          admin: widget.space.iAmAdmin,
        );
        final picked = await pickCheckInTeams(
          context,
          teams: teams,
          chosen: _card.draft?.checkInTeams ?? const [],
        );
        if (picked != null) await _card.setCheckInTeams(picked);
      case CheckInPick.time:
        await _pickCheckInTime();
      case CheckInPick.place:
        await setCheckInPlace(context, ref, _card);
    }
  }

  /// The check-in's time and allowance (one single choice).
  Future<void> _pickCheckInTime() async {
    final d = _card.draft;
    if (d == null) return;
    final picked = await pickCheckInTime(
      context,
      out: false,
      time: d.inTime,
      allow: d.inAllow,
    );
    if (picked == null || !mounted) return;
    setState(() => _askWho = null);
    await _card.setCheckInTime(picked.time, picked.allow);
  }

  /// + → Check-out (CI1b), or its chip: the time and the allowance.
  Future<void> _pickCheckOut() async {
    final d = _card.draft;
    if (d == null) return;
    final from = d.inTime;
    final picked = await pickCheckInTime(
      context,
      out: true,
      time: d.outTime,
      allow: d.outAllow ?? checkInDefaultAllowance,
      suggested: from == null
          ? null
          : DayTime((from.hour + 8) % 24, from.minute),
    );
    if (picked != null) await _card.setCheckOut(picked);
  }

  void _setMenu(DaybookWritingMenu? menu) {
    if (menu == DaybookWritingMenu.audience) {
      unawaited(_pickAudience());
      return;
    }
    setState(() {
      _menu = menu;
      if (menu != null) _askWho = null;
    });
  }

  /// Review 111 TM5: Who sees it, a sheet over the page.
  Future<void> _pickAudience() async {
    _setMenu(null);
    final people = ref.read(spacePeopleProvider(_spaceId)).value;
    final me = ref.read(authUserIdProvider).value;
    if (people == null || me == null) return;
    final picked = await pickWhoSees(
      context,
      people: people,
      me: me,
      spaceAdmin: widget.space.iAmAdmin,
      chosen: _card.draft?.teamId,
    );
    if (picked != null && mounted) await _card.setTeam(picked.team);
  }

  /// Who a checklist or an activity is for (F45): a sheet over the page,
  /// so nothing under it can be tapped. Each pick adds or takes out a
  /// person at once; Done, dragging it down, a tap outside or Back closes
  /// it and keeps the choice. It never posts by itself.
  Future<void> _pickPeople() async {
    _setMenu(null);
    final me = ref.read(authUserIdProvider).value;
    await showBvSheet<void>(
      context: context,
      title: AppLocalizations.of(context).daybookPeople,
      builder: (_) =>
          DaybookPeopleSheet(spaceId: _spaceId, me: me, editing: _editing),
      foot: (sheet) => DaybookPeopleDone(
        spaceId: _spaceId,
        editing: _editing,
        onDone: () => Navigator.of(sheet).pop(),
      ),
    );
  }

  /// A Thanks's To (review 110 TH1): Teams, then people.
  Future<void> _pickThanksTo() async {
    _setMenu(null);
    final picked = await pickThanksTo(
      context,
      ref,
      spaceId: _spaceId,
      me: ref.read(authUserIdProvider).value,
      currentId: _card.draft?.thanksToId,
    );
    if (picked == null || !mounted) return;
    setState(() => _askWho = null);
    await _card.setThanksTo(
      id: picked.id,
      name: picked.name,
      team: picked.team,
    );
  }

  /// A Thanks's For: one of this Space's open work items.
  Future<void> _pickThanksFor() async {
    _setMenu(null);
    final picked = await pickThanksFor(
      context,
      ref,
      spaceId: _spaceId,
      currentId: _card.draft?.thanksForId,
    );
    if (picked != null) await _card.setThanksFor(picked);
  }

  /// The Place row, or More → Location (review 105C; the lead's check
  /// O1): the Space's places on a sheet, like Give to's.
  Future<void> _pickPlace() async {
    _setMenu(null);
    await showBvSheet<void>(
      context: context,
      title: AppLocalizations.of(context).daybookRowPlace,
      builder: (_) => DaybookPlaceSheet(spaceId: _spaceId, editing: _editing),
    );
  }

  /// Templates (slice 7; review 110 W9: on the composer's top bar): this
  /// kind's templates for this audience; one fills the card.
  Future<void> _pickTemplate() async {
    _setMenu(null);
    final draft = _card.draft;
    if (draft == null) return;
    final List<PostTemplate> all;
    try {
      all = await ref.read(spaceTemplatesProvider(_spaceId).future);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    if (!mounted) return;
    final picked = await showTemplatePicker(
      context,
      spaceId: _spaceId,
      templates: templatesFor(
        all,
        draft.kind,
        teamId: draft.teamId,
        chosenTeam: draft.teamId != null,
      ),
    );
    if (picked == null || !mounted) return;
    final team = picked.teamId == null
        ? null
        : ref
              .read(spacePeopleProvider(_spaceId))
              .value
              ?.teams
              .where((t) => t.id == picked.teamId)
              .firstOrNull;
    await _card.useTemplate(AppLocalizations.of(context), picked, team: team);
  }

  Future<void> _pickDue() async {
    _setMenu(null);
    final draft = _card.draft;
    final picked = await ref.read(pickDueProvider)(
      context,
      now: ref.read(clockProvider)(),
      day: draft?.dueDate,
      at: draft?.dueAt,
    );
    if (picked != null) await _card.setDue(picked);
  }

  /// An announcement's pin (More → Pin until): the last day, or Remove.
  Future<void> _pickPin() async {
    _setMenu(null);
    final picked = await ref.read(pickPinProvider)(
      context,
      now: ref.read(clockProvider)(),
      until: _card.draft?.pinnedUntil,
    );
    if (picked == null || !mounted) return;
    final until = picked.until;
    // F82: today, a time kept from before may have passed.
    if (until != null && !until.isAfter(ref.read(clockProvider)())) {
      showSpaceMessage(context, AppLocalizations.of(context).daybookPinLater);
      return;
    }
    await _card.setPin(until);
  }

  /// "+ Time" on the pin (F82): the time on its last day it ends; one
  /// that has passed is refused before sending.
  Future<void> _pickPinTime() async {
    final until = _card.draft?.pinnedUntil;
    if (until == null) return;
    final day = dayOf(pinnedLastDay(until));
    final now = ref.read(clockProvider)();
    final picked = await ref.read(pickPinTimeProvider)(
      context,
      initial: TimeOfDay.fromDateTime(
        pinHasTime(until) ? until.toLocal() : nextFiveMinutesAfterAnHour(now),
      ),
    );
    if (picked == null || !mounted) return;
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      picked.hour,
      picked.minute,
    );
    if (!at.isAfter(ref.read(clockProvider)())) {
      showSpaceMessage(context, AppLocalizations.of(context).daybookPinLater);
      return;
    }
    await _card.setPin(at);
  }

  /// An activity's start and end (More → Time). True when one was set; a
  /// start that has come already says so.
  Future<bool> _pickStart() async {
    _setMenu(null);
    final draft = _card.draft;
    final picked = await ref.read(pickStartProvider)(
      context,
      now: ref.read(clockProvider)(),
      start: draft?.startsAt,
      end: draft?.endsAt,
    );
    if (picked == null || !mounted) return false;
    if (!picked.start.isAfter(ref.read(clockProvider)())) {
      showSpaceMessage(context, AppLocalizations.of(context).daybookStartLater);
      return false;
    }
    await _card.setStart(picked.start, picked.end);
    return true;
  }

  /// A file post's file (K2): one in the Library or one from the phone.
  Future<void> _pickFile() async {
    _setMenu(null);
    final file = await chooseDaybookFile(context, ref, spaceId: _spaceId);
    if (file != null) await _card.addFile(file);
  }

  /// 📎 (K4, F39): the same "Add to this post" sheet on every kind, a
  /// photo from the gallery or a file. The server takes PDFs on every kind
  /// (create_space_post's p_files, add_post_files), so the File row is
  /// always there: on a file post it chooses its file; on the others it
  /// adds one, which goes to the Library too.
  /// Photos being added: a line when any of them nobody could open (review
  /// 74 H1); the others are on the card.
  Future<void> _photos(Future<int> adding) async {
    final refused = await adding;
    if (refused > 0 && mounted) {
      showSpaceMessage(context, AppLocalizations.of(context).photoCannotOpen);
    }
  }

  Future<void> _attach() async {
    _setMenu(null);
    final l10n = AppLocalizations.of(context);
    final writer = _card;
    final kind = writer.draft?.kind ?? DaybookKind.workItem;
    final choice = await showDaybookAttach(
      context,
      photosLeft: writer.room.clamp(0, DaybookPostDraft.filesMax),
      // A file post is its file: no photos.
      photos: kind != DaybookKind.file,
    );
    if (!mounted || choice == null) return;
    final source = switch (choice) {
      DaybookAttach.files => DaybookFileSource.phone,
      DaybookAttach.library => DaybookFileSource.library,
      _ => null,
    };
    // A file post's one file: a new one replaces it.
    if (source != null && kind == DaybookKind.file) {
      final file = await chooseDaybookFile(
        context,
        ref,
        spaceId: _spaceId,
        source: source,
      );
      if (file != null) await writer.addFile(file);
      return;
    }
    if (writer.room <= 0) {
      showSpaceMessage(context, l10n.daybookFilesFull);
      return;
    }
    switch (choice) {
      case DaybookAttach.camera:
        await _photos(writer.addPhoto());
      case DaybookAttach.photos:
        await _photos(writer.addPhotos());
      case DaybookAttach.files || DaybookAttach.library:
        final file = await chooseDaybookFile(
          context,
          ref,
          spaceId: _spaceId,
          source: source,
        );
        if (file == null) return;
        // Review 81 R2: a new version is always a File post, so it asks
        // people to receive it and the older post says "Replaced by".
        if (file.supersedesId != null) await writer.setKind(DaybookKind.file);
        await writer.addFile(file);
    }
  }

  /// Post. What it still needs opens first: with nobody to do a work
  /// item, the assign picker (review 46); with nobody a checklist is for,
  /// the people sheet (then Post again: F45); an activity with no start,
  /// the time pickers.
  /// Post (F56): only this button posts. With nobody chosen yet, the
  /// "who" row pulses and asks; with no time, the time pickers open. A
  /// picker only fills the card, and never posts.
  Future<void> _postOrAsk(String? myName) async {
    final draft = _writer.draft;
    if (draft == null || !draft.readyToTry) return;
    switch (draft.missing(ref.read(clockProvider)())) {
      // Review 110 CP1: an activity's lines are When and Team, so who's
      // coming (still required, F56) is asked on the people sheet.
      case DaybookMissing.people when draft.kind == DaybookKind.activity:
        await _pickPeople();
      case DaybookMissing.owner || DaybookMissing.people || DaybookMissing.to:
        setState(() {
          _menu = null;
          _askWho = Object();
        });
      case DaybookMissing.start:
        await _pickStart();
      case DaybookMissing.checkInTime:
        setState(() => _askWho = Object());
        await _pickCheckInTime();
      case null:
        await _post(myName);
    }
  }

  void _assigned() => _setMenu(null);

  /// Post later (review 108 PL1): the time, then the post goes to the
  /// server to be made then; "Scheduled for …". On the Space's clock and
  /// its market's calendar (V3).
  Future<void> _postLater(String? myName) async {
    final space = widget.space;
    final later = await showPostLaterSheet(
      context,
      zone: space.timeZone,
      marketId: space.marketId,
    );
    if (later == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final now = spaceWallNow(space.timeZone, ref.read(clockProvider)());
    await _post(myName, at: later.at);
    if (!mounted) return;
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    showSpaceMessage(
      context,
      l10n.plScheduledFor(reminderWhen(l10n, words, later.wall, now)),
    );
  }

  Future<void> _post(String? myName, {DateTime? at}) async {
    // A daily report goes with its page, made now in the writer's words.
    final draft = _writer.draft;
    if (draft != null && draft.kind == DaybookKind.report) {
      await _writer.setPage(reportPage(AppLocalizations.of(context), draft));
      if (!mounted) return;
    }
    // B4 (review 114): a voice note with no title is named for what it is,
    // in the writer's words.
    if (draft != null && draft.untitledVoice) {
      await _writer.setTitle(
        AppLocalizations.of(
          context,
        ).daybookVoiceTitle(voiceTime(Duration(milliseconds: draft.voiceMs))),
      );
      if (!mounted) return;
    }
    final kind = draft?.kind;
    await _writer.post(authorName: myName, at: at);
    if (!mounted) return;
    if (kind != null) {
      // Review 110 G1: the next one here opens on it.
      unawaited(
        rememberComposerKind(
          ref.read(sharedPreferencesProvider),
          _spaceId,
          kind,
        ),
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _composing(false);
    setState(() {
      _writing = false;
      _menu = null;
      _panel = null;
      _askWho = null;
      _fromBefore = false;
    });
  }

  Future<void> _save() async {
    try {
      await _editor.save();
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    if (!mounted) return;
    _stopWriting();
    await _loop.refresh();
  }

  /// A refused post that waited while another card was written: back into
  /// the Draft when the card is free, and writing reopens.
  Future<void> _reopen(PendingItem item) async {
    final moved = await ref
        .read(workOutboxProvider.notifier)
        .reopenRefused(item);
    if (!mounted || !moved) return;
    _fromBefore = true;
    _startWriting();
  }

  /// A refused walk (create_walk is all or nothing, e.g. an owner left
  /// while the phone had no signal): send it again as it is, or throw it
  /// away with its photos. It never becomes one work item's Draft.
  Future<void> _fixWalk(PendingItem item) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showBvScreenMenu<bool>(
      context,
      key: const Key('walk-refused-menu'),
      items: [
        BvMenuItem(value: true, label: l10n.commonRetry, icon: BvIcons.send),
        BvMenuItem(value: false, label: l10n.walkDiscard, icon: BvIcons.delete),
      ],
    );
    if (!mounted || picked == null) return;
    final outbox = ref.read(workOutboxProvider.notifier);
    if (picked) {
      await outbox.send(item);
    } else {
      final away = await showBvDialog(
        context: context,
        title: l10n.walkDiscardTitle,
        body: l10n.walkDiscardBody,
        cancelLabel: l10n.walkKeep,
        confirmLabel: l10n.walkDiscard,
        destructive: true,
      );
      if (!away) return;
      await outbox.discard(item);
    }
    if (mounted) await _loop.refresh();
  }

  /// The reader's open work items, due first (late first), else the
  /// oldest. A hold of the post bar's camera proves the first; the proof
  /// screen lists them all (review 47, answer 3).
  List<DaybookPost> _toProve(
    List<DaybookCard> cards,
    String? me,
    Set<String> signing,
  ) {
    final mine = [
      for (final c in cards)
        // A target (a walk) is done when its work items are checked;
        // it is never signed itself.
        if (c.post.isWorkItem &&
            !c.post.isTarget &&
            c.post.isOpen &&
            c.post.item?.ownerId == me &&
            !signing.contains(c.id))
          c.post,
    ];
    DateTime due(DaybookPost p) =>
        p.dueAt ??
        (p.dueDate == null
            ? DateTime(_farFuture)
            : p.dueDate!.add(const Duration(days: 1)));
    mine.sort((a, b) {
      final d = due(a).compareTo(due(b));
      return d != 0 ? d : a.createdAt.compareTo(b.createdAt);
    });
    return mine;
  }

  static const _farFuture = 9999;

  /// Review 110 D: writing, over the whole screen (CP1–CP5).
  Widget _composer(
    AppLocalizations l10n,
    DaybookWords words,
    DaybookPostDraft? cardDraft, {
    required bool laterBlocked,
    required String? myName,
    required String? me,
  }) {
    final kind = cardDraft?.kind ?? DaybookKind.note;
    // Review 112: alone in the Space (nobody else can own a work item),
    // a work item can't go: Post stays off and For says to invite someone.
    final people = ref.watch(spacePeopleProvider(widget.space.id)).value;
    final alone =
        !_editing &&
        kind == DaybookKind.workItem &&
        people != null &&
        people.members.isNotEmpty &&
        ownerPeople(people, me: me).isEmpty;
    final postReady =
        !alone &&
        (_editing || (cardDraft?.canPost(ref.watch(clockProvider)()) ?? false));
    final extras = composerOffered(kind, editing: _editing);
    // W11: what # offers is what this person may post; who may only thank
    // (a Viewer) has no # at all.
    final kinds = composerKindsFor(widget.space);
    final laterNote = l10n.plCantYet;
    // Review 113 (11): a new post takes a voice note; a Check-in, a report,
    // a file post and a poll (review 116) don't.
    final voice =
        !_editing &&
        kind != DaybookKind.checkIn &&
        kind != DaybookKind.report &&
        kind != DaybookKind.file &&
        kind != DaybookKind.poll;
    final bar = BvWritingToolbar.tools(
      holdsInOrder: true,
      field: _recording
          ? RecordingBar(elapsed: _elapsed, cancelling: _cancelling)
          : null,
      tools: [
        // + (CP3): what this kind can take.
        BvWritingTool(
          key: const Key('writing-add'),
          icon: BvIcons.add,
          label: l10n.daybookMore,
          outlined:
              _panel == ComposerPanel.extras || _panel == ComposerPanel.tags,
          active:
              _panel == ComposerPanel.extras || _panel == ComposerPanel.tags,
          onTap: extras.isEmpty
              ? null
              : () => _setPanel(
                  _panel == ComposerPanel.extras ? null : ComposerPanel.extras,
                ),
        ),
        // Review 109: a Check-in has no camera; review 116: a poll neither.
        if (kind != DaybookKind.checkIn && kind != DaybookKind.poll)
          BvWritingTool(
            key: const Key('writing-camera'),
            icon: BvIcons.camera,
            label: l10n.daybookCamera,
            // An edit keeps its photos (slice 5 opens a post in place).
            onTap: _editing
                ? null
                : () => unawaited(_photos(_writer.addPhoto())),
          ),
        if (voice)
          BvWritingTool(
            key: const Key('writing-mic'),
            icon: BvIcons.microphone,
            label: l10n.cpVoice,
            onTap: () => showSpaceMessage(context, l10n.notebookHoldToRecord),
            onHoldStart: () => unawaited(_startRecording()),
            onHoldMove: _slide,
            onHoldEnd: () => unawaited(_endRecording()),
          ),
      ],
      postLabel: _editing ? l10n.daybookSave : l10n.daybookPost,
      // Post turns on with what the kind can't go without (review 46);
      // what it still needs opens first.
      onPost: _editing
          ? (cardDraft?.titleFits ?? false ? _save : null)
          : (!alone && (cardDraft?.readyToTry ?? false)
                ? () => unawaited(_postOrAsk(myName))
                : null),
      // F56: grey until the "who" is chosen too; a tap asks.
      postReady: postReady,
      // CP5: hold Send for Post later, once the post could go now. V7:
      // not yet for one with Library files or a place from the list.
      laterLabel: _editing ? null : l10n.plLater,
      laterReady: !laterBlocked,
      laterNote: laterNote,
      onLater: !_editing && postReady
          ? (laterBlocked
                ? () => showSpaceMessage(context, laterNote)
                : () => unawaited(_postLater(myName)))
          : null,
    );
    final menu = _menu;
    return BvBackSwipe(
      holding: true,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_panel != null) {
            _setPanel(null);
          } else if (_menu != null) {
            _setMenu(null);
          } else {
            _stopWriting();
          }
        },
        child: DaybookComposer(
          key: ValueKey(('composer', _editing)),
          spaceId: _spaceId,
          spaceName: widget.space.name,
          words: words,
          editing: _editing,
          askWho: _askWho,
          bar: bar,
          panel: _panel,
          onPanel: _setPanel,
          kinds: kinds,
          onTemplates: _editing ? null : () => unawaited(_pickTemplate()),
          onClose: _stopWriting,
          onDiscard: _editing ? null : () => unawaited(_discardDraft()),
          onKind: (k) => unawaited(_switchKind(k)),
          onExtra: (e) => unawaited(_extra(e)),
          onMenu: _setMenu,
          onPickPeople: () => unawaited(_pickPeople()),
          onPickStart: () => unawaited(_pickStart()),
          onPickPin: () => unawaited(_pickPin()),
          onPickPinTime: () => unawaited(_pickPinTime()),
          onPickPlace: () => unawaited(_pickPlace()),
          onPickDue: () => unawaited(_pickDue()),
          onPickThanksTo: () => unawaited(_pickThanksTo()),
          onPickThanksFor: () => unawaited(_pickThanksFor()),
          onCheckIn: (p) => unawaited(_checkIn(p)),
          // Review 113 bug 7: Tap to fix's Try again sends as Post does;
          // Link folder opens the Library's, for big drawings.
          onTryAgain: _editing || alone || !(cardDraft?.readyToTry ?? false)
              ? null
              : () => unawaited(_postOrAsk(myName)),
          onLinkFolder: _editing || !widget.space.myRights.addFiles
              ? null
              : () => unawaited(_linkFolder()),
          // H3: Walk is for who may post work (a Lead or Crew).
          onWalk: _editing || !widget.space.mayPostWork
              ? null
              : () => unawaited(_walk()),
          overlay: menu == null
              ? null
              : Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        // No dim: a tap anywhere else closes it (E2).
                        Positioned.fill(
                          child: GestureDetector(
                            key: const Key('writing-menu-away'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _setMenu(null),
                          ),
                        ),
                        PositionedDirectional(
                          start: BvPopoverMenuSpec.writingStart,
                          bottom: BvPopoverMenuSpec.writingGap,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.max(
                                0,
                                constraints.maxHeight -
                                    2 * BvPopoverMenuSpec.writingGap,
                              ),
                            ),
                            child: DaybookWritingPopover(
                              key: ValueKey((menu, _editing)),
                              spaceId: _spaceId,
                              menu: menu,
                              me: me,
                              editing: _editing,
                              onMenu: _setMenu,
                              onPickDue: _pickDue,
                              onPickPin: () => unawaited(_pickPin()),
                              onPickStart: () => unawaited(_pickStart()),
                              onPickFile: () => unawaited(_pickFile()),
                              onClose: () => _setMenu(null),
                              onAssigned: _assigned,
                              onPickPeople: () => unawaited(_pickPeople()),
                              onPickPlace: () => unawaited(_pickPlace()),
                              onPickTemplate: () => unawaited(_pickTemplate()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final now = ref.watch(clockProvider)();
    final today = dayOf(now);
    final me = ref.watch(authUserIdProvider).value;
    final space = widget.space;
    // A refused check, send-back or cancel says why; the page has read
    // again (review 47, answer 5).
    ref.listen(refusalsProvider, (_, r) {
      if (r == null || r.spaceId != _spaceId) return;
      showSpaceMessage(
        context,
        DaybookLoop.refusalText(
          l10n,
          r,
          ref.read(daybookCardsProvider(_spaceId)).value ?? const [],
        ),
      );
    });
    // A push about this Space while it's open: read again (F11).
    ref.listen(pushArrivalProvider, (_, push) {
      if (push?.spaceId == _spaceId) unawaited(_refresh());
    });
    ref.listen(daybookCardsProvider(_spaceId), (was, now) {
      final value = now.value;
      if (now.hasValue && value != null) {
        _keepPlace(_movedOn(was?.value, value));
      }
    });
    // Something done here moves its card to Now at once, too.
    ref.listen(workOutboxProvider, (was, now) {
      final known = {for (final i in was ?? const <PendingItem>[]) i.id};
      _keepPlace({
        for (final i in now)
          if (i.spaceId == _spaceId && !known.contains(i.id)) i.id,
      });
    });
    final canPost = space.myRights.createItems;
    // Founder, 1 Nov: who may not post work may still thank, so may write.
    final canWrite = composerKindsFor(space).isNotEmpty;
    final page = ref.watch(daybookCardsProvider(_spaceId));
    final dueToday =
        ref.watch(daybookDueTodayProvider(_spaceId)).value ??
        const <CalendarWorkItem>[];
    final draft = ref.watch(daybookDraftProvider(_spaceId));
    final edit = ref.watch(daybookEditProvider(_spaceId));
    // Post later's go to the server, never to the page (review 108 PL1).
    final pending = [
      for (final i in ref.watch(workOutboxProvider))
        if (i.spaceId == _spaceId && i.scheduleAt == null) i,
    ];
    // Review 108 PL2: "{n} scheduled", mine waiting to go out here.
    final scheduledHere = [
      for (final p in ref.watch(myScheduledProvider).value ?? const [])
        if (p.spaceId == _spaceId && p.state == ScheduledState.waiting) p,
    ].length;
    final myName = ref
        .watch(spacePeopleProvider(_spaceId))
        .value
        ?.member(me ?? '')
        ?.person
        .fullName;
    final card =
        canWrite && (_writing || _editing || (draft != null && !draft.isEmpty));
    final signing = {
      for (final i in pending)
        if (i.kind == PendingKind.signOff) i.id,
    };
    final cards = page.value ?? const <DaybookCard>[];
    final pinned = _pinned(cards, now);
    final mine = _mine(pinned);
    // F38: the strip is what the reader still has to do. An item leaves it
    // once it is signed as done (on the phone or on the page), and comes
    // back when it is sent back (Open again).
    final signed = {
      for (final i in pending)
        if (i.kind == PendingKind.signOff && !i.refused) i.id,
    };
    final onPage = {
      for (final c in cards)
        if (c.post.isWorkItem) c.id: c.post,
    };
    final due = [
      for (final i in dueToday)
        if (!signed.contains(i.postId) && (onPage[i.postId]?.isOpen ?? true)) i,
    ];
    // Review 105 Part 6: what waits on me, here and in what's due, and
    // what of it is due today.
    final waiting = {
      for (final c in cards)
        if (c.need != null &&
            !signed.contains(c.id) &&
            !c.post.cancelled &&
            // Signed as done, it waits on the checker, not on me.
            (c.need == DaybookNeed.toCheck || c.post.isOpen))
          c.id,
      for (final i in due) i.postId,
    };
    final dueNow = due.where((i) => i.day == today).length;
    if (waiting.isEmpty && _needsMine) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _needsMine = false);
      });
    }
    if (_target != null && page.hasValue && !_revealing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_reveal()));
    }

    // Review 105C: Work for one place, said by a chip with ✕.
    final place = ref.watch(workPlaceFilterProvider(_spaceId));
    final tag = ref.watch(workTagFilterProvider(_spaceId));
    final shown = _shownDay ?? today;
    // Any new post waiting to send keeps the first page away: a work
    // item, another kind, a walk.
    final waitingPosts = [
      for (final i in pending)
        if (i.isNewPost) i,
    ];
    final body = switch (page) {
      AsyncData(:final value)
          when value.isEmpty && !card && waitingPosts.isEmpty =>
        RefreshIndicator(
          onRefresh: _refresh,
          child: _FirstPage(
            space: space,
            canPost: canPost,
            onPost: _startWriting,
          ),
        ),
      AsyncData(:final value) => _diary(
        value,
        pending,
        words,
        me: me,
        myName: myName,
        now: now,
        card: card,
        signing: signing,
        only: _shownOnly(cards, place, _needsMine ? waiting : null, tag: tag),
      ),
      // Pull down to try again.
      AsyncError() => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          children: [EmptyNote(l10n.errorGeneric)],
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
    _openItems = canPost ? _toProve(cards, me, signing) : const [];
    final cardDraft = _editing ? edit : draft;
    // W7: a Thanks can be scheduled too.
    // Review 116: a poll goes now only (no scheduled create_poll yet).
    final laterBlocked =
        cardDraft != null &&
        (cardDraft.kind == DaybookKind.poll ||
            (cardDraft.kind == DaybookKind.workItem &&
                (cardDraft.files.isNotEmpty || cardDraft.placeId != null)));
    // At Now, and while writing, the masthead reads Today (F59); away from
    // Now it follows the day at the top of the page (F23).
    final atToday = _writing || !_wasAway || shown == today;
    final day = atToday ? today : shown;

    if (_writing && canWrite) {
      return _composer(
        l10n,
        words,
        cardDraft,
        laterBlocked: laterBlocked,
        myName: myName,
        me: me,
      );
    }

    // Review 100 B6: an iPhone's swipe from the edge does what ← does,
    // also while this screen holds Back for itself.
    final selected = ref.watch(workSelectionProvider(_spaceId));
    final selecting = selected.isNotEmpty && !_writing;
    final work = BvBackSwipe(
      holding: _writing || selecting,
      child: PopScope(
        canPop: !_writing && !selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (selecting) {
            ref.read(workSelectionProvider(_spaceId).notifier).clear();
          } else {
            _menu != null ? _setMenu(null) : _stopWriting();
          }
        },
        child: ColoredBox(
          color: BvColors.surfaceApp,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (place != null && !_writing)
                Padding(
                  padding: BvPlaceFilterSpec.outer,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BvFilterChip(
                      key: const Key('place-filter'),
                      icon: BvIcons.place,
                      label: place.name,
                      clearLabel: l10n.daybookPlaceFilterClear,
                      clearKey: const Key('place-filter-clear'),
                      onClear: ref
                          .read(workPlaceFilterProvider(_spaceId).notifier)
                          .clear,
                    ),
                  ),
                ),
              // Review 110 TG1: Work for one tag, said the same way.
              if (tag != null && !_writing)
                Padding(
                  padding: BvPlaceFilterSpec.outer,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BvFilterChip(
                      key: const Key('tag-filter'),
                      icon: BvIcons.tag,
                      label: tag.nameIn(
                        Localizations.localeOf(context).languageCode,
                      ),
                      danger: tag.danger,
                      clearLabel: l10n.daybookTagFilterClear,
                      clearKey: const Key('tag-filter-clear'),
                      onClear: ref
                          .read(workTagFilterProvider(_spaceId).notifier)
                          .clear,
                    ),
                  ),
                ),
              BvDaybookMasthead(
                key: _mastheadKey,
                weekday: atToday
                    ? l10n.daybookTodayDivider
                    : words.weekday(day),
                date: atToday
                    ? l10n.daybookMastheadToday(words.compactDate(today))
                    : words.dayMonth(day),
                onTap: _writing ? null : () => _openMonth(today, shown),
              ),
              // OF: the last try to reach the server failed for want of a
              // signal; it goes as soon as something gets through.
              if (!ref.watch(signalProvider))
                BvNoSignalStrip(
                  key: const Key('no-signal'),
                  text: l10n.noSignalStrip,
                ),
              // Review 105 Part 6: "3 need you · 2 due today ›"; a tap shows
              // only what waits on me, again everything.
              if (waiting.isNotEmpty && !_writing)
                Padding(
                  padding: BvNeedsYouSpec.outer,
                  child: BvNeedsYouLine(
                    key: const Key('needs-you'),
                    need: l10n.daybookNeedYou(waiting.length),
                    due: dueNow == 0 ? null : l10n.daybookNeedYouDue(dueNow),
                    on: _needsMine,
                    offLabel: l10n.daybookNeedYouShowAll,
                    onTap: () => unawaited(_toggleNeedsMine(waiting)),
                  ),
                ),
              // Pinned announcements stay under the masthead while pinned
              // (K1 v13), whatever their last activity.
              if (!_writing)
                for (final p in pinned)
                  Padding(
                    padding: BvPinnedSpec.outer,
                    child: _pinnedNote(p, words, cards, me: me, now: now),
                  ),
              // Review 105B: mine, under the Space's; at most 3 (L9).
              if (!_writing) ...[
                for (final p in mine.take(_myPinsShown))
                  Padding(
                    padding: BvPinnedSpec.outer,
                    child: _myPin(p, me: me),
                  ),
                if (mine.length > _myPinsShown)
                  Padding(
                    padding: BvPinnedSpec.outer,
                    child: _myPinsMore(
                      mine.skip(_myPinsShown).toList(),
                      me: me,
                    ),
                  ),
              ],
              Expanded(
                key: _viewportKey,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Positioned.fill(child: body),
                      if (_newBelow && !_writing)
                        PositionedDirectional(
                          start: 0,
                          end: 0,
                          bottom: BvNewChipSpec.offset,
                          child: Center(
                            child: BvNewChip(
                              key: const Key('daybook-new'),
                              label: l10n.daybookNew,
                              onTap: _toNow,
                            ),
                          ),
                        )
                      // Up in older days: back to Today (F59).
                      else if (_wasAway && !_writing)
                        PositionedDirectional(
                          start: 0,
                          end: 0,
                          bottom: BvNewChipSpec.offset,
                          child: Center(
                            child: BvNewChip(
                              key: const Key('daybook-today'),
                              label: l10n.daybookTodayDivider,
                              onTap: _toNow,
                            ),
                          ),
                        ),
                      if (_menu != null) ...[
                        // No dim: a tap anywhere else closes it (E2).
                        Positioned.fill(
                          child: GestureDetector(
                            key: const Key('writing-menu-away'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _setMenu(null),
                          ),
                        ),
                        PositionedDirectional(
                          start: BvPopoverMenuSpec.writingStart,
                          bottom: BvPopoverMenuSpec.writingGap,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.max(
                                0,
                                constraints.maxHeight -
                                    2 * BvPopoverMenuSpec.writingGap,
                              ),
                            ),
                            child: DaybookWritingPopover(
                              key: ValueKey((_menu, _editing)),
                              spaceId: _spaceId,
                              menu: _menu!,
                              me: me,
                              editing: _editing,
                              onMenu: _setMenu,
                              onPickDue: _pickDue,
                              onPickPin: () => unawaited(_pickPin()),
                              onPickStart: () => unawaited(_pickStart()),
                              onPickFile: () => unawaited(_pickFile()),
                              onClose: () => _setMenu(null),
                              onAssigned: _assigned,
                              onPickPeople: () => unawaited(_pickPeople()),
                              onPickPlace: () => unawaited(_pickPlace()),
                              onPickTemplate: () => unawaited(_pickTemplate()),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Review 105 SP6: while cards are held, what can be done with
              // them takes the post bar's place.
              if (selecting)
                _selectionBar(
                  [for (final c in cards) c.post, ...pinned, ...mine],
                  selected,
                  me: me,
                  spacePinned: {for (final p in pinned) p.id},
                )
              else if (!canPost)
                BvPostBar.viewer(
                  passLabel: passName(l10n, space.myPass),
                  passTone: passTone(space.myPass),
                  // "Read only" is a Viewer's; a locked Crew pass is just
                  // the pass (review 67, V1).
                  readOnly: space.myPass == SpacePass.viewer
                      ? l10n.daybookReadOnly
                      : null,
                  // Founder, 1 Nov: they may thank, and only thank.
                  thankLabel: l10n.thanksSomeone,
                  onThank: () => _startWriting(kind: DaybookKind.thanks),
                )
              // A Draft on the page takes the post bar's place until it is
              // posted or emptied (E4).
              else if (!card) ...[
                if (scheduledHere > 0) ScheduledLine(count: scheduledHere),
                BvPostBar(
                  // Review 105 J4 (SP1).
                  placeholder: l10n.daybookWriteInSpace,
                  onWrite: _startWriting,
                  cameraLabel: l10n.daybookCameraLabel,
                  // Review 107 OB7: the first tip points here.
                  cameraAnchor: FirstRunTip.camera,
                  // The camera, with Photo · Walk at its bottom (the lead's
                  // rulings on 105A). Nothing on a hold: Sign as done is on
                  // the work item (H1).
                  onCamera: () => unawaited(_camera()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    // Review 107 OB7: the first-run tips, over Work: the camera and holding
    // a card for who may post, Sign as done for who may sign (Q4).
    final rights = space.myRights;
    return FirstRunTips(
      tips: [
        if (rights.createItems) ...[FirstRunTip.camera, FirstRunTip.hold],
        if (rights.markDone) FirstRunTip.signDone,
      ],
      child: work,
    );
  }

  /// The bottom bar while cards are held (review 113 (14, 16); the lead's
  /// check of 115): only what I may do on them, in this order. Pin, or
  /// Unpin for my pins (mine only, from 105B); Reminder for one held post;
  /// Stop for one repeating Check-in I may stop; then, last and in red,
  /// Archive (once someone acted on my post, or a Lead's on a Checked item)
  /// or Delete (my post while nobody has acted on it). The server says
  /// which ("hold", "can_stop"). Share is on every card; Duplicate is gone.
  /// No Move: work stays in its Space (rule 8).
  Widget _selectionBar(
    List<DaybookPost> shown,
    Set<String> selected, {
    required String? me,
    required Set<String> spacePinned,
  }) {
    final l10n = AppLocalizations.of(context);
    final later = ref.watch(workLaterProvider);
    final lead = widget.space.myPass == SpacePass.lead;
    final posts = {
      for (final p in shown)
        if (selected.contains(p.id)) p.id: p,
    }.values.toList();
    final deletes =
        posts.isNotEmpty && posts.every((p) => p.hold == PostHold.delete);
    final archives =
        posts.isNotEmpty &&
        posts.every(
          (p) =>
              mayArchiveHeld(p, lead: lead, archiveOn: later.archive != null),
        );
    final stop =
        posts.length == 1 &&
        posts.single.isCheckIn &&
        (posts.single.checkIn?.canStop ?? false);
    // Review 116: Close poll, for its creator or a Space admin, while open.
    final closePoll =
        posts.length == 1 &&
        posts.single.isPoll &&
        !(posts.single.poll?.isClosed(ref.read(clockProvider)()) ?? true) &&
        _loop.mayRunPoll(posts.single, me: me);
    // L9: held, my pinned ones can be unpinned here; ones not pinned,
    // pinned. Not an announcement pinned for the Space: it shows at the top
    // already.
    final mineIds = _mineIds();
    // The lead, 4 Nov: Pin and Reminder are for one held card; with
    // several, only what every one of them allows (Archive or Delete).
    final pinOn =
        later.pin != null &&
        posts.length == 1 &&
        posts.every((p) => !spacePinned.contains(p.id));
    final toPin = pinOn && posts.every((p) => !mineIds.contains(p.id));
    final toUnpin = pinOn && posts.every((p) => mineIds.contains(p.id));
    final remind = posts.length == 1 ? posts.single : null;
    final reminded =
        remind != null &&
        ref.watch(spaceRemindersProvider)[spaceReminderId(
              _spaceId,
              remind.id,
            )] !=
            null;
    return SelectionBar(
      actions: [
        if (toPin)
          SelectionAction(
            key: const Key('select-pin'),
            icon: BvIcons.pin,
            label: l10n.workPin,
            onTap: () {
              _endSelection();
              unawaited(_pinAll(posts));
            },
          ),
        if (toUnpin)
          SelectionAction(
            key: const Key('select-unpin'),
            icon: BvIcons.pin,
            label: l10n.workUnpin,
            onTap: () {
              _endSelection();
              unawaited(_unpinAll(posts));
            },
          ),
        if (remind != null)
          SelectionAction(
            key: const Key('select-remind'),
            icon: BvIcons.remind,
            label: reminded ? l10n.workChangeReminder : l10n.workReminder,
            onTap: () {
              _endSelection();
              unawaited(_remind(remind));
            },
          ),
        if (stop)
          SelectionAction(
            key: const Key('select-stop'),
            icon: BvIcons.stop,
            label: l10n.checkInStop,
            destructive: true,
            onTap: () => unawaited(_stop(posts.single)),
          ),
        if (closePoll)
          SelectionAction(
            key: const Key('select-close-poll'),
            icon: BvIcons.lock,
            label: l10n.pollClose,
            onTap: () => unawaited(_closePoll(posts.single)),
          ),
        // Hidden, not greyed, when one held can't be archived or deleted
        // (H4). Last, in red.
        if (archives)
          SelectionAction(
            key: const Key('select-archive'),
            icon: BvIcons.archive,
            label: l10n.workArchive,
            destructive: true,
            onTap: () => unawaited(_archiveHeld(posts)),
          ),
        if (deletes)
          SelectionAction(
            key: const Key('select-delete'),
            icon: BvIcons.delete,
            label: l10n.delete,
            destructive: true,
            onTap: () => unawaited(_delete(posts)),
          ),
      ],
    );
  }

  void _endSelection() =>
      ref.read(workSelectionProvider(_spaceId).notifier).clear();

  /// Archive (review 113 (16)): it leaves the daily view and stays in the
  /// record. An open work item asks first: archiving stops it, and its
  /// owner is told it's no longer needed. Then "Archived · Undo".
  Future<void> _archiveHeld(List<DaybookPost> posts) async {
    final l10n = AppLocalizations.of(context);
    final open = posts.where((p) => p.isWorkItem && p.isOpen).toList();
    if (open.isNotEmpty) {
      final owner = open.first.item?.ownerName;
      final sure = await showBvDialog(
        context: context,
        title: l10n.holdArchiveOpenTitle,
        body: l10n.holdArchiveOpenBody(personName(l10n, owner)),
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.workArchive,
      );
      if (!sure || !mounted) return;
    }
    _endSelection();
    final repository = ref.read(daybookRepositoryProvider);
    final done = <DaybookPost>[];
    for (final p in posts) {
      try {
        await repository.archivePost(p.id);
        done.add(p);
      } on SpaceException catch (e) {
        if (mounted) showSpaceError(context, e);
      }
    }
    if (!mounted) return;
    if (done.isNotEmpty) {
      showBvUndoBar(
        context,
        message: l10n.workArchived,
        actionLabel: l10n.daybookUndo,
        onAction: () => unawaited(_unarchiveAll(done)),
      );
    }
    await _loop.refresh();
  }

  Future<void> _unarchiveAll(List<DaybookPost> posts) async {
    for (final p in posts) {
      await _unarchive(p);
      if (!mounted) return;
    }
  }

  /// Stop (review 113): a repeating Check-in, asked first, as on its list.
  Future<void> _stop(DaybookPost post) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showBvDialog(
      context: context,
      title: l10n.checkInStopTitle,
      body: l10n.checkInStopBody,
      cancelLabel: l10n.checkInKeep,
      confirmLabel: l10n.checkInStop,
      destructive: true,
    );
    if (!yes || !mounted) return;
    _endSelection();
    try {
      await ref.read(checkInRepositoryProvider).stop(post.id);
    } on SpaceException catch (e) {
      if (mounted) {
        showSpaceMessage(
          context,
          checkInRefusalText(l10n, CheckInRefusal.of(e)),
        );
      }
      return;
    }
    if (mounted) showSpaceMessage(context, l10n.checkInStoppedDone);
    await _loop.refresh();
  }

  /// Close poll (review 116 PL3), asked once: nobody votes after it.
  Future<void> _closePoll(DaybookPost post) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showBvDialog(
      context: context,
      title: l10n.pollCloseTitle,
      body: l10n.pollCloseBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.pollClose,
    );
    if (!yes || !mounted) return;
    _endSelection();
    await _loop.closePoll(context, post);
  }

  /// Delete (SP6), asked first: each is gone from Work for everyone. The
  /// server keeps one someone else has added to; that one is cancelled
  /// instead, by its author, from the opened item.
  Future<void> _delete(List<DaybookPost> posts) async {
    final l10n = AppLocalizations.of(context);
    final sure = await showBvDialog(
      context: context,
      title: l10n.daybookDeleteTitle(posts.length),
      body: l10n.daybookDeleteBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!sure || !mounted) return;
    _endSelection();
    final repository = ref.read(daybookRepositoryProvider);
    // Every one is tried; what failed is said after (H5).
    var kept = 0;
    final failed = <DaybookPost>[];
    for (final p in posts) {
      try {
        await repository.deletePost(p.id);
      } on SpaceException catch (e) {
        // Review 113: the server keeps a post someone has acted on.
        if (e.failure == SpaceFailure.rule || isActedOn(e)) {
          kept++;
        } else {
          failed.add(p);
        }
      }
    }
    if (!mounted) return;
    if (failed.isNotEmpty) {
      showSpaceMessage(
        context,
        l10n.daybookDeleteFailed(joinMeta(failed.map((p) => p.title))),
      );
    } else if (kept > 0) {
      showSpaceMessage(context, l10n.holdDeleteActed);
    }
    await _loop.refresh();
  }

  /// Review 105B: the posts I pinned (mine only): what daybook_extras says
  /// and any card pinned by me on the page.
  Set<String> _mineIds() => {
    for (final p
        in ref.watch(daybookExtrasProvider(_spaceId)).value?.mine ??
            const <DaybookPost>[])
      p.id,
    for (final c
        in ref.watch(daybookCardsProvider(_spaceId)).value ??
            const <DaybookCard>[])
      if (c.pinnedByMe) c.id,
  };

  /// My pinned posts at the top of Work (review 105B), as slim lines,
  /// leaving out an announcement already pinned for the Space.
  List<DaybookPost> _mine(List<DaybookPost> spacePinned) {
    final extras = ref.watch(daybookExtrasProvider(_spaceId)).value;
    final cards =
        ref.watch(daybookCardsProvider(_spaceId)).value ??
        const <DaybookCard>[];
    final shown = {for (final p in spacePinned) p.id};
    final byId = <String, DaybookPost>{
      for (final p in extras?.mine ?? const <DaybookPost>[]) p.id: p,
      for (final c in cards)
        if (c.pinnedByMe) c.id: c.post,
    };
    return [
      for (final p in byId.values)
        if (!shown.contains(p.id)) p,
    ];
  }

  /// Pin or Unpin for me (review 105B), then Work read again.
  Future<void> _pin(DaybookPost post, {required bool on}) async {
    final pin = ref.read(workLaterProvider).pin;
    if (pin == null) return;
    try {
      await pin(post, on: on);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    ref.invalidate(daybookExtrasProvider(_spaceId));
    await _loop.refresh();
  }

  Future<void> _pinAll(List<DaybookPost> posts) async {
    for (final p in posts) {
      await _pin(p, on: true);
      if (!mounted) return;
    }
  }

  Future<void> _unpinAll(List<DaybookPost> posts) async {
    for (final p in posts) {
      await _pin(p, on: false);
      if (!mounted) return;
    }
  }

  Future<void> _unarchive(DaybookPost post) async {
    try {
      await ref.read(daybookRepositoryProvider).unarchivePost(post.id);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    await _loop.refresh();
  }

  /// My pinned line's tap (review 105B): the item opens as from its card,
  /// with what I may do there.
  Future<void> _openMine(DaybookPost post, {required String? me}) async {
    if (!post.isWorkItem) return _loop.openPinned(context, post, me: me);
    DaybookCard? card =
        (ref.read(daybookCardsProvider(_spaceId)).value ??
                const <DaybookCard>[])
            .where((c) => c.id == post.id)
            .firstOrNull;
    try {
      card ??= await ref.read(daybookRepositoryProvider).card(post.id);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    if (card == null || !mounted) return;
    await _openCard(card, me: me);
  }

  /// [card]'s page, as a tap on it opens it.
  Future<void> _openCard(DaybookCard card, {required String? me}) async {
    final l10n = AppLocalizations.of(context);
    final view = DaybookCardView(
      spaceId: _spaceId,
      card: card,
      words: DaybookWords(
        l10n,
        Localizations.localeOf(context).toLanguageTag(),
        use24: MediaQuery.alwaysUse24HourFormatOf(context),
      ),
      me: me,
      now: ref.read(clockProvider)(),
      activityAt: card.lastActivityAt,
    );
    await showDaybookPage(
      context,
      space: widget.space,
      post: card.post,
      actions: _loop.pageActions(context, view, me: me),
    );
  }

  /// One of my pinned posts under the masthead: its title; a tap opens it,
  /// a hold selects it.
  Widget _myPin(DaybookPost post, {required String? me}) {
    final selection = ref.watch(workSelectionProvider(_spaceId));
    void hold() {
      unawaited(HapticFeedback.selectionClick());
      ref.read(workSelectionProvider(_spaceId).notifier).toggle(post.id);
    }

    return BvPinnedLine(
      key: Key('my-pin-${post.id}'),
      text: post.title,
      onTap: selection.isNotEmpty
          ? hold
          : () => unawaited(_openMine(post, me: me)),
      onLongPress: hold,
      selected: selection.contains(post.id),
    );
  }

  /// My pins shown at the top (L9); the rest open from "+n more".
  static const _myPinsShown = 3;

  /// "+n more" under my first pins: the rest, on a sheet; a tap opens one.
  Widget _myPinsMore(List<DaybookPost> rest, {required String? me}) {
    final l10n = AppLocalizations.of(context);
    return BvPinnedLine(
      key: const Key('my-pins-more'),
      text: l10n.workPinsMore(rest.length),
      onTap: () => unawaited(
        showBvSheet<void>(
          context: context,
          builder: (sheet) => Column(
            key: const Key('my-pins-sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in rest)
                Padding(
                  padding: BvPinnedSpec.outer,
                  child: BvPinnedLine(
                    key: Key('my-pin-${p.id}'),
                    text: p.title,
                    onTap: () {
                      Navigator.of(sheet).pop();
                      unawaited(_openMine(p, me: me));
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reminder (SP5; review 108 RM1): the Reminder sheet, Me · Someone. Me
  /// is the phone's own notification; Someone, the server's, for the
  /// item's creator, its owner or a Lead.
  Future<void> _remind(DaybookPost post) async {
    final message = await showReminderSheet(
      context,
      space: widget.space,
      post: post,
    );
    if (!mounted || message == null) return;
    showSpaceMessage(context, message);
  }

  /// The announcements pinned now (K1 v13): what daybook_extras says, and
  /// any pinned card on the page (it may be newer), newest first.
  List<DaybookPost> _pinned(List<DaybookCard> cards, DateTime now) {
    final extras = ref.watch(daybookExtrasProvider(_spaceId)).value;
    final byId = <String, DaybookPost>{
      for (final p in extras?.pinned ?? const <DaybookPost>[])
        if (p.pinnedAt(now)) p.id: p,
      for (final c in cards)
        if (c.post.pinnedAt(now)) c.id: c.post,
    };
    final pinned = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _unpinAt(pinned, now);
    return pinned;
  }

  /// F82: the first pin to end comes down by itself at its time, with no
  /// reload (a pin to 2 pm is gone at 2 pm).
  Timer? _unpin;

  void _unpinAt(List<DaybookPost> pinned, DateTime now) {
    _unpin?.cancel();
    _unpin = null;
    final first = pinned
        .map((p) => p.pinnedUntil!)
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    if (first == null) return;
    final wait = first.difference(now);
    // A pin ending days away is read again long before then.
    if (wait > _unpinFarthest) return;
    _unpin = Timer(wait + _unpinMargin, () {
      if (mounted) setState(() {});
    });
  }

  static const _unpinFarthest = Duration(days: 1);
  static const _unpinMargin = Duration(seconds: 1);

  /// [post]'s own acknowledgements with what the phone gave or took back
  /// that waits for the server.
  Set<DaybookAck> _acksOf(DaybookPost post, List<DaybookMark> marks) => {
    for (final a in post.myAcks)
      if (!marks.any((m) => m.postId == post.id && m.ack == a && !m.on)) a,
    for (final m in marks)
      if (m.postId == post.id && m.ack != null && m.on) m.ack!,
  };

  /// A pinned announcement under the masthead: who wrote it and for whom,
  /// until when, its words, Got it for the reader, and for its author the
  /// faces of who got it.
  ///
  /// Review 61 G1: after Got it it folds to one slim line, and its author
  /// sees the slim line from the start; a tap opens it in full (Got it
  /// shown as given), a tap on the full one folds it again. Edited since
  /// the reader's Got it, it opens in full until they give Got it again.
  /// The time of the Got it is the server's `my_ack_at` (migration 29),
  /// else the reader's own history line on the card; with neither the
  /// edit can't be compared, and it stays folded.
  Widget _pinnedNote(
    DaybookPost post,
    DaybookWords words,
    List<DaybookCard> cards, {
    required String? me,
    required DateTime now,
  }) {
    final l10n = AppLocalizations.of(context);
    final marks = ref.watch(daybookMarksProvider);
    var shown = post.shownAs(myAcks: _acksOf(post, marks));
    final given = shown.myAcks.contains(DaybookAck.gotIt);
    final givenAt =
        marks
            .where(
              (m) => m.postId == post.id && m.ack == DaybookAck.gotIt && m.on,
            )
            .lastOrNull
            ?.at ??
        post.myAckAt[DaybookAck.gotIt] ??
        cards
            .where((c) => c.id == post.id)
            .firstOrNull
            ?.history
            .where((e) => e.kind == DaybookEventKind.gotIt && e.byId == me)
            .firstOrNull
            ?.at;
    final edited = post.editedAt;
    final editedSince =
        given && edited != null && givenAt != null && edited.isAfter(givenAt);
    if (editedSince) {
      // Got it again: the edit is new to them.
      shown = shown.shownAs(
        myAcks: shown.myAcks.difference(const {DaybookAck.gotIt}),
      );
    }
    final folds =
        (post.authorId != null && post.authorId == me) ||
        (given && !editedSince);
    // H2: Work's one language. A tap opens it as an item (its Unpin · Save
    // as template · Cancel on ⋯), a hold selects it; folding is its own
    // chevron.
    final selection = ref.watch(workSelectionProvider(_spaceId));
    final held = selection.contains(post.id);
    void hold() {
      unawaited(HapticFeedback.selectionClick());
      ref.read(workSelectionProvider(_spaceId).notifier).toggle(post.id);
    }

    void open() => selection.isNotEmpty
        ? hold()
        : unawaited(_loop.openPinned(context, post, me: me));
    if (folds && !_openPinned.contains(post.id)) {
      // F104: its author sees who got it on the folded line too, live (a
      // broadcast reads postAcksProvider again). Nobody else sees others'.
      final gotBy = _loop.actsFor(post, me: me)
          ? acknowledgedBy(ref, post.id, DaybookAck.gotIt)
          : const <DaybookPerson>[];
      return BvPinnedLine(
        key: Key('pinned-line-${post.id}'),
        text: post.title,
        // F85: the end shows folded too.
        until: l10n.daybookPinnedLineUntil(
          words.pinnedDay(post.pinnedUntil!, now),
        ),
        faces: gotBy.isEmpty
            ? null
            : DaybookFacesLine(
                key: Key('pinned-line-faces-${post.id}'),
                faces: facesOf(l10n, gotBy),
              ),
        onTap: open,
        onLongPress: hold,
        onFold: () => setState(() => _openPinned.add(post.id)),
        selected: held,
      );
    }
    final team = post.teamId == null
        ? null
        : ref
              .watch(spacePeopleProvider(_spaceId))
              .value
              ?.teams
              .where((t) => t.id == post.teamId)
              .firstOrNull
              ?.name;
    final by = acknowledgedBy(ref, post.id, DaybookAck.gotIt);
    return BvPinnedNote(
      key: Key('pinned-${post.id}'),
      onTap: open,
      onLongPress: hold,
      selected: held,
      author: post.authorId != null && post.authorId == me
          ? l10n.daybookYou
          : personName(l10n, post.authorName),
      audience: team == null
          ? l10n.daybookToEveryone
          : l10n.daybookToTeam(team),
      // F85: the header ends with when it was posted; how long it lasts
      // is the facts line under the title, in ink on its last day.
      time: words.ackTime(post.createdAt, now),
      until: words.pinnedUntil(post.pinnedUntil!, now),
      untilToday: dayOf(pinnedLastDay(post.pinnedUntil!)) == dayOf(now),
      title: post.title,
      body: post.body,
      // F83: the message it was made from, opening it (F87).
      quote: post.quote == null
          ? null
          : BvQuoteBlock(
              key: const Key('pinned-quote'),
              from: words.quoteFrom(post.quote!, now),
              text: post.quote!.text,
              onTap: post.sourceMessageId == null
                  ? null
                  : () => unawaited(
                      _loop.openQuote(context, post.sourceMessageId!),
                    ),
            ),
      // F48: the author's faces of who got it; a tap lists them with times.
      leading: by.isEmpty
          ? null
          : DaybookFacesLine(
              key: const Key('got-it-by'),
              faces: facesOf(l10n, by),
              onTap: () => showDaybookAcks(
                context,
                title: l10n.daybookGotIt,
                faces: acksOf(ref, post.id, DaybookAck.gotIt),
                now: now,
              ),
            ),
      onFold: folds ? () => setState(() => _openPinned.remove(post.id)) : null,
      action: daybookAckAction(
        l10n,
        shown,
        me: me,
        now: now,
        onAck: (kind, {required on}) {
          // Given now: it folds.
          if (on) setState(() => _openPinned.remove(post.id));
          unawaited(
            _loop.acknowledge(context, shown, kind, on: on, again: editedSince),
          );
        },
      ),
    );
  }

  /// A post still in the outbox, as its card at the time Post was tapped.
  DaybookPost _waitingPost(PendingItem i, String? me, DateTime now) {
    final d = i.draft;
    if (d != null) return _waitingKind(i, d, me, now);
    if (i.kind == PendingKind.walk) return _waitingWalk(i, me, now);
    return DaybookPost(
      id: i.id,
      kind: DaybookPost.workItemKind,
      createdAt: i.madeAt ?? now,
      title: i.title,
      authorId: me,
      authorName: i.authorName,
      place: i.place,
      dueDate: i.dueDate,
      dueAt: i.dueAt,
      item: DaybookItem(
        status: WorkStatus.open,
        ownerId: i.ownerId,
        ownerName: i.ownerName,
      ),
      // The words it quotes show while it waits, as once it is sent.
      quote: i.quote,
    );
  }

  /// A walk in the outbox: its card, a row per photo, the photos the
  /// phone's own until they are up.
  DaybookPost _waitingWalk(PendingItem i, String? me, DateTime now) =>
      DaybookPost(
        id: i.id,
        kind: DaybookPost.workItemKind,
        createdAt: i.madeAt ?? now,
        title: i.title,
        authorId: me,
        authorName: i.authorName,
        place: i.place,
        item: DaybookItem(
          status: WorkStatus.open,
          ownerId: me,
          ownerName: i.authorName,
        ),
        children: DaybookChildren(
          total: i.walk.length,
          checked: 0,
          target: true,
          rows: [
            for (final (n, w) in i.walk.indexed)
              DaybookChild(
                id: w.id,
                title: w.line,
                ownerId: w.ownerId,
                ownerName: w.ownerName,
                coverPath: n < i.photos.length ? i.photos[n].local : null,
              ),
          ],
        ),
      );

  /// A checklist, an announcement, an activity or a file post in the
  /// outbox, from the card as it was written.
  DaybookPost _waitingKind(
    PendingItem i,
    DaybookPostDraft d,
    String? me,
    DateTime now,
  ) {
    final file = i.files.firstOrNull;
    final title = d.title.trim();
    return DaybookPost(
      id: i.id,
      kind: d.kind.json,
      createdAt: i.madeAt ?? now,
      title: title.isEmpty && file != null ? file.name : title,
      body: d.body.trim().isEmpty ? null : d.body.trim(),
      authorId: me,
      authorName: i.authorName,
      place: d.place,
      dueDate: d.dueDate,
      dueAt: d.dueAt,
      pointsTotal: d.writtenPoints.length,
      people: [for (final p in d.people) DaybookPerson(id: p.id, name: p.name)],
      pinnedUntil: d.pinnedUntil,
      startsAt: d.startsAt,
      endsAt: d.endsAt,
      file: file == null
          ? null
          : DaybookFile(
              id: file.libraryId,
              name: file.name,
              mime: file.mime,
              bytes: file.bytes,
              revLabel: file.revLabel,
              replacesRev: file.supersedesRev,
              replacesName: file.supersedesRev,
            ),
      newVersion: file?.supersedesId != null,
      quote: d.quote,
      // Review 109: a Check-in waits with its times; nothing to mark yet.
      checkIn: d.kind == DaybookKind.checkIn && d.inTime != null
          ? CheckInSetup(
              inTime: d.inTime!,
              inAllow: d.inAllow,
              outTime: d.outTime,
              outAllow: d.outAllow,
              daily: d.daily,
              teams: d.checkInTeams.isEmpty ? null : d.checkInTeams,
            )
          : null,
      // A daily report waits with its page, as it was posted.
      blocks: d.kind == DaybookKind.report ? d.blocks : const [],
      refs: d.kind == DaybookKind.report
          ? {
              for (final r in [...d.notes, ...d.refsIn])
                r.postId: DaybookRef(
                  title: r.title,
                  isNote: r.isNote,
                  itemStatus: r.isNote ? null : WorkStatus.checked,
                  checkedAt: r.isNote ? null : r.at,
                  createdAt: r.isNote ? r.at : null,
                  authorName: r.isNote ? r.ownerName : null,
                  checkerName: r.checkerName,
                  photoPath: r.photoPath,
                ),
            }
          : const {},
    );
  }

  /// The history line a tick or an acknowledgement writes.
  static DaybookEventKind _markLine(DaybookMark m) => m.isTick
      ? (m.on ? DaybookEventKind.ticked : DaybookEventKind.unticked)
      : switch (m.ack!) {
          DaybookAck.gotIt => DaybookEventKind.gotIt,
          DaybookAck.received => DaybookEventKind.received,
          DaybookAck.onMyWay => DaybookEventKind.onMyWay,
          DaybookAck.inMyCalendar => DaybookEventKind.inMyCalendar,
        };

  /// [c] with what the phone did that waits to be sent: a cancel fades
  /// it, a check stamps it CHECKED, a sign-off marks it DONE with its
  /// photo from the phone; each is a line in its history at once, and the
  /// card moves to Now.
  /// Where the server's last activity puts [c], save a pin-only edit
  /// (F44's Unpin): the server counts it as activity, but it doesn't move
  /// the card to Now; it stays on the day of what came before.
  static DateTime _placedOnServer(DaybookCard c) {
    final newest = c.history.firstOrNull;
    if (newest == null ||
        !newest.pinOnly ||
        c.lastActivityAt.isAfter(newest.at)) {
      return c.lastActivityAt;
    }
    return c.history.skip(1).where((e) => !e.pinOnly).firstOrNull?.at ??
        c.post.createdAt;
  }

  _Shown _asShown(
    DaybookCard c,
    Map<String, PendingItem> cancels,
    Map<String, PendingItem> checks,
    Map<String, PendingItem> signOffs, {
    required String? me,
    required String? myName,
    required DateTime now,
    List<DaybookMark> marks = const [],
    List<PendingItem> changes = const [],
  }) {
    final outbox = ref.read(workOutboxProvider.notifier);
    var card = c;
    var at = _placedOnServer(c);
    var waiting = false;
    var changing = false;
    var landing = false;
    String? localPhoto;
    PendingItem? refusedProof;
    final lines = <DaybookEvent>[];
    DateTime made(PendingItem i) => i.madeAt ?? now;
    void later(DateTime t) {
      if (t.isAfter(at)) at = t;
    }

    DaybookEvent mine(PendingItem i, DaybookEventKind kind, {String? note}) =>
        DaybookEvent(
          id: '${i.kind.json}-${i.id}',
          kind: kind,
          at: made(i),
          byId: me,
          byName: myName,
          note: note,
        );

    final signOff = signOffs[c.id];
    if (signOff != null && signOff.refused) {
      // A refused proof isn't done: the card stays as the server has it.
      refusedProof = signOff;
      localPhoto = signOff.photos.firstOrNull?.local;
      later(made(signOff));
    } else if (signOff != null && c.post.item?.status == WorkStatus.open) {
      // Until the server has the item as done.
      card = card.copyWith(
        post: card.post.shownAs(status: WorkStatus.done),
        proof: DaybookProof(
          at: made(signOff),
          byId: me,
          byName: myName,
          note: signOff.note,
          outcome: DaybookOutcome(
            kind: DaybookOutcomeKind.done,
            at: made(signOff),
            byId: me,
            byName: myName,
          ),
        ),
        clearNeed: true,
      );
      lines.add(mine(signOff, DaybookEventKind.done, note: signOff.note));
      localPhoto = signOff.photos.firstOrNull?.local;
      // Sent, it no longer waits, though the page hasn't read it yet
      // (F17). Under its undo bar, it isn't waiting for a signal (F7).
      waiting =
          !signOff.sent && !outbox.isHeld(PendingKind.signOff, signOff.id);
      later(made(signOff));
    }
    final check = checks[c.id];
    if (check != null) {
      final proof = card.proof;
      card = card.copyWith(
        post: card.post.shownAs(status: WorkStatus.checked),
        proof: proof?.withOutcome(
          DaybookOutcome(
            kind: DaybookOutcomeKind.checked,
            at: made(check),
            byId: me,
            byName: myName,
          ),
        ),
        clearNeed: true,
      );
      lines.add(mine(check, DaybookEventKind.checked));
      landing = outbox.isHeld(PendingKind.check, c.id);
      later(made(check));
    }
    // A target's rows: a sign-off or check made here shows on its row
    // until the server has it.
    final kids = card.post.children;
    if (kids != null &&
        kids.rows.any(
          (r) =>
              checks.containsKey(r.id) ||
              (signOffs[r.id] != null && !signOffs[r.id]!.refused),
        )) {
      card = card.copyWith(
        post: card.post.shownAs(
          children: kids.withRows([
            for (final r in kids.rows)
              checks.containsKey(r.id)
                  ? r.shownAs(WorkStatus.checked)
                  : signOffs[r.id] != null &&
                        !signOffs[r.id]!.refused &&
                        r.status == WorkStatus.open
                  ? r.shownAs(WorkStatus.done)
                  : r,
          ]),
        ),
      );
    }
    final cancel = cancels[c.id];
    if (cancel != null) {
      final proof = card.proof;
      card = card.copyWith(
        post: card.post.shownAs(cancelled: true),
        proof: proof?.withOutcome(
          DaybookOutcome(
            kind: DaybookOutcomeKind.cancelled,
            at: made(cancel),
            byId: me,
            byName: myName,
          ),
        ),
        clearNeed: true,
      );
      lines.add(mine(cancel, DaybookEventKind.cancelled));
      later(made(cancel));
    }
    // Send back, give to and an update on their way (slice 10): each a
    // line on the card at once, "Waiting to send" until the server has it.
    for (final i in changes) {
      if (i.cardId != c.id) continue;
      switch (i.kind) {
        case PendingKind.sendBack:
          final proof = card.proof;
          final reason = SendBackReason.fromJson(i.body);
          card = card.copyWith(
            post: card.post.shownAs(status: WorkStatus.open),
            proof: proof?.withOutcome(
              DaybookOutcome(
                kind: DaybookOutcomeKind.sentBack,
                at: made(i),
                byId: me,
                byName: myName,
                reason: reason,
                note: i.note,
              ),
            ),
            clearNeed: true,
          );
          lines.add(
            DaybookEvent(
              id: '${i.kind.json}-${i.id}',
              kind: DaybookEventKind.sentBack,
              at: made(i),
              byId: me,
              byName: myName,
              note: i.note,
              reason: reason,
            ),
          );
        case PendingKind.giveTo:
          lines.add(
            DaybookEvent(
              id: '${i.kind.json}-${i.id}',
              kind: DaybookEventKind.reassigned,
              at: made(i),
              byId: me,
              byName: myName,
              fromName: c.post.item?.ownerName,
              toName: i.ownerName,
            ),
          );
        case PendingKind.update:
          lines.add(mine(i, DaybookEventKind.comment, note: i.body));
        default:
          continue;
      }
      if (!i.sent) changing = true;
      later(made(i));
    }
    // Ticks and acknowledgements on their way: on the card at once, each a
    // line; a tick, an un-tick or a Received moves it to Now (review 60
    // S1), a take-back takes its line off.
    final onCard = [
      for (final m in marks)
        if (m.postId == c.id) m,
    ];
    final takenBack = {
      for (final m in onCard)
        if (!m.isTick && !m.on) _markLine(m),
    };
    if (onCard.isNotEmpty) {
      var ticked = card.post.pointsTicked;
      final points = card.post.isChecklist
          ? ref.watch(checklistPointsProvider(c.id)).value
          : null;
      if (points != null) {
        final byPoint = {
          for (final m in onCard)
            if (m.isTick) m.pointId: m,
        };
        ticked = [
          for (final p in points)
            if (DaybookChecklistPoints.markedPoint(p, byPoint[p.id], me).ticked)
              p,
        ].length;
      }
      card = card.copyWith(
        post: card.post.shownAs(
          myAcks: _acksOf(card.post, onCard),
          pointsTicked: ticked,
        ),
      );
      for (final m in onCard) {
        if (m.isTick || m.on) {
          lines.add(
            DaybookEvent(
              id: 'mark-${m.key}',
              kind: _markLine(m),
              at: m.at,
              byId: me,
              byName: myName,
              point: m.pointText,
            ),
          );
        }
        if (m.moves) later(m.at);
      }
      // No signal took one (slice 10): it waits on the card.
      if (onCard.any((m) => m.waiting)) changing = true;
    }
    if (lines.isNotEmpty || takenBack.isNotEmpty) {
      card = card.copyWith(
        history: [
          ...lines.reversed,
          for (final e in card.history)
            if (!(takenBack.contains(e.kind) && e.byId == me)) e,
        ],
      );
    }
    return _Shown(
      card: card,
      at: at,
      waiting: waiting,
      changeWaiting: changing,
      refusedProof: refusedProof,
      localPhoto: localPhoto,
      landing: landing,
    );
  }

  /// For each card, every earlier day (the phone's) on which something
  /// happened to it: that day's latest event.
  /// An activity starting today, not over, posted on an earlier day: it
  /// shows again at the start of today (K3 v13), its header still at its
  /// own last activity.
  static _Shown _onItsDay(_Shown s, DateTime now) {
    final post = s.card.post;
    final start = post.startsAt;
    final end = post.activityEnd;
    final today = dayOf(now);
    if (!post.isActivity ||
        post.cancelled ||
        start == null ||
        end == null ||
        dayOf(start) != today ||
        !now.isBefore(end) ||
        !dayOf(s.at).isBefore(today)) {
      return s;
    }
    return _Shown(
      card: s.card,
      at: s.at,
      waiting: s.waiting,
      changeWaiting: s.changeWaiting,
      unsent: s.unsent,
      refusedProof: s.refusedProof,
      localPhoto: s.localPhoto,
      landing: s.landing,
      dayAt: today,
    );
  }

  static List<(DateTime, _Trace)> _traces(_Shown s) {
    final cardDay = dayOf(s.placedAt);
    final seen = <DateTime>{};
    return [
      // Newest first: the first of each day is its latest.
      for (final e in s.card.history)
        if (e.kind != DaybookEventKind.unknown &&
            dayOf(e.at).isBefore(cardDay) &&
            seen.add(dayOf(e.at)))
          (e.at, (card: s.card, event: e)),
    ];
  }

  /// [post]'s site tag (review 105C): its place's name, and a tap that
  /// filters Work to it.
  ({String name, VoidCallback? onTap})? _siteOf(
    DaybookPost post,
    List<SpacePlace>? places,
  ) {
    final place = places?.where((p) => p.id == post.placeId).firstOrNull;
    if (place == null) return null;
    return (
      name: place.name,
      onTap: _writing
          ? null
          : () => ref
                .read(workPlaceFilterProvider(_spaceId).notifier)
                .show(place),
    );
  }

  Widget _diary(
    List<DaybookCard> cards,
    List<PendingItem> pending,
    DaybookWords words, {
    required String? me,
    required String? myName,
    required DateTime now,
    required bool card,
    required Set<String> signing,
    Set<String>? only,
  }) {
    final l10n = AppLocalizations.of(context);
    final viewer = widget.space.myPass == SpacePass.viewer;
    final today = dayOf(now);
    Map<String, PendingItem> byKind(PendingKind kind) => {
      for (final i in pending)
        if (i.kind == kind) i.id: i,
    };
    final cancels = byKind(PendingKind.cancel);
    final checks = byKind(PendingKind.check);
    final signOffs = byKind(PendingKind.signOff);
    final changes = [
      for (final i in pending)
        if (i.isChange) i,
    ];
    final onServer = {for (final c in cards) c.id};
    // A target's work items are rows on its card, not cards of their own.
    final folded = {
      for (final c in cards)
        for (final r in c.post.children?.rows ?? const <DaybookChild>[])
          if (c.post.isTarget) r.id,
    };
    final marks = ref.watch(daybookMarksProvider);
    final extras = ref.watch(daybookExtrasProvider(_spaceId)).value;
    final names = ref.watch(spacePeopleProvider(_spaceId)).value;
    final places = ref.watch(spacePlacesProvider(_spaceId)).value;
    // Every kind the daybook draws, with what still waits for a signal. A
    // pinned announcement sits under the masthead instead.
    final shown = <_Shown>[
      for (final c in cards)
        if (DaybookPost.shownKinds.contains(c.post.kind) &&
            !c.post.pinnedAt(now))
          _onItsDay(
            _asShown(
              c,
              cancels,
              checks,
              signOffs,
              me: me,
              myName: myName,
              now: now,
              marks: marks,
              changes: changes,
            ),
            now,
          ),
      // An activity starting today that is on an older page: its card
      // shows again on its day (K3 v13).
      for (final p in extras?.activities ?? const <DaybookPost>[])
        if (!onServer.contains(p.id))
          _onItsDay(
            _asShown(
              DaybookCard(post: p, lastActivityAt: p.createdAt),
              cancels,
              checks,
              signOffs,
              me: me,
              myName: myName,
              now: now,
              marks: marks,
            ),
            now,
          ),
      // A new post not on the server yet: a card at the time Post was
      // tapped.
      for (final i in pending)
        if (i.isNewPost && !onServer.contains(i.id))
          _Shown(
            card: DaybookCard(
              post: _waitingPost(i, me, now),
              lastActivityAt: i.madeAt ?? now,
            ),
            at: i.madeAt ?? now,
            waiting: !i.sent,
            unsent: i,
          ),
      // A proof for an item on an older page, not loaded: its own card.
      for (final i in signOffs.values)
        if (!onServer.contains(i.id) && !folded.contains(i.id))
          _asShown(
            DaybookCard(
              post: DaybookPost(
                id: i.id,
                kind: DaybookPost.workItemKind,
                createdAt: i.madeAt ?? now,
                title: i.title,
                item: DaybookItem(
                  status: WorkStatus.open,
                  ownerId: me,
                  ownerName: myName,
                ),
              ),
              lastActivityAt: i.madeAt ?? now,
            ),
            cancels,
            checks,
            signOffs,
            me: me,
            myName: myName,
            now: now,
          ),
    ];
    // Oldest first, grouped by the phone's own days; the writing card is
    // today's. A card is at its latest activity, its traces on the days
    // before.
    final byDay = <DateTime, List<(DateTime, String, Object)>>{};
    // Review 105 Part 6: only what waits on me, with no traces.
    for (final s in shown) {
      if (only != null && !only.contains(s.card.id)) continue;
      byDay.putIfAbsent(dayOf(s.placedAt), () => []).add((
        s.placedAt,
        s.card.id,
        s,
      ));
      for (final (at, t)
          in only == null ? _traces(s) : const <(DateTime, _Trace)>[]) {
        byDay.putIfAbsent(dayOf(at), () => []).add((
          at,
          '${t.card.id}-${t.event.id}',
          t,
        ));
      }
    }
    for (final rows in byDay.values) {
      rows.sort((a, b) {
        final t = a.$1.compareTo(b.$1);
        return t != 0 ? t : a.$2.compareTo(b.$2);
      });
    }
    // Today is always there, with its divider, even before anything is
    // posted (F59).
    byDay.putIfAbsent(today, () => []);
    _days = byDay.keys.toList()..sort();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateShownDay();
      _loadOlderIfNear();
    });

    final sending = ref.watch(outboxSendingProvider);
    // Review 105 SP3: work items' tables of tasks, on their cards.
    final taskTables =
        ref.watch(taskTablesProvider(_spaceId)).value ??
        const <String, List<PageTaskTable>>{};
    final selected = ref.watch(workSelectionProvider(_spaceId));
    final selecting = selected.isNotEmpty;
    void select(String id) {
      unawaited(HapticFeedback.selectionClick());
      ref.read(workSelectionProvider(_spaceId).notifier).toggle(id);
    }

    Widget cardOf(_Shown s) {
      final c = s.card;
      final unsent = s.unsent;
      final refusedProof = s.refusedProof;
      final tables = unsent == null ? taskTables[c.id] : null;
      final view = DaybookCardView(
        spaceId: _spaceId,
        card: c,
        words: words,
        me: me,
        now: now,
        activityAt: s.at,
        viewer: viewer,
        taskCount: tables == null ? null : taskCount(tables),
        taskTables: tables == null
            ? null
            : Column(
                key: Key('card-task-tables-${c.id}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvSpace.s8,
                children: [
                  for (final t in tables)
                    PageTaskTableView(
                      key: Key('card-task-table-${t.id}'),
                      space: widget.space,
                      post: c.post,
                      table: t,
                      me: me,
                    ),
                ],
              ),
        waiting: s.waiting,
        changeWaiting: s.changeWaiting,
        // F73: on its way now (with a signal), not waiting for one.
        sending: switch (sending[c.id]) {
          final OutboxSending g => (sent: g.sent, total: g.total),
          null => null,
        },
        couldNotSend: s.refused,
        localPhoto: s.localPhoto,
        // A new post's photos from the phone, each until it is uploaded
        // (F51).
        waitingPhotos: [
          for (final p in unsent?.photos ?? const <PendingPhoto>[])
            (local: p.local, waiting: p.remote == null && !unsent!.sent),
        ],
        landing: s.landing,
        expanded: _expanded.contains(c.id),
        onEarlier: () => _earlier(c),
        lineKey: (id) => _lineKeys.putIfAbsent(id, GlobalKey.new),
        // Who ticked a point: a member's name, else the card's history's.
        nameOf: (id) =>
            names?.member(id)?.person.fullName ??
            c.history.where((e) => e.byId == id).firstOrNull?.byName,
        site: _siteOf(c.post, places),
        onTag: switch (c.post.tag) {
          final tag? when !_writing =>
            () => ref.read(workTagFilterProvider(_spaceId).notifier).show(tag),
          _ => null,
        },
        selected: selected.contains(c.id),
        // While writing, a tap on a card puts the card down, as anywhere
        // off it; while selecting it adds or takes off this one; a refused
        // one reopens to fix; otherwise a tap opens it (review 105).
        onTap: _writing
            ? _stopWriting
            : selecting
            ? (unsent == null ? () => select(c.id) : null)
            : unsent != null && unsent.refused
            ? () => unawaited(
                unsent.kind == PendingKind.walk
                    ? _fixWalk(unsent)
                    : _reopen(unsent),
              )
            : refusedProof != null
            ? () => unawaited(
                _loop.reopenProof(context, refusedProof, post: c.post),
              )
            : null,
      );
      return KeyedSubtree(
        key: _cardKeys.putIfAbsent(c.id, GlobalKey.new),
        child: KeyedSubtree(
          key: Key('daybook-card-${c.id}'),
          // The card a row or a push opened (F20). Review 107 OB7: "Hold a
          // card to share or delete it" points at it.
          child: BvTipAnchor(
            // Only for who can hold a card (Q4).
            id: widget.space.myRights.createItems ? FirstRunTip.hold : null,
            child: BvHighlight(
              flash: _highlighted == c.id ? _flashes : null,
              // A post not on the server yet has nothing to do on it.
              // The lead's check of 115: one gesture model. A hold is the
              // card's actions (SP6): Pin · Reminder, then what the server
              // says (review 113); a sideways swipe is always the page's.
              // The clip keeps the card as the swipe's row drew it: its
              // shadow stops at its edge, as on the signed-off shots.
              child: unsent != null
                  ? view
                  : ClipRect(
                      child: _loop.withActions(
                        context,
                        view,
                        me: me,
                        signing: signing,
                        onHold: () => select(c.id),
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    Widget traceOf(_Trace t) {
      final e = t.event;
      final by = e.byId;
      return BvTraceRow(
        key: Key('daybook-trace-${t.card.id}-${dayOf(e.at).toIso8601String()}'),
        name: personName(l10n, e.byName),
        tint: by == null ? BvAvatarTints.plain : BvAvatarTints.forId(by),
        text: l10n.daybookTrace(
          words.eventPhrase(e, me: me, now: now, trace: true),
          t.card.post.title,
        ),
        time: words.time.clock(e.at),
        onTap: _writing ? _stopWriting : () => unawaited(_openAt(t)),
      );
    }

    // Review 101 A: a row at a time, newest first, as older days grow up
    // from Now; each day's divider is its top row. The writing card stays
    // built under them all.
    final rows = <({DateTime day, Widget child})>[];
    _rowDays = [];
    _cardRow.clear();
    _dayRow.clear();
    void add(DateTime day, Widget child) {
      rows.add((day: day, child: child));
      _rowDays.add(day);
    }

    for (final day in _days.reversed) {
      for (final (_, _, row) in byDay[day]!.reversed) {
        if (row is _Shown) _cardRow[row.card.id] = rows.length;
        add(day, switch (row) {
          _Shown s => cardOf(s),
          _ => traceOf(row as _Trace),
        });
      }
      if (day == today && byDay[day]!.isEmpty) {
        add(
          day,
          Text(
            l10n.daybookNothingYetToday,
            key: const Key('daybook-nothing-today'),
            textAlign: TextAlign.center,
            style: BvType.of(
              context,
            ).labelSm.copyWith(color: BvColors.textSecondary),
          ),
        );
      }
      _dayRow[day] = rows.length;
      add(
        day,
        KeyedSubtree(
          key: _dayKeys.putIfAbsent(day, GlobalKey.new),
          // Under a masthead naming the same day, it keeps its place but
          // doesn't show (F23).
          child: Visibility(
            key: Key('daybook-divider-${day.toIso8601String()}'),
            visible: !_dividerHidden(day, today),
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: BvDayDivider(
              label: day == today
                  ? l10n.daybookTodayDivider
                  : words.compactDate(day),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      // While writing, a tap off the card puts it down.
      behavior: HitTestBehavior.opaque,
      onTap: _writing ? _stopWriting : null,
      // Pull down to read again; it always pulls, however short the page
      // (F11).
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: _DaybookScroll(
          key: const Key('daybook'),
          controller: _scroll,
          page: SliverPadding(
            padding: const EdgeInsetsDirectional.only(
              start: BvCardSpec.paddingSide,
              end: BvCardSpec.paddingSide,
              top: BvCardSpec.paddingTop,
            ),
            sliver: _SliverListTopDown(
              delegate: SliverChildBuilderDelegate(
                childCount: rows.length,
                // Drawn in one picture with the page, as it always was.
                addRepaintBoundaries: false,
                (context, i) => LazyRow(
                  index: i,
                  built: _built,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: i == 0 ? 0 : BvCardSpec.gap,
                    ),
                    child: rows[i].child,
                  ),
                ),
              ),
            ),
          ),
          now: SliverPadding(
            padding: const EdgeInsetsDirectional.only(
              start: BvCardSpec.paddingSide,
              end: BvCardSpec.paddingSide,
              bottom: BvCardSpec.paddingBottom,
            ),
            sliver: card
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: BvCardSpec.gap,
                      ),
                      child: KeyedSubtree(
                        key: const Key('daybook-now'),
                        child: DaybookWritingCard(
                          // An edit's card is its own.
                          key: ValueKey(_editing),
                          spaceId: _spaceId,
                          writing: _writing,
                          editing: _editing,
                          words: words,
                          fromBefore: _fromBefore && !_editing,
                          onOpen: _startWriting,
                          onMenu: _setMenu,
                          onPickDue: _pickDue,
                          onPickPin: () => unawaited(_pickPin()),
                          onPickPinTime: () => unawaited(_pickPinTime()),
                          onPickStart: () => unawaited(_pickStart()),
                          onPickFile: () => unawaited(_pickFile()),
                          onPickPeople: () => unawaited(_pickPeople()),
                          onPickPlace: () => unawaited(_pickPlace()),
                          onWalk: widget.space.mayPostWork
                              ? () => unawaited(_walk())
                              : null,
                          askWho: _askWho,
                        ),
                      ),
                    ),
                  )
                : const SliverToBoxAdapter(),
          ),
        ),
      ),
    );
  }
}

/// The Daybook's page (review 101 A), building only the rows on screen and
/// a small margin. Now is its centre, at the foot of the screen, and older
/// days grow up from it: offset 0 is Now, older days are below 0.
class _DaybookScroll extends CustomScrollView {
  _DaybookScroll({
    super.key,
    super.controller,
    required Widget page,
    required Widget now,
  }) : super(
         center: _now,
         anchor: 1,
         physics: const AlwaysScrollableScrollPhysics(),
         slivers: [
           _SliverFromTop(sliver: _PageGroup(slivers: [page, now])),
           const SliverToBoxAdapter(key: _now),
         ],
       );

  static const _now = Key('daybook-centre');

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) => _NowViewport(
    axisDirection: axisDirection,
    offset: offset,
    center: center,
    anchor: anchor,
    clipBehavior: clipBehavior,
    slivers: slivers,
  );
}

/// Bringing a card, a line or a field into view (Flutter's reveal), on a
/// page that grows up from Now:
/// - its leading edge is Now's, at the foot, as the page always had it: an
///   alignment of 0 is the foot and 1 the top;
/// - Flutter's reveal leaves out the anchor, so with Now at the foot it
///   would land a screen off; this puts the anchor back.
class _NowViewport extends Viewport {
  _NowViewport({
    super.axisDirection,
    required super.offset,
    super.center,
    super.anchor,
    super.clipBehavior,
    super.slivers,
  });

  @override
  RenderViewport createRenderObject(BuildContext context) => _RenderNowViewport(
    axisDirection: axisDirection,
    crossAxisDirection:
        crossAxisDirection ??
        Viewport.getDefaultCrossAxisDirection(context, axisDirection),
    anchor: anchor,
    offset: offset,
    clipBehavior: clipBehavior,
  );
}

class _RenderNowViewport extends RenderViewport {
  _RenderNowViewport({
    super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    super.anchor,
    super.clipBehavior,
  });

  @override
  RevealedOffset getOffsetToReveal(
    RenderObject target,
    double alignment, {
    Rect? rect,
    Axis? axis,
  }) {
    final revealed = super.getOffsetToReveal(
      target,
      1 - alignment,
      rect: rect,
      axis: axis,
    );
    if (!revealed.offset.isFinite) return revealed;
    final shift = anchor * size.height;
    return RevealedOffset(
      offset: revealed.offset + shift,
      rect: revealed.rect.translate(0, -shift),
    );
  }
}

/// The page of rows, then the writing card at Now, under it. Laid out as
/// [SliverMainAxisGroup] does, but painted top to bottom as the page always
/// was, though it grows up from Now: a card's paper clip reaches over the
/// card above it, so the one below is painted after it, and is hit first.
class _PageGroup extends SliverMainAxisGroup {
  const _PageGroup({required super.slivers});

  @override
  RenderSliverMainAxisGroup createRenderObject(BuildContext context) =>
      _RenderPageGroup();
}

class _RenderPageGroup extends RenderSliverMainAxisGroup {
  bool get _up => constraints.growthDirection == GrowthDirection.reverse;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_up) return super.paint(context, offset);
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (child.geometry!.visible) {
        final data = child.parentData! as SliverPhysicalParentData;
        context.paintChild(child, offset + data.paintOffset);
      }
    }
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    if (!_up) {
      return super.hitTestChildren(
        result,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
      );
    }
    for (var child = lastChild; child != null; child = childBefore(child)) {
      final data = child.parentData! as SliverPhysicalParentData;
      if (result.addWithAxisOffset(
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
        paintOffset: data.paintOffset,
        mainAxisOffset: childMainAxisPosition(child),
        crossAxisOffset: childCrossAxisPosition(child),
        hitTest: child.hitTest,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Growing up, a child starts past the ones under it, nearer Now: their
  /// length, counted forward (Flutter's group counts it back).
  @override
  double? childScrollOffset(RenderObject child) {
    if (!_up) return super.childScrollOffset(child);
    var offset = 0.0;
    for (
      var current = childAfter(child as RenderSliver);
      current != null;
      current = childAfter(current)
    ) {
      offset += current.geometry!.scrollExtent;
    }
    return offset;
  }
}

/// The rows, painted top to bottom as the page always was, though they grow
/// up from Now: a card's paper clip reaches over the card above it, so the
/// card below is painted after it, and is hit first.
class _SliverListTopDown extends SliverList {
  const _SliverListTopDown({required super.delegate});

  @override
  RenderSliverList createRenderObject(BuildContext context) =>
      _RenderSliverListTopDown(
        childManager: context as SliverMultiBoxAdaptorElement,
      );
}

class _RenderSliverListTopDown extends RenderSliverList {
  _RenderSliverListTopDown({required super.childManager});

  bool get _up =>
      applyGrowthDirectionToAxisDirection(
        constraints.axisDirection,
        constraints.growthDirection,
      ) ==
      AxisDirection.up;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_up) return super.paint(context, offset);
    // As [RenderSliverMultiBoxAdaptor.paint] does growing up, last row first.
    final origin = offset + Offset(0, geometry!.paintExtent);
    for (var child = lastChild; child != null; child = childBefore(child)) {
      final along = childMainAxisPosition(child);
      final extent = paintExtentOf(child);
      if (along < constraints.remainingPaintExtent && along + extent > 0) {
        context.paintChild(
          child,
          origin + Offset(childCrossAxisPosition(child), -along - extent),
        );
      }
    }
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    if (!_up) {
      return super.hitTestChildren(
        result,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
      );
    }
    final boxResult = BoxHitTestResult.wrap(result);
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (hitTestBoxChild(
        boxResult,
        child,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
      )) {
        return true;
      }
    }
    return false;
  }
}

/// A page shorter than the screen sits at its top, as it always has: the
/// page grows up from Now, so the gap goes under it.
class _SliverFromTop extends SingleChildRenderObjectWidget {
  const _SliverFromTop({required Widget sliver}) : super(child: sliver);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFromTop();
}

class _RenderFromTop extends RenderSliverEdgeInsetsPadding {
  var _gap = 0.0;

  @override
  EdgeInsets get resolvedPadding => EdgeInsets.only(bottom: _gap);

  @override
  void performLayout() {
    _gap = 0;
    super.performLayout();
    // A page that ends before the screen does was laid out whole: its
    // length is exact.
    final short =
        constraints.viewportMainAxisExtent -
        constraints.precedingScrollExtent -
        geometry!.scrollExtent;
    if (short > precisionErrorTolerance &&
        geometry!.scrollOffsetCorrection == null) {
      _gap = short;
      super.performLayout();
    }
  }
}

/// Day one (DY3): the first page, 16 from each edge.
class _FirstPage extends StatelessWidget {
  const _FirstPage({
    required this.space,
    required this.canPost,
    required this.onPost,
  });

  final SpaceDetail space;
  final bool canPost;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        // Pull down to read again (F11).
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvCardSpec.paddingSide,
            ),
            child: Center(
              child: BvFirstPage(
                key: const Key('daybook-first-page'),
                title: l10n.daybookFirstTitle,
                body: l10n.daybookFirstBody,
                actions: [
                  if (canPost)
                    BvFirstPageAction(
                      icon: BvIcons.confirmed,
                      label: l10n.daybookFirstPost,
                      primary: true,
                      onTap: onPost,
                    ),
                  if (space.canInvite)
                    BvFirstPageAction(
                      icon: BvIcons.team,
                      label: l10n.daybookFirstInvite,
                      onTap: () =>
                          context.push(AppRoutes.spaceInvite(space.id)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The month drop-down's content (DY2): its own month, and the marks from
/// the server. Pops with the day picked.
class DaybookMonthDrop extends ConsumerStatefulWidget {
  const DaybookMonthDrop({
    super.key,
    required this.spaceId,
    required this.today,
    required this.selected,
    required this.firstWeekday,
  });

  final String spaceId;
  final DateTime today;
  final DateTime selected;
  final int firstWeekday;

  @override
  ConsumerState<DaybookMonthDrop> createState() => _DaybookMonthState();
}

class _DaybookMonthState extends ConsumerState<DaybookMonthDrop> {
  late var _month = DateTime(widget.selected.year, widget.selected.month);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final marks = ref
        .watch(daybookMonthProvider((spaceId: widget.spaceId, month: _month)))
        .value;
    Set<int> inMonth(Set<DateTime>? days) => {
      for (final d in days ?? const <DateTime>{})
        if (d.year == _month.year && d.month == _month.month) d.day,
    };
    return BvMonthDropdown(
      month: _month,
      today: widget.today,
      selected: widget.selected,
      firstWeekday: widget.firstWeekday,
      postsLabel: l10n.daybookMonthPosts,
      dueLabel: l10n.daybookMonthDue,
      postDays: inMonth(marks?.postDays),
      dueDays: inMonth(marks?.dueDays),
      onDay: (day) => Navigator.of(context).pop(day),
      onPrevious: () =>
          setState(() => _month = DateTime(_month.year, _month.month - 1)),
      onNext: () =>
          setState(() => _month = DateTime(_month.year, _month.month + 1)),
    );
  }
}
