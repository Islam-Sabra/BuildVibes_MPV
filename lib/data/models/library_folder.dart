import 'package:flutter/foundation.dart';

/// Review 113 (8, 9), LB1 and LB2: a Library folder, or a linked folder
/// (a OneDrive, Google Drive or Dropbox share link that opens in the
/// browser). Who sees it is one single choice (rule 6); a file in a
/// folder is seen by whoever sees the folder (the server's
/// can_read_library_folder).

/// Who sees a folder.
enum FolderShare {
  onlyMe('only_me'),
  person('person'),
  team('team'),
  space('space');

  const FolderShare(this.json);
  final String json;

  static FolderShare fromJson(Object? v) =>
      values.where((s) => s.json == v).firstOrNull ?? onlyMe;
}

/// The service a linked folder lives in.
enum LinkService {
  oneDrive('onedrive'),
  googleDrive('google_drive'),
  dropbox('dropbox');

  const LinkService(this.json);
  final String json;

  static LinkService? fromJson(Object? v) =>
      values.where((s) => s.json == v).firstOrNull;
}

/// The service a pasted share link is from, as the server works it out
/// (create_library_folder): https only, and the host one of OneDrive's
/// (onedrive.live.com, 1drv.ms, any *.sharepoint.com), Google Drive's
/// (drive.google.com, docs.google.com) or Dropbox's (www.dropbox.com,
/// dropbox.com). Null for anything else.
LinkService? linkServiceOf(String text) {
  final uri = Uri.tryParse(text.trim());
  // As the server: https, no user@, no port but 443.
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host == 'onedrive.live.com' ||
      host == '1drv.ms' ||
      host.endsWith('.sharepoint.com')) {
    return LinkService.oneDrive;
  }
  if (host == 'drive.google.com' || host == 'docs.google.com') {
    return LinkService.googleDrive;
  }
  if (host == 'www.dropbox.com' || host == 'dropbox.com') {
    return LinkService.dropbox;
  }
  return null;
}

/// A folder in a Space's Library, as space_library_folders gives it.
@immutable
class LibraryFolder {
  const LibraryFolder({
    required this.id,
    required this.name,
    required this.share,
    this.url,
    this.service,
    this.sharePersonId,
    this.sharePersonName,
    this.shareTeamId,
    this.shareTeamName,
    this.hasFiles = false,
    this.createdBy,
    this.mine = false,
  });

  factory LibraryFolder.fromJson(Map<String, dynamic> json) => LibraryFolder(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    share: FolderShare.fromJson(json['share']),
    url: json['kind'] == 'link' ? json['url'] as String? : null,
    service: LinkService.fromJson(json['service']),
    sharePersonId: json['share_person'] as String?,
    sharePersonName: json['share_person_name'] as String?,
    shareTeamId: json['share_team'] as String?,
    shareTeamName: json['share_team_name'] as String?,
    // Only whether it holds files (Delete asks to empty it first); the
    // number is never shown (rule 3).
    hasFiles: ((json['file_count'] as num?) ?? 0) > 0,
    createdBy: json['created_by'] as String?,
    mine: json['mine'] == true,
  );

  final String id;
  final String name;
  final FolderShare share;

  /// A linked folder's share link; null for a folder of files.
  final String? url;
  final LinkService? service;
  final String? sharePersonId;
  final String? sharePersonName;
  final String? shareTeamId;
  final String? shareTeamName;
  final bool hasFiles;
  final String? createdBy;

  /// I made it.
  final bool mine;

  bool get isLink => url != null;
}

/// A folder to make or change (create_library_folder,
/// update_library_folder). [url] makes it a linked folder.
@immutable
class FolderChange {
  const FolderChange({
    required this.id,
    required this.spaceId,
    required this.name,
    required this.share,
    this.personId,
    this.teamId,
    this.url,
  });

  final String id;
  final String spaceId;
  final String name;
  final FolderShare share;
  final String? personId;
  final String? teamId;
  final String? url;

  /// The server's rule: a person or a Team only with that choice.
  bool get complete =>
      name.trim().isNotEmpty &&
      name.trim().length <= LibraryFolderRules.nameMax &&
      (share != FolderShare.person || personId != null) &&
      (share != FolderShare.team || teamId != null) &&
      (url == null || linkServiceOf(url!) != null);
}

/// The server's limits (library_folders.name 1..80).
abstract final class LibraryFolderRules {
  static const nameMax = 80;
}
