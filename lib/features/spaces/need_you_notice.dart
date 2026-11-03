import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/need_you.dart';
import '../../data/models/space.dart';
import '../../data/repositories/need_you_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../work/check_in_notice.dart'
    show CheckInNotice, CheckInNotifier, fcmNotificationId;

/// Review 113 NN2: Need you now's notification, as check-in's (review 109,
/// option C): the server sends a notification with data on the `need_you`
/// channel under the tag `needyou:<call>`; the app draws its own under
/// that tag and id 0, replacing it, with On my way · Can't now, in exactly
/// the server's words (push_title, push_body: plain when the person keeps
/// text off the lock screen). Plain Dart, tested without a phone.

/// The push kinds (push_queue.kind, data "kind").
const needYouKind = 'need_you';
const needYouAnswerKind = 'need_you_answer';

/// The Android channel: high importance, with sound.
const needYouChannelId = 'need_you';

/// The iOS category the server's alert names.
const needYouCategory = 'NEED_YOU';

/// A notification's actions.
const needYouActionComing = 'need_you_coming';
const needYouActionCant = 'need_you_cant';

const needYouPayloadPrefix = 'need_you:';

/// The answer an action id stands for; null for a plain tap.
NeedYouAnswer? needYouAnswerOfAction(String? actionId) => switch (actionId) {
  needYouActionComing => NeedYouAnswer.coming,
  needYouActionCant => NeedYouAnswer.cant,
  _ => null,
};

/// A need_you push: ids, the tag, and the server's words, never rebuilt.
@immutable
class NeedYouPush {
  const NeedYouPush({
    required this.callId,
    required this.spaceId,
    this.title,
    this.body,
    this.tag,
    this.sentAt,
  });

  /// Null when [data] isn't a need_you push.
  static NeedYouPush? fromData(Map<String, String> data) {
    if (data['kind'] != needYouKind) return null;
    final call = data['call_id'];
    final space = data['space_id'];
    if (call == null || space == null) return null;
    return NeedYouPush(
      callId: call,
      spaceId: space,
      title: data['push_title'],
      body: data['push_body'],
      tag: data['tag'] ?? 'needyou:$call',
      sentAt: data['sent_at'],
    );
  }

  /// The payload a notification carries back: ids only.
  static NeedYouPush? fromPayload(String? payload) {
    if (payload == null || !payload.startsWith(needYouPayloadPrefix)) {
      return null;
    }
    try {
      final j =
          jsonDecode(payload.substring(needYouPayloadPrefix.length))
              as Map<String, dynamic>;
      return NeedYouPush(
        callId: j['call_id'] as String,
        spaceId: j['space_id'] as String,
        tag: j['tag'] as String?,
        sentAt: j['sent_at'] as String?,
      );
    } on Object {
      return null;
    }
  }

  final String callId;
  final String spaceId;
  final String? title;
  final String? body;
  final String? tag;

  /// When the server sent it (ISO 8601 UTC, review 114): a tap long after
  /// says the alert came late. A time, never words.
  final String? sentAt;

  String get payload =>
      needYouPayloadPrefix +
      jsonEncode({
        'call_id': callId,
        'space_id': spaceId,
        'tag': ?tag,
        'sent_at': ?sentAt,
      });
}

/// NN2: drawn from the server's words, with On my way · Can't now. On
/// Android they answer without opening the app; iPhone's category opens
/// it (needYouDarwinCategories).
CheckInNotice needYouNotice(AppLocalizations l10n, NeedYouPush push) =>
    CheckInNotice(
      id: fcmNotificationId,
      tag: push.tag,
      title: push.title ?? l10n.needYouSomeone,
      body: push.body ?? '',
      payload: push.payload,
      category: needYouCategory,
      actions: [
        (id: needYouActionComing, label: l10n.needYouOnMyWay, opensApp: false),
        (id: needYouActionCant, label: l10n.needYouCantNow, opensApp: false),
      ],
    );

String needYouAnswerWord(AppLocalizations l10n, NeedYouAnswer a) => switch (a) {
  NeedYouAnswer.coming => l10n.needYouOnMyWay,
  NeedYouAnswer.cant => l10n.needYouCantNow,
};

/// In place of the notification once answered. Never a name or a reason:
/// it stays on the lock screen.
CheckInNotice needYouResultNotice(
  AppLocalizations l10n,
  NeedYouPush push,
  String line,
) => CheckInNotice(
  id: fcmNotificationId,
  tag: push.tag,
  title: l10n.needYouNow,
  body: line,
  payload: push.payload,
);

/// An action on the notification: answer_need_you, then the result in
/// its place. Never throws.
Future<bool> answerFromNotice({
  required NeedYouPush push,
  required NeedYouAnswer answer,
  required NeedYouRepository repository,
  required CheckInNotifier notifier,
  required AppLocalizations l10n,
}) async {
  try {
    await repository.answer(push.callId, answer);
    await notifier.show(
      needYouResultNotice(
        l10n,
        push,
        l10n.needYouYouAnswered(needYouAnswerWord(l10n, answer)),
      ),
    );
    return true;
  } on SpaceException catch (e) {
    await notifier.show(
      needYouResultNotice(
        l10n,
        push,
        (e.message ?? '').contains('already answered')
            ? l10n.needYouAlreadyAnswered
            : l10n.needYouAnswerFailed,
      ),
    );
    return false;
  }
}

/// Whether Need you now shows for [target]: not myself, neither of us a
/// Viewer, they are in the Space and not blocked by me. A block the other
/// way only the server knows; it refuses in plain words.
bool mayCallNeedYou({
  required SpaceDetail space,
  required SpacePeople people,
  required String? me,
  required String target,
  Set<String> blocked = const {},
}) {
  if (me == null || me == target) return false;
  if (space.myPass == SpacePass.viewer) return false;
  final member = people.member(target);
  return member != null &&
      member.pass != SpacePass.viewer &&
      !blocked.contains(target);
}
