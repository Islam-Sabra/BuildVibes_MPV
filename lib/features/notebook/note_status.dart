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

  /// A share: it has an older version (review 106 T5) and Share again.
  bool get share => this == feed || this == space || this == message;

  /// Review 106 T4: a held entry's icon not used yet, read as its action.
  String action(AppLocalizations l10n) => switch (this) {
    pinned => l10n.notebookPin,
    reminder => l10n.notebookActRemind,
    feed => l10n.notebookActFeed,
    space => l10n.notebookActSpace,
    message => l10n.notebookActMessage,
  };

  /// What a tap on a used one does again: unpin, change the reminder,
  /// share again.
  String again(AppLocalizations l10n) => switch (this) {
    pinned => l10n.daybookUnpin,
    reminder => l10n.notebookChangeReminder,
    _ => l10n.notebookShareAgain,
  };
}

/// [note]'s shares to [target] that can be shown, oldest first: a Space or
/// a person with no name is left out, never shown blank (review 104 F3).
List<NoteShare> _shown(Note note, NoteShareTarget target) => [
  for (final s in note.shares)
    if (s.target == target &&
        (target == NoteShareTarget.feed ||
            (s.name?.trim().isNotEmpty ?? false)))
      s,
]..sort((a, b) => a.at.compareTo(b.at));

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

/// Review 106 T4: the actions a held entry offers, in the row's order: all
/// five (a voice note has no reminder).
List<NoteStatusKind> holdKinds(Note note) => [
  for (final k in NoteStatusKind.values)
    if (k != NoteStatusKind.reminder || note.kind != NoteKind.voice) k,
];

/// One line of a status card: a share, and whether it is of an older
/// version than the entry is now (review 106 T5).
typedef NoteStatusLine = ({String text, bool older});

/// One status of an entry: its kind, what a screen reader says (the
/// latest of its kind, as review 104), the lines its card lists (every
/// share of the kind, review 106 T1), its icon's colour, and whether its
/// last share is older than the entry (T5: the dot).
@immutable
class NoteStatus {
  const NoteStatus(
    this.kind, {
    required this.label,
    this.lines = const [],
    this.colour = BvColors.iconSecondary,
    this.older = false,
    this.changed,
  });

  final NoteStatusKind kind;
  final String label;
  final List<NoteStatusLine> lines;
  final Color colour;
  final bool older;

  /// When the entry last changed, for "changed at {time}".
  final String? changed;
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
  final changedAt = note.contentChangedAt;
  // Review 106 T5: made before the entry's content last changed.
  bool older(NoteShare s) => changedAt != null && s.at.isBefore(changedAt);
  NoteStatus shares(NoteStatusKind kind, List<NoteShare> list, String label) =>
      NoteStatus(
        kind,
        label: label,
        lines: [
          for (final s in list)
            (
              text: kind == NoteStatusKind.feed ? clock(s) : named(s),
              older: older(s),
            ),
        ],
        older: older(list.last),
        changed: changedAt == null ? null : words.time.clock(changedAt),
      );
  NoteStatus status(NoteStatusKind kind) {
    switch (kind) {
      case NoteStatusKind.pinned:
        return NoteStatus(kind, label: l10n.notebookPinnedLabel);
      case NoteStatusKind.reminder:
        final when = reminderWhen(l10n, words, note.remindAt!, now);
        return NoteStatus(
          kind,
          label: l10n.notebookStatusReminder(when),
          lines: [(text: l10n.notebookReminderLine(when), older: false)],
          colour: remindsAt(note, now)
              ? BvColors.iconAction
              : BvColors.iconSecondary,
        );
      case NoteStatusKind.feed:
        final feed = _shown(note, NoteShareTarget.feed);
        return shares(kind, feed, l10n.notebookStatusFeed(clock(feed.last)));
      case NoteStatusKind.space:
        final spaces = _shown(note, NoteShareTarget.space);
        if (spaces.isEmpty) {
          return NoteStatus(
            kind,
            label: l10n.notebookPut,
            lines: [(text: l10n.notebookPut, older: false)],
          );
        }
        return shares(
          kind,
          spaces,
          l10n.notebookStatusSpace(
            spaces.last.name!.trim(),
            clock(spaces.last),
          ),
        );
      case NoteStatusKind.message:
        final sent = _shown(note, NoteShareTarget.message);
        return shares(
          kind,
          sent,
          l10n.notebookStatusSent(sent.last.name!.trim(), clock(sent.last)),
        );
    }
  }

  return [for (final kind in statusKinds(note)) status(kind)];
}

/// What a status icon's tap asks of the page: [kind]'s action, the icon
/// [anchor] the share steps open next to.
typedef NoteStatusAct =
    void Function(NoteStatusKind kind, BuildContext? Function() anchor);

/// An entry's status row (review 106 T1): one round icon per status, at
/// the end of the entry. A tap opens a compact card under the icon listing
/// every share of its kind; the icon shows selected while it is open; a
/// reminder's card has Change ([onChangeReminder]); a share older than the
/// entry has a dot, and its card Share again ([onShareAgain], T5).
///
/// [actions] (T4, one entry held): every kind of [holdKinds], the used
/// ones filled and the others outlined, "Tap to do it" at the start; a tap
/// does it ([onAction]).
class NoteStatusIcons extends StatefulWidget {
  const NoteStatusIcons({
    super.key,
    required this.id,
    required this.statuses,
    this.onChangeReminder,
    this.onShareAgain,
    this.actions,
    this.onAction,
  });

  final String id;
  final List<NoteStatus> statuses;
  final VoidCallback? onChangeReminder;
  final NoteStatusAct? onShareAgain;
  final List<NoteStatusKind>? actions;
  final NoteStatusAct? onAction;

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

  BuildContext? Function() _anchor(NoteStatusKind kind) =>
      () => _icons[kind]?.currentContext;

  void _show(NoteStatus s) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final again = widget.onShareAgain;
    setState(() => _open = s.kind);
    _card.show(
      context,
      anchor: _anchor(s.kind),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.text,
                              textDirection: directionOf(line.text),
                              style: type.bodySm.copyWith(
                                color: BvColors.textPrimary,
                              ),
                            ),
                            // Review 106 T5: sent before the entry changed.
                            if (line.older && s.changed != null)
                              Text(
                                l10n.notebookOlderVersion(s.changed!),
                                style: type.metadata.copyWith(
                                  color: BvColors.textAction,
                                ),
                              ),
                          ],
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
              // Review 106 T5: the entry as it is now, the same step.
              if (s.kind.share && s.older && again != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: BvLineMenuSpec.padding,
                  ),
                  child: Material(
                    color: BvColors.surfaceBrandSoft,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const Key('note-status-share-again'),
                      onTap: () {
                        _close();
                        again(s.kind, _anchor(s.kind));
                      },
                      child: Padding(
                        padding: BvLineMenuSpec.rowPadding,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: BvLineMenuSpec.rowGap,
                          children: [
                            const Icon(
                              BvIcons.shareAgain,
                              size: BvNotebookPagesSpec.statusIcon,
                              color: BvColors.textAction,
                            ),
                            Text(
                              l10n.notebookShareAgain,
                              style: type.labelMd.copyWith(
                                color: BvColors.textAction,
                              ),
                            ),
                          ],
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

  /// One round icon: [used] filled (or selected while its card is open),
  /// else outlined (T4); [dot], its share older than the entry (T5).
  Widget _icon(
    NoteStatusKind kind, {
    required bool used,
    required String label,
    required Color colour,
    required bool dot,
    required VoidCallback onTap,
  }) {
    final open = _open == kind;
    final key = 'note-status-${widget.id}-${kind.name}';
    return Semantics(
      button: true,
      selected: open,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        key: _icons.putIfAbsent(kind, GlobalKey.new),
        onTap: onTap,
        radius: BvNotebookPagesSpec.statusTouch / 2,
        child: KeyedSubtree(
          key: Key(key),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                key: Key('$key-disc'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: open
                      ? BvColors.surfaceBrandSoft
                      : used
                      ? BvColors.surfaceSubtle
                      : BvColors.surfaceElevated,
                  border: open
                      ? Border.all(
                          color: BvColors.borderSelected,
                          width: BvStroke.thin,
                        )
                      : used
                      ? null
                      : Border.all(
                          color: BvColors.borderSubtle,
                          width: BvStroke.thin,
                        ),
                ),
                child: SizedBox.square(
                  dimension: BvNotebookPagesSpec.statusTouch,
                  child: Center(
                    child: Icon(
                      kind.icon,
                      size: BvNotebookPagesSpec.statusIcon,
                      color: colour,
                    ),
                  ),
                ),
              ),
              if (dot)
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: DecoratedBox(
                    key: Key('$key-dot'),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BvColors.iconAction,
                      border: Border.all(
                        color: BvColors.surfaceElevated,
                        width: BvStroke.thin,
                      ),
                    ),
                    child: const SizedBox.square(
                      dimension: BvNotebookPagesSpec.statusDot,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = widget.actions;
    if (actions == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvNotebookPagesSpec.statusGap,
        children: [
          for (final s in widget.statuses)
            _icon(
              s.kind,
              used: true,
              label: s.label,
              colour: s.colour,
              dot: s.older,
              onTap: () => _show(s),
            ),
        ],
      );
    }
    final used = {for (final s in widget.statuses) s.kind: s};
    return Row(
      key: Key('note-status-${widget.id}-row'),
      spacing: BvNotebookPagesSpec.statusGap,
      children: [
        Expanded(
          child: Text(
            l10n.notebookTapToDo,
            style: BvType.of(
              context,
            ).metadata.copyWith(color: BvColors.textSecondary),
          ),
        ),
        for (final k in actions)
          _icon(
            k,
            used: used.containsKey(k),
            label: used[k] == null
                ? k.action(l10n)
                : l10n.notebookStatusThen(used[k]!.label, k.again(l10n)),
            colour: used[k]?.colour ?? BvColors.iconPrimary,
            dot: used[k]?.older ?? false,
            onTap: () => widget.onAction?.call(k, _anchor(k)),
          ),
      ],
    );
  }
}
