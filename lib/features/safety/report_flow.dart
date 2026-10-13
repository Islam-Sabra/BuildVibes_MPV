import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/space.dart';
import '../../data/repositories/safety_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../spaces/space_errors.dart';

String reasonTitle(AppLocalizations l10n, ReportReason r) => switch (r) {
  ReportReason.spam => l10n.reasonSpam,
  ReportReason.harassment => l10n.reasonHarassment,
  ReportReason.misleading => l10n.reasonMisleading,
  ReportReason.fake => l10n.reasonFake,
  ReportReason.privateInfo => l10n.reasonPrivate,
  ReportReason.other => l10n.reasonOther,
};

String _reasonHelp(AppLocalizations l10n, ReportReason r) => switch (r) {
  ReportReason.spam => l10n.reasonSpamHelp,
  ReportReason.harassment => l10n.reasonHarassmentHelp,
  ReportReason.misleading => l10n.reasonMisleadingHelp,
  ReportReason.fake => l10n.reasonFakeHelp,
  ReportReason.privateInfo => l10n.reasonPrivateHelp,
  ReportReason.other => l10n.reasonOtherHelp,
};

/// R1 → (a note for "Something else") → R2. The server hides what you
/// reported from you at once; [onReported] lets the screen drop it too,
/// once R2 closes (the frame keeps it behind R2, and dropping it earlier
/// would close the screen this flow runs on). R2 offers Block for posts
/// and people, when [person] is given.
Future<void> startReport(
  BuildContext context, {
  required ReportKind kind,
  required String id,
  ({String id, String name})? person,
  VoidCallback? onReported,
  VoidCallback? onBlocked,
}) async {
  final l10n = AppLocalizations.of(context);
  final container = ProviderScope.containerOf(context, listen: false);

  final reason = await showBvSheet<ReportReason>(
    context: context,
    title: l10n.reportTitle(kind.json),
    subtitle: l10n.reportSubtitle,
    builder: (sheet) => ClipRRect(
      key: const Key('report-sheet'),
      borderRadius: BvRadius.cardAll,
      child: BvListGroup(
        rows: [
          for (final r in ReportReason.values)
            BvListRow(
              key: Key('report-reason-${r.json}'),
              title: reasonTitle(l10n, r),
              subtitle: _reasonHelp(l10n, r),
              onTap: () => Navigator.of(sheet).pop(r),
            ),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;

  String? note;
  if (reason == ReportReason.other) {
    note = await showBvSheet<String>(
      context: context,
      title: l10n.reportNoteTitle,
      builder: (sheet) => const _NoteSheet(),
    );
    if (note == null || !context.mounted) return;
  }

  try {
    await container
        .read(safetyRepositoryProvider)
        .report(kind, id, reason, note: note);
  } on SpaceException catch (e) {
    if (context.mounted) showSpaceError(context, e);
    return;
  }
  if (!context.mounted) {
    onReported?.call();
    return;
  }

  final offerBlock =
      person != null && (kind == ReportKind.post || kind == ReportKind.profile);
  final block = await showBvSheet<bool>(
    context: context,
    builder: (sheet) => _SentSheet(
      offerBlock: offerBlock,
      onDone: () => Navigator.of(sheet).pop(false),
      onBlock: () => Navigator.of(sheet).pop(true),
    ),
  );
  if (block == true && person != null && context.mounted) {
    await confirmBlock(
      context,
      personId: person.id,
      name: person.name,
      onChanged: (_) => onBlocked?.call(),
    );
  }
  onReported?.call();
}

/// The block dialog, then "{name} blocked" with Undo. [onChanged] runs
/// after each change, with true when blocked.
Future<void> confirmBlock(
  BuildContext context, {
  required String personId,
  required String name,
  void Function(bool blocked)? onChanged,
}) async {
  final l10n = AppLocalizations.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final shown = inOwnDirection(name);
  final yes = await showBvDialog(
    context: context,
    title: l10n.blockConfirmTitle(shown),
    body: l10n.blockConfirmBody,
    cancelLabel: l10n.commonCancel,
    confirmLabel: l10n.block,
    destructive: true,
  );
  if (!yes) return;
  final repo = container.read(safetyRepositoryProvider);
  try {
    await repo.block(personId, true);
  } on SpaceException catch (e) {
    if (context.mounted) showSpaceError(context, e);
    return;
  }
  container.invalidate(blockedProvider);
  onChanged?.call(true);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const Key('block-toast'),
        content: Text(l10n.blockDone(shown)),
        action: SnackBarAction(
          label: l10n.postUndo,
          onPressed: () async {
            await repo.block(personId, false);
            container.invalidate(blockedProvider);
            onChanged?.call(false);
          },
        ),
      ),
    );
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet();

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = _note.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s16,
      children: [
        BvTextField(
          key: const Key('report-note'),
          controller: _note,
          placeholder: l10n.reportNoteHint,
          maxLines: 3,
          maxLength: 500,
          onChanged: (_) => setState(() {}),
        ),
        BvButton(
          key: const Key('report-send'),
          label: l10n.reportSend,
          expand: true,
          onPressed: text.isEmpty
              ? null
              : () => Navigator.of(context).pop(text),
        ),
      ],
    );
  }
}

/// R2: a check, "Report sent", Done, and Block this account.
class _SentSheet extends StatelessWidget {
  const _SentSheet({
    required this.offerBlock,
    required this.onDone,
    required this.onBlock,
  });

  final bool offerBlock;
  final VoidCallback onDone;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Column(
      key: const Key('report-sent'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s12,
      children: [
        Center(
          child: Container(
            width: BvSize.avatarLg,
            height: BvSize.avatarLg,
            decoration: const BoxDecoration(
              color: BvColors.surfaceSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              BvIcons.check,
              size: BvSize.iconLg,
              color: BvColors.iconPrimary,
            ),
          ),
        ),
        Text(
          l10n.reportSentTitle,
          textAlign: TextAlign.center,
          style: type.headingMd,
        ),
        Text(
          l10n.reportSentBody,
          textAlign: TextAlign.center,
          style: type.bodySm.copyWith(color: BvColors.textSecondary),
        ),
        const SizedBox(height: BvSpace.s4),
        BvButton(
          key: const Key('report-done'),
          label: l10n.reportDone,
          expand: true,
          onPressed: onDone,
        ),
        if (offerBlock)
          BvButton(
            key: const Key('report-block'),
            label: l10n.reportBlock,
            style: BvButtonStyle.secondary,
            expand: true,
            onPressed: onBlock,
          ),
      ],
    );
  }
}
