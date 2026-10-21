import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The two haptics of the Space's work (daybook.md; review 50 F67).
enum BvHaptic {
  /// One short tick: a checklist point ticked.
  tick,

  /// The strong one: a work item checked, or signed as done.
  strong,
}

const _channel = MethodChannel('buildvibes/settings');

/// Plays [kind]. Every tick, check and sign-off comes here.
///
/// On Android 10 and later the phone's own effect plays (EFFECT_TICK, or
/// EFFECT_HEAVY_CLICK for [BvHaptic.strong]): Flutter's impacts become
/// key-press feedback, which MIUI plays very weakly or not at all (F67).
/// The phone's Haptic feedback setting wins: off, nothing is felt.
/// Elsewhere, Flutter's medium or heavy impact.
Future<void> bvHaptic(BvHaptic kind) async {
  try {
    // True: played; false: the phone's touch feedback is off. Null: the
    // phone has no such effect.
    final played = await _channel.invokeMethod<bool>('haptic', kind.name);
    if (played != null) return;
  } on PlatformException catch (e) {
    debugPrint('haptic: $e');
  } on MissingPluginException {
    // Not Android.
  }
  await switch (kind) {
    BvHaptic.tick => HapticFeedback.mediumImpact(),
    BvHaptic.strong => HapticFeedback.heavyImpact(),
  };
}
