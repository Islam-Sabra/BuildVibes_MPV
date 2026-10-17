import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_writing_card.dart';
import '../../core/design/bv_tokens.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/former_member.dart';
import 'daybook_draft.dart';
import 'daybook_entry.dart' show localPhotoProvider;
import 'daybook_words.dart';
import 'work_outbox.dart';

/// A new post's id, chosen on the phone when its card opens, so sending it
/// again is the same post (review 43). Tests stand in for it.
final newPostIdProvider = Provider<String Function()>((ref) => newUuid);

/// What opens over the diary while writing (E2, E3).
enum DaybookWritingMenu { more, assign, place }

/// A due day and, when chosen, its time: both the phone's own.
typedef PickedDue = ({DateTime day, DateTime? at});

/// Picks a due date, then an optional time ("No time" keeps the date
/// only). Null when cancelled. A provider so tests can stand in for the
/// pickers.
typedef PickDue =
    Future<PickedDue?> Function(
      BuildContext context, {
      required DateTime now,
      DateTime? day,
      DateTime? at,
    });

final pickDueProvider = Provider<PickDue>((ref) => _pickDue);

Future<PickedDue?> _pickDue(
  BuildContext context, {
  required DateTime now,
  DateTime? day,
  DateTime? at,
}) async {
  final l10n = AppLocalizations.of(context);
  final today = DateTime(now.year, now.month, now.day);
  final picked = await showDatePicker(
    context: context,
    firstDate: today,
    lastDate: DateTime(today.year + _yearsAhead, today.month, today.day),
    initialDate: day == null || day.isBefore(today) ? today : day,
  );
  if (picked == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(at ?? now),
    helpText: l10n.daybookDueTimeHelp,
    cancelText: l10n.daybookNoTime,
  );
  return (
    day: picked,
    at: time == null
        ? null
        : DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          ),
  );
}

/// How far ahead a due date can be chosen.
const _yearsAhead = 2;

/// Who can own a work item (review 44 C5): Lead and Crew members who are
/// active in the Space, never a Viewer. Each with their first Team ("MEP")
/// under the name; [me] last. Slice 1 posts to Everyone, so every member
/// can see the post.
List<BvGiveToPerson> assignablePeople(SpacePeople people, {String? me}) {
  BvGiveToPerson person(SpaceMember m) => BvGiveToPerson(
    id: m.person.id,
    name: m.person.fullName,
    team: people.teamsOf(m.person.id).firstOrNull?.name,
  );
  final owners = [
    for (final m in people.members)
      if (m.pass == SpacePass.lead || m.pass == SpacePass.crew) m,
  ];
  return [
    for (final m in owners)
      if (m.person.id != me) person(m),
    for (final m in owners)
      if (m.person.id == me) person(m),
  ];
}

/// Writing in one Space: the card's changes, its photo, due and owner, and
/// Post. The card itself is [DaybookWritingCard]; the toolbar and the
/// menus belong to the daybook page.
class DaybookWriter {
  DaybookWriter(this.ref, this.spaceId);

  final WidgetRef ref;
  final String spaceId;

  DaybookDraft get _notifier =>
      ref.read(daybookDraftProvider(spaceId).notifier);
  WorkItemDraft? get draft => ref.read(daybookDraftProvider(spaceId));

  Future<void> _put(WorkItemDraft Function(WorkItemDraft d) change) async {
    final d = draft;
    if (d != null) await _notifier.put(change(d));
  }

  Future<void> setTitle(String text) => _put((d) => d.copyWith(title: text));
  Future<void> setBody(String text) => _put((d) => d.copyWith(body: text));

  Future<void> setOwner(BvGiveToPerson p) =>
      _put((d) => d.copyWith(ownerId: p.id, ownerName: p.name));

  Future<void> setPlace(String text) => _put(
    (d) => d.copyWith(place: () => text.trim().isEmpty ? null : text.trim()),
  );

  Future<void> setDue(PickedDue due) =>
      _put((d) => d.copyWith(dueDate: () => due.day, dueAt: () => due.at));

  /// The cover photo, from the camera or the phone. One per card in slice
  /// 1: a new one takes the old one's place.
  Future<void> addPhoto({required bool camera}) async {
    final picked = await ref.read(pickPhotoProvider)(camera: camera);
    if (picked == null) return;
    final kept = await ref.read(keepPhotoProvider)(picked);
    final old = draft?.photo;
    await _put((d) => d.copyWith(photo: () => kept));
    if (old != null) unawaited(DaybookDraft.deleteKept(old));
  }

  Future<void> removePhoto() async {
    final old = draft?.photo;
    await _put((d) => d.copyWith(photo: () => null));
    if (old != null) unawaited(DaybookDraft.deleteKept(old));
  }

  /// Post: into the outbox (it sends now, or when the signal is back), and
  /// the card is gone. [authorName] is the writer's own, for the slip while
  /// it waits.
  Future<void> post({String? authorName}) async {
    final d = draft;
    if (d == null || !d.canPost) return;
    final now = ref.read(clockProvider)();
    final body = d.body.trim();
    unawaited(
      ref
          .read(workOutboxProvider.notifier)
          .send(
            PendingItem(
              kind: PendingKind.workItem,
              id: d.id,
              spaceId: spaceId,
              title: d.title.trim(),
              ownerId: d.ownerId!,
              ownerName: d.ownerName ?? '',
              body: body.isEmpty ? null : body,
              place: d.place,
              dueDate: d.dueDate,
              dueAt: d.dueAt,
              madeAt: now,
              authorName: authorName,
              photos: [
                if (d.photo != null)
                  PendingPhoto(local: d.photo!, takenAt: now),
              ],
            ),
          ),
    );
    // The photo now belongs to the outbox, until it is sent.
    await _notifier.discard(keepPhoto: true);
  }
}

/// The work item being written in place at "Now" (E1, E3), or its Draft
/// when the card was left with text (E4; only its author sees it). While
/// not [writing] it is read only, and a tap reopens it.
class DaybookWritingCard extends ConsumerStatefulWidget {
  const DaybookWritingCard({
    super.key,
    required this.spaceId,
    required this.writing,
    required this.words,
    required this.fromBefore,
    required this.onOpen,
    required this.onMenu,
    required this.onPickDue,
  });

  final String spaceId;
  final bool writing;
  final DaybookWords words;

  /// Left from before (the app closed or the card was put down): "Draft".
  final bool fromBefore;
  final VoidCallback onOpen;
  final ValueChanged<DaybookWritingMenu> onMenu;
  final VoidCallback onPickDue;

  @override
  ConsumerState<DaybookWritingCard> createState() => _WritingCardState();
}

class _WritingCardState extends ConsumerState<DaybookWritingCard> {
  late final DaybookWriter _writer = DaybookWriter(ref, widget.spaceId);
  late final TextEditingController _title;
  late final TextEditingController _body;
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final draft = _writer.draft;
    _title = TextEditingController(text: draft?.title);
    _body = TextEditingController(text: draft?.body);
  }

  @override
  void didUpdateWidget(DaybookWritingCard old) {
    super.didUpdateWidget(old);
    if (widget.writing && !old.writing) _titleFocus.requestFocus();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(daybookDraftProvider(widget.spaceId));
    if (draft == null) return const SizedBox.shrink();
    final writing = widget.writing;
    void menu(DaybookWritingMenu m) => writing ? widget.onMenu(m) : null;
    final card = BvWritingCard(
      key: const Key('daybook-writing-card'),
      titleController: _title,
      titlePlaceholder: l10n.daybookWritingTitle,
      bodyController: _body,
      bodyPlaceholder: l10n.daybookWritingBody,
      titleFocusNode: _titleFocus,
      bodyFocusNode: _bodyFocus,
      autofocus: writing,
      titleMaxLength: WorkItemDraft.titleMax,
      bodyMaxLength: WorkItemDraft.bodyMax,
      onTitleChanged: _writer.setTitle,
      onBodyChanged: _writer.setBody,
      draftLabel: widget.fromBefore ? l10n.daybookDraft : null,
      // Slice 1 posts work items only, so there is nothing to choose
      // (review 44 C5).
      kindLabel: writing ? l10n.daybookWorkItem : null,
      properties: [
        if (draft.ownerId != null)
          BvWritingProperty.person(
            label: personName(l10n, draft.ownerName),
            tint: BvAvatarTints.forId(draft.ownerId!),
            onTap: writing ? () => menu(DaybookWritingMenu.assign) : null,
          ),
        if (draft.dueDate != null)
          BvWritingProperty.icon(
            icon: BvIcons.due,
            label: widget.words.dueProperty(draft.dueDate!, draft.dueAt),
            onTap: writing ? widget.onPickDue : null,
          ),
        if (draft.place != null)
          BvWritingProperty.icon(
            icon: BvIcons.place,
            label: draft.place!,
            onTap: writing ? () => menu(DaybookWritingMenu.place) : null,
          ),
      ],
      cover: draft.photo == null
          ? null
          : Image(
              image: ref.watch(localPhotoProvider(draft.photo!)),
              fit: BoxFit.cover,
            ),
      onRemoveCover: writing ? _writer.removePhoto : null,
      removeCoverLabel: l10n.daybookRemovePhoto,
    );
    if (writing) {
      // A tap on the card's paper stays on the card (a tap elsewhere puts
      // the card down).
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: card,
      );
    }
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('daybook-draft'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: AbsorbPointer(child: card),
      ),
    );
  }
}

/// What opens over the diary while writing: the More menu (Assign,
/// Location, Due date; review 44 C5: no Checklist or Template in slice 1),
/// the assign picker, or the place field.
class DaybookWritingPopover extends ConsumerStatefulWidget {
  const DaybookWritingPopover({
    super.key,
    required this.spaceId,
    required this.menu,
    required this.me,
    required this.onMenu,
    required this.onPickDue,
    required this.onClose,
  });

  final String spaceId;
  final DaybookWritingMenu menu;
  final String? me;
  final ValueChanged<DaybookWritingMenu> onMenu;
  final VoidCallback onPickDue;
  final VoidCallback onClose;

  @override
  ConsumerState<DaybookWritingPopover> createState() => _PopoverState();
}

enum _More { assign, location, due }

class _PopoverState extends ConsumerState<DaybookWritingPopover> {
  late final DaybookWriter _writer = DaybookWriter(ref, widget.spaceId);
  late final TextEditingController _place;

  @override
  void initState() {
    super.initState();
    _place = TextEditingController(text: _writer.draft?.place);
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (widget.menu) {
      case DaybookWritingMenu.more:
        return BvPopoverMenu<_More>.more(
          key: const Key('writing-more-menu'),
          items: [
            BvMenuItem(
              value: _More.assign,
              label: l10n.daybookAssign,
              icon: BvIcons.person,
            ),
            BvMenuItem(
              value: _More.location,
              label: l10n.daybookLocation,
              icon: BvIcons.place,
            ),
            BvMenuItem(
              value: _More.due,
              label: l10n.daybookDueDateMenu,
              icon: BvIcons.due,
            ),
          ],
          onSelected: (v) => switch (v) {
            _More.assign => widget.onMenu(DaybookWritingMenu.assign),
            _More.location => widget.onMenu(DaybookWritingMenu.place),
            _More.due => widget.onPickDue(),
          },
        );
      case DaybookWritingMenu.assign:
        final people = ref.watch(spacePeopleProvider(widget.spaceId)).value;
        if (people == null) {
          return const SizedBox.square(
            dimension: BvSize.touchMin,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return BvGiveToPicker(
          key: const Key('writing-assign'),
          people: assignablePeople(people, me: widget.me),
          currentOwnerId: _writer.draft?.ownerId,
          currentLabel: l10n.daybookOwnerNow,
          searchPlaceholder: l10n.daybookGiveToSearch,
          onPick: (p) async {
            await _writer.setOwner(p);
            widget.onClose();
          },
        );
      case DaybookWritingMenu.place:
        return BvPopoverField(
          key: const Key('writing-place'),
          icon: BvIcons.place,
          controller: _place,
          placeholder: l10n.daybookPlaceHint,
          maxLength: WorkItemDraft.placeMax,
          onDone: (text) async {
            await _writer.setPlace(text);
            widget.onClose();
          },
        );
    }
  }
}
