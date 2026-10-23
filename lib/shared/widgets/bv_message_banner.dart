import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';

/// F81: a quiet banner for a direct message that arrives while the app is
/// open: who it is from, then the words (or "Open BuildVibes to read it"
/// when the person keeps message text off the lock screen).
class BvMessageBanner extends StatelessWidget {
  const BvMessageBanner({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Material(
      color: BvColors.surfaceElevated,
      borderRadius: BvMessageBannerSpec.radius,
      elevation: 0,
      child: InkWell(
        borderRadius: BvMessageBannerSpec.radius,
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BvMessageBannerSpec.radius,
            boxShadow: BvShadow.popover,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(
              BvMessageBannerSpec.padding,
            ),
            child: Row(
              spacing: BvMessageBannerSpec.padding,
              children: [
                const Icon(
                  BvIcons.chat,
                  size: BvSize.iconMd,
                  color: BvColors.iconSecondary,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: BvMessageBannerSpec.gap,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: directionOf(title),
                        style: type.emphasis,
                      ),
                      Text(
                        body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: directionOf(body),
                        style: type.bodySm.copyWith(
                          color: BvColors.textSecondary,
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
    );
  }
}
