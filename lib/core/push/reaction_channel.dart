import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../l10n/gen/app_localizations.dart';

/// Review 113 RX1: the server sends a reaction's push (`post_reaction`) on
/// this Android channel.
const reactionsChannelId = 'reactions';

/// The quiet "Reactions" channel: low importance, so a reaction makes no
/// sound and never pops up. Made at app start and in the background
/// handler, with the Check-in channel.
AndroidNotificationChannel reactionsChannel(AppLocalizations l10n) =>
    AndroidNotificationChannel(
      reactionsChannelId,
      l10n.reactionsChannel,
      description: l10n.reactionsChannelAbout,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
