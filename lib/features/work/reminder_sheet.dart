import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_reminder_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_give_to_picker.dart' show BvGiveToPerson;
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_segmented.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../../shared/widgets/bv_writing_rows.dart';
import '../entry/entry_state.dart';
import '../notebook/notebook_page_screen.dart' show reminderWhen;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/space_errors.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart';
import 'space_day.dart';
import 'work_gestures.dart';

/// The Reminder sheet (review 108 RM1, 2701:39107): one choice, Me ·
/// Someone. Me is a notification on this phone, as before. Someone is
/// for the item's creator, its owner or a Lead: one or more people who
/// can see it (the owner chosen first), when (Tomorrow 7:00 · 1 h before
/// due, only when the item has a time · Pick…; in the Space's time zone),
/// an optional note, then Set reminder; the server sends it. Pops with
/// what to tell the person, or null.
Future<String?> showReminderSheet(
  BuildContext context, {
  required SpaceDetail space,
  required DaybookPost post,
}) => showBvSheet<String>(
  context: context,
  title: AppLocalizations.of(context).workReminder,
  builder: (sheet) => _ReminderSheet(space: space, post: post),
);

enum _Who { me, someone }

/// A time choice: tomorrow morning, 1 h before the due, or picked.
enum _When { tomorrow, beforeDue, picked }

class _ReminderSheet extends ConsumerStatefulWidget {
  const _ReminderSheet({required this.space, required this.post});

  final SpaceDetail space;
  final DaybookPost post;

  @override
  ConsumerState<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<_ReminderSheet> {
  /// "Tomorrow 7:00".
  static const _morning = BvLaterSpec.morningHour;
  static const _noteMax = 140;

  final _note = TextEditingController();
  var _who = _Who.me;
  var _when = _When.tomorrow;
  DateTime? _picked;
  List<BvGiveToPerson>? _people;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _spaceId => widget.space.id;

  /// The item's creator, its owner or a Lead may remind someone else.
  bool _maySomeone(String? me) =>
      me != null &&
      (widget.post.authorId == me ||
          widget.post.item?.ownerId == me ||
          widget.space.myPass == SpacePass.lead);

  /// Who may be reminded: Lead and Crew, of the item's Team when it has
  /// one (and the Space's admins), as Give to's.
  List<BvGiveToPerson> _candidates(SpacePeople people) {
    final team = people.teams
        .where((t) => t.id == widget.post.teamId)
        .firstOrNull;
    return [
      for (final p in assignablePeople(people))
        if (widget.post.teamId == null ||
            (team?.memberIds.contains(p.id) ?? false) ||
            (people.member(p.id)?.isAdmin ?? false))
          p,
    ];
  }

  /// Someone: the owner chosen first.
  List<BvGiveToPerson> _chosen(SpacePeople? people) {
    final kept = _people;
    if (kept != null) return kept;
    if (people == null) return const [];
    final owner = widget.post.item?.ownerId;
    return [
      for (final p in _candidates(people))
        if (p.id == owner) p,
    ];
  }

  /// The time chosen, in the Space's time zone for Someone and the
  /// phone's for Me.
  DateTime? _at(DateTime now) {
    final zone = _who == _Who.someone ? widget.space.timeZone : null;
    return switch (_when) {
      _When.tomorrow => spaceTimeOn(zone, now, days: 1, hour: _morning),
      _When.beforeDue => widget.post.dueAt?.subtract(const Duration(hours: 1)),
      // As picked, on the same clock as Tomorrow 7:00 (V3).
      _When.picked => _picked == null ? null : spaceTimeAt(zone, _picked!),
    };
  }

  Future<void> _pick(DateTime now) async {
    final picked = await ref.read(pickReminderProvider)(
      context,
      now: now,
      day: _picked == null ? null : dayOf(_picked!),
      at: _picked,
    );
    if (!mounted || picked == null || picked.day == null) return;
    final day = picked.day!;
    setState(() {
      _picked = picked.at ?? DateTime(day.year, day.month, day.day, _morning);
      _when = _When.picked;
      _error = null;
    });
  }

  Future<void> _choosePeople(SpacePeople people) async {
    final l10n = AppLocalizations.of(context);
    final candidates = _candidates(people);
    final chosen = {for (final p in _chosen(people)) p.id};
    final picked = await showBvSheet<Set<String>>(
      context: context,
      title: l10n.rmChooseWho,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheet) => Column(
          key: const Key('reminder-who-sheet'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in candidates)
              BvListRow(
                key: Key('reminder-person-${p.id}'),
                title: p.name,
                trailing: BvRowTrailing.check(selected: chosen.contains(p.id)),
                onTap: () => setSheet(
                  () => chosen.contains(p.id)
                      ? chosen.remove(p.id)
                      : chosen.add(p.id),
                ),
              ),
            const SizedBox(height: BvSpace.s12),
            BvButton(
              key: const Key('reminder-who-done'),
              label: l10n.rmDone,
              expand: true,
              onPressed: () => Navigator.of(sheet).pop(chosen),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      // In the order they are listed, the owner first when chosen.
      final owner = widget.post.item?.ownerId;
      _people = [
        for (final p in candidates)
          if (picked.contains(p.id) && p.id == owner) p,
        for (final p in candidates)
          if (picked.contains(p.id) && p.id != owner) p,
      ];
      _error = null;
    });
  }

  Future<void> _set(DateTime now, SpacePeople? people) async {
    final l10n = AppLocalizations.of(context);
    final at = _at(now);
    if (at == null || !at.isAfter(now)) {
      setState(() => _error = l10n.workRemindPast);
      return;
    }
    final navigator = Navigator.of(context);
    if (_who == _Who.me) {
      await ref
          .read(spaceRemindersProvider.notifier)
          .set(_spaceId, widget.post, at: at, body: widget.space.name);
      navigator.pop(l10n.workReminderLine(_whenWords(l10n, at, now)));
      return;
    }
    final chosen = _chosen(people);
    if (chosen.isEmpty) {
      setState(() => _error = l10n.rmChooseWho);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(workReminderRepositoryProvider)
          .set(
            id: ref.read(newPostIdProvider)(),
            postId: widget.post.id,
            people: [for (final p in chosen) p.id],
            at: at,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      ref.invalidate(postRemindersProvider(widget.post.id));
      navigator.pop(l10n.rmSetDone);
    } on SpaceException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.failure == SpaceFailure.limit
              // Review 108 V4: 20 a day.
              ? l10n.rmDailyMost
              : spaceErrorText(l10n, e),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DaybookWords _words(AppLocalizations l10n) => DaybookWords(
    l10n,
    Localizations.localeOf(context).toLanguageTag(),
    use24: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  /// "Tomorrow 7:00", "Fri 16 Oct 15:30": as a note's reminder says it.
  String _whenWords(AppLocalizations l10n, DateTime at, DateTime now) =>
      reminderWhen(l10n, _words(l10n), at, now);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final now = ref.watch(clockProvider)();
    final me = ref.watch(authUserIdProvider).value;
    final people = ref.watch(spacePeopleProvider(_spaceId)).value;
    final maySomeone = _maySomeone(me);
    final someone = maySomeone && _who == _Who.someone;
    final kept = ref
        .watch(spaceRemindersProvider.notifier)
        .of(_spaceId, widget.post.id);
    final chosen = _chosen(people);
    final clock = _words(
      l10n,
    ).time.clock(spaceTimeOn(null, now, hour: _morning));

    return Column(
      key: const Key('reminder-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s12,
      children: [
        if (maySomeone)
          BvSegmented<_Who>(
            segments: [
              BvSegment(
                key: const Key('reminder-me'),
                value: _Who.me,
                label: l10n.rmMe,
              ),
              BvSegment(
                key: const Key('reminder-someone'),
                value: _Who.someone,
                label: l10n.rmSomeone,
              ),
            ],
            value: _who,
            onChanged: (v) => setState(() {
              _who = v;
              _error = null;
            }),
          ),
        if (someone)
          BvWritingRows(
            rows: [
              BvWritingRow(
                key: const Key('reminder-who'),
                label: l10n.rmWho,
                value: chosen.isEmpty
                    ? l10n.rmChooseWho
                    : chosen.length == 1
                    ? chosen.single.name
                    : l10n.rmWhoMore(
                        inOwnDirection(chosen.first.name),
                        [for (final p in chosen.skip(1)) inOwnDirection(p.name)]
                            .join(l10n.rmSeparator),
                      ),
                person: chosen.firstOrNull?.name,
                empty: chosen.isEmpty,
                onTap: people == null ? null : () => _choosePeople(people),
              ),
            ],
          ),
        Text(
          l10n.rmWhen,
          style: type.metadata.copyWith(color: BvColors.textSecondary),
        ),
        Wrap(
          spacing: BvSpace.s8,
          runSpacing: BvSpace.s8,
          children: [
            BvChip(
              key: const Key('reminder-tomorrow'),
              label: l10n.rmTomorrowAt(clock),
              icon: BvIcons.clock,
              selected: _when == _When.tomorrow,
              onTap: () => setState(() {
                _when = _When.tomorrow;
                _error = null;
              }),
            ),
            if (widget.post.dueAt != null)
              BvChip(
                key: const Key('reminder-before-due'),
                label: l10n.rmBeforeDue,
                selected: _when == _When.beforeDue,
                onTap: () => setState(() {
                  _when = _When.beforeDue;
                  _error = null;
                }),
              ),
            BvChip(
              key: const Key('reminder-pick'),
              label: _picked == null
                  ? l10n.rmPick
                  : _whenWords(l10n, _picked!, now),
              icon: BvIcons.calendar,
              selected: _when == _When.picked,
              onTap: () => unawaited(_pick(now)),
            ),
          ],
        ),
        if (someone)
          BvTextField(
            key: const Key('reminder-note'),
            label: l10n.rmNote,
            controller: _note,
            maxLength: _noteMax,
            textCapitalization: TextCapitalization.sentences,
          ),
        if (_error != null)
          Text(
            _error!,
            key: const Key('reminder-error'),
            style: type.metadata.copyWith(color: BvColors.textDestructive),
          ),
        BvButton(
          key: const Key('reminder-set'),
          label: l10n.rmSet,
          icon: BvIcons.remind,
          expand: true,
          onPressed: _saving ? null : () => _set(now, people),
        ),
        if (!someone && kept != null)
          Center(
            child: BvButton(
              key: const Key('reminder-remove'),
              label: l10n.rmRemoveMine,
              style: BvButtonStyle.tertiary,
              onPressed: () async {
                final navigator = Navigator.of(context);
                await ref
                    .read(spaceRemindersProvider.notifier)
                    .set(_spaceId, widget.post, at: null, body: '');
                navigator.pop();
              },
            ),
          ),
        const SizedBox(height: BvSheetSpec.footerGap),
      ],
    );
  }
}
