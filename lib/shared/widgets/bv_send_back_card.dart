import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import 'bv_writing_card.dart' show bvBareField;
import 'bv_button.dart';
import 'bv_chip.dart';
import 'bv_controls.dart';
import 'bv_tap_target.dart';

/// Send-back reasons, shown in place under the lifted slip (2530:33802):
/// one choice of reason, an optional note and the Send back button. The
/// note's microphone (hold for a voice note) shows only with
/// [onMicrophoneHoldStart]. The screen decides when sending is
/// allowed: [onSend] is null until it is (a reason, and a note for
/// "Something else").
///
/// [dues] is the new date (review 50 F62): one choice as a line of chips
/// under [dueLabel], nothing chosen first.
///
/// [BvSendBackCard.inSheet] is the same content on a field sheet (F24):
/// no box of its own, the sheet's title above it and the item quoted in
/// one line ([quote]) first.
class BvSendBackCard<T> extends StatelessWidget {
  const BvSendBackCard({
    super.key,
    required String this.title,
    required this.reasons,
    required this.selected,
    required this.onSelected,
    required this.noteController,
    required this.notePlaceholder,
    required this.sendLabel,
    required this.onSend,
    this.noteFocusNode,
    this.onNoteChanged,
    this.microphoneLabel,
    this.onMicrophoneHoldStart,
    this.onMicrophoneHoldEnd,
    this.dueLabel,
    this.dues = const [],
  }) : quote = null;

  const BvSendBackCard.inSheet({
    super.key,
    required Widget this.quote,
    required this.reasons,
    required this.selected,
    required this.onSelected,
    required this.noteController,
    required this.notePlaceholder,
    required this.sendLabel,
    required this.onSend,
    this.noteFocusNode,
    this.onNoteChanged,
    this.microphoneLabel,
    this.onMicrophoneHoldStart,
    this.onMicrophoneHoldEnd,
    this.dueLabel,
    this.dues = const [],
  }) : title = null;

  /// "Send back to Omar"; on a sheet, the sheet says it.
  final String? title;

  /// On a sheet: the item, in one line.
  final Widget? quote;
  final List<({T value, String label})> reasons;
  final T? selected;
  final ValueChanged<T> onSelected;

  final TextEditingController noteController;
  final String notePlaceholder;
  final FocusNode? noteFocusNode;
  final ValueChanged<String>? onNoteChanged;

  /// Read out for the microphone; hold it to record a voice note.
  final String? microphoneLabel;
  final VoidCallback? onMicrophoneHoldStart;
  final VoidCallback? onMicrophoneHoldEnd;

  final String sendLabel;
  final VoidCallback? onSend;

  /// "New date", above [dues].
  final String? dueLabel;
  final List<BvSendBackDue> dues;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final quote = this.quote;
    final title = this.title;
    final content = [
      ?quote,
      if (title != null)
        Text(title, style: type.labelMd.copyWith(color: BvColors.textPrimary)),
      for (final r in reasons)
        _Reason(
          label: r.label,
          selected: r.value == selected,
          onTap: () => onSelected(r.value),
        ),
      if (dues.isNotEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: BvSendBackSpec.dueTop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvSendBackSpec.dueLabelGap,
            children: [
              if (dueLabel != null)
                Text(
                  dueLabel!,
                  style: type.labelSm.copyWith(color: BvColors.textSecondary),
                ),
              Wrap(
                spacing: BvSendBackSpec.dueChipGap,
                runSpacing: BvSendBackSpec.dueChipGap,
                children: [
                  for (final d in dues)
                    BvChip(
                      key: d.key,
                      label: d.label,
                      icon: d.icon,
                      selected: d.selected,
                      onTap: d.onTap,
                    ),
                ],
              ),
            ],
          ),
        ),
      _Note(
        controller: noteController,
        focusNode: noteFocusNode,
        placeholder: notePlaceholder,
        onChanged: onNoteChanged,
        microphoneLabel: microphoneLabel,
        onHoldStart: onMicrophoneHoldStart,
        onHoldEnd: onMicrophoneHoldEnd,
      ),
      Padding(
        padding: const EdgeInsetsDirectional.only(
          top: BvSendBackSpec.buttonTop,
        ),
        child: BvButton(
          label: sendLabel,
          onPressed: onSend,
          size: BvButtonSize.medium,
          expand: true,
        ),
      ),
    ];
    if (quote != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSendBackSpec.gap,
        children: content,
      );
    }
    return Container(
      width: BvSendBackSpec.width,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSendBackSpec.paddingHorizontal,
        vertical: BvSendBackSpec.paddingVertical,
      ),
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvSendBackSpec.radius,
        boxShadow: BvShadow.popover,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvSendBackSpec.gap,
          children: content,
        ),
      ),
    );
  }
}

/// One choice of the new date on [BvSendBackCard].
typedef BvSendBackDue = ({
  Key? key,
  String label,
  IconData? icon,
  bool selected,
  VoidCallback onTap,
});

class _Reason extends StatelessWidget {
  const _Reason({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: BvSendBackSpec.reasonPaddingVertical,
          ),
          child: Row(
            spacing: BvSendBackSpec.reasonGap,
            children: [
              BvRadio(selected: selected, small: true),
              Expanded(
                child: Text(
                  label,
                  style: BvType.of(
                    context,
                  ).bodyMd.copyWith(color: BvColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onChanged,
    required this.microphoneLabel,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final String? microphoneLabel;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  @override
  Widget build(BuildContext context) {
    final style = BvType.of(context).bodySm;
    // The microphone's touch area runs the note's full height and 48 wide;
    // past a one-line note it reaches into the gaps above and below.
    return BvTapTarget(
      child: Container(
        padding: const EdgeInsetsDirectional.only(
          start: BvSendBackSpec.notePaddingStart,
        ),
        decoration: const BoxDecoration(
          color: BvColors.surfaceSubtle,
          borderRadius: BvSendBackSpec.noteRadius,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    top: BvSendBackSpec.notePaddingVertical,
                    bottom: BvSendBackSpec.notePaddingVertical,
                    end: onHoldStart == null
                        ? BvSendBackSpec.notePaddingEnd
                        : 0,
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: style.copyWith(color: BvColors.textPrimary),
                    cursorColor: BvColors.actionPrimary,
                    decoration: bvBareField(hint: placeholder, style: style),
                  ),
                ),
              ),
              if (onHoldStart != null)
                Semantics(
                  button: true,
                  label: microphoneLabel,
                  child: GestureDetector(
                    key: const Key('send-back-microphone'),
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (_) => onHoldStart!(),
                    onLongPressEnd: onHoldEnd == null
                        ? null
                        : (_) => onHoldEnd!(),
                    child: const SizedBox(
                      width: BvSendBackSpec.microphoneTouch,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: BvSendBackSpec.notePaddingEnd,
                          ),
                          child: Icon(
                            BvIcons.microphone,
                            size: BvSendBackSpec.microphone,
                            color: BvColors.iconPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
