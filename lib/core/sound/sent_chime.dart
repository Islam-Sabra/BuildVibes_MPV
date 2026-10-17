import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// The soft "sent" sound with a light haptic (F5, review 50): when a post
/// or a sign-off is accepted by the server, never while it only waits.
/// On silent or vibrate, the haptic only.
class SentChime {
  SentChime({
    required this.soundOn,
    required this.playSound,
    required this.haptic,
  });

  /// Whether the phone's ringer lets sounds play (not silent or vibrate).
  final Future<bool> Function() soundOn;
  final Future<void> Function() playSound;
  final Future<void> Function() haptic;

  /// The haptic always; the sound only when the ringer is on.
  Future<void> play() async {
    final tap = _quietly(haptic);
    if (await _quietly(soundOn) ?? false) await _quietly(playSound);
    await tap;
  }

  /// A sound or a tap that can't play is never worth an error.
  static Future<T?> _quietly<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (_) {
      return null;
    }
  }
}

/// The ringer, from Android's AudioManager (MainActivity.kt). On iPhone
/// the sound plays without taking the audio session, so the silent switch
/// mutes it by itself.
Future<bool> phoneRingerAllowsSound() async {
  if (defaultTargetPlatform != TargetPlatform.android) return true;
  const channel = MethodChannel('buildvibes/sound');
  return await channel.invokeMethod<bool>('ringerNormal') ?? false;
}

/// Plays `assets/sounds/sent.wav`, loaded once. It never takes the audio
/// focus or session, so music or a call carries on.
class _SentSound {
  static const asset = 'assets/sounds/sent.wav';

  AudioPlayer? _player;
  Future<void>? _loaded;

  Future<void> play() async {
    final player = _player ??= AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: false,
    );
    await (_loaded ??= player.setAsset(asset));
    await player.seek(Duration.zero);
    unawaited(player.play());
  }

  Future<void> dispose() async => _player?.dispose();
}

/// A provider so tests can stand in for the speaker and the ringer.
final sentChimeProvider = Provider<SentChime>((ref) {
  final sound = _SentSound();
  ref.onDispose(sound.dispose);
  return SentChime(
    soundOn: phoneRingerAllowsSound,
    playSound: sound.play,
    haptic: HapticFeedback.lightImpact,
  );
});
