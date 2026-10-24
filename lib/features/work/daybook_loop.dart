import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/daybook_loop_specs.dart' show BvFieldSheetSpec;
import '../../core/design/daybook_writing_specs.dart' show BvUndoBarSpec;
import '../../core/haptics.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_field_sheet.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_send_back_card.dart';
import '../../shared/widgets/bv_undo_bar.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/former_member.dart';
import '../spaces/space_errors.dart';
import 'daybook_card.dart' show DaybookCardActions, DaybookCardView;
import 'daybook_marks.dart';
import 'daybook_page.dart' show mayEditPage, showDaybookPage;
import 'daybook_photos.dart';
import 'daybook_report_pdf.dart';
import 'daybook_target_card.dart' show showDaybookChild;
import 'daybook_state.dart';
import 'daybook_templates.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart' show assignablePeople, pickDueProvider;
import 'proof_camera.dart';
import 'work_outbox.dart';

/// What the long-press menus offer (B1 2530:33626, X1 2530:34246).
enum DaybookSlipAction {
  check,
  sendBack,
  update,
  edit,
  page,
  giveTo,
  unpin,

  /// Save as template (slice 7): a Lead or a Space admin.
  template,
  cancel,
}

/// The work item loop in one Space (slice 1 part 1d, on v13's cards): sign
/// as done with a photo or a note, check by double-tap with Undo, the
/// long-press menu, send back with a reason, updates, give to someone
/// else, cancel. What the reader may do comes from the card (needs_me) and
/// the pass; the server decides again on every call.
class DaybookLoop {
  DaybookLoop(
    this.ref,
    this.space, {
    required this.onEdit,
    this.openItems = const [],
  });

  final WidgetRef ref;
  final SpaceDetail space;

  /// The reader's open work items on the page, due soonest first: the
  /// proof screen offers them to switch to (review 47, answer 3).
  final List<DaybookPost> openItems;

  /// Edit opens the post's card in place (the daybook page holds it).
  final ValueChanged<DaybookPost> onEdit;

  String get _spaceId => space.id;
  bool get _viewer => space.myPass == SpacePass.viewer;

  /// The card's actions, as the reader [me] may use them. [signing] are
  /// the items with a sign-off waiting on the phone. Any card's quote opens
  /// its chat message (F87), for Viewers too.
  DaybookCardView withActions(
    BuildContext context,
    DaybookCardView view, {
    required String? me,
    required Set<String> signing,
  }) {
    final v = _withActions(context, view, me: me, signing: signing);
    final message = v.card.post.sourceMessageId;
    final newer = v.card.post.file?.newerPostId;
    if (message == null && newer == null) return v;
    return v.copyWith(
      actions: v.actions.withLinks(
        openQuote: message == null
            ? null
            : () => unawaited(openQuote(context, message)),
        // F76: the newer version's post, on its day.
        openNewer: newer == null
            ? null
            : () => unawaited(
                GoRouter.of(context).push(AppRoutes.spaceCard(_spaceId, newer)),
              ),
      ),
    );
  }

  /// F87: the Space chat at the message a post was made from, scrolled to
  /// it and highlighted, read back to it if older. A message that went
  /// (deleted, or no longer readable) opens nothing.
  Future<void> openQuote(BuildContext context, String messageId) =>
      openQuotedMessage(context, ref, spaceId: _spaceId, messageId: messageId);

  DaybookCardView _withActions(
    BuildContext context,
    DaybookCardView view, {
    required String? me,
    required Set<String> signing,
  }) {
    final card = view.card;
    final post = card.post;
    if (!post.isWorkItem) return _kindActions(context, view, me: me);
    // A Viewer reads: the page, nothing more.
    if (_viewer) {
      return view.copyWith(
        actions: DaybookCardActions(
          onOpenPage: _openPage(context, post),
          onOpenChild: (id) => unawaited(openChild(context, id)),
        ),
      );
    }
    final menu = _menu(card, me: me);
    final lifted = view.copyWith(lifted: true);
    void press(Rect at) =>
        unawaited(_longPress(context, card, lifted, at, menu, view.localPhoto));
    return view.copyWith(
      actions: DaybookCardActions(
        onMenu: menu.isEmpty ? null : press,
        onCheck: card.need == DaybookNeed.toCheck
            ? () => unawaited(check(context, card))
            : null,
        // Where the server puts the owner's clip (needs_me): never two on
        // one item.
        onSignDone:
            card.need == DaybookNeed.toSign &&
                post.isOpen &&
                post.item?.ownerId == me &&
                !signing.contains(post.id)
            ? () => unawaited(signDone(context, post))
            : null,
        onGiveTo: card.need == DaybookNeed.giveTo && post.isOpen
            ? (at) => unawaited(_giveTo(context, post, lifted, at))
            : null,
        onUpdate: !post.cancelled
            ? (_) => unawaited(_update(context, card, view.localPhoto))
            : null,
        onOpenPage: _openPage(context, post),
        onOpenChild: (id) => unawaited(openChild(context, id)),
      ),
    );
  }

  /// A target's work item, on its own card over the daybook (slice 6).
  Future<void> openChild(BuildContext context, String id) =>
      showDaybookChild(context, loop: this, childId: id);

  /// The post's page over the daybook (slice 5), for whoever sees it.
  VoidCallback _openPage(
    BuildContext context,
    DaybookPost post, {
    bool edit = false,
  }) =>
      () => unawaited(
        showDaybookPage(context, space: space, post: post, edit: edit),
      );

  /// Its author may edit its page now (the server decides again).
  bool _mayEditPage(DaybookPost post, String? me) =>
      mayEditPage(space, post, me, now: ref.read(clockProvider)());

  /// A checklist, an announcement, an activity or a file: tick a point
  /// (Lead and Crew), acknowledge (Viewers too), open the file, and for
  /// the author the menu's Cancel. Updates, checks and sign-offs are work
  /// items' only.
  DaybookCardView _kindActions(
    BuildContext context,
    DaybookCardView view, {
    required String? me,
  }) {
    final post = view.card.post;
    final menu = kindMenu(post, me: me);
    final lifted = view.copyWith(lifted: true);
    final fileId = post.file?.id;
    return view.copyWith(
      actions: DaybookCardActions(
        onMenu: menu.isEmpty
            ? null
            : (at) => unawaited(
                _longPress(context, view.card, lifted, at, menu, null),
              ),
        onTick: _viewer
            ? null
            : (point, {required on}) =>
                  unawaited(tick(context, post, point, on: on)),
        onAck: (kind, {required on}) =>
            unawaited(acknowledge(context, post, kind, on: on)),
        onOpenFile: fileId == null
            ? null
            : () => context.push(AppRoutes.libraryFile(_spaceId, fileId)),
        onOpenPage: _openPage(context, post),
        // A daily report's lines open their cards; Share as PDF (slice 7).
        onOpenChild: post.isReport
            ? (id) => unawaited(openChild(context, id))
            : null,
        onShareReport: post.isReport
            ? () => unawaited(shareReportPdf(context, ref, space, post))
            : null,
      ),
    );
  }

  /// Whether [me] is [post]'s author, or an admin acting for an author who
  /// has left the Space (review 62 N2).
  bool actsFor(DaybookPost post, {required String? me}) {
    if (post.authorId != null && post.authorId == me) return true;
    final people = ref.read(spacePeopleProvider(_spaceId)).value;
    final authorId = post.authorId;
    final gone =
        people != null && (authorId == null || people.member(authorId) == null);
    return gone && space.iAmAdmin;
  }

  /// The long-press menu of a note, a checklist, an announcement, an
  /// activity or a file, the same on its card and on the pinned note (F44):
  /// - its author: Edit (a note or an announcement) and Unpin (an
  ///   announcement, while pinned), then Cancel;
  /// - an admin, for an author who has left the Space: Unpin and Cancel,
  ///   never Edit: the words stay the author's (review 62 N2);
  /// - everyone else: nothing.
  List<DaybookSlipAction> kindMenu(DaybookPost post, {required String? me}) {
    if (post.cancelled || _viewer) return const [];
    final mine = post.authorId != null && post.authorId == me;
    final announcement = post.kind == DaybookPost.announcementKind;
    final actsForAuthor = actsFor(post, me: me);
    return [
      if (mine && (announcement || post.isNote)) DaybookSlipAction.edit,
      if (mine && _mayEditPage(post, me)) DaybookSlipAction.page,
      if (actsForAuthor && announcement && post.pinnedUntil != null)
        DaybookSlipAction.unpin,
      if (_savesAsTemplate(post)) DaybookSlipAction.template,
      if (actsForAuthor) DaybookSlipAction.cancel,
    ];
  }

  /// Save as template (slice 7): for a Lead or a Space admin, on a work
  /// item, checklist, announcement or report.
  bool _savesAsTemplate(DaybookPost post) =>
      mayManageTemplates(space) && savesAsTemplate(post);

  /// Saves [post]'s words as a template; at the Space's 50 it offers Space
  /// info › Templates.
  Future<void> saveTemplate(BuildContext context, DaybookPost post) {
    final router = GoRouter.of(context);
    return saveAsTemplate(
      context,
      ref,
      post,
      spaceId: _spaceId,
      onOpenList: () => router.push(AppRoutes.spaceTemplates(_spaceId)),
    );
  }

  /// The pinned note's long-press menu (F44), full or folded: [lifted] is
  /// the note as it stands, raised over the dimmed page.
  Future<void> pinnedMenu(
    BuildContext context,
    DaybookPost post,
    Widget lifted,
    Rect at, {
    required String? me,
  }) async {
    final menu = kindMenu(post, me: me);
    if (menu.isEmpty) return;
    final picked = await _pick(context, lifted, at, menu, workItem: false);
    if (picked == null || !context.mounted) return;
    switch (picked) {
      case DaybookSlipAction.edit:
        onEdit(post);
      case DaybookSlipAction.page:
        _openPage(context, post, edit: true)();
      case DaybookSlipAction.unpin:
        await unpin(context, post);
      case DaybookSlipAction.template:
        await saveTemplate(context, post);
      case DaybookSlipAction.cancel:
        await cancel(context, post);
      default:
        break;
    }
  }

  /// Unpin (F44): the announcement becomes an ordinary card on its day; it
  /// doesn't move to Now.
  Future<void> unpin(BuildContext context, DaybookPost post) async {
    try {
      await ref
          .read(daybookRepositoryProvider)
          .editPost(post.id, const PostEdit.unpin());
    } on SpaceException catch (e) {
      if (context.mounted) showSpaceError(context, e);
      return;
    }
    ref.invalidate(daybookExtrasProvider(_spaceId));
    await refresh();
  }

  /// Ticks or unticks [point] on [post]: it shows at once, and the card
  /// moves to Now (everyone who sees it sees the tick).
  Future<void> tick(
    BuildContext context,
    DaybookPost post,
    DaybookPoint point, {
    required bool on,
  }) => _mark(
    context,
    DaybookMark(
      spaceId: _spaceId,
      postId: post.id,
      on: on,
      at: ref.read(clockProvider)(),
      pointId: point.id,
      pointText: point.text,
    ),
  );

  /// Got it, Received, Add to my calendar or On my way, or taking one
  /// back. Only a Received moves the card (review 60 S1). [again] gives it
  /// anew, at this time: an announcement edited since its Got it (review 61
  /// G1), whose old Got it is taken back first.
  Future<void> acknowledge(
    BuildContext context,
    DaybookPost post,
    DaybookAck kind, {
    required bool on,
    bool again = false,
  }) async {
    if (on) unawaited(HapticFeedback.lightImpact());
    DaybookMark mark({required bool on}) => DaybookMark(
      spaceId: _spaceId,
      postId: post.id,
      on: on,
      at: ref.read(clockProvider)(),
      ack: kind,
    );
    await _mark(context, mark(on: on), again: again && on);
  }

  Future<void> _mark(
    BuildContext context,
    DaybookMark mark, {
    bool again = false,
  }) async {
    try {
      await ref.read(daybookMarksProvider.notifier).send(mark, again: again);
    } on SpaceException catch (e) {
      if (context.mounted) showSpaceError(context, e);
    }
  }

  /// The menu, in the order of review 53: Check, Send back, Add update,
  /// Edit, Give to someone else, Cancel, as allowed.
  List<DaybookSlipAction> _menu(DaybookCard card, {required String? me}) {
    final post = card.post;
    if (post.cancelled) return const [];
    final mine = post.authorId != null && post.authorId == me;
    final checked = post.item?.status == WorkStatus.checked;
    return [
      if (card.need == DaybookNeed.toCheck) ...[
        DaybookSlipAction.check,
        DaybookSlipAction.sendBack,
      ],
      DaybookSlipAction.update,
      if (mine && post.isOpen) DaybookSlipAction.edit,
      if (_mayEditPage(post, me)) DaybookSlipAction.page,
      if ((mine || card.need == DaybookNeed.giveTo) && post.isOpen)
        DaybookSlipAction.giveTo,
      if (_savesAsTemplate(post)) DaybookSlipAction.template,
      if (mine && !checked) DaybookSlipAction.cancel,
    ];
  }

  Future<void> _longPress(
    BuildContext context,
    DaybookCard card,
    DaybookCardView lifted,
    Rect at,
    List<DaybookSlipAction> menu,
    String? localPhoto,
  ) async {
    final picked = await _pick(
      context,
      lifted,
      at,
      menu,
      workItem: card.post.isWorkItem,
    );
    if (picked == null || !context.mounted) return;
    final post = card.post;
    switch (picked) {
      case DaybookSlipAction.check:
        await check(context, card);
      case DaybookSlipAction.sendBack:
        await _sendBack(context, card, localPhoto);
      case DaybookSlipAction.update:
        await _update(context, card, localPhoto);
      case DaybookSlipAction.edit:
        onEdit(post);
      case DaybookSlipAction.page:
        _openPage(context, post, edit: true)();
      case DaybookSlipAction.giveTo:
        await _giveTo(context, post, lifted, at);
      case DaybookSlipAction.unpin:
        await unpin(context, post);
      case DaybookSlipAction.template:
        await saveTemplate(context, post);
      case DaybookSlipAction.cancel:
        await cancel(context, post);
    }
  }

  /// [lifted] raised over the dimmed page with [menu] beside it; what was
  /// picked, or null.
  Future<DaybookSlipAction?> _pick(
    BuildContext context,
    Widget lifted,
    Rect at,
    List<DaybookSlipAction> menu, {
    required bool workItem,
  }) {
    final l10n = AppLocalizations.of(context);
    unawaited(HapticFeedback.mediumImpact());
    return showBvLifted<DaybookSlipAction>(
      context,
      anchor: at,
      lifted: lifted,
      popover: (menuContext) => BvSlipMenu<DaybookSlipAction>(
        key: const Key('slip-menu'),
        items: [for (final a in menu) _item(l10n, a, workItem: workItem)],
        onSelected: (a) => Navigator.of(menuContext).pop(a),
      ),
    );
  }

  static BvSlipMenuItem<DaybookSlipAction> _item(
    AppLocalizations l10n,
    DaybookSlipAction a, {
    required bool workItem,
  }) => switch (a) {
    DaybookSlipAction.check => BvSlipMenuItem(
      value: a,
      label: l10n.daybookCheck,
      icon: BvIcons.check,
      tone: BvSlipMenuTone.positive,
    ),
    DaybookSlipAction.sendBack => BvSlipMenuItem(
      value: a,
      label: l10n.daybookSendBack,
      icon: BvIcons.sendBack,
      tone: BvSlipMenuTone.destructive,
    ),
    DaybookSlipAction.update => BvSlipMenuItem(
      value: a,
      label: l10n.daybookAddUpdate,
      icon: BvIcons.add,
    ),
    // Figma draws Edit with dots-three, not a pencil.
    DaybookSlipAction.edit => BvSlipMenuItem(
      value: a,
      label: l10n.daybookEdit,
      icon: BvIcons.more,
    ),
    DaybookSlipAction.page => BvSlipMenuItem(
      value: a,
      label: l10n.pageEdit,
      icon: BvIcons.edit,
    ),
    DaybookSlipAction.giveTo => BvSlipMenuItem(
      value: a,
      label: l10n.daybookGiveTo,
      icon: BvIcons.person,
    ),
    DaybookSlipAction.unpin => BvSlipMenuItem(
      value: a,
      label: l10n.daybookUnpin,
      icon: BvIcons.pin,
    ),
    DaybookSlipAction.template => BvSlipMenuItem(
      value: a,
      label: l10n.templateSave,
      icon: BvIcons.clipboard,
    ),
    DaybookSlipAction.cancel => BvSlipMenuItem(
      value: a,
      label: workItem ? l10n.daybookCancelItem : l10n.daybookCancelPost,
      icon: BvIcons.close,
      tone: BvSlipMenuTone.destructive,
    ),
  };

  /// Check (B3): the stamp lands with a strong haptic, and "Checked ·
  /// Undo" shows for 5 seconds. Only then is the check sent (review 44,
  /// answer 4); Undo takes it back before anything reaches the server.
  Future<void> check(BuildContext context, DaybookCard card) async {
    final l10n = AppLocalizations.of(context);
    unawaited(bvHaptic(BvHaptic.strong));
    final outbox = ref.read(workOutboxProvider.notifier);
    final post = card.post;
    await outbox.hold(
      PendingItem(
        kind: PendingKind.check,
        id: post.id,
        spaceId: _spaceId,
        title: post.title,
        ownerId: card.proof?.byId ?? post.item?.ownerId ?? '',
        ownerName: card.proof?.byName ?? post.item?.ownerName ?? '',
        madeAt: ref.read(clockProvider)(),
      ),
      BvUndoBarSpec.duration,
    );
    if (!context.mounted) return;
    showBvUndoBar(
      context,
      message: l10n.daybookChecked,
      actionLabel: l10n.daybookUndo,
      onAction: () => unawaited(outbox.undo(PendingKind.check, post.id)),
    );
  }

  /// Cancel work item: the slip fades with CANCELLED at once, and
  /// "Cancelled · Undo" shows; it is sent when the bar goes.
  Future<void> cancel(BuildContext context, DaybookPost p) async {
    final l10n = AppLocalizations.of(context);
    final outbox = ref.read(workOutboxProvider.notifier);
    await outbox.hold(
      PendingItem(
        kind: PendingKind.cancel,
        id: p.id,
        spaceId: _spaceId,
        title: p.title,
        ownerId: p.item?.ownerId ?? '',
        ownerName: p.item?.ownerName ?? '',
        madeAt: ref.read(clockProvider)(),
      ),
      BvUndoBarSpec.duration,
    );
    if (!context.mounted) return;
    showBvUndoBar(
      context,
      message: l10n.daybookCancelled,
      actionLabel: l10n.daybookUndo,
      onAction: () => unawaited(outbox.undo(PendingKind.cancel, p.id)),
    );
  }

  /// Sign as done (O1 → O2): only opens the proof screen, the camera one
  /// tap away and "Without a photo" (F6, F7). Nothing is sent until Send
  /// as done there, and then only once the undo bar has gone.
  Future<void> signDone(BuildContext context, DaybookPost p) =>
      _prove(context, p, photos: const []);

  /// A refused sign-off ("Couldn't send. Tap to fix", answer 5): the proof
  /// again with its photos and note, to send again or for another item.
  Future<void> reopenProof(
    BuildContext context,
    PendingItem item, {
    DaybookPost? post,
  }) => _prove(
    context,
    post ?? _itemFor(item),
    photos: item.photos,
    note: item.note,
    refused: item,
  );

  /// The work item a held or refused sign-off proves.
  DaybookPost _itemFor(PendingItem item) =>
      openItems.where((p) => p.id == item.id).firstOrNull ??
      DaybookPost(
        id: item.id,
        kind: DaybookPost.workItemKind,
        createdAt: item.madeAt ?? ref.read(clockProvider)(),
        title: item.title,
        place: item.photos.firstOrNull?.place,
      );

  /// The proof screen. Sent, "Signed as done · Undo" shows for 5 seconds
  /// while the sign-off waits on the phone (F7; review 44, answer 4).
  Future<void> _prove(
    BuildContext context,
    DaybookPost p, {
    required List<PendingPhoto> photos,
    String? note,
    PendingItem? refused,
  }) async {
    final sent = await Navigator.of(context).push<PendingItem>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProofCamera(
          spaceId: _spaceId,
          post: p,
          photos: photos,
          choices: openItems,
          note: note,
          refused: refused,
        ),
      ),
    );
    if (sent == null || !context.mounted) return;
    showBvUndoBar(
      context,
      message: AppLocalizations.of(context).daybookSignedUndo,
      actionLabel: AppLocalizations.of(context).daybookUndo,
      onAction: () => unawaited(_undoSignOff(context, sent)),
    );
  }

  /// Undo: the sign-off never leaves the phone, and the proof screen opens
  /// again with its photos and note, so nothing is lost.
  Future<void> _undoSignOff(BuildContext context, PendingItem sent) async {
    await ref
        .read(workOutboxProvider.notifier)
        .undo(PendingKind.signOff, sent.id);
    if (!context.mounted) return;
    await _prove(context, _itemFor(sent), photos: sent.photos, note: sent.note);
  }

  /// Send back with a reason (B2), on a sheet that sits on the keyboard,
  /// the item quoted in one line (F24).
  Future<void> _sendBack(
    BuildContext context,
    DaybookCard card,
    String? localPhoto,
  ) async {
    final post = card.post;
    final l10n = AppLocalizations.of(context);
    final result =
        await showBvFieldSheet<(SendBackReason, String?, SendBackDue)>(
          context: context,
          title: l10n.daybookSendBackTo(
            personFirstName(l10n, card.proof?.byName ?? post.item?.ownerName),
          ),
          builder: (_) => DaybookSendBack(
            quote: DaybookItemQuote(card: card, localPhoto: localPhoto),
          ),
        );
    if (result == null || !context.mounted) return;
    // On the phone first: with no signal it waits and goes by itself
    // (slice 10).
    await ref
        .read(workOutboxProvider.notifier)
        .send(
          PendingItem(
            kind: PendingKind.sendBack,
            id: post.id,
            spaceId: _spaceId,
            title: post.title,
            ownerId: post.item?.ownerId ?? '',
            ownerName: post.item?.ownerName ?? '',
            body: result.$1.json,
            note: result.$2,
            dueDate: result.$3.day,
            dueAt: result.$3.at,
            madeAt: ref.read(clockProvider)(),
          ),
        );
  }

  /// An update (Y1 → Y2): one line on a sheet that sits on the keyboard,
  /// the item quoted in one line above it (W1 v13c 2582:77206, F24).
  Future<void> _update(
    BuildContext context,
    DaybookCard card,
    String? localPhoto,
  ) async {
    final postId = card.id;
    final text = await showBvFieldSheet<String>(
      context: context,
      title: AppLocalizations.of(context).daybookAddUpdate,
      builder: (_) => DaybookUpdateField(
        quote: DaybookItemQuote(card: card, localPhoto: localPhoto),
      ),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    await ref
        .read(workOutboxProvider.notifier)
        .send(
          PendingItem(
            kind: PendingKind.update,
            id: newUuid(),
            postId: postId,
            spaceId: _spaceId,
            title: card.post.title,
            ownerId: card.post.item?.ownerId ?? '',
            ownerName: card.post.item?.ownerName ?? '',
            body: text,
            madeAt: ref.read(clockProvider)(),
          ),
        );
  }

  /// Give to someone else (X2): Lead and Crew only, the owner marked
  /// "now".
  Future<void> _giveTo(
    BuildContext context,
    DaybookPost p,
    DaybookCardView lifted,
    Rect at,
  ) async {
    final l10n = AppLocalizations.of(context);
    final people = await ref.read(spacePeopleProvider(_spaceId).future);
    if (!context.mounted) return;
    final picked = await showBvLifted<BvGiveToPerson>(
      context,
      anchor: at,
      lifted: lifted,
      popover: (pickerContext) => BvGiveToPicker(
        key: const Key('give-to'),
        // Only the author gives it away: they are the reader.
        people: assignablePeople(people, me: p.authorId),
        currentOwnerId: p.item?.ownerId,
        currentLabel: l10n.daybookOwnerNow,
        searchPlaceholder: l10n.daybookGiveToSearch,
        onPick: (person) => Navigator.of(pickerContext).pop(person),
      ),
    );
    if (picked == null || picked.id == p.item?.ownerId || !context.mounted) {
      return;
    }
    await ref
        .read(workOutboxProvider.notifier)
        .send(
          PendingItem(
            kind: PendingKind.giveTo,
            id: p.id,
            spaceId: _spaceId,
            title: p.title,
            ownerId: picked.id,
            ownerName: picked.name,
            madeAt: ref.read(clockProvider)(),
          ),
        );
  }

  /// "Couldn't check: this item was cancelled". [cards] is the page read
  /// again: when the server only says the item changed, it tells how.
  static String refusalText(
    AppLocalizations l10n,
    DaybookRefusal r,
    List<DaybookCard> cards,
  ) {
    final action = switch (r.action) {
      RefusedAction.check => l10n.daybookCouldNotCheck,
      RefusedAction.sendBack => l10n.daybookCouldNotSendBack,
      RefusedAction.cancel => l10n.daybookCouldNotCancel,
      RefusedAction.giveTo => l10n.daybookCouldNotGiveTo,
      RefusedAction.update => l10n.daybookCouldNotUpdate,
      RefusedAction.tick => l10n.daybookCouldNotTick,
      RefusedAction.ack => l10n.daybookCouldNotAck,
    };
    var why = r.why;
    if (why == RefusalWhy.changed) {
      final post = cards.where((c) => c.id == r.postId).firstOrNull?.post;
      if (post?.cancelled ?? false) {
        why = RefusalWhy.cancelled;
      } else if (post?.item?.status == WorkStatus.checked) {
        why = RefusalWhy.checked;
      }
    }
    final reason = switch (why) {
      RefusalWhy.cancelled => l10n.daybookWhyCancelled,
      RefusalWhy.checked => l10n.daybookWhyChecked,
      RefusalWhy.changed => l10n.daybookWhyChanged,
      RefusalWhy.removed => l10n.daybookWhyRemoved,
      RefusalWhy.notAllowed => l10n.daybookWhyNotAllowed,
      RefusalWhy.unknown => null,
    };
    return reason == null
        ? l10n.daybookRefusedPlain(action)
        : l10n.daybookRefusedBecause(action, reason);
  }

  Future<void> refresh() async {
    ref
      ..invalidate(daybookChildCardProvider)
      ..invalidate(mySpacesProvider)
      ..invalidate(daybookDueTodayProvider(_spaceId));
    try {
      await ref.read(daybookCardsProvider(_spaceId).notifier).refresh();
    } on SpaceException {
      // The page catches up on its next read.
    }
  }
}

/// The send-back sheet's state (B2): the item quoted, one reason, an
/// optional note ("Something else" needs one). Pops with the reason and
/// the note. No microphone: send_back takes no voice note.
class DaybookSendBack extends ConsumerStatefulWidget {
  const DaybookSendBack({super.key, required this.quote});

  /// The item, in one line.
  final Widget quote;

  @override
  ConsumerState<DaybookSendBack> createState() => _DaybookSendBackState();
}

/// The new date on a send-back (F62, F64): Today, Tomorrow or a picked
/// day, all optional, nothing chosen first.
enum _NewDue { today, tomorrow, pick }

class _DaybookSendBackState extends ConsumerState<DaybookSendBack> {
  final _note = TextEditingController();
  SendBackReason? _reason;
  _NewDue? _due;

  /// The day (and time) picked for [_NewDue.pick].
  SendBackDue? _picked;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// A date is optional (F64): the reason is enough.
  bool get _ready =>
      _reason != null &&
      (_reason != SendBackReason.other || _note.text.trim().isNotEmpty);

  /// What the server gets: the chosen day, or none.
  SendBackDue get _newDue {
    final today = dayOf(ref.read(clockProvider)());
    return switch (_due) {
      _NewDue.today => (day: today, at: null),
      _NewDue.tomorrow => (
        day: DateTime(today.year, today.month, today.day + 1),
        at: null,
      ),
      _NewDue.pick => _picked!,
      null => (day: null, at: null),
    };
  }

  /// A tap on the chosen chip un-chooses it (F64); a tap on another
  /// chooses that one.
  void _tap(_NewDue d) {
    if (_due == d) {
      setState(() {
        _due = null;
        _picked = null;
      });
    } else if (d == _NewDue.pick) {
      unawaited(_pick());
    } else {
      setState(() => _due = d);
    }
  }

  Future<void> _pick() async {
    final picked = await ref.read(pickDueProvider)(
      context,
      now: ref.read(clockProvider)(),
    );
    // Taking the day off isn't a date: keep what was chosen before.
    if (!mounted || picked == null || picked.day == null) return;
    setState(() {
      _picked = (day: picked.day, at: picked.at);
      _due = _NewDue.pick;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final picked = _picked;
    BvSendBackDue choice(_NewDue d, String label, {IconData? icon}) => (
      key: Key('send-back-due-${d.name}'),
      label: label,
      icon: icon,
      selected: _due == d,
      onTap: () => _tap(d),
    );
    return BvSendBackCard<SendBackReason>.inSheet(
      key: const Key('send-back-card'),
      quote: widget.quote,
      reasons: [
        for (final r in SendBackReason.values)
          (value: r, label: words.reason(r)),
      ],
      selected: _reason,
      onSelected: (r) => setState(() => _reason = r),
      dueLabel: l10n.daybookSendBackNewDate,
      dues: [
        choice(_NewDue.today, l10n.daybookSendBackToday),
        choice(_NewDue.tomorrow, l10n.daybookSendBackTomorrow),
        choice(
          _NewDue.pick,
          picked?.day == null
              ? l10n.daybookSendBackPickDate
              : words.dueProperty(picked!.day!, picked.at),
          icon: BvIcons.due,
        ),
      ],
      noteController: _note,
      notePlaceholder: _reason == SendBackReason.other
          ? l10n.daybookNoteNeeded
          : l10n.daybookNoteOptional,
      onNoteChanged: (_) => setState(() {}),
      sendLabel: l10n.daybookSendBack,
      onSend: _ready
          ? () {
              final note = _note.text.trim();
              Navigator.of(
                context,
              ).pop((_reason!, note.isEmpty ? null : note, _newDue));
            }
          : null,
    );
  }
}

/// The Add update sheet's content: the item quoted in one line, then one
/// line for the update and its send button. Pops with the text, on the
/// button or the keyboard's send key.
class DaybookUpdateField extends StatefulWidget {
  const DaybookUpdateField({super.key, required this.quote});

  /// The item, in one line.
  final Widget quote;

  @override
  State<DaybookUpdateField> createState() => _DaybookUpdateFieldState();
}

class _DaybookUpdateFieldState extends State<DaybookUpdateField> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = _text.text.trim();
    return Column(
      key: const Key('update-field'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvFieldSheetSpec.gap,
      children: [
        widget.quote,
        BvSendField(
          controller: _text,
          placeholder: l10n.daybookUpdateHint,
          sendLabel: l10n.daybookSendUpdate,
          maxLength: updateMax,
          onChanged: (_) => setState(() {}),
          onSend: text.isEmpty
              ? null
              : () => Navigator.of(context).pop(_text.text),
        ),
      ],
    );
  }

  /// An update's length (the same as a note).
  static const updateMax = 1000;
}

/// The work item quoted in one line on a sheet (F24): its ref and title,
/// and a small thumbnail of its latest photo.
class DaybookItemQuote extends ConsumerWidget {
  const DaybookItemQuote({super.key, required this.card, this.localPhoto});

  final DaybookCard card;

  /// A sign-off's photo still on the phone.
  final String? localPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final post = card.post;
    final itemRef = post.item?.ref;
    final title = inOwnDirection(post.title);
    final local = localPhoto;
    final path = card.proof?.photos.firstOrNull?.path ?? post.coverPath;
    return BvItemQuote(
      text: itemRef == null ? title : l10n.daybookQuote(itemRef, title),
      image: local != null
          ? ref.watch(localPhotoProvider(local))
          : path == null
          ? null
          : ref.watch(daybookPhotoProvider(path)),
    );
  }
}

/// F87: the Space chat at the message [messageId] (a quote's), scrolled to
/// it and highlighted, read back to it if older. A message that went
/// (deleted, or no longer readable) opens nothing.
Future<void> openQuotedMessage(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  required String messageId,
}) async {
  final router = GoRouter.of(context);
  final message = await ref
      .read(chatRepositoryProvider)
      .message(messageId)
      .catchError((Object _) => null);
  if (message == null || message.deletedAt != null) return;
  await router.push(
    AppRoutes.spaceThread(spaceId, message.threadId, message: messageId),
  );
}
