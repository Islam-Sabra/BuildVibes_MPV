import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart' show SpaceDetail;
import '../../data/models/upload_rules.dart';
import '../../data/repositories/space_repository.dart' show spaceDetailProvider;
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../library/library_folders.dart' show showFolderSheet;
import '../library/library_parts.dart' show fileSize;
import '../work/could_not_send.dart' show fileRefusedText;
import 'scan.dart' show scanDirProvider;

/// Review 103: Make it smaller is offered on a PDF this big or bigger;
/// under it there's nothing to gain.
const pdfSmallerFrom = 1024 * 1024;

/// Each page drawn again at this many dots per inch, as a JPEG of
/// [pdfSmallerQuality]: drawings stay readable.
const pdfSmallerDpi = 150;
const pdfSmallerQuality = 75;

/// A smaller copy: [bytes] long, [pages] pages.
typedef ShrunkPdf = ({int bytes, int pages});

/// The lead's check, D14: [page] of [total] is done.
typedef PdfPageDone = void Function(int page, int total);

/// Makes [input] ([inBytes] long) smaller at [out]; null when the phone
/// can't read it. The original is never touched. [onPage] after each page.
typedef PdfShrinker =
    Future<ShrunkPdf?> Function({
      required String input,
      required String out,
      required int inBytes,
      PdfPageDone? onPage,
    });

/// Tests stand in for the phone's PDF renderer.
final pdfShrinkerProvider = Provider<PdfShrinker>((ref) => shrinkPdf);

/// Review 103: every page drawn by the phone's own PDF renderer at
/// [pdfSmallerDpi] as a JPEG, then one new PDF of them, each page its
/// size. All on the phone, with no outside service.
Future<ShrunkPdf?> shrinkPdf({
  required String input,
  required String out,
  required int inBytes,
  PdfPageDone? onPage,
}) async {
  final pdfx.PdfDocument source;
  try {
    source = await pdfx.PdfDocument.openFile(input);
  } on Object {
    return null;
  }
  final doc = pw.Document(compress: true);
  try {
    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      try {
        const scale = pdfSmallerDpi / 72;
        final image = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: pdfSmallerQuality,
        );
        if (image == null) return null;
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            build: (_) =>
                pw.Image(pw.MemoryImage(image.bytes), fit: pw.BoxFit.fill),
          ),
        );
      } finally {
        await page.close();
      }
      onPage?.call(i, source.pagesCount);
    }
  } on Object {
    return null;
  } finally {
    await source.close();
  }
  final bytes = await doc.save();
  await File(out).writeAsBytes(bytes, flush: true);
  return (bytes: bytes.length, pages: source.pagesCount);
}

/// Whether Make it smaller is offered on [file]: a PDF still on the
/// phone, [pdfSmallerFrom] or bigger.
bool offersSmaller(String? local, String mime, int? bytes) =>
    local != null &&
    mime == 'application/pdf' &&
    (bytes ?? 0) >= pdfSmallerFrom;

/// Make it smaller: compressed on the phone, then before → after with the
/// warning line, and Use smaller · Keep original. The smaller copy, or
/// null to keep the original.
Future<PhoneFile?> makeSmaller(
  BuildContext context,
  WidgetRef ref,
  PhoneFile file,
) async {
  final made = await _shrink(context, ref, file);
  if (!context.mounted) return null;
  final l10n = AppLocalizations.of(context);
  // The lead's check, D13: a copy that isn't smaller is no use.
  if (made == null || (made.bytes ?? 0) >= (file.bytes ?? 0)) {
    if (made != null) _drop(made.local);
    await _notSmaller(context);
    return null;
  }
  final use = await showBvSheet<bool>(
    context: context,
    title: l10n.pdfSmallerTitle,
    builder: (sheet) => _Result(
      before: file.bytes ?? 0,
      after: made.bytes ?? 0,
      onUse: () => Navigator.of(sheet).pop(true),
      onKeep: () => Navigator.of(sheet).pop(false),
    ),
  );
  if (use != true) {
    _drop(made.local);
    return null;
  }
  return made;
}

/// Review 103: where a file goes at once (the Library), the offer is a
/// question before it goes: "9.1 MB" with Make it smaller · Keep original.
/// The file to send: the smaller copy, or [file] as it was.
Future<PhoneFile> offerSmaller(
  BuildContext context,
  WidgetRef ref,
  PhoneFile file,
) async {
  if (!offersSmaller(file.local, file.mime, file.bytes)) return file;
  final l10n = AppLocalizations.of(context);
  final smaller = await showBvSheet<bool>(
    context: context,
    title: l10n.pdfSmallerTitle,
    builder: (sheet) {
      final type = BvType.of(sheet);
      return Column(
        key: const Key('pdf-offer'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          Text(
            '${file.name} · ${fileSize(l10n, file.bytes)}',
            style: type.bodyMd.copyWith(color: BvColors.textPrimary),
          ),
          Row(
            spacing: BvSpace.s12,
            children: [
              Expanded(
                child: BvButton(
                  key: const Key('pdf-offer-keep'),
                  label: l10n.pdfKeepOriginal,
                  style: BvButtonStyle.secondary,
                  expand: true,
                  onPressed: () => Navigator.of(sheet).pop(false),
                ),
              ),
              Expanded(
                child: BvButton(
                  key: const Key('pdf-offer-smaller'),
                  label: l10n.pdfSmaller,
                  expand: true,
                  onPressed: () => Navigator.of(sheet).pop(true),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  if (smaller != true || !context.mounted) return file;
  return await makeSmaller(context, ref, file) ?? file;
}

/// Review 103: a PDF over [maxBytes] ("too large"): Make it smaller
/// first, Link folder beside it ([spaceId]'s, for who may add files).
/// Smaller and under the limit, Use smaller gives the copy; still over
/// it, "Still too large" with Link folder only. Null: nothing goes.
Future<PhoneFile?> fitTooLarge(
  BuildContext context,
  WidgetRef ref, {
  required PhoneFile file,
  required int maxBytes,
  String? spaceId,
}) async {
  final l10n = AppLocalizations.of(context);
  final space = spaceId == null
      ? null
      : ref.read(spaceDetailProvider(spaceId)).value;
  final link = space != null && space.myRights.addFiles;
  final refused = FileRefused(UploadProblem.tooBig, bytes: file.bytes);
  final choice = await showBvSheet<_TooLarge>(
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
          BvButton(
            key: const Key('file-refused-smaller'),
            label: l10n.pdfSmaller,
            expand: true,
            onPressed: () => Navigator.of(sheet).pop(_TooLarge.smaller),
          ),
          if (link)
            BvButton(
              key: const Key('file-refused-link-folder'),
              label: l10n.libraryLinkFolder,
              icon: BvIcons.link,
              style: BvButtonStyle.secondary,
              expand: true,
              onPressed: () => Navigator.of(sheet).pop(_TooLarge.link),
            ),
        ],
      );
    },
  );
  if (!context.mounted || choice == null) return null;
  if (choice == _TooLarge.link) {
    await _link(context, ref, space);
    return null;
  }
  final made = await _shrink(context, ref, file);
  if (!context.mounted) return null;
  if (made == null) {
    await _notSmaller(context);
    return null;
  }
  if ((made.bytes ?? 0) > maxBytes) {
    _drop(made.local);
    final again = await showBvSheet<bool>(
      context: context,
      title: l10n.couldNotSendTitle,
      builder: (sheet) => Column(
        key: const Key('file-still-too-large'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          Text(
            l10n.pdfStillTooLarge(
              _wholeMb(made.bytes ?? 0),
              _wholeMb(maxBytes),
            ),
            style: BvType.of(
              sheet,
            ).bodyMd.copyWith(color: BvColors.textPrimary),
          ),
          if (link)
            BvButton(
              key: const Key('file-still-link-folder'),
              label: l10n.libraryLinkFolder,
              icon: BvIcons.link,
              expand: true,
              onPressed: () => Navigator.of(sheet).pop(true),
            ),
        ],
      ),
    );
    if (again == true && context.mounted) await _link(context, ref, space);
    return null;
  }
  final use = await showBvSheet<bool>(
    context: context,
    title: l10n.pdfSmallerTitle,
    builder: (sheet) => _Result(
      before: file.bytes ?? 0,
      after: made.bytes ?? 0,
      onUse: () => Navigator.of(sheet).pop(true),
    ),
  );
  if (use != true) {
    _drop(made.local);
    return null;
  }
  return made;
}

enum _TooLarge { smaller, link }

/// The lead's check, D15: rounded up, so 25.4 MB is never "25 MB" beside
/// a limit of 25.
String _wholeMb(int bytes) => (bytes / (1024 * 1024)).ceil().toString();

/// Link folder, as the "too large" sheet always offered it.
Future<void> _link(
  BuildContext context,
  WidgetRef ref,
  SpaceDetail? space,
) async {
  if (space == null || !context.mounted) return;
  await showFolderSheet(context, ref, space: space, link: true);
}

/// The smaller copy, made on the phone while a sheet says how far it is
/// (the lead's check, D14: "Making it smaller… page 3 of 12").
Future<PhoneFile?> _shrink(
  BuildContext context,
  WidgetRef ref,
  PhoneFile file,
) async {
  final shrinker = ref.read(pdfShrinkerProvider);
  final dir = await ref.read(scanDirProvider)();
  final out = '$dir/${newUuid()}.pdf';
  final inBytes = file.bytes ?? await File(file.local).length();
  if (!context.mounted) return null;
  final done = ValueNotifier<(int, int)?>(null);
  final sheet = Navigator.of(context, rootNavigator: true);
  unawaited(
    showBvSheet<void>(
      context: context,
      title: AppLocalizations.of(context).pdfSmallerTitle,
      builder: (sheet) => PopScope(canPop: false, child: _Making(done: done)),
    ),
  );
  final ShrunkPdf? made;
  try {
    made = await shrinker(
      input: file.local,
      out: out,
      inBytes: inBytes,
      onPage: (page, total) => done.value = (page, total),
    );
  } finally {
    sheet.pop();
    done.dispose();
  }
  if (made == null) return null;
  return PhoneFile(
    local: out,
    name: file.name,
    mime: file.mime,
    bytes: made.bytes,
  );
}

void _drop(String path) {
  try {
    File(path).deleteSync();
  } on FileSystemException {
    // Already gone.
  }
}

/// The lead's check, D13: "This PDF couldn't be made smaller.", and only
/// Keep original.
Future<void> _notSmaller(BuildContext context) => showBvSheet<void>(
  context: context,
  builder: (sheet) {
    final l10n = AppLocalizations.of(sheet);
    return Column(
      key: const Key('pdf-not-smaller'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s12,
      children: [
        Text(
          l10n.pdfSmallerFailed,
          style: BvType.of(sheet).bodyMd.copyWith(color: BvColors.textPrimary),
        ),
        BvButton(
          key: const Key('pdf-keep-original'),
          label: l10n.pdfKeepOriginal,
          style: BvButtonStyle.secondary,
          expand: true,
          onPressed: () => Navigator.of(sheet).pop(),
        ),
      ],
    );
  },
);

/// "Making it smaller… page 3 of 12", with a bar, while the phone works.
class _Making extends StatelessWidget {
  const _Making({required this.done});

  final ValueNotifier<(int, int)?> done;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return ValueListenableBuilder(
      valueListenable: done,
      builder: (context, done, _) => Column(
        key: const Key('pdf-making'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          if (done case (final page, final total))
            Text(
              l10n.pdfSmallerMaking(page, total),
              style: type.bodyMd.copyWith(color: BvColors.textPrimary),
            ),
          LinearProgressIndicator(
            value: done == null ? null : done.$1 / done.$2,
            color: BvColors.iconAction,
            backgroundColor: BvColors.surfaceBrandSoft,
          ),
        ],
      ),
    );
  }
}

/// "9.1 MB → 2.3 MB", the warning line, then Use smaller (and Keep
/// original when there is one to keep).
class _Result extends StatelessWidget {
  const _Result({
    required this.before,
    required this.after,
    required this.onUse,
    this.onKeep,
  });

  final int before;
  final int after;
  final VoidCallback onUse;
  final VoidCallback? onKeep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Column(
      key: const Key('pdf-smaller'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s12,
      children: [
        Text(
          l10n.pdfSmallerResult(fileSize(l10n, before), fileSize(l10n, after)),
          style: type.titleMd.copyWith(color: BvColors.textPrimary),
        ),
        Text(
          l10n.pdfSmallerWarning,
          style: type.bodySm.copyWith(color: BvColors.textSecondary),
        ),
        Row(
          spacing: BvSpace.s12,
          children: [
            if (onKeep case final keep?)
              Expanded(
                child: BvButton(
                  key: const Key('pdf-keep-original'),
                  label: l10n.pdfKeepOriginal,
                  style: BvButtonStyle.secondary,
                  expand: true,
                  onPressed: keep,
                ),
              ),
            Expanded(
              child: BvButton(
                key: const Key('pdf-use-smaller'),
                label: l10n.pdfUseSmaller,
                expand: true,
                onPressed: onUse,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
