import 'package:flutter/widgets.dart' show Locale, immutable;

import 'market.dart';

String _join(Object? first, Object? last) =>
    '${first ?? ''} ${last ?? ''}'.trim();

/// A photo on a post.
@immutable
class PostPhoto {
  const PostPhoto({required this.path, this.width, this.height});

  factory PostPhoto.fromJson(Map<String, dynamic> json) => PostPhoto(
    path: json['path'] as String,
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
  );

  final String path;
  final int? width;
  final int? height;

  Map<String, dynamic> toJson() => {
    'path': path,
    'width': width,
    'height': height,
  };
}

/// The project a post is tagged with (the active one, after merges).
@immutable
class PostProject {
  const PostProject({
    required this.id,
    required this.name,
    this.typeName,
    this.placeName,
    this.locationText,
  });

  final String id;
  final String name;
  final LocalizedText? typeName;
  final LocalizedText? placeName;
  final String? locationText;

  String? place(Locale locale) => placeName?.of(locale) ?? locationText;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': typeName == null ? null : {'en': typeName!.en, 'ar': typeName!.ar},
    'place': placeName == null
        ? null
        : {'en': placeName!.en, 'ar': placeName!.ar},
    'location': locationText,
  };

  static PostProject fromCache(Map<String, dynamic> j) => PostProject(
    id: j['id'] as String,
    name: j['name'] as String,
    typeName: j['type'] == null
        ? null
        : LocalizedText.fromJson(j['type'] as Map<String, dynamic>),
    placeName: j['place'] == null
        ? null
        : LocalizedText.fromJson(j['place'] as Map<String, dynamic>),
    locationText: j['location'] as String?,
  );

  PostProject withNames({LocalizedText? typeName, LocalizedText? placeName}) =>
      PostProject(
        id: id,
        name: name,
        typeName: typeName ?? this.typeName,
        placeName: placeName ?? this.placeName,
        locationText: locationText,
      );
}

/// A post card (post_cards): author, text, photos and the tag. No counts.
@immutable
class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.lang,
    required this.createdAt,
    this.authorHeadline,
    this.authorCompany,
    this.body,
    this.project,
    this.editedAt,
    this.photos = const [],
    this.myUseful = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    authorId: json['author_id'] as String,
    authorName: _join(json['author_first_name'], json['author_last_name']),
    authorHeadline: json['author_headline'] as String?,
    authorCompany: json['author_company'] as String?,
    body: json['body'] as String?,
    lang: json['lang'] as String? ?? 'en',
    project: json['project_id'] == null
        ? null
        : PostProject(
            id: json['project_id'] as String,
            name: json['project_name'] as String? ?? '',
            locationText: json['project_location'] as String?,
          ),
    createdAt: DateTime.parse(json['created_at'] as String),
    editedAt: json['edited_at'] == null
        ? null
        : DateTime.parse(json['edited_at'] as String),
    photos: [
      for (final m in (json['media'] as List?) ?? const [])
        PostPhoto.fromJson(m as Map<String, dynamic>),
    ],
    myUseful: json['my_useful'] as bool? ?? false,
  );

  final String id;
  final String authorId;
  final String authorName;
  final String? authorHeadline;
  final String? authorCompany;
  final String? body;

  /// 'en' or 'ar': the language it was written in.
  final String lang;
  final PostProject? project;
  final DateTime createdAt;
  final DateTime? editedAt;
  final List<PostPhoto> photos;
  final bool myUseful;

  /// For the offline copy of the feed (H6).
  Map<String, dynamic> toCache() => {
    'id': id,
    'author_id': authorId,
    'author_name': authorName,
    'author_headline': authorHeadline,
    'author_company': authorCompany,
    'body': body,
    'lang': lang,
    'project': project?.toJson(),
    'created_at': createdAt.toIso8601String(),
    'edited_at': editedAt?.toIso8601String(),
    'media': [for (final p in photos) p.toJson()],
    'my_useful': myUseful,
  };

  static Post fromCache(Map<String, dynamic> j) => Post(
    id: j['id'] as String,
    authorId: j['author_id'] as String,
    authorName: j['author_name'] as String,
    authorHeadline: j['author_headline'] as String?,
    authorCompany: j['author_company'] as String?,
    body: j['body'] as String?,
    lang: j['lang'] as String? ?? 'en',
    project: j['project'] == null
        ? null
        : PostProject.fromCache(j['project'] as Map<String, dynamic>),
    createdAt: DateTime.parse(j['created_at'] as String),
    editedAt: j['edited_at'] == null
        ? null
        : DateTime.parse(j['edited_at'] as String),
    photos: [
      for (final m in (j['media'] as List?) ?? const [])
        PostPhoto.fromJson(m as Map<String, dynamic>),
    ],
    myUseful: j['my_useful'] as bool? ?? false,
  );

  Post copyWith({
    String? body,
    String? lang,
    bool? myUseful,
    PostProject? project,
    DateTime? editedAt,
  }) => Post(
    id: id,
    authorId: authorId,
    authorName: authorName,
    authorHeadline: authorHeadline,
    authorCompany: authorCompany,
    body: body ?? this.body,
    lang: lang ?? this.lang,
    project: project ?? this.project,
    createdAt: createdAt,
    editedAt: editedAt ?? this.editedAt,
    photos: photos,
    myUseful: myUseful ?? this.myUseful,
  );
}

/// The two parts of the feed: the home market, then "Beyond {market}".
enum FeedSection { home, beyond }

@immutable
class FeedEntry {
  const FeedEntry({required this.section, required this.post});

  final FeedSection section;
  final Post post;
}

/// A page of posts and where the next one starts (null at the end).
@immutable
class PostPage<T> {
  const PostPage({required this.items, this.next});

  final List<T> items;
  final Map<String, dynamic>? next;
}

/// A reply on a post. [replyTo] is the top-level reply it is filed under;
/// [replyToPerson] is the person it answers ("Replying to {name}", review
/// 50 F2). The server keeps that person from migration 25 on; before it,
/// or for older replies, it is null and the top-level reply's author is
/// the one answered.
@immutable
class PostReply {
  const PostReply({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.authorHeadline,
    this.replyTo,
    this.replyToPerson,
    this.myUseful = false,
  });

  factory PostReply.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return PostReply(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      authorName: _join(author?['first_name'], author?['last_name']),
      authorHeadline: author?['headline'] as String?,
      replyTo: json['reply_to'] as String?,
      // Absent before migration 25.
      replyToPerson: json['reply_to_person'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorHeadline;
  final String? replyTo;
  final String? replyToPerson;
  final String body;
  final DateTime createdAt;
  final bool myUseful;

  PostReply copyWith({bool? myUseful}) => PostReply(
    id: id,
    postId: postId,
    authorId: authorId,
    authorName: authorName,
    authorHeadline: authorHeadline,
    replyTo: replyTo,
    replyToPerson: replyToPerson,
    body: body,
    createdAt: createdAt,
    myUseful: myUseful ?? this.myUseful,
  );
}

/// The post language from its letters: Arabic if most letters are Arabic.
String detectLang(String text) {
  var arabic = 0;
  var latin = 0;
  for (final r in text.runes) {
    if (r >= 0x0600 && r <= 0x06FF) {
      arabic++;
    } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) {
      latin++;
    }
  }
  return arabic > latin ? 'ar' : 'en';
}
