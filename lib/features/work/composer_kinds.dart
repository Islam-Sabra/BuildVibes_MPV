import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/space.dart';
import 'daybook_draft.dart';

/// Review 110 CP3: what + adds, in the grid's order (founder, 11:49).
enum ComposerExtra {
  place('place'),
  // An activity's people, if wanted (founder, 31 Oct).
  people('people'),
  due('due'),
  tag('tag'),
  photos('photos'),
  file('file'),
  checklist('checklist'),
  bullets('bullets'),
  table('table'),
  taskTable('task_table'),
  // Kept from before review 110: an announcement's pin (W9). A template
  // is on the composer's top bar (W9), not here.
  pin('pin'),

  /// Review 109 CI1b: a Check-in's check-out (a time and an allowance),
  /// and Every day (the market pack's working days).
  checkOut('check_out'),
  everyDay('every_day');

  const ComposerExtra(this.key);

  /// Its tile's key: "composer-extra-[key]".
  final String key;
}

/// The kinds # offers, in the grid's order (CP2). Walk follows them;
/// Check-in (review 109, for Leads only) and Thanks (review 110 TH1) come
/// before Walk. A checklist is no longer a kind to
/// start (founder, 13:42): a work item takes ticks from + → Checklist.
const composerKinds = [
  DaybookKind.note,
  DaybookKind.workItem,
  DaybookKind.announcement,
  DaybookKind.activity,
  DaybookKind.checkIn,
  DaybookKind.thanks,
];

/// Each kind shows only its own extras (CP3, the founder's table; W9).
List<ComposerExtra> composerExtras(DaybookKind kind) => switch (kind) {
  DaybookKind.note => const [
    ComposerExtra.photos,
    ComposerExtra.file,
    ComposerExtra.place,
    ComposerExtra.bullets,
    ComposerExtra.table,
  ],
  DaybookKind.workItem => const [
    ComposerExtra.place,
    ComposerExtra.due,
    ComposerExtra.tag,
    ComposerExtra.photos,
    ComposerExtra.file,
    ComposerExtra.checklist,
    ComposerExtra.bullets,
    ComposerExtra.table,
    ComposerExtra.taskTable,
  ],
  DaybookKind.checklist => const [
    ComposerExtra.due,
    ComposerExtra.photos,
    ComposerExtra.bullets,
  ],
  DaybookKind.announcement => const [
    ComposerExtra.photos,
    ComposerExtra.file,
    ComposerExtra.bullets,
    ComposerExtra.table,
    ComposerExtra.pin,
  ],
  DaybookKind.activity => const [
    ComposerExtra.place,
    ComposerExtra.people,
    ComposerExtra.photos,
    ComposerExtra.file,
    ComposerExtra.bullets,
  ],
  // TH1: a Thanks takes photos only.
  DaybookKind.thanks => const [ComposerExtra.photos],
  // A file post is its file: + → File changes it (F72, as 📎 did).
  DaybookKind.file => const [ComposerExtra.file],
  DaybookKind.report => const [],
  // Review 109 CI1b: + offers exactly Check-out and Every day.
  DaybookKind.checkIn => const [ComposerExtra.checkOut, ComposerExtra.everyDay],
};

/// An edit of a posted work item changes only its place and its due from
/// + (an edit keeps its photos and files; the owner changes with Give to).
const composerEditExtras = {ComposerExtra.place, ComposerExtra.due};

/// What + offers: the kind's extras, or an edit's.
List<ComposerExtra> composerOffered(DaybookKind kind, {bool editing = false}) =>
    [
      for (final e in composerExtras(kind))
        if (!editing || composerEditExtras.contains(e)) e,
    ];

/// What a kind switch takes away (CP3: "Due was removed: an announcement
/// has none"). Title, words and photos always stay.
enum ComposerDrop {
  owner,
  people,
  place,
  due,
  start,
  pin,
  files,
  tables,

  /// A Thanks's To and For (review 110 TH1).
  thanks,

  /// A work item's tag (TG1).
  tag,

  /// A work item's checklist from + (step 5): its points and their block.
  checklist,

  /// A Check-in's times, Teams and place (review 109).
  checkIn,

  /// Photos: a Check-in has no camera (review 109 §1).
  photos,
}

bool _isChecklist(Map<String, dynamic> b) => b['type'] == 'checklist_ref';

/// What [draft] holds that [kind] doesn't take.
List<ComposerDrop> composerDrops(DaybookPostDraft draft, DaybookKind kind) {
  final extras = composerExtras(kind);
  final tables = draft.blocks.any(
    (b) =>
        (b['type'] == 'table' && !extras.contains(ComposerExtra.table)) ||
        (b['type'] == 'task_table' &&
            !extras.contains(ComposerExtra.taskTable)),
  );
  return [
    if (draft.ownerId != null && kind != DaybookKind.workItem)
      ComposerDrop.owner,
    if (draft.people.isNotEmpty &&
        kind != DaybookKind.checklist &&
        kind != DaybookKind.activity)
      ComposerDrop.people,
    if ((draft.place != null || draft.placeId != null) &&
        !extras.contains(ComposerExtra.place))
      ComposerDrop.place,
    if (draft.dueDate != null && !extras.contains(ComposerExtra.due))
      ComposerDrop.due,
    if (draft.startsAt != null && kind != DaybookKind.activity)
      ComposerDrop.start,
    if (draft.files.isNotEmpty && !extras.contains(ComposerExtra.file))
      ComposerDrop.files,
    if (tables) ComposerDrop.tables,
    if ((draft.thanksToId != null || draft.thanksForId != null) &&
        kind != DaybookKind.thanks)
      ComposerDrop.thanks,
    if (draft.tag != null && !extras.contains(ComposerExtra.tag))
      ComposerDrop.tag,
    if (draft.blocks.any(_isChecklist) &&
        !extras.contains(ComposerExtra.checklist))
      ComposerDrop.checklist,
    if (kind != DaybookKind.checkIn &&
        (draft.placeReady ||
            draft.inTime != null ||
            draft.outTime != null ||
            draft.daily ||
            draft.checkInTeams.isNotEmpty))
      ComposerDrop.checkIn,
    if (kind == DaybookKind.checkIn && draft.photos.isNotEmpty)
      ComposerDrop.photos,
  ];
}

/// [draft] as [kind], without what [drops] names.
DaybookPostDraft composerSwitched(
  DaybookPostDraft draft,
  DaybookKind kind,
  List<ComposerDrop> drops,
) {
  final extras = composerExtras(kind);
  bool kept(Map<String, dynamic> b) =>
      !(b['type'] == 'table' && !extras.contains(ComposerExtra.table)) &&
      !(b['type'] == 'task_table' && !extras.contains(ComposerExtra.taskTable));
  final json = {...draft.toJson(), 'kind': kind.json};
  void drop(ComposerDrop d, List<String> keys) {
    if (!drops.contains(d)) return;
    for (final k in keys) {
      json.remove(k);
    }
  }

  drop(ComposerDrop.owner, ['owner_id', 'owner_name']);
  drop(ComposerDrop.people, ['people']);
  drop(ComposerDrop.place, ['place', 'place_id']);
  drop(ComposerDrop.due, ['due_date', 'due_at']);
  drop(ComposerDrop.start, ['starts_at', 'ends_at']);
  drop(ComposerDrop.files, ['files']);
  drop(ComposerDrop.thanks, [
    'thanks_to_id',
    'thanks_to_name',
    'thanks_to_team',
    'thanks_for_id',
    'thanks_for_label',
  ]);
  drop(ComposerDrop.tag, ['tag']);
  drop(ComposerDrop.checkIn, [
    'check_in_teams',
    'in_time',
    'in_allow',
    'out_time',
    'out_allow',
    'daily',
    'site_lat',
    'site_lng',
  ]);
  drop(ComposerDrop.photos, ['photos']);
  // A pin is an announcement's alone; it goes quietly.
  if (kind != DaybookKind.announcement) json.remove('pinned_until');
  if (drops.contains(ComposerDrop.tables)) {
    json['blocks'] = [
      for (final b in draft.blocks)
        if (kept(b)) b,
    ];
  }
  if (drops.contains(ComposerDrop.checklist)) {
    final listed = {
      for (final b in draft.blocks)
        if (_isChecklist(b))
          for (final id in b['point_ids'] as List? ?? const []) '$id',
    };
    json['blocks'] = [
      for (final b in json['blocks'] as List)
        if (!_isChecklist(b as Map<String, dynamic>)) b,
    ];
    json['points'] = [
      for (final p in draft.points)
        if (!listed.contains(p.id)) {'id': p.id, 'text': p.text},
    ];
  }
  return DaybookPostDraft.fromJson(json);
}

/// The kinds [space]'s reader may post from #. Who may not post work (a
/// Viewer, or a Crew pass with posting locked) may still thank (founder,
/// 1 Nov: create_thanks takes any member), and only thank. Review 109's
/// Check-in is for a Lead and the Space admin only (post_check_in).
List<DaybookKind> composerKindsFor(SpaceDetail space) {
  if (!space.myRights.createItems) return const [DaybookKind.thanks];
  if (space.myPass == SpacePass.lead || space.iAmAdmin) return composerKinds;
  return [
    for (final k in composerKinds)
      if (k != DaybookKind.checkIn) k,
  ];
}

/// G1: the kind the composer opens on is the last one posted in this
/// Space, kept on the phone; Note the first time. W11: only one of
/// [kinds] (what this person may post); else Note, else the first of them
/// (a Viewer: Thanks).
String composerKindKey(String spaceId) => 'composer_kind:$spaceId';

DaybookKind composerStartKind(
  SharedPreferences prefs,
  String spaceId,
  List<DaybookKind> kinds,
) {
  final kept = prefs.getString(composerKindKey(spaceId));
  final kind = kept == null ? null : DaybookKind.fromJson(kept);
  if (kind != null && kinds.contains(kind)) return kind;
  return kinds.contains(DaybookKind.note) ? DaybookKind.note : kinds.first;
}

Future<void> rememberComposerKind(
  SharedPreferences prefs,
  String spaceId,
  DaybookKind kind,
) async {
  if (!composerKinds.contains(kind)) return;
  await prefs.setString(composerKindKey(spaceId), kind.json);
}
