import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';

/// One action on a [BvHoldMenu]: its icon and words. While not [ready] it
/// shows grey, with [note] (why) under it, and still answers a tap.
class BvHoldAction {
  const BvHoldAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.ready = true,
    this.note,
  });

  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool ready;
  final String? note;
}

/// Review 110 CP5 (2708:39511): holding [child] (Send) opens a small card
/// just above its end with [action] (Post later…); a tap on it closes the
/// card and does it, a tap anywhere else only closes it. With no
/// [action], holding does nothing.
class BvHoldMenu extends StatefulWidget {
  const BvHoldMenu({super.key, required this.child, required this.action});

  final Widget child;
  final BvHoldAction? action;

  @override
  State<BvHoldMenu> createState() => _BvHoldMenuState();
}

class _BvHoldMenuState extends State<BvHoldMenu> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  void _close() {
    if (_portal.isShowing) _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => action == null
            ? const SizedBox.shrink()
            : _Card(link: _link, action: action, onClose: _close),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: action == null ? null : _portal.show,
          child: widget.child,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.link,
    required this.action,
    required this.onClose,
  });

  final LayerLink link;
  final BvHoldAction action;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final colour = action.ready ? BvColors.textPrimary : BvColors.textSecondary;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('hold-menu-away'),
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          // Its end over the button's end, just above it.
          targetAnchor: rtl ? Alignment.topLeft : Alignment.topRight,
          followerAnchor: rtl ? Alignment.bottomLeft : Alignment.bottomRight,
          offset: const Offset(0, -BvHoldMenuSpec.gap),
          child: Material(
            color: BvColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BvHoldMenuSpec.radius,
              side: const BorderSide(
                color: BvColors.borderSubtle,
                width: BvStroke.thin,
              ),
            ),
            shadowColor: Colors.transparent,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: BvHoldMenuSpec.radius,
                boxShadow: BvShadow.menu,
              ),
              child: InkWell(
                key: action.key,
                borderRadius: BvHoldMenuSpec.radius,
                onTap: () {
                  onClose();
                  action.onTap();
                },
                child: Padding(
                  padding: BvHoldMenuSpec.padding,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: BvHoldMenuSpec.gapIcon,
                    children: [
                      Icon(
                        action.icon,
                        size: BvHoldMenuSpec.icon,
                        color: action.ready
                            ? BvColors.actionPrimary
                            : BvColors.iconSecondary,
                      ),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.label,
                              style: BvType.of(
                                context,
                              ).emphasis.copyWith(color: colour),
                            ),
                            if (!action.ready && action.note != null)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: BvHoldMenuSpec.noteWidth,
                                ),
                                child: Text(
                                  action.note!,
                                  key: const Key('hold-menu-note'),
                                  style: BvType.of(context).metadata.copyWith(
                                    color: BvColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
