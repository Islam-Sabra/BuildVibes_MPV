import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import 'daybook_state.dart' show daybookCardsProvider;
import 'daybook_writing.dart' show attendees;
import 'work_outbox.dart' show ThanksRefusal;

/// Who a Thanks is to (review 110 TH1): a person or a Team.
typedef ThanksTo = ({String id, String name, bool team});

/// The work item a Thanks is for, with its "KCT-016 · title" line.
typedef ThanksFor = ({String id, String label});

/// To (TH1): one sheet, the Space's Teams first, then its people (not
/// me). A pick closes it.
Future<ThanksTo?> pickThanksTo(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  required String? me,
  required String? currentId,
}) async {
  final l10n = AppLocalizations.of(context);
  final people = await ref.read(spacePeopleProvider(spaceId).future);
  if (!context.mounted) return null;
  final others = [
    for (final p in attendees(people, me: me))
      if (p.id != me) p,
  ];
  return showBvSheet<ThanksTo>(
    context: context,
    title: l10n.thanksToTitle,
    builder: (sheet) => Column(
      key: const Key('thanks-to-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (people.teams.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: BvSpace.gutter,
              top: BvSpace.s8,
              bottom: BvSpace.s4,
            ),
            child: Text(
              l10n.thanksTeams,
              style: BvType.of(
                sheet,
              ).metadata.copyWith(color: BvColors.textSecondary),
            ),
          ),
        for (final t in people.teams)
          BvListRow(
            key: Key('thanks-to-team-${t.id}'),
            title: t.name,
            leading: const BvRowIcon(BvIcons.team),
            trailing: BvRowTrailing.check(selected: t.id == currentId),
            onTap: () =>
                Navigator.of(sheet).pop((id: t.id, name: t.name, team: true)),
          ),
        BvGiveToPicker(
          people: others,
          currentOwnerId: currentId,
          searchPlaceholder: l10n.daybookAssignSearch,
          inSheet: true,
          onPick: (p) =>
              Navigator.of(sheet).pop((id: p.id, name: p.name, team: false)),
        ),
      ],
    ),
  );
}

/// For (TH1, optional): one of this Space's open work items, from the
/// cards already read. A pick closes the sheet.
Future<ThanksFor?> pickThanksFor(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  required String? currentId,
}) {
  final l10n = AppLocalizations.of(context);
  final cards = ref.read(daybookCardsProvider(spaceId)).value ?? const [];
  final open = [
    for (final c in cards)
      if (c.post.isWorkItem && c.post.isOpen) c.post,
  ];
  return showBvSheet<ThanksFor>(
    context: context,
    title: l10n.thanksForTitle,
    builder: (sheet) => Column(
      key: const Key('thanks-for-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (open.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
            child: Text(
              l10n.thanksForNone,
              style: BvType.of(
                sheet,
              ).bodyMd.copyWith(color: BvColors.textSecondary),
            ),
          ),
        for (final p in open)
          BvListRow(
            key: Key('thanks-for-${p.id}'),
            title: thanksForLabel(p.ref, p.title),
            leading: const BvRowIcon(BvIcons.confirmed),
            trailing: BvRowTrailing.check(selected: p.id == currentId),
            onTap: () => Navigator.of(
              sheet,
            ).pop((id: p.id, label: thanksForLabel(p.ref, p.title))),
          ),
      ],
    ),
  );
}

/// "KCT-016 · Fix the cracked tile", the title in its own direction.
String thanksForLabel(String? ref, String title) =>
    [?ref, inOwnDirection(title)].join(' · ');

/// A refused Thanks's plain line; the generic "Couldn't send" for the
/// unknown.
String thanksRefusalText(AppLocalizations l10n, String? why) =>
    switch (ThanksRefusal.fromName(why)) {
      ThanksRefusal.notAllowed => l10n.thanksRefusedNotAllowed,
      ThanksRefusal.signIn => l10n.thanksRefusedSignIn,
      ThanksRefusal.idTaken => l10n.thanksRefusedIdTaken,
      ThanksRefusal.noOne => l10n.thanksRefusedNoOne,
      ThanksRefusal.self => l10n.thanksRefusedSelf,
      ThanksRefusal.notMember => l10n.thanksRefusedNotMember,
      ThanksRefusal.team => l10n.thanksRefusedTeam,
      ThanksRefusal.forItem => l10n.thanksRefusedFor,
      ThanksRefusal.tooLong => l10n.thanksRefusedTooLong,
      ThanksRefusal.unknown || null => l10n.daybookCouldNotSend,
    };
