import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/l10n/bv_time.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/check_in.dart';
import '../../data/models/space.dart' show SpaceException;
import '../../l10n/gen/app_localizations.dart';
import 'check_in_marking.dart' show CheckInMarker;
import 'check_in_words.dart';

/// Review 109 CI2: a check-in's notifications. The server's data push
/// (`check_in_open`) is drawn by the app, with Check in (or Check out) ·
/// Open; the result of a mark from it comes back as a notification too.
/// Everything here is plain Dart behind [CheckInNotifier], so it is
/// tested without a phone.

/// The push kinds (push_queue.kind, data "kind").
const checkInOpenKind = 'check_in_open';
const checkInSummaryKind = 'check_in_summary';

/// The Android channel (the server's data "channel_id"): high importance,
/// with sound.
const checkInChannelId = 'check_in';

/// iOS categories, registered at start so the server's alert shows the
/// buttons.
const checkInCategoryIn = 'CHECK_IN_IN';
const checkInCategoryOut = 'CHECK_IN_OUT';

/// A notification's actions.
const checkInActionMark = 'check_in_mark';
const checkInActionOpen = 'check_in_open';

/// A payload of ours starts with this, so a reminder's never mixes in.
const checkInPayloadPrefix = 'check_in:';

/// A check_in_open push: which post, In or Out, and the words the server
/// chose (push_title, push_body: plain words when the person keeps text
/// off the lock screen). Never rebuilt from the other fields.
@immutable
class CheckInPush {
  const CheckInPush({
    required this.postId,
    required this.spaceId,
    required this.kind,
    this.title,
    this.body,
    this.postTitle,
    this.zone,
    this.tag,
  });

  /// Null when [data] isn't a check_in_open push.
  static CheckInPush? fromData(Map<String, String> data) {
    if (data['kind'] != checkInOpenKind) return null;
    final post = data['post_id'];
    final space = data['space_id'];
    if (post == null || space == null) return null;
    return CheckInPush(
      postId: post,
      spaceId: space,
      kind: CheckInMarkKind.fromJson(data['mark']),
      title: data['push_title'],
      body: data['push_body'],
      postTitle: data['title'],
      zone: data['tz'],
      tag: data['tag'],
    );
  }

  /// The payload a notification carries back when tapped: ids only.
  static CheckInPush? fromPayload(String? payload) {
    if (payload == null || !payload.startsWith(checkInPayloadPrefix)) {
      return null;
    }
    try {
      final j =
          jsonDecode(payload.substring(checkInPayloadPrefix.length))
              as Map<String, dynamic>;
      return CheckInPush(
        postId: j['post_id'] as String,
        spaceId: j['space_id'] as String,
        kind: CheckInMarkKind.fromJson(j['mark']),
        postTitle: j['title'] as String?,
        zone: j['tz'] as String?,
        tag: j['tag'] as String?,
      );
    } on Object {
      return null;
    }
  }

  final String postId;
  final String spaceId;
  final CheckInMarkKind kind;
  final String? title;
  final String? body;

  /// The post's own title, and the Space's time zone (data "title",
  /// "tz"): kept in the payload, shown only as [checkInResultNotice] says.
  final String? postTitle;
  final String? zone;

  /// The server's tag on Android (`checkin:<post>:<in|out>`): FCM posts
  /// its own notification under it with id 0, so the app's, with the
  /// same tag and id 0, replaces it. Never two.
  final String? tag;

  String get payload =>
      checkInPayloadPrefix +
      jsonEncode({
        'post_id': postId,
        'space_id': spaceId,
        'mark': kind.json,
        'title': ?postTitle,
        'tz': ?zone,
        'tag': ?tag,
      });

  /// The same notification for the same post and mark: a new one
  /// replaces it, and the result takes its place. With the server's
  /// [tag], id 0 (as FCM's own), so the system's notification goes.
  int get notificationId =>
      tag == null ? checkInNotificationId(postId, kind) : fcmNotificationId;
}

/// The id FCM gives the notification it draws itself.
const fcmNotificationId = 0;

int checkInNotificationId(String postId, CheckInMarkKind kind) {
  var h = 0x811c9dc5;
  for (final c in '$postId:${kind.json}'.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// One action on a notification.
typedef CheckInNoticeAction = ({String id, String label, bool opensApp});

/// What a notification shows.
@immutable
class CheckInNotice {
  const CheckInNotice({
    required this.id,
    required this.title,
    required this.body,
    this.actions = const [],
    this.payload,
    this.category,
    this.tag,
  });

  final int id;

  /// Android's tag: with [id], what a notification replaces.
  final String? tag;
  final String title;
  final String body;
  final List<CheckInNoticeAction> actions;
  final String? payload;

  /// iOS's category for the buttons.
  final String? category;
}

/// The phone's side: draws a notice. A fake in tests.
abstract class CheckInNotifier {
  /// The "check_in" channel (high importance, sound), made at start so
  /// the server's own notification lands on it before the app drew one.
  Future<void> ensureChannel();

  Future<void> show(CheckInNotice notice);
}

/// CI2: the notification for [push], drawn from the server's words, with
/// Check in (or Check out) · Open. [accepted]: the person said yes to the
/// warning (CI3) on this phone, so Check in marks without opening the app
/// (Android); otherwise it opens the app, where the warning comes first.
CheckInNotice checkInOpenNotice(
  AppLocalizations l10n,
  CheckInPush push, {
  required bool accepted,
}) {
  final out = push.kind == CheckInMarkKind.checkOut;
  return CheckInNotice(
    id: push.notificationId,
    tag: push.tag,
    title: push.title ?? (out ? l10n.checkInTimeOut : l10n.checkInTimeIn),
    body: push.body ?? '',
    payload: push.payload,
    category: out ? checkInCategoryOut : checkInCategoryIn,
    actions: [
      (
        id: checkInActionMark,
        label: out ? l10n.checkOutButton : l10n.checkInButton,
        opensApp: !accepted,
      ),
      (id: checkInActionOpen, label: l10n.checkInActionOpen, opensApp: true),
    ],
  );
}

/// "Checked in 6:58 · on site" (CI2), in place of the notification it
/// answers. Its title names the post only when the person shows text on
/// the lock screen ([showText]); otherwise it is the plain "Check-in".
CheckInNotice checkInResultNotice(
  AppLocalizations l10n,
  BvTime time,
  CheckInPush push,
  CheckInResult result, {
  required bool showText,
}) => CheckInNotice(
  id: push.notificationId,
  tag: push.tag,
  title: showText && push.postTitle != null
      ? push.postTitle!
      : l10n.checkInChannel,
  body: checkInResultText(l10n, time, push.zone, result),
  payload: push.payload,
);

/// A refusal, in place of the notification, in plain words.
CheckInNotice checkInRefusedNotice(
  AppLocalizations l10n,
  CheckInPush push,
  CheckInRefusal why,
) => CheckInNotice(
  id: push.notificationId,
  tag: push.tag,
  title: l10n.checkInChannel,
  body: checkInRefusalText(l10n, why),
  payload: push.payload,
);

/// Where a tap on a check-in push opens: the post's card for
/// check_in_open, the creator's list for check_in_summary (CI5).
String? checkInPushRoute(Map<String, String> data) {
  final post = data['post_id'];
  final space = data['space_id'];
  if (post == null || space == null) return null;
  return switch (data['kind']) {
    checkInOpenKind => AppRoutes.spaceCard(space, post),
    checkInSummaryKind => AppRoutes.spaceCheckIn(space, post),
    _ => null,
  };
}

/// The Check in action from a notification (Android, without opening the
/// app): the mark as the card makes it, the location read once when the
/// person accepted the warning on this phone; then the result in place of
/// the notification. Never throws.
Future<CheckInResult?> markFromNotice({
  required CheckInPush push,
  required CheckInMarker marker,
  required CheckInNotifier notifier,
  required AppLocalizations l10n,
  required BvTime time,
  required Future<bool> Function() showText,
}) async {
  try {
    final result = await marker.mark(
      push.postId,
      push.kind,
      share: marker.accepted,
    );
    var shown = false;
    try {
      shown = await showText();
    } on Object {
      // Unknown: plain words, as on the lock screen.
    }
    await notifier.show(
      checkInResultNotice(l10n, time, push, result, showText: shown),
    );
    return result;
  } on SpaceException catch (e) {
    await notifier.show(checkInRefusedNotice(l10n, push, CheckInRefusal.of(e)));
    return null;
  }
}
