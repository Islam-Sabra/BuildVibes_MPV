import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the phone's own share sheet (WhatsApp, SMS and so on). A provider
/// so tests can see what was shared.
typedef ShareText = Future<void> Function(String text);

final shareTextProvider = Provider<ShareText>(
  (ref) =>
      (text) => SharePlus.instance.share(ShareParams(text: text)),
);
