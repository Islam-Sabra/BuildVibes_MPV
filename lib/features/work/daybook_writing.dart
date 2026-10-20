import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/repositories/daybook_live.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_faces.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../../shared/widgets/bv_writing_card.dart';
import '../library/library_parts.dart' show fileSize;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/former_member.dart';
import 'daybook_draft.dart';
import 'daybook_photos.dart' show localPhotoProvider;
import 'daybook_words.dart';
import 'work_outbox.dart';

/// A new post's id, chosen on the phone when its card opens, so sending it
/// again is the same post (review 43). Tests stand in for it.
final newPostIdProvider = Provider<String Function()>((ref) => newUuid);

/// What opens over the diary while writing (E2, E3, E6): More, the kind
/// menu, the assign picker or the place field. Who a checklist or an
/// activity is for opens as a sheet ([DaybookPeopleSheet], F45).
enum DaybookWritingMenu { more, kind, assign, place }

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
  final picked = await _pickDay(
    context,
    today: today,
    day: day,
    last: DateTime(today.year + _yearsAhead, today.month, today.day),
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
  return (day: pickedDay, at: time == null ? null : _on(pickedDay, time));
}

DateTime _on(DateTime day, TimeOfDay time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute);

/// An announcement's pin: the last day it stays under the masthead, at
/// most 90 days on (create_space_post), or Remove. A null [until] takes
/// the pin off. Null when cancelled. A provider so tests can stand in.
typedef PickPin =
    Future<({DateTime? until})?> Function(
      BuildContext context, {
      required DateTime now,
      DateTime? until,
    });

final pickPinProvider = Provider<PickPin>((ref) => _pickPin);

Future<({DateTime? until})?> _pickPin(
  BuildContext context, {
  required DateTime now,
  DateTime? until,
}) async {
  final today = DateTime(now.year, now.month, now.day);
  final picked = await _pickDay(
    context,
    today: today,
    day: until == null ? null : dayOf(pinnedLastDay(until)),
    last: today.add(const Duration(days: pinDaysMax - 1)),
  );
  if (picked == null) return null;
  final day = picked.day;
  // Pinned to the end of that day: the phone's next midnight.
  return (
    until: day == null ? null : DateTime(day.year, day.month, day.day + 1),
  );
}

/// An announcement pins for at most this many days (create_space_post).
const pinDaysMax = 90;

/// When an activity starts and, if chosen, ends: the day, the start time,
/// then an optional end time ("No end time"), all the phone's own. Null
/// when cancelled. A provider so tests can stand in for the pickers.
typedef PickStart =
    Future<({DateTime start, DateTime? end})?> Function(
      BuildContext context, {
      required DateTime now,
      DateTime? start,
      DateTime? end,
    });

final pickStartProvider = Provider<PickStart>((ref) => _pickStart);

Future<({DateTime start, DateTime? end})?> _pickStart(
  BuildContext context, {
  required DateTime now,
  DateTime? start,
  DateTime? end,
}) async {
  final l10n = AppLocalizations.of(context);
  final today = DateTime(now.year, now.month, now.day);
  final picked = await _pickDay(
    context,
    today: today,
    day: start,
    last: DateTime(today.year + 1, today.month, today.day),
    removable: false,
  );
  final day = picked?.day;
  if (day == null || !context.mounted) return null;
  final from = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start ?? now.add(_nextHour)),
    helpText: l10n.daybookStartsAtHelp,
  );
  if (from == null || !context.mounted) return null;
  final startsAt = _on(day, from);
  final to = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(end ?? startsAt.add(_nextHour)),
    helpText: l10n.daybookEndsAtHelp,
    cancelText: l10n.daybookNoEndTime,
  );
  if (to == null) return (start: startsAt, end: null);
  var endsAt = _on(day, to);
  // Past midnight: the next morning (an activity lasts at most a day).
  if (!endsAt.isAfter(startsAt)) endsAt = endsAt.add(const Duration(days: 1));
  return (start: startsAt, end: endsAt);
}

const _nextHour = Duration(hours: 1);

/// The day picked in [_DueDayDialog]; null [day] is Remove.
typedef _DayChoice = ({DateTime? day});

Future<_DayChoice?> _pickDay(
  BuildContext context, {
  required DateTime today,
  required DateTime? day,
  required DateTime last,
  bool removable = true,
}) => showDialog<_DayChoice>(
  context: context,
  builder: (_) => _DueDayDialog(
    today: today,
    last: last,
    initial: day == null || day.isBefore(today) || day.isAfter(last)
        ? today
        : DateTime(day.year, day.month, day.day),
    removable: removable && day != null,
  ),
);

/// How far ahead a due date can be chosen.
const _yearsAhead = 2;

/// A day's calendar, with Remove when the card already has one.
class _DueDayDialog extends StatefulWidget {
  const _DueDayDialog({
    required this.today,
    required this.last,
    required this.initial,
    required this.removable,
  });

  final DateTime today;
  final DateTime last;
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
    return Dialog(
      key: const Key('due-day-picker'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarDatePicker(
            initialDate: _day,
            firstDate: widget.today,
            lastDate: widget.last,
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
/// under the name; [me] last. Posts go to Everyone, so every member can
/// see them. A checklist is for the same people: they tick it.
List<BvGiveToPerson> assignablePeople(SpacePeople people, {String? me}) =>
    _people(
      people,
      me: me,
      pass: (p) => p == SpacePass.lead || p == SpacePass.crew,
    );

/// Who an activity can be for: everyone active in the Space, Viewers too
/// (a Viewer attends).
List<BvGiveToPerson> attendees(SpacePeople people, {String? me}) =>
    _people(people, me: me, pass: (_) => true);

List<BvGiveToPerson> _people(
  SpacePeople people, {
  required String? me,
  required bool Function(SpacePass pass) pass,
}) {
  BvGiveToPerson person(SpaceMember m) => BvGiveToPerson(
    id: m.person.id,
    name: m.person.fullName,
    team: people.teamsOf(m.person.id).firstOrNull?.name,
  );
  final chosen = [
    for (final m in people.members)
      if (pass(m.pass)) m,
  ];
  return [
    for (final m in chosen)
      if (m.person.id != me) person(m),
    for (final m in chosen)
      if (m.person.id == me) person(m),
  ];
}

/// The kind chip's and the kind menu's word for [kind].
String kindName(AppLocalizations l10n, DaybookKind kind) => switch (kind) {
  DaybookKind.note => l10n.daybookKindNote,
  DaybookKind.workItem => l10n.daybookWorkItem,
  DaybookKind.checklist => l10n.daybookKindChecklist,
  DaybookKind.announcement => l10n.daybookKindAnnouncement,
  DaybookKind.activity => l10n.daybookKindActivity,
  // F50: named for what it does; the kind stays `file` on the server.
  DaybookKind.file => l10n.daybookKindDocument,
};

/// The kind menu's icon for [kind] (E6 v14 2598:36360).
IconData kindIcon(DaybookKind kind) => switch (kind) {
  DaybookKind.note => BvIcons.edit,
  DaybookKind.workItem => BvIcons.confirmed,
  DaybookKind.checklist => BvIcons.workItems,
  DaybookKind.announcement => BvIcons.info,
  DaybookKind.activity => BvIcons.due,
  DaybookKind.file => BvIcons.document,
};

/// Writing in one Space: the card's changes, its photos and files, the
/// kind's own properties, and Post. With [editing], the card is a posted
/// work item's, and Save sends only what changed (edit_space_post). The
/// card itself is [DaybookWritingCard]; the toolbar and the menus belong
/// to the daybook page.
class DaybookWriter {
  DaybookWriter(this.ref, this.spaceId, {this.editing = false});

  final WidgetRef ref;
  final String spaceId;
  final bool editing;

  DaybookWritingNotifier get _notifier => editing
      ? ref.read(daybookEditProvider(spaceId).notifier)
      : ref.read(daybookDraftProvider(spaceId).notifier);
  DaybookPostDraft? get draft => editing
      ? ref.read(daybookEditProvider(spaceId))
      : ref.read(daybookDraftProvider(spaceId));

  Future<void> _put(
    DaybookPostDraft Function(DaybookPostDraft d) change,
  ) async {
    final d = draft;
    if (d != null) await _notifier.put(change(d));
  }

  Future<void> setKind(DaybookKind kind) => _put((d) => d.copyWith(kind: kind));
  Future<void> setTitle(String text) => _put((d) => d.copyWith(title: text));
  Future<void> setBody(String text) => _put((d) => d.copyWith(body: text));

  Future<void> setOwner(BvGiveToPerson p) =>
      _put((d) => d.copyWith(ownerId: p.id, ownerName: p.name));

  /// Adds [p] to who it is for, or takes them out.
  Future<void> togglePerson(BvGiveToPerson p) => _put((d) {
    final had = d.people.any((x) => x.id == p.id);
    return d.copyWith(
      people: had
          ? [
              for (final x in d.people)
                if (x.id != p.id) x,
            ]
          : [...d.people, (id: p.id, name: p.name)],
    );
  });

  Future<void> setPoints(List<DraftPoint> points) =>
      _put((d) => d.copyWith(points: points));

  Future<void> setPlace(String text) => _put(
    (d) => d.copyWith(place: () => text.trim().isEmpty ? null : text.trim()),
  );

  Future<void> setDue(PickedDue due) =>
      _put((d) => d.copyWith(dueDate: () => due.day, dueAt: () => due.at));

  Future<void> setPin(DateTime? until) =>
      _put((d) => d.copyWith(pinnedUntil: () => until));

  Future<void> setStart(DateTime start, DateTime? end) =>
      _put((d) => d.copyWith(startsAt: () => start, endsAt: () => end));

  /// How many more photos and files the post takes (post_files: 10).
  int get room {
    final d = draft;
    if (d == null) return 0;
    return DaybookPostDraft.filesMax - d.photos.length - d.files.length;
  }

  /// A photo from the camera, kept in the app's folder.
  Future<void> addPhoto() async {
    if (room <= 0) return;
    final picked = await ref.read(pickPhotoProvider)(camera: true);
    if (picked == null) return;
    final kept = await ref.read(keepPhotoProvider)(picked);
    await _put((d) => d.copyWith(photos: [...d.photos, kept]));
  }

  /// Photos from the gallery (K4: up to 10 on a post).
  Future<void> addPhotos() async {
    final left = room;
    if (left <= 0) return;
    final picked = await ref.read(pickPhotosProvider)(max: left);
    final kept = [
      for (final p in picked.take(left)) await ref.read(keepPhotoProvider)(p),
    ];
    if (kept.isEmpty) return;
    await _put((d) => d.copyWith(photos: [...d.photos, ...kept]));
  }

  Future<void> removePhoto(int index) async {
    final d = draft;
    if (d == null || index >= d.photos.length) return;
    final old = d.photos[index];
    await _put((d) => d.copyWith(photos: [...d.photos]..removeAt(index)));
    unawaited(DaybookDraft.deleteKept(old));
  }

  /// A file on the post: a file post's one file (a new one replaces it),
  /// or one more on a work item.
  Future<void> addFile(DraftFile file) async {
    final d = draft;
    if (d == null) return;
    final one = d.kind == DaybookKind.file;
    final dropped = one ? d.files : const <DraftFile>[];
    await _put((d) => d.copyWith(files: one ? [file] : [...d.files, file]));
    for (final f in dropped) {
      if (f.local != null) unawaited(DaybookDraft.deleteKept(f.local!));
    }
  }

  Future<void> removeFile(DraftFile file) async {
    await _put(
      (d) => d.copyWith(
        files: [
          for (final f in d.files)
            if (f.libraryId != file.libraryId) f,
        ],
      ),
    );
    if (file.local != null) unawaited(DaybookDraft.deleteKept(file.local!));
  }

  /// Post: into the outbox (it sends now, or when the signal is back), and
  /// the card is gone. [authorName] is the writer's own, for the card while
  /// it waits.
  Future<void> post({String? authorName}) async {
    final d = draft;
    final now = ref.read(clockProvider)();
    if (d == null || !d.canPost(now)) return;
    final body = d.body.trim();
    final photos = [
      for (final p in d.photos) PendingPhoto(local: p, takenAt: now),
    ];
    final workItem = d.kind == DaybookKind.workItem;
    unawaited(
      ref
          .read(workOutboxProvider.notifier)
          .send(
            PendingItem(
              kind: workItem ? PendingKind.workItem : PendingKind.post,
              id: d.id,
              spaceId: spaceId,
              title: d.title.trim(),
              ownerId: d.ownerId ?? '',
              ownerName: d.ownerName ?? '',
              body: body.isEmpty ? null : body,
              place: d.place,
              dueDate: d.dueDate,
              dueAt: d.dueAt,
              madeAt: now,
              authorName: authorName,
              photos: photos,
              files: d.files,
              draft: workItem ? null : d,
            ),
          ),
    );
    // The photos and files now belong to the outbox, until they are sent.
    await ref
        .read(daybookDraftProvider(spaceId).notifier)
        .discard(keepFiles: true);
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
      pinChanged:
          d.kind == DaybookKind.announcement &&
          d.pinnedUntil != was.pinnedUntil,
      pinnedUntil: d.pinnedUntil,
    );
  }

  /// Save an edit: edit_space_post with only what changed.
  Future<void> save() async {
    final edit = changes();
    final id = draft?.id;
    if (id == null || edit.isEmpty) return;
    await ref.read(daybookRepositoryProvider).editPost(id, edit);
    // The Space's other open daybooks read it at once (F47).
    unawaited(ref.read(daybookLiveProvider).changed(spaceId, id));
  }
}

/// The post being written in place at "Now" (E1, E3, E6), its Draft when
/// the card was left with anything in it (E4; only its author sees it),
/// or a posted work item being edited ([editing], X1 Edit). While not
/// [writing] it is read only, and a tap reopens it.
///
/// The kind chip opens the kind menu (E6). Each kind shows its own line of
/// properties under the title: a work item's owner, due and place; a
/// checklist's people and due, and its points to type; an announcement's
/// pin; an activity's time, place and people; a file post's file.
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
    required this.onPickPin,
    required this.onPickStart,
    required this.onPickFile,
    required this.onPickPeople,
    this.editing = false,
    this.askWho,
  });

  final String spaceId;
  final bool writing;
  final DaybookWords words;
  final bool editing;

  /// Each new value pulses the "who" row: Post was tapped before anyone
  /// was chosen (F56).
  final Object? askWho;

  /// Left from before (the app closed or the card was put down): "Draft".
  final bool fromBefore;
  final VoidCallback onOpen;
  final ValueChanged<DaybookWritingMenu> onMenu;
  final VoidCallback onPickDue;
  final VoidCallback onPickPin;
  final VoidCallback onPickStart;
  final VoidCallback onPickFile;
  final VoidCallback onPickPeople;

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

  String _bodyHint(AppLocalizations l10n, DaybookKind kind) => switch (kind) {
    DaybookKind.workItem => l10n.daybookWritingBody,
    DaybookKind.announcement => l10n.daybookBodyAnnouncement,
    DaybookKind.activity => l10n.daybookBodyActivity,
    DaybookKind.note ||
    DaybookKind.checklist ||
    DaybookKind.file => l10n.daybookBodyNote,
  };

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
    final words = widget.words;
    final now = ref.watch(clockProvider)();
    VoidCallback? tap(VoidCallback f) => writing ? f : null;
    void menu(DaybookWritingMenu m) => writing ? widget.onMenu(m) : null;
    final kind = draft.kind;
    // F56: the "who" row from the start, as a line to tap; required on a
    // work item, a checklist and an activity. Choosing only fills it.
    BvWritingProperty choose(String label, VoidCallback onTap) =>
        BvWritingProperty.icon(
          key: const Key('writing-who'),
          icon: BvIcons.person,
          label: widget.askWho == null ? label : l10n.daybookChooseWho,
          empty: true,
          ask: widget.askWho,
          onTap: tap(onTap),
        );
    final people = BvWritingProperty.icon(
      icon: BvIcons.person,
      label: words.peopleFor([
        for (final p in draft.people) DaybookPerson(id: p.id, name: p.name),
      ], me: ref.watch(authUserIdProvider).value),
      onTap: tap(widget.onPickPeople),
    );
    final place = draft.place == null
        ? null
        : BvWritingProperty.icon(
            icon: BvIcons.place,
            label: draft.place!,
            onTap: tap(() => menu(DaybookWritingMenu.place)),
          );
    final due = draft.dueDate == null
        ? null
        : BvWritingProperty.icon(
            icon: BvIcons.due,
            label: words.dueProperty(draft.dueDate!, draft.dueAt),
            onTap: tap(widget.onPickDue),
          );
    final properties = <BvWritingProperty>[
      if (kind == DaybookKind.workItem) ...[
        if (draft.ownerId == null && !widget.editing)
          choose(l10n.daybookForChoose, () => menu(DaybookWritingMenu.assign))
        else if (draft.ownerId != null)
          BvWritingProperty.person(
            label: personName(l10n, draft.ownerName),
            tint: BvAvatarTints.forId(draft.ownerId!),
            // An edit keeps the owner: Give to someone else changes it.
            onTap: writing && !widget.editing
                ? () => menu(DaybookWritingMenu.assign)
                : null,
          ),
        ?due,
        ?place,
      ],
      if (kind == DaybookKind.checklist) ...[
        if (draft.people.isNotEmpty)
          people
        else
          choose(l10n.daybookForChoose, widget.onPickPeople),
        ?due,
      ],
      if (kind == DaybookKind.announcement && draft.pinnedUntil != null)
        BvWritingProperty.icon(
          icon: BvIcons.pin,
          label: l10n.daybookPinnedProperty(
            words.pinnedDay(draft.pinnedUntil!, now),
          ),
          onTap: tap(widget.onPickPin),
        ),
      if (kind == DaybookKind.activity) ...[
        if (draft.startsAt != null)
          BvWritingProperty.icon(
            icon: BvIcons.due,
            label: words.activityWhen(draft.startsAt!, draft.endsAt, now),
            onTap: tap(widget.onPickStart),
          ),
        ?place,
        if (draft.people.isNotEmpty)
          people
        else
          choose(l10n.daybookComingChoose, widget.onPickPeople),
      ],
      // A work item's files (attached from 📎) and a file post's file.
      for (final f in draft.files)
        BvWritingProperty.icon(
          icon: BvIcons.document,
          label: [
            f.revLabel == null
                ? f.name
                : l10n.daybookFileChip(f.name, f.revLabel!),
            if (f.supersedesRev != null)
              l10n.daybookReplacesOption(f.supersedesRev!),
            if (f.bytes != null) fileSize(l10n, f.bytes),
          ].join(' · '),
          // A file post's file is changed by choosing another; a work
          // item's is taken off with its ×.
          onTap: writing && kind == DaybookKind.file ? widget.onPickFile : null,
          onRemove: writing && kind != DaybookKind.file
              ? () => unawaited(_writer.removeFile(f))
              : null,
          removeLabel: l10n.daybookRemoveFile,
        ),
    ];
    final card = BvWritingCard(
      key: const Key('daybook-writing-card'),
      titleController: _title,
      titlePlaceholder: l10n.daybookWritingTitle,
      bodyController: _body,
      bodyPlaceholder: _bodyHint(l10n, kind),
      titleFocusNode: _titleFocus,
      bodyFocusNode: _bodyFocus,
      autofocus: writing,
      titleMaxLength: draft.titleLimit,
      bodyMaxLength: DaybookPostDraft.bodyMax,
      onTitleChanged: _writer.setTitle,
      onBodyChanged: _writer.setBody,
      draftLabel: widget.fromBefore ? l10n.daybookDraft : null,
      // The kind chip opens the kind menu (E6); an edit stays the kind it
      // is.
      kindLabel: writing ? kindName(l10n, kind) : null,
      onKindTap: writing && !widget.editing
          ? () => menu(DaybookWritingMenu.kind)
          : null,
      properties: properties,
      extra: kind == DaybookKind.checklist
          ? DaybookPointsEditor(
              key: ValueKey('points-${draft.id}'),
              points: draft.points,
              writing: writing,
              onChanged: _writer.setPoints,
            )
          : null,
      photos: [
        for (final p in draft.photos)
          Image(image: ref.watch(localPhotoProvider(p)), fit: BoxFit.cover),
      ],
      photoHeight: draft.photos.length > 1
          ? BvWritingCardSpec.postPhotoHeight
          : BvWritingCardSpec.coverHeight,
      onRemovePhoto: writing ? _writer.removePhoto : null,
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

/// Who a checklist or an activity is for, picked on a sheet (review 50
/// F45): the Space's people, each chosen one with a check; a pick adds or
/// takes them out at once, and never closes the sheet.
class DaybookPeopleSheet extends ConsumerWidget {
  const DaybookPeopleSheet({
    super.key,
    required this.spaceId,
    required this.me,
    this.editing = false,
  });

  final String spaceId;
  final String? me;
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(
      editing ? daybookEditProvider(spaceId) : daybookDraftProvider(spaceId),
    );
    final people = ref.watch(spacePeopleProvider(spaceId)).value;
    if (people == null) {
      return const SizedBox.square(
        dimension: BvSize.touchMin,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final writer = DaybookWriter(ref, spaceId, editing: editing);
    return BvGiveToPicker(
      key: const Key('writing-people'),
      people: draft?.kind == DaybookKind.activity
          ? attendees(people, me: me)
          : assignablePeople(people, me: me),
      currentOwnerId: null,
      currentLabel: l10n.daybookOwnerNow,
      chosenIds: {for (final p in draft?.people ?? const []) p.id},
      searchPlaceholder: l10n.daybookPeopleSearch,
      inSheet: true,
      onPick: writer.togglePerson,
    );
  }
}

/// The people sheet's fixed foot (F45): the chosen people's faces, never
/// a number, and Done.
class DaybookPeopleDone extends ConsumerWidget {
  const DaybookPeopleDone({
    super.key,
    required this.spaceId,
    required this.onDone,
    this.editing = false,
  });

  final String spaceId;
  final bool editing;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(
      editing ? daybookEditProvider(spaceId) : daybookDraftProvider(spaceId),
    );
    return Row(
      spacing: BvSpace.s12,
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: BvFaces([
              for (final p in draft?.people ?? const <DraftPerson>[])
                (name: p.name, tint: BvAvatarTints.forId(p.id)),
            ], large: true),
          ),
        ),
        BvButton(
          key: const Key('people-done'),
          label: l10n.daybookPeopleDone,
          onPressed: onDone,
        ),
      ],
    );
  }
}

/// A checklist's points while writing: each an empty box and a line to
/// type on; the last line ("Add a point") becomes a new point as soon as
/// it has words. Enter moves to the next point (from the last, to the
/// empty line); Backspace on an empty point takes it out and goes back to
/// the one before. A point's × takes it out too. At most 50
/// (create_space_post).
///
/// Review 50 F40: each point keeps its key (its id), its controller and its
/// focus node for the life of the card, and typing in a point never
/// rebuilds the list, so the keyboard stays up.
class DaybookPointsEditor extends StatefulWidget {
  const DaybookPointsEditor({
    super.key,
    required this.points,
    required this.writing,
    required this.onChanged,
  });

  final List<DraftPoint> points;
  final bool writing;
  final ValueChanged<List<DraftPoint>> onChanged;

  @override
  State<DaybookPointsEditor> createState() => _PointsEditorState();
}

class _PointsEditorState extends State<DaybookPointsEditor> {
  late var _points = [...widget.points];
  final _controllers = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};

  /// The id the next point will have: the empty last line's.
  var _next = newUuid();

  TextEditingController _controller(String id, String text) =>
      _controllers.putIfAbsent(id, () => TextEditingController(text: text));

  FocusNode _node(String id) => _focus.putIfAbsent(
    id,
    () => FocusNode(onKeyEvent: (_, event) => _key(id, event)),
  );

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Backspace on an empty point: it goes, and the one before has the
  /// focus.
  KeyEventResult _key(String id, KeyEvent event) {
    final at = _points.indexWhere((p) => p.id == id);
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace ||
        at < 0 ||
        (_controllers[id]?.text.isNotEmpty ?? true)) {
      return KeyEventResult.ignored;
    }
    final before = at > 0 ? _points[at - 1].id : null;
    _remove(id);
    if (before != null) _node(before).requestFocus();
    return KeyEventResult.handled;
  }

  void _changed(String id, String text) {
    final at = _points.indexWhere((p) => p.id == id);
    if (at >= 0) {
      // Only the words change: the field has them; no rebuild.
      _points = [..._points]..[at] = (id: id, text: text);
    } else {
      if (text.trim().isEmpty) return;
      // The empty line got words: it is a point now, under the same id, so
      // it keeps its field and its focus; a new empty line comes under it.
      setState(() {
        _points = [..._points, (id: id, text: text)];
        _next = newUuid();
      });
    }
    widget.onChanged(_points);
  }

  /// Enter: the next point, or the empty line after the last one.
  void _submitted(String id) {
    final at = _points.indexWhere((p) => p.id == id);
    if (at < 0) return;
    final next = at + 1 < _points.length ? _points[at + 1].id : _next;
    _node(next).requestFocus();
  }

  void _remove(String id) {
    setState(
      () => _points = [
        for (final p in _points)
          if (p.id != id) p,
      ],
    );
    // Gone after this frame: the field lets go of them first.
    final controller = _controllers.remove(id);
    final node = _focus.remove(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller?.dispose();
      node?.dispose();
    });
    widget.onChanged(_points);
  }

  @override
  Widget build(BuildContext context) {
    final full = _points.length >= BvWritingPointSpec.max;
    return Column(
      key: const Key('writing-points'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in _points) _row(p.id, p.text, real: true),
        if (!full && widget.writing) _row(_next, '', real: false),
      ],
    );
  }

  Widget _row(String id, String text, {required bool real}) {
    final l10n = AppLocalizations.of(context);
    final style = BvType.of(context).bodyMd;
    return ConstrainedBox(
      key: ValueKey('writing-point-$id'),
      constraints: const BoxConstraints(
        minHeight: BvWritingPointSpec.rowMinHeight,
      ),
      child: Row(
        spacing: BvWritingPointSpec.gap,
        children: [
          Container(
            width: BvChecklistSpec.box,
            height: BvChecklistSpec.box,
            decoration: BoxDecoration(
              borderRadius: BvChecklistSpec.boxRadius,
              border: Border.all(
                color: BvColors.borderDefault,
                width: BvChecklistSpec.boxBorder,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: ValueKey('writing-point-field-$id'),
              controller: _controller(id, text),
              focusNode: _node(id),
              enabled: widget.writing,
              inputFormatters: [
                LengthLimitingTextInputFormatter(BvWritingPointSpec.textMax),
              ],
              textInputAction: TextInputAction.next,
              onChanged: (t) => _changed(id, t),
              // Enter moves on here, not to the next field on the screen.
              onEditingComplete: () {},
              onSubmitted: (_) => _submitted(id),
              style: style.copyWith(color: BvColors.textPrimary),
              cursorColor: BvColors.actionPrimary,
              decoration: bvBareField(
                hint: l10n.daybookPointHint,
                style: style,
              ),
            ),
          ),
          // Kept in place on the empty line too, so a row never changes
          // shape as it gets its first letter.
          Visibility(
            visible: real && widget.writing,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: BvTapTarget(
              child: Semantics(
                button: true,
                label: l10n.daybookRemovePoint,
                child: GestureDetector(
                  key: ValueKey('writing-point-remove-$id'),
                  behavior: HitTestBehavior.opaque,
                  onTap: real ? () => _remove(id) : null,
                  child: const Icon(
                    BvIcons.close,
                    size: BvSize.iconSm,
                    color: BvColors.iconSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What opens over the diary while writing: the More menu (a kind's own
/// choices; an edit has no Assign), the kind menu (E6), the assign picker,
/// who a checklist or an activity is for, or the place field.
/// [onAssigned] follows a pick in the assign picker; [onPickPeople] opens
/// the people sheet.
class DaybookWritingPopover extends ConsumerStatefulWidget {
  const DaybookWritingPopover({
    super.key,
    required this.spaceId,
    required this.menu,
    required this.me,
    required this.onMenu,
    required this.onPickDue,
    required this.onPickPin,
    required this.onPickStart,
    required this.onPickFile,
    required this.onClose,
    required this.onAssigned,
    required this.onPickPeople,
    this.editing = false,
  });

  final String spaceId;
  final DaybookWritingMenu menu;
  final String? me;
  final bool editing;
  final ValueChanged<DaybookWritingMenu> onMenu;
  final VoidCallback onPickDue;
  final VoidCallback onPickPin;
  final VoidCallback onPickStart;
  final VoidCallback onPickFile;
  final VoidCallback onClose;
  final VoidCallback onAssigned;
  final VoidCallback onPickPeople;

  @override
  ConsumerState<DaybookWritingPopover> createState() => _PopoverState();
}

enum _More { assign, people, location, due, pin, time, file }

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

  List<BvMenuItem<_More>> _moreItems(AppLocalizations l10n, DaybookKind kind) {
    final assign = BvMenuItem(
      value: _More.assign,
      label: l10n.daybookAssign,
      icon: BvIcons.person,
    );
    final people = BvMenuItem(
      value: _More.people,
      label: l10n.daybookPeople,
      icon: BvIcons.people,
    );
    final location = BvMenuItem(
      value: _More.location,
      label: l10n.daybookLocation,
      icon: BvIcons.place,
    );
    final due = BvMenuItem(
      value: _More.due,
      label: l10n.daybookDueDateMenu,
      icon: BvIcons.due,
    );
    return switch (kind) {
      // A note has nothing to set: its words, photos and files only (F58).
      DaybookKind.note => const [],
      DaybookKind.workItem => [if (!widget.editing) assign, location, due],
      DaybookKind.checklist => [people, due],
      DaybookKind.announcement => [
        BvMenuItem(
          value: _More.pin,
          label: l10n.daybookPinUntil,
          icon: BvIcons.pin,
        ),
      ],
      DaybookKind.activity => [
        BvMenuItem(
          value: _More.time,
          label: l10n.daybookActivityTime,
          icon: BvIcons.due,
        ),
        location,
        people,
      ],
      DaybookKind.file => [
        BvMenuItem(
          value: _More.file,
          label: l10n.daybookKindFile,
          icon: BvIcons.document,
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(
      widget.editing
          ? daybookEditProvider(widget.spaceId)
          : daybookDraftProvider(widget.spaceId),
    );
    final kind = draft?.kind ?? DaybookKind.workItem;
    switch (widget.menu) {
      case DaybookWritingMenu.more:
        return BvPopoverMenu<_More>.more(
          key: const Key('writing-more-menu'),
          items: _moreItems(l10n, kind),
          onSelected: (v) => switch (v) {
            _More.assign => widget.onMenu(DaybookWritingMenu.assign),
            _More.people => widget.onPickPeople(),
            _More.location => widget.onMenu(DaybookWritingMenu.place),
            _More.due => widget.onPickDue(),
            _More.pin => widget.onPickPin(),
            _More.time => widget.onPickStart(),
            _More.file => widget.onPickFile(),
          },
        );
      case DaybookWritingMenu.kind:
        return BvPopoverMenu<DaybookKind>.picker(
          key: const Key('writing-kind-menu'),
          selected: kind,
          items: [
            for (final k in DaybookKind.values)
              BvMenuItem(
                value: k,
                label: kindName(l10n, k),
                icon: kindIcon(k),
                note: switch (k) {
                  DaybookKind.note => l10n.daybookKindNoteNote,
                  DaybookKind.file => l10n.daybookKindDocumentNote,
                  _ => null,
                },
              ),
          ],
          onSelected: (k) async {
            await _writer.setKind(k);
            // A file post goes straight to its file.
            if (k == DaybookKind.file &&
                (_writer.draft?.files.isEmpty ?? true)) {
              widget.onPickFile();
            } else {
              widget.onClose();
            }
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
        // One owner: the first pick closes it.
        return BvGiveToPicker(
          key: const Key('writing-assign'),
          people: assignablePeople(people, me: widget.me),
          currentOwnerId: draft?.ownerId,
          currentLabel: l10n.daybookOwnerNow,
          // The menu says "Assign" (review 46).
          searchPlaceholder: l10n.daybookAssignSearch,
          onPick: (p) async {
            await _writer.setOwner(p);
            widget.onAssigned();
          },
          // F56: nobody to own it? Post it as a note instead.
          footer: widget.editing
              ? null
              : BvListRow(
                  key: const Key('writing-as-note'),
                  title: l10n.daybookPostAsNote,
                  leading: const BvRowIcon(BvIcons.edit),
                  onTap: () async {
                    await _writer.setKind(DaybookKind.note);
                    widget.onClose();
                  },
                ),
        );
      case DaybookWritingMenu.place:
        return BvPopoverField(
          key: const Key('writing-place'),
          icon: BvIcons.place,
          controller: _place,
          placeholder: l10n.daybookPlaceHint,
          maxLength: DaybookPostDraft.placeMax,
          onDone: (text) async {
            await _writer.setPlace(text);
            widget.onClose();
          },
        );
    }
  }
}
