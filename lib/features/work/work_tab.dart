import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../../shared/widgets/bv_work_item_card.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import 'work_outbox.dart';

enum WorkFilter { all, mine, open, toCheck, checked }

/// S20 v3 · Work: the project title block, the privacy line, the filter
/// chips, then Needs you, Open and Checked this week. "New item" for
/// members who can raise items.
class WorkTab extends ConsumerStatefulWidget {
  const WorkTab({super.key, required this.space});

  final SpaceDetail space;

  @override
  ConsumerState<WorkTab> createState() => _WorkTabState();
}

class _WorkTabState extends ConsumerState<WorkTab> {
  var _filter = WorkFilter.all;

  String get _spaceId => widget.space.id;

  Future<void> _refresh() async {
    ref
      ..invalidate(workItemsProvider(_spaceId))
      ..invalidate(workNeedsProvider(_spaceId));
    await ref.read(workItemsProvider(_spaceId).future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(workItemsProvider(_spaceId));
    final needs =
        ref.watch(workNeedsProvider(_spaceId)).value ?? const WorkNeeds();
    final me = ref.watch(authUserIdProvider).value;
    final now = ref.watch(clockProvider)();
    final canCreate = widget.space.myRights.createItems;

    final all = items.value;
    Widget body;
    if (all == null) {
      body = items.hasError
          ? Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: EmptyNote(l10n.errorGeneric),
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      final sections = _sections(l10n, all, needs, me, now);
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const Key('work-tab'),
          padding: const EdgeInsetsDirectional.fromSTEB(
            BvSpace.gutter,
            BvSpace.s12,
            BvSpace.gutter,
            // The last card scrolls clear of New item (review 09): the
            // button's height, 16 above it and the 16 it sits off the edge.
            BvButtonSpec.heightLarge + BvSpace.s16 * 2,
          ),
          children: [
            _ProjectHeader(space: widget.space),
            const SizedBox(height: BvSpace.s12),
            _FilterChips(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: BvSpace.s16),
            // Items made on this phone that didn't reach the server yet.
            for (final p in ref.watch(workOutboxProvider))
              if (p.spaceId == _spaceId)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: BvSpace.s12,
                  ),
                  child: _PendingCard(item: p),
                ),
            if (all.isEmpty &&
                !ref
                    .watch(workOutboxProvider)
                    .any((p) => p.spaceId == _spaceId))
              _EmptyWork(canCreate: canCreate)
            else if (all.isNotEmpty &&
                sections.every((s) => s.items.isEmpty && !s.keepEmpty))
              EmptyNote(l10n.workFilterEmpty)
            else
              for (final s in sections)
                if (s.items.isNotEmpty || s.keepEmpty) ...[
                  _SectionLabel(s.label),
                  if (s.items.isEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: BvSpace.s16,
                      ),
                      child: EmptyNote(l10n.workNothingNeedsYou),
                    ),
                  for (final item in s.items)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: BvSpace.s12,
                      ),
                      child: _ItemCard(item: item, needs: needs, me: me),
                    ),
                  const SizedBox(height: BvSpace.s4),
                ],
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: body),
        if (canCreate)
          PositionedDirectional(
            end: BvSpace.gutter,
            bottom: BvSpace.s16,
            child: BvButton(
              key: const Key('work-new-item'),
              label: l10n.workNewItem,
              icon: BvIcons.create,
              onPressed: () => context.push(AppRoutes.workNew(_spaceId)),
            ),
          ),
      ],
    );
  }

  /// The sections for the chosen filter. The server decides what needs you
  /// ([needs]); the app only sorts.
  List<_Section> _sections(
    AppLocalizations l10n,
    List<WorkItem> all,
    WorkNeeds needs,
    String? me,
    DateTime now,
  ) {
    final weekAgo = now.subtract(const Duration(days: 7));
    bool thisWeek(WorkItem i) =>
        i.checkedAt != null && i.checkedAt!.toLocal().isAfter(weekAgo);
    int byStatus(WorkItem a, WorkItem b) =>
        a.status.index.compareTo(b.status.index);

    final mine = [
      for (final i in all)
        if (i.ownerId == me || i.createdById == me) i,
    ];
    List<WorkItem> needing(List<WorkItem> from) => [
      for (final i in from)
        if (needs.needs(i.id)) i,
    ]..sort(byStatus);
    List<WorkItem> notDone(List<WorkItem> from) => [
      for (final i in from)
        if (i.status != WorkStatus.checked && !needs.needs(i.id)) i,
    ];
    List<WorkItem> checked(List<WorkItem> from, {required bool recent}) => [
      for (final i in from)
        if (i.status == WorkStatus.checked && thisWeek(i) == recent) i,
    ];

    return switch (_filter) {
      WorkFilter.all => [
        _Section(l10n.workSectionNeedsYou, needing(all), keepEmpty: true),
        _Section(l10n.workSectionOpen, notDone(all)),
        _Section(l10n.workSectionCheckedWeek, checked(all, recent: true)),
      ],
      WorkFilter.mine => [
        _Section(l10n.workSectionNeedsYou, needing(mine)),
        _Section(l10n.workSectionOpen, notDone(mine)),
        _Section(l10n.workSectionCheckedWeek, checked(mine, recent: true)),
      ],
      WorkFilter.open => [
        _Section(l10n.workSectionNeedsYou, [
          for (final i in all)
            if (needs.toSign.contains(i.id) || needs.toReassign.contains(i.id))
              i,
        ]),
        _Section(l10n.workSectionOpen, [
          for (final i in all)
            if (i.status == WorkStatus.open && !needs.needs(i.id)) i,
        ]),
      ],
      WorkFilter.toCheck => [
        _Section(l10n.workSectionNeedsYou, [
          for (final i in all)
            if (needs.toCheck.contains(i.id)) i,
        ]),
        _Section(l10n.workSectionWaitingCheck, [
          for (final i in all)
            if (i.status == WorkStatus.done && !needs.toCheck.contains(i.id)) i,
        ]),
      ],
      WorkFilter.checked => [
        _Section(l10n.workSectionCheckedWeek, checked(all, recent: true)),
        _Section(l10n.workSectionCheckedEarlier, checked(all, recent: false)),
      ],
    };
  }
}

class _Section {
  const _Section(this.label, this.items, {this.keepEmpty = false});

  final String label;
  final List<WorkItem> items;

  /// Shown with "Nothing needs you right now." when empty.
  final bool keepEmpty;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s8),
    child: Text(
      text,
      style: BvType.of(
        context,
      ).overline.copyWith(color: BvColors.textSecondary),
    ),
  );
}

/// The project title block (name, place, type) and the privacy line.
class _ProjectHeader extends ConsumerWidget {
  const _ProjectHeader({required this.space});

  final SpaceDetail space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final project = space.projectId == null
        ? null
        : ref.watch(projectProvider(space.projectId!)).value;
    final typeName = project?.typeName?.of(Localizations.localeOf(context));

    return DecoratedBox(
      key: const Key('work-project-header'),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvRadius.cardAll,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvSpace.s8,
          children: [
            if (space.projectId != null) ...[
              Row(
                spacing: BvSpace.s12,
                children: [
                  BvProjectAvatar(id: space.projectId!, icon: BvIcons.crane),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project?.name ?? space.projectName ?? '',
                          style: type.titleMd,
                        ),
                        if ((project?.location(lang) ?? '').isNotEmpty)
                          Text(
                            project!.location(lang)!,
                            style: type.bodySm.copyWith(
                              color: BvColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (typeName != null)
                    BvBadge(
                      label: lang == 'ar' ? typeName : typeName.toUpperCase(),
                      tone: BvBadgeTone.brand,
                    ),
                ],
              ),
              const Divider(
                height: BvStroke.thin,
                thickness: BvStroke.thin,
                color: BvColors.borderDefault,
              ),
            ],
            Text(
              l10n.workPrivacyLine,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});

  final WorkFilter value;
  final ValueChanged<WorkFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(WorkFilter f) => switch (f) {
      WorkFilter.all => l10n.workFilterAll,
      WorkFilter.mine => l10n.workFilterMine,
      WorkFilter.open => l10n.workFilterOpen,
      WorkFilter.toCheck => l10n.workFilterToCheck,
      WorkFilter.checked => l10n.workFilterChecked,
    };
    // One single choice; scrolls sideways on narrow phones.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: BvSpace.s8,
        children: [
          for (final f in WorkFilter.values)
            BvChip(
              key: Key('work-filter-${f.name}'),
              label: label(f),
              selected: f == value,
              onTap: () => onChanged(f),
            ),
        ],
      ),
    );
  }
}

class _EmptyWork extends StatelessWidget {
  const _EmptyWork({required this.canCreate});

  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return ProfileCard(
      child: Column(
        key: const Key('work-empty'),
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s8,
        children: [
          Text(l10n.workEmptyTitle, style: type.titleMd),
          EmptyNote(canCreate ? l10n.workEmptyCanCreate : l10n.workEmptyCannot),
        ],
      ),
    );
  }
}

/// One item on BvWorkItemCard: reference and Team, status, title, place,
/// owner and creator, evidence, and the action the server says is yours.
class _ItemCard extends ConsumerWidget {
  const _ItemCard({required this.item, required this.needs, required this.me});

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
        : l10n.workOwner(item.ownerName ?? '');
    final second = item.status == WorkStatus.checked
        ? l10n.workCheckedByLine(item.checkedByName ?? '')
        : item.createdById == me
        ? l10n.workFromYou
        : l10n.workFrom(item.createdByName ?? '');

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
        l10n.workCheckedBy(item.checkedByName ?? ''),
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

/// "Not sent yet · Retry": a new item kept on this phone after a weak
/// signal, with its photo. Nothing is lost.
class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard({required this.item});

  final PendingItem item;

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  var _busy = false;

  Future<void> _retry() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final sent = await ref
        .read(workOutboxProvider.notifier)
        .retry(widget.item.id);
    // Once sent, this card is gone; the message still shows.
    if (mounted) setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(sent ? l10n.workSent : l10n.workNotSentNote)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return ProfileCard(
      child: Column(
        key: Key('work-pending-${widget.item.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s4,
        children: [
          Text(
            widget.item.kind == PendingKind.signDone
                ? l10n.workPendingSignOff
                : l10n.workNotSent,
            style: type.overline.copyWith(color: BvColors.textWarning),
          ),
          Text(widget.item.title, style: type.titleMd),
          Text(
            joinMeta([
              l10n.workOwner(widget.item.ownerName),
              if (widget.item.photos.isNotEmpty)
                l10n.workPhotos(widget.item.photos.length),
            ]),
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
          EmptyNote(l10n.workNotSentNote),
          BvButton(
            key: Key('work-retry-${widget.item.id}'),
            label: l10n.workRetry,
            style: BvButtonStyle.secondary,
            size: BvButtonSize.medium,
            onPressed: _busy ? null : _retry,
          ),
        ],
      ),
    );
  }
}
