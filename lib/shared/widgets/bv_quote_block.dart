import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/l10n/bidi.dart';

/// A message quoted in a post (DM5 2561:76753; review 64): a soft panel,
/// an orange bar at its start, [from] ("From Omar Haddad · 10:42") small
/// and grey, then [text] cut after [maxLines]. The words keep their own
/// direction inside the other language.
class BvQuoteBlock extends StatelessWidget {
  const BvQuoteBlock({
    super.key,
    required this.from,
    required this.text,
    this.maxLines = BvQuoteSpec.linesCard,
    this.onTap,
  });

  final String from;
  final String text;
  final int maxLines;

  /// F87: opens the message it quotes, when the reader may.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final block = ClipRRect(
      borderRadius: BvQuoteSpec.radius,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: BvColors.surfaceSubtle),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ColoredBox(
                key: Key('quote-bar'),
                color: BvColors.actionPrimary,
                child: SizedBox(width: BvQuoteSpec.bar),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: BvQuoteSpec.paddingStart,
                    end: BvQuoteSpec.paddingEnd,
                    top: BvQuoteSpec.paddingVertical,
                    bottom: BvQuoteSpec.paddingVertical,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvQuoteSpec.lineGap,
                    children: [
                      Text(
                        from,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                      Text(
                        inOwnDirection(text),
                        key: const Key('quote-text'),
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: type.bodyMd.copyWith(
                          color: BvColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final tap = onTap;
    return tap == null
        ? block
        : GestureDetector(
            key: const Key('quote-open'),
            behavior: HitTestBehavior.opaque,
            onTap: tap,
            child: block,
          );
  }
}
