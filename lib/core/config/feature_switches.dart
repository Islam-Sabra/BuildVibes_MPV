import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Review 113 (6): the Home feed is hidden from the MVP and comes back
/// after the pilot. This one switch hides it: the bottom bar's first tab is
/// Spaces (no Home), the app opens there, a link to a feed post opens
/// Spaces, Create goes straight to a Space, and the notebook's Share offers
/// Space and Message only. The feed's code stays; `true` brings it all
/// back.
const feedEnabled = false;

/// [feedEnabled], as a provider so a test can turn the feed on.
final feedEnabledProvider = Provider<bool>((ref) => feedEnabled);
