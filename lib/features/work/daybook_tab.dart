import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../core/design/daybook_paper_specs.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/push/push_state.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/daybook_live.dart';
import '../../data/repositories/daybook_repository.dart'
    show daybookRepositoryProvider;
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_day_divider.dart';
import '../../shared/widgets/bv_daybook_masthead.dart';
import '../../shared/widgets/bv_due_today_strip.dart';
import '../../shared/widgets/bv_first_page.dart';
import '../../shared/widgets/bv_highlight.dart';
import '../../shared/widgets/bv_month_dropdown.dart';
import '../../shared/widgets/bv_new_chip.dart';
import '../../shared/widgets/bv_pinned_note.dart';
import '../../shared/widgets/bv_popover_menu.dart' show bvGlobalRect;
import '../../shared/widgets/bv_post_bar.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_trace_row.dart';
import '../../shared/widgets/bv_writing_toolbar.dart';
import '../account/account_parts.dart' show myMarketProvider;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/former_member.dart';
import '../spaces/pass_words.dart';
import '../spaces/space_errors.dart';
import 'daybook_attach.dart';
import 'daybook_card.dart';
import 'daybook_draft.dart';
import 'daybook_kinds.dart';
import 'daybook_loop.dart';
import 'daybook_marks.dart';
import 'daybook_state.dart';
import 'daybook_target.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart';
import 'work_outbox.dart';

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
    this.startFile,
  });

  final SpaceDetail space;

  /// Opened from an Activity row, a push or a Needs you card (F20): the
  /// page loads down to that card, scrolls to it and highlights it, its
  /// history open at the event's line. Gone: "This was removed".
  final DaybookTarget? target;

  /// Opened from Create's "Work item in a Space" (F1): the card opens at
  /// Now, when the reader may write work items here.
  final bool startWriting;

  /// Opened from the Library: a file post at Now, its chooser open.
  final DaybookFileStart? startFile;

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

  /// The card is a posted work item's, being edited (X1 Edit).
  var _editing = false;
  DaybookWritingMenu? _menu;

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

  DaybookLoop get _loop =>
      DaybookLoop(ref, widget.space, onEdit: _startEdit, openItems: _openItems);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // A card that only quotes a message just put in this Space (review
    // 64, DM5) is new, not a Draft from before.
    final kept = ref.read(daybookDraftProvider(_spaceId));
    _fromBefore = kept != null && !kept.onlyQuote;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.startWriting && widget.space.myRights.createItems) {
        _startWriting();
      }
      if (mounted && widget.startFile != null) {
        unawaited(_startFile(widget.startFile!));
      }
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
    final start = widget.startFile;
    if (start != null && start != old.startFile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startFile(start));
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
        found = await pages.find(target.postId);
        if (!found) {
          final one = await ref
              .read(daybookRepositoryProvider)
              .card(target.postId);
          final parent = one?.post.parentId;
          if (parent != null && await pages.find(parent)) {
            found = true;
            child = target.postId;
          }
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
          final at = _cardKeys[parentId]?.currentContext;
          if (at != null && at.mounted) {
            await Scrollable.ensureVisible(at, alignment: 0.5);
          }
          if (!mounted) return;
          setState(() {
            _highlighted = parentId;
            _flashes++;
          });
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
      final at =
          (line == null ? null : _lineKeys[line]?.currentContext) ??
          _cardKeys[target.postId]?.currentContext;
      if (at != null && at.mounted) {
        await Scrollable.ensureVisible(at, alignment: 0.5);
      }
      if (!mounted) return;
      setState(() {
        _highlighted = target.postId;
        _flashes++;
      });
      _updateShownDay();
    } finally {
      _revealing = false;
    }
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
      _scroll.hasClients && _scroll.offset > BvNewChipSpec.awayFromNow;

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
        (_scroll.offset + shift).clamp(
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
    _updateShownDay();
    _loadOlderIfNear();
    if (_newBelow && !_away) setState(() => _newBelow = false);
  }

  /// Older days hang above today on the same page (review 45 B1): load
  /// them while the top is near, including when the page isn't full yet.
  void _loadOlderIfNear() {
    if (!_scroll.hasClients || _scroll.position.extentAfter >= _loadAhead) {
      return;
    }
    unawaited(ref.read(daybookCardsProvider(_spaceId).notifier).loadOlder());
  }

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
    final top = viewport.localToGlobal(Offset.zero).dy;
    DateTime? shown;
    for (final day in _days) {
      final box =
          _dayKeys[day]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      // The first day laid out is the top one, even below the top edge.
      shown ??= day;
      if (box.localToGlobal(Offset.zero).dy <=
          top + BvMastheadSpec.readingLine) {
        shown = day;
      }
    }
    if (shown != _shownDay) setState(() => _shownDay = shown);
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
    final context = _dayKeys[target]?.currentContext;
    if (context == null || !context.mounted) return;
    // The list runs bottom up: 1 puts the day's top at the page's top.
    await Scrollable.ensureVisible(context, alignment: 1);
    _updateShownDay();
  }

  /// A trace's ›: the card, with its history open at that event.
  Future<void> _openAt(_Trace trace) async {
    setState(() => _expanded.add(trace.card.id));
    await WidgetsBinding.instance.endOfFrame;
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

  /// Opens the card at "Now", with a new post id (or the Draft's).
  void _startWriting() {
    ref
        .read(daybookDraftProvider(_spaceId).notifier)
        .open(ref.read(newPostIdProvider)());
    setState(() {
      _writing = true;
      _editing = false;
      _menu = null;
      _askWho = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /// A file post from the Library (review 69 1b): the card at Now as a
  /// Document for receipt, the file chooser open; for a new version, the
  /// phone's files at once, replacing [DaybookFileStart.replaces].
  Future<void> _startFile(DaybookFileStart start) async {
    if (!widget.space.myRights.createItems) return;
    _startWriting();
    await _card.setKind(DaybookKind.file);
    if (!mounted) return;
    final file = await chooseDaybookFile(
      context,
      ref,
      spaceId: _spaceId,
      replaces: start.replaces,
    );
    if (file != null) await _card.addFile(file);
  }

  /// Edit a posted work item: its card opens at "Now", filled (X1 Edit).
  void _startEdit(DaybookPost post) {
    ref.read(daybookEditProvider(_spaceId).notifier).start(post);
    setState(() {
      _writing = true;
      _editing = true;
      _menu = null;
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
    setState(() {
      _writing = false;
      _editing = false;
      _menu = null;
      _askWho = null;
    });
  }

  void _setMenu(DaybookWritingMenu? menu) => setState(() {
    _menu = menu;
    if (menu != null) _askWho = null;
  });

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
    if (picked != null) await _card.setPin(picked.until);
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
    );
    if (!mounted || choice == null) return;
    if (choice == DaybookAttach.file && kind == DaybookKind.file) {
      return _pickFile();
    }
    if (writer.room <= 0) {
      showSpaceMessage(context, l10n.daybookFilesFull);
      return;
    }
    switch (choice) {
      case DaybookAttach.photos:
        await _photos(writer.addPhotos());
      case DaybookAttach.file:
        final file = await chooseDaybookFile(context, ref, spaceId: _spaceId);
        if (file != null) await writer.addFile(file);
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
      case DaybookMissing.owner || DaybookMissing.people:
        setState(() {
          _menu = null;
          _askWho = Object();
        });
      case DaybookMissing.start:
        await _pickStart();
      case null:
        await _post(myName);
    }
  }

  void _assigned() => _setMenu(null);

  Future<void> _post(String? myName) async {
    await _writer.post(authorName: myName);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _writing = false;
      _menu = null;
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
        if (c.post.isWorkItem &&
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
    final page = ref.watch(daybookCardsProvider(_spaceId));
    final dueToday =
        ref.watch(daybookDueTodayProvider(_spaceId)).value ??
        const <CalendarWorkItem>[];
    final draft = ref.watch(daybookDraftProvider(_spaceId));
    final edit = ref.watch(daybookEditProvider(_spaceId));
    final pending = [
      for (final i in ref.watch(workOutboxProvider))
        if (i.spaceId == _spaceId) i,
    ];
    final myName = ref
        .watch(spacePeopleProvider(_spaceId))
        .value
        ?.member(me ?? '')
        ?.person
        .fullName;
    final card =
        canPost && (_writing || _editing || (draft != null && !draft.isEmpty));
    final signing = {
      for (final i in pending)
        if (i.kind == PendingKind.signOff) i.id,
    };
    final cards = page.value ?? const <DaybookCard>[];
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
    final strip = [
      for (final i in due) (day: words.stripDay(i.day, now), title: i.title),
    ];
    if (_target != null && page.hasValue && !_revealing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_reveal()));
    }

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
    final prove = _openItems.firstOrNull;
    final cardDraft = _editing ? edit : draft;
    // At Now, and while writing, the masthead reads Today (F59); away from
    // Now it follows the day at the top of the page (F23).
    final atToday = _writing || !_wasAway || shown == today;
    final day = atToday ? today : shown;

    return PopScope(
      canPop: !_writing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _menu != null ? _setMenu(null) : _stopWriting();
      },
      child: ColoredBox(
        color: BvColors.surfaceApp,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BvDaybookMasthead(
              key: _mastheadKey,
              weekday: atToday ? l10n.daybookTodayDivider : words.weekday(day),
              date: atToday
                  ? l10n.daybookMastheadToday(words.compactDate(today))
                  : words.dayMonth(day),
              onTap: _writing ? null : () => _openMonth(today, shown),
            ),
            if (due.isNotEmpty && !_writing)
              BvDueTodayStrip(
                key: const Key('to-do-strip'),
                label: l10n.daybookToDo,
                count: strip.length,
                // Review 73 A1: every item, each opening its card.
                onTap: () => showBvToDoSheet(
                  context,
                  title: l10n.daybookToDo,
                  items: strip,
                  onOpen: (n) {
                    if (!mounted) return;
                    setState(() => _target = DaybookTarget(due[n].postId));
                  },
                ),
              ),
            // Pinned announcements stay under the masthead while pinned
            // (K1 v13), whatever their last activity.
            if (!_writing)
              for (final p in _pinned(cards, now))
                Padding(
                  padding: BvPinnedSpec.outer,
                  child: _pinnedNote(p, words, cards, me: me, now: now),
                ),
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
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!canPost)
              BvPostBar.viewer(
                passLabel: passName(l10n, space.myPass),
                passTone: passTone(space.myPass),
                // "Read only" is a Viewer's; a locked Crew pass is just
                // the pass (review 67, V1).
                readOnly: space.myPass == SpacePass.viewer
                    ? l10n.daybookReadOnly
                    : null,
              )
            else if (_writing)
              BvWritingToolbar(
                cameraLabel: l10n.daybookCamera,
                // An edit keeps its photos (slice 5 opens a post in place).
                onCamera: _editing
                    ? null
                    : () => unawaited(_photos(_writer.addPhoto())),
                attachLabel: l10n.daybookAttachTitle,
                onAttach: _editing ? null : () => unawaited(_attach()),
                moreLabel: l10n.daybookMore,
                // A note has nothing more to set (F58).
                onMore: cardDraft?.kind == DaybookKind.note
                    ? null
                    : () => _setMenu(
                        _menu == DaybookWritingMenu.more
                            ? null
                            : DaybookWritingMenu.more,
                      ),
                moreActive: _menu == DaybookWritingMenu.more,
                postLabel: _editing ? l10n.daybookSave : l10n.daybookPost,
                // Post turns on with what the kind can't go without (a
                // title, a checklist's points, a file; review 46); what it
                // still needs opens first.
                onPost: _editing
                    ? (cardDraft?.titleFits ?? false ? _save : null)
                    : (cardDraft?.readyToTry ?? false
                          ? () => unawaited(_postOrAsk(myName))
                          : null),
                // F56: grey until the "who" is chosen too; a tap asks.
                postReady:
                    _editing ||
                    (cardDraft?.canPost(ref.watch(clockProvider)()) ?? false),
              )
            // A Draft on the page takes the post bar's place until it is
            // posted or emptied (E4).
            else if (!card)
              BvPostBar(
                placeholder: l10n.daybookWorkItem,
                onWrite: _startWriting,
                cameraLabel: l10n.daybookHoldToProve,
                // A tap writes a work item with a photo; holding proves
                // your open work item (O1 → O2).
                onCamera: () {
                  _startWriting();
                  unawaited(_photos(_writer.addPhoto()));
                },
                onProve: prove == null
                    ? null
                    : () => unawaited(_loop.signDone(context, prove)),
              ),
          ],
        ),
      ),
    );
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
    return byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

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
    // F44: full or folded, the same long-press menu as its card; [lifted]
    // is the note raised over the dimmed page while the menu is open.
    final hasMenu = _loop.kindMenu(post, me: me).isNotEmpty;
    Widget withMenu(Widget Function(VoidCallback? onLongPress) note) => Builder(
      builder: (context) => note(
        hasMenu
            ? () => unawaited(
                _loop.pinnedMenu(
                  context,
                  post,
                  IgnorePointer(child: note(null)),
                  bvGlobalRect(context),
                  me: me,
                ),
              )
            : null,
      ),
    );
    if (folds && !_openPinned.contains(post.id)) {
      return withMenu(
        (onLongPress) => BvPinnedLine(
          key: Key('pinned-line-${post.id}'),
          text: post.title,
          onTap: () => setState(() => _openPinned.add(post.id)),
          onLongPress: onLongPress,
        ),
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
    return withMenu(
      (onLongPress) => BvPinnedNote(
        key: Key('pinned-${post.id}'),
        onLongPress: onLongPress,
        author: post.authorId != null && post.authorId == me
            ? l10n.daybookYou
            : personName(l10n, post.authorName),
        audience: team == null
            ? l10n.daybookToEveryone
            : l10n.daybookToTeam(team),
        until: l10n.daybookPinnedUntil(words.pinnedDay(post.pinnedUntil!, now)),
        title: post.title,
        body: post.body,
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
        onTap: folds ? () => setState(() => _openPinned.remove(post.id)) : null,
        action: daybookAckAction(
          l10n,
          shown,
          me: me,
          now: now,
          onAck: (kind, {required on}) {
            // Given now: it folds.
            if (on) setState(() => _openPinned.remove(post.id));
            unawaited(
              _loop.acknowledge(
                context,
                shown,
                kind,
                on: on,
                again: editedSince,
              ),
            );
          },
        ),
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
  }) {
    final outbox = ref.read(workOutboxProvider.notifier);
    var card = c;
    var at = _placedOnServer(c);
    var waiting = false;
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

  Widget _diary(
    List<DaybookCard> cards,
    List<PendingItem> pending,
    DaybookWords words, {
    required String? me,
    required String? myName,
    required DateTime now,
    required bool card,
    required Set<String> signing,
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
    final onServer = {for (final c in cards) c.id};
    final marks = ref.watch(daybookMarksProvider);
    final extras = ref.watch(daybookExtrasProvider(_spaceId)).value;
    final names = ref.watch(spacePeopleProvider(_spaceId)).value;
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
        if (!onServer.contains(i.id))
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
    for (final s in shown) {
      byDay.putIfAbsent(dayOf(s.placedAt), () => []).add((
        s.placedAt,
        s.card.id,
        s,
      ));
      for (final (at, t) in _traces(s)) {
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

    Widget cardOf(_Shown s) {
      final c = s.card;
      final unsent = s.unsent;
      final refusedProof = s.refusedProof;
      final view = DaybookCardView(
        card: c,
        words: words,
        me: me,
        now: now,
        activityAt: s.at,
        viewer: viewer,
        waiting: s.waiting,
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
        // While writing, a tap on a card puts the card down, as anywhere
        // off it; a refused one reopens to fix; otherwise a short press
        // shows the card's menu (F16).
        onTap: _writing
            ? _stopWriting
            : unsent != null && unsent.refused
            ? () => unawaited(_reopen(unsent))
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
          // The card a row or a push opened (F20).
          child: BvHighlight(
            flash: _highlighted == c.id ? _flashes : null,
            // A post not on the server yet has nothing to do on it.
            child: unsent != null
                ? view
                : _loop.withActions(context, view, me: me, signing: signing),
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

    return GestureDetector(
      // While writing, a tap off the card puts it down.
      behavior: HitTestBehavior.opaque,
      onTap: _writing ? _stopWriting : null,
      // Pull down to read again; it always pulls, however short the page
      // (F11). The list runs bottom up: the pull is at its top.
      child: LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            key: const Key('daybook'),
            controller: _scroll,
            reverse: true,
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: BvCardSpec.paddingSide,
                  end: BvCardSpec.paddingSide,
                  top: BvCardSpec.paddingTop,
                  bottom: BvCardSpec.paddingBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BvCardSpec.gap,
                  children: [
                    for (final day in _days)
                      Column(
                        key: _dayKeys.putIfAbsent(day, GlobalKey.new),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: BvCardSpec.gap,
                        children: [
                          // Under a masthead naming the same day, it keeps
                          // its place but doesn't show (F23).
                          Visibility(
                            key: Key(
                              'daybook-divider-${day.toIso8601String()}',
                            ),
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
                          if (day == today && byDay[day]!.isEmpty)
                            Text(
                              l10n.daybookNothingYetToday,
                              key: const Key('daybook-nothing-today'),
                              textAlign: TextAlign.center,
                              style: BvType.of(
                                context,
                              ).labelSm.copyWith(color: BvColors.textSecondary),
                            ),
                          for (final (_, _, row) in byDay[day]!)
                            switch (row) {
                              _Shown s => cardOf(s),
                              _ => traceOf(row as _Trace),
                            },
                          if (card && day == today)
                            KeyedSubtree(
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
                                onPickStart: () => unawaited(_pickStart()),
                                onPickFile: () => unawaited(_pickFile()),
                                onPickPeople: () => unawaited(_pickPeople()),
                                askWho: _askWho,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
