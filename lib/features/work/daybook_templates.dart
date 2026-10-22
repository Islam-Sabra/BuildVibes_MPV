import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/template.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/template_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../spaces/space_errors.dart';
import 'daybook_draft.dart';
import 'daybook_writing.dart' show kindIcon;

/// A template's name as a list says it: a built-in's in the reader's
/// language, a Space's own as typed.
String templateName(AppLocalizations l10n, PostTemplate t) =>
    switch (t.builtinKey) {
      PostTemplate.dailyReportKey => l10n.templateBuiltinDailyReport,
      null => t.name ?? '',
      _ => t.name ?? '',
    };

/// The templates a card of [kind] can start from, in the server's order
/// (built-ins first, then the Space's own, newest first).
///
/// A Team's template sets the post's audience, so it is offered only where
/// the card has one ([audience], an announcement or a report): with a Team
/// already chosen ([teamId]), only that Team's and the Everyone ones, so
/// the server never refuses (review 78). A work item and a checklist go to
/// Everyone: only the Everyone ones.
List<PostTemplate> templatesFor(
  List<PostTemplate> all,
  DaybookKind kind, {
  String? teamId,
  bool chosenTeam = false,
}) {
  final audience =
      kind == DaybookKind.announcement || kind == DaybookKind.report;
  return [
    for (final t in all)
      if (t.kind == kind.json &&
          (t.teamId == null ||
              (audience && (!chosenTeam || t.teamId == teamId))))
        t,
  ];
}

/// A heading kept by its key (a built-in's) in the reader's words.
String? headingWords(AppLocalizations l10n, String? key) => switch (key) {
  PostTemplate.onSiteKey => l10n.dailyReportOnSite,
  PostTemplate.doneTodayKey => l10n.dailyReportDoneToday,
  PostTemplate.problemsKey => l10n.dailyReportProblems,
  _ => null,
};

/// [t]'s page for a new post: each block under a new id (a post's ids are
/// its own), and a heading kept by key in the writer's words.
List<Map<String, dynamic>> templatePage(AppLocalizations l10n, PostTemplate t) {
  Map<String, dynamic> fresh(Map<String, dynamic> b) {
    final out = Map<String, dynamic>.of(b)..['id'] = newUuid();
    final words = headingWords(l10n, b['key'] as String?);
    if (b['type'] == 'heading' && words != null) {
      out
        ..remove('key')
        ..['text'] = words
        ..putIfAbsent('level', () => 1);
    }
    if (b['children'] case final List children) {
      out['children'] = [
        for (final c in children) fresh(c as Map<String, dynamic>),
      ];
    }
    return out;
  }

  return [for (final b in t.blocks) fresh(b)];
}

/// The card filled from [t] (review 78 §1): its title and words, a
/// checklist's or a work item's points, its page, and a Team's audience.
/// What the person already typed in a field the template leaves empty
/// stays.
DaybookPostDraft fillFromTemplate(
  AppLocalizations l10n,
  DaybookPostDraft d,
  PostTemplate t, {
  SpaceTeam? team,
}) {
  final page = templatePage(l10n, t);
  final points = [for (final p in t.points) (id: newUuid(), text: p)];
  // A work item's points show on its page, under the words.
  if (d.kind == DaybookKind.workItem && points.isNotEmpty) {
    page.add({
      'id': newUuid(),
      'type': 'checklist_ref',
      'point_ids': [for (final p in points) p.id],
    });
  }
  String pick(String? from, String typed) =>
      (from ?? '').trim().isEmpty ? typed : from!;
  return d.copyWith(
    title: d.kind == DaybookKind.report ? d.title : pick(t.title, d.title),
    body: pick(t.body, d.body),
    points: points.isEmpty ? d.points : points,
    team: t.teamId == null || team == null
        ? null
        : () => (id: team.id, name: team.name),
    template: () => (id: t.id, name: templateName(l10n, t), blocks: page),
  );
}

/// A report's sections from [t] (one of the Space's own report templates):
/// the words under On site and under Problems, by the headings' order.
({String onSite, String problems}) reportSections(PostTemplate t) {
  final onSite = <String>[];
  final problems = <String>[];
  var heading = -1;
  for (final b in t.blocks) {
    switch (b['type']) {
      case 'heading':
        heading = switch (b['key']) {
          PostTemplate.onSiteKey => 0,
          PostTemplate.doneTodayKey => 1,
          PostTemplate.problemsKey => 2,
          _ => heading + 1,
        };
      case 'text':
        final text = (b['text'] as String? ?? '').trim();
        if (text.isEmpty) break;
        if (heading <= 0) onSite.add(text);
        if (heading >= 2) problems.add(text);
    }
  }
  return (onSite: onSite.join('\n'), problems: problems.join('\n'));
}

/// The rows of a template list (review 79 §1): the kind's own icon, the
/// name, and for a Space's own a small grey line, its Team or Everyone; no
/// count and no date. The built-ins come first under no heading; the
/// Space's own after a hairline, under "This Space's templates".
class TemplateList extends ConsumerWidget {
  const TemplateList({
    super.key,
    required this.spaceId,
    required this.templates,
    required this.rowFor,
    this.empty,
  });

  final String spaceId;
  final List<PostTemplate> templates;

  /// One row, built by the caller (a tap to choose, or a Delete).
  final Widget Function(PostTemplate t, String name, String? line) rowFor;

  /// Shown under the heading when the Space has none of its own.
  final String? empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final teams = ref.watch(spacePeopleProvider(spaceId)).value?.teams;
    String line(PostTemplate t) {
      if (t.teamId == null) return l10n.daybookEveryone;
      return teams?.where((x) => x.id == t.teamId).firstOrNull?.name ??
          l10n.daybookEveryone;
    }

    final builtins = [
      for (final t in templates)
        if (t.isBuiltin) t,
    ];
    final own = [
      for (final t in templates)
        if (!t.isBuiltin) t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in builtins) rowFor(t, templateName(l10n, t), null),
        if (own.isNotEmpty || empty != null) ...[
          if (builtins.isNotEmpty)
            const Divider(
              key: Key('templates-hairline'),
              height: BvStroke.thin,
              thickness: BvStroke.thin,
              color: BvColors.borderSubtle,
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: BvSpace.s16,
              bottom: BvSpace.s8,
            ),
            child: Text(
              l10n.templateSpaceOwn,
              style: BvType.of(
                context,
              ).labelSm.copyWith(color: BvColors.textSecondary),
            ),
          ),
          if (own.isEmpty)
            Text(
              empty!,
              key: const Key('templates-none'),
              style: BvType.of(
                context,
              ).bodySm.copyWith(color: BvColors.textSecondary),
            ),
          for (final t in own) rowFor(t, inOwnDirection(t.name ?? ''), line(t)),
        ],
      ],
    );
  }
}

/// The template picker (review 78 §1): this kind's templates, chosen by a
/// tap. Null when closed.
Future<PostTemplate?> showTemplatePicker(
  BuildContext context, {
  required String spaceId,
  required List<PostTemplate> templates,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<PostTemplate>(
    context: context,
    title: l10n.templatePickTitle,
    builder: (sheet) => TemplateList(
      key: const Key('template-picker'),
      spaceId: spaceId,
      templates: templates,
      rowFor: (t, name, line) => BvListRow(
        key: Key('template-${t.id}'),
        leading: Icon(
          kindIcon(DaybookKind.fromJson(t.kind)),
          size: BvSize.iconMd,
          color: BvColors.iconSecondary,
        ),
        title: name,
        subtitle: line,
        onTap: () => Navigator.of(sheet).pop(t),
      ),
    ),
  );
}

/// Who may save and delete a Space's templates: a Lead or a Space admin
/// (may_manage_templates).
bool mayManageTemplates(SpaceDetail? space) =>
    space != null && (space.iAmAdmin || space.myPass == SpacePass.lead);

/// The kinds that can be saved as a template (save_template).
bool savesAsTemplate(DaybookPost post) =>
    !post.cancelled && PostTemplate.kinds.contains(post.kind);

/// What Save as template ended in.
enum TemplateSaved { saved, full, cancelled }

/// Save as template (review 78 §2): a name of 1 to 60 characters,
/// prefilled with the post's title, then save_template. At the Space's
/// limit it says so and offers Space info › Templates ([onOpenList]).
Future<TemplateSaved> saveAsTemplate(
  BuildContext context,
  WidgetRef ref,
  DaybookPost post, {
  required String spaceId,
  required VoidCallback onOpenList,
}) async {
  final l10n = AppLocalizations.of(context);
  final name = await showBvSheet<String>(
    context: context,
    title: l10n.templateNameTitle,
    builder: (_) => _NameSheet(initial: post.title),
  );
  if (name == null || !context.mounted) return TemplateSaved.cancelled;
  try {
    await ref
        .read(templateRepositoryProvider)
        .save(id: newUuid(), spaceId: spaceId, fromPostId: post.id, name: name);
    ref.invalidate(spaceTemplatesProvider(spaceId));
    if (context.mounted) showSpaceMessage(context, l10n.templateSaved);
    return TemplateSaved.saved;
  } on SpaceException catch (e) {
    if (!context.mounted) return TemplateSaved.cancelled;
    if (e.failure == SpaceFailure.limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('templates-full'),
          content: Text(l10n.templateFull(PostTemplate.perSpace)),
          action: SnackBarAction(
            label: l10n.templateOpenList,
            onPressed: onOpenList,
          ),
        ),
      );
      return TemplateSaved.full;
    }
    showSpaceError(context, e);
    return TemplateSaved.cancelled;
  }
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});

  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _name = TextEditingController(
    text: widget.initial.length > PostTemplate.nameMax
        ? widget.initial.substring(0, PostTemplate.nameMax)
        : widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ok = _name.text.trim().isNotEmpty;
    return Column(
      key: const Key('template-name-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s16,
      children: [
        BvTextField(
          key: const Key('template-name'),
          controller: _name,
          placeholder: l10n.templateNameHint,
          maxLength: PostTemplate.nameMax,
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        BvButton(
          key: const Key('template-name-save'),
          label: l10n.save,
          expand: true,
          onPressed: ok
              ? () => Navigator.of(context).pop(_name.text.trim())
              : null,
        ),
      ],
    );
  }
}
