import 'package:shared_preferences/shared_preferences.dart';

import 'daybook_draft.dart';

/// Review 110 CP3: what + adds, in the grid's order (founder, 11:49).
enum ComposerExtra {
  place('place'),
  due('due'),
  tag('tag'),
  photos('photos'),
  file('file'),
  checklist('checklist'),
  bullets('bullets'),
  table('table'),
  taskTable('task_table'),
  // Kept from before review 110 (not in the founder's table, but no
  // other changes): an announcement's pin, and a template.
  pin('pin'),
  template('template');

  const ComposerExtra(this.key);

  /// Its tile's key: "composer-extra-[key]".
  final String key;
}

/// The kinds # offers, in the grid's order (CP2). Walk follows them;
/// Check-in waits for review 109. A checklist is no longer a kind to
/// start (founder, 13:42): a work item takes ticks from + → Checklist.
const composerKinds = [
  DaybookKind.note,
  DaybookKind.workItem,
  DaybookKind.announcement,
  DaybookKind.activity,
];

/// Each kind shows only its own extras (CP3, the founder's table), then
/// Template where the Space has one for it (slice 7, kept).
List<ComposerExtra> composerExtras(DaybookKind kind) => switch (kind) {
  DaybookKind.note => const [
    ComposerExtra.photos,
    ComposerExtra.file,
    ComposerExtra.place,
    ComposerExtra.bullets,
    ComposerExtra.table,
    ComposerExtra.template,
  ],
  DaybookKind.workItem => const [
    ComposerExtra.place,
    ComposerExtra.due,
    ComposerExtra.photos,
    ComposerExtra.file,
    ComposerExtra.bullets,
    ComposerExtra.table,
    ComposerExtra.taskTable,
    ComposerExtra.template,
  ],
  DaybookKind.checklist => const [
    ComposerExtra.due,
    ComposerExtra.photos,
    ComposerExtra.bullets,
    ComposerExtra.template,
  ],
  DaybookKind.announcement => const [
    ComposerExtra.photos,
    ComposerExtra.file,
    ComposerExtra.bullets,
    ComposerExtra.table,
    ComposerExtra.pin,
    ComposerExtra.template,
  ],
  DaybookKind.activity => const [
    ComposerExtra.place,
    ComposerExtra.photos,
    ComposerExtra.file,
    ComposerExtra.bullets,
    ComposerExtra.template,
  ],
  // A file post is its file: + → File changes it (F72, as 📎 did).
  DaybookKind.file => const [ComposerExtra.file],
  DaybookKind.report => const [],
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
enum ComposerDrop { owner, people, place, due, start, pin, files, tables }

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
    if (draft.people.isNotEmpty && kind != DaybookKind.checklist)
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
  // A pin is an announcement's alone; it goes quietly.
  if (kind != DaybookKind.announcement) json.remove('pinned_until');
  if (drops.contains(ComposerDrop.tables)) {
    json['blocks'] = [
      for (final b in draft.blocks)
        if (kept(b)) b,
    ];
  }
  return DaybookPostDraft.fromJson(json);
}

/// G1: the kind the composer opens on is the last one posted in this
/// Space, kept on the phone; Note the first time.
String composerKindKey(String spaceId) => 'composer_kind:$spaceId';

DaybookKind composerStartKind(SharedPreferences prefs, String spaceId) {
  final kept = prefs.getString(composerKindKey(spaceId));
  if (kept == null) return DaybookKind.note;
  final kind = DaybookKind.fromJson(kept);
  return composerKinds.contains(kind) ? kind : DaybookKind.note;
}

Future<void> rememberComposerKind(
  SharedPreferences prefs,
  String spaceId,
  DaybookKind kind,
) async {
  if (!composerKinds.contains(kind)) return;
  await prefs.setString(composerKindKey(spaceId), kind.json);
}
