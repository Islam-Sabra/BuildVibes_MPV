import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_segmented.dart';
import 'daybook_draft.dart';
import 'daybook_writing.dart';

/// Review 116 PL1: a poll's options under its question: each in its own
/// field with ✕ (2 to 6), Add an option, and One answer · More than one
/// (one single choice, rule 6).
class ComposerPollEditor extends StatefulWidget {
  const ComposerPollEditor({
    super.key,
    required this.draft,
    required this.writer,
  });

  final DaybookPostDraft draft;
  final DaybookWriter writer;

  @override
  State<ComposerPollEditor> createState() => _ComposerPollEditorState();
}

class _ComposerPollEditorState extends State<ComposerPollEditor> {
  /// One controller per option id, so typing keeps its place.
  final _fields = <String, TextEditingController>{};

  TextEditingController _field(DraftPoint o) =>
      _fields.putIfAbsent(o.id, () => TextEditingController(text: o.text));

  @override
  void didUpdateWidget(ComposerPollEditor old) {
    super.didUpdateWidget(old);
    final ids = {for (final o in widget.draft.pollOptions) o.id};
    for (final id in _fields.keys.toList()) {
      if (!ids.contains(id)) _fields.remove(id)?.dispose();
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final options = widget.draft.pollOptions;
    final canRemove = options.length > DaybookPostDraft.pollOptionsMin;
    return Column(
      key: const Key('composer-poll'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        for (final (i, o) in options.indexed)
          Container(
            key: Key('poll-option-row-$i'),
            decoration: BoxDecoration(
              color: BvColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(BvRadius.control),
            ),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.s12,
            ),
            child: Row(
              spacing: BvSpace.s8,
              children: [
                const PollRing(),
                Expanded(
                  child: TextField(
                    key: Key('poll-option-field-$i'),
                    controller: _field(o),
                    maxLength: DaybookPostDraft.pollOptionMax,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                    // Bare, as the composer's title: the row is the field.
                    decoration: InputDecoration.collapsed(hintText: '')
                        .copyWith(
                          hintText: l10n.pollOptionHint(i + 1),
                          hintStyle: type.bodyMd.copyWith(
                            color: BvColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsetsDirectional.symmetric(
                            vertical: BvSpace.s12,
                          ),
                        ),
                    onChanged: (t) =>
                        unawaited(widget.writer.setPollOption(o.id, t)),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    key: Key('poll-option-remove-$i'),
                    tooltip: l10n.pollRemoveOption,
                    icon: const Icon(
                      BvIcons.close,
                      size: BvSize.iconMd,
                      color: BvColors.iconSecondary,
                    ),
                    onPressed: () =>
                        unawaited(widget.writer.removePollOption(o.id)),
                  ),
              ],
            ),
          ),
        if (options.length < DaybookPostDraft.pollOptionsMax)
          InkWell(
            key: const Key('poll-add-option'),
            onTap: () => unawaited(widget.writer.addPollOption()),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: BvSpace.s8,
              ),
              child: Row(
                spacing: BvSpace.s8,
                children: [
                  const Icon(
                    BvIcons.add,
                    size: BvSize.iconMd,
                    color: BvColors.textAction,
                  ),
                  Text(
                    l10n.pollAddOption,
                    style: type.emphasis.copyWith(color: BvColors.textAction),
                  ),
                ],
              ),
            ),
          ),
        BvSegmented<bool>(
          key: const Key('poll-answers'),
          value: widget.draft.pollMulti,
          segments: [
            BvSegment(
              key: const Key('poll-answers-one'),
              value: false,
              label: l10n.pollOneAnswer,
            ),
            BvSegment(
              key: const Key('poll-answers-more'),
              value: true,
              label: l10n.pollMoreThanOne,
            ),
          ],
          onChanged: (v) => unawaited(widget.writer.setPollMulti(v)),
        ),
      ],
    );
  }
}

/// Review 116: an option's choice mark: an empty ring, or a dark filled
/// circle with a tick when chosen (ink, never the brand red; the founder,
/// 17:49).
class PollRing extends StatelessWidget {
  const PollRing({super.key, this.on = false});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: BvSize.iconMd,
    height: BvSize.iconMd,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? BvColors.textPrimary : null,
      border: Border.all(
        color: on ? BvColors.textPrimary : BvColors.borderInput,
        width: BvSpace.borderWidth,
      ),
    ),
    child: on
        ? const Icon(
            BvIcons.check,
            size: BvSize.iconSm,
            color: BvColors.iconInverse,
          )
        : null,
  );
}
