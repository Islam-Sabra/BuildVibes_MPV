import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_specs.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../l10n/gen/app_localizations.dart';

/// The top of E1 and E2: a warm wash with a quiet site skyline, the
/// wordmark, and the "Starting in {country}" pill. The language switch sits
/// at the top end.
class EntryHero extends ConsumerWidget {
  const EntryHero({super.key, this.countryName});

  /// From the market pack; the pill is hidden without it.
  final String? countryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: BvEntrySpec.heroHeight + topInset,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [BvColors.brandEnergySoft, BvColors.surfaceApp],
                ),
              ),
            ),
          ),
          // Skyline, always drawn left to right like a photo.
          Positioned.fill(
            top: topInset,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                textDirection: TextDirection.ltr,
                children: [
                  for (final (start, width, height) in BvEntrySpec.skyline)
                    Positioned(
                      left: box.maxWidth * start,
                      bottom: BvSpace.s16,
                      width: width,
                      height: height,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: BvColors.borderDefault.withValues(
                            alpha: BvEntrySpec.skylineOpacity,
                          ),
                          borderRadius: BvRadius.smallAll,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            top: topInset + BvSpace.s8,
            end: BvSpace.s8,
            child: TextButton.icon(
              key: const Key('entry-language'),
              onPressed: () => ref
                  .read(localeControllerProvider.notifier)
                  .set(Locale(isArabic ? 'en' : 'ar')),
              icon: const Icon(BvIcons.language, size: BvSize.iconMd),
              label: Text(
                isArabic ? l10n.languageEnglish : l10n.languageArabic,
              ),
              style: TextButton.styleFrom(
                foregroundColor: BvColors.textPrimary,
              ),
            ),
          ),
          Positioned.fill(
            top: topInset + BvSpace.s40,
            child: Column(
              children: [
                Text(
                  l10n.appTitle,
                  style: BvType.latin.displayBrand.copyWith(
                    color: BvColors.brandInk,
                  ),
                ),
                if (countryName != null) ...[
                  const SizedBox(height: BvSpace.s8),
                  Container(
                    key: const Key('entry-country-pill'),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: BvEntrySpec.pillPaddingHorizontal,
                      vertical: BvEntrySpec.pillPaddingVertical,
                    ),
                    decoration: const BoxDecoration(
                      color: BvColors.surfaceElevated,
                      borderRadius: BvRadius.roundAll,
                    ),
                    child: Text(
                      l10n.entryStartingIn(countryName!),
                      style: type.labelMd.copyWith(color: BvColors.textAction),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
