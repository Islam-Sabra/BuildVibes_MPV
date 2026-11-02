import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/models/upload_rules.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../library/library_folders.dart' show showFolderSheet;

/// Review 113, bug 7: "Couldn't send · Tap to fix" is never a dead end. A
/// tap opens what is wrong, in plain words, with Try again and Remove;
/// for a file too big for a Space, Link folder for big drawings.

/// "This file is 38 MB. The most is 25 MB.", or the type line.
String fileRefusedText(AppLocalizations l10n, FileRefused r) =>
    switch (r.problem) {
      UploadProblem.tooBig => l10n.fileTooBigLine(
        '${r.megabytes ?? spaceFilesMaxMegabytes + 1}',
        '$spaceFilesMaxMegabytes',
      ),
      UploadProblem.wrongType => l10n.fileWrongTypeLine,
      UploadProblem.notPdfOrPhoto => l10n.fileNotPdfOrPhotoLine,
    };

/// The bucket's limit in whole megabytes (25).
const spaceFilesMaxMegabytes = spaceFilesMaxBytes ~/ (1024 * 1024);

/// What Tap to fix chose.
enum CouldNotSendFix { tryAgain, remove, linkFolder }

/// The sheet: what is wrong ([why]), then Remove and Try again. A file
/// too big ([refused]) also offers Link folder ([linkFolder]).
Future<CouldNotSendFix?> showCouldNotSendFix(
  BuildContext context, {
  required String why,
  FileRefused? refused,
  bool tryAgain = true,
  bool linkFolder = false,
}) {
  final l10n = AppLocalizations.of(context);
  final big = refused?.problem == UploadProblem.tooBig && linkFolder;
  return showBvSheet<CouldNotSendFix>(
    context: context,
    title: l10n.couldNotSendTitle,
    builder: (sheet) {
      final type = BvType.of(sheet);
      return Column(
        key: const Key('could-not-send-fix'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          Text(
            why,
            key: const Key('could-not-send-why'),
            style: type.bodyMd.copyWith(color: BvColors.textPrimary),
          ),
          if (big) ...[
            Text(
              l10n.fileBigDrawingsHint,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
            BvButton(
              key: const Key('could-not-send-link-folder'),
              label: l10n.libraryLinkFolder,
              icon: BvIcons.link,
              style: BvButtonStyle.secondary,
              expand: true,
              onPressed: () =>
                  Navigator.of(sheet).pop(CouldNotSendFix.linkFolder),
            ),
          ],
          Row(
            spacing: BvSpace.s12,
            children: [
              Expanded(
                child: BvButton(
                  key: const Key('could-not-send-remove'),
                  label: l10n.couldNotSendRemove,
                  style: BvButtonStyle.secondary,
                  expand: true,
                  onPressed: () =>
                      Navigator.of(sheet).pop(CouldNotSendFix.remove),
                ),
              ),
              Expanded(
                child: BvButton(
                  key: const Key('could-not-send-try-again'),
                  label: l10n.commonRetry,
                  expand: true,
                  onPressed: tryAgain
                      ? () => Navigator.of(sheet).pop(CouldNotSendFix.tryAgain)
                      : null,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// The composer's red line: [text] ("Couldn't send. Tap to fix", or the
/// server's own reason), a tap away from [onTap].
class CouldNotSendLine extends StatelessWidget {
  const CouldNotSendLine({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      key: const Key('writing-could-not-send'),
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s4),
        child: Text(
          text,
          style: BvType.of(
            context,
          ).metadata.copyWith(color: BvColors.textDestructive),
        ),
      ),
    ),
  );
}

/// Runs the fix [picked] chose: [tryAgain] sends again, [remove] takes off
/// the refused file (or the post), [linkFolder] opens Link folder.
void runCouldNotSendFix(
  CouldNotSendFix? picked, {
  required VoidCallback? tryAgain,
  required Future<void> Function() remove,
  VoidCallback? linkFolder,
}) {
  switch (picked) {
    case CouldNotSendFix.tryAgain:
      tryAgain?.call();
    case CouldNotSendFix.remove:
      unawaited(remove());
    case CouldNotSendFix.linkFolder:
      linkFolder?.call();
    case null:
      break;
  }
}

/// A file refused before it goes (picked on the phone): the plain line,
/// and for a file too big, Link folder for big drawings ([spaceId]'s,
/// for who may add files).
Future<void> showFileRefused(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  required FileRefused refused,
}) async {
  final l10n = AppLocalizations.of(context);
  final space = ref.read(spaceDetailProvider(spaceId)).value;
  final offerLink =
      refused.problem == UploadProblem.tooBig &&
      space != null &&
      space.myRights.addFiles;
  final link = await showBvSheet<bool>(
    context: context,
    title: l10n.couldNotSendTitle,
    builder: (sheet) {
      final type = BvType.of(sheet);
      return Column(
        key: const Key('file-refused'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          Text(
            fileRefusedText(l10n, refused),
            key: const Key('file-refused-why'),
            style: type.bodyMd.copyWith(color: BvColors.textPrimary),
          ),
          if (offerLink) ...[
            Text(
              l10n.fileBigDrawingsHint,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
            BvButton(
              key: const Key('file-refused-link-folder'),
              label: l10n.libraryLinkFolder,
              icon: BvIcons.link,
              style: BvButtonStyle.secondary,
              expand: true,
              onPressed: () => Navigator.of(sheet).pop(true),
            ),
          ],
          BvButton(
            key: const Key('file-refused-ok'),
            label: l10n.commonOk,
            expand: true,
            onPressed: () => Navigator.of(sheet).pop(false),
          ),
        ],
      );
    },
  );
  if (link != true || !context.mounted || space == null) return;
  await showFolderSheet(context, ref, space: space, link: true);
}
