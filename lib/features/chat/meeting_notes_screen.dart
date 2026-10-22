import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_specs.dart' show BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/meeting_report_specs.dart';
import '../../core/l10n/bv_time.dart';
import '../../data/models/chat.dart';
import '../../data/models/space.dart';
import '../../data/repositories/chat_repository.dart' show spaceThreadsProvider;
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/week_report_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart';
import '../spaces/space_errors.dart';
import '../work/daybook_draft.dart' show DaybookPostDraft;
import '../work/daybook_writing.dart' show assignablePeople, newPostIdProvider;
import 'chat_tab.dart' show threadName;

/// At most this many lines go in as work items (create_from_message).
const meetingLinesMax = 30;

/// A meeting's words split as R3 reads them: the first line is the title
/// (the meeting's own work item), every other non-blank line a line that
/// can become a work item, its list mark ("- ", "• ", "1. ") left out. A
/// line longer than a title is cut at a word.
({String title, List<String> lines}) meetingNotes(String body) {
  final all = [
    for (final l in body.split('\n'))
      if (l.trim().isNotEmpty) _cut(_unmark(l.trim())),
  ];
  if (all.isEmpty) return (title: '', lines: const []);
  return (title: all.first, lines: all.skip(1).take(meetingLinesMax).toList());
}

/// Two lines or more: meeting notes can be made of it.
bool hasMeetingLines(String? body) => meetingNotes(body ?? '').lines.isNotEmpty;

final _mark = RegExp(r'^([-•*·–]|\d{1,2}[.)])\s+');

String _unmark(String line) => line.replaceFirst(_mark, '').trim();

String _cut(String text) {
  const max = DaybookPostDraft.titleMax;
  if (text.length <= max) return text;
  final space = text.lastIndexOf(' ', max);
  return text.substring(0, space > 0 ? space : max).trim();
}

/// What R3 posted: the meeting's work item and how many under it.
typedef MeetingPosted = ({String parentId, int count});

/// R3 (2540:34503): a chat message's lines into work items. The first
/// line is the title; tick the lines that are work, each with who does it
/// (ticking one asks at once); Post sends them all in one step, under ids
/// chosen when the screen opened, so trying again is the same batch.
/// Pops [MeetingPosted] once the server took them.
class MeetingNotesScreen extends ConsumerStatefulWidget {
  const MeetingNotesScreen({
    super.key,
    required this.spaceId,
    required this.threadId,
    required this.message,
  });

  final String spaceId;
  final String threadId;
  final ChatMessage message;

  @override
  ConsumerState<MeetingNotesScreen> createState() => _MeetingNotesState();
}

class _MeetingNotesState extends ConsumerState<MeetingNotesScreen> {
  late final _notes = meetingNotes(widget.message.body ?? '');
  late final _parentId = ref.read(newPostIdProvider)();
  late final _lineIds = [
    for (final _ in _notes.lines) ref.read(newPostIdProvider)(),
  ];
  final _owners = <int, BvGiveToPerson>{};
  bool _posting = false;

  /// Who may be given a line: the Space's Leads and Crew; in a Team's
  /// thread, only that Team (the work stays in the Team).
  Future<List<BvGiveToPerson>?> _people() async {
    final me = ref.read(authUserIdProvider).value;
    final SpacePeople people;
    try {
      people = await ref.read(spacePeopleProvider(widget.spaceId).future);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return null;
    }
    final teamId = ref
        .read(spaceThreadsProvider(widget.spaceId))
        .value
        ?.where((t) => t.id == widget.threadId)
        .firstOrNull
        ?.teamId;
    final team = people.teams.where((t) => t.id == teamId).firstOrNull;
    return [
      for (final p in assignablePeople(people, me: me))
        if (team == null || team.memberIds.contains(p.id)) p,
    ];
  }

  Future<BvGiveToPerson?> _pick(int index) async {
    final l10n = AppLocalizations.of(context);
    final people = await _people();
    if (people == null || !mounted) return null;
    return showBvSheet<BvGiveToPerson>(
      context: context,
      title: l10n.walkOwner,
      builder: (sheet) => BvGiveToPicker(
        key: const Key('meeting-owner-picker'),
        people: people,
        currentOwnerId: _owners[index]?.id,
        meId: ref.read(authUserIdProvider).value,
        meLabel: l10n.daybookYou,
        searchPlaceholder: l10n.daybookAssignSearch,
        inSheet: true,
        onPick: (p) => Navigator.of(sheet).pop(p),
      ),
    );
  }

  /// A tick asks who does it at once; no answer, no tick.
  Future<void> _toggle(int index) async {
    if (_owners.containsKey(index)) {
      setState(() => _owners.remove(index));
      return;
    }
    final picked = await _pick(index);
    if (picked != null && mounted) setState(() => _owners[index] = picked);
  }

  Future<void> _changeOwner(int index) async {
    final picked = await _pick(index);
    if (picked != null && mounted) setState(() => _owners[index] = picked);
  }

  Future<void> _post() async {
    final l10n = AppLocalizations.of(context);
    final ticked = _owners.keys.toList()..sort();
    setState(() => _posting = true);
    try {
      await ref
          .read(weekReportRepositoryProvider)
          .createFromMessage(
            spaceId: widget.spaceId,
            messageId: widget.message.id,
            parentId: _parentId,
            title: _notes.title,
            lines: [
              for (final i in ticked)
                (
                  id: _lineIds[i],
                  text: _notes.lines[i],
                  ownerId: _owners[i]!.id,
                ),
            ],
          );
    } on SpaceException catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      if (e.failure == SpaceFailure.network) {
        showSpaceMessage(context, l10n.meetingNoSignal);
      } else {
        showSpaceError(context, e);
      }
      return;
    }
    if (!mounted) return;
    context.pop<MeetingPosted>((parentId: _parentId, count: ticked.length));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final space = ref.watch(spaceDetailProvider(widget.spaceId)).value;
    final thread = ref
        .watch(spaceThreadsProvider(widget.spaceId))
        .value
        ?.where((t) => t.id == widget.threadId)
        .firstOrNull;
    final m = widget.message;
    final author = m.authorName ?? l10n.formerMember;
    final count = _owners.length;

    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              thread == null ? '' : threadName(l10n, thread),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.titleMd,
            ),
            if (space != null && thread != null)
              Text(
                '${space.name} · ${threadName(l10n, thread)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('meeting-list'),
              reverse: true,
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: BvSpace.s8,
                  children: [
                    BvAvatar(name: author, size: BvAvatarSize.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: BvSpace.s4,
                        children: [
                          Text(
                            '$author · ${BvTime.of(context).clock(m.createdAt.toLocal())}',
                            style: type.metadata.copyWith(
                              color: BvColors.textSecondary,
                            ),
                          ),
                          _NotesCard(
                            title: _notes.title,
                            lines: _notes.lines,
                            owners: _owners,
                            onToggle: _posting ? null : _toggle,
                            onOwner: _posting ? null : _changeOwner,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: BvColors.surfaceElevated,
              border: Border(
                top: BorderSide(
                  color: BvColors.borderSubtle,
                  width: BvStroke.thin,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                child: Row(
                  children: [
                    TextButton(
                      key: const Key('meeting-cancel'),
                      onPressed: () => context.pop(),
                      child: Text(
                        l10n.commonCancel,
                        style: type.labelMd.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: BvSpace.s8),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: BvButton(
                          key: const Key('meeting-post'),
                          label: l10n.meetingPost(count),
                          size: BvButtonSize.medium,
                          onPressed: count == 0 || _posting ? null : _post,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// R3's message card (2540:34546): outlined in the action colour, the
/// title, then a row per line with its tick box and, once ticked, the face
/// of who does it.
class _NotesCard extends StatelessWidget {
  const _NotesCard({
    required this.title,
    required this.lines,
    required this.owners,
    required this.onToggle,
    required this.onOwner,
  });

  final String title;
  final List<String> lines;
  final Map<int, BvGiveToPerson> owners;
  final ValueChanged<int>? onToggle;
  final ValueChanged<int>? onOwner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Container(
      key: const Key('meeting-card'),
      padding: const EdgeInsetsDirectional.all(BvMeetingSpec.cardPadding),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        border: Border.all(
          color: BvColors.borderSelected,
          width: BvMeetingSpec.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            key: const Key('meeting-title'),
            style: type.labelMd.copyWith(color: BvColors.textPrimary),
          ),
          for (final (i, line) in lines.indexed)
            _Line(
              key: Key('meeting-line-$i'),
              text: line,
              owner: owners[i],
              // A line of one letter can't be a work item.
              onTap: line.length < DaybookPostDraft.titleMin
                  ? null
                  : onToggle == null
                  ? null
                  : () => onToggle!(i),
              onOwner: onOwner == null ? null : () => onOwner!(i),
              ownerLabel: l10n.meetingChangeOwner,
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.text,
    required this.owner,
    required this.onTap,
    required this.onOwner,
    required this.ownerLabel,
  });

  final String text;
  final BvGiveToPerson? owner;
  final VoidCallback? onTap;
  final VoidCallback? onOwner;
  final String ownerLabel;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final ticked = owner != null;
    return Semantics(
      checked: ticked,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BvSize.touchMin),
          child: Row(
            spacing: BvMeetingSpec.lineGap,
            children: [
              Container(
                width: BvMeetingSpec.box,
                height: BvMeetingSpec.box,
                decoration: BoxDecoration(
                  color: ticked ? BvColors.actionPrimary : null,
                  borderRadius: BvMeetingSpec.boxRadius,
                  border: ticked
                      ? null
                      : Border.all(
                          color: BvColors.borderInput,
                          width: BvMeetingSpec.boxBorder,
                        ),
                ),
                child: ticked
                    ? const Icon(
                        BvMeetingSpec.checkIcon,
                        size: BvMeetingSpec.check,
                        color: BvColors.actionPrimaryForeground,
                      )
                    : null,
              ),
              Expanded(
                child: Text(
                  text,
                  style: type.bodyMd.copyWith(
                    color: onTap == null
                        ? BvColors.textSecondary
                        : BvColors.textPrimary,
                  ),
                ),
              ),
              if (owner != null)
                Semantics(
                  button: true,
                  label: ownerLabel,
                  child: InkResponse(
                    key: Key('meeting-owner-${owner!.id}'),
                    radius: BvSize.touchMin / 2,
                    onTap: onOwner,
                    child: SizedBox.square(
                      dimension: BvSize.touchMin,
                      child: Center(
                        child: BvAvatar(
                          name: owner!.name,
                          size: BvAvatarSize.xs,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
