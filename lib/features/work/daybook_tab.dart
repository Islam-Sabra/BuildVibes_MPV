import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/push/push_state.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_day_divider.dart';
import '../../shared/widgets/bv_daybook_masthead.dart';
import '../../shared/widgets/bv_daybook_spine.dart';
import '../../shared/widgets/bv_due_today_strip.dart';
import '../../shared/widgets/bv_first_page.dart';
import '../../shared/widgets/bv_month_dropdown.dart';
import '../../shared/widgets/bv_new_chip.dart';
import '../../shared/widgets/bv_post_bar.dart';
import '../../shared/widgets/bv_writing_toolbar.dart';
import '../account/account_parts.dart' show myMarketProvider;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/pass_words.dart';
import '../spaces/space_errors.dart';
import 'daybook_draft.dart';
import 'daybook_entry.dart';
import 'daybook_loop.dart';
import 'daybook_state.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart';
import 'work_outbox.dart';

/// The Space's Work tab: the daybook (D1). Today's masthead at the top, the
/// newest entries at the bottom; scrolling up goes back through older days
/// on the same page, each after a day divider (DY1), and the masthead
/// names the day at the top. Tapping it drops down the month (DY2). An
/// empty Space shows its first page (DY3); a Viewer reads only (V1).
///
/// The post bar's notepad writes a work item in place at "Now" (E1–E5):
/// the masthead shrinks to one line and the writing toolbar takes the post
/// bar's place. A card with anything in it stays as a Draft (E4).
///
/// The loop (part 1d) lives on the slips: Sign as done, double-tap to
/// check, long-press menus, swipe to add an update ([DaybookLoop]).
class DaybookTab extends ConsumerStatefulWidget {
  const DaybookTab({super.key, required this.space, this.startWriting = false});

  final SpaceDetail space;

  /// Opened from Create's "Work item in a Space" (F1): the card opens at
  /// Now, when the reader may write work items here.
  final bool startWriting;

  @override
  ConsumerState<DaybookTab> createState() => _DaybookTabState();
}

class _DaybookTabState extends ConsumerState<DaybookTab> {
  /// Older entries load while this much is left to scroll back.
  static const _loadAhead = 600.0;

  final _scroll = ScrollController();
  final _mastheadKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _dayKeys = <DateTime, GlobalKey>{};

  /// The loaded days, oldest first.
  var _days = <DateTime>[];

  /// The day the masthead names once scrolled back: the one at the top of
  /// the page. Null at rest on the newest posts: today.
  DateTime? _shownDay;

  /// Writing in place: the card is open with the keyboard's toolbar.
  var _writing = false;

  /// The card is a posted work item's, being edited (X1 Edit).
  var _editing = false;
  DaybookWritingMenu? _menu;

  /// Post was tapped with nobody to do it: picking someone posts it.
  var _postOnAssign = false;

  /// The card on the page was left from before: it says "Draft".
  late bool _fromBefore;

  late final DaybookWriter _writer = DaybookWriter(ref, _spaceId);
  late final DaybookWriter _editor = DaybookWriter(
    ref,
    _spaceId,
    editing: true,
  );
  late final AppLifecycleListener _life;

  /// New entries came in at Now while the reader was up in older ones
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
    _fromBefore = ref.read(daybookDraftProvider(_spaceId)) != null;
    // What was made with no signal sends when it's back: on opening and
    // on coming back to the app (the outbox also tries by itself). The
    // page is never stale (F11): it reads the newest entries when it
    // opens (from a push too), when the app comes back to the front, and
    // when a push for this Space arrives (build).
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
      _flush();
      // Kept from an earlier visit (another page of this Space is open
      // underneath): read again. A first load is already reading.
      if (mounted && ref.read(daybookPageProvider(_spaceId)).hasValue) {
        unawaited(_refresh());
      }
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
    _life.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _flush() {
    if (!mounted) return;
    unawaited(ref.read(workOutboxProvider.notifier).flush(_spaceId));
  }

  /// Reads the newest entries again, quietly; with no signal the page
  /// stays as it was.
  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      await ref.read(daybookPageProvider(_spaceId).notifier).refresh();
    } on SpaceException catch (e) {
      debugPrint('daybook refresh: $e');
    }
  }

  /// The reader is up in older entries, away from Now.
  bool get _away =>
      _scroll.hasClients && _scroll.offset > BvNewChipSpec.awayFromNow;

  /// New entries at Now while the reader is up in older ones: the page
  /// stays where it is, and the "New" chip shows. The list runs bottom
  /// up, so what came in below grows the scroll extent by its height.
  void _arrivedAtNow(List<DaybookRecord>? before, List<DaybookRecord> now) {
    if (before == null || before.isEmpty || !_away) return;
    final known = {for (final r in before) r.id};
    final pending = {for (final i in ref.read(workOutboxProvider)) i.id};
    final newest = before.first.at;
    final fresh = now.any(
      (r) =>
          !known.contains(r.id) &&
          !pending.contains(r.id) &&
          !r.at.isBefore(newest),
    );
    if (!fresh) return;
    final offset = _scroll.offset;
    final extent = _scroll.position.maxScrollExtent;
    setState(() => _newBelow = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final grown = _scroll.position.maxScrollExtent - extent;
      if (grown > 0) _scroll.jumpTo(offset + grown);
    });
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
    unawaited(ref.read(daybookPageProvider(_spaceId).notifier).loadOlder());
  }

  void _updateShownDay() {
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize || _days.isEmpty) return;
    if (!_scroll.hasClients || _scroll.offset <= 0) {
      if (_shownDay != null) setState(() => _shownDay = null);
      return;
    }
    final top = viewport.localToGlobal(Offset.zero).dy;
    DateTime? shown = _days.first;
    for (final day in _days) {
      final box =
          _dayKeys[day]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      if (box.localToGlobal(Offset.zero).dy <= top) shown = day;
    }
    if (shown != _shownDay) setState(() => _shownDay = shown);
  }

  /// Shows [day]: loads older pages until it is reached, then puts the
  /// latest day on or before it at the top.
  Future<void> _jumpTo(DateTime day) async {
    final provider = daybookPageProvider(_spaceId);
    final pages = ref.read(provider.notifier);
    for (;;) {
      final entries = ref.read(provider).value ?? const <DaybookRecord>[];
      if (entries.isEmpty ||
          !dayOf(entries.last.at).isAfter(day) ||
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
      _postOnAssign = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /// Edit a posted work item: its card opens at "Now", filled (X1 Edit).
  void _startEdit(DaybookPost post) {
    ref.read(daybookEditProvider(_spaceId).notifier).start(post);
    setState(() {
      _writing = true;
      _editing = true;
      _menu = null;
      _postOnAssign = false;
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
      _postOnAssign = false;
    });
  }

  void _setMenu(DaybookWritingMenu? menu) => setState(() {
    _menu = menu;
    if (menu != DaybookWritingMenu.assign) _postOnAssign = false;
  });

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

  /// Post with a title but nobody to do it: the assign picker opens, and
  /// picking someone posts it (review 46).
  void _postOrAssign(String? myName) {
    final draft = _writer.draft;
    if (draft == null || !draft.titleFits) return;
    if (draft.ownerId != null) {
      unawaited(_post(myName));
      return;
    }
    setState(() {
      _menu = DaybookWritingMenu.assign;
      _postOnAssign = true;
    });
  }

  void _assigned(String? myName) {
    if (_postOnAssign) {
      unawaited(_post(myName));
    } else {
      _setMenu(null);
    }
  }

  Future<void> _post(String? myName) async {
    await _writer.post(authorName: myName);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _writing = false;
      _menu = null;
      _postOnAssign = false;
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
    List<DaybookRecord> records,
    String? me,
    Set<String> signing,
  ) {
    final mine = [
      for (final r in records)
        if (r is DaybookPost &&
            r.isWorkItem &&
            r.isOpen &&
            r.item?.ownerId == me &&
            !signing.contains(r.id))
          r,
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
          ref.read(daybookPageProvider(_spaceId)).value ?? const [],
        ),
      );
    });
    // A push about this Space while it's open: read again (F11).
    ref.listen(pushArrivalProvider, (_, push) {
      if (push?.spaceId == _spaceId) unawaited(_refresh());
    });
    ref.listen(daybookPageProvider(_spaceId), (was, now) {
      final value = now.value;
      if (now.hasValue && value != null) _arrivedAtNow(was?.value, value);
    });
    final canPost = space.myRights.createItems;
    final page = ref.watch(daybookPageProvider(_spaceId));
    final due =
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
    final records = page.value ?? const <DaybookRecord>[];

    final shown = _shownDay ?? today;
    final waitingPosts = [
      for (final i in pending)
        if (i.kind == PendingKind.workItem) i,
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
    _openItems = canPost ? _toProve(records, me, signing) : const [];
    final prove = _openItems.firstOrNull;
    final cardDraft = _editing ? edit : draft;

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
            if (_writing)
              BvDaybookMasthead.compact(
                key: _mastheadKey,
                title: words.compactDate(today),
              )
            else
              BvDaybookMasthead(
                key: _mastheadKey,
                weekday: words.weekday(shown),
                dateLine: words.dateLine(shown, space.siteStartDate),
                onTap: () => _openMonth(today, shown),
              ),
            if (due.isNotEmpty && !_writing)
              BvDueTodayStrip(
                l10n.daybookDueTodayStrip(due.map((i) => i.title).join(' · ')),
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
                            onClose: () => _setMenu(null),
                            onAssigned: () => _assigned(myName),
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
                readOnly: l10n.daybookReadOnly,
              )
            else if (_writing)
              BvWritingToolbar(
                cameraLabel: l10n.daybookCamera,
                // An edit keeps its photos (slice 5 opens a post in place).
                onCamera: _editing
                    ? null
                    : () => _writer.addPhoto(camera: true),
                attachLabel: l10n.daybookAddPhoto,
                onAttach: _editing
                    ? null
                    : () => _writer.addPhoto(camera: false),
                moreLabel: l10n.daybookMore,
                onMore: () => _setMenu(
                  _menu == DaybookWritingMenu.more
                      ? null
                      : DaybookWritingMenu.more,
                ),
                moreActive: _menu == DaybookWritingMenu.more,
                postLabel: _editing ? l10n.daybookSave : l10n.daybookPost,
                // Post turns on with a title (review 46); with nobody to
                // do it, it opens the assign picker first.
                onPost: cardDraft?.titleFits ?? false
                    ? (_editing ? _save : () => _postOrAssign(myName))
                    : null,
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
                  unawaited(_writer.addPhoto(camera: true));
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

  /// A work item still in the outbox, as its slip at the time Post was
  /// tapped.
  DaybookPost _waitingPost(PendingItem i, String? me, DateTime now) =>
      DaybookPost(
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

  /// A sign-off still in the outbox, as its proof at the time it was sent.
  DaybookSignOff _waitingSignOff(PendingItem i, String? me, DateTime now) =>
      DaybookSignOff(
        id: '${PendingKind.signOff.json}-${i.id}',
        at: i.madeAt ?? now,
        postId: i.id,
        title: i.title,
        actorId: me,
        actorName: i.authorName,
        note: i.note,
        outcome: const DaybookOutcome(kind: DaybookOutcomeKind.done),
      );

  /// What the phone did that waits to be sent, shown on its slips: a
  /// cancel fades it, a check stamps it, a sign-off marks it done.
  DaybookRecord _asShown(
    DaybookRecord r,
    Map<String, PendingItem> cancels,
    Map<String, PendingItem> checks,
    Map<String, PendingItem> signOffs, {
    required String? me,
    required String? myName,
    required DateTime now,
  }) {
    switch (r) {
      case DaybookPost():
        final cancel = cancels[r.id];
        if (cancel != null) {
          return r.shownAs(
            stamp: DaybookStamp(
              kind: DaybookStampKind.cancelled,
              at: cancel.madeAt ?? now,
              byName: myName,
            ),
            cancelled: true,
          );
        }
        final check = checks[r.id];
        if (check != null) {
          return r.shownAs(
            stamp: DaybookStamp(
              kind: DaybookStampKind.checked,
              at: check.madeAt ?? now,
              byName: myName,
            ),
            status: WorkStatus.checked,
          );
        }
        final signOff = signOffs[r.id];
        if (signOff != null) {
          return r.shownAs(
            stamp: DaybookStamp(
              kind: DaybookStampKind.done,
              at: signOff.madeAt ?? now,
              byName: myName,
            ),
            status: WorkStatus.done,
          );
        }
        return r;
      case DaybookSignOff():
        final check = checks[r.postId];
        // The check is on the latest proof: the one that needed it.
        if (check == null || !r.needsMe) return r;
        return r.checkedBy(id: me, name: myName, at: check.madeAt ?? now);
      case DaybookSentBack():
      case DaybookUpdate():
        return r;
    }
  }

  Widget _diary(
    List<DaybookRecord> records,
    List<PendingItem> pending,
    DaybookWords words, {
    required String? me,
    required String? myName,
    required DateTime now,
    required bool card,
  }) {
    final l10n = AppLocalizations.of(context);
    final viewer = widget.space.myPass == SpacePass.viewer;
    final today = dayOf(now);
    final outbox = ref.read(workOutboxProvider.notifier);
    Map<String, PendingItem> byKind(PendingKind kind) => {
      for (final i in pending)
        if (i.kind == kind) i.id: i,
    };
    final cancels = byKind(PendingKind.cancel);
    final checks = byKind(PendingKind.check);
    final signOffs = byKind(PendingKind.signOff);
    // A refused proof isn't done: the item shows as the server has it.
    final sending = {
      for (final e in signOffs.entries)
        if (!e.value.refused) e.key: e.value,
    };
    // Work items, and their sign-offs and updates (other kinds of post
    // come in slice 2), with what still waits for a signal.
    final shown = [
      for (final r in records)
        if (r is! DaybookPost || r.isWorkItem)
          _asShown(
            r,
            cancels,
            checks,
            sending,
            me: me,
            myName: myName,
            now: now,
          ),
    ];
    final posts = {
      for (final r in shown)
        if (r is DaybookPost) r.id: r,
    };
    final onServer = {for (final r in shown) r.id};
    final unsent = {
      for (final i in pending)
        if (i.kind == PendingKind.workItem && !onServer.contains(i.id)) i.id: i,
    };
    // A proof waiting to be sent, until the server has the item as done;
    // a refused one stays on the phone until it is fixed or deleted.
    final unsentProofs = {
      for (final i in signOffs.values)
        if (i.refused ||
            records.whereType<DaybookPost>().any(
              (p) => p.id == i.id && p.item?.status == WorkStatus.open,
            ))
          '${PendingKind.signOff.json}-${i.id}': i,
    };
    final all =
        [
          ...shown,
          for (final i in unsent.values) _waitingPost(i, me, now),
          for (final i in unsentProofs.values) _waitingSignOff(i, me, now),
        ]..sort((a, b) {
          final t = a.at.compareTo(b.at);
          return t != 0 ? t : a.id.compareTo(b.id);
        });
    // Oldest first, grouped by the phone's own days; the card is today's.
    final byDay = <DateTime, List<DaybookRecord>>{};
    for (final r in all) {
      byDay.putIfAbsent(dayOf(r.at), () => []).add(r);
    }
    if (card) byDay.putIfAbsent(today, () => []);
    _days = byDay.keys.toList()..sort();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateShownDay();
      _loadOlderIfNear();
    });

    Widget entry(DaybookRecord r) {
      final waitingPost = unsent[r.id];
      final waitingProof = unsentProofs[r.id];
      final refused =
          (waitingPost?.refused ?? false) || (waitingProof?.refused ?? false);
      final slip = DaybookSlip(
        record: r,
        words: words,
        me: me,
        now: now,
        viewer: viewer,
        // Sent, it no longer waits, though the page hasn't read it yet
        // (F17). Under its undo bar, a proof isn't waiting for a signal
        // (F7).
        waiting:
            (waitingPost != null && !waitingPost.sent) ||
            (waitingProof != null &&
                !waitingProof.sent &&
                !outbox.isHeld(PendingKind.signOff, waitingProof.id)),
        couldNotSend: refused,
        localPhoto: (waitingPost ?? waitingProof)?.photos.firstOrNull?.local,
        landing:
            r is DaybookSignOff && outbox.isHeld(PendingKind.check, r.postId),
        checker: r is DaybookSignOff ? posts[r.postId]?.authorName : null,
        // While writing, a tap on a slip puts the card down, as anywhere
        // off it; otherwise a short press shows the slip's menu (F16).
        onTap: _writing
            ? _stopWriting
            : !refused
            ? null
            : waitingPost != null
            ? () => unawaited(_reopen(waitingPost))
            : () => unawaited(
                _loop.reopenProof(
                  context,
                  waitingProof!,
                  post: posts[waitingProof.id],
                ),
              ),
      );
      return DaybookEntry(
        words: words,
        slip: _loop.withActions(
          context,
          slip,
          me: me,
          posts: posts,
          signing: signOffs.keys.toSet(),
        ),
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
            child: BvDaybookSpine(
              minHeight: constraints.maxHeight,
              children: [
                for (final (i, day) in _days.indexed)
                  Column(
                    key: _dayKeys.putIfAbsent(day, GlobalKey.new),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BvSpineSpec.entryGap,
                    children: [
                      // The first day loaded sits under the masthead.
                      if (i > 0)
                        BvDayDivider(
                          weekday: words.weekday(day),
                          date: words.dayMonth(day),
                        ),
                      for (final r in byDay[day]!) entry(r),
                      if (card && day == today)
                        BvSpineEntry(
                          key: const Key('daybook-now'),
                          time: l10n.daybookNow,
                          dot: BvSpineDot.now,
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
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Day one (DY3): the first page, inset from the start over the spine.
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
        child: BvDaybookSpine(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  constraints.maxHeight -
                      BvSpineSpec.paddingTop -
                      BvSpineSpec.paddingBottom,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: BvFirstPageSpec.insetStart,
                  ),
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
          ],
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
