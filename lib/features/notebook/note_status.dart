import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart' show BvLineMenuSpec;
import '../../core/design/planning_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/note.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_line_popover.dart';
import '../work/daybook_words.dart';
import 'note_reminders.dart' show remindsAt;
import 'notebook_page_screen.dart' show reminderWhen;

/// What an entry's status icon says (review 104 N12), in this order: the
/// status row's, the Filter's STATUS and the Status sort's (review 106).
enum NoteStatusKind {
  pinned,
  reminder,
  feed,
  space,
  message;

  /// Its card's title, its Filter choice and its group in the Status sort.
  String title(AppLocalizations l10n) => switch (this) {
    pinned => l10n.notebookPinnedLabel,
    reminder => l10n.notebookStatusTitleReminder,
    feed => l10n.notebookStatusTitleFeed,
    space => l10n.notebookStatusTitleSpace,
    message => l10n.notebookStatusTitleMessage,
  };

  /// The glyph of its action.
  IconData get icon => switch (this) {
    pinned => BvIcons.pin,
    reminder => BvIcons.remind,
    feed => BvIcons.feed,
    space => BvIcons.team,
    message => BvIcons.chat,
  };
}

/// [note]'s shares to [target] that can be shown, oldest first: a Space or
/// a person with no name is left out, never shown blank (review 104 F3).
List<NoteShare> _shown(Note note, NoteShareTarget target) => [
  for (final s in note.shares)
    if (s.target == target &&
        (target == NoteShareTarget.feed || (s.name?.trim().isNotEmpty ?? false)))
      s,
];

/// Put in a Space before its shares were kept: no share, the post only.
bool _put(Note note) =>
    !note.shares.any((s) => s.target == NoteShareTarget.space) &&
    note.putInPostId != null &&
    !note.waiting;

/// The statuses [note] has, in their order (review 106 T1, T3): pinned; a
/// reminder (a voice note has none); shared to the feed, to a Space (or put
/// in one), sent to a person.
List<NoteStatusKind> statusKinds(Note note) => [
  if (note.pinned) NoteStatusKind.pinned,
  if (note.kind != NoteKind.voice && note.remindAt != null)
    NoteStatusKind.reminder,
  if (_shown(note, NoteShareTarget.feed).isNotEmpty) NoteStatusKind.feed,
  if (_shown(note, NoteShareTarget.space).isNotEmpty || _put(note))
    NoteStatusKind.space,
  if (_shown(note, NoteShareTarget.message).isNotEmpty) NoteStatusKind.message,
];

/// One status of an entry: its kind, what a screen reader says (the
/// latest of its kind, as review 104), the lines its card lists (every
/// share of the kind, review 106 T1) and its icon's colour.
@immutable
class NoteStatus {
  const NoteStatus(
    this.kind, {
    required this.label,
    this.lines = const [],
    this.colour = BvColors.iconSecondary,
  });

  final NoteStatusKind kind;
  final String label;
  final List<String> lines;
  final Color colour;
}

/// [note]'s statuses, in their order: the reminder in the accent colour
/// while it is still to ring, grey after.
List<NoteStatus> noteStatuses(
  Note note,
  AppLocalizations l10n,
  DaybookWords words,
  DateTime now,
) {
  String clock(NoteShare s) => words.time.clock(s.at);
  String named(NoteShare s) =>
      l10n.notebookStatusShareLine(s.name!.trim(), clock(s));
  NoteStatus status(NoteStatusKind kind) {
    switch (kind) {
      case NoteStatusKind.pinned:
        return NoteStatus(kind, label: l10n.notebookPinnedLabel);
      case NoteStatusKind.reminder:
        final when = reminderWhen(l10n, words, note.remindAt!, now);
        return NoteStatus(
          kind,
          label: l10n.notebookStatusReminder(when),
          lines: [l10n.notebookReminderLine(when)],
          colour: remindsAt(note, now)
              ? BvColors.iconAction
              : BvColors.iconSecondary,
        );
      case NoteStatusKind.feed:
        final feed = _shown(note, NoteShareTarget.feed);
        return NoteStatus(
          kind,
          label: l10n.notebookStatusFeed(clock(feed.last)),
          lines: [for (final s in feed) clock(s)],
        );
      case NoteStatusKind.space:
        final spaces = _shown(note, NoteShareTarget.space);
        if (spaces.isEmpty) {
          return NoteStatus(
            kind,
            label: l10n.notebookPut,
            lines: [l10n.notebookPut],
          );
        }
        return NoteStatus(
          kind,
          label: l10n.notebookStatusSpace(
            spaces.last.name!.trim(),
            clock(spaces.last),
          ),
          lines: [for (final s in spaces) named(s)],
        );
      case NoteStatusKind.message:
        final sent = _shown(note, NoteShareTarget.message);
        return NoteStatus(
          kind,
          label: l10n.notebookStatusSent(
            sent.last.name!.trim(),
            clock(sent.last),
          ),
          lines: [for (final s in sent) named(s)],
        );
    }
  }

  return [for (final kind in statusKinds(note)) status(kind)];
}

/// An entry's status row (review 106 T1): one round icon per status, at
/// the end of the entry. A tap opens a compact card under the icon listing
/// every share of its kind; the icon shows selected while it is open; a
/// reminder's card has Change ([onChangeReminder]).
class NoteStatusIcons extends StatefulWidget {
  const NoteStatusIcons({
    super.key,
    required this.id,
    required this.statuses,
    this.onChangeReminder,
  });

  final String id;
  final List<NoteStatus> statuses;
  final VoidCallback? onChangeReminder;

  @override
  State<NoteStatusIcons> createState() => _NoteStatusIconsState();
}

class _NoteStatusIconsState extends State<NoteStatusIcons> {
  final _card = BvLinePopover();
  final _icons = <NoteStatusKind, GlobalKey>{};

  /// The icon whose card is open.
  NoteStatusKind? _open;

  @override
  void dispose() {
    _card.hide();
    super.dispose();
  }

  void _close() {
    _card.hide();
    if (mounted) setState(() => _open = null);
  }

  void _show(NoteStatus s) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    setState(() => _open = s.kind);
    _card.show(
      context,
      anchor: () => _icons[s.kind]?.currentContext,
      atEnd: true,
      barrier: true,
      gap: BvLineMenuSpec.menuGap,
      onDismiss: _close,
      builder: (_) => Container(
        key: const Key('note-status-card'),
        width: BvLineMenuSpec.width,
        padding: const EdgeInsetsDirectional.all(BvLineMenuSpec.padding),
        decoration: BoxDecoration(
          color: BvColors.surfaceElevated,
          borderRadius: BvLineMenuSpec.radius,
          border: Border.all(
            color: BvColors.borderSubtle,
            width: BvStroke.thin,
          ),
          boxShadow: BvShadow.menu,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: BvLineMenuSpec.groupPadding,
                child: Text(
                  s.kind.title(l10n),
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
              ),
              for (final line in s.lines)
                Padding(
                  padding: BvLineMenuSpec.rowPadding,
                  child: Row(
                    spacing: BvLineMenuSpec.rowGap,
                    children: [
                      Icon(
                        s.kind.icon,
                        size: BvNotebookPagesSpec.statusIcon,
                        color: s.colour,
                      ),
                      Expanded(
                        child: Text(
                          line,
                          textDirection: directionOf(line),
                          style: type.bodySm.copyWith(
                            color: BvColors.textPrimary,
                          ),
                        ),
                      ),
                      if (s.kind == NoteStatusKind.reminder &&
                          widget.onChangeReminder != null)
                        TextButton(
                          key: const Key('note-status-change'),
                          onPressed: () {
                            _close();
                            widget.onChangeReminder!();
                          },
                          child: Text(l10n.notebookStatusChange),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: BvNotebookPagesSpec.statusGap,
    children: [
      for (final s in widget.statuses)
        Semantics(
          button: true,
          selected: _open == s.kind,
          label: s.label,
          excludeSemantics: true,
          child: InkResponse(
            key: _icons.putIfAbsent(s.kind, GlobalKey.new),
            onTap: () => _show(s),
            radius: BvNotebookPagesSpec.statusTouch / 2,
            child: KeyedSubtree(
              key: Key('note-status-${widget.id}-${s.kind.name}'),
              child: DecoratedBox(
                key: Key('note-status-${widget.id}-${s.kind.name}-disc'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _open == s.kind
                      ? BvColors.surfaceBrandSoft
                      : BvColors.surfaceSubtle,
                  border: _open == s.kind
                      ? Border.all(
                          color: BvColors.borderSelected,
                          width: BvStroke.thin,
                        )
                      : null,
                ),
                child: SizedBox.square(
                  dimension: BvNotebookPagesSpec.statusTouch,
                  child: Center(
                    child: Icon(
                      s.kind.icon,
                      size: BvNotebookPagesSpec.statusIcon,
                      color: s.colour,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
