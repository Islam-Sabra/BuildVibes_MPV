import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../shared/widgets/bv_text_field.dart' show BvWesternDigitsFormatter;
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';

/// Voice notes stop on their own at this length (review 12).
const maxVoice = Duration(minutes: 2);

/// Shorter than this is a slip of the thumb, not a voice note.
const minVoice = Duration(seconds: 1);

/// "0:42", "1:58": minutes and seconds, Western digits.
String voiceTime(Duration d) {
  final s = d.inSeconds;
  return BvWesternDigitsFormatter.normalise(
    '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
  );
}

/// Records a voice note to a file on the phone. A provider so tests can
/// stand in for the microphone.
abstract class VoiceRecorder {
  /// Asks for the microphone the first time. False when it's refused.
  Future<bool> allowed();

  /// Starts recording; returns the file it records to.
  Future<String> start();

  /// Stops; returns the recorded file, or null when nothing was recorded.
  Future<String?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();
}

/// AAC-LC in an .m4a file, one channel at 32 kbit/s: about 240 KB a minute,
/// clear enough for speech on a site.
class PhoneVoiceRecorder implements VoiceRecorder {
  PhoneVoiceRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> allowed() => _recorder.hasPermission();

  @override
  Future<String> start() async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/chat_outbox',
    );
    await dir.create(recursive: true);
    final path = '${dir.path}/${newUuid()}.m4a';
    await _recorder.start(
      const RecordConfig(numChannels: 1, bitRate: 32000),
      path: path,
    );
    return path;
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();
}

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = PhoneVoiceRecorder();
  ref.onDispose(recorder._recorder.dispose);
  return recorder;
});

/// Plays voice notes. A provider so tests can stand in for the speaker.
abstract class VoicePlayback {
  /// [source] is a link or a file on the phone.
  Future<void> play(String source, {required bool isFile});
  Future<void> pause();
  Future<void> resume();
  Stream<Duration> get position;

  /// Emits when a note plays to its end.
  Stream<void> get finished;
}

class PhoneVoicePlayback implements VoicePlayback {
  final _player = AudioPlayer();

  @override
  Future<void> play(String source, {required bool isFile}) async {
    if (isFile) {
      await _player.setFilePath(source);
    } else {
      await _player.setUrl(source);
    }
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<void> get finished => _player.processingStateStream
      .where((s) => s == ProcessingState.completed)
      .map((_) {});

  Future<void> dispose() => _player.dispose();
}

final voicePlaybackProvider = Provider<VoicePlayback>((ref) {
  final player = PhoneVoicePlayback();
  ref.onDispose(player.dispose);
  return player;
});

/// What is playing now: one voice note at a time.
@immutable
class VoiceState {
  const VoiceState({
    this.id,
    this.playing = false,
    this.position = Duration.zero,
  });

  final String? id;
  final bool playing;
  final Duration position;
}

final voicePlayerProvider = NotifierProvider<VoicePlayer, VoiceState>(
  VoicePlayer.new,
);

class VoicePlayer extends Notifier<VoiceState> {
  StreamSubscription<Duration>? _position;
  StreamSubscription<void>? _finished;

  @override
  VoiceState build() {
    final playback = ref.watch(voicePlaybackProvider);
    _position = playback.position.listen((p) {
      if (state.id != null) {
        state = VoiceState(id: state.id, playing: state.playing, position: p);
      }
    });
    _finished = playback.finished.listen((_) => state = const VoiceState());
    ref.onDispose(() {
      _position?.cancel();
      _finished?.cancel();
    });
    return const VoiceState();
  }

  /// Plays [id] from [source]; pauses it when it is playing; another note
  /// stops the one before.
  Future<void> toggle(String id, String source, {required bool isFile}) async {
    final playback = ref.read(voicePlaybackProvider);
    if (state.id == id) {
      if (state.playing) {
        await playback.pause();
        state = VoiceState(id: id, position: state.position);
      } else {
        await playback.resume();
        state = VoiceState(id: id, playing: true, position: state.position);
      }
      return;
    }
    state = VoiceState(id: id, playing: true);
    await playback.play(source, isFile: isFile);
  }
}

/// A voice note in a bubble: play or pause, progress, and its length.
/// [path] is in the Space; [local] is still on the phone.
class VoiceNote extends ConsumerWidget {
  const VoiceNote({
    super.key,
    required this.id,
    required this.duration,
    this.path,
    this.local,
  });

  final String id;
  final Duration duration;
  final String? path;
  final String? local;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final voice = ref.watch(voicePlayerProvider);
    final mine = voice.id == id;
    final playing = mine && voice.playing;
    final position = mine ? voice.position : Duration.zero;
    final total = duration.inMilliseconds == 0 ? minVoice : duration;
    final progress = (position.inMilliseconds / total.inMilliseconds).clamp(
      0.0,
      1.0,
    );

    Future<void> toggle() async {
      if (local != null) {
        await ref
            .read(voicePlayerProvider.notifier)
            .toggle(id, local!, isFile: true);
        return;
      }
      final url = await ref.read(fileUrlProvider(path!).future);
      await ref
          .read(voicePlayerProvider.notifier)
          .toggle(id, url, isFile: false);
    }

    return SizedBox(
      key: Key('chat-voice-$id'),
      width: BvChatSpec.voiceWidth,
      child: Row(
        spacing: BvSpace.s8,
        children: [
          IconButton.filled(
            key: Key('chat-voice-play-$id'),
            tooltip: playing ? l10n.chatPause : l10n.chatPlay,
            style: IconButton.styleFrom(
              backgroundColor: BvColors.actionPrimary,
              foregroundColor: BvColors.actionPrimaryForeground,
            ),
            icon: Icon(
              playing ? BvIcons.pause : BvIcons.play,
              size: BvSize.iconMd,
            ),
            onPressed: toggle,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvSpace.s4,
              children: [
                ClipRRect(
                  borderRadius: BvRadius.roundAll,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: BvChatSpec.voiceBar,
                    color: BvColors.textAction,
                    backgroundColor: BvColors.borderDefault,
                  ),
                ),
                Text(
                  voiceTime(
                    mine && position > Duration.zero ? position : duration,
                  ),
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The orange mic of S8k: hold to record, release to send, slide away to
/// cancel. A tap says how.
class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.onStart,
    required this.onSlide,
    required this.onEnd,
    required this.onTap,
  });

  final VoidCallback onStart;

  /// How far the thumb has moved from where it started.
  final ValueChanged<Offset> onSlide;
  final VoidCallback onEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.chatRecord,
      // The raw pointer too: a lifted or cancelled thumb (a permission
      // dialog takes the pointer) always ends the hold.
      child: Listener(
        onPointerUp: (_) => onEnd(),
        onPointerCancel: (_) => onEnd(),
        child: GestureDetector(
          key: const Key('chat-record'),
          onTap: onTap,
          onLongPressStart: (_) => onStart(),
          onLongPressMoveUpdate: (d) => onSlide(d.offsetFromOrigin),
          onLongPressEnd: (_) => onEnd(),
          child: Container(
            width: BvSize.controlMd,
            height: BvSize.controlMd,
            decoration: const BoxDecoration(
              color: BvColors.actionPrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              BvIcons.microphone,
              size: BvSize.iconMd,
              color: BvColors.actionPrimaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}

/// While recording: a red dot, the time, and how to cancel.
class RecordingBar extends StatelessWidget {
  const RecordingBar({
    super.key,
    required this.elapsed,
    required this.cancelling,
  });

  final Duration elapsed;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Container(
      key: const Key('chat-recording'),
      constraints: const BoxConstraints(minHeight: BvSize.controlMd),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: BvSpace.s16),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvRadius.roundAll,
      ),
      child: Row(
        spacing: BvSpace.s8,
        children: [
          Container(
            width: BvChatSpec.recordDot,
            height: BvChatSpec.recordDot,
            decoration: const BoxDecoration(
              color: BvColors.textDestructive,
              shape: BoxShape.circle,
            ),
          ),
          Text(voiceTime(elapsed), style: type.labelMd),
          Expanded(
            child: Text(
              cancelling ? l10n.chatReleaseToCancel : l10n.chatSlideToCancel,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodySm.copyWith(
                color: cancelling
                    ? BvColors.textDestructive
                    : BvColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
