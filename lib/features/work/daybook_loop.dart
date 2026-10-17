import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/daybook_writing_specs.dart' show BvUndoBarSpec;
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_send_back_card.dart';
import '../../shared/widgets/bv_undo_bar.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/former_member.dart';
import '../spaces/space_errors.dart';
import 'daybook_entry.dart' show DaybookSlip, DaybookSlipActions;
import 'daybook_state.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart' show assignablePeople;
import 'proof_camera.dart';
import 'work_outbox.dart';

/// What the long-press menus offer (B1 2530:33626, X1 2530:34246).
enum DaybookSlipAction { check, sendBack, update, edit, giveTo, cancel }

/// The work item loop in one Space (slice 1 part 1d): sign as done with
/// the camera, check by double-tap with Undo, the long-press menus, send
/// back with a reason, updates, give to someone else, cancel. What the
/// reader may do comes from the record and the pass; the server decides
/// again on every call.
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

  /// The slip's actions for [record], as the reader [me] may use them.
  /// [posts] are the work items on the page, by id; [signing] the items
  /// with a sign-off waiting to be sent.
  DaybookSlip withActions(
    BuildContext context,
    DaybookSlip slip, {
    required String? me,
    required Map<String, DaybookPost> posts,
    required Set<String> signing,
  }) {
    final r = slip.record;
    if (_viewer || slip.waiting || r is DaybookUpdate) return slip;
    final menu = _menu(r, me: me, posts: posts);
    final lifted = slip.copyWith(lifted: true);
    void press(Rect at) => unawaited(_longPress(context, r, lifted, at, menu));
    return slip.copyWith(
      actions: DaybookSlipActions(
        onLongPress: menu.isEmpty ? null : press,
        onCheck: r is DaybookSignOff && r.needsMe
            ? () => unawaited(check(context, r))
            : null,
        // Where the server puts the owner's clip (needs_me): the latest
        // send-back of an item sent back, else the item's own slip. Never
        // two on one item.
        onSignDone: switch (r) {
          DaybookPost()
              when r.needsMe &&
                  r.isOpen &&
                  r.item?.ownerId == me &&
                  !signing.contains(r.id) =>
            () => unawaited(signDone(context, r)),
          DaybookSentBack()
              when r.needsMe && !r.cancelled && !signing.contains(r.postId) =>
            () => unawaited(signDone(context, posts[r.postId] ?? _itemOf(r))),
          _ => null,
        },
        onUpdate: r is DaybookPost && !r.cancelled
            ? (at) => unawaited(_update(context, r.id, lifted, at))
            : null,
      ),
    );
  }

  List<DaybookSlipAction> _menu(
    DaybookRecord r, {
    required String? me,
    required Map<String, DaybookPost> posts,
  }) {
    switch (r) {
      case DaybookSignOff():
        final live = r.outcome.kind != DaybookOutcomeKind.cancelled;
        return [
          if (r.needsMe) ...[
            DaybookSlipAction.check,
            DaybookSlipAction.sendBack,
          ],
          if (live) DaybookSlipAction.update,
        ];
      case DaybookPost():
        if (r.cancelled) return const [];
        final mine = r.authorId != null && r.authorId == me;
        final checked = r.item?.status == WorkStatus.checked;
        return [
          if (mine && r.isOpen) DaybookSlipAction.edit,
          DaybookSlipAction.update,
          if (mine && r.isOpen) DaybookSlipAction.giveTo,
          if (mine && !checked) DaybookSlipAction.cancel,
        ];
      case DaybookSentBack():
        return [if (!r.cancelled) DaybookSlipAction.update];
      case DaybookUpdate():
        return const [];
    }
  }

  /// The work item a send-back quotes, when its own slip isn't loaded (an
  /// older page): enough to prove it.
  static DaybookPost _itemOf(DaybookSentBack b) => DaybookPost(
    id: b.postId,
    kind: DaybookPost.workItemKind,
    createdAt: b.at,
    title: b.title,
    item: DaybookItem(status: b.itemStatus, ref: b.ref),
  );

  Future<void> _longPress(
    BuildContext context,
    DaybookRecord r,
    DaybookSlip lifted,
    Rect at,
    List<DaybookSlipAction> menu,
  ) async {
    final l10n = AppLocalizations.of(context);
    unawaited(HapticFeedback.mediumImpact());
    final picked = await showBvLifted<DaybookSlipAction>(
      context,
      anchor: at,
      lifted: lifted,
      popover: (menuContext) => BvSlipMenu<DaybookSlipAction>(
        key: const Key('slip-menu'),
        items: [for (final a in menu) _item(l10n, a)],
        onSelected: (a) => Navigator.of(menuContext).pop(a),
      ),
    );
    if (picked == null || !context.mounted) return;
    switch ((picked, r)) {
      case (DaybookSlipAction.check, DaybookSignOff s):
        await check(context, s);
      case (DaybookSlipAction.sendBack, DaybookSignOff s):
        await _sendBack(context, s, lifted, at);
      case (DaybookSlipAction.update, _):
        await _update(context, r.postId, lifted, at);
      case (DaybookSlipAction.edit, DaybookPost p):
        onEdit(p);
      case (DaybookSlipAction.giveTo, DaybookPost p):
        await _giveTo(context, p, lifted, at);
      case (DaybookSlipAction.cancel, DaybookPost p):
        await cancel(context, p);
      case _:
        break;
    }
  }

  static BvSlipMenuItem<DaybookSlipAction> _item(
    AppLocalizations l10n,
    DaybookSlipAction a,
  ) => switch (a) {
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
    DaybookSlipAction.giveTo => BvSlipMenuItem(
      value: a,
      label: l10n.daybookGiveTo,
      icon: BvIcons.person,
    ),
    DaybookSlipAction.cancel => BvSlipMenuItem(
      value: a,
      label: l10n.daybookCancelItem,
      icon: BvIcons.close,
      tone: BvSlipMenuTone.destructive,
    ),
  };

  /// Check (B3): the stamp lands with a strong haptic, and "Checked ·
  /// Undo" shows for 5 seconds. Only then is the check sent (review 44,
  /// answer 4); Undo takes it back before anything reaches the server.
  Future<void> check(BuildContext context, DaybookSignOff s) async {
    final l10n = AppLocalizations.of(context);
    unawaited(HapticFeedback.heavyImpact());
    final outbox = ref.read(workOutboxProvider.notifier);
    await outbox.hold(
      PendingItem(
        kind: PendingKind.check,
        id: s.postId,
        spaceId: _spaceId,
        title: s.title,
        ownerId: s.actorId ?? '',
        ownerName: s.actorName ?? '',
        madeAt: ref.read(clockProvider)(),
      ),
      BvUndoBarSpec.duration,
    );
    if (!context.mounted) return;
    showBvUndoBar(
      context,
      message: l10n.daybookChecked,
      actionLabel: l10n.daybookUndo,
      onAction: () => unawaited(outbox.undo(PendingKind.check, s.postId)),
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

  /// Sign as done with the camera (O1 → O2): the camera first (never the
  /// gallery: founder, review 47), then the proof with an optional note.
  Future<void> signDone(BuildContext context, DaybookPost p) async {
    final picked = await ref.read(pickPhotoProvider)(camera: true);
    if (picked == null || !context.mounted) return;
    final kept = await ref.read(keepPhotoProvider)(picked);
    if (!context.mounted) return;
    await _prove(
      context,
      p,
      photos: [
        PendingPhoto(
          local: kept,
          takenAt: ref.read(clockProvider)(),
          place: p.place,
        ),
      ],
    );
  }

  /// A refused sign-off ("Couldn't send. Tap to fix", answer 5): the proof
  /// again with its photos and note, to send again or for another item.
  Future<void> reopenProof(
    BuildContext context,
    PendingItem item, {
    DaybookPost? post,
  }) => _prove(
    context,
    post ??
        DaybookPost(
          id: item.id,
          kind: DaybookPost.workItemKind,
          createdAt: item.madeAt ?? ref.read(clockProvider)(),
          title: item.title,
          place: item.photos.firstOrNull?.place,
        ),
    photos: item.photos,
    note: item.note,
    refused: item,
  );

  Future<void> _prove(
    BuildContext context,
    DaybookPost p, {
    required List<PendingPhoto> photos,
    String? note,
    PendingItem? refused,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
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

  /// Send back with a reason (B2), in place under the lifted proof.
  Future<void> _sendBack(
    BuildContext context,
    DaybookSignOff s,
    DaybookSlip lifted,
    Rect at,
  ) async {
    final result = await showBvLifted<(SendBackReason, String?)>(
      context,
      anchor: at,
      lifted: lifted,
      popover: (_) => DaybookSendBack(
        owner: personFirstName(AppLocalizations.of(context), s.actorName),
      ),
    );
    if (result == null || !context.mounted) return;
    await _call(
      context,
      RefusedAction.sendBack,
      s.postId,
      () => ref
          .read(workRepositoryProvider)
          .sendBack(s.postId, result.$1, note: result.$2),
    );
  }

  /// An update (Y1 → Y2): one line under the lifted slip.
  Future<void> _update(
    BuildContext context,
    String postId,
    DaybookSlip lifted,
    Rect at,
  ) async {
    final text = await showBvLifted<String>(
      context,
      anchor: at,
      lifted: lifted,
      popover: (_) => const DaybookUpdateField(),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    await _call(
      context,
      RefusedAction.update,
      postId,
      () => ref.read(workRepositoryProvider).addComment(postId, text),
    );
  }

  /// Give to someone else (X2): Lead and Crew only, the owner marked
  /// "now".
  Future<void> _giveTo(
    BuildContext context,
    DaybookPost p,
    DaybookSlip lifted,
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
    await _call(
      context,
      RefusedAction.giveTo,
      p.id,
      () => ref.read(workRepositoryProvider).reassign(p.id, picked.id),
    );
  }

  /// Runs a change on the server, then reads the daybook again. A lost
  /// signal says so; a refusal says why in plain words (review 47, answer
  /// 5) and the page reads again too.
  Future<void> _call(
    BuildContext context,
    RefusedAction action,
    String postId,
    Future<void> Function() run,
  ) async {
    try {
      await run();
    } on SpaceException catch (e) {
      if (e.failure == SpaceFailure.network) {
        if (context.mounted) showSpaceError(context, e);
        return;
      }
      await refresh();
      ref
          .read(refusalsProvider.notifier)
          .add(
            DaybookRefusal(
              action: action,
              spaceId: _spaceId,
              postId: postId,
              why: RefusalWhy.of(e),
            ),
          );
      return;
    }
    await refresh();
  }

  /// "Couldn't check: this item was cancelled". [records] is the page read
  /// again: when the server only says the item changed, it tells how.
  static String refusalText(
    AppLocalizations l10n,
    DaybookRefusal r,
    List<DaybookRecord> records,
  ) {
    final action = switch (r.action) {
      RefusedAction.check => l10n.daybookCouldNotCheck,
      RefusedAction.sendBack => l10n.daybookCouldNotSendBack,
      RefusedAction.cancel => l10n.daybookCouldNotCancel,
      RefusedAction.giveTo => l10n.daybookCouldNotGiveTo,
      RefusedAction.update => l10n.daybookCouldNotUpdate,
    };
    var why = r.why;
    if (why == RefusalWhy.changed) {
      final post = records
          .whereType<DaybookPost>()
          .where((p) => p.id == r.postId)
          .firstOrNull;
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
    ref.invalidate(mySpacesProvider);
    try {
      await ref.read(daybookPageProvider(_spaceId).notifier).refresh();
    } on SpaceException {
      // The page catches up on its next read.
    }
  }
}

/// The send-back card's state (B2): one reason, an optional note
/// ("Something else" needs one). Pops with the reason and the note. No
/// microphone: send_back takes no voice note.
class DaybookSendBack extends StatefulWidget {
  const DaybookSendBack({super.key, required this.owner});

  /// The owner's first name: "Send back to Omar".
  final String owner;

  @override
  State<DaybookSendBack> createState() => _DaybookSendBackState();
}

class _DaybookSendBackState extends State<DaybookSendBack> {
  final _note = TextEditingController();
  SendBackReason? _reason;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _ready =>
      _reason != null &&
      (_reason != SendBackReason.other || _note.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return BvSendBackCard<SendBackReason>(
      key: const Key('send-back-card'),
      title: l10n.daybookSendBackTo(widget.owner),
      reasons: [
        for (final r in SendBackReason.values)
          (value: r, label: words.reason(r)),
      ],
      selected: _reason,
      onSelected: (r) => setState(() => _reason = r),
      noteController: _note,
      notePlaceholder: _reason == SendBackReason.other
          ? l10n.daybookNoteNeeded
          : l10n.daybookNoteOptional,
      onNoteChanged: (_) => setState(() {}),
      sendLabel: l10n.daybookSendBack,
      onSend: _ready
          ? () {
              final note = _note.text.trim();
              Navigator.of(context).pop((_reason!, note.isEmpty ? null : note));
            }
          : null,
    );
  }
}

/// One line for an update, under the lifted slip. Pops with the text on
/// the keyboard's done key.
class DaybookUpdateField extends StatefulWidget {
  const DaybookUpdateField({super.key});

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
  Widget build(BuildContext context) => BvPopoverField(
    key: const Key('update-field'),
    icon: BvIcons.add,
    controller: _text,
    placeholder: AppLocalizations.of(context).daybookUpdateHint,
    maxLength: updateMax,
    onDone: (text) => Navigator.of(context).pop(text),
  );

  /// An update's length (the same as a note).
  static const updateMax = 1000;
}
