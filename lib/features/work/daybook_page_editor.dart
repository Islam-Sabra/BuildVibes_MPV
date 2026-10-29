import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_page_specs.dart';
import '../../core/network/signal_state.dart';
import '../../data/models/daybook.dart';
import '../../data/models/library.dart';
import '../../data/models/note.dart' show noteBulletMark;
import '../../data/models/post_page.dart';
import '../../data/models/space.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/page_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import '../entry/entry_state.dart';
import '../spaces/space_errors.dart';
import 'daybook_attach.dart';
import 'daybook_loop.dart';
import 'daybook_marks.dart' show checklistPointsProvider, postFilesProvider;
import 'daybook_page.dart';
import 'daybook_writing.dart' show assignablePeople;
import 'page_block_editing.dart';
import 'work_outbox.dart';

/// What "/" and + offer (N3), in the frame's order: a work item's seven
/// of review 105 SP4 first (Text · Bullet points · Checklist · Table ·
/// Table of tasks · Photo · File or scan), then a heading, a toggle and a
/// work item under it.
enum PageAdd {
  text,
  bullets,
  checklist,
  table,
  taskTable,
  photo,
  file,
  heading,
  toggle,
  item,
}

/// What a block turns into (N4).
enum PageTurn { text, point, item }

/// A block's menu on its ⋮⋮ (N4): Turn into, Move up and Move down
/// (review 98: no drag on a phone), and Delete.
enum _BlockAction { text, point, item, up, down, delete }

/// How a save went: it stays open ([failed]), there was nothing to send,
/// or it was sent.
enum _Saved { failed, nothing, sent }

/// The blocks a page's author may add here: points only on a work item
/// or a checklist, a work item under this one only on a top-level work
/// item.
List<PageAdd> pageAdds(DaybookPost post) => [
  for (final a in PageAdd.values)
    if (switch (a) {
      PageAdd.checklist =>
        post.isWorkItem || post.kind == DaybookPost.checklistKind,
      // Review 105 Part 4: one owner ticks its rows, then signs once.
      PageAdd.taskTable => post.isWorkItem,
      PageAdd.item => mayHaveItemsUnder(post),
      _ => true,
    })
      a,
];

/// A top-level work item: the server allows one level only.
bool mayHaveItemsUnder(DaybookPost post) =>
    post.isWorkItem && post.parentId == null;

/// The block menu's words (N3). In a work item (review 105 SP4) a file
/// is "File or scan".
String pageAddName(
  AppLocalizations l10n,
  PageAdd a, {
  bool workItem = false,
}) => switch (a) {
  PageAdd.text => l10n.pageText,
  PageAdd.bullets => l10n.pageBulletPoints,
  PageAdd.heading => l10n.pageHeading,
  PageAdd.checklist => l10n.pageChecklist,
  PageAdd.toggle => l10n.pageToggle,
  PageAdd.table => l10n.pageTable,
  PageAdd.taskTable => l10n.pageTaskTable,
  PageAdd.photo => l10n.pagePhoto,
  PageAdd.file => workItem ? l10n.pageFileOrScan : l10n.pageFile,
  PageAdd.item => l10n.pageItemUnder,
};

/// The line under a kind in a work item's + (review 105 SP4): a plain
/// table has no owners; a table of tasks is ticked by the owner.
String? pageAddHint(AppLocalizations l10n, PageAdd a) => switch (a) {
  PageAdd.table => l10n.pageTableHint,
  PageAdd.taskTable => l10n.pageTaskTableHint,
  _ => null,
};

IconData pageAddIcon(PageAdd a) => switch (a) {
  PageAdd.text => BvIcons.textBlock,
  PageAdd.bullets => BvIcons.bulletList,
  PageAdd.heading => BvIcons.headingBlock,
  PageAdd.checklist => BvIcons.workItems,
  PageAdd.toggle => BvIcons.caretForward,
  PageAdd.table || PageAdd.taskTable => BvIcons.tableBlock,
  PageAdd.photo => BvIcons.camera,
  PageAdd.file => BvIcons.document,
  PageAdd.item => BvIcons.useful,
};

/// A bullet point's start: Work's text block with a bullet (review 105
/// Part 4).
const pageBulletStart = '$noteBulletMark ';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// [blocks] with every id the server takes: what the page showed without
/// a block yet (points, photos, files, work items under it) gets its own.
List<PageBlock> withRealIds(List<PageBlock> blocks) => [
  for (final b in blocks)
    if (_uuid.hasMatch(b.id))
      b
    else
      switch (b) {
        PageChecklist(:final pointIds) => PageChecklist(newUuid(), pointIds),
        PagePhoto(:final path, :final caption) => PagePhoto(
          newUuid(),
          path,
          caption: caption,
        ),
        PageFile(:final libraryFileId) => PageFile(newUuid(), libraryFileId),
        PageChildItem(:final postId) => PageChildItem(newUuid(), postId),
        _ => b,
      },
];

/// F90: each toggle ends with an empty line ready to type inside (dropped
/// again when the page is saved).
List<PageBlock> withReadyToggles(List<PageBlock> blocks) => [
  for (final b in blocks)
    if (b case PageToggle(:final text, :final children)
        when children.isEmpty ||
            !(children.last is PageText &&
                (children.last as PageText).text.isEmpty))
      PageToggle(b.id, text, [...children, PageText(newUuid(), '')])
    else
      b,
];

/// What to send for [page] edited into [blocks], [points] (id → words),
/// [title] and [body], in the order it must go (review 76): [before] (the
/// words and new points), the blocks, then [after] (the points no block
/// shows any more, and their order). Empty headings, toggles and checklists go;
/// an empty new point goes, an emptied old one is removed. A ticked point
/// keeps its words and is never removed.
({
  Map<String, Object?> before,
  List<PageBlock> blocks,
  Map<String, Object?> after,
})
planPageSave(
  PostPage page, {
  required List<PageBlock> blocks,
  required Map<String, String> points,
  required String title,
  required String body,
}) {
  final server = {for (final p in page.points) p.id: p};
  final kept = <PageBlock>[];
  final shownIds = <String>[];
  for (final b in blocks) {
    switch (b) {
      case PageHeading(:final text) when text.trim().isEmpty:
        break;
      case PageToggle(:final text, :final children):
        // F90: the empty line ready to type inside goes.
        final inside = [
          for (final c in children)
            if (!(c is PageText && c.text.trim().isEmpty) &&
                !(c is PageHeading && c.text.trim().isEmpty))
              c,
        ];
        if (text.trim().isEmpty) {
          kept.addAll(inside);
        } else {
          kept.add(PageToggle(b.id, text.trim(), inside));
        }
      case PageChecklist(:final pointIds):
        final ids = [
          for (final id in pointIds)
            if (server[id]?.ticked == true ||
                (points[id] ?? '').trim().isNotEmpty)
              id,
        ];
        if (ids.isNotEmpty) {
          kept.add(PageChecklist(b.id, ids));
          shownIds.addAll(ids);
        }
      case PageTaskTable(:final rows):
        // A tick is the owner's or a Lead's (tick_task_row): each row keeps
        // the one the server has, and a ticked row its words. An empty new
        // row goes; a table with no rows left goes.
        final saved = {
          for (final t in page.blocks)
            if (t is PageTaskTable && t.id == b.id)
              for (final r in t.rows) r.id: r,
        };
        final left = [
          for (final r in rows)
            if (saved[r.id] case final s? when s.ticked)
              s
            else if (r.text.trim().isNotEmpty)
              TaskRow(r.id, r.text.trim(), note: r.note.trim()),
        ];
        if (left.isNotEmpty) kept.add(PageTaskTable(b.id, left));
      default:
        kept.add(b);
    }
  }

  final add = [
    for (final id in shownIds)
      if (!server.containsKey(id)) {'id': id, 'text': points[id]!.trim()},
  ];
  final edit = [
    for (final id in shownIds)
      if (server[id] case final p?
          when !p.ticked && points[id]!.trim() != p.text)
        {'id': id, 'text': points[id]!.trim()},
  ];
  final remove = [
    for (final p in page.points)
      if (!p.ticked && !shownIds.contains(p.id)) p.id,
  ];
  // Every point left, in the page's order; ticked ones no block shows
  // keep their place after them.
  final order = [
    ...shownIds,
    for (final p in page.points)
      if (p.ticked && !shownIds.contains(p.id)) p.id,
  ];
  final serverOrder = [
    for (final p in page.points)
      if (!remove.contains(p.id)) p.id,
  ];
  final reordered =
      order.length == serverOrder.length + add.length &&
      !_sameOrder(order.where(server.containsKey).toList(), serverOrder);

  final before = <String, Object?>{
    if (title.trim() != page.post.title) 'title': title.trim(),
    if (body.trim() != (page.post.body ?? '').trim()) 'body': body.trim(),
    if (add.isNotEmpty || edit.isNotEmpty)
      'points': {
        if (add.isNotEmpty) 'add': add,
        if (edit.isNotEmpty) 'edit': edit,
      },
  };
  // A photo or file the page no longer shows leaves the post too, once the
  // page that showed it is saved (edit_space_post keeps a shown one).
  final (:photos, :files) = pageAttachments(kept);
  final removeFiles = [
    for (final f in page.files)
      // Only what a page can show (PostPage.shown): a photo, a Library
      // file. Anything else stays as it is.
      if (f.isPhoto && f.path != null
          ? !photos.contains(f.path)
          : f.libraryFileId != null && !files.contains(f.libraryFileId))
        f.id,
  ];
  final after = <String, Object?>{
    if (remove.isNotEmpty || reordered)
      'points': {
        if (remove.isNotEmpty) 'remove': remove,
        if (reordered || remove.isNotEmpty) 'order': order,
      },
    if (removeFiles.isNotEmpty) 'remove_files': removeFiles,
  };
  return (before: before, blocks: kept, after: after);
}

/// The photos (paths) and Library files (ids) [blocks] show, toggles'
/// included.
({Set<String> photos, Set<String> files}) pageAttachments(
  List<PageBlock> blocks,
) {
  final photos = <String>{};
  final files = <String>{};
  void see(PageBlock b) {
    switch (b) {
      case PagePhoto(:final path):
        photos.add(path);
      case PageFile(:final libraryFileId):
        files.add(libraryFileId);
      case PageToggle(:final children):
        children.forEach(see);
      default:
        break;
    }
  }

  blocks.forEach(see);
  return (photos: photos, files: files);
}

bool _sameOrder(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// N2–N4 · The page as its author edits it: the title and words in place,
/// ⋮⋮ on every block (hold to drag, tap for Turn into and Delete), "/"
/// or + for a new block, tables, and Done to save (by version).
class DaybookPageEditor extends ConsumerStatefulWidget {
  const DaybookPageEditor({super.key, required this.space, required this.page});

  final SpaceDetail space;
  final PostPage page;

  @override
  ConsumerState<DaybookPageEditor> createState() => DaybookPageEditorState();
}

class DaybookPageEditorState extends ConsumerState<DaybookPageEditor>
    with PageBlockEditing<DaybookPageEditor> {
  /// post_files: 10 on a post.
  static const _filesMax = 10;

  late PostPage _page = widget.page;
  late final Map<String, String> _points = {
    for (final p in _page.points) p.id: p.text,
  };
  late final _title = TextEditingController(text: _page.post.title);
  late final _body = TextEditingController(text: _page.post.body ?? '');
  final _add = TextEditingController();
  final _addFocus = FocusNode();

  /// A point's Backspace listener, one per point.
  final _pointKeys = <String, FocusNode>{};

  /// Photos and files added here, sent with the save (post_files).
  final _addFiles = <Map<String, Object?>>[];
  var _saving = false;

  /// The work item each point is turning into, by point (review 79 C1):
  /// kept from the first try until the server has it.
  final _turning = <String, String>{};

  DaybookPost get _post => _page.post;
  String get _spaceId => widget.space.id;

  @override
  int get blockTextMax => PageText.max;

  @override
  void initState() {
    super.initState();
    editBlocks = withReadyToggles(withRealIds(_page.shown));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _add.dispose();
    _addFocus.dispose();
    for (final f in _pointKeys.values) {
      f.dispose();
    }
    disposeBlockEditing();
    super.dispose();
  }

  /// The words in the fields, back on the blocks and the points.
  List<PageBlock> _collect() {
    for (final e in fieldsStartingWith('pt:')) {
      _points[e.key.substring(3)] = e.value.text;
    }
    return collectBlocks();
  }

  int get _filesLeft => _filesMax - _page.files.length - _addFiles.length;

  /// Done (N2): saves; false when it stays open (no signal, or a newer
  /// page to choose from).
  Future<bool> save() async => await _save() != _Saved.failed;

  /// Something written here isn't on the server yet: leaving asks first
  /// (slice 10).
  bool get dirty {
    final plan = planPageSave(
      _page,
      blocks: _collect(),
      points: _points,
      title: _title.text,
      body: _body.text,
    );
    return plan.before.isNotEmpty ||
        plan.after.isNotEmpty ||
        _addFiles.isNotEmpty ||
        editBlocksChanged(plan.blocks);
  }

  Future<_Saved> _save() async {
    if (_saving) return _Saved.failed;
    final plan = planPageSave(
      _page,
      blocks: _collect(),
      points: _points,
      title: _title.text,
      body: _body.text,
    );
    // A photo or file added here and deleted again doesn't go.
    final (:photos, :files) = pageAttachments(plan.blocks);
    _addFiles.removeWhere(
      (a) => a['path'] != null
          ? !photos.contains(a['path'])
          : !files.contains(a['library_file_id']),
    );
    final repo = ref.read(pageRepositoryProvider);
    final unchanged =
        plan.before.isEmpty &&
        plan.after.isEmpty &&
        _addFiles.isEmpty &&
        !editBlocksChanged(plan.blocks);
    if (unchanged) return _Saved.nothing;
    setState(() => _saving = true);
    try {
      if (plan.before.isNotEmpty) await repo.edit(_post.id, plan.before);
      if (editBlocksChanged(plan.blocks) || _addFiles.isNotEmpty) {
        await repo.save(
          _post.id,
          plan.blocks,
          baseVersion: _page.version,
          addFiles: _addFiles,
        );
      }
      if (plan.after.isNotEmpty) await repo.edit(_post.id, plan.after);
    } on PageStaleException {
      if (!mounted) return _Saved.failed;
      setState(() => _saving = false);
      return await _newer() ? _Saved.sent : _Saved.failed;
    } on SpaceException catch (e) {
      final network = e.failure == SpaceFailure.network;
      if (network) ref.read(signalProvider.notifier).lost();
      if (mounted) {
        setState(() => _saving = false);
        // No signal (slice 10): the editor stays open with every change;
        // a later send could clash with the page's version, so it isn't
        // queued.
        network
            ? showSpaceMessage(
                context,
                AppLocalizations.of(context).pageNoSignal,
              )
            : showSpaceError(context, e);
      }
      // Some steps may have gone: start the next Done from what the
      // server has, so nothing is sent twice.
      await _catchUp();
      return _Saved.failed;
    }
    ref.read(signalProvider.notifier).back();
    _addFiles.clear();
    _changed();
    if (mounted) setState(() => _saving = false);
    return _Saved.sent;
  }

  /// Whether [blocks] differ from the page as it opened. A post with no
  /// page yet opens on its points, photos and files: the same again saves
  /// nothing (no "Page edited", no "Open the page").
  bool editBlocksChanged(List<PageBlock> blocks) =>
      !_sameBlocks(blocks, _page.blocks) &&
      !(_page.blocks.isEmpty && _sameShape(blocks, _page.shown));

  /// The same blocks but for their own ids (the editor gives the page's
  /// loose points and files real ids).
  static bool _sameShape(List<PageBlock> a, List<PageBlock> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = {...a[i].toJson()}..remove('id');
      final y = {...b[i].toJson()}..remove('id');
      if ('$x' != '$y') return false;
    }
    return true;
  }

  static bool _sameBlocks(List<PageBlock> a, List<PageBlock> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ('${a[i].toJson()}' != '${b[i].toJson()}') return false;
    }
    return true;
  }

  /// The page and the daybook read again; others hear of the change.
  void _changed() {
    // The card under the sheet keeps its points and files: read them
    // again too (the database's broadcast reads only the daybook).
    ref
      ..invalidate(postPageProvider(_post.id))
      ..invalidate(checklistPointsProvider(_post.id))
      ..invalidate(postFilesProvider(_post.id))
      ..invalidate(taskTablesProvider(_spaceId));
    unawaited(DaybookLoop(ref, widget.space, onEdit: (_) {}).refresh());
  }

  /// The page as the server has it now, under this phone's edit: what
  /// already went (points, files, a version) isn't sent again.
  Future<void> _catchUp() async {
    final PostPage? fresh;
    try {
      fresh = await ref.read(pageRepositoryProvider).page(_post.id);
    } on SpaceException {
      return;
    }
    if (!mounted || fresh == null) return;
    final paths = {for (final f in fresh.files) ?f.path};
    final library = {for (final f in fresh.files) ?f.libraryFileId};
    setState(() {
      _page = _rebase(fresh!);
      _addFiles.removeWhere(
        (a) =>
            paths.contains(a['path']) || library.contains(a['library_file_id']),
      );
    });
  }

  /// The author's other phone saved first: keep this one's, or take the
  /// newer page. Dismissed, the editor stays as it is.
  Future<bool> _newer() async {
    final l10n = AppLocalizations.of(context);
    final mine = await showBvChoiceDialog(
      context: context,
      title: l10n.pageStale,
      body: '',
      cancelLabel: l10n.pageUseNewer,
      confirmLabel: l10n.pageUseMine,
    );
    if (!mounted || mine == null) return false;
    if (mine) {
      await _catchUp();
      if (!mounted) return false;
      return save();
    }
    ref.invalidate(postPageProvider(_post.id));
    return true;
  }

  /// This phone's edit over [fresh]'s version and points.
  PostPage _rebase(PostPage fresh) => PostPage(
    post: fresh.post,
    blocks: fresh.blocks,
    version: fresh.version,
    points: fresh.points,
    files: fresh.files,
    under: fresh.under,
  );

  // Adding ------------------------------------------------------------------

  /// What a toggle may hold (validateeditBlocks), for "/" inside one (F90).
  static const _insideToggle = {
    PageAdd.text,
    PageAdd.heading,
    PageAdd.table,
    PageAdd.photo,
    PageAdd.file,
  };

  Future<void> _openAdd({
    String filter = '',
    int? replace,
    (int, String)? intoToggle,
  }) async {
    final l10n = AppLocalizations.of(context);
    final f = filter.toLowerCase();
    final adds = [
      for (final a in pageAdds(_post))
        if ((f.isEmpty ||
                pageAddName(
                  l10n,
                  a,
                  workItem: _post.isWorkItem,
                ).toLowerCase().startsWith(f)) &&
            (intoToggle == null || _insideToggle.contains(a)))
          a,
    ];
    if (adds.isEmpty) return;
    final item = _post.isWorkItem;
    final picked = await showPageBlockMenu<PageAdd>(
      context,
      // Review 105 SP4: "Add to this work item", each kind's line under
      // Table and Table of tasks.
      title: item ? l10n.pageAddToItem : l10n.pageMenuTitle,
      items: [
        for (final a in adds)
          (
            value: a,
            label: pageAddName(l10n, a, workItem: item),
            icon: pageAddIcon(a),
          ),
      ],
      keyOf: (a) => a.name,
      hintOf: item ? (a) => pageAddHint(l10n, a) : null,
    );
    _add.clear();
    if (picked == null || !mounted) return;
    await _addBlock(picked, at: replace, intoToggle: intoToggle);
  }

  /// [keep]: the line at [at] (or the toggle's line) keeps its words and
  /// the new block goes after it.
  Future<void> _addBlock(
    PageAdd a, {
    int? at,
    (int, String)? intoToggle,
    bool keep = false,
  }) async {
    editBlocks = _collect();
    final id = newUuid();
    PageBlock? block;
    String? focus;
    switch (a) {
      case PageAdd.text:
        block = PageText(id, '');
        focus = 't:$id';
      case PageAdd.bullets:
        block = PageText(id, pageBulletStart);
        focus = 't:$id';
      case PageAdd.heading:
        block = PageHeading(id, '');
        focus = 't:$id';
      case PageAdd.toggle:
        block = PageToggle(id, '', [PageText(newUuid(), '')]);
        focus = 't:$id';
      case PageAdd.checklist:
        final point = newUuid();
        _points[point] = '';
        block = PageChecklist(id, [point]);
        focus = 'pt:$point';
      case PageAdd.table:
        block = PageTable(id, const [
          ['', ''],
          ['', ''],
        ]);
        focus = 'c:$id:0:0';
      case PageAdd.taskTable:
        final row = newUuid();
        block = PageTaskTable(id, [TaskRow(row, '')]);
        focus = taskFieldKey(id, row, note: false);
      case PageAdd.photo:
        block = await _photo(id);
      case PageAdd.file:
        block = await _file(id);
      case PageAdd.item:
        block = await _item(id);
    }
    if (block == null || !mounted) return;
    if (intoToggle != null) {
      // F90: in the empty line's place, inside the toggle; its ready line
      // follows it.
      final (index, childId) = intoToggle;
      editBlocks = _collect();
      final t = editBlocks[index] as PageToggle;
      setState(
        () => editBlocks = withReadyToggles([
          ...editBlocks.take(index),
          PageToggle(t.id, t.text, [
            for (final c in t.children)
              if (c.id != childId) c else ...[if (keep) c, block!],
          ]),
          ...editBlocks.skip(index + 1),
        ]),
      );
      if (focus != null) focusBlockLater(focus);
      return;
    }
    setState(() {
      if (at != null && at < editBlocks.length) {
        if (keep) {
          editBlocks.insert(at + 1, block!);
        } else {
          editBlocks[at] = block!;
        }
      } else {
        editBlocks.add(block!);
      }
    });
    if (focus != null) focusBlockLater(focus);
  }

  bool _roomForFile() {
    if (_filesLeft > 0) return true;
    showSpaceMessage(context, AppLocalizations.of(context).pageFull);
    return false;
  }

  /// A photo from the camera, made safe to leave the phone, uploaded to the
  /// post's folder; it goes on the post with the save.
  Future<PageBlock?> _photo(String id) async {
    if (!_roomForFile()) return null;
    final l10n = AppLocalizations.of(context);
    final picked = await ref.read(pickPhotoProvider)(camera: true);
    if (!mounted) return null;
    if (picked.refused > 0) showSpaceMessage(context, l10n.photoCannotOpen);
    final photo = picked.photos.firstOrNull;
    if (photo == null) return null;
    try {
      final path = await ref
          .read(daybookRepositoryProvider)
          .uploadPostPhoto(_spaceId, _post.id, File(photo.path));
      _addFiles.add({'path': path, 'mime': 'image/jpeg'});
      return PagePhoto(id, path);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return null;
    }
  }

  /// A Library file, or one from the phone into the Library first.
  Future<PageBlock?> _file(String id) async {
    if (!_roomForFile()) return null;
    final file = await chooseDaybookFile(context, ref, spaceId: _spaceId);
    if (file == null || !mounted) return null;
    if (file.isNew) {
      final library = ref.read(libraryRepositoryProvider);
      try {
        final path = await library.upload(
          _spaceId,
          file.libraryId,
          PhoneFile(
            local: file.local!,
            name: file.name,
            mime: file.mime,
            bytes: file.bytes,
          ),
        );
        await library.add(
          id: file.libraryId,
          spaceId: _spaceId,
          name: file.name,
          path: path,
          mime: file.mime,
          bytes: file.bytes,
          revLabel: file.revLabel,
          supersedesId: file.supersedesId,
        );
      } on SpaceException catch (e) {
        if (mounted) showSpaceError(context, e);
        return null;
      }
    }
    _addFiles.add({'library_file_id': file.libraryId});
    return PageFile(id, file.libraryId);
  }

  /// A work item under this one: its words and who owns it; made at once
  /// (its owner is told), so the block shows it.
  Future<PageBlock?> _item(String id, {String text = ''}) async {
    final picked = await _askItem(text);
    if (picked == null || !mounted) return null;
    final itemId = newUuid();
    try {
      await ref
          .read(pageRepositoryProvider)
          .addItemUnder(
            spaceId: _spaceId,
            parentId: _post.id,
            id: itemId,
            title: picked.title,
            ownerId: picked.owner.id,
          );
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return null;
    }
    _under(itemId, picked.title, picked.owner);
    return PageChildItem(id, itemId);
  }

  /// The new work item shows under this one before the page reads again.
  void _under(String id, String title, BvGiveToPerson owner) {
    _page = PostPage(
      post: _page.post,
      blocks: _page.blocks,
      version: _page.version,
      points: _page.points,
      files: _page.files,
      under: [
        ..._page.under,
        PageUnder(
          id: id,
          title: title,
          ownerId: owner.id,
          ownerName: owner.name,
        ),
      ],
    );
  }

  /// The new work item's words (2 to 140) and its owner (the give-to
  /// picker: someone who can sign it as done).
  Future<({String title, BvGiveToPerson owner})?> _askItem(String text) async {
    final l10n = AppLocalizations.of(context);
    final me = ref.read(authUserIdProvider).value;
    final people = await ref.read(spacePeopleProvider(_spaceId).future);
    if (!mounted) return null;
    return showBvSheet<({String title, BvGiveToPerson owner})>(
      context: context,
      title: l10n.pageItemUnder,
      builder: (sheet) => _ItemSheet(
        key: const Key('page-item-sheet'),
        text: text,
        people: assignablePeople(people, me: me),
        me: me,
        onPick: (title, owner) =>
            Navigator.of(sheet).pop((title: title, owner: owner)),
      ),
    );
  }

  /// The block a field's key is in: its index, and the toggle's own line
  /// when it is one.
  (int, String?)? _whereKey(String key) {
    final id = PageBlockEditing.blockIdOfKey(key);
    for (final (i, b) in editBlocks.indexed) {
      if (b.id == id) return (i, null);
      if (b case PageToggle(
        :final children,
      ) when children.any((c) => c.id == id)) {
        return (i, id);
      }
    }
    return null;
  }

  /// "/" (review 98): the same kinds as +, by their names in English and
  /// Arabic.
  @override
  List<PageSlashItem> slashItems(String key) {
    final l10n = AppLocalizations.of(context);
    final where = _whereKey(key);
    if (where == null) return const [];
    return [
      for (final a in pageAdds(_post))
        if (where.$2 == null || _insideToggle.contains(a))
          (
            value: a,
            key: a.name,
            label: pageAddName(l10n, a, workItem: _post.isWorkItem),
            icon: pageAddIcon(a),
            shortcut: null,
            words: [
              for (final w in slashLanguages)
                pageAddName(w, a, workItem: _post.isWorkItem),
            ],
          ),
    ];
  }

  /// A kind picked from "/": an empty line becomes it; a line with words
  /// keeps them, and the kind goes after it.
  @override
  void slashPicked(String key, Object value) {
    editBlocks = _collect();
    final where = _whereKey(key);
    if (where == null || value is! PageAdd) return;
    final (index, child) = where;
    final empty = (existingField(key)?.text ?? '').trim().isEmpty;
    unawaited(
      child != null
          ? _addBlock(value, intoToggle: (index, child), keep: !empty)
          : _addBlock(value, at: index, keep: !empty),
    );
  }

  // A block's menu ------------------------------------------------------------

  @override
  Future<void> blockMenu(int index) async {
    final l10n = AppLocalizations.of(context);
    editBlocks = _collect();
    final b = editBlocks[index];
    // Only what the server takes: a point's or a title's length.
    final words = b is PageText ? b.text.trim().length : 0;
    final turns = <_BlockAction>[
      if (b is PageText &&
          words <= PageChecklist.pointMax &&
          pageAdds(_post).contains(PageAdd.checklist))
        _BlockAction.point,
      if (b is PageText &&
          words <= PageChecklist.itemTitleMax &&
          mayHaveItemsUnder(_post))
        _BlockAction.item,
    ];
    // A work item under this one has its own life: it is cancelled from
    // its card, never deleted from the page (it would come back).
    final deletable = b is! PageChildItem;
    final phone = !dragsLines;
    final up = phone && index > 0;
    final down = phone && index < editBlocks.length - 1;
    if (turns.isEmpty && !deletable && !up && !down) return;
    final picked = await showBvSheet<_BlockAction>(
      context: context,
      title: turns.isEmpty ? null : l10n.pageTurnInto,
      builder: (sheet) => Column(
        key: const Key('page-block-menu'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in turns)
            BvListRow(
              key: Key('page-turn-${t.name}'),
              title: switch (t) {
                _BlockAction.text => l10n.pageText,
                _BlockAction.point => l10n.pagePoint,
                _ => l10n.pageItemUnder,
              },
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(t),
            ),
          if (up)
            BvListRow(
              key: const Key('page-move-up'),
              leading: const BvRowIcon(BvIcons.moveUp),
              title: l10n.notebookMoveUp,
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(_BlockAction.up),
            ),
          if (down)
            BvListRow(
              key: const Key('page-move-down'),
              leading: const BvRowIcon(BvIcons.moveDown),
              title: l10n.notebookMoveDown,
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(_BlockAction.down),
            ),
          if (deletable)
            BvListRow(
              key: const Key('page-block-delete'),
              leading: const BvRowIcon(BvIcons.delete, destructive: true),
              title: l10n.pageMenuDelete,
              destructive: true,
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(_BlockAction.delete),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case _BlockAction.delete:
        _delete(index);
      case _BlockAction.up || _BlockAction.down:
        final to = picked == _BlockAction.up ? index - 1 : index + 1;
        editBlocks = _collect();
        setState(() => editBlocks.insert(to, editBlocks.removeAt(index)));
      case _BlockAction.point when b is PageText:
        final point = newUuid();
        _points[point] = b.text.trim();
        setState(() => editBlocks[index] = PageChecklist(newUuid(), [point]));
      case _BlockAction.item when b is PageText:
        final block = await _item(newUuid(), text: b.text.trim());
        if (block != null && mounted) setState(() => editBlocks[index] = block);
      default:
        break;
    }
  }

  void _delete(int index) {
    final l10n = AppLocalizations.of(context);
    final gone = editBlocks[index];
    // A ticked point is a record: its block stays.
    if (gone is PageChecklist &&
        gone.pointIds.any(
          (id) => _page.points.any((p) => p.id == id && p.ticked),
        )) {
      showSpaceMessage(context, l10n.pageTickedStays);
      return;
    }
    deleteBlock(index);
  }

  /// One point out of its checklist (F92), with Undo; an empty checklist
  /// goes. A saved point leaves the post when the page is saved.
  void _deletePoint(int index, String pointId) {
    final l10n = AppLocalizations.of(context);
    editBlocks = _collect();
    final before = [...editBlocks];
    final text = _points[pointId];
    final list = editBlocks[index] as PageChecklist;
    final ids = [
      for (final x in list.pointIds)
        if (x != pointId) x,
    ];
    setState(() {
      _points.remove(pointId);
      dropField('pt:$pointId');
      if (ids.isEmpty) {
        editBlocks.removeAt(index);
      } else {
        editBlocks[index] = PageChecklist(list.id, ids);
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.pageDeleted),
          action: SnackBarAction(
            key: const Key('page-undo'),
            label: l10n.spacesUndo,
            onPressed: () {
              if (!mounted) return;
              setState(() {
                editBlocks = before;
                if (text != null) _points[pointId] = text;
              });
            },
          ),
        ),
      );
  }

  /// A point's menu (N4): Text, Work item under this one; a ticked point
  /// stays as it is.
  Future<void> _pointMenu(int index, String pointId) async {
    final l10n = AppLocalizations.of(context);
    final ticked = _page.points.any((p) => p.id == pointId && p.ticked);
    if (ticked) {
      showSpaceMessage(context, l10n.pageTickedStays);
      return;
    }
    final picked = await showBvSheet<Object>(
      context: context,
      title: l10n.pageTurnInto,
      builder: (sheet) => Column(
        key: const Key('page-point-menu'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BvListRow(
            key: const Key('page-turn-text'),
            title: l10n.pageText,
            trailing: const BvRowTrailing.none(),
            onTap: () => Navigator.of(sheet).pop(PageTurn.text),
          ),
          BvListRow(
            key: const Key('page-turn-point'),
            title: l10n.pagePoint,
            trailing: const BvRowTrailing.check(selected: true),
            onTap: () => Navigator.of(sheet).pop(PageTurn.point),
          ),
          if (mayHaveItemsUnder(_post))
            BvListRow(
              key: const Key('page-turn-item'),
              title: l10n.pageItemUnder,
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(PageTurn.item),
            ),
          // F92: one point goes, the rest of its checklist stays.
          BvListRow(
            key: const Key('page-point-delete'),
            leading: const BvRowIcon(BvIcons.delete, destructive: true),
            title: l10n.pageMenuDelete,
            destructive: true,
            trailing: const BvRowTrailing.none(),
            onTap: () => Navigator.of(sheet).pop(_BlockAction.delete),
          ),
        ],
      ),
    );
    if (picked == _BlockAction.delete && mounted) {
      _deletePoint(index, pointId);
      return;
    }
    if (picked == null || picked == PageTurn.point || !mounted) return;
    editBlocks = _collect();
    final text = (_points[pointId] ?? '').trim();
    if (picked == PageTurn.text) {
      setState(() => _splitPoint(index, pointId, PageText(newUuid(), text)));
      return;
    }
    if (text.length > PageChecklist.itemTitleMax) {
      showSpaceMessage(context, l10n.pageTooLongForItem);
      return;
    }
    final onServer = _page.points.any((p) => p.id == pointId);
    if (!onServer) {
      final block = await _item(newUuid(), text: text);
      if (block != null && mounted) {
        setState(() => _splitPoint(index, pointId, block));
      }
      return;
    }
    // On the server: the point turns in one step (turn_point_into_item),
    // with the sheet's words as the title (review 79 C1).
    final asked = await _askItem(text);
    if (asked == null || !mounted) return;
    // The point keeps the server's words: the sheet's go with the turn,
    // so the point is never edited on the way.
    final words = _page.points.firstWhere((p) => p.id == pointId).text;
    _points[pointId] = words;
    existingField('pt:$pointId')?.text = words;
    // Anything else written so far is saved first; with nothing else, the
    // turn is the one call.
    switch (await _save()) {
      case _Saved.failed:
        return;
      case _Saved.nothing:
        break;
      case _Saved.sent:
        final PostPage? fresh;
        try {
          fresh = await ref.read(pageRepositoryProvider).page(_post.id);
        } on SpaceException catch (e) {
          if (mounted) showSpaceError(context, e);
          return;
        }
        if (fresh == null || !mounted) return;
        // Saved: the next Done starts from here.
        setState(() => _page = fresh!);
    }
    // The same item on a retry after a lost answer, never a second one.
    final itemId = _turning.putIfAbsent(pointId, newUuid);
    try {
      await ref
          .read(pageRepositoryProvider)
          .turnPointIntoItem(
            postId: _post.id,
            pointId: pointId,
            itemId: itemId,
            ownerId: asked.owner.id,
            title: asked.title,
            baseVersion: _page.version,
          );
    } on PageStaleException {
      if (mounted) showSpaceMessage(context, l10n.pageStale);
      return;
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    final PostPage? turned;
    try {
      turned = await ref.read(pageRepositoryProvider).page(_post.id);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    if (turned == null || !mounted) return;
    _turning.remove(pointId);
    _changed();
    setState(() => _reload(turned!));
  }

  /// The editor over [page], as the server has it now.
  void _reload(PostPage page) {
    _page = page;
    editBlocks = withReadyToggles(withRealIds(page.shown));
    _points
      ..clear()
      ..addAll({for (final p in page.points) p.id: p.text});
    resetBlockFields();
  }

  /// [pointId] leaves its checklist at [index]; [into] takes its place,
  /// splitting the checklist around it.
  void _splitPoint(int index, String pointId, PageBlock into) {
    final list = editBlocks[index] as PageChecklist;
    final at = list.pointIds.indexOf(pointId);
    final head = list.pointIds.sublist(0, at);
    final tail = list.pointIds.sublist(at + 1);
    _points.remove(pointId);
    dropField('pt:$pointId');
    editBlocks
      ..removeAt(index)
      ..insertAll(index, [
        if (head.isNotEmpty) PageChecklist(list.id, head),
        into,
        if (tail.isNotEmpty) PageChecklist(newUuid(), tail),
      ]);
  }

  // Points --------------------------------------------------------------------

  /// Enter at the end of a point adds the next one.
  void _nextPoint(int index, String after) {
    editBlocks = _collect();
    final list = editBlocks[index] as PageChecklist;
    final point = newUuid();
    _points[point] = '';
    final ids = [...list.pointIds]
      ..insert(list.pointIds.indexOf(after) + 1, point);
    setState(() => editBlocks[index] = PageChecklist(list.id, ids));
    focusBlockLater('pt:$point');
  }

  /// Backspace on an empty new point takes it away.
  void _dropPoint(int index, String id) {
    if (_page.points.any((p) => p.id == id)) return;
    editBlocks = _collect();
    final list = editBlocks[index] as PageChecklist;
    final ids = [
      for (final x in list.pointIds)
        if (x != id) x,
    ];
    final before = list.pointIds.indexOf(id) - 1;
    setState(() {
      _points.remove(id);
      if (ids.isEmpty) {
        editBlocks.removeAt(index);
      } else {
        editBlocks[index] = PageChecklist(list.id, ids);
      }
    });
    if (before >= 0) focusBlockLater('pt:${list.pointIds[before]}');
  }

  // Building ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: BvSpace.s4,
              end: BvPageSpec.padding,
            ),
            child: ReorderableListView.builder(
              key: const Key('page-editor'),
              buildDefaultDragHandles: false,
              // Directional insets around the list: the list itself takes
              // only EdgeInsets.
              padding: const EdgeInsets.symmetric(
                vertical: BvPageSpec.titleTop,
              ),
              header: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: BvPageSpec.handleWidth + BvSpace.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BvPageSpec.factsTop,
                  children: [
                    TextField(
                      key: const Key('page-title'),
                      controller: _title,
                      maxLength: _post.isWorkItem
                          ? PageChecklist.itemTitleMax
                          : 200,
                      maxLines: null,
                      style: type.titleLg,
                      decoration: bvBareField(
                        hint: l10n.daybookWritingTitle,
                        style: type.titleLg,
                      ).copyWith(counterText: ''),
                    ),
                    TextField(
                      key: const Key('page-body'),
                      controller: _body,
                      maxLines: null,
                      maxLength: 5000,
                      style: type.bodyMd,
                      decoration: bvBareField(
                        hint: l10n.daybookBodyNote,
                        style: type.bodyMd,
                      ).copyWith(counterText: ''),
                    ),
                  ],
                ),
              ),
              footer: _addLine(l10n, type),
              itemCount: editBlocks.length,
              onReorderItem: (from, to) {
                _collect();
                moveBlock(from, to);
              },
              itemBuilder: (context, i) => blockRow(i),
            ),
          ),
        ),
        if (_saving) const LinearProgressIndicator(minHeight: BvStroke.thick),
      ],
    );
  }

  /// "+ Type / to add a block" (N2): + or "/" opens the block menu.
  Widget _addLine(AppLocalizations l10n, BvTypeSet type) => Padding(
    key: const Key('page-add'),
    padding: const EdgeInsetsDirectional.only(top: BvPageSpec.blockGap),
    child: Row(
      spacing: BvSpace.s8,
      children: [
        IconButton(
          key: const Key('page-add-button'),
          tooltip: l10n.pageMenuTitle,
          icon: const Icon(BvIcons.create, size: BvSize.iconMd),
          onPressed: () => unawaited(_openAdd()),
        ),
        Expanded(
          child: TextField(
            key: const Key('page-add-field'),
            controller: _add,
            focusNode: _addFocus,
            style: type.bodyMd,
            decoration: bvBareField(
              hint: l10n.pageAddBlock,
              style: type.bodyMd,
            ),
            onChanged: (v) {
              if (v.startsWith('/')) {
                unawaited(_openAdd(filter: v.substring(1)));
              } else if (v.isNotEmpty) {
                // Words typed here are a new text block.
                final id = newUuid();
                editBlocks = _collect();
                blockField('t:$id', v);
                _add.clear();
                setState(() => editBlocks.add(PageText(id, v)));
                focusBlockLater('t:$id');
              }
            },
          ),
        ),
      ],
    ),
  );

  @override
  Widget hostBlock(int i, PageBlock b) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    switch (b) {
      case PageChecklist(:final pointIds):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final id in pointIds) _pointRow(i, id)],
        );
      case PagePhoto(:final caption):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvSpace.s4,
          children: [
            PageBlockView(
              space: widget.space,
              page: _page,
              block: PagePhoto(b.id, b.path),
              me: null,
            ),
            blockText(
              'p:${b.id}',
              caption ?? '',
              style: type.metadata,
              hint: l10n.pagePhotoCaption,
              maxLength: PagePhoto.captionMax,
            ),
          ],
        );
      case PageChildItem(:final postId):
        final u = _page.under.where((u) => u.id == postId).firstOrNull;
        return u == null ? const SizedBox.shrink() : PageUnderRow(item: u);
      default:
        // A file, a block this page doesn't edit, or a toggle's own block.
        return PageBlockView(
          space: widget.space,
          page: _page,
          block: b,
          me: null,
        );
    }
  }

  Widget _pointRow(int index, String id) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final ticked = _page.points.any((p) => p.id == id && p.ticked);
    final c = blockField('pt:$id', _points[id] ?? '');
    final node = blockNode('pt:$id');
    return Row(
      key: Key('page-point-$id'),
      spacing: BvSpace.s8,
      children: [
        // F92 (N4): each point's own ⋮⋮: Turn into, and Delete.
        GestureDetector(
          key: Key('page-point-handle-$id'),
          onTap: () => unawaited(_pointMenu(index, id)),
          child: Semantics(
            button: true,
            label: l10n.pageBlockMenu,
            child: const Icon(
              BvIcons.dragHandle,
              size: BvPageSpec.handleIcon,
              color: BvColors.iconSecondary,
            ),
          ),
        ),
        GestureDetector(
          key: Key('page-point-menu-$id'),
          onTap: () => unawaited(_pointMenu(index, id)),
          child: Icon(
            ticked ? BvIcons.checkCircle : BvIcons.checkbox,
            size: BvSize.iconMd,
            color: ticked ? BvColors.textPositive : BvColors.iconSecondary,
          ),
        ),
        Expanded(
          child: KeyboardListener(
            focusNode: _pointKeys.putIfAbsent(
              id,
              () => FocusNode(skipTraversal: true),
            ),
            onKeyEvent: (e) {
              if (e is KeyDownEvent &&
                  e.logicalKey == LogicalKeyboardKey.backspace &&
                  c.text.isEmpty) {
                _dropPoint(index, id);
              }
            },
            child: TextField(
              key: Key('page-field-pt:$id'),
              controller: c,
              focusNode: node,
              readOnly: ticked,
              maxLength: PageChecklist.pointMax,
              style: type.bodyMd.copyWith(
                color: ticked ? BvColors.textSecondary : null,
                decoration: ticked ? TextDecoration.lineThrough : null,
              ),
              decoration: bvBareField(
                hint: l10n.pagePoint,
                style: type.bodyMd,
              ).copyWith(counterText: ''),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _nextPoint(index, id),
            ),
          ),
        ),
      ],
    );
  }
}

/// The sheet for a work item under this one: its words and who does it.
/// It owns its words' controller, so the words outlive the sheet's
/// closing slide.
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    super.key,
    required this.text,
    required this.people,
    required this.me,
    required this.onPick,
  });

  final String text;
  final List<BvGiveToPerson> people;
  final String? me;
  final void Function(String title, BvGiveToPerson owner) onPick;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _words = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSpace.gutter,
          ),
          child: TextField(
            key: const Key('page-item-title'),
            controller: _words,
            autofocus: widget.text.isEmpty,
            maxLength: PageChecklist.itemTitleMax,
            decoration: InputDecoration(hintText: l10n.pageItemTitle),
          ),
        ),
        BvGiveToPicker(
          key: const Key('page-item-owner'),
          people: widget.people,
          currentOwnerId: null,
          // You first, as in the writing card (F69).
          meId: widget.me,
          meLabel: l10n.daybookYou,
          currentLabel: l10n.daybookOwnerNow,
          searchPlaceholder: l10n.daybookAssignSearch,
          inSheet: true,
          onPick: (p) {
            final t = _words.text.trim();
            if (t.length >= 2) widget.onPick(t, p);
          },
        ),
      ],
    );
  }
}
