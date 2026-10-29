import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/photo_privacy.dart'
    show photosPreparingProvider, PhotosPreparing;
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/template.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/template_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_quote_block.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_faces.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_time_wheel.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../../shared/widgets/bv_writing_card.dart';
import '../../shared/widgets/bv_writing_rows.dart';
import '../library/library_parts.dart' show fileSize;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/former_member.dart';
import '../spaces/space_errors.dart' show showSpaceMessage;
import 'daybook_draft.dart';
import 'daybook_photos.dart' show localPhotoProvider;
import 'daybook_report.dart' show ReportWriting;
import 'daybook_templates.dart';
import 'daybook_words.dart';
import 'work_outbox.dart';

/// A new post's id, chosen on the phone when its card opens, so sending it
/// again is the same post (review 43). Tests stand in for it.
final newPostIdProvider = Provider<String Function()>((ref) => newUuid);

/// What opens over the diary while writing (E2, E3, E6): More, the kind
/// menu, the assign picker or the place field. Who a checklist or an
/// activity is for opens as a sheet ([DaybookPeopleSheet], F45).
enum DaybookWritingMenu { more, kind, assign, place, audience }

/// The Teams [me] may post to (F56, "To: Everyone"): their own, or every
/// Team for a Space admin (create_space_post's rule).
List<SpaceTeam> audienceTeams(
  SpacePeople? people, {
  required String? me,
  required bool admin,
}) {
  if (people == null || me == null) return const [];
  return admin ? people.teams : people.teamsOf(me);
}

/// The kinds that go to an audience rather than to chosen people.
/// Slice 7: Template, when the Space has one of [draft]'s kind for its
/// audience (hidden otherwise, review 44); never on an edit.
bool writingHasTemplates(
  WidgetRef ref,
  String spaceId,
  DaybookPostDraft? draft, {
  required bool editing,
}) =>
    !editing &&
    draft != null &&
    templatesFor(
      ref.watch(spaceTemplatesProvider(spaceId)).value ?? const [],
      draft.kind,
      teamId: draft.teamId,
      chosenTeam: draft.teamId != null,
    ).isNotEmpty;

/// What the writing bar's + holds (review 105 SP2): a template, and an
/// announcement's pin; null-tap while it holds nothing.
bool writingHasMore(
  WidgetRef ref,
  String spaceId,
  DaybookPostDraft? draft, {
  required bool editing,
}) =>
    draft != null &&
    (draft.kind == DaybookKind.announcement ||
        writingHasTemplates(ref, spaceId, draft, editing: editing));

/// The kinds written with For · Place · Due · Team rows and chosen with
/// the kind chips (review 105 SP2), in the chips' order. A file post and a
/// daily report start elsewhere (📎, Space info).
const rowKinds = [
  DaybookKind.note,
  DaybookKind.workItem,
  DaybookKind.checklist,
  DaybookKind.announcement,
  DaybookKind.activity,
];

/// The writing card's last kind chip (the lead's ruling on H3, review
/// 105): Walk, for who may post work. Not a kind of post: it starts walk
/// mode.
const kindChipWalk = 'walk';

bool goesToAudience(DaybookKind kind) =>
    kind == DaybookKind.announcement ||
    kind == DaybookKind.file ||
    kind == DaybookKind.report;

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

/// A note's Remind me (F107 B5): the same day picker, then the time in
/// the reminder's own words ("Remind me at…"). Review 102 N1, N2: a time
/// must be chosen (Cancel cancels), starting at the next 5-minute mark an
/// hour on, and one already passed today is greyed. A stand-in for
/// [pickDueProvider] (tests) stands in here too.
final pickReminderProvider = Provider<PickDue>((ref) {
  final due = ref.watch(pickDueProvider);
  return identical(due, _pickDue) ? _pickReminder : due;
});

Future<PickedDue?> _pickReminder(
  BuildContext context, {
  required DateTime now,
  DateTime? day,
  DateTime? at,
}) => _pickDue(context, now: now, day: day, at: at, reminder: true);

Future<PickedDue?> _pickDue(
  BuildContext context, {
  required DateTime now,
  DateTime? day,
  DateTime? at,
  bool reminder = false,
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
  final time = await showBvTimeWheel(
    context,
    initial: TimeOfDay.fromDateTime(at ?? nextFiveMinutesAfterAnHour(now)),
    title: reminder ? l10n.notebookRemindTime : l10n.daybookDueTimeHelp,
    cancelLabel: reminder ? null : l10n.daybookNoTime,
    after: reminder && pickedDay == today ? TimeOfDay.fromDateTime(now) : null,
  );
  // A reminder has a time: its Cancel cancels.
  if (time == null && reminder) return null;
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
  if (day == null) return (until: null);
  // F82: a time chosen before stays, on the new day; with none the pin ends
  // with that day, at the phone's next midnight.
  return (
    until: until != null && pinHasTime(until)
        ? _on(day, TimeOfDay.fromDateTime(until.toLocal()))
        : pinToEndOf(day),
  );
}

/// The time an announcement's pin ends (F82, "+ Time"): the time wheels
/// (review 102 N2). Null when cancelled. A provider so tests can stand in.
typedef PickPinTime =
    Future<TimeOfDay?> Function(
      BuildContext context, {
      required TimeOfDay initial,
    });

final pickPinTimeProvider = Provider<PickPinTime>((ref) => _pickPinTime);

Future<TimeOfDay?> _pickPinTime(
  BuildContext context, {
  required TimeOfDay initial,
}) => showBvTimeWheel(
  context,
  initial: initial,
  title: AppLocalizations.of(context).daybookPinTimeHelp,
);

/// An announcement pins for at most this many days (create_space_post).
const pinDaysMax = 90;

/// When an activity starts and, if chosen, ends: the day, the start time,
/// then an optional end time ("No end time"), the times on the wheels
/// (review 102 N2). Null when cancelled. A provider so tests can stand in
/// for the pickers.
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
  final from = await showBvTimeWheel(
    context,
    initial: TimeOfDay.fromDateTime(start ?? nextFiveMinutesAfterAnHour(now)),
    title: l10n.daybookStartsAtHelp,
  );
  if (from == null || !context.mounted) return null;
  final startsAt = _on(day, from);
  final to = await showBvTimeWheel(
    context,
    initial: TimeOfDay.fromDateTime(end ?? startsAt.add(_nextHour)),
    title: l10n.daybookEndsAtHelp,
    cancelLabel: l10n.daybookNoEndTime,
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
  DaybookKind.report => l10n.daybookKindReport,
};

/// The kind menu's icon for [kind] (E6 v14 2598:36360).
IconData kindIcon(DaybookKind kind) => switch (kind) {
  DaybookKind.note => BvIcons.edit,
  DaybookKind.workItem => BvIcons.confirmed,
  DaybookKind.checklist => BvIcons.workItems,
  DaybookKind.announcement => BvIcons.info,
  DaybookKind.activity => BvIcons.due,
  DaybookKind.file => BvIcons.document,
  DaybookKind.report => BvIcons.clipboard,
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

  /// Review 105 Part 6: an announcement starts pinned until today ends,
  /// at the phone's midnight (the lead's ruling Q5; the Space's own time
  /// zone comes in 105B), as a morning brief; + changes or removes it.
  Future<void> setKind(DaybookKind kind) => _put(
    (d) => d.copyWith(
      kind: kind,
      pinnedUntil: kind == DaybookKind.announcement && d.pinnedUntil == null
          ? () => pinToEndOf(dayOf(ref.read(clockProvider)()))
          : null,
    ),
  );
  Future<void> setTitle(String text) => _put((d) => d.copyWith(title: text));
  Future<void> setBody(String text) => _put((d) => d.copyWith(body: text));

  /// Who it goes to: a Team, or Everyone (null).
  Future<void> setTeam(SpaceTeam? team) => _put(
    (d) => d.copyWith(
      team: () => team == null ? null : (id: team.id, name: team.name),
    ),
  );

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

  /// Fills the card from [t] (slice 7, review 78 §1); a Team's template
  /// sets the audience to [team]. A report takes its On site and Problems.
  Future<void> useTemplate(
    AppLocalizations l10n,
    PostTemplate t, {
    SpaceTeam? team,
  }) => _put((d) {
    if (d.kind != DaybookKind.report) {
      return fillFromTemplate(l10n, d, t, team: team);
    }
    final words = reportSections(t);
    return d.copyWith(
      onSite: words.onSite.isEmpty ? d.onSite : words.onSite,
      problems: words.problems.isEmpty ? d.problems : words.problems,
      team: t.teamId == null || team == null
          ? null
          : () => (id: team.id, name: team.name),
      template: () => (id: t.id, name: templateName(l10n, t), blocks: const []),
    );
  });

  /// A daily report for [day] (slice 7): its title the day, from the
  /// built-in Daily report (no "From:" line for it).
  Future<void> startReport(DateTime day, {required String title}) => _put(
    (d) => d.copyWith(
      kind: DaybookKind.report,
      title: title,
      reportDay: () => day,
      template: () =>
          (id: PostTemplate.dailyReportId, name: null, blocks: const []),
    ),
  );

  /// ✕ on "From:": no longer from a template; what was written stays.
  Future<void> dropTemplate() => _put((d) => d.copyWith(template: () => null));

  /// A daily report's lines (slice 7).
  Future<void> setOnSite(String text) => _put((d) => d.copyWith(onSite: text));
  Future<void> setProblems(String text) =>
      _put((d) => d.copyWith(problems: text));

  /// Takes a Done today line out of the report, or a note out of On site.
  Future<void> takeOut(ReportRef r) => _put(
    (d) => r.isNote
        ? d.copyWith(
            notes: [
              for (final n in d.notes)
                if (n.postId != r.postId) n,
            ],
          )
        : d.copyWith(refsOut: {...d.refsOut, r.postId}.toList()),
  );

  /// Adds one of the day's notes under On site.
  Future<void> addNote(ReportRef note) => _put(
    (d) => d.notes.any((n) => n.postId == note.postId)
        ? d
        : d.copyWith(notes: [...d.notes, note]),
  );

  /// The day's checked work, as daily_report_fill gave it now.
  Future<void> setChecked(List<ReportRef> refs) =>
      _put((d) => listEquals(d.refs, refs) ? d : d.copyWith(refs: refs));

  /// The page a report goes with, made just before Post.
  Future<void> setPage(List<Map<String, dynamic>> blocks) =>
      _put((d) => d.copyWith(blocks: blocks));

  /// How many more photos and files the post takes (post_files: 10).
  int get room {
    final d = draft;
    if (d == null) return 0;
    return DaybookPostDraft.filesMax - d.photos.length - d.files.length;
  }

  /// The writing card's photos still being prepared.
  PhotosPreparing get _preparing =>
      ref.read(photosPreparingProvider('daybook:$spaceId').notifier);

  /// A photo from the camera, kept in the app's folder. How many photos
  /// nobody could open, and so were left out (review 74 H1).
  Future<int> addPhoto() async {
    if (room <= 0) return 0;
    final picked = await ref.read(pickPhotoProvider)(
      camera: true,
      onPreparing: _preparing.set,
    );
    await _keep(picked.photos);
    return picked.refused;
  }

  /// Photos from the gallery (K4: up to 10 on a post), as [addPhoto].
  Future<int> addPhotos() async {
    final left = room;
    if (left <= 0) return 0;
    final picked = await ref.read(pickPhotosProvider)(
      max: left,
      onPreparing: _preparing.set,
    );
    await _keep(picked.photos.take(left));
    return picked.refused;
  }

  Future<void> _keep(Iterable<XFile> photos) async {
    final kept = [for (final p in photos) await ref.read(keepPhotoProvider)(p)];
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

  /// F71: the file goes as a new file, not a new version.
  Future<void> notReplacing(DraftFile file) => _put(
    (d) => d.copyWith(
      files: [
        for (final f in d.files) f.libraryId == file.libraryId ? f.asNew : f,
      ],
    ),
  );

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
    // A work item's points go only with the page that shows them (a
    // template's, slice 7).
    final listed = {
      for (final b in d.blocks)
        if (b['type'] == 'checklist_ref')
          for (final id in b['point_ids'] as List? ?? const []) '$id',
    };
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
              quote: workItem ? d.quote : null,
              sourceMessageId: workItem ? d.sourceMessageId : null,
              templateId: workItem ? d.templateId : null,
              teamId: workItem ? d.teamId : null,
              noteId: workItem ? d.noteId : null,
              blocks: workItem && d.blocks.isNotEmpty ? d.blocks : null,
              points: workItem
                  ? [
                      for (final p in d.writtenPoints)
                        if (listed.contains(p.id)) p,
                    ]
                  : const [],
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
    required this.onPickPinTime,
    required this.onPickStart,
    required this.onPickFile,
    required this.onPickPeople,
    this.editing = false,
    this.askWho,
    this.onWalk,
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

  /// "+ Time" on the pin (F82).
  final VoidCallback onPickPinTime;
  final VoidCallback onPickStart;
  final VoidCallback onPickFile;
  final VoidCallback onPickPeople;

  /// Walk, the last kind chip: starts walk mode. Null for who may not
  /// post work (no chip).
  final VoidCallback? onWalk;

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
    DaybookKind.workItem => l10n.daybookWritingDetails,
    DaybookKind.announcement => l10n.daybookBodyAnnouncement,
    DaybookKind.activity => l10n.daybookBodyActivity,
    DaybookKind.note ||
    DaybookKind.checklist ||
    DaybookKind.file ||
    DaybookKind.report => l10n.daybookBodyNote,
  };

  /// Under the words: a checklist's points, and the message it is made
  /// from (review 64, DM5), on every kind (F83).
  Widget? _extra(
    DaybookKind kind,
    DaybookPostDraft draft,
    DaybookWords words,
    DateTime now, {
    required bool writing,
  }) {
    final quote = draft.quote == null
        ? null
        : BvQuoteBlock(
            key: const Key('writing-quote'),
            from: words.quoteFrom(draft.quote!, now),
            text: draft.quote!.text,
            maxLines: BvQuoteSpec.linesWriting,
          );
    if (kind != DaybookKind.checklist) return quote;
    final points = DaybookPointsEditor(
      key: ValueKey('points-${draft.id}-${draft.templateId}'),
      points: draft.points,
      writing: writing,
      onChanged: _writer.setPoints,
    );
    return quote == null
        ? points
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvSpace.s8,
            children: [quote, points],
          );
  }

  /// Review 105 SP2: For · Place · Due · Team, as the kind uses them. For
  /// a work item is one person (Give to's picker); a checklist's and an
  /// activity's are people. Team is "Whole Space" until one is chosen.
  List<BvWritingRow> _rows(
    AppLocalizations l10n,
    DaybookPostDraft draft,
    DaybookWords words,
    DateTime now, {
    required String? me,
    required List<SpaceTeam> teams,
    required VoidCallback? Function(VoidCallback f) tap,
    required void Function(DaybookWritingMenu m) menu,
  }) {
    final kind = draft.kind;
    BvWritingRow choose(VoidCallback onTap) => BvWritingRow(
      key: const Key('writing-who'),
      label: l10n.daybookRowFor,
      value: widget.askWho == null
          ? l10n.daybookRowChoose
          : l10n.daybookChooseWho,
      empty: true,
      ask: widget.askWho,
      onTap: tap(onTap),
    );
    BvWritingRow people(VoidCallback onTap) => draft.people.isEmpty
        ? choose(onTap)
        : BvWritingRow(
            key: const Key('writing-who'),
            label: l10n.daybookRowFor,
            value: words.peopleFor([
              for (final p in draft.people)
                DaybookPerson(id: p.id, name: p.name),
            ], me: me),
            onTap: tap(onTap),
          );
    BvWritingRow owner() {
      final id = draft.ownerId;
      // An edit keeps the owner: Give to someone else changes it.
      if (id == null) return choose(() => menu(DaybookWritingMenu.assign));
      final name = personName(l10n, draft.ownerName);
      return BvWritingRow(
        key: const Key('writing-who'),
        label: l10n.daybookRowFor,
        value: id == me ? l10n.daybookYou : name,
        person: name,
        tint: BvAvatarTints.forId(id),
        onTap: widget.editing
            ? null
            : tap(() => menu(DaybookWritingMenu.assign)),
      );
    }

    final place = BvWritingRow(
      key: const Key('writing-place-row'),
      label: l10n.daybookRowPlace,
      value: draft.place ?? l10n.daybookRowAdd,
      empty: draft.place == null,
      onTap: tap(() => menu(DaybookWritingMenu.place)),
    );
    final due = BvWritingRow(
      key: const Key('writing-due-row'),
      label: l10n.daybookRowDue,
      value: draft.dueDate == null
          ? l10n.daybookRowAdd
          : words.dueProperty(draft.dueDate!, draft.dueAt),
      empty: draft.dueDate == null,
      onTap: tap(widget.onPickDue),
    );
    final team = BvWritingRow(
      key: const Key('writing-to'),
      label: l10n.daybookRowTeam,
      value: draft.teamName ?? l10n.daybookWholeSpace,
      onTap: teams.isEmpty || widget.editing
          ? null
          : tap(() => menu(DaybookWritingMenu.audience)),
    );
    return switch (kind) {
      DaybookKind.workItem => [owner(), place, due, team],
      DaybookKind.checklist => [people(widget.onPickPeople), due, team],
      DaybookKind.activity => [
        people(widget.onPickPeople),
        place,
        BvWritingRow(
          key: const Key('writing-when-row'),
          label: l10n.daybookRowWhen,
          value: draft.startsAt == null
              ? l10n.daybookRowAdd
              : words.activityWhen(draft.startsAt!, draft.endsAt, now),
          empty: draft.startsAt == null,
          onTap: tap(widget.onPickStart),
        ),
        team,
      ],
      // Note has no For or Due (review 105 Part 3).
      DaybookKind.note || DaybookKind.announcement => [team],
      DaybookKind.file || DaybookKind.report => const [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = widget.editing
        ? daybookEditProvider(widget.spaceId)
        : daybookDraftProvider(widget.spaceId);
    // Slice 7: a template filled the card; its boxes show the new words
    // (typing never comes through here: it fills the draft from the box).
    ref.listen(provider, (was, now) {
      if (now == null || now.templateId == null) return;
      if (was?.templateId == now.templateId) return;
      if (_title.text != now.title) _title.text = now.title;
      if (_body.text != now.body) _body.text = now.body;
    });
    final draft = ref.watch(provider);
    if (draft == null) return const SizedBox.shrink();
    final preparing = ref.watch(
      photosPreparingProvider('daybook:${widget.spaceId}'),
    );
    final writing = widget.writing;
    final words = widget.words;
    final now = ref.watch(clockProvider)();
    VoidCallback? tap(VoidCallback f) => writing ? f : null;
    void menu(DaybookWritingMenu m) => writing ? widget.onMenu(m) : null;
    final kind = draft.kind;
    final me = ref.watch(authUserIdProvider).value;
    final teams = audienceTeams(
      ref.watch(spacePeopleProvider(widget.spaceId)).value,
      me: me,
      admin:
          ref.watch(spaceDetailProvider(widget.spaceId)).value?.iAmAdmin ??
          false,
    );
    final properties = <BvWritingProperty>[
      // Slice 7 (review 79 §1): the template it started from, grey and
      // small, with ✕; dropping it keeps what was written.
      if (draft.templateName != null && draft.templateId != null)
        BvWritingProperty.icon(
          key: const Key('writing-template'),
          icon: BvIcons.clipboard,
          label: l10n.templateFrom(inOwnDirection(draft.templateName!)),
          empty: true,
          onRemove: writing ? () => unawaited(_writer.dropTemplate()) : null,
          removeLabel: l10n.templateDrop,
        ),
      // F56: a Document for receipt and a daily report go to Everyone or
      // a Team, already filled; a tap chooses (an edit keeps it). The
      // other kinds have the Team row (review 105 SP2).
      if (goesToAudience(kind) && !rowKinds.contains(kind))
        BvWritingProperty.icon(
          key: const Key('writing-to'),
          icon: BvIcons.team,
          label: l10n.daybookToAudience(draft.teamName ?? l10n.daybookEveryone),
          // F72: a file goes to the whole Space (Team-only files aren't in
          // the pilot), so its To isn't a choice.
          caret:
              teams.isNotEmpty && !widget.editing && kind != DaybookKind.file,
          onTap: kind == DaybookKind.file && !widget.editing
              ? () => showSpaceMessage(context, l10n.daybookFileToEveryone)
              : teams.isEmpty || widget.editing
              ? null
              : tap(() => menu(DaybookWritingMenu.audience)),
        ),
      if (kind == DaybookKind.announcement && draft.pinnedUntil != null) ...[
        BvWritingProperty.icon(
          key: const Key('writing-pin'),
          icon: BvIcons.pin,
          label: l10n.daybookPinnedProperty(
            words.pinnedShort(draft.pinnedUntil!, now),
          ),
          onTap: tap(widget.onPickPin),
          // F82: ✕ takes the time away; the pin then ends with its day.
          onRemove: writing && pinHasTime(draft.pinnedUntil!)
              ? () => unawaited(
                  _writer.setPin(
                    pinToEndOf(dayOf(pinnedLastDay(draft.pinnedUntil!))),
                  ),
                )
              : null,
          removeLabel: l10n.daybookPinRemoveTime,
        ),
        if (writing && !pinHasTime(draft.pinnedUntil!))
          BvWritingProperty.icon(
            key: const Key('pin-add-time'),
            icon: BvIcons.due,
            label: l10n.daybookPinAddTime,
            empty: true,
            onTap: tap(widget.onPickPinTime),
          ),
      ],
      // A work item's files (attached from 📎) and a file post's file.
      for (final f in draft.files)
        BvWritingProperty.icon(
          icon: BvIcons.document,
          label: [
            f.revLabel == null
                ? f.name
                : l10n.daybookFileChip(f.name, f.revLabel!),
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
      // F71: "Replaces A-501 · V2", with ✕ to make it a new file.
      for (final f in draft.files)
        if (f.supersedesRev != null && f.local != null)
          BvWritingProperty.icon(
            key: Key('writing-replaces-${f.libraryId}'),
            icon: BvIcons.newAbove,
            label: l10n.daybookReplacesOption(f.supersedesRev!),
            onRemove: writing && f.local != null
                ? () => unawaited(_writer.notReplacing(f))
                : null,
            removeLabel: l10n.daybookNotNewVersion,
          ),
    ];
    final rows = rowKinds.contains(kind)
        ? _rows(
            l10n,
            draft,
            words,
            now,
            me: me,
            teams: teams,
            tap: tap,
            menu: menu,
          )
        : const <BvWritingRow>[];
    // Review 105 SP2: the kinds as one choice, Work item first chosen; an
    // edit, a file post and a daily report stay the kind they are.
    final chooses = writing && !widget.editing && rowKinds.contains(kind);
    final card = BvWritingCard(
      key: const Key('daybook-writing-card'),
      kinds: chooses
          ? BvKindChips<Object>(
              key: const Key('writing-kinds'),
              choices: [
                for (final k in rowKinds)
                  BvKindChoice(
                    value: k,
                    label: kindName(l10n, k),
                    icon: kindIcon(k),
                  ),
                if (widget.onWalk != null)
                  BvKindChoice(
                    value: kindChipWalk,
                    label: l10n.daybookKindWalk,
                    icon: BvIcons.camera,
                  ),
              ],
              selected: kind,
              onSelected: (k) => k is DaybookKind
                  ? unawaited(_writer.setKind(k))
                  : widget.onWalk?.call(),
            )
          : null,
      rows: rows.isEmpty ? null : BvWritingRows(rows: rows),
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
      kindLabel: writing && !chooses ? kindName(l10n, kind) : null,
      // A daily report stays one (it starts from the Space menu).
      onKindTap: writing && !widget.editing && kind != DaybookKind.report
          ? () => menu(DaybookWritingMenu.kind)
          : null,
      properties: properties,
      // A daily report has its own sections (R2) in place of the words.
      showBody: kind != DaybookKind.report,
      extra: kind == DaybookKind.report
          ? ReportWriting(
              key: ValueKey('report-${draft.id}'),
              writer: _writer,
              draft: draft,
              words: words,
              writing: writing,
            )
          : _extra(kind, draft, words, now, writing: writing),
      photos: [
        for (final p in draft.photos)
          Image(image: ref.watch(localPhotoProvider(p)), fit: BoxFit.cover),
      ],
      preparing: preparing,
      preparingLabel: l10n.photoPreparing,
      photoHeight: draft.photos.length + preparing > 1
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
      // F69: me first, as You.
      meId: me,
      meLabel: l10n.daybookYou,
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
    required this.onPickTemplate,
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

  /// "Template" (slice 7): start from one of this kind's templates.
  final VoidCallback onPickTemplate;

  @override
  ConsumerState<DaybookWritingPopover> createState() => _PopoverState();
}

enum _More { template, assign, people, location, due, pin, time, file }

/// Everyone, in the To menu (a Team is chosen by its id).
const _everyone = '';

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

  List<BvMenuItem<_More>> _moreItems(
    AppLocalizations l10n,
    DaybookPostDraft? draft,
  ) {
    final kind = draft?.kind ?? DaybookKind.workItem;
    final template = [
      if (writingHasTemplates(
        ref,
        widget.spaceId,
        draft,
        editing: widget.editing,
      ))
        BvMenuItem(
          value: _More.template,
          label: l10n.templateMenu,
          icon: BvIcons.clipboard,
        ),
    ];
    return [...template, ..._kindItems(l10n, kind)];
  }

  List<BvMenuItem<_More>> _kindItems(AppLocalizations l10n, DaybookKind kind) {
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
    // Review 105 SP2: For · Place · Due · Team are rows on the card; a
    // daily report and a file post keep theirs here.
    if (rowKinds.contains(kind)) {
      return [
        if (kind == DaybookKind.announcement)
          BvMenuItem(
            value: _More.pin,
            label: l10n.daybookPinUntil,
            icon: BvIcons.pin,
          ),
      ];
    }
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
      // F72: one way to add a file, the paper clip.
      DaybookKind.file => const [],
      DaybookKind.report => const [],
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
          items: _moreItems(l10n, draft),
          onSelected: (v) => switch (v) {
            _More.template => widget.onPickTemplate(),
            _More.assign => widget.onMenu(DaybookWritingMenu.assign),
            _More.people => widget.onPickPeople(),
            _More.location => widget.onMenu(DaybookWritingMenu.place),
            _More.due => widget.onPickDue(),
            _More.pin => widget.onPickPin(),
            _More.time => widget.onPickStart(),
            _More.file => widget.onPickFile(),
          },
        );
      case DaybookWritingMenu.audience:
        final teams = audienceTeams(
          ref.watch(spacePeopleProvider(widget.spaceId)).value,
          me: widget.me,
          admin:
              ref.watch(spaceDetailProvider(widget.spaceId)).value?.iAmAdmin ??
              false,
        );
        // One choice: Everyone or one Team (rule 6).
        return BvPopoverMenu<String>.picker(
          key: const Key('writing-to-menu'),
          selected: draft?.teamId ?? _everyone,
          items: [
            BvMenuItem(
              value: _everyone,
              label: l10n.daybookEveryone,
              icon: BvIcons.people,
            ),
            for (final t in teams)
              BvMenuItem(value: t.id, label: t.name, icon: BvIcons.team),
          ],
          onSelected: (id) async {
            await _writer.setTeam(teams.where((t) => t.id == id).firstOrNull);
            widget.onClose();
          },
        );
      case DaybookWritingMenu.kind:
        return BvPopoverMenu<DaybookKind>.picker(
          key: const Key('writing-kind-menu'),
          wide: true,
          selected: kind,
          items: [
            for (final k in DaybookKind.values)
              BvMenuItem(value: k, label: kindName(l10n, k), icon: kindIcon(k)),
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
          // F69: me first, as You.
          meId: widget.me,
          meLabel: l10n.daybookYou,
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
