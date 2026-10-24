import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';

/// One tool on [BvWritingToolbar.tools]: its icon, the words read out for
/// it, and a tap, or a hold (a voice note: hold to record, as the post
/// bar's mic). [active] tints it: the tool is in use (F106).
class BvWritingTool {
  const BvWritingTool({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.onHoldStart,
    this.onHoldMove,
    this.onHoldEnd,
    this.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final VoidCallback? onHoldStart;

  /// How far the thumb has moved from where the hold started.
  final ValueChanged<Offset>? onHoldMove;
  final VoidCallback? onHoldEnd;
  final Key? key;

  bool get holds => onHoldStart != null;
}

/// The bar on the keyboard while writing in the Daybook (2527:33399):
/// camera, attach and More at the start, Post at the end. Post is off
/// while [onPost] is null (no title yet), and grey but still tappable
/// while not [postReady] (F56: a tap asks for what is missing).
///
/// [BvWritingToolbar.tools] is the same bar with its own tools: My
/// notebook's slip (F106 NBW1), where a tool in use is tinted and Send
/// keeps the note. While [field] is there (recording a voice note) it
/// takes the place of the tools that don't hold.
class BvWritingToolbar extends StatelessWidget {
  const BvWritingToolbar({
    super.key,
    required String this.cameraLabel,
    required this.onCamera,
    required String this.attachLabel,
    required this.onAttach,
    required String this.moreLabel,
    required this.onMore,
    required this.postLabel,
    required this.onPost,
    this.moreActive = false,
    this.moreKey,
    this.postReady = true,
  }) : tools = null,
       field = null;

  const BvWritingToolbar.tools({
    super.key,
    required List<BvWritingTool> this.tools,
    required this.postLabel,
    required this.onPost,
    this.field,
  }) : cameraLabel = null,
       onCamera = null,
       attachLabel = null,
       onAttach = null,
       moreLabel = null,
       onMore = null,
       moreActive = false,
       moreKey = null,
       postReady = true;

  /// The notebook's own tools, in order.
  final List<BvWritingTool>? tools;

  /// In place of the tools that don't hold (the recording bar).
  final Widget? field;

  // The labels are read out; the buttons show icons only.
  final String? cameraLabel;
  final VoidCallback? onCamera;
  final String? attachLabel;
  final VoidCallback? onAttach;
  final String? moreLabel;
  final VoidCallback? onMore;
  final String postLabel;
  final VoidCallback? onPost;

  /// The More menu is open.
  final bool moreActive;

  /// Everything the post needs is there: Post in the action colour.
  final bool postReady;

  /// On the More button, so the screen can place the More menu over it.
  final Key? moreKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: BvWritingToolbarSpec.height,
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvWritingToolbarSpec.paddingStart,
        BvWritingToolbarSpec.paddingVertical,
        BvWritingToolbarSpec.paddingEnd,
        BvWritingToolbarSpec.paddingVertical,
      ),
      color: BvColors.surfaceElevated,
      // In front, so the line doesn't take height from the tools.
      foregroundDecoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: BvColors.borderSubtle, width: BvStroke.thin),
        ),
      ),
      child: Row(
        children: tools == null
            ? [
                _Tool(
                  icon: BvIcons.camera,
                  label: cameraLabel!,
                  onTap: onCamera,
                ),
                _Tool(
                  icon: BvIcons.attach,
                  label: attachLabel!,
                  onTap: onAttach,
                ),
                _Tool(
                  key: moreKey,
                  icon: BvIcons.more,
                  label: moreLabel!,
                  onTap: onMore,
                  active: moreActive,
                ),
                const Spacer(),
                _Post(label: postLabel, onTap: onPost, ready: postReady),
              ]
            : [
                if (field != null)
                  Expanded(child: field!)
                else
                  for (final t in tools!)
                    if (!t.holds) _tool(t),
                for (final t in tools!)
                  if (t.holds) _tool(t),
                if (field == null) const Spacer(),
                _Post(label: postLabel, onTap: onPost, ready: true),
              ],
      ),
    );
  }

  Widget _tool(BvWritingTool t) => _Tool(
    key: t.key,
    icon: t.icon,
    label: t.label,
    onTap: t.onTap,
    active: t.active,
    tinted: true,
    onHoldStart: t.onHoldStart,
    onHoldMove: t.onHoldMove,
    onHoldEnd: t.onHoldEnd,
  );
}

class _Tool extends StatelessWidget {
  const _Tool({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.tinted = false,
    this.onHoldStart,
    this.onHoldMove,
    this.onHoldEnd,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  /// In use shows in the soft action colour (the notebook's tools, F106);
  /// the Daybook's open More menu is grey.
  final bool tinted;
  final VoidCallback? onHoldStart;
  final ValueChanged<Offset>? onHoldMove;
  final VoidCallback? onHoldEnd;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || onHoldStart != null;
    final start = onHoldStart;
    final move = onHoldMove;
    final end = onHoldEnd;
    Widget tool = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: start == null ? null : (_) => start(),
      onLongPressMoveUpdate: move == null
          ? null
          : (d) => move(d.offsetFromOrigin),
      onLongPressEnd: end == null ? null : (_) => end(),
      child: SizedBox.square(
        dimension: BvWritingToolbarSpec.touch,
        child: Center(
          child: Container(
            width: BvWritingToolbarSpec.tool,
            height: BvWritingToolbarSpec.tool,
            decoration: BoxDecoration(
              color: active
                  ? (tinted
                        ? BvColors.surfaceBrandSoft
                        : BvColors.surfaceSubtle)
                  : null,
              borderRadius: BvWritingToolbarSpec.toolRadius,
            ),
            child: Icon(
              icon,
              size: BvWritingToolbarSpec.toolIcon,
              color: !enabled
                  ? BvColors.actionDisabledForeground
                  : active && tinted
                  ? BvColors.iconAction
                  : BvColors.iconPrimary,
            ),
          ),
        ),
      ),
    );
    if (end != null) {
      // The raw pointer too: a lifted or cancelled thumb (a permission
      // dialog takes the pointer) always ends the hold.
      tool = Listener(
        onPointerUp: (_) => end(),
        onPointerCancel: (_) => end(),
        child: tool,
      );
    }
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      excludeSemantics: true,
      child: tool,
    );
  }
}

class _Post extends StatelessWidget {
  const _Post({required this.label, required this.onTap, required this.ready});

  final String label;
  final VoidCallback? onTap;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && ready;
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('writing-post'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: BvWritingToolbarSpec.touch,
          child: Center(
            child: AnimatedContainer(
              duration: BvMotion.fast,
              curve: BvMotion.standard,
              width: BvWritingToolbarSpec.post,
              height: BvWritingToolbarSpec.post,
              decoration: BoxDecoration(
                color: enabled
                    ? BvColors.actionPrimary
                    : BvColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                BvIcons.send,
                size: BvWritingToolbarSpec.postIcon,
                color: enabled
                    ? BvColors.actionPrimaryForeground
                    : BvColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
