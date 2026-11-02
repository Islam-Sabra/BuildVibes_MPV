import 'package:buildvibes/data/models/need_you.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/need_you_repository.dart';

/// Need you now with no network.
class FakeNeedYouRepository implements NeedYouRepository {
  final sent = <({String id, String to, String? reason, String? place})>[];
  final answers = <String>[];
  final callsList = <NeedYouCall>[];

  /// send_need_you and answer_need_you refuse with these.
  SpaceException? refuseSend;
  SpaceException? refuseAnswer;

  @override
  Future<void> send({
    required String id,
    required String spaceId,
    required String toId,
    String? reason,
    String? place,
  }) async {
    if (refuseSend case final e?) throw e;
    sent.add((id: id, to: toId, reason: reason, place: place));
  }

  @override
  Future<void> answer(String callId, NeedYouAnswer answer) async {
    if (refuseAnswer case final e?) throw e;
    answers.add('$callId ${answer.json}');
  }

  @override
  Future<List<NeedYouCall>> calls({String? spaceId}) async => [
    for (final c in callsList)
      if (spaceId == null || c.spaceId == spaceId) c,
  ];
}
