import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_loop_specs.dart';
import '../../data/models/daybook.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'daybook_draft.dart';
import 'daybook_entry.dart' show localPhotoProvider;
import 'daybook_words.dart';
import 'work_outbox.dart';

/// Sign as done with the camera (O2 2529:33493): the photo just taken,
/// linked to its work item (its title at the top, × to leave), labelled
/// with the place, the date and time and who took it. Another photo and
/// an optional note can go with it; the round button sends it as done
/// through the outbox, so a weak signal never loses it.
class ProofCamera extends ConsumerStatefulWidget {
  const ProofCamera({
    super.key,
    required this.spaceId,
    required this.post,
    required this.first,
  });

  final String spaceId;
  final DaybookPost post;

  /// The first photo, kept in the app's folder.
  final String first;

  @override
  ConsumerState<ProofCamera> createState() => _ProofCameraState();
}

class _ProofCameraState extends ConsumerState<ProofCamera> {
  final _note = TextEditingController();
  late final _taken = ref.read(clockProvider)();
  late final _photos = <PendingPhoto>[_photo(widget.first)];

  PendingPhoto _photo(String kept) => PendingPhoto(
    local: kept,
    takenAt: ref.read(clockProvider)(),
    place: widget.post.place,
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final picked = await ref.read(pickPhotoProvider)(camera: true);
    if (picked == null || !mounted) return;
    final kept = await ref.read(keepPhotoProvider)(picked);
    if (mounted) setState(() => _photos.add(_photo(kept)));
  }

  void _leave() {
    for (final p in _photos) {
      unawaited(DaybookDraft.deleteKept(p.local));
    }
    Navigator.of(context).pop();
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

  void _send() {
    final me = ref.read(authUserIdProvider).value ?? '';
    final name = _myName() ?? '';
    final note = _note.text.trim();
    unawaited(HapticFeedback.heavyImpact());
    unawaited(
      ref
          .read(workOutboxProvider.notifier)
          .send(
            PendingItem(
              kind: PendingKind.signOff,
              id: widget.post.id,
              spaceId: widget.spaceId,
              title: widget.post.title,
              ownerId: me,
              ownerName: name,
              note: note.isEmpty ? null : note,
              photos: List.of(_photos),
              madeAt: ref.read(clockProvider)(),
              authorName: name,
            ),
          ),
    );
    Navigator.of(context).pop();
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        key: const Key('proof-camera'),
        backgroundColor: BvColors.brandInk,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: ref.watch(localPhotoProvider(_photos.last.local)),
                    fit: BoxFit.cover,
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
                        child: _Link(
                          title: widget.post.title,
                          closeLabel: l10n.daybookCloseProof,
                          onClose: _leave,
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: BvProofCameraSpec.labelInset,
                    end: BvProofCameraSpec.labelInset,
                    bottom: BvProofCameraSpec.labelInset,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _Label(
                        words.photoLabel(
                          place: widget.post.place,
                          at: _taken,
                          name: name,
                        ),
                      ),
                    ),
                  ),
                ],
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
                    Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: BvProofCameraSpec.notePaddingHorizontal,
                        vertical: BvProofCameraSpec.notePaddingVertical,
                      ),
                      decoration: BoxDecoration(
                        color: inverse.withValues(
                          alpha: BvProofCameraSpec.noteOpacity,
                        ),
                        borderRadius: BvProofCameraSpec.noteRadius,
                      ),
                      child: TextField(
                        key: const Key('proof-note'),
                        controller: _note,
                        minLines: 1,
                        maxLines: BvProofCameraSpec.noteLines,
                        maxLength: BvProofCameraSpec.noteMax,
                        textCapitalization: TextCapitalization.sentences,
                        style: type.bodyMd.copyWith(color: inverse),
                        cursorColor: inverse,
                        decoration:
                            bvBareField(
                              hint: l10n.daybookNoteOptional,
                              style: type.bodyMd,
                            ).copyWith(
                              counterText: '',
                              hintStyle: type.bodyMd.copyWith(
                                color: inverse.withValues(
                                  alpha: BvProofCameraSpec.hintOpacity,
                                ),
                              ),
                            ),
                      ),
                    ),
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
                        _SendButton(
                          label: l10n.daybookSendAsDone,
                          onTap: _send,
                        ),
                        const Spacer(),
                      ],
                    ),
                    Text(
                      l10n.daybookSendAsDone,
                      textAlign: TextAlign.center,
                      style: type.labelMd.copyWith(color: inverse),
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

/// The work item the photo is for: a white pill with its title and ×.
class _Link extends StatelessWidget {
  const _Link({
    required this.title,
    required this.closeLabel,
    required this.onClose,
  });

  final String title;
  final String closeLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Opacity(
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
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: BvProofCameraSpec.linkPaddingVertical,
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BvType.of(
                  context,
                ).labelMd.copyWith(color: BvColors.textPrimary),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      key: const Key('proof-send'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
  );
}
