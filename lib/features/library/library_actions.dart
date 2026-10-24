import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/share.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../chat/chat_tab.dart' show threadName;
import '../spaces/space_errors.dart';
import '../../core/routing/open_thread.dart';

/// What a Library file offers wherever it opens (F1, LV2): Download, and
/// Share in chat.

void _toast(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// Download: the file saved on the phone.
Future<void> downloadLibraryFile(
  BuildContext context,
  WidgetRef ref,
  LibraryFile f,
) async {
  final l10n = AppLocalizations.of(context);
  try {
    final bytes = await ref.read(libraryRepositoryProvider).download(f.path);
    final saved = await ref.read(saveFileProvider)(f.name, bytes);
    if (saved && context.mounted) _toast(context, l10n.previewSaved);
  } on SpaceException catch (e) {
    if (context.mounted) showSpaceError(context, e);
  }
}

/// A Team's file goes only to that Team's thread; an Everyone file to
/// any thread you see.
Future<void> shareLibraryFileInChat(
  BuildContext context,
  WidgetRef ref,
  String spaceId,
  LibraryFile f,
) async {
  final l10n = AppLocalizations.of(context);
  final threads = (await ref.read(
    spaceThreadsProvider(spaceId).future,
  )).where((t) => f.teamId == null || t.teamId == f.teamId).toList();
  if (!context.mounted || threads.isEmpty) return;
  final picked = await showBvSheet<String>(
    context: context,
    title: l10n.previewShareTo,
    subtitle: f.teamId == null ? null : l10n.previewShareTeamOnly,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in threads)
          BvListRow(
            key: Key('share-to-${t.id}'),
            title: threadName(l10n, t),
            leading: BvRowIcon(
              t.isEveryone ? BvIcons.team : BvIcons.chat,
              ink: true,
            ),
            onTap: () => Navigator.of(sheetContext).pop(t.id),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  // F77: the chat opens with the file in the message box, not sent, so
  // words can go with it (as in WhatsApp).
  await openSpaceThread(GoRouter.of(context), spaceId, picked, extra: f);
}
