import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../../shared/widgets/bv_work_item_card.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;

/// One item on BvWorkItemCard: reference and Team, status, title, place,
/// owner and creator, evidence, and the action the server says is yours.
/// The Work tab and chat cards (S8k) use it.
class WorkItemCard extends ConsumerWidget {
  const WorkItemCard({
    super.key,
    required this.item,
    required this.needs,
    required this.me,
  });

  final WorkItem item;
  final WorkNeeds needs;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final now = ref.watch(clockProvider)();
    String day(DateTime d) {
      final text = BvWesternDigitsFormatter.normalise(
        DateFormat('EEE d MMM', locale).format(d.toLocal()),
      );
      return ar ? text : text.toUpperCase();
    }

    final overdue = item.overdue(now);
    final status = switch (item.status) {
      WorkStatus.open => overdue ? BvWorkStatus.overdue : BvWorkStatus.open,
      WorkStatus.done => BvWorkStatus.done,
      WorkStatus.checked => BvWorkStatus.checked,
    };
    final statusLine = switch (item.status) {
      WorkStatus.open when needs.toReassign.contains(item.id) =>
        l10n.workStatusOwnerLeft,
      WorkStatus.open when overdue => l10n.workStatusOverdue(day(item.due!)),
      WorkStatus.open when item.due != null => l10n.workStatusOpenDue(
        day(item.due!),
      ),
      WorkStatus.open => l10n.workStatusOpen,
      WorkStatus.done when needs.toCheck.contains(item.id) =>
        l10n.workStatusDoneYouCheck,
      WorkStatus.done => l10n.workStatusDoneWaiting,
      WorkStatus.checked => l10n.workStatusChecked(day(item.checkedAt!)),
    };

    final owner = item.ownerId == me
        ? l10n.workOwnerYou
        : l10n.workOwner(inOwnDirection(item.ownerName ?? ''));
    final second = item.status == WorkStatus.checked
        ? l10n.workCheckedByLine(inOwnDirection(item.checkedByName ?? ''))
        : item.createdById == me
        ? l10n.workFromYou
        : l10n.workFrom(inOwnDirection(item.createdByName ?? ''));

    final photos = item.photoPaths.length;
    final quote = item.doneNote == null
        ? null
        : ar
        ? '«${item.doneNote}»'
        : '“${item.doneNote}”';
    final evidenceText = switch (item.status) {
      WorkStatus.done => joinMeta([
        if (photos > 0) l10n.workPhotos(photos),
        ?quote,
      ]),
      WorkStatus.checked => joinMeta([
        l10n.workCheckedBy(inOwnDirection(item.checkedByName ?? '')),
        if (photos > 0) l10n.workPhotos(photos),
      ]),
      WorkStatus.open => '',
    };
    final photoUrl = photos == 0
        ? null
        : ref.watch(workPhotoUrlProvider(item.photoPaths.first)).value;

    final action = needs.toSign.contains(item.id)
        ? l10n.workSignAsDone
        : needs.toReassign.contains(item.id)
        ? l10n.workReassign
        : needs.toCheck.contains(item.id)
        ? l10n.workCheckIt
        : null;
    void open() => context.push(AppRoutes.workItem(item.spaceId, item.id));

    return BvWorkItemCard(
      key: Key('work-item-${item.id}'),
      reference: [
        item.ref,
        if (item.teamName != null)
          ar ? item.teamName! : item.teamName!.toUpperCase(),
      ].join(' · '),
      status: status,
      statusLine: statusLine,
      title: item.title,
      place: item.place,
      people: joinMeta([owner, second]),
      evidence: item.status == WorkStatus.open
          ? null
          : BvWorkEvidence(
              text: evidenceText,
              photo: photoUrl == null ? null : NetworkImage(photoUrl),
              hasPhoto: photos > 0,
            ),
      actionLabel: action,
      onAction: action == null ? null : open,
      onTap: open,
    );
  }
}
