import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/library_folder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Review 113 (9) LB2: the service is found from the link', () {
    test('OneDrive', () {
      expect(linkServiceOf('https://1drv.ms/f/s!Ab3xYz'), LinkService.oneDrive);
      expect(
        linkServiceOf('https://onedrive.live.com/?id=ABC'),
        LinkService.oneDrive,
      );
      expect(
        linkServiceOf('https://contoso-my.sharepoint.com/:f:/g/abc'),
        LinkService.oneDrive,
      );
    });

    test('Google Drive', () {
      expect(
        linkServiceOf(' https://drive.google.com/drive/folders/1AbC '),
        LinkService.googleDrive,
      );
      expect(
        linkServiceOf('https://docs.google.com/document/d/1'),
        isNull,
        reason: 'Z10: a document, not a folder',
      );
    });

    test('Dropbox', () {
      expect(
        linkServiceOf('https://www.dropbox.com/scl/fo/abc'),
        LinkService.dropbox,
      );
      expect(linkServiceOf('https://dropbox.com/sh/abc'), LinkService.dropbox);
    });

    test('anything else is refused, as the server does', () {
      expect(linkServiceOf('http://1drv.ms/f/s!Ab3'), isNull, reason: 'https');
      expect(linkServiceOf('https://evil-sharepoint.com.example.org'), isNull);
      expect(linkServiceOf('https://example.com/drive.google.com'), isNull);
      expect(linkServiceOf('Gate 2 drawings'), isNull);
      expect(
        linkServiceOf('https://me@1drv.ms/f/s!A'),
        isNull,
        reason: 'user@',
      );
      expect(linkServiceOf('https://1drv.ms:8443/f/s!A'), isNull);
      expect(linkServiceOf('https://1drv.ms:443/f/s!A'), LinkService.oneDrive);
      expect(linkServiceOf(''), isNull);
    });
  });

  group('LB1: a folder as space_library_folders gives it', () {
    test('a Team folder', () {
      final f = LibraryFolder.fromJson({
        'id': 'f1',
        'name': 'MEP submittals',
        'kind': 'folder',
        'url': null,
        'service': null,
        'share': 'team',
        'share_person_name': null,
        'share_team_name': 'Gulf MEP',
        'file_count': 3,
        'created_by': 'u1',
        'mine': true,
      });
      expect(f.share, FolderShare.team);
      expect(f.shareTeamName, 'Gulf MEP');
      expect(f.isLink, isFalse);
      expect(f.hasFiles, isTrue);
      expect(f.mine, isTrue);
    });

    test('a linked folder', () {
      final f = LibraryFolder.fromJson({
        'id': 'f2',
        'name': 'Shop drawings, Block B',
        'kind': 'link',
        'url': 'https://1drv.ms/f/s!Ab3',
        'service': 'onedrive',
        'share': 'space',
        'file_count': 0,
        'mine': false,
      });
      expect(f.isLink, isTrue);
      expect(f.service, LinkService.oneDrive);
      expect(f.share, FolderShare.space);
      expect(f.hasFiles, isFalse);
    });
  });

  group('A folder to make', () {
    FolderChange change(
      FolderShare share, {
      String? person,
      String? team,
      String name = 'Drawings',
      String? url,
    }) => FolderChange(
      id: 'f',
      spaceId: 's',
      name: name,
      share: share,
      personId: person,
      teamId: team,
      url: url,
    );

    test('a person or a Team only with its pick', () {
      expect(change(FolderShare.space).complete, isTrue);
      expect(change(FolderShare.onlyMe).complete, isTrue);
      expect(change(FolderShare.person).complete, isFalse);
      expect(change(FolderShare.person, person: 'u2').complete, isTrue);
      expect(change(FolderShare.team).complete, isFalse);
      expect(change(FolderShare.team, team: 't1').complete, isTrue);
    });

    test('a name of 1 to 80, and a link the server takes', () {
      expect(change(FolderShare.space, name: '  ').complete, isFalse);
      expect(change(FolderShare.space, name: 'x' * 81).complete, isFalse);
      expect(
        change(FolderShare.space, url: 'https://example.com/x').complete,
        isFalse,
      );
      expect(
        change(FolderShare.space, url: 'https://1drv.ms/f/s!A').complete,
        isTrue,
      );
    });
  });

  test('a Library file keeps its folder (folder_id)', () {
    final f = LibraryFile.fromJson({
      'id': 'x',
      'name': 'A-501.pdf',
      'folder_id': 'f1',
    });
    expect(f.folderId, 'f1');
    expect(LibraryFile.fromJson({'id': 'y', 'name': 'b'}).folderId, isNull);
  });
}
