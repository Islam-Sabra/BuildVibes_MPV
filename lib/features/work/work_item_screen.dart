import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/ago.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_sign_off_strip.dart';
import '../../shared/widgets/bv_site_photo.dart';
import '../../shared/widgets/bv_site_tag.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_errors.dart';
import 'attach_files.dart';
import 'work_actions.dart';
import 'work_outbox.dart';
import '../spaces/former_member.dart';

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
        showSpaceMessage(
          context,
          l10n.workReassigned(inOwnDirection(picked.person.fullName)),
        );
      }
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
  }

  /// So the comment field doesn't take focus back when a sheet closes.
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// W4: through the outbox, so a weak signal never loses the photos.
  Future<void> _signDone(WorkItem item) async {
    final l10n = AppLocalizations.of(context);
    _unfocus();
    final sent = await showSignDoneSheet(context, item);
    if (sent == null || !mounted) return;
    _refresh();
    _toast(sent ? l10n.workSigned : l10n.workNotSentNote);
  }

  Future<void> _sendBack(WorkItem item) async {
    final l10n = AppLocalizations.of(context);
    _unfocus();
    final choice = await showSendBackSheet(context, item);
    if (choice == null || !mounted) return;
    try {
      await ref
          .read(workRepositoryProvider)
          .sendBack(item.id, choice.$1, note: choice.$2);
      _refresh();
      _toast(
        l10n.workSentBack(
          inOwnDirection(personFirstName(l10n, item.ownerName)),
        ),
      );
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
  }

  Future<void> _check(WorkItem item) async {
    final l10n = AppLocalizations.of(context);
    _unfocus();
    final yes = await showBvDialog(
      context: context,
      title: l10n.workCheckTitle(ltrRun(item.ref)),
      body: l10n.workCheckBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.workCheckConfirm,
    );
    if (!yes || !mounted) return;
    try {
      await ref.read(workRepositoryProvider).checkItem(item.id);
      _refresh();
      _toast(l10n.workClosed);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
  }

  Future<void> _setShown(WorkItem item, bool shown) async {
    try {
      await ref.read(workRepositoryProvider).setShown(item.id, shown);
      _refresh();
      ref.invalidate(myDeliveredWorkProvider);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
  }

  Future<void> _retry(String id) async {
    final l10n = AppLocalizations.of(context);
    final sent = await ref.read(workOutboxProvider.notifier).retry(id);
    if (mounted) _toast(sent ? l10n.workSigned : l10n.workNotSentNote);
  }

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
        id != null && id == me ? l10n.spacesYouTag : personName(l10n, name);

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
        // Reassign, for the author, while Open.
        if (d != null &&
            d.item.status == WorkStatus.open &&
            people != null &&
            d.item.createdById == me)
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
    String first(String? name) => personFirstName(l10n, name);

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
        SendBackReason.notAsAsked => l10n.workReasonNotAsAsked,
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
              title: l10n.workCheckBannerTitle(
                inOwnDirection(first(item.ownerName)),
              ),
              body: l10n.workCheckBannerBody,
            )
          : item.ownerId == me
          ? _Banner(
              title: l10n.workWaitingCheckBy(
                inOwnDirection(personName(l10n, item.createdByName)),
              ),
              body: l10n.workWaitingCheckBody,
            )
          : _Banner(title: l10n.workDoneWaiting);
    } else if (item.status == WorkStatus.checked) {
      final closedByYou = item.checkedById == me || item.createdById == me;
      banner = _Banner(
        tone: _BannerTone.positive,
        title: closedByYou
            ? l10n.workClosed
            : l10n.workClosedBy(
                inOwnDirection(personName(l10n, item.checkedByName)),
              ),
        body: closedByYou && item.ownerId != me
            ? l10n.workClosedCanShow(inOwnDirection(first(item.ownerName)))
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
    // Discussion: comments, and who it was reassigned to.
    final talk = [
      for (final e in d.events)
        if (e.kind == WorkEventKind.comment ||
            e.kind == WorkEventKind.reassigned)
          e,
    ];
    final pending = ref
        .watch(workOutboxProvider)
        .where((p) => p.id == item.id)
        .firstOrNull;

    Widget? footer;
    if (toSign && pending == null) {
      footer = BvButton(
        key: const Key('work-sign-done'),
        label: l10n.workSignAsDone,
        expand: true,
        onPressed: () => _signDone(item),
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
              onPressed: () => _sendBack(item),
            ),
          ),
          Expanded(
            child: BvButton(
              key: const Key('work-check'),
              label: l10n.workCheckAndClose,
              expand: true,
              onPressed: () => _check(item),
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
              due: item.due == null ? null : day(item.due!),
              overdue: item.overdue(now),
              checkedStamp:
                  item.status == WorkStatus.checked && item.checkedAt != null
                  ? l10n.workCheckedStamp(
                      ar
                          ? stampDay(item.checkedAt!)
                          : stampDay(item.checkedAt!).toUpperCase(),
                      item.checkedByName == null
                          ? l10n.formerMember
                          : ar
                          ? _short(item.checkedByName)
                          : _short(item.checkedByName).toUpperCase(),
                    )
                  : null,
            ),
            // A sign-off kept on this phone after a weak signal.
            if (pending != null) ...[
              const SizedBox(height: BvSpace.s16),
              _Banner(
                tone: _BannerTone.warning,
                title: l10n.workPendingSignOff,
                body: l10n.workNotSentNote,
                action: BvButton(
                  key: const Key('work-retry-sign-off'),
                  label: l10n.workRetry,
                  style: BvButtonStyle.secondary,
                  size: BvButtonSize.medium,
                  onPressed: () => _retry(pending.id),
                ),
              ),
            ],
            if (banner != null) ...[
              const SizedBox(height: BvSpace.s16),
              banner,
            ],
            // The owner chooses to show checked work on the profile (RE2).
            if (item.status == WorkStatus.checked && item.ownerId == me) ...[
              const SizedBox(height: BvSpace.s12),
              ProfileCard(
                padding: false,
                child: BvListRow(
                  key: const Key('work-show-on-profile'),
                  title: l10n.workShowOnProfile,
                  subtitle: l10n.workShowOnProfileHelp,
                  trailing: BvRowTrailing.toggle(
                    value: item.shown,
                    onChanged: (v) => _setShown(item, v),
                  ),
                ),
              ),
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
            _Attached(item: item, me: me),
            const SizedBox(height: BvSpace.s16),
            _DiscussionLabel(item: item),
            if (talk.isEmpty)
              EmptyNote(l10n.workNoComments)
            else
              for (final c in talk) ...[
                if (c.kind == WorkEventKind.reassigned)
                  Text(
                    l10n.workReassignedLine(
                      personName(l10n, c.fromName),
                      personName(l10n, c.toName),
                    ),
                    key: Key('work-reassigned-${c.id}'),
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  )
                else
                  _Comment(
                    name: who(c.actorId, c.actorName),
                    ago: formatAgo(l10n, c.at.toLocal(), now),
                    text: c.note ?? '',
                  ),
                const SizedBox(height: BvSpace.s12),
              ],
            const SizedBox(height: BvSpace.s8),
            _CommentField(
              controller: _comment,
              sending: _sending,
              onChanged: () => setState(() {}),
              onSend: _sendComment,
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

/// W3 "Attached": Library files on this item, and "Attach a file" for its
/// creator, its owner and people who may check items.
class _Attached extends ConsumerWidget {
  const _Attached({required this.item, required this.me});

  final WorkItem item;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final files = ref.watch(itemFilesProvider(item.id)).value ?? const [];
    final canAttach =
        me != null && (me == item.createdById || me == item.ownerId);
    if (files.isEmpty && !canAttach) return const SizedBox.shrink();

    Future<void> attach() async {
      final fileId = await chooseFileToAttach(
        context,
        spaceId: item.spaceId,
        itemRef: item.ref,
        teamId: item.teamId,
        teamName: item.teamName,
        exclude: {for (final f in files) f.id},
      );
      if (fileId == null || !context.mounted) return;
      try {
        await ref.read(libraryRepositoryProvider).attach(item.id, fileId);
        ref.invalidate(itemFilesProvider(item.id));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.workAttachedToast)));
        }
      } on SpaceException catch (e) {
        if (context.mounted) showSpaceError(context, e);
      }
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: BvSpace.s16),
      child: Column(
        key: const Key('work-attached'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (files.isNotEmpty) ...[
            _Label(l10n.workAttached),
            ProfileCard(
              padding: false,
              child: DividedColumn(
                children: [
                  for (final f in files)
                    AttachedFileRow(spaceId: item.spaceId, file: f),
                ],
              ),
            ),
          ],
          if (canAttach)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BvButton(
                key: const Key('work-attach'),
                label: l10n.workAttach,
                icon: BvIcons.create,
                style: BvButtonStyle.tertiary,
                size: BvButtonSize.medium,
                padded: false,
                onPressed: attach,
              ),
            ),
        ],
      ),
    );
  }
}

/// "DISCUSSION · ALSO IN THE TEAM CHAT": an item with a Team has a thread
/// for that Team. Comments stay on the item; the link opens the thread.
class _DiscussionLabel extends ConsumerWidget {
  const _DiscussionLabel({required this.item});

  final WorkItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final style = BvType.of(
      context,
    ).overline.copyWith(color: BvColors.textSecondary);
    final thread = item.teamId == null
        ? null
        : ref
              .watch(spaceThreadsProvider(item.spaceId))
              .value
              ?.where((t) => t.teamId == item.teamId)
              .firstOrNull;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s8),
      child: Wrap(
        children: [
          Text(l10n.workDiscussion, style: style),
          if (thread != null) ...[
            Text(' · ', style: style),
            GestureDetector(
              key: const Key('work-team-chat'),
              onTap: () =>
                  context.push(AppRoutes.spaceThread(item.spaceId, thread.id)),
              child: Text(
                l10n.workAlsoInTeamChat,
                style: style.copyWith(color: BvColors.textAction),
              ),
            ),
          ],
        ],
      ),
    );
  }
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

/// "Add a comment": a one-line pill that grows while typing, with the send
/// icon inside once there is text (review 10).
class _CommentField extends StatelessWidget {
  const _CommentField({
    required this.controller,
    required this.sending,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final hasText = controller.text.trim().isNotEmpty;
    return Container(
      key: const Key('work-comment'),
      constraints: const BoxConstraints(minHeight: BvSize.controlMd),
      padding: const EdgeInsetsDirectional.only(
        start: BvSpace.s16,
        end: BvSpace.s4,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvRadius.roundAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: type.bodyMd,
              // The pill is the field: no theme border or fill inside it.
              decoration: InputDecoration(
                isCollapsed: true,
                // One line stays 44 high; more lines keep air top and bottom.
                contentPadding: const EdgeInsetsDirectional.symmetric(
                  vertical: BvSpace.s8,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: l10n.workAddComment,
                hintStyle: type.bodyMd.copyWith(color: BvColors.textSecondary),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (hasText)
            IconButton(
              key: const Key('work-comment-send'),
              tooltip: l10n.workSendComment,
              icon: const Icon(BvIcons.send, color: BvColors.iconAction),
              onPressed: sending ? null : onSend,
            )
          else
            const SizedBox(height: BvSize.controlMd),
        ],
      ),
    );
  }
}
