import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/daybook.dart';
import '../../data/models/post_page.dart' show PageText;
import '../../data/models/space.dart';
import '../../data/models/template.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/template_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_ack_pill.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'daybook_draft.dart';
import 'daybook_photos.dart' show daybookPhotoProvider;
import 'daybook_words.dart';
import 'daybook_writing.dart' show DaybookWriter;

/// Whose day a daily report is: a Space, its audience (a Team, or null
/// for Everyone) and the phone's day.
typedef ReportDay = ({String spaceId, String? teamId, DateTime day});

/// The phone's [day] from midnight, up to now when it is today.
({DateTime from, DateTime to}) _span(DateTime day, DateTime now) {
  final from = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day + 1);
  return (from: from, to: now.isBefore(end) ? now : end);
}

/// What was checked that day, for that audience (daily_report_fill): only
/// work all the report's readers may see (an Everyone report never lists a
/// Team's).
final reportCheckedProvider = FutureProvider.autoDispose
    .family<List<ReportRef>, ReportDay>((ref, d) {
      final span = _span(d.day, ref.read(clockProvider)());
      return ref
          .watch(templateRepositoryProvider)
          .checked(d.spaceId, teamId: d.teamId, from: span.from, to: span.to);
    });

/// The day's notes, offered for "On site" (daily_report_notes, migration
/// 30). Without them, "On site" is a heading to write under: a failed call
/// offers none.
final reportNotesProvider = FutureProvider.autoDispose
    .family<List<ReportRef>, ReportDay>((ref, d) async {
      final span = _span(d.day, ref.read(clockProvider)());
      try {
        return await ref
            .watch(templateRepositoryProvider)
            .notes(d.spaceId, teamId: d.teamId, from: span.from, to: span.to);
      } on SpaceException {
        return const [];
      }
    });

/// The daily report's page as it is posted (R2): On site with its words
/// and the notes added, Done today with each checked work item as an
/// `item_ref`, then Problems. Headings in the writer's words; ids new.
List<Map<String, dynamic>> reportPage(
  AppLocalizations l10n,
  DaybookPostDraft d,
) {
  Map<String, dynamic> heading(String text) => {
    'id': newUuid(),
    'type': 'heading',
    'text': text,
    'level': 2,
  };
  Map<String, dynamic> ref(ReportRef r) => {
    'id': newUuid(),
    'type': 'item_ref',
    'post_id': r.postId,
  };
  List<Map<String, dynamic>> words(String text) {
    final t = text.trim();
    if (t.isEmpty) return const [];
    return [
      {
        'id': newUuid(),
        'type': 'text',
        'text': t.length > PageText.max ? t.substring(0, PageText.max) : t,
      },
    ];
  }

  return [
    heading(l10n.dailyReportOnSite),
    ...words(d.onSite),
    for (final n in d.notes) ref(n),
    heading(l10n.dailyReportDoneToday),
    for (final r in d.refsIn) ref(r),
    heading(l10n.dailyReportProblems),
    ...words(d.problems),
  ];
}

/// The daily report on the writing card (review 78 §4): On site to write
/// under, with the day's notes to Add; Done today, filled with what was
/// checked today, each line with ✕; Problems to write under. Photos are
/// the post's own (📎), as on any post.
class ReportWriting extends ConsumerStatefulWidget {
  const ReportWriting({
    super.key,
    required this.writer,
    required this.draft,
    required this.words,
    required this.writing,
  });

  final DaybookWriter writer;
  final DaybookPostDraft draft;
  final DaybookWords words;
  final bool writing;

  @override
  ConsumerState<ReportWriting> createState() => _ReportWritingState();
}

class _ReportWritingState extends ConsumerState<ReportWriting> {
  late final _onSite = TextEditingController(text: widget.draft.onSite);
  late final _problems = TextEditingController(text: widget.draft.problems);

  @override
  void didUpdateWidget(ReportWriting old) {
    super.didUpdateWidget(old);
    // A template filled it: the boxes show its words.
    final d = widget.draft;
    if (d.templateId != old.draft.templateId) {
      if (_onSite.text != d.onSite) _onSite.text = d.onSite;
      if (_problems.text != d.problems) _problems.text = d.problems;
    }
  }

  @override
  void dispose() {
    _onSite.dispose();
    _problems.dispose();
    super.dispose();
  }

  ReportDay get _day => (
    spaceId: widget.writer.spaceId,
    teamId: widget.draft.teamId,
    day: widget.draft.reportDay ?? dayOf(ref.read(clockProvider)()),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final d = widget.draft;
    final day = _day;
    // What was checked today goes into the draft, so it is posted (and
    // kept) as the person saw it.
    ref.listen(reportCheckedProvider(day), (_, next) {
      if (next.value case final refs?) {
        unawaited(Future.microtask(() => widget.writer.setChecked(refs)));
      }
    });
    final checked = ref.watch(reportCheckedProvider(day)).value ?? d.refs;
    final shown = [
      for (final r in checked)
        if (!d.refsOut.contains(r.postId)) r,
    ];
    final notes = [
      for (final n in ref.watch(reportNotesProvider(day)).value ?? const [])
        if (!d.notes.any((x) => x.postId == n.postId)) n,
    ];
    Widget label(String text) =>
        Text(text, style: type.labelSm.copyWith(color: BvColors.textSecondary));
    Widget field(
      Key key,
      TextEditingController c,
      String hint,
      ValueChanged<String> onChanged,
    ) => TextField(
      key: key,
      controller: c,
      enabled: widget.writing,
      minLines: 1,
      maxLines: null,
      maxLength: PageText.max,
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      style: type.bodyMd.copyWith(color: BvColors.textPrimary),
      decoration: bvBareField(hint: hint, style: type.bodyMd),
      onChanged: onChanged,
    );
    return Column(
      key: const Key('report-writing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        label(l10n.dailyReportOnSite),
        field(
          const Key('report-on-site'),
          _onSite,
          l10n.dailyReportOnSiteHint,
          (v) => unawaited(widget.writer.setOnSite(v)),
        ),
        for (final n in d.notes)
          ReportLine(
            key: Key('report-note-${n.postId}'),
            title: n.title,
            time: widget.words.time.clock(n.at),
            onRemove: widget.writing
                ? () => unawaited(widget.writer.takeOut(n))
                : null,
          ),
        if (notes.isNotEmpty && widget.writing) ...[
          label(l10n.dailyReportNotes),
          for (final n in notes)
            _NoteSuggestion(
              key: Key('report-suggest-${n.postId}'),
              title: n.title,
              time: widget.words.time.clock(n.at),
              onAdd: () => unawaited(widget.writer.addNote(n)),
            ),
        ],
        const SizedBox(height: BvSpace.s4),
        label(l10n.dailyReportDoneToday),
        if (shown.isEmpty)
          Text(
            l10n.dailyReportNothingChecked,
            key: const Key('report-nothing-checked'),
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
        for (final r in shown)
          ReportLine(
            key: Key('report-done-${r.postId}'),
            title: r.title,
            time: widget.words.time.clock(r.at),
            checked: true,
            onRemove: widget.writing
                ? () => unawaited(widget.writer.takeOut(r))
                : null,
          ),
        const SizedBox(height: BvSpace.s4),
        label(l10n.dailyReportProblems),
        field(
          const Key('report-problems'),
          _problems,
          l10n.dailyReportProblemsHint,
          (v) => unawaited(widget.writer.setProblems(v)),
        ),
      ],
    );
  }
}

/// One line of a report (R2): the words, the time, and for checked work a
/// small CHECKED stamp; while writing, ✕ takes it out ([onRemove]); on the
/// card, a tap opens it ([onTap]).
class ReportLine extends StatelessWidget {
  const ReportLine({
    super.key,
    required this.title,
    required this.time,
    this.checked = false,
    this.onRemove,
    this.onTap,
  });

  final String title;
  final String time;
  final bool checked;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final row = Row(
      spacing: BvSpace.s8,
      children: [
        Expanded(
          child: Text(
            inOwnDirection(title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: type.bodyMd.copyWith(color: BvColors.textPrimary),
          ),
        ),
        Text(time, style: type.bodySm.copyWith(color: BvColors.textSecondary)),
        if (checked)
          BvInkStamp(
            label: l10n.daybookStampChecked,
            size: BvInkStampSize.xs,
            tone: BvInkStampTone.positive,
          ),
        if (onRemove != null)
          BvTapTarget(
            child: Semantics(
              button: true,
              label: l10n.dailyReportTakeOut,
              child: GestureDetector(
                key: const Key('report-line-remove'),
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: const Icon(
                  BvIcons.close,
                  size: BvSize.iconSm,
                  color: BvColors.iconSecondary,
                ),
              ),
            ),
          ),
      ],
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

class _NoteSuggestion extends StatelessWidget {
  const _NoteSuggestion({
    super.key,
    required this.title,
    required this.time,
    required this.onAdd,
  });

  final String title;
  final String time;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Row(
      spacing: BvSpace.s8,
      children: [
        const Icon(
          BvIcons.edit,
          size: BvSize.iconSm,
          color: BvColors.iconSecondary,
        ),
        Expanded(
          child: Text(
            inOwnDirection(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
        ),
        Text(time, style: type.bodySm.copyWith(color: BvColors.textSecondary)),
        TextButton(
          key: const Key('report-add-note'),
          onPressed: onAdd,
          child: Text(l10n.dailyReportAddNote),
        ),
      ],
    );
  }
}

/// The built-in Daily report, as a template a report starts from.
const dailyReportTemplateId = PostTemplate.dailyReportId;

/// A daily report on its card (R2, redrawn: review 79 §5): its page as
/// written, with On site, Done today and Problems as small grey labels;
/// each work item a line with its time and a small CHECKED stamp, a tap
/// opening its card; a note its words and time. A line the reader can't
/// see isn't in [DaybookPost.refs], and is left out, never greyed (review
/// 78). Then the photos, filling the width, and Share as PDF at the end.
/// A report is no work item: no stamp of its own, no Sign as done, and it
/// never counts as proof.
class DaybookReportBody extends ConsumerWidget {
  const DaybookReportBody({
    super.key,
    required this.post,
    required this.words,
    this.onOpenRef,
    this.onShare,
  });

  final DaybookPost post;
  final DaybookWords words;
  final ValueChanged<String>? onOpenRef;
  final VoidCallback? onShare;

  /// R2's row of photos.
  static const photosInRow = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lines = <Widget>[];
    final photos = <String>[];
    for (final b in post.blocks) {
      switch (b['type']) {
        case 'heading':
          lines.add(
            Padding(
              padding: EdgeInsetsDirectional.only(
                top: lines.isEmpty ? 0 : BvSpace.s8,
              ),
              child: Text(
                b['text'] as String? ?? '',
                style: type.labelSm.copyWith(color: BvColors.textSecondary),
              ),
            ),
          );
        case 'text':
          final text = (b['text'] as String? ?? '').trim();
          if (text.isNotEmpty) {
            lines.add(
              Text(
                text,
                style: type.bodyMd.copyWith(color: BvColors.textPrimary),
              ),
            );
          }
        case 'item_ref':
          final id = b['post_id'] as String? ?? '';
          final r = post.refs[id];
          if (r == null || r.cancelled) break;
          final at = r.at;
          lines.add(
            ReportLine(
              key: Key('report-ref-$id'),
              title: r.title,
              time: at == null ? '' : words.time.clock(at),
              checked: !r.isNote && r.itemStatus == WorkStatus.checked,
              onTap: onOpenRef == null ? null : () => onOpenRef!(id),
            ),
          );
          if (r.photoPath case final path?) photos.add(path);
      }
    }
    if (post.coverPath case final cover? when !photos.contains(cover)) {
      photos.add(cover);
    }
    final shown = photos.take(photosInRow).toList();
    return Column(
      key: Key('report-${post.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s4,
      children: [
        ...lines,
        if (shown.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: BvSpace.s8),
            child: Row(
              key: const Key('report-photos'),
              spacing: BvSpace.s8,
              children: [
                for (var i = 0; i < photosInRow; i++)
                  Expanded(
                    child: i < shown.length
                        ? AspectRatio(
                            aspectRatio: 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                BvRadius.photo,
                              ),
                              child: _Photo(path: shown[i]),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        if (onShare != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: BvSpace.s8),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: BvAckPill(
                key: const Key('report-share-pdf'),
                label: l10n.dailyReportSharePdf,
                icon: BvIcons.document,
                onTap: onShare,
              ),
            ),
          ),
      ],
    );
  }
}

class _Photo extends ConsumerWidget {
  const _Photo({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(daybookPhotoProvider(path));
    if (image == null) return const ColoredBox(color: BvColors.surfaceSubtle);
    return Image(
      image: image,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const ColoredBox(color: BvColors.surfaceSubtle),
    );
  }
}
