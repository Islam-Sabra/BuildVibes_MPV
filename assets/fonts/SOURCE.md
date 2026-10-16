# BuildVibes font asset provenance (TR-T1)

Copied from the old app (Build-Vibes, mobile/assets/fonts) on 11 Oct 2026. Family names match `BvFonts` in `lib/core/design/bv_tokens.dart`.

## Plus Jakarta Sans

- Family (pubspec): `PlusJakartaSans`
- License: SIL Open Font License 1.1 (`OFL-PlusJakartaSans.txt`)
- Source: official upstream release Tokotype PlusJakartaSans 2.7.1
  https://github.com/tokotype/PlusJakartaSans/releases/tag/2.7.1
- Also catalogued on Google Fonts (OFL)
- Form: static TTF weights (not variable)
- Weights bundled: 400 Regular, 500 Medium, 600 SemiBold, 700 Bold, and 800 ExtraBold (added 16 Oct 2026 for the Daybook stamps, from the same 2.7.1 release zip, `ttf/PlusJakartaSans-ExtraBold.ttf`)

## Noto Sans Arabic

- Family (pubspec): `NotoSansArabic`
- License: SIL Open Font License 1.1 (`OFL-NotoSansArabic.txt`)
- Source: notofonts/noto-fonts hinted static TTFs
  https://github.com/notofonts/noto-fonts/tree/main/hinted/ttf/NotoSansArabic
- Also catalogued on Google Fonts (OFL); google/fonts ships variable-only for this family
- Form: static TTF weights
- Weights bundled: 400 Regular, 500 Medium, 600 SemiBold, 700 Bold
  (SemiBold included for Latin hierarchy parity; frozen Arabic DS styles use Regular / Medium / Bold)

## Phosphor (icons)

- Family (pubspec): `PhosphorRegular`
- License: MIT (`LICENSE-Phosphor.txt`)
- Source: `lib/fonts/Phosphor.ttf` from the pub package `phosphor_flutter` 2.1.0 (Phosphor Icons, regular weight), copied 11 Oct 2026.
- Why bundled here: `phosphor_flutter` 2.1.0 (the latest) doesn't compile on Flutter 3.44, because `IconData` is now a final class. The app uses the font through `lib/core/design/bv_icons.dart`; code points come from the package's `PhosphorIconsRegular` table.
