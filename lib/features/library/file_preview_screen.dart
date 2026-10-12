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
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../chat/chat_tab.dart' show threadName;
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_errors.dart';
import 'library_parts.dart';

/// F1 · Drawing preview, on the dark sheet of a drawing table: the file
/// (a PDF with pinch-zoom, or a photo), its revision, note, the items that
/// use it and its older revisions. Share in chat, Download, and Upload a
/// new revision for people who may add files.
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
    final space = ref.watch(spaceDetailProvider(spaceId)).value;

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
                  if (f.uploadedByName != null)
                    l10n.previewFrom(f.uploadedByName!),
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
            _InfoCard(
              spaceId: spaceId,
              detail: d,
              day: day,
              canAdd: space?.myRights.addFiles ?? false,
            ),
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
                    onPressed: () => _shareInChat(context, ref, f),
                  ),
                ),
                Expanded(
                  child: BvButton(
                    key: const Key('preview-download'),
                    label: l10n.previewDownload,
                    expand: true,
                    onPressed: () => _download(context, ref, f),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String text) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _download(
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

  /// A Team's file goes only to that Team's thread; an Everyone file to
  /// any thread you see.
  Future<void> _shareInChat(
    BuildContext context,
    WidgetRef ref,
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
    try {
      await ref
          .read(chatRepositoryProvider)
          .shareFile(id: newUuid(), threadId: picked, fileId: f.id);
      ref.invalidate(spaceThreadsProvider(spaceId));
      if (context.mounted) {
        final t = threads.firstWhere((t) => t.id == picked);
        _toast(context, l10n.previewShared(threadName(l10n, t)));
      }
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
    final url = ref.watch(fileUrlProvider(file.path));
    final Widget child;
    if (url.hasError) {
      child = Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.s16),
          child: EmptyNote(l10n.previewCantShow),
        ),
      );
    } else if (!url.hasValue) {
      child = const Center(child: CircularProgressIndicator());
    } else if (file.isPdf) {
      child = _PdfSheet(path: file.path);
    } else {
      child = InteractiveViewer(
        key: const Key('preview-image'),
        maxScale: BvPreviewSpec.maxZoom,
        child: Image.network(
          url.value!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) =>
              Center(child: EmptyNote(l10n.previewCantShow)),
        ),
      );
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
    required this.canAdd,
  });

  final String spaceId;
  final LibraryFileDetail detail;
  final String Function(DateTime) day;
  final bool canAdd;

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
          Row(
            children: [
              if (detail.isCurrent)
                BvStamp(key: const Key('preview-current'), label: stamp)
              else
                BvStamp(
                  label: f.revLabel ?? l10n.libraryFiles,
                  tone: BvStampTone.muted,
                ),
              const Spacer(),
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
                    onTap: () =>
                        context.push(AppRoutes.workItem(spaceId, u.itemId)),
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
          if (canAdd && detail.isCurrent)
            BvButton(
              key: const Key('preview-new-revision'),
              label: l10n.previewNewRevision,
              icon: BvIcons.upload,
              style: BvButtonStyle.tertiary,
              size: BvButtonSize.medium,
              padded: false,
              onPressed: () async {
                await context.push(
                  AppRoutes.libraryAdd(spaceId, supersedes: f.id),
                );
              },
            ),
        ],
      ),
    );
  }
}
