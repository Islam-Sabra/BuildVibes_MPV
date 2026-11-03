import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daybook.dart';
import '../../data/models/library.dart';
import '../../data/models/library_folder.dart';
import '../../data/models/space.dart' show SpaceException;
import '../../data/models/upload_rules.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../spaces/space_errors.dart';
import '../work/could_not_send.dart' show showFileRefused;
import '../work/daybook_attach.dart';

/// libfix (Z14, privacy): who hears that a file has a new version: its
/// folder's own audience (the whole Space at the Library's top level).
/// Null, nobody, for an only-me or a person's folder.
({String? teamId})? newVersionAudience(LibraryFolder? folder) =>
    switch (folder?.share) {
      null || FolderShare.space => (teamId: null),
      FolderShare.team when folder!.shareTeamId != null => (
        teamId: folder.shareTeamId,
      ),
      _ => null,
    };

/// libfix (Z14, privacy): + Add a file and Add a new version in the
/// Library. The file from the phone goes straight into [folder] (or
/// [replaces]'s), with the folder's sharing, and no post: a post would open
/// it for everyone who sees the post. Only a new version in a whole-Space
/// or Team folder tells that same audience, with a small file post.
Future<void> addLibraryFileHere(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  LibraryFolder? folder,
  LibraryFile? replaces,
}) async {
  final l10n = AppLocalizations.of(context);
  final folderId = folder?.id ?? replaces?.folderId;
  final into =
      folder ??
      (ref.read(libraryFoldersProvider(spaceId)).value ?? const [])
          .where((f) => f.id == folderId)
          .firstOrNull;
  final file = await chooseDaybookFile(
    context,
    ref,
    spaceId: spaceId,
    replaces: replaces,
    source: DaybookFileSource.phone,
    folderId: folderId,
    sameFolder: true,
  );
  final local = file?.local;
  if (file == null || local == null || !context.mounted) return;
  final older =
      replaces ??
      (ref.read(libraryFilesProvider(spaceId)).value ?? const [])
          .where((f) => f.id == file.supersedesId)
          .firstOrNull;
  final library = ref.read(libraryRepositoryProvider);
  try {
    final path = await library.upload(
      spaceId,
      file.libraryId,
      PhoneFile(
        local: local,
        name: file.name,
        mime: file.mime,
        bytes: file.bytes,
      ),
    );
    await library.add(
      id: file.libraryId,
      spaceId: spaceId,
      name: file.name,
      path: path,
      mime: file.mime,
      bytes: file.bytes,
      revLabel: file.revLabel,
      supersedesId: file.supersedesId,
      folderId: file.folderId,
    );
    final to = file.supersedesId == null ? null : newVersionAudience(into);
    if (to != null) {
      await ref
          .read(daybookRepositoryProvider)
          .createPost(
            NewSpacePost(
              id: newUuid(),
              spaceId: spaceId,
              kind: DaybookPost.fileKind,
              title: l10n.libraryNewVersionPost(
                file.name,
                file.revLabel ??
                    l10n.libraryVersionNo((older?.versionNo ?? 1) + 1),
              ),
              libraryFileId: file.libraryId,
              teamId: to.teamId,
            ),
          );
    }
  } on FileRefused catch (e) {
    if (context.mounted) {
      await showFileRefused(context, ref, spaceId: spaceId, refused: e);
    }
  } on SpaceException catch (e) {
    if (context.mounted) showSpaceError(context, e);
  } finally {
    ref
      ..invalidate(libraryFilesProvider(spaceId))
      ..invalidate(libraryFoldersProvider(spaceId))
      ..invalidate(libraryOverviewProvider(spaceId));
    // The copy kept while it went; nothing waits for it.
    unawaited(_deleteKept(local));
  }
}

Future<void> _deleteKept(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // Already gone.
  }
}
