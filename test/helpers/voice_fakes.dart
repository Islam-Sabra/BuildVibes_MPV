import 'dart:async';
import 'dart:io';

import 'package:buildvibes/features/chat/voice.dart';

/// A real tiny .m4a on disk, the stand-in for a recording.
final String testVoicePath = () {
  final dir = Directory.systemTemp.createTempSync('bv_test_voice');
  return (File(
    '${dir.path}/voice.m4a',
  )..writeAsBytesSync(List<int>.filled(512, 7))).path;
}();

/// The microphone with no microphone. [allowedValue] false is a refused
/// permission.
class FakeVoiceRecorder implements VoiceRecorder {
  bool allowedValue = true;
  final calls = <String>[];
  String? _recording;

  @override
  Future<bool> allowed() async => allowedValue;

  @override
  Future<String> start() async {
    calls.add('start');
    // A fresh copy, so a sent note can delete its own file.
    final copy =
        '${Directory.systemTemp.createTempSync('bv_rec').path}/rec.m4a';
    File(testVoicePath).copySync(copy);
    return _recording = copy;
  }

  @override
  Future<String?> stop() async {
    calls.add('stop');
    final path = _recording;
    _recording = null;
    return path;
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
    _recording = null;
  }
}

/// The speaker with no speaker: what was played, and a position to push.
class FakeVoicePlayback implements VoicePlayback {
  final played = <String>[];
  final calls = <String>[];
  final _position = StreamController<Duration>.broadcast();
  final _finished = StreamController<void>.broadcast();

  void moveTo(Duration d) => _position.add(d);
  void finish() => _finished.add(null);

  @override
  Future<void> play(String source, {required bool isFile}) async {
    played.add('${isFile ? 'file' : 'url'} $source');
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<void> get finished => _finished.stream;
}
