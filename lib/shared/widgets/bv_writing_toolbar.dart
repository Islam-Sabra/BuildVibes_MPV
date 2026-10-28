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
    this.dot,
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

  /// Review 100 Part 5: something is attached with it (📷, 📎): a small dot
  /// at its corner, with this key.
  final Key? dot;

  bool get holds => onHoldStart != null;
}

/// The bar on the keyboard while writing in the Daybook (2527:33399):
/// camera, attach and More at the start, Post at the end. Post is off
/// while [onPost] is null (no title yet), and grey but still tappable
/// while not [postReady] (F56: a tap asks for what is missing).
///
/// [BvWritingToolbar.tools] is the same bar with its own tools: My
/// notebook's additions bar (F107 NBX1 2619:36779): the + for the
/// block list at the start ([categories]), then the additions; Send keeps
/// the note. While [field] is there (recording a
/// voice note) it takes the place of the tools that don't hold.
///
/// Review 100 Part 5 (BH6): + · Photo · Add, then [beside] (⇥ ⇤ while a
/// list line can move), then the voice (a tool that holds) and Send at the
/// far end; a tool whose card is open shows on a grey square, and one in
/// use has a dot.
///
/// Review 93: [beside] (⇥ ⇤ while a line can move) stand right after the
/// +; the additions then scroll sideways when they no longer fit, with
/// the mic kept in sight.
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
       field = null,
       categories = null,
       categoriesOpen = false,
       beside = const [];

  const BvWritingToolbar.tools({
    super.key,
    required List<BvWritingTool> this.tools,
    required this.postLabel,
    required this.onPost,
    this.field,
    this.categories,
    this.categoriesOpen = false,
    this.beside = const [],
  }) : cameraLabel = null,
       onCamera = null,
       attachLabel = null,
       onAttach = null,
       moreLabel = null,
       onMore = null,
       moreActive = false,
       moreKey = null,
       postReady = true;

  /// The + at the start: the categories grid (F107).
  final BvWritingTool? categories;

  /// The grid is open: the + is solid.
  final bool categoriesOpen;

  /// Right after the + (a note's ⇥ and ⇤).
  final List<BvWritingTool> beside;

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
                if (field != null) ...[
                  Expanded(child: field!),
                  for (final t in tools!)
                    if (t.holds) _tool(t),
                ] else ...[
                  if (categories case final c?)
                    _Categories(tool: c, open: categoriesOpen),
                  for (final t in tools!)
                    if (!t.holds) _tool(t),
                  for (final t in beside) _tool(t),
                  const Spacer(),
                  for (final t in tools!)
                    if (t.holds) _tool(t),
                ],
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
    dot: t.dot,
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
    this.dot,
    this.onHoldStart,
    this.onHoldMove,
    this.onHoldEnd,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Its card or menu is open: a grey square under it.
  final bool active;
  final VoidCallback? onHoldStart;
  final ValueChanged<Offset>? onHoldMove;
  final VoidCallback? onHoldEnd;
  final Key? dot;

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
      child: SizedBox(
        width: BvWritingToolbarSpec.touch,
        height: BvWritingToolbarSpec.touch,
        child: Center(
          child: Container(
            width: BvWritingToolbarSpec.tool,
            height: BvWritingToolbarSpec.tool,
            decoration: BoxDecoration(
              color: active ? BvColors.surfaceSubtle : null,
              borderRadius: BvWritingToolbarSpec.toolRadius,
            ),
            child: Icon(
              icon,
              size: BvWritingToolbarSpec.toolIcon,
              color: !enabled
                  ? BvColors.actionDisabledForeground
                  : BvColors.iconPrimary,
            ),
          ),
        ),
      ),
    );
    if (dot case final dot?) {
      tool = Stack(
        children: [
          tool,
          PositionedDirectional(
            top: BvWritingToolbarSpec.dotInset,
            end: BvWritingToolbarSpec.dotInset,
            child: Container(
              key: dot,
              width: BvWritingToolbarSpec.dot,
              height: BvWritingToolbarSpec.dot,
              decoration: const BoxDecoration(
                color: BvColors.iconAction,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }
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

/// The + for the block list (review 100 BH6, BH8): a plain +, on a grey
/// square while its card is open.
class _Categories extends StatelessWidget {
  const _Categories({required this.tool, required this.open});

  final BvWritingTool tool;
  final bool open;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tool.label,
    selected: open,
    excludeSemantics: true,
    child: GestureDetector(
      key: tool.key,
      behavior: HitTestBehavior.opaque,
      onTap: tool.onTap,
      child: SizedBox(
        width: BvWritingToolbarSpec.touch,
        height: BvWritingToolbarSpec.touch,
        child: Center(
          child: AnimatedContainer(
            duration: BvMotion.fast,
            curve: BvMotion.standard,
            width: BvWritingToolbarSpec.tool,
            height: BvWritingToolbarSpec.tool,
            decoration: BoxDecoration(
              color: open ? BvColors.surfaceSubtle : null,
              borderRadius: BvWritingToolbarSpec.toolRadius,
            ),
            child: Icon(
              tool.icon,
              size: BvWritingToolbarSpec.toolIcon,
              color: BvColors.iconPrimary,
            ),
          ),
        ),
      ),
    ),
  );
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
