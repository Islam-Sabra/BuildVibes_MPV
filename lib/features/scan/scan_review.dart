import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/scan_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../library/library_parts.dart' show fileSize;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../work/daybook_words.dart';
import '../work/work_outbox.dart' show pickPhotoProvider;
import 'scan.dart';

/// A scan ready to add: one PDF on the phone ([local]), [pages] pages and
/// [bytes] long, its page 1 thumbnail ([thumb]) and the name it was given
/// (without ".pdf").
@immutable
class ScannedDocument {
  const ScannedDocument({
    required this.local,
    required this.name,
    required this.pages,
    required this.bytes,
    required this.thumb,
  });

  final String local;
  final String name;
  final int pages;
  final int bytes;
  final String thumb;

  String get fileName => '$name.pdf';
}

/// Review 103: Scan a document, from any place that takes one. The phone's
/// scanner gives the pages (or, on a phone without one, the app's camera
/// takes them one by one); the review sheet (SC3) makes them one PDF,
/// names it, and Add returns it. Null when nothing is added. A PDF over
/// [maxBytes] can't be added.
Future<ScannedDocument?> scanDocument(
  BuildContext context,
  WidgetRef ref, {
  required int maxBytes,
}) async {
  final scanner = ref.read(documentScannerProvider);
  final phone = await scanner.available();
  final pages = await scanPages(ref, phone: phone, room: scanPagesMax);
  if (pages.isEmpty || !context.mounted) return null;
  return Navigator.of(context, rootNavigator: true).push<ScannedDocument>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ScanReviewScreen(
        pages: pages,
        phoneScanner: phone,
        maxBytes: maxBytes,
      ),
    ),
  );
}

/// Pages from the phone's scanner, or one photo from the app's camera on a
/// phone without one; never more than [room].
Future<List<String>> scanPages(
  WidgetRef ref, {
  required bool phone,
  required int room,
}) async {
  if (room <= 0) return const [];
  if (phone) {
    final pages = await ref.read(documentScannerProvider).scan(maxPages: room);
    return (pages ?? const <String>[]).take(room).toList();
  }
  final picked = await ref.read(pickPhotoProvider)(camera: true);
  return [for (final p in picked.photos.take(1)) p.path];
}

/// SC3: after scanning. "Scanned document" and how many pages, the strip
/// of pages (a tap shows one full size, ✕ takes it off), Scan more pages,
/// the name, then ✕ Cancel (asked once) and Add.
class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({
    super.key,
    required this.pages,
    required this.phoneScanner,
    required this.maxBytes,
  });

  final List<String> pages;
  final bool phoneScanner;
  final int maxBytes;

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  late final List<String> _pages = List.of(widget.pages);
  final _name = TextEditingController();
  String? _out;
  String? _thumb;
  MadeScan? _made;

  /// Each change makes the PDF again; only the latest counts.
  int _making = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_out == null) {
      final l10n = AppLocalizations.of(context);
      final words = DaybookWords(
        l10n,
        Localizations.localeOf(context).toLanguageTag(),
        use24: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      _name.text = scanName(words, ref.read(clockProvider)());
      _out = '';
      unawaited(_make());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _make() async {
    final turn = ++_making;
    setState(() => _made = null);
    final dir = await ref.read(scanDirProvider)();
    final id = newUuid();
    final out = '$dir/$id.pdf';
    final thumb = scanThumbFor(out);
    final made = await ref.read(scanPdfBuilderProvider)(
      pages: _pages,
      out: out,
      thumbOut: thumb,
    );
    if (!mounted || turn != _making) {
      _drop(out, thumb);
      return;
    }
    if (_out case final old? when old.isNotEmpty) _drop(old, _thumb);
    setState(() {
      _out = out;
      _thumb = thumb;
      _made = made;
    });
  }

  static void _drop(String pdf, String? thumb) {
    for (final p in [pdf, ?thumb]) {
      try {
        File(p).deleteSync();
      } on FileSystemException {
        // Already gone.
      }
    }
  }

  Future<void> _more() async {
    final more = await scanPages(
      ref,
      phone: widget.phoneScanner,
      room: scanPagesMax - _pages.length,
    );
    if (more.isEmpty || !mounted) return;
    _pages.addAll(more);
    await _make();
  }

  Future<void> _remove(int i) async {
    _pages.removeAt(i);
    if (_pages.isEmpty) {
      _cancelled();
      return;
    }
    await _make();
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final yes = await showBvDialog(
      context: context,
      title: l10n.scanDiscardTitle,
      body: l10n.scanDiscardBody,
      cancelLabel: l10n.scanKeep,
      confirmLabel: l10n.scanDiscard,
      destructive: true,
    );
    if (yes && mounted) _cancelled();
  }

  void _cancelled() {
    if (_out case final out? when out.isNotEmpty) _drop(out, _thumb);
    Navigator.of(context).pop();
  }

  void _add() {
    final made = _made;
    final out = _out;
    if (made == null || out == null || out.isEmpty) return;
    final words = _name.text.trim();
    Navigator.of(context).pop(
      ScannedDocument(
        local: out,
        name: words.isEmpty ? _name.text : words,
        pages: made.pages,
        bytes: made.bytes,
        thumb: _thumb!,
      ),
    );
  }

  void _show(String page) => unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        key: const Key('scan-page-full'),
        backgroundColor: BvColors.textPrimary,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(child: Image.file(File(page))),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final made = _made;
    final tooLarge = made != null && made.bytes > widget.maxBytes;
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        key: const Key('scan-review'),
        backgroundColor: BvColors.surfaceApp,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s12,
              children: [
                Text(l10n.scanReviewTitle, style: type.titleLg),
                Row(
                  spacing: BvSpace.s8,
                  children: [
                    Text(
                      l10n.scanPages(_pages.length),
                      key: const Key('scan-count'),
                      style: quiet,
                    ),
                    if (made != null)
                      Text(
                        fileSize(l10n, made.bytes),
                        key: const Key('scan-size'),
                        style: quiet,
                      ),
                  ],
                ),
                SizedBox(
                  height: BvScanSpec.stripHeight,
                  child: ListView.separated(
                    key: const Key('scan-strip'),
                    scrollDirection: Axis.horizontal,
                    itemCount: _pages.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: BvSpace.s8),
                    itemBuilder: (context, i) => _Page(
                      key: Key('scan-page-$i'),
                      path: _pages[i],
                      removeKey: Key('scan-page-remove-$i'),
                      removeLabel: l10n.scanRemovePage,
                      onTap: () => _show(_pages[i]),
                      onRemove: () => unawaited(_remove(i)),
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BvButton(
                    key: const Key('scan-more'),
                    label: widget.phoneScanner
                        ? l10n.scanMorePages
                        : l10n.scanAddPage,
                    icon: widget.phoneScanner ? BvIcons.scan : BvIcons.camera,
                    style: BvButtonStyle.secondary,
                    size: BvButtonSize.medium,
                    onPressed: _pages.length < scanPagesMax
                        ? () => unawaited(_more())
                        : null,
                  ),
                ),
                if (!widget.phoneScanner)
                  Text(
                    l10n.scanNoScanner,
                    key: const Key('scan-no-scanner'),
                    style: quiet,
                  ),
                TextField(
                  key: const Key('scan-name'),
                  controller: _name,
                  style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                  decoration: InputDecoration(labelText: l10n.scanName),
                ),
                if (made == null)
                  Text(l10n.scanMaking, style: quiet)
                else if (tooLarge)
                  Text(
                    l10n.scanTooLarge,
                    key: const Key('scan-too-large'),
                    style: type.metadata.copyWith(
                      color: BvColors.textDestructive,
                    ),
                  ),
                const Spacer(),
                Row(
                  spacing: BvSpace.s12,
                  children: [
                    Expanded(
                      child: BvButton(
                        key: const Key('scan-cancel'),
                        label: l10n.commonCancel,
                        icon: BvIcons.close,
                        style: BvButtonStyle.secondary,
                        expand: true,
                        onPressed: () => unawaited(_cancel()),
                      ),
                    ),
                    Expanded(
                      child: BvButton(
                        key: const Key('scan-add'),
                        label: l10n.scanAdd,
                        icon: BvIcons.send,
                        expand: true,
                        onPressed: made == null || tooLarge ? null : _add,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One page in the strip: its photo, a tap to see it, ✕ to take it off.
class _Page extends StatelessWidget {
  const _Page({
    super.key,
    required this.path,
    required this.removeKey,
    required this.removeLabel,
    required this.onTap,
    required this.onRemove,
  });

  final String path;
  final Key removeKey;
  final String removeLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: BvScanSpec.pageWidth,
    child: Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BvRadius.control),
            child: ColoredBox(
              color: BvColors.surfaceElevated,
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: IconButton(
            key: removeKey,
            tooltip: removeLabel,
            icon: const Icon(
              BvIcons.close,
              size: BvSize.iconSm,
              color: BvColors.iconPrimary,
            ),
            onPressed: onRemove,
          ),
        ),
      ],
    ),
  );
}
