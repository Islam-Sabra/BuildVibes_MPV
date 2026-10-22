import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/page_repository.dart';

/// Pages with no network, by post id. Saves keep the server's rules that
/// matter to the app: the version, points shown on the page can't be
/// removed, a ticked point stays.
class FakePageRepository implements PageRepository {
  final pages = <String, PostPage>{};
  final calls = <String>[];

  /// The next call fails for want of signal.
  bool offline = false;

  /// Someone else saves before the next save (its version moves on).
  bool staleOnce = false;

  /// The signal goes after the first step of a Done: the next blocks save
  /// fails, what went before it stays.
  bool failSaveOnce = false;

  void _check() {
    if (offline) throw const SpaceException(SpaceFailure.network);
  }

  @override
  Future<PostPage?> page(String postId) async {
    _check();
    return pages[postId];
  }

  @override
  Future<int> save(
    String postId,
    List<PageBlock> blocks, {
    required int baseVersion,
    List<Map<String, Object?>> addFiles = const [],
  }) async {
    _check();
    if (failSaveOnce) {
      failSaveOnce = false;
      throw const SpaceException(SpaceFailure.network);
    }
    final p = pages[postId]!;
    if (staleOnce) {
      staleOnce = false;
      pages[postId] = p.copyWith(version: p.version + 1);
      throw const PageStaleException();
    }
    if (baseVersion != p.version) throw const PageStaleException();
    calls.add(
      'save $postId v$baseVersion '
      '[${blocks.map((b) => b.type).join(', ')}]'
      '${addFiles.isEmpty ? '' : ' +${addFiles.length} files'}',
    );
    pages[postId] = PostPage(
      post: p.post,
      blocks: blocks,
      version: p.version + 1,
      points: p.points,
      files: [
        ...p.files,
        for (final (i, f) in addFiles.indexed)
          PageFileRow(
            id: 'added-${p.files.length + i}',
            mime: f['mime'] as String? ?? 'image/jpeg',
            path: f['path'] as String?,
            libraryFileId: f['library_file_id'] as String?,
          ),
      ],
      under: p.under,
    );
    return p.version + 1;
  }

  @override
  Future<void> edit(String postId, Map<String, Object?> changes) async {
    _check();
    final p = pages[postId]!;
    calls.add('edit $postId ${changes.keys.join(', ')}');
    var points = [...p.points];
    final pointChanges = changes['points'] as Map<String, Object?>?;
    if (pointChanges != null) {
      final shown = {
        for (final b in p.blocks)
          if (b is PageChecklist) ...b.pointIds,
      };
      for (final id in pointChanges['remove'] as List? ?? const []) {
        final point = points.firstWhere((x) => x.id == id);
        if (point.ticked) throw const SpaceException(SpaceFailure.rule);
        if (shown.contains(id)) throw const SpaceException(SpaceFailure.rule);
        points.removeWhere((x) => x.id == id);
      }
      for (final e in pointChanges['edit'] as List? ?? const []) {
        final m = e as Map<String, Object?>;
        points = [
          for (final x in points)
            x.id == m['id']
                ? DaybookPoint(
                    id: x.id,
                    text: m['text'] as String,
                    tickedAt: x.tickedAt,
                  )
                : x,
        ];
      }
      for (final a in pointChanges['add'] as List? ?? const []) {
        final m = a as Map<String, Object?>;
        points.add(
          DaybookPoint(id: m['id'] as String, text: m['text'] as String),
        );
      }
      final order = pointChanges['order'] as List?;
      if (order != null) {
        points = [for (final id in order) points.firstWhere((x) => x.id == id)];
      }
    }
    pages[postId] = PostPage(
      post: p.post,
      blocks: p.blocks,
      version: p.version,
      points: points,
      files: p.files,
      under: p.under,
    );
  }

  @override
  Future<void> addItemUnder({
    required String spaceId,
    required String parentId,
    required String id,
    required String title,
    required String ownerId,
  }) async {
    _check();
    final p = pages[parentId]!;
    if (p.under.any((u) => u.id == id)) return;
    calls.add('under $parentId $title $ownerId');
    pages[parentId] = PostPage(
      post: p.post,
      blocks: p.blocks,
      version: p.version,
      points: p.points,
      files: p.files,
      under: [
        ...p.under,
        PageUnder(id: id, title: title, ownerId: ownerId, ownerName: ownerId),
      ],
    );
  }

  @override
  Future<int> turnPointIntoItem({
    required String postId,
    required String pointId,
    required String itemId,
    required String ownerId,
    required int baseVersion,
  }) async {
    _check();
    final p = pages[postId]!;
    if (p.under.any((u) => u.id == itemId)) return p.version;
    if (baseVersion != p.version) throw const PageStaleException();
    final point = p.points.firstWhere((x) => x.id == pointId);
    if (point.ticked) throw const SpaceException(SpaceFailure.rule);
    calls.add('turn $pointId into $itemId for $ownerId');
    final blocks = <PageBlock>[];
    var placed = false;
    final child = PageChildItem('child-$itemId', itemId);
    for (final b in p.blocks) {
      if (b is PageChecklist && b.pointIds.contains(pointId)) {
        final rest = [
          for (final id in b.pointIds)
            if (id != pointId) id,
        ];
        if (rest.isNotEmpty) blocks.add(PageChecklist(b.id, rest));
        blocks.add(child);
        placed = true;
      } else {
        blocks.add(b);
      }
    }
    if (p.blocks.isNotEmpty && !placed) blocks.add(child);
    final version = p.blocks.isEmpty ? p.version : p.version + 1;
    pages[postId] = PostPage(
      post: p.post,
      blocks: blocks,
      version: version,
      points: [
        for (final x in p.points)
          if (x.id != pointId) x,
      ],
      files: p.files,
      under: [
        ...p.under,
        PageUnder(
          id: itemId,
          title: point.text,
          ownerId: ownerId,
          ownerName: ownerId,
        ),
      ],
    );
    return version;
  }
}
