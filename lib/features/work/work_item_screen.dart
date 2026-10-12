import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/ago.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_sign_off_strip.dart';
import '../../shared/widgets/bv_site_photo.dart';
import '../../shared/widgets/bv_site_tag.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_errors.dart';

/// W3a–g · the item page: the site tag, the banner for this state and
/// your role, evidence, the sign-off strip, Discussion, and your action.
/// What you may do comes from the server (needs_you).
class WorkItemScreen extends ConsumerStatefulWidget {
  const WorkItemScreen({
    super.key,
    required this.spaceId,
    required this.itemId,
  });

  final String spaceId;
  final String itemId;

  @override
  ConsumerState<WorkItemScreen> createState() => _WorkItemScreenState();
}

class _WorkItemScreenState extends ConsumerState<WorkItemScreen> {
  final _comment = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _refresh() => ref
    ..invalidate(workItemDetailProvider(widget.itemId))
    ..invalidate(workItemsProvider(widget.spaceId))
    ..invalidate(workNeedsProvider(widget.spaceId))
    ..invalidate(mySpacesProvider);

  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(workRepositoryProvider).addComment(widget.itemId, text);
      _comment.clear();
      ref.invalidate(workItemDetailProvider(widget.itemId));
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reassign(WorkItem item, List<SpaceMember> members) async {
    final l10n = AppLocalizations.of(context);
    final candidates = [
      for (final m in members)
        if (m.pass != SpacePass.viewer && m.person.id != item.ownerId) m,
    ];
    final picked = await showBvSheet<SpaceMember>(
      context: context,
      title: l10n.workReassignTitle,
      builder: (sheetContext) => BvChoiceList<String>(
        value: null,
        options: [
          for (final m in candidates)
            BvChoiceOption(
              key: Key('reassign-${m.person.id}'),
              value: m.person.id,
              title: m.person.fullName,
            ),
        ],
        onChanged: (id) => Navigator.of(
          sheetContext,
        ).pop(candidates.firstWhere((m) => m.person.id == id)),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await ref
          .read(workRepositoryProvider)
          .reassign(item.id, picked.person.id);
      _refresh();
      if (mounted) {
        showSpaceMessage(context, l10n.workReassigned(picked.person.fullName));
      }
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
  }

  /// Sign as done (W4), Check and close, and Send back (W5) are built in
  /// week 5 part 3.
  Future<void> _comingNext() => showBvSheet<void>(
    context: context,
    builder: (_) => EmptyNote(AppLocalizations.of(context).placeholderBody),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final me = ref.watch(authUserIdProvider).value;
    final now = ref.watch(clockProvider)();
    final space = ref.watch(spaceDetailProvider(widget.spaceId)).value;
    final people = ref.watch(spacePeopleProvider(widget.spaceId)).value;
    final needs =
        ref.watch(workNeedsProvider(widget.spaceId)).value ?? const WorkNeeds();
    final detail = ref.watch(workItemDetailProvider(widget.itemId));
    final d = detail.value;

    String day(DateTime t) => BvWesternDigitsFormatter.normalise(
      DateFormat('EEE d MMM', locale).format(t.toLocal()),
    );
    String stampDay(DateTime t) => BvWesternDigitsFormatter.normalise(
      DateFormat('d MMM', locale).format(t.toLocal()),
    );
    String when(DateTime t) {
      final local = t.toLocal();
      final time = BvWesternDigitsFormatter.normalise(
        DateFormat.Hm(locale).format(local),
      );
      return DateUtils.isSameDay(local, now)
          ? l10n.workTodayAt(time)
          : '${day(local)} $time';
    }

    String who(String? id, String? name) =>
        id != null && id == me ? l10n.spacesYouTag : (name ?? '—');

    final appBar = AppBar(
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            d?.item.ref ?? '',
            textDirection: TextDirection.ltr,
            style: type.titleLg,
          ),
          if (space != null)
            Text(
              space.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
        ],
      ),
      actions: [
        // Reassign, for the creator and members who may check, while Open.
        if (d != null &&
            d.item.status == WorkStatus.open &&
            people != null &&
            (d.item.createdById == me || (space?.myRights.checkItems ?? false)))
          IconButton(
            key: const Key('work-item-more'),
            tooltip: l10n.workReassignTitle,
            icon: const Icon(BvIcons.more),
            onPressed: () => _reassign(d.item, people.members),
          ),
      ],
    );

    if (d == null) {
      return Scaffold(
        appBar: appBar,
        body: detail.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                child: EmptyNote(l10n.workItemGone),
              ),
      );
    }

    final item = d.item;
    final lastDone = d.lastDone;
    final toSign = needs.toSign.contains(item.id);
    final toCheck = needs.toCheck.contains(item.id);
    final ownerLeft = needs.toReassign.contains(item.id);
    String first(String? name) => (name ?? '').split(' ').first;

    // The banner for this state and your role (W3a–g).
    Widget? banner;
    if (ownerLeft) {
      banner = _Banner(
        tone: _BannerTone.warning,
        title: l10n.workOwnerLeftTitle,
        body: l10n.workOwnerLeftBody,
        action: people == null
            ? null
            : BvButton(
                key: const Key('work-banner-reassign'),
                label: l10n.workReassign,
                style: BvButtonStyle.secondary,
                size: BvButtonSize.medium,
                onPressed: () => _reassign(item, people.members),
              ),
      );
    } else if (item.status == WorkStatus.open && d.sentBack != null) {
      final reason = switch (d.sentBack!.reason) {
        SendBackReason.photoMissing => l10n.workReasonPhotoMissing,
        SendBackReason.notAsDrawing => l10n.workReasonNotAsDrawing,
        SendBackReason.notFinished => l10n.workReasonNotFinished,
        SendBackReason.other || null => l10n.workReasonOther,
      };
      banner = _Banner(
        tone: _BannerTone.destructive,
        title: l10n.workSentBackTitle(reason),
        body: d.sentBack!.note,
      );
    } else if (item.status == WorkStatus.done) {
      banner = toCheck
          ? _Banner(
              tone: _BannerTone.action,
              title: l10n.workCheckBannerTitle(first(item.ownerName)),
              body: l10n.workCheckBannerBody,
            )
          : item.ownerId == me
          ? _Banner(
              title: l10n.workWaitingCheckBy(item.createdByName ?? ''),
              body: l10n.workWaitingCheckBody,
            )
          : _Banner(title: l10n.workDoneWaiting);
    } else if (item.status == WorkStatus.checked) {
      final closedByYou = item.checkedById == me || item.createdById == me;
      banner = _Banner(
        tone: _BannerTone.positive,
        title: closedByYou
            ? l10n.workClosed
            : l10n.workClosedBy(item.checkedByName ?? ''),
        body: closedByYou && item.ownerId != me
            ? l10n.workClosedCanShow(first(item.ownerName))
            : l10n.workClosedStays,
      );
    }

    // Evidence: the Done photos and note; for an Open item, the photos
    // from when it was raised.
    final done = item.status != WorkStatus.open ? lastDone : null;
    final photos =
        done?.photos ??
        (item.status == WorkStatus.open ? d.raisedPhotos : const <WorkPhoto>[]);
    final photoBy = done ?? d.last(WorkEventKind.raised);

    final raised = d.last(WorkEventKind.raised);
    final checked = d.last(WorkEventKind.checked);

    Widget? footer;
    if (toSign) {
      footer = BvButton(
        key: const Key('work-sign-done'),
        label: l10n.workSignAsDone,
        expand: true,
        onPressed: _comingNext,
      );
    } else if (toCheck) {
      footer = Row(
        spacing: BvSpace.s12,
        children: [
          Expanded(
            child: BvButton(
              key: const Key('work-send-back'),
              label: l10n.workSendBack,
              style: BvButtonStyle.secondary,
              expand: true,
              onPressed: _comingNext,
            ),
          ),
          Expanded(
            child: BvButton(
              key: const Key('work-check'),
              label: l10n.workCheckAndClose,
              expand: true,
              onPressed: _comingNext,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: appBar,
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await ref.read(workItemDetailProvider(widget.itemId).future);
        },
        child: ListView(
          key: const Key('work-item'),
          padding: const EdgeInsetsDirectional.fromSTEB(
            BvSpace.gutter,
            BvSpace.s8,
            BvSpace.gutter,
            BvSpace.s32,
          ),
          children: [
            BvSiteTag(
              itemId: item.ref,
              team: item.teamName == null
                  ? ''
                  : ar
                  ? item.teamName!
                  : item.teamName!.toUpperCase(),
              title: item.title,
              place: item.place ?? '',
              from: who(item.createdById, item.createdByName),
              owner: who(item.ownerId, item.ownerName),
              due: item.due == null ? '—' : day(item.due!),
              overdue: item.overdue(now),
              checkedStamp:
                  item.status == WorkStatus.checked && item.checkedAt != null
                  ? l10n.workCheckedStamp(
                      ar
                          ? stampDay(item.checkedAt!)
                          : stampDay(item.checkedAt!).toUpperCase(),
                      ar
                          ? _short(item.checkedByName)
                          : _short(item.checkedByName).toUpperCase(),
                    )
                  : null,
            ),
            if (banner != null) ...[
              const SizedBox(height: BvSpace.s16),
              banner,
            ],
            if (photos.isNotEmpty || (done?.note ?? '').isNotEmpty) ...[
              const SizedBox(height: BvSpace.s16),
              _Label(done != null ? l10n.workEvidence : l10n.workPhotosLabel),
              for (final p in photos) ...[
                _Photo(
                  photo: p,
                  stamp: joinMeta([
                    ?(p.place ?? item.place),
                    if (p.takenAt != null)
                      BvWesternDigitsFormatter.normalise(
                        DateFormat.Hm(locale).format(p.takenAt!.toLocal()),
                      ),
                    who(photoBy?.actorId, photoBy?.actorName),
                  ]),
                ),
                const SizedBox(height: BvSpace.s8),
              ],
              if ((done?.note ?? '').isNotEmpty)
                UserText(
                  ar ? '«${done!.note}»' : '“${done!.note}”',
                  style: type.bodyMd,
                ),
            ],
            const SizedBox(height: BvSpace.s16),
            // The strip has its own SIGN-OFF heading.
            BvSignOffStrip(
              key: const Key('work-sign-off'),
              steps: [
                BvSignOffStep(
                  kind: BvSignOffStepKind.raised,
                  person: who(item.createdById, item.createdByName),
                  when: raised == null ? null : day(raised.at),
                ),
                BvSignOffStep(
                  kind: BvSignOffStepKind.done,
                  person: done == null
                      ? null
                      : who(done.actorId, done.actorName),
                  when: done == null ? null : when(done.at),
                ),
                BvSignOffStep(
                  kind: BvSignOffStepKind.checked,
                  person: checked == null
                      ? null
                      : who(checked.actorId, checked.actorName),
                  waitingFor: toCheck ? l10n.workYouCheckIt : null,
                  when: checked == null ? null : when(checked.at),
                ),
              ],
            ),
            const SizedBox(height: BvSpace.s16),
            _Label(l10n.workDiscussion),
            if (d.comments.isEmpty)
              EmptyNote(l10n.workNoComments)
            else
              for (final c in d.comments) ...[
                _Comment(
                  name: who(c.actorId, c.actorName),
                  ago: formatAgo(l10n, c.at.toLocal(), now),
                  text: c.note ?? '',
                ),
                const SizedBox(height: BvSpace.s12),
              ],
            const SizedBox(height: BvSpace.s8),
            Row(
              spacing: BvSpace.s8,
              children: [
                Expanded(
                  child: BvTextField(
                    key: const Key('work-comment'),
                    placeholder: l10n.workAddComment,
                    controller: _comment,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                BvButton(
                  key: const Key('work-comment-send'),
                  label: l10n.workSendComment,
                  style: BvButtonStyle.tertiary,
                  size: BvButtonSize.medium,
                  onPressed: _sending || _comment.text.trim().isEmpty
                      ? null
                      : _sendComment,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: footer == null
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: BvColors.surfaceApp,
                border: Border(
                  top: BorderSide(
                    color: BvColors.borderDefault,
                    width: BvSpace.borderWidth,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: BvSpace.gutter,
                    vertical: BvSpace.s12,
                  ),
                  child: footer,
                ),
              ),
            ),
    );
  }
}

/// "Sami Al-Mansour" -> "S. Al-Mansour", short enough for the stamp.
String _short(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return parts.join();
  return '${parts.first.characters.first}. ${parts.sublist(1).join(' ')}';
}

class _Label extends StatelessWidget {
  const _Label(this.text);

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

enum _BannerTone { neutral, action, positive, warning, destructive }

/// The status banner (W3b, W3c, W3d, W3g).
class _Banner extends StatelessWidget {
  const _Banner({
    required this.title,
    this.body,
    this.tone = _BannerTone.neutral,
    this.action,
  });

  final String title;
  final String? body;
  final _BannerTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final (fill, ink) = switch (tone) {
      _BannerTone.neutral => (BvColors.surfaceSubtle, BvColors.textPrimary),
      _BannerTone.action => (BvColors.surfaceBrandSoft, BvColors.textAction),
      _BannerTone.positive => (BvColors.surfaceSubtle, BvColors.textPositive),
      _BannerTone.warning => (BvColors.surfaceSubtle, BvColors.textWarning),
      _BannerTone.destructive => (
        BvColors.surfaceBrandSoft,
        BvColors.textDestructive,
      ),
    };
    return DecoratedBox(
      key: const Key('work-banner'),
      decoration: BoxDecoration(color: fill, borderRadius: BvRadius.controlAll),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BvSpace.s4,
          children: [
            Text(title, style: type.labelMd.copyWith(color: ink)),
            if ((body ?? '').isNotEmpty)
              Text(
                body!,
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
            if (action != null) ...[
              const SizedBox(height: BvSpace.s4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A photo on a signed link, with its site stamp.
class _Photo extends ConsumerWidget {
  const _Photo({required this.photo, required this.stamp});

  final WorkPhoto photo;
  final String stamp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(workPhotoUrlProvider(photo.path)).value;
    return BvSitePhoto(
      key: Key('work-photo-${photo.path}'),
      photo: url == null ? null : NetworkImage(url),
      stamp: stamp,
    );
  }
}

class _Comment extends StatelessWidget {
  const _Comment({required this.name, required this.ago, required this.text});

  final String name;
  final String ago;
  final String text;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s2,
      children: [
        Row(
          spacing: BvSpace.s8,
          children: [
            Text(name, style: type.labelMd),
            Text(
              ago,
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
          ],
        ),
        UserText(text, style: type.bodyMd),
      ],
    );
  }
}
