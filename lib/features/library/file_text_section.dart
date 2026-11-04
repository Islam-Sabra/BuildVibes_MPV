import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart' show directionOf;
import '../../data/repositories/file_text_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../spaces/space_errors.dart' show showSpaceMessage;

/// Review 103, OCR: Extract text («استخرج النص») under a file. Only on a
/// tap: the file goes to Google Cloud Vision through the extract-text
/// function. Its text then shows here in a Text section that folds, with
/// Copy, and is found by search. A failure says "Couldn't read this file";
/// past 50 pages a day, so. Over 10 MB it says so, with Make it smaller
/// when [onMakeSmaller] is given (the lead's check, D7). A file over 20
/// pages says "First 20 pages" (D3).
/// D25: whether a file shows a Text section: Extract text is on, or a text
/// was already kept. Otherwise nothing, not even its space.
bool showsFileText(WidgetRef ref, FileTextKind kind, String file) =>
    ref.watch(ocrAvailableProvider).value == true ||
    ref.watch(fileTextProvider((kind: kind, ref: file))).value != null;

class FileTextSection extends ConsumerStatefulWidget {
  const FileTextSection({
    super.key,
    required this.kind,
    required this.ref,
    this.onMakeSmaller,
  });

  final FileTextKind kind;

  /// A Library file's id, or a note file's storage path.
  final String ref;

  /// Makes the file smaller (a new version); none, no button.
  final Future<void> Function()? onMakeSmaller;

  @override
  ConsumerState<FileTextSection> createState() => _FileTextSectionState();
}

class _FileTextSectionState extends ConsumerState<FileTextSection> {
  var _reading = false;
  var _open = true;
  FileTextFailure? _failed;

  ({FileTextKind kind, String ref}) get _file =>
      (kind: widget.kind, ref: widget.ref);

  Future<void> _extract() async {
    setState(() {
      _reading = true;
      _failed = null;
    });
    try {
      await ref
          .read(fileTextRepositoryProvider)
          .extract(widget.kind, widget.ref);
      ref.invalidate(fileTextProvider(_file));
      await ref.read(fileTextProvider(_file).future);
    } on FileTextException catch (e) {
      if (mounted) setState(() => _failed = e.failure);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showSpaceMessage(context, AppLocalizations.of(context).fileTextCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final quiet = type.bodySm.copyWith(color: BvColors.textSecondary);
    final kept = ref.watch(fileTextProvider(_file)).value;
    if (kept == null && ref.watch(ocrAvailableProvider).value != true) {
      return const SizedBox.shrink();
    }
    if (kept == null) {
      return Column(
        key: const Key('file-text'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s8,
        children: [
          BvButton(
            key: const Key('file-extract-text'),
            label: _reading ? l10n.fileTextReading : l10n.fileExtractText,
            icon: BvIcons.textBlock,
            style: BvButtonStyle.secondary,
            expand: true,
            onPressed: _reading ? null : () => unawaited(_extract()),
          ),
          if (_failed case final failed?)
            Text(
              switch (failed) {
                FileTextFailure.dailyLimit => l10n.fileTextLimit,
                FileTextFailure.tooLarge => l10n.fileTextTooLarge,
                FileTextFailure.failed => l10n.fileTextFailed,
              },
              key: const Key('file-text-failed'),
              style: type.bodySm.copyWith(color: BvColors.textDestructive),
            ),
          if (_failed == FileTextFailure.tooLarge)
            if (widget.onMakeSmaller case final smaller?)
              BvButton(
                key: const Key('file-text-smaller'),
                label: l10n.pdfSmaller,
                style: BvButtonStyle.secondary,
                expand: true,
                onPressed: () => unawaited(smaller()),
              ),
        ],
      );
    }
    final text = kept.text.trim();
    return Column(
      key: const Key('file-text'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                key: const Key('file-text-toggle'),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: BvSpace.s8,
                  ),
                  child: Row(
                    spacing: BvSpace.s8,
                    children: [
                      Icon(
                        _open ? BvIcons.caretDown : BvIcons.caretForward,
                        size: BvSize.iconSm,
                        color: BvColors.iconSecondary,
                      ),
                      Text(l10n.fileTextTitle, style: type.labelMd),
                      if (kept.partial)
                        Flexible(
                          child: Text(
                            l10n.fileTextPartial,
                            key: const Key('file-text-partial'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: quiet,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (text.isNotEmpty)
              BvButton(
                key: const Key('file-text-copy'),
                label: l10n.fileTextCopy,
                icon: BvIcons.copy,
                style: BvButtonStyle.tertiary,
                size: BvButtonSize.medium,
                onPressed: () => unawaited(_copy(text)),
              ),
          ],
        ),
        if (_open)
          text.isEmpty
              ? Text(l10n.fileTextEmpty, style: quiet)
              : SelectableText(
                  text,
                  textDirection: directionOf(text),
                  style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                ),
      ],
    );
  }
}
