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

/// What an entry's status icon says (review 104 N12), in this order.
enum NoteStatusKind { pinned, reminder, feed, space, message }

/// One status of an entry: its icon (the glyph of its action), what a
/// screen reader says, and the line its card shows.
@immutable
class NoteStatus {
  const NoteStatus(
    this.kind, {
    required this.icon,
    required this.label,
    required this.detail,
    this.colour = BvColors.iconSecondary,
  });

  final NoteStatusKind kind;
  final IconData icon;
  final String label;
  final String detail;
  final Color colour;
}

/// [note]'s statuses: pinned; a reminder (the accent colour while it is
/// still to ring, grey after); its latest share to the feed, to a Space
/// (or put in one) and to a person.
List<NoteStatus> noteStatuses(
  Note note,
  AppLocalizations l10n,
  DaybookWords words,
  DateTime now,
) {
  NoteShare? last(NoteShareTarget target) =>
      note.shares.where((s) => s.target == target).lastOrNull;
  final feed = last(NoteShareTarget.feed);
  final space = last(NoteShareTarget.space);
  final sent = last(NoteShareTarget.message);
  final remind = note.kind == NoteKind.voice ? null : note.remindAt;
  final put = space == null && note.putInPostId != null && !note.waiting;
  return [
    if (note.pinned)
      NoteStatus(
        NoteStatusKind.pinned,
        icon: BvIcons.pin,
        label: l10n.notebookPinnedLabel,
        detail: l10n.notebookPinnedLabel,
      ),
    if (remind != null)
      NoteStatus(
        NoteStatusKind.reminder,
        icon: BvIcons.remind,
        label: l10n.notebookStatusReminder(
          reminderWhen(l10n, words, remind, now),
        ),
        detail: l10n.notebookReminderLine(
          reminderWhen(l10n, words, remind, now),
        ),
        colour: remindsAt(note, now)
            ? BvColors.iconAction
            : BvColors.iconSecondary,
      ),
    if (feed != null)
      NoteStatus(
        NoteStatusKind.feed,
        icon: BvIcons.feed,
        label: l10n.notebookStatusFeed(words.time.clock(feed.at)),
        detail: l10n.notebookMarkFeed(words.time.clock(feed.at)),
      ),
    if (space != null)
      NoteStatus(
        NoteStatusKind.space,
        icon: BvIcons.team,
        label: l10n.notebookStatusSpace(
          space.name ?? '',
          words.time.clock(space.at),
        ),
        detail: l10n.notebookMarkTo(
          space.name ?? '',
          words.time.clock(space.at),
        ),
      )
    else if (put)
      NoteStatus(
        NoteStatusKind.space,
        icon: BvIcons.team,
        label: l10n.notebookPut,
        detail: l10n.notebookPut,
      ),
    if (sent != null)
      NoteStatus(
        NoteStatusKind.message,
        icon: BvIcons.chat,
        label: l10n.notebookStatusSent(
          sent.name ?? '',
          words.time.clock(sent.at),
        ),
        detail: l10n.notebookMarkSent(
          sent.name ?? '',
          words.time.clock(sent.at),
        ),
      ),
  ];
}

/// An entry's status icons at the top end of its card (review 104 N12):
/// 14, grey, 4 apart; at most three, and past three the third is "+N". A
/// tap opens a compact card with the detail ("+N": the rest); a
/// reminder's has Change ([onChangeReminder]).
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
  final _row = GlobalKey();

  @override
  void dispose() {
    _card.hide();
    super.dispose();
  }

  void _open(List<NoteStatus> shown) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    _card.show(
      context,
      anchor: () => _row.currentContext,
      atEnd: true,
      barrier: true,
      gap: BvLineMenuSpec.menuGap,
      onDismiss: _card.hide,
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
              for (final s in shown)
                Padding(
                  padding: BvLineMenuSpec.rowPadding,
                  child: Row(
                    spacing: BvLineMenuSpec.rowGap,
                    children: [
                      Icon(
                        s.icon,
                        size: BvNotebookPagesSpec.statusIcon,
                        color: s.colour,
                      ),
                      Expanded(
                        child: Text(
                          s.detail,
                          textDirection: directionOf(s.detail),
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
                            _card.hide();
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final all = widget.statuses;
    const most = BvNotebookPagesSpec.statusMax;
    final icons = all.length > most ? all.take(most - 1).toList() : all;
    final rest = all.length > most
        ? all.skip(most - 1).toList()
        : const <NoteStatus>[];
    Widget tap({
      required String key,
      required String label,
      required List<NoteStatus> shown,
      required Widget child,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        key: Key(key),
        onTap: () => _open(shown),
        radius: BvNotebookPagesSpec.statusTouch / 2,
        child: SizedBox(
          height: BvNotebookPagesSpec.statusTouch,
          child: Center(child: child),
        ),
      ),
    );
    return Row(
      key: _row,
      mainAxisSize: MainAxisSize.min,
      spacing: BvNotebookPagesSpec.statusGap,
      children: [
        for (final s in icons)
          tap(
            key: 'note-status-${widget.id}-${s.kind.name}',
            label: s.label,
            shown: [s],
            child: Icon(
              s.icon,
              size: BvNotebookPagesSpec.statusIcon,
              color: s.colour,
            ),
          ),
        if (rest.isNotEmpty)
          tap(
            key: 'note-status-${widget.id}-more',
            label: l10n.notebookStatusMore(rest.length),
            shown: rest,
            child: Text(
              l10n.daybookFacesMore(rest.length),
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
          ),
      ],
    );
  }
}
