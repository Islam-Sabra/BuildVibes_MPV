import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/models/space.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_writing_card.dart';
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

/// A due day and, when chosen, its time: both the phone's own. A null
/// [day] takes the due off (Remove).
typedef PickedDue = ({DateTime? day, DateTime? at});

/// Picks a due date, then an optional time ("No time" keeps the date
/// only). With [removable], the date picker also offers Remove (review
/// 46). Null when cancelled. A provider so tests can stand in for the
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
  final picked = await showDialog<_DayChoice>(
    context: context,
    builder: (_) => _DueDayDialog(
      today: today,
      initial: day == null || day.isBefore(today) ? today : day,
      removable: day != null,
    ),
  );
  if (picked == null || !context.mounted) return null;
  final pickedDay = picked.day;
  if (pickedDay == null) return (day: null, at: null);
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(at ?? now),
    helpText: l10n.daybookDueTimeHelp,
    cancelText: l10n.daybookNoTime,
  );
  return (
    day: pickedDay,
    at: time == null
        ? null
        : DateTime(
            pickedDay.year,
            pickedDay.month,
            pickedDay.day,
            time.hour,
            time.minute,
          ),
  );
}

/// The day picked in [_DueDayDialog]; null [day] is Remove.
typedef _DayChoice = ({DateTime? day});

/// How far ahead a due date can be chosen.
const _yearsAhead = 2;

/// The due date's calendar, with Remove when the card already has one.
class _DueDayDialog extends StatefulWidget {
  const _DueDayDialog({
    required this.today,
    required this.initial,
    required this.removable,
  });

  final DateTime today;
  final DateTime initial;
  final bool removable;

  @override
  State<_DueDayDialog> createState() => _DueDayDialogState();
}

class _DueDayDialogState extends State<_DueDayDialog> {
  late var _day = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final today = widget.today;
    return Dialog(
      key: const Key('due-day-picker'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarDatePicker(
            initialDate: _day,
            firstDate: today,
            lastDate: DateTime(
              today.year + _yearsAhead,
              today.month,
              today.day,
            ),
            onDateChanged: (d) => setState(() => _day = d),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.s8,
              vertical: BvSpace.s8,
            ),
            child: Row(
              children: [
                if (widget.removable)
                  TextButton(
                    key: const Key('due-remove'),
                    onPressed: () =>
                        Navigator.of(context).pop<_DayChoice>((day: null)),
                    child: Text(
                      l10n.daybookRemoveDue,
                      style: BvType.of(
                        context,
                      ).labelMd.copyWith(color: BvColors.textDestructive),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(material.cancelButtonLabel),
                ),
                TextButton(
                  key: const Key('due-ok'),
                  onPressed: () =>
                      Navigator.of(context).pop<_DayChoice>((day: _day)),
                  child: Text(material.okButtonLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
/// Post. With [editing], the card is a posted work item's, and Save sends
/// only what changed (edit_space_post). The card itself is
/// [DaybookWritingCard]; the toolbar and the menus belong to the daybook
/// page.
class DaybookWriter {
  DaybookWriter(this.ref, this.spaceId, {this.editing = false});

  final WidgetRef ref;
  final String spaceId;
  final bool editing;

  DaybookCard get _notifier => editing
      ? ref.read(daybookEditProvider(spaceId).notifier)
      : ref.read(daybookDraftProvider(spaceId).notifier);
  WorkItemDraft? get draft => editing
      ? ref.read(daybookEditProvider(spaceId))
      : ref.read(daybookDraftProvider(spaceId));

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
    await ref
        .read(daybookDraftProvider(spaceId).notifier)
        .discard(keepPhoto: true);
  }

  /// What an edit changes, against the post as it was; empty when nothing
  /// did.
  PostEdit changes() {
    final d = draft;
    final was = ref.read(daybookEditProvider(spaceId).notifier).original;
    if (d == null || was == null) return const PostEdit();
    String? text(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
    final title = d.title.trim();
    return PostEdit(
      title: title == was.title ? null : title,
      body: text(d.body),
      bodyChanged: text(d.body) != text(was.body),
      place: d.place,
      placeChanged: text(d.place) != text(was.place),
      dueChanged: d.dueDate != was.dueDate || d.dueAt != was.dueAt,
      dueDate: d.dueDate,
      dueAt: d.dueAt,
    );
  }

  /// Save an edit: edit_space_post with only what changed.
  Future<void> save() async {
    final edit = changes();
    final id = draft?.id;
    if (id == null || edit.isEmpty) return;
    await ref.read(daybookRepositoryProvider).editPost(id, edit);
  }
}

/// The work item being written in place at "Now" (E1, E3), its Draft when
/// the card was left with anything in it (E4; only its author sees it),
/// or a posted work item being edited ([editing], X1 Edit). While not
/// [writing] it is read only, and a tap reopens it.
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
    this.editing = false,
  });

  final String spaceId;
  final bool writing;
  final DaybookWords words;
  final bool editing;

  /// Left from before (the app closed or the card was put down): "Draft".
  final bool fromBefore;
  final VoidCallback onOpen;
  final ValueChanged<DaybookWritingMenu> onMenu;
  final VoidCallback onPickDue;

  @override
  ConsumerState<DaybookWritingCard> createState() => _WritingCardState();
}

class _WritingCardState extends ConsumerState<DaybookWritingCard> {
  late final DaybookWriter _writer = DaybookWriter(
    ref,
    widget.spaceId,
    editing: widget.editing,
  );
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
    final draft = ref.watch(
      widget.editing
          ? daybookEditProvider(widget.spaceId)
          : daybookDraftProvider(widget.spaceId),
    );
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
            // An edit keeps the owner: Give to someone else changes it.
            onTap: writing && !widget.editing
                ? () => menu(DaybookWritingMenu.assign)
                : null,
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
      photos: [
        if (draft.photo != null)
          Image(
            image: ref.watch(localPhotoProvider(draft.photo!)),
            fit: BoxFit.cover,
          ),
      ],
      onRemovePhoto: writing ? (_) => _writer.removePhoto() : null,
      removePhotoLabel: l10n.daybookRemovePhoto,
      errorLine: draft.couldNotSend && !writing
          ? l10n.daybookCouldNotSend
          : null,
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
/// Location, Due date; review 44 C5: no Checklist or Template in slice 1;
/// an edit has no Assign), the assign picker, or the place field.
/// [onAssigned] follows a pick in the assign picker.
class DaybookWritingPopover extends ConsumerStatefulWidget {
  const DaybookWritingPopover({
    super.key,
    required this.spaceId,
    required this.menu,
    required this.me,
    required this.onMenu,
    required this.onPickDue,
    required this.onClose,
    required this.onAssigned,
    this.editing = false,
  });

  final String spaceId;
  final DaybookWritingMenu menu;
  final String? me;
  final bool editing;
  final ValueChanged<DaybookWritingMenu> onMenu;
  final VoidCallback onPickDue;
  final VoidCallback onClose;
  final VoidCallback onAssigned;

  @override
  ConsumerState<DaybookWritingPopover> createState() => _PopoverState();
}

enum _More { assign, location, due }

class _PopoverState extends ConsumerState<DaybookWritingPopover> {
  late final DaybookWriter _writer = DaybookWriter(
    ref,
    widget.spaceId,
    editing: widget.editing,
  );
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
            if (!widget.editing)
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
          // The menu says "Assign" (review 46).
          searchPlaceholder: l10n.daybookAssignSearch,
          onPick: (p) async {
            await _writer.setOwner(p);
            widget.onAssigned();
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
