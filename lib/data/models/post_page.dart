import 'package:flutter/foundation.dart';

import 'daybook.dart';
import 'work_item.dart';

/// One block of a post's page (migration 20's `space_posts.blocks`,
/// checked by `validate_blocks`). Each has its own id, chosen by the app.
@immutable
sealed class PageBlock {
  const PageBlock(this.id);

  final String id;

  String get type;

  Map<String, dynamic> toJson();

  /// A block from the server, or [PageOtherBlock] for a kind this page
  /// doesn't edit (a report's work item), kept as it came.
  static PageBlock fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    String text() => json['text'] as String? ?? '';
    return switch (json['type']) {
      PageText.kind => PageText(id, text()),
      PageHeading.kind => PageHeading(
        id,
        text(),
        level: (json['level'] as num?)?.toInt() == 2 ? 2 : 1,
      ),
      PageToggle.kind => PageToggle(id, text(), [
        for (final c in json['children'] as List? ?? const [])
          PageBlock.fromJson(c as Map<String, dynamic>),
      ]),
      PageTable.kind => PageTable(id, [
        for (final r in json['rows'] as List? ?? const [])
          [for (final c in r as List) '${c ?? ''}'],
      ]),
      PagePhoto.kind => PagePhoto(
        id,
        json['path'] as String? ?? '',
        caption: json['caption'] as String?,
      ),
      PageFile.kind => PageFile(id, json['library_file_id'] as String? ?? ''),
      PageChecklist.kind => PageChecklist(id, [
        for (final p in json['point_ids'] as List? ?? const []) '$p',
      ]),
      PageChildItem.kind => PageChildItem(id, json['post_id'] as String? ?? ''),
      PageTodo.kind => PageTodo(
        id,
        text(),
        done: json['done'] as bool? ?? false,
      ),
      PageBullet.kind => PageBullet(id, text()),
      PageNumbered.kind => PageNumbered(id, text()),
      PageCallout.kind => PageCallout(id, text()),
      PageQuote.kind => PageQuote(id, text()),
      PageDivider.kind => PageDivider(id),
      PageVoice.kind => PageVoice(
        id,
        path: json['path'] as String?,
        local: json['local'] as String?,
        durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      ),
      _ => PageOtherBlock(id, Map.unmodifiable(json)),
    };
  }
}

class PageText extends PageBlock {
  const PageText(super.id, this.text);

  static const kind = 'text';

  /// validate_blocks: up to 2000 characters.
  static const max = 2000;

  final String text;

  @override
  String get type => kind;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'type': kind, 'text': text};
}

class PageHeading extends PageBlock {
  const PageHeading(super.id, this.text, {this.level = 1});

  static const kind = 'heading';
  static const max = 200;

  final String text;
  final int level;

  @override
  String get type => kind;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': kind,
    'text': text,
    'level': level,
  };
}

/// Closed until tapped; holds text, headings, tables, photos and files.
class PageToggle extends PageBlock {
  const PageToggle(super.id, this.text, this.children);

  static const kind = 'toggle';
  static const max = 200;

  /// What a toggle may hold (validate_blocks).
  static const holds = {
    PageText.kind,
    PageHeading.kind,
    PageTable.kind,
    PagePhoto.kind,
    PageFile.kind,
  };

  final String text;
  final List<PageBlock> children;

  @override
  String get type => kind;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': kind,
    'text': text,
    'children': [for (final c in children) c.toJson()],
  };
}

/// The first row is the header. 1–20 rows of 1–8 cells, every row as
/// wide; a cell up to 200 characters.
class PageTable extends PageBlock {
  const PageTable(super.id, this.rows);

  static const kind = 'table';
  static const maxRows = 20;
  static const maxColumns = 8;
  static const cellMax = 200;

  final List<List<String>> rows;

  int get columns => rows.isEmpty ? 0 : rows.first.length;

  @override
  String get type => kind;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'type': kind, 'rows': rows};
}

/// One of the post's own photos (post_files).
class PagePhoto extends PageBlock {
  const PagePhoto(super.id, this.path, {this.caption});

  static const kind = 'photo';
  static const captionMax = 300;

  final String path;
  final String? caption;

  @override
  String get type => kind;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': kind,
    'path': path,
    if ((caption ?? '').isNotEmpty) 'caption': caption,
  };
}

/// A Library file on the post (post_files).
class PageFile extends PageBlock {
  const PageFile(super.id, this.libraryFileId);

  static const kind = 'file';

  final String libraryFileId;

  @override
  String get type => kind;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': kind,
    'library_file_id': libraryFileId,
  };
}

/// Some of the post's checklist points, in this order; each point is in
/// one block only.
class PageChecklist extends PageBlock {
  const PageChecklist(super.id, this.pointIds);

  static const kind = 'checklist_ref';

  /// A point's words, at most (checklist_points).
  static const pointMax = 300;

  /// A work item's title, at most (create_work_item).
  static const itemTitleMax = 140;

  final List<String> pointIds;

  @override
  String get type => kind;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': kind,
    'point_ids': pointIds,
  };
}

/// A work item under this one.
class PageChildItem extends PageBlock {
  const PageChildItem(super.id, this.postId);

  static const kind = 'child_item';

  final String postId;

  @override
  String get type => kind;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'type': kind, 'post_id': postId};
}

// My notebook's own blocks (F107, review 92; migration 44's
// is_valid_note_blocks). A Work post's page doesn't take them.

/// One line of words: a to-do, a bullet, a numbered line, a callout or a
/// quote.
sealed class PageLine extends PageBlock {
  const PageLine(super.id, this.text);

  /// is_valid_note_blocks: up to 5,000 characters.
  static const max = 5000;

  final String text;

  /// The same kind of line, with other words.
  PageLine withText(String text);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'text': text};
}

/// A to-do: ticked or not, by its owner, on the note.
class PageTodo extends PageLine {
  const PageTodo(super.id, super.text, {this.done = false});

  static const kind = 'todo';

  final bool done;

  @override
  String get type => kind;

  @override
  PageTodo withText(String text) => PageTodo(id, text, done: done);

  PageTodo ticked() => PageTodo(id, text, done: !done);

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'done': done};
}

class PageBullet extends PageLine {
  const PageBullet(super.id, super.text);

  static const kind = 'bullet';

  @override
  String get type => kind;

  @override
  PageBullet withText(String text) => PageBullet(id, text);
}

/// Numbered by its place in a run of numbered lines.
class PageNumbered extends PageLine {
  const PageNumbered(super.id, super.text);

  static const kind = 'numbered';

  @override
  String get type => kind;

  @override
  PageNumbered withText(String text) => PageNumbered(id, text);
}

class PageCallout extends PageLine {
  const PageCallout(super.id, super.text);

  static const kind = 'callout';

  @override
  String get type => kind;

  @override
  PageCallout withText(String text) => PageCallout(id, text);
}

class PageQuote extends PageLine {
  const PageQuote(super.id, super.text);

  static const kind = 'quote';

  @override
  String get type => kind;

  @override
  PageQuote withText(String text) => PageQuote(id, text);
}

/// A thin line between parts of a note.
class PageDivider extends PageBlock {
  const PageDivider(super.id);

  static const kind = 'divider';

  @override
  String get type => kind;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'type': kind};
}

/// A voice recording inside a note: in `notebook-files` once sent
/// ([path], one of the note's files), on the phone until then ([local]).
class PageVoice extends PageBlock {
  const PageVoice(super.id, {this.path, this.local, this.durationMs = 0});

  static const kind = 'voice';

  final String? path;
  final String? local;
  final int durationMs;

  Duration get duration => Duration(milliseconds: durationMs);

  PageVoice uploaded(String path) =>
      PageVoice(id, path: path, local: local, durationMs: durationMs);

  @override
  String get type => kind;

  /// As the phone keeps it: with its copy on the phone until it is sent.
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': kind,
    'path': path,
    if (local != null) 'local': local,
    'duration_ms': durationMs,
  };

  /// As save_note takes it.
  Map<String, dynamic> toServer() => {
    'id': id,
    'type': kind,
    'path': path,
    'duration_ms': durationMs,
  };
}

/// A block this page shows nothing for and keeps as it came.
class PageOtherBlock extends PageBlock {
  const PageOtherBlock(super.id, this.raw);

  final Map<String, dynamic> raw;

  @override
  String get type => raw['type'] as String? ?? '';

  @override
  Map<String, dynamic> toJson() => Map.of(raw);
}

/// A work item under this one, as post_page gives it (`under`).
@immutable
class PageUnder {
  const PageUnder({
    required this.id,
    required this.title,
    this.ref,
    this.status = WorkStatus.open,
    this.cancelled = false,
    this.ownerId,
    this.ownerName,
  });

  factory PageUnder.fromJson(Map<String, dynamic> json) => PageUnder(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    ref: json['ref'] as String?,
    status: WorkStatus.fromJson(json['item_status']),
    cancelled: json['status'] == 'cancelled',
    ownerId: json['owner_id'] as String?,
    ownerName: json['owner_name'] as String?,
  );

  final String id;
  final String title;
  final String? ref;
  final WorkStatus status;
  final bool cancelled;
  final String? ownerId;
  final String? ownerName;
}

/// A post's own file, as post_page gives it (`files`).
@immutable
class PageFileRow {
  const PageFileRow({
    required this.id,
    required this.mime,
    this.path,
    this.libraryFileId,
    this.name,
    this.bytes,
  });

  factory PageFileRow.fromJson(Map<String, dynamic> json) => PageFileRow(
    id: json['id'] as String,
    mime: json['mime'] as String? ?? '',
    path: json['path'] as String?,
    libraryFileId: json['library_file_id'] as String?,
    name: json['name'] as String?,
    bytes: (json['bytes'] as num?)?.toInt(),
  );

  final String id;
  final String mime;
  final String? path;
  final String? libraryFileId;
  final String? name;
  final int? bytes;

  bool get isPhoto => libraryFileId == null && mime.startsWith('image/');
}

/// A post's full page (post_page): the post, its blocks at [version], its
/// points, own files and the work items under it.
@immutable
class PostPage {
  const PostPage({
    required this.post,
    this.blocks = const [],
    this.version = 0,
    this.points = const [],
    this.files = const [],
    this.under = const [],
  });

  factory PostPage.fromJson(Map<String, dynamic> json) => PostPage(
    post: DaybookPost.fromJson(json),
    blocks: [
      for (final b in json['blocks'] as List? ?? const [])
        PageBlock.fromJson(b as Map<String, dynamic>),
    ],
    version: (json['blocks_version'] as num?)?.toInt() ?? 0,
    points: [
      for (final p in json['point_list'] as List? ?? const [])
        DaybookPoint(
          id: (p as Map<String, dynamic>)['id'] as String,
          text: p['text'] as String? ?? '',
          tickedAt: p['ticked_at'] == null
              ? null
              : DateTime.parse(p['ticked_at'] as String),
        ),
    ],
    files: [
      for (final f in json['files'] as List? ?? const [])
        PageFileRow.fromJson(f as Map<String, dynamic>),
    ],
    under: [
      for (final u in json['under'] as List? ?? const [])
        PageUnder.fromJson(u as Map<String, dynamic>),
    ],
  );

  /// At most 200 blocks, toggles' included (validate_blocks).
  static const maxBlocks = 200;

  final DaybookPost post;
  final List<PageBlock> blocks;
  final int version;
  final List<DaybookPoint> points;
  final List<PageFileRow> files;
  final List<PageUnder> under;

  /// A file post has no page.
  bool get hasPage => post.kind != DaybookPost.fileKind;

  /// The whole page as blocks: the saved ones, then anything the post
  /// holds that no block shows yet (points, photos, files, work items under
  /// it), so a post written before it had a page opens full, and nothing a
  /// half-made change left goes missing.
  List<PageBlock> get shown {
    final points = <String>{};
    final photos = <String>{};
    final libraryFiles = <String>{};
    final items = <String>{};
    void see(PageBlock b) {
      switch (b) {
        case PageChecklist(:final pointIds):
          points.addAll(pointIds);
        case PagePhoto(:final path):
          photos.add(path);
        case PageFile(:final libraryFileId):
          libraryFiles.add(libraryFileId);
        case PageChildItem(:final postId):
          items.add(postId);
        case PageToggle(:final children):
          children.forEach(see);
        default:
          break;
      }
    }

    blocks.forEach(see);
    final loosePoints = [
      for (final p in this.points)
        if (!points.contains(p.id)) p.id,
    ];
    return [
      ...blocks,
      if (loosePoints.isNotEmpty)
        PageChecklist('points:${post.id}', loosePoints),
      for (final f in files)
        if (f.isPhoto && f.path != null && !photos.contains(f.path))
          PagePhoto('photo:${f.id}', f.path!)
        else if (f.libraryFileId != null &&
            !libraryFiles.contains(f.libraryFileId))
          PageFile('file:${f.id}', f.libraryFileId!),
      for (final u in under)
        if (!items.contains(u.id)) PageChildItem('item:${u.id}', u.id),
    ];
  }

  PostPage copyWith({List<PageBlock>? blocks, int? version}) => PostPage(
    post: post,
    blocks: blocks ?? this.blocks,
    version: version ?? this.version,
    points: points,
    files: files,
    under: under,
  );
}
