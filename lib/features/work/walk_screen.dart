import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_page_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/repositories/daybook_repository.dart' show NewWalk;
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/space_errors.dart';
import 'daybook_draft.dart' show DaybookDraft, DaybookPostDraft;
import 'daybook_photos.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart' show assignablePeople;
import 'work_outbox.dart';

/// One photo of a walk being taken: the phone's copy, when, its line and
/// who owns it.
class _Shot {
  _Shot({required this.local, required this.at, this.owner})
    : line = TextEditingController();

  final String local;
  final DateTime at;
  final TextEditingController line;
  BvGiveToPerson? owner;

  bool get ready => line.text.trim().length >= 2 && owner != null;
}

/// R1 · Walk mode (2539:34353, slice 6): name the walk, then for each thing
/// to fix one photo, one line (the keyboard's own mic types it) and who
/// does it. Finish posts it as one walk with a work item per photo, through
/// the outbox: with no signal it waits and sends later.
class WalkScreen extends ConsumerStatefulWidget {
  const WalkScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends ConsumerState<WalkScreen> {
  final _name = TextEditingController();
  final _place = TextEditingController();
  final _shots = <_Shot>[];
  var _current = 0;
  var _taking = false;

  static const _lineMax = 140;

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    for (final s in _shots) {
      s.line.dispose();
    }
    super.dispose();
  }

  _Shot? get _shot => _shots.isEmpty ? null : _shots[_current];

  Future<void> _take() async {
    final l10n = AppLocalizations.of(context);
    if (_shots.length >= NewWalk.maxPhotos) {
      showSpaceMessage(context, l10n.walkFull);
      return;
    }
    final shot = _shot;
    if (shot != null && !shot.ready) {
      showSpaceMessage(
        context,
        shot.line.text.trim().length < 2
            ? l10n.walkNeedsLine
            : l10n.walkNeedsOwner,
      );
      return;
    }
    setState(() => _taking = true);
    String? kept;
    try {
      final picked = await ref.read(pickPhotoProvider)(camera: true);
      if (!mounted) return;
      if (picked.refused > 0) showSpaceMessage(context, l10n.photoCannotOpen);
      final photo = picked.photos.firstOrNull;
      if (photo != null) kept = await ref.read(keepPhotoProvider)(photo);
    } on Exception {
      // No camera permission, or the photo couldn't be kept: say so, and
      // the shutter works again.
      if (mounted) showSpaceMessage(context, l10n.photoCannotOpen);
    } finally {
      if (mounted) setState(() => _taking = false);
    }
    if (!mounted || kept == null) return;
    final local = kept;
    setState(() {
      // The last owner stays for the next photo.
      _shots.add(
        _Shot(
          local: local,
          at: ref.read(clockProvider)(),
          owner: _shots.lastOrNull?.owner,
        ),
      );
      _current = _shots.length - 1;
    });
  }

  Future<void> _pickOwner() async {
    final l10n = AppLocalizations.of(context);
    final shot = _shot;
    if (shot == null) return;
    final me = ref.read(authUserIdProvider).value;
    final people = await ref.read(spacePeopleProvider(widget.spaceId).future);
    if (!mounted) return;
    final picked = await showBvSheet<BvGiveToPerson>(
      context: context,
      title: l10n.walkOwner,
      builder: (sheet) => BvGiveToPicker(
        key: const Key('walk-owner-picker'),
        people: assignablePeople(people, me: me),
        currentOwnerId: shot.owner?.id,
        // You first, as in the writing card (F69).
        meId: me,
        meLabel: l10n.daybookYou,
        currentLabel: l10n.daybookOwnerNow,
        searchPlaceholder: l10n.daybookAssignSearch,
        inSheet: true,
        onPick: (p) => Navigator.of(sheet).pop(p),
      ),
    );
    if (picked != null && mounted) setState(() => shot.owner = picked);
  }

  Future<void> _remove(int index) async {
    final gone = _shots.removeAt(index);
    unawaited(DaybookDraft.deleteKept(gone.local));
    gone.line.dispose();
    setState(
      () =>
          _current = _shots.isEmpty ? 0 : _current.clamp(0, _shots.length - 1),
    );
  }

  /// Finish: every photo needs its line and owner; then the walk goes to
  /// the outbox and the daybook shows it at once.
  Future<void> _finish() async {
    final l10n = AppLocalizations.of(context);
    final missing = _shots.indexWhere((s) => !s.ready);
    if (missing >= 0) {
      setState(() => _current = missing);
      showSpaceMessage(
        context,
        _shots[missing].line.text.trim().length < 2
            ? l10n.walkNeedsLine
            : l10n.walkNeedsOwner,
      );
      return;
    }
    final me = ref.read(authUserIdProvider).value ?? '';
    final name =
        ref
            .read(spacePeopleProvider(widget.spaceId))
            .value
            ?.member(me)
            ?.person
            .fullName ??
        '';
    final place = _place.text.trim();
    final now = ref.read(clockProvider)();
    final item = PendingItem(
      kind: PendingKind.walk,
      id: newUuid(),
      spaceId: widget.spaceId,
      title: _name.text.trim(),
      ownerId: me,
      ownerName: name,
      place: place.isEmpty ? null : place,
      madeAt: now,
      authorName: name,
      photos: [
        for (final s in _shots)
          PendingPhoto(
            local: s.local,
            takenAt: s.at,
            place: place.isEmpty ? null : place,
          ),
      ],
      walk: [
        for (final s in _shots)
          WalkLine(
            id: newUuid(),
            line: s.line.text.trim(),
            ownerId: s.owner!.id,
            ownerName: s.owner!.name,
          ),
      ],
    );
    unawaited(ref.read(workOutboxProvider.notifier).send(item));
    // Sent: past the "throw it away?" question.
    Navigator.of(context).pop();
  }

  /// ✕: with photos taken, asks first; they're never sent.
  Future<void> _leave() async {
    final l10n = AppLocalizations.of(context);
    if (_shots.isNotEmpty) {
      final away = await showBvDialog(
        context: context,
        title: l10n.walkDiscardTitle,
        body: l10n.walkDiscardBody,
        cancelLabel: l10n.walkKeep,
        confirmLabel: l10n.walkDiscard,
        destructive: true,
      );
      if (!away || !mounted) return;
      for (final s in _shots) {
        unawaited(DaybookDraft.deleteKept(s.local));
      }
      _shots.clear();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        key: const Key('walk-screen'),
        backgroundColor: BvColors.brandInk,
        body: SafeArea(
          child: _shots.isEmpty ? _start(context) : _walking(context),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Align(
      child: Container(
        height: BvWalkSpec.chipHeight,
        padding: const EdgeInsetsDirectional.only(start: BvSpace.s16),
        decoration: const BoxDecoration(
          color: BvColors.surfaceElevated,
          borderRadius: BvRadius.roundAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodySm,
              ),
            ),
            IconButton(
              key: const Key('walk-close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(BvIcons.close, size: BvSize.iconSm),
              onPressed: () => unawaited(_leave()),
            ),
          ],
        ),
      ),
    ).withSemantics(l10n.walkTitle);
  }

  /// Before the first photo: the walk's name and place.
  Widget _start(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final ready = _name.text.trim().length >= 2;
    return Padding(
      padding: const EdgeInsetsDirectional.all(BvWalkSpec.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          _chip(l10n.walkTitle),
          const Spacer(),
          Container(
            padding: const EdgeInsetsDirectional.all(BvWalkSpec.linePadding),
            decoration: const BoxDecoration(
              color: BvColors.surfaceElevated,
              borderRadius: BvWalkSpec.lineRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s12,
              children: [
                TextField(
                  key: const Key('walk-name'),
                  controller: _name,
                  autofocus: true,
                  maxLength: _lineMax,
                  style: type.titleMd,
                  decoration: bvBareField(
                    hint: l10n.walkNameHint,
                    style: type.titleMd,
                  ).copyWith(counterText: ''),
                  onChanged: (_) => setState(() {}),
                ),
                Row(
                  spacing: BvSpace.s8,
                  children: [
                    const Icon(
                      BvIcons.place,
                      size: BvSize.iconMd,
                      color: BvColors.iconSecondary,
                    ),
                    Expanded(
                      child: TextField(
                        key: const Key('walk-place'),
                        controller: _place,
                        maxLength: DaybookPostDraft.placeMax,
                        style: type.bodyMd,
                        decoration: bvBareField(
                          hint: l10n.daybookPlaceHint,
                          style: type.bodyMd,
                        ).copyWith(counterText: ''),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          BvButton(
            key: const Key('walk-start'),
            label: l10n.walkStart,
            icon: BvIcons.camera,
            expand: true,
            onPressed: ready && !_taking ? () => unawaited(_take()) : null,
          ),
        ],
      ),
    );
  }

  /// R1: the photo just taken, its line and owner, the photos so far, the
  /// shutter and Finish.
  Widget _walking(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final shot = _shot!;
    final me = ref.watch(authUserIdProvider).value;
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final place = _place.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                key: Key('walk-photo-$_current'),
                image: ref.watch(localPhotoProvider(shot.local)),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: BvColors.brandInk),
              ),
              PositionedDirectional(
                top: BvSpace.s12,
                start: BvWalkSpec.padding,
                end: BvWalkSpec.padding,
                // "Walk · Level 4 corridor": the place, else the name.
                child: _chip(
                  joinMeta([
                    l10n.walkTitle,
                    inOwnDirection(place.isEmpty ? _name.text.trim() : place),
                  ]),
                ),
              ),
              PositionedDirectional(
                start: BvWalkSpec.padding,
                end: BvWalkSpec.padding,
                bottom: BvSpace.s12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BvSpace.s8,
                  children: [
                    Container(
                      padding: const EdgeInsetsDirectional.all(
                        BvWalkSpec.linePadding,
                      ),
                      decoration: const BoxDecoration(
                        color: BvColors.surfaceElevated,
                        borderRadius: BvWalkSpec.lineRadius,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: BvSpace.s8,
                        children: [
                          TextField(
                            key: Key('walk-line-$_current'),
                            controller: shot.line,
                            maxLength: _lineMax,
                            maxLines: null,
                            style: type.bodyMd,
                            decoration: bvBareField(
                              hint: l10n.walkLineHint,
                              style: type.bodyMd,
                            ).copyWith(counterText: ''),
                            onChanged: (_) => setState(() {}),
                          ),
                          _OwnerChip(
                            owner: shot.owner,
                            label: l10n.walkOwner,
                            onTap: () => unawaited(_pickOwner()),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: BvSpace.s8,
                          vertical: BvSpace.s4,
                        ),
                        decoration: BoxDecoration(
                          color: BvColors.brandInk.withValues(
                            alpha: BvWalkSpec.labelScrim,
                          ),
                          borderRadius: BvRadius.smallAll,
                        ),
                        child: Text(
                          words.photoLabel(
                            place: place.isEmpty ? null : place,
                            at: shot.at,
                            name: me == null ? null : l10n.daybookYou,
                          ),
                          style: type.metadata.copyWith(
                            color: BvColors.textInverse,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(BvWalkSpec.padding),
          child: Column(
            spacing: BvWalkSpec.barGap,
            children: [
              SizedBox(
                height: BvWalkSpec.thumb,
                child: ListView.separated(
                  key: const Key('walk-thumbs'),
                  scrollDirection: Axis.horizontal,
                  itemCount: _shots.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: BvWalkSpec.thumbGap),
                  itemBuilder: (context, i) => GestureDetector(
                    key: Key('walk-thumb-$i'),
                    onTap: () => setState(() => _current = i),
                    onLongPress: () => unawaited(_askRemove(i)),
                    child: Container(
                      width: BvWalkSpec.thumb,
                      decoration: BoxDecoration(
                        borderRadius: BvWalkSpec.thumbRadius,
                        border: Border.all(
                          color: i == _current
                              ? BvColors.borderSelected
                              : BvColors.textInverse,
                          width: BvStroke.thick,
                        ),
                        image: DecorationImage(
                          image: ref.watch(localPhotoProvider(_shots[i].local)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.walkPhotos(_shots.length),
                      style: type.bodySm.copyWith(color: BvColors.textInverse),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.walkNext,
                    child: GestureDetector(
                      key: const Key('walk-shutter'),
                      onTap: _taking ? null : () => unawaited(_take()),
                      child: Container(
                        width: BvWalkSpec.shutter,
                        height: BvWalkSpec.shutter,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: shot.ready
                              ? BvColors.surfaceElevated
                              : BvColors.surfaceElevated.withValues(
                                  alpha: BvWalkSpec.shutterWaiting,
                                ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: BvButton(
                        key: const Key('walk-finish'),
                        label: l10n.walkFinish,
                        size: BvButtonSize.medium,
                        onPressed: () => unawaited(_finish()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _askRemove(int i) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showBvDialog(
      context: context,
      title: l10n.walkRemovePhoto,
      body: '',
      cancelLabel: l10n.walkKeep,
      confirmLabel: l10n.walkRemovePhoto,
      destructive: true,
    );
    if (yes && mounted) await _remove(i);
  }
}

/// The owner's chip: their face and name in the action colour, or "Who
/// does it".
class _OwnerChip extends StatelessWidget {
  const _OwnerChip({
    required this.owner,
    required this.label,
    required this.onTap,
  });

  final BvGiveToPerson? owner;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final o = owner;
    return Material(
      key: const Key('walk-owner'),
      color: BvColors.surfaceBrandSoft,
      borderRadius: BvRadius.roundAll,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSpace.s8,
            vertical: BvSpace.s4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s8,
            children: [
              if (o != null)
                BvAvatar(
                  name: o.name,
                  size: BvAvatarSize.face,
                  tint: BvAvatarTints.forId(o.id),
                )
              else
                const Icon(
                  BvIcons.person,
                  size: BvSize.iconSm,
                  color: BvColors.textAction,
                ),
              Text(
                o?.name ?? label,
                style: type.labelSm.copyWith(color: BvColors.textAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Widget {
  Widget withSemantics(String label) =>
      Semantics(container: true, label: label, child: this);
}
