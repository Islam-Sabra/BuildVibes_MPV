import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';

/// The bar on the keyboard while writing in the Daybook (2527:33399):
/// camera, attach and More at the start, Post at the end. Post is off
/// while [onPost] is null (no title yet), and grey but still tappable
/// while not [postReady] (F56: a tap asks for what is missing).
class BvWritingToolbar extends StatelessWidget {
  const BvWritingToolbar({
    super.key,
    required this.cameraLabel,
    required this.onCamera,
    required this.attachLabel,
    required this.onAttach,
    required this.moreLabel,
    required this.onMore,
    required this.postLabel,
    required this.onPost,
    this.moreActive = false,
    this.moreKey,
    this.postReady = true,
  });

  // The labels are read out; the buttons show icons only.
  final String cameraLabel;
  final VoidCallback? onCamera;
  final String attachLabel;
  final VoidCallback? onAttach;
  final String moreLabel;
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
        children: [
          _Tool(icon: BvIcons.camera, label: cameraLabel, onTap: onCamera),
          _Tool(icon: BvIcons.attach, label: attachLabel, onTap: onAttach),
          _Tool(
            key: moreKey,
            icon: BvIcons.more,
            label: moreLabel,
            onTap: onMore,
            active: moreActive,
          ),
          const Spacer(),
          _Post(label: postLabel, onTap: onPost, ready: postReady),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: BvWritingToolbarSpec.touch,
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
                color: onTap == null
                    ? BvColors.actionDisabledForeground
                    : BvColors.iconPrimary,
              ),
            ),
          ),
        ),
      ),
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
