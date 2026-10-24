import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/space.dart' show SpaceException;
import '../../data/repositories/dm_repository.dart';
import '../../shared/widgets/bv_mute_sheet.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/space_errors.dart';

/// F102: mutes a conversation for how long the person picks (8 hours /
/// 1 week / Always), or unmutes it when [muted]. Dismissing the sheet
/// changes nothing. After the time the server counts it as unmuted by
/// itself. True when it was saved.
Future<bool> toggleDmMute(
  BuildContext context,
  WidgetRef ref,
  String threadId, {
  required bool muted,
}) async {
  DateTime? until;
  if (!muted) {
    final pick = await showMuteSheet(context);
    if (pick == null || !context.mounted) return false;
    until = pick.until(ref.read(clockProvider)());
  }
  try {
    await ref
        .read(dmRepositoryProvider)
        .mute(threadId, on: !muted, until: until);
    ref.invalidate(dmInboxProvider);
    return true;
  } on SpaceException catch (e) {
    if (context.mounted) showSpaceError(context, e);
    return false;
  }
}

/// F102: a long-press on a conversation in Messages: Mute or Unmute.
Future<void> muteDmFromList(
  BuildContext context,
  WidgetRef ref,
  String threadId, {
  required bool muted,
}) async {
  if (!await showMuteMenu(context, muted: muted) || !context.mounted) return;
  await toggleDmMute(context, ref, threadId, muted: muted);
}
