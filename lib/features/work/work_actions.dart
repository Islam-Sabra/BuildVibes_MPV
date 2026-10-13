import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/work_item.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'work_outbox.dart';
import '../spaces/former_member.dart';

/// W4 · Sign DONE: one or more photos and/or a note. Sent through the
/// outbox, so a weak signal keeps it on the phone. True when it reached the
/// server, false when it waits as "Not sent yet", null when cancelled.
Future<bool?> showSignDoneSheet(BuildContext context, WorkItem item) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<bool>(
    context: context,
    title: l10n.workSignTitle(ltrRun(item.ref)),
    subtitle: l10n.workSignBody(
      inOwnDirection(personFirstName(l10n, item.createdByName)),
    ),
    builder: (_) => _SignDone(item: item),
  );
}

class _SignDone extends ConsumerStatefulWidget {
  const _SignDone({required this.item});

  final WorkItem item;

  @override
  ConsumerState<_SignDone> createState() => _SignDoneState();
}

class _SignDoneState extends ConsumerState<_SignDone> {
  final _note = TextEditingController();
  final _photos = <PendingPhoto>[];
  var _showError = false;
  var _sending = false;

  static const _maxPhotos = 6;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add({required bool camera}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await ref.read(pickPhotoProvider)(camera: camera);
    if (picked == null || !mounted) return;
    final kept = await ref.read(keepPhotoProvider)(picked);
    if (!mounted) return;
    setState(() {
      _photos.add(
        PendingPhoto(
          local: kept,
          takenAt: ref.read(clockProvider)(),
          place: widget.item.place,
        ),
      );
      _showError = false;
    });
  }

  Future<void> _sign() async {
    final note = _note.text.trim();
    if (_photos.isEmpty && note.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _sending = true);
    final navigator = Navigator.of(context);
    final sent = await ref
        .read(workOutboxProvider.notifier)
        .send(
          PendingItem(
            id: widget.item.id,
            spaceId: widget.item.spaceId,
            title: widget.item.title,
            ownerId: widget.item.ownerId ?? '',
            ownerName: widget.item.ownerName ?? '',
            kind: PendingKind.signDone,
            note: note.isEmpty ? null : note,
            ref: widget.item.ref,
            photos: List.of(_photos),
          ),
        );
    navigator.pop(sent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Column(
      key: const Key('sign-done-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s12,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s8,
            children: [
              for (final p in _photos)
                ClipRRect(
                  borderRadius: BvRadius.controlAll,
                  child: Image.file(
                    File(p.local),
                    width: BvSignDoneSpec.thumb,
                    height: BvSignDoneSpec.thumb,
                    fit: BoxFit.cover,
                  ),
                ),
              if (_photos.length < _maxPhotos)
                _AddPhotoTile(
                  label: l10n.workAddPhoto,
                  onCamera: () => _add(camera: true),
                  onGallery: () => _add(camera: false),
                ),
            ],
          ),
        ),
        BvTextField(
          key: const Key('sign-done-note'),
          label: l10n.workNote,
          placeholder: l10n.workNoteHint,
          controller: _note,
          maxLines: 3,
          maxLength: 1000,
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
        ),
        if (_showError)
          Text(
            l10n.workSignNeedsSomething,
            style: type.bodySm.copyWith(color: BvColors.textDestructive),
          ),
        BvButton(
          key: const Key('sign-done-confirm'),
          label: l10n.workSignAsDone,
          expand: true,
          onPressed: _sending ? null : _sign,
        ),
      ],
    );
  }
}

/// The dashed "Add photo" tile: tap for the camera, long-press for the
/// gallery (also offered as a link under it).
class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    required this.label,
    required this.onCamera,
    required this.onGallery,
  });

  final String label;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: const Key('sign-done-add-photo'),
          onTap: onCamera,
          onLongPress: onGallery,
          borderRadius: BvRadius.controlAll,
          child: Container(
            width: BvSignDoneSpec.thumb,
            height: BvSignDoneSpec.thumb,
            decoration: BoxDecoration(
              borderRadius: BvRadius.controlAll,
              border: Border.all(
                color: BvColors.borderInput,
                width: BvStroke.thin,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: BvSpace.s4,
              children: [
                const Icon(
                  BvIcons.camera,
                  size: BvSize.iconLg,
                  color: BvColors.iconPrimary,
                ),
                Text(label, style: type.labelSm),
              ],
            ),
          ),
        ),
        TextButton(
          key: const Key('sign-done-gallery'),
          onPressed: onGallery,
          child: Text(l10n.workFromGallery, style: type.labelSm),
        ),
      ],
    );
  }
}

/// W5 · Send back: one reason (single choice) and a note for the owner.
/// Returns the reason and the note, or null when cancelled.
Future<(SendBackReason, String?)?> showSendBackSheet(
  BuildContext context,
  WorkItem item,
) {
  final l10n = AppLocalizations.of(context);
  final owner = personFirstName(l10n, item.ownerName);
  return showBvSheet<(SendBackReason, String?)>(
    context: context,
    title: l10n.workSendBackTitle(ltrRun(item.ref), inOwnDirection(owner)),
    subtitle: l10n.workSendBackBody(inOwnDirection(owner)),
    builder: (_) => _SendBack(owner: owner),
  );
}

class _SendBack extends StatefulWidget {
  const _SendBack({required this.owner});

  final String owner;

  @override
  State<_SendBack> createState() => _SendBackState();
}

class _SendBackState extends State<_SendBack> {
  final _note = TextEditingController();
  SendBackReason? _reason;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n, SendBackReason r) => switch (r) {
    SendBackReason.photoMissing => l10n.workReasonPhotoMissing,
    SendBackReason.notAsDrawing => l10n.workReasonNotAsDrawing,
    SendBackReason.notFinished => l10n.workReasonNotFinished,
    SendBackReason.other => l10n.workReasonOther,
  };

  void _send() {
    final l10n = AppLocalizations.of(context);
    final note = _note.text.trim();
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = l10n.workReasonRequired);
      return;
    }
    if (reason == SendBackReason.other && note.isEmpty) {
      setState(() => _error = l10n.workOtherNeedsNote);
      return;
    }
    Navigator.of(context).pop((reason, note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Column(
      key: const Key('send-back-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s12,
      children: [
        Text(l10n.workReason, style: type.labelMd),
        // One single choice (rule 6).
        Wrap(
          spacing: BvSpace.s8,
          runSpacing: BvSpace.s8,
          children: [
            for (final r in SendBackReason.values)
              BvChip(
                key: Key('reason-${r.json}'),
                label: _label(l10n, r),
                selected: r == _reason,
                onTap: () => setState(() {
                  _reason = r;
                  _error = null;
                }),
              ),
          ],
        ),
        BvTextField(
          key: const Key('send-back-note'),
          label: l10n.workNoteFor(inOwnDirection(widget.owner)),
          controller: _note,
          maxLines: 3,
          maxLength: 1000,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        if (_error != null)
          Text(
            _error!,
            style: type.bodySm.copyWith(color: BvColors.textDestructive),
          ),
        BvButton(
          key: const Key('send-back-confirm'),
          label: l10n.workSendBackTo(inOwnDirection(widget.owner)),
          expand: true,
          onPressed: _send,
        ),
      ],
    );
  }
}
