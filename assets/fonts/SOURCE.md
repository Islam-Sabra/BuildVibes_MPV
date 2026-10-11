# BuildVibes font asset provenance (TR-T1)

Copied from the old app (Build-Vibes, mobile/assets/fonts) on 11 Oct 2026. Family names match `BvFonts` in `lib/core/design/bv_tokens.dart`.

## Plus Jakarta Sans

- Family (pubspec): `PlusJakartaSans`
- License: SIL Open Font License 1.1 (`OFL-PlusJakartaSans.txt`)
- Source: official upstream release Tokotype PlusJakartaSans 2.7.1
  https://github.com/tokotype/PlusJakartaSans/releases/tag/2.7.1
- Also catalogued on Google Fonts (OFL)
- Form: static TTF weights (not variable)
- Weights bundled: 400 Regular, 500 Medium, 600 SemiBold, 700 Bold

## Noto Sans Arabic

- Family (pubspec): `NotoSansArabic`
- License: SIL Open Font License 1.1 (`OFL-NotoSansArabic.txt`)
- Source: notofonts/noto-fonts hinted static TTFs
  https://github.com/notofonts/noto-fonts/tree/main/hinted/ttf/NotoSansArabic
- Also catalogued on Google Fonts (OFL); google/fonts ships variable-only for this family
- Form: static TTF weights
- Weights bundled: 400 Regular, 500 Medium, 600 SemiBold, 700 Bold
  (SemiBold included for Latin hierarchy parity; frozen Arabic DS styles use Regular / Medium / Bold)
