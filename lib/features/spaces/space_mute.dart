import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../shared/widgets/bv_mute_sheet.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'space_errors.dart';

/// F102: sets my notifications for a Space. Off or Needs you only first
/// asks for how long (8 hours / 1 week / Always); dismissing that changes
/// nothing. After the time the server counts it as All by itself. True
/// when it was saved.
Future<bool> setSpaceNotify(
  BuildContext context,
  WidgetRef ref,
  String spaceId,
  SpaceNotify level,
) async {
  DateTime? until;
  if (level != SpaceNotify.all) {
    final pick = await showMuteSheet(context);
    if (pick == null || !context.mounted) return false;
    until = pick.until(ref.read(clockProvider)());
  }
  try {
    await ref
        .read(spaceRepositoryProvider)
        .setNotifications(spaceId, level, until: until);
    ref
      ..invalidate(spaceDetailProvider(spaceId))
      ..invalidate(mySpacesProvider);
    return true;
  } on SpaceException catch (e) {
    if (context.mounted) showSpaceError(context, e);
    return false;
  }
}

/// F102: a long-press on a Space row: Mute (Off, for how long) or Unmute
/// (All).
Future<void> muteSpaceFromList(
  BuildContext context,
  WidgetRef ref,
  SpaceSummary space,
) async {
  if (!await showMuteMenu(context, muted: space.muted) || !context.mounted) {
    return;
  }
  await setSpaceNotify(
    context,
    ref,
    space.id,
    space.muted ? SpaceNotify.all : SpaceNotify.off,
  );
}
