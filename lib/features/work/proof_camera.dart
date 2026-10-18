import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_loop_specs.dart';
import '../../core/design/daybook_writing_specs.dart' show BvUndoBarSpec;
import '../../data/models/daybook.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'daybook_draft.dart';
import 'daybook_entry.dart' show localPhotoProvider;
import 'daybook_words.dart';
import 'work_outbox.dart';

/// Sign as done (O2 2529:33493): linked to its work item (its title at
/// the top, × to leave). It opens with the camera one tap away and
/// "Without a photo" (F6, review 50); a tap on Sign as done never signs
/// (F7). The photo is labelled with the place, the date and time and who
/// took it; another photo and an optional note can go with it. Without a
/// photo, the note is needed ("What was done?"). The round button holds
/// it for the 5-second undo bar, then sends it through the outbox, so a
/// weak signal never loses it.
///
/// Proof photos come from the camera only (founder, review 47): the time
/// and place are real. Tapping the item name lists the reader's other
/// open items ([choices]) to prove one of them instead (answer 3).
///
/// A sign-off the server refused opens here again with its photos and
/// note ([refused], answer 5); × then asks before anything is deleted.
class ProofCamera extends ConsumerStatefulWidget {
  const ProofCamera({
    super.key,
    required this.spaceId,
    required this.post,
    required this.photos,
    this.choices = const [],
    this.note,
    this.refused,
  });

  final String spaceId;
  final DaybookPost post;

  /// The photos so far, kept in the app's folder (the first just taken).
  final List<PendingPhoto> photos;

  /// The reader's open work items, due soonest first.
  final List<DaybookPost> choices;
  final String? note;

  /// The refused sign-off this reopens.
  final PendingItem? refused;

  @override
  ConsumerState<ProofCamera> createState() => _ProofCameraState();
}

class _ProofCameraState extends ConsumerState<ProofCamera> {
  late final _note = TextEditingController(text: widget.note)
    ..addListener(_noteChanged);
  late var _post = widget.post;
  late final _photos = List.of(widget.photos);

  /// "Without a photo" chosen: the note says what was done. A note-only
  /// proof opens again this way.
  late var _noPhoto =
      widget.photos.isEmpty && (widget.note ?? '').trim().isNotEmpty;
  var _switching = false;
  var _sending = false;

  List<DaybookPost> get _choices => [
    if (!widget.choices.any((c) => c.id == widget.post.id)) widget.post,
    ...widget.choices,
  ];

  /// A photo, or without one a note: what the server needs (sign_done).
  bool get _canSend =>
      !_sending && (_photos.isNotEmpty || _note.text.trim().isNotEmpty);

  void _noteChanged() => setState(() {});

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final picked = await ref.read(pickPhotoProvider)(camera: true);
    if (picked == null || !mounted) return;
    final kept = await ref.read(keepPhotoProvider)(picked);
    if (!mounted) return;
    setState(
      () => _photos.add(
        PendingPhoto(
          local: kept,
          takenAt: ref.read(clockProvider)(),
          place: _post.place,
        ),
      ),
    );
  }

  /// The photos taken here, not the refused sign-off's.
  Iterable<PendingPhoto> get _new {
    final before = {
      for (final p in widget.refused?.photos ?? const <PendingPhoto>[]) p.local,
    };
    return _photos.where((p) => !before.contains(p.local));
  }

  Future<void> _leave() async {
    final refused = widget.refused;
    if (refused != null) {
      final l10n = AppLocalizations.of(context);
      final delete = await showBvDialog(
        context: context,
        title: l10n.daybookDiscardProofTitle,
        body: l10n.daybookDiscardProofBody,
        cancelLabel: l10n.daybookDiscardProofKeep,
        confirmLabel: l10n.daybookDiscardProofDelete,
        destructive: true,
      );
      if (!mounted) return;
      if (delete) await ref.read(workOutboxProvider.notifier).discard(refused);
    }
    for (final p in _new) {
      unawaited(DaybookDraft.deleteKept(p.local));
    }
    if (mounted) Navigator.of(context).pop();
  }

  String? _myName() {
    final me = ref.read(authUserIdProvider).value;
    return ref
        .read(spacePeopleProvider(widget.spaceId))
        .value
        ?.member(me ?? '')
        ?.person
        .fullName;
  }

  /// Send as done: held on the phone for the undo bar's 5 seconds, then
  /// sent through the outbox (F7; review 44, answer 4). The screen closes
  /// with what it holds, for the daybook's "Signed as done · Undo".
  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    final me = ref.read(authUserIdProvider).value ?? '';
    final name = _myName() ?? '';
    final note = _note.text.trim();
    final outbox = ref.read(workOutboxProvider.notifier);
    final refused = widget.refused;
    // Another item: the photos upload again into its own folder.
    final moved = refused != null && refused.id != _post.id;
    if (moved) await outbox.forget(refused);
    unawaited(HapticFeedback.heavyImpact());
    final item = PendingItem(
      kind: PendingKind.signOff,
      id: _post.id,
      spaceId: widget.spaceId,
      title: _post.title,
      ownerId: me,
      ownerName: name,
      note: note.isEmpty ? null : note,
      photos: [
        for (final p in _photos)
          PendingPhoto(
            local: p.local,
            takenAt: p.takenAt,
            place: _post.place,
            remote: moved ? null : p.remote,
          ),
      ],
      madeAt: refused?.madeAt ?? ref.read(clockProvider)(),
      authorName: name,
    );
    await outbox.hold(item, BvUndoBarSpec.duration);
    if (mounted) Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final name = ref
        .watch(spacePeopleProvider(widget.spaceId))
        .value
        ?.member(ref.watch(authUserIdProvider).value ?? '')
        ?.person
        .fullName;
    final inverse = BvColors.textInverse;
    final choices = _choices;
    final photo = _photos.isNotEmpty;
    final noteField = Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvProofCameraSpec.notePaddingHorizontal,
        vertical: BvProofCameraSpec.notePaddingVertical,
      ),
      decoration: BoxDecoration(
        color: inverse.withValues(alpha: BvProofCameraSpec.noteOpacity),
        borderRadius: BvProofCameraSpec.noteRadius,
      ),
      child: TextField(
        key: const Key('proof-note'),
        controller: _note,
        // Chosen without a photo: the note is next.
        autofocus: !photo,
        minLines: 1,
        maxLines: photo
            ? BvProofCameraSpec.noteLines
            : BvProofCameraSpec.noteLinesRequired,
        maxLength: BvProofCameraSpec.noteMax,
        textCapitalization: TextCapitalization.sentences,
        style: type.bodyMd.copyWith(color: inverse),
        cursorColor: inverse,
        decoration:
            bvBareField(
              hint: photo ? l10n.daybookNoteOptional : l10n.daybookWhatWasDone,
              style: type.bodyMd,
            ).copyWith(
              counterText: '',
              hintStyle: type.bodyMd.copyWith(
                color: inverse.withValues(alpha: BvProofCameraSpec.hintOpacity),
              ),
            ),
      ),
    );
    final send = _SendButton(
      label: l10n.daybookSendAsDone,
      onTap: _canSend ? () => unawaited(_send()) : null,
    );
    final sendLabel = Text(
      l10n.daybookSendAsDone,
      textAlign: TextAlign.center,
      style: type.labelMd.copyWith(color: inverse),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_switching) {
          setState(() => _switching = false);
        } else {
          unawaited(_leave());
        }
      },
      child: Scaffold(
        key: const Key('proof-camera'),
        backgroundColor: BvColors.brandInk,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    if (photo) ...[
                      Image(
                        image: ref.watch(
                          localPhotoProvider(_photos.last.local),
                        ),
                        fit: BoxFit.cover,
                      ),
                      PositionedDirectional(
                        start: BvProofCameraSpec.labelInset,
                        end: BvProofCameraSpec.labelInset,
                        bottom: BvProofCameraSpec.labelInset,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _Label(
                            words.photoLabel(
                              place: _post.place,
                              at: _photos.first.takenAt,
                              name: name,
                            ),
                          ),
                        ),
                      ),
                    ] else
                      // Camera only (founder, review 47), one tap away.
                      Center(
                        child: _Shutter(
                          label: l10n.daybookCamera,
                          onTap: _addPhoto,
                        ),
                      ),
                    if (_switching)
                      Positioned.fill(
                        child: GestureDetector(
                          key: const Key('proof-switch-away'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _switching = false),
                        ),
                      ),
                    SafeArea(
                      bottom: false,
                      child: Align(
                        alignment: AlignmentDirectional.topCenter,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: BvProofCameraSpec.linkTop,
                            start: BvSpace.gutter,
                            end: BvSpace.gutter,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: BvProofCameraSpec.switchGap,
                            children: [
                              _Link(
                                title: _post.title,
                                closeLabel: l10n.daybookCloseProof,
                                onClose: () => unawaited(_leave()),
                                switchLabel: l10n.daybookSwitchItem,
                                onSwitch: choices.length < 2
                                    ? null
                                    : () => setState(
                                        () => _switching = !_switching,
                                      ),
                              ),
                              if (_switching)
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight:
                                        constraints.maxHeight *
                                        BvProofCameraSpec.switchMaxHeight,
                                  ),
                                  child: SingleChildScrollView(
                                    child: BvPopoverMenu<String>.picker(
                                      key: const Key('proof-switch'),
                                      selected: _post.id,
                                      items: [
                                        for (final c in choices)
                                          BvMenuItem(
                                            value: c.id,
                                            label: c.title,
                                            icon: BvIcons.workItems,
                                          ),
                                      ],
                                      onSelected: (id) => setState(() {
                                        _post = choices.firstWhere(
                                          (c) => c.id == id,
                                        );
                                        _switching = false;
                                      }),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(
                  BvProofCameraSpec.controlsPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BvProofCameraSpec.controlsGap,
                  children: [
                    if (photo) ...[
                      noteField,
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: _Thumbs(
                                photos: [for (final p in _photos) p.local],
                                addLabel: l10n.daybookAddAnotherPhoto,
                                onAdd: _addPhoto,
                              ),
                            ),
                          ),
                          send,
                          const Spacer(),
                        ],
                      ),
                      sendLabel,
                    ] else if (_noPhoto) ...[
                      noteField,
                      Center(child: send),
                      sendLabel,
                    ] else
                      _WithoutPhoto(
                        label: l10n.daybookWithoutPhoto,
                        onTap: () => setState(() => _noPhoto = true),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Before the first photo: the camera in the middle, a white ring with
/// "Take a photo" under it (F6).
class _Shutter extends StatelessWidget {
  const _Shutter({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      key: const Key('proof-take-photo'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: BvProofCameraSpec.shutterGap,
        children: [
          Container(
            width: BvProofCameraSpec.shutter,
            height: BvProofCameraSpec.shutter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: BvColors.textInverse,
                width: BvProofCameraSpec.shutterStroke,
              ),
            ),
            child: const Icon(
              BvIcons.camera,
              size: BvProofCameraSpec.shutterIcon,
              color: BvColors.iconInverse,
            ),
          ),
          Text(
            label,
            style: BvType.of(
              context,
            ).labelMd.copyWith(color: BvColors.textInverse),
          ),
        ],
      ),
    ),
  );
}

/// "Without a photo": a plain underlined link, 48 high (F6).
class _WithoutPhoto extends StatelessWidget {
  const _WithoutPhoto({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('proof-without-photo'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: BvSize.touchMin,
            minWidth: BvSize.touchMin,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: BvType.of(context).labelMd.copyWith(
                color: BvColors.textInverse,
                decoration: TextDecoration.underline,
                decorationColor: BvColors.textInverse,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The work item the photo is for: a white pill with its title and ×.
/// With other open items, the title opens them ([onSwitch]).
class _Link extends StatelessWidget {
  const _Link({
    required this.title,
    required this.closeLabel,
    required this.onClose,
    required this.switchLabel,
    this.onSwitch,
  });

  final String title;
  final String closeLabel;
  final VoidCallback onClose;
  final String switchLabel;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final text = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: BvProofCameraSpec.linkPaddingVertical,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvSpace.s4,
        children: [
          Flexible(
            child: Text(
              title,
              key: const Key('proof-item'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BvType.of(
                context,
              ).labelMd.copyWith(color: BvColors.textPrimary),
            ),
          ),
          if (onSwitch != null)
            const Icon(
              BvIcons.caretDown,
              size: BvProofCameraSpec.linkIcon,
              color: BvColors.iconPrimary,
            ),
        ],
      ),
    );
    return Opacity(
      opacity: BvProofCameraSpec.linkOpacity,
      child: Container(
        padding: const EdgeInsetsDirectional.only(
          start: BvProofCameraSpec.linkPaddingStart,
          end: BvProofCameraSpec.linkPaddingEnd,
        ),
        decoration: const BoxDecoration(
          color: BvColors.surfaceElevated,
          borderRadius: BvRadius.roundAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: BvProofCameraSpec.linkGap,
          children: [
            Flexible(
              child: onSwitch == null
                  ? text
                  : Semantics(
                      button: true,
                      label: switchLabel,
                      child: GestureDetector(
                        key: const Key('proof-switch-open'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onSwitch,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: BvSize.touchMin,
                          ),
                          child: Center(widthFactor: 1, child: text),
                        ),
                      ),
                    ),
            ),
            // The × is small; its touch area is 48.
            Semantics(
              button: true,
              label: closeLabel,
              excludeSemantics: true,
              child: GestureDetector(
                key: const Key('proof-close'),
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: const SizedBox.square(
                  dimension: BvSize.touchMin,
                  child: Center(
                    child: Icon(
                      BvIcons.close,
                      size: BvProofCameraSpec.linkIcon,
                      color: BvColors.iconPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Level 2, grid C7 · 15 Oct 09:40 · Omar Haddad" on the photo.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: BvProofCameraSpec.labelPaddingHorizontal,
      vertical: BvProofCameraSpec.labelPaddingVertical,
    ),
    decoration: BoxDecoration(
      color: BvColors.brandInk.withValues(
        alpha: BvProofCameraSpec.labelOpacity,
      ),
      borderRadius: BvProofCameraSpec.labelRadius,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: BvProofCameraSpec.labelGap,
      children: [
        const Icon(
          BvIcons.place,
          size: BvProofCameraSpec.labelIcon,
          color: BvColors.iconInverse,
        ),
        Flexible(
          child: Text(
            text,
            key: const Key('proof-label'),
            style: BvType.of(
              context,
            ).labelSm.copyWith(color: BvColors.textInverse),
          ),
        ),
      ],
    ),
  );
}

/// The photos taken (44, white edge) and a + for another.
class _Thumbs extends ConsumerWidget {
  const _Thumbs({
    required this.photos,
    required this.addLabel,
    required this.onAdd,
  });

  final List<String> photos;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget box({Widget? child, ImageProvider? image}) => Container(
      width: BvProofCameraSpec.thumb,
      height: BvProofCameraSpec.thumb,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
          Radius.circular(BvProofCameraSpec.thumbRadius),
        ),
        border: Border.all(
          color: BvColors.textInverse,
          width: BvProofCameraSpec.thumbBorder,
        ),
        image: image == null
            ? null
            : DecorationImage(image: image, fit: BoxFit.cover),
      ),
      child: child,
    );
    return Wrap(
      spacing: BvProofCameraSpec.thumbGap,
      runSpacing: BvProofCameraSpec.thumbGap,
      children: [
        for (final p in photos) box(image: ref.watch(localPhotoProvider(p))),
        Semantics(
          button: true,
          label: addLabel,
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('proof-add-photo'),
            behavior: HitTestBehavior.opaque,
            onTap: onAdd,
            child: box(
              child: const Icon(
                BvIcons.add,
                size: BvSize.iconMd,
                color: BvColors.iconInverse,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The round button: an orange ring around a white disc (O2).
class _SendButton extends StatelessWidget {
  const _SendButton({required this.label, required this.onTap});

  final String label;

  /// Null until there is a photo or a note: dimmed.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      key: const Key('proof-send'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? BvProofCameraSpec.sendDisabledOpacity : 1,
        child: Container(
          width: BvProofCameraSpec.ring,
          height: BvProofCameraSpec.ring,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: BvColors.brandEnergy,
              width: BvProofCameraSpec.ringStroke,
            ),
          ),
          alignment: Alignment.center,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: BvColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: BvProofCameraSpec.button),
          ),
        ),
      ),
    ),
  );
}
