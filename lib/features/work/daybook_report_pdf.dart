import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/design/bv_tokens.dart';
import '../../core/photo_privacy.dart';
import '../../core/share.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/library_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../spaces/former_member.dart';
import 'daybook_words.dart';

/// The fonts a report's PDF embeds: the app's own, Plus Jakarta Sans and
/// Almarai. Almarai holds Arabic letters only, so each falls back on the
/// other: Latin words and digits in an Arabic report, an Arabic name in an
/// English one (review 79 §1).
typedef ReportFonts = ({
  pw.Font latin,
  pw.Font latinBold,
  pw.Font arabic,
  pw.Font arabicBold,
});

final reportFontsProvider = FutureProvider<ReportFonts>((ref) async {
  Future<pw.Font> font(String name) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/$name.ttf'));
  return (
    latin: await font('PlusJakartaSans-Regular'),
    latinBold: await font('PlusJakartaSans-Bold'),
    arabic: await font('Almarai-Regular'),
    arabicBold: await font('Almarai-Bold'),
  );
});

/// The PDF's page, in points (A4): the app's two text sizes scaled for
/// paper, the day larger, and the paper's spacing.
abstract final class _Pdf {
  static const margin = 36.0;
  static const day = 20.0;
  static const main = 13.0;
  static const small = 11.0;
  static const under = 10.0;
  static const stamp = 8.0;
  static const gapTiny = 2.0;
  static const gapSmall = 4.0;
  static const lineGap = 6.0;
  static const headingTop = 10.0;
  static const divider = 20.0;
  static const hairline = 0.5;
  static const stampPad = 1.0;
  static const stampBorder = 1.0;
  static const stampRadius = 2.0;
  static const photosTop = 12.0;
  static const photoGap = 8.0;
  static const photoRadius = 4.0;
  static const photo = 160.0;
}

/// One line of a report's PDF: its words, and for checked work "Checked
/// 10:12 by Omar Haddad" under them.
typedef ReportPdfLine = ({String text, String? under, bool checked});

/// One section of a report's PDF: its heading and lines.
typedef ReportPdfSection = ({String heading, List<ReportPdfLine> lines});

/// What a report's PDF holds (review 78 §6): the Space's name, the day,
/// who wrote it and when, the three headings with their lines, and the
/// photos. Only what its author may see, as on the card. No logo, no
/// company facts, no totals (rules 3 and 4).
@immutable
class ReportPdf {
  const ReportPdf({
    required this.spaceName,
    required this.day,
    required this.by,
    required this.sections,
    required this.rtl,
    this.photos = const [],
    this.checkedLabel = '',
  });

  /// [post]'s report as the reader reads it, in their language and
  /// direction. [photos] the photos' bytes, already made safe.
  factory ReportPdf.of(
    AppLocalizations l10n,
    DaybookWords words, {
    required String spaceName,
    required DaybookPost post,
    List<Uint8List> photos = const [],
  }) {
    final sections = <ReportPdfSection>[];
    for (final b in post.blocks) {
      switch (b['type']) {
        case 'heading':
          sections.add((heading: b['text'] as String? ?? '', lines: []));
        case 'text':
          final text = (b['text'] as String? ?? '').trim();
          if (text.isEmpty) break;
          if (sections.isEmpty) sections.add((heading: '', lines: []));
          sections.last.lines.add((text: text, under: null, checked: false));
        case 'item_ref':
          final r = post.refs[b['post_id']];
          if (r == null || r.cancelled) break;
          if (sections.isEmpty) sections.add((heading: '', lines: []));
          final at = r.at;
          final time = at == null ? '' : words.time.clock(at);
          final checked = !r.isNote && r.itemStatus == WorkStatus.checked;
          sections.last.lines.add((
            text: r.title,
            under: checked
                ? l10n.dailyReportPdfChecked(
                    time,
                    personName(l10n, r.checkerName),
                  )
                : [
                    if (r.isNote) personName(l10n, r.authorName),
                    time,
                  ].where((s) => s.isNotEmpty).join(' · '),
            checked: checked,
          ));
      }
    }
    return ReportPdf(
      spaceName: spaceName,
      day: post.title,
      by: l10n.dailyReportPdfBy(
        personName(l10n, post.authorName),
        words.time.clock(post.createdAt),
      ),
      sections: sections,
      rtl: l10n.localeName.startsWith('ar'),
      photos: photos,
      checkedLabel: l10n.daybookStampChecked,
    );
  }

  final String spaceName;
  final String day;
  final String by;
  final List<ReportPdfSection> sections;
  final bool rtl;
  final List<Uint8List> photos;
  final String checkedLabel;

  /// The PDF's bytes, made on the phone.
  Future<Uint8List> bytes(ReportFonts fonts) {
    final base = rtl ? fonts.arabic : fonts.latin;
    final bold = rtl ? fonts.arabicBold : fonts.latinBold;
    final theme = pw.ThemeData.withFont(
      base: base,
      bold: bold,
      fontFallback: rtl
          ? [fonts.latin, fonts.latinBold]
          : [fonts.arabic, fonts.arabicBold],
    );
    final ink = PdfColor.fromInt(BvColors.textPrimary.toARGB32());
    final grey = PdfColor.fromInt(BvColors.textSecondary.toARGB32());
    final green = PdfColor.fromInt(BvColors.textPositive.toARGB32());
    final line = PdfColor.fromInt(BvColors.borderSubtle.toARGB32());
    final doc = pw.Document(theme: theme, title: day);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_Pdf.margin),
        textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (_) => [
          pw.Text(
            spaceName,
            style: pw.TextStyle(color: grey, fontSize: _Pdf.small),
          ),
          pw.SizedBox(height: _Pdf.gapSmall),
          pw.Text(
            day,
            style: pw.TextStyle(
              font: bold,
              fontSize: _Pdf.day,
              color: ink,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: _Pdf.gapTiny),
          pw.Text(
            by,
            style: pw.TextStyle(color: grey, fontSize: _Pdf.small),
          ),
          pw.Divider(
            color: line,
            thickness: _Pdf.hairline,
            height: _Pdf.divider,
          ),
          for (final s in sections) ...[
            if (s.heading.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(
                  top: _Pdf.headingTop,
                  bottom: _Pdf.gapSmall,
                ),
                child: pw.Text(
                  s.heading,
                  style: pw.TextStyle(color: grey, fontSize: _Pdf.small),
                ),
              ),
            for (final l in s.lines)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: _Pdf.lineGap),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            l.text,
                            style: pw.TextStyle(
                              color: ink,
                              fontSize: _Pdf.main,
                            ),
                          ),
                          if ((l.under ?? '').isNotEmpty)
                            pw.Text(
                              l.under!,
                              style: pw.TextStyle(
                                color: grey,
                                fontSize: _Pdf.under,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (l.checked)
                      pw.Container(
                        margin: const pw.EdgeInsets.symmetric(
                          horizontal: _Pdf.lineGap,
                        ),
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: _Pdf.gapSmall,
                          vertical: _Pdf.stampPad,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: green,
                            width: _Pdf.stampBorder,
                          ),
                          borderRadius: pw.BorderRadius.circular(
                            _Pdf.stampRadius,
                          ),
                        ),
                        child: pw.Text(
                          checkedLabel,
                          style: pw.TextStyle(
                            font: bold,
                            color: green,
                            fontSize: _Pdf.stamp,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
          if (photos.isNotEmpty) ...[
            pw.SizedBox(height: _Pdf.photosTop),
            pw.Wrap(
              spacing: _Pdf.photoGap,
              runSpacing: _Pdf.photoGap,
              children: [
                for (final p in photos)
                  pw.ClipRRect(
                    horizontalRadius: _Pdf.photoRadius,
                    verticalRadius: _Pdf.photoRadius,
                    child: pw.Image(
                      pw.MemoryImage(p),
                      width: _Pdf.photo,
                      height: _Pdf.photo,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  /// At most this many photos go in the PDF.
  static const maxPhotos = 8;
}

/// Share as PDF (review 78 §6): the report as the reader may read it, made
/// on the phone, its photos made safe first (F60), then the phone's share
/// sheet. It leaves the Space only by this tap (review 79 §1).
Future<void> shareReportPdf(
  BuildContext context,
  WidgetRef ref,
  SpaceDetail space,
  DaybookPost post,
) async {
  final l10n = AppLocalizations.of(context);
  final words = DaybookWords(
    l10n,
    Localizations.localeOf(context).toLanguageTag(),
    use24: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(content: Text(l10n.dailyReportMakingPdf)));
  try {
    final fonts = await ref.read(reportFontsProvider.future);
    final paths = <String>{
      for (final b in post.blocks)
        if (b['type'] == 'item_ref') ?post.refs[b['post_id']]?.photoPath,
      ?post.coverPath,
    }.take(ReportPdf.maxPhotos);
    final library = ref.read(libraryRepositoryProvider);
    final photos = <Uint8List>[];
    for (final path in paths) {
      try {
        final raw = await library.download(path);
        final safe = await cleanPhotoBytes(raw);
        if (safe.result == PhotoCleaning.cleaned) photos.add(safe.bytes ?? raw);
      } on Exception {
        // A photo that can't be read is left out; the words still go.
      }
    }
    final bytes = await ReportPdf.of(
      l10n,
      words,
      spaceName: space.name,
      post: post,
      photos: photos,
    ).bytes(fonts);
    messenger.hideCurrentSnackBar();
    await ref.read(shareFileProvider)(
      '${l10n.dailyReportPdfFile(post.title)}.pdf',
      'application/pdf',
      bytes,
    );
  } on Exception {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.dailyReportPdfFailed)));
  }
}
