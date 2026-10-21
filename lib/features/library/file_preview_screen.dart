import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdfx/pdfx.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../core/share.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/library_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_errors.dart';
import 'library_actions.dart';
import 'library_parts.dart';
import '../spaces/former_member.dart';

/// F1 · Drawing preview, on the dark sheet of a drawing table: the file
/// (a PDF with pinch-zoom, or a photo), its revision, note, the items that
/// use it and its older revisions. Share in chat and Download. A new
/// version is added on the file's page (LV2), always with its post.
class FilePreviewScreen extends ConsumerWidget {
  const FilePreviewScreen({
    super.key,
    required this.spaceId,
    required this.fileId,
  });

  final String spaceId;
  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final detail = ref.watch(libraryFileProvider(fileId));
    final d = detail.value;

    if (d == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: detail.isLoading
              ? const Center(child: CircularProgressIndicator())
              : EmptyNote(l10n.errorGeneric),
        ),
      );
    }
    final f = d.file;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String day(DateTime t) => BvWesternDigitsFormatter.normalise(
      DateFormat('d MMM', locale).format(t.toLocal()),
    );
    const muted = TextStyle(color: BvColors.textInverse);

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: BvColors.brandInk,
        appBarTheme: Theme.of(context).appBarTheme.copyWith(
          backgroundColor: BvColors.brandInk,
          foregroundColor: BvColors.textInverse,
          iconTheme: const IconThemeData(color: BvColors.iconInverse),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('preview-close'),
            tooltip: l10n.previewClose,
            icon: const Icon(BvIcons.close, color: BvColors.iconInverse),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                inOwnDirection(f.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.titleMd.copyWith(color: BvColors.textInverse),
              ),
              Text(
                joinMeta([
                  ?f.revLabel,
                  if (f.isPdf) 'PDF',
                  fileSize(l10n, f.bytes),
                  l10n.previewFrom(
                    inOwnDirection(personName(l10n, f.uploadedByName)),
                  ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodySm.merge(muted),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('preview-share-file'),
              tooltip: l10n.previewSendFile,
              icon: const Icon(BvIcons.shareFile, color: BvColors.iconInverse),
              onPressed: () => _shareOut(context, ref, f),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          children: [
            _Sheet(file: f),
            const SizedBox(height: BvSpace.s16),
            _InfoCard(spaceId: spaceId, detail: d, day: day),
            const SizedBox(height: BvSpace.s16),
            Row(
              spacing: BvSpace.s12,
              children: [
                Expanded(
                  child: BvButton(
                    key: const Key('preview-share'),
                    label: l10n.previewShare,
                    style: BvButtonStyle.secondary,
                    expand: true,
                    onPressed: () =>
                        shareLibraryFileInChat(context, ref, spaceId, f),
                  ),
                ),
                Expanded(
                  child: BvButton(
                    key: const Key('preview-download'),
                    label: l10n.previewDownload,
                    expand: true,
                    onPressed: () => downloadLibraryFile(context, ref, f),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareOut(
    BuildContext context,
    WidgetRef ref,
    LibraryFile f,
  ) async {
    try {
      final bytes = await ref.read(libraryRepositoryProvider).download(f.path);
      await ref.read(shareFileProvider)(f.name, f.mime, bytes);
    } on SpaceException catch (e) {
      if (context.mounted) showSpaceError(context, e);
    }
  }
}

/// The drawing itself, on a white sheet: pinch to zoom.
class _Sheet extends ConsumerWidget {
  const _Sheet({required this.file});

  final LibraryFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final Widget child;
    // A photo needs no link: it is drawn from its bytes (review 61 G4).
    final url = file.isPdf ? ref.watch(fileUrlProvider(file.path)) : null;
    if (url == null) {
      child = _PhotoSheet(path: file.path);
    } else if (url.hasError) {
      child = Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.s16),
          child: EmptyNote(l10n.previewCantShow),
        ),
      );
    } else if (!url.hasValue) {
      child = const Center(child: CircularProgressIndicator());
    } else {
      child = _PdfSheet(path: file.path);
    }
    return ClipRRect(
      borderRadius: BvRadius.controlAll,
      child: ColoredBox(
        color: BvColors.surfaceElevated,
        child: AspectRatio(
          aspectRatio: BvPreviewSpec.sheetAspect,
          child: child,
        ),
      ),
    );
  }
}

/// A photo or a model view (review 61 G4), drawn from its bytes, read with
/// the person's own session as the PDF sheet reads a PDF, so the sheet
/// never waits on a link with nothing shown; a spinner while it loads, and
/// "can't show" if it can't be read or drawn. Pinch to zoom.
class _PhotoSheet extends ConsumerWidget {
  const _PhotoSheet({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cantShow = Center(child: EmptyNote(l10n.previewCantShow));
    return switch (ref.watch(fileBytesProvider(path))) {
      AsyncData(:final value) => InteractiveViewer(
        key: const Key('preview-image'),
        maxScale: BvPreviewSpec.maxZoom,
        child: Image(
          image: MemoryImage(value),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => cantShow,
        ),
      ),
      AsyncError() => cantShow,
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// A PDF, opened from its bytes by the phone's own PDF renderer; pinch to
/// zoom, scroll for more sheets.
class _PdfSheet extends ConsumerStatefulWidget {
  const _PdfSheet({required this.path});

  final String path;

  @override
  ConsumerState<_PdfSheet> createState() => _PdfSheetState();
}

class _PdfSheetState extends ConsumerState<_PdfSheet> {
  late final _controller = PdfControllerPinch(
    document: PdfDocument.openData(
      ref.read(libraryRepositoryProvider).download(widget.path),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PdfViewPinch(
      key: const Key('preview-pdf'),
      controller: _controller,
      maxScale: BvPreviewSpec.maxZoom,
      backgroundDecoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
      ),
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) =>
            Center(child: EmptyNote(l10n.previewCantShow)),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.spaceId,
    required this.detail,
    required this.day,
  });

  final String spaceId;
  final LibraryFileDetail detail;
  final String Function(DateTime) day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final f = detail.file;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final stamp = f.revLabel == null
        ? l10n.previewCurrentNoRev
        : l10n.previewCurrent(ar ? f.revLabel! : f.revLabel!.toUpperCase());

    return Container(
      padding: const EdgeInsetsDirectional.all(BvSpace.s16),
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s8,
        children: [
          // Stamp at the start, upload date at the end; on a narrow phone
          // the date goes under the stamp.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: BvSpace.s8,
            runSpacing: BvSpace.s4,
            children: [
              if (detail.isCurrent)
                BvStamp(key: const Key('preview-current'), label: stamp)
              else
                BvStamp(
                  label: f.revLabel ?? l10n.libraryFiles,
                  tone: BvStampTone.muted,
                ),
              Text(
                l10n.previewUploaded(day(f.createdAt)),
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              ),
            ],
          ),
          if (!detail.isCurrent)
            Wrap(
              spacing: BvSpace.s8,
              children: [
                Text(l10n.previewReplaced, style: type.bodySm),
                GestureDetector(
                  key: const Key('preview-open-current'),
                  onTap: () => context.pushReplacement(
                    AppRoutes.libraryFile(spaceId, detail.supersededById!),
                  ),
                  child: Text(
                    l10n.previewOpenCurrent,
                    style: type.labelSm.copyWith(color: BvColors.textAction),
                  ),
                ),
              ],
            ),
          if ((f.note ?? '').isNotEmpty)
            Text(
              f.note!,
              textDirection: directionOf(f.note!),
              style: type.bodyMd,
            ),
          if (detail.usedIn.isNotEmpty)
            Wrap(
              spacing: BvSpace.s8,
              runSpacing: BvSpace.s4,
              children: [
                Text(
                  l10n.previewUsedIn,
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
                for (final u in detail.usedIn)
                  GestureDetector(
                    key: Key('preview-used-${u.itemId}'),
                    // On the Space's daybook, where the work item lives.
                    onTap: () => context.push(AppRoutes.space(spaceId)),
                    child: Text(
                      joinMeta([u.ref, u.title]),
                      style: type.bodySm.copyWith(color: BvColors.textAction),
                    ),
                  ),
              ],
            ),
          for (final o in detail.older)
            GestureDetector(
              key: Key('preview-older-${o.id}'),
              onTap: () => context.push(AppRoutes.libraryFile(spaceId, o.id)),
              child: Text(
                joinMeta([
                  ?o.revLabel,
                  day(o.createdAt),
                  l10n.previewSuperseded,
                ]),
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
            ),
          // A model view's versions come only from BuildVibes 360: the
          // server refuses an upload (review 59 L2, review 61 G4). Other
          // files get a new version on their page (LV2), with its post.
          if (f.source == LibrarySource.modelView)
            Text(
              l10n.previewModelViewVersions,
              key: const Key('preview-model-view-versions'),
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
