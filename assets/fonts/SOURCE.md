# BuildVibes font asset provenance (TR-T1)

Plus Jakarta Sans and Phosphor were copied from the old app (Build-Vibes, mobile/assets/fonts) on 11 Oct 2026; Almarai was added on 18 Oct 2026. Family names match `BvFonts` in `lib/core/design/bv_tokens.dart`.

## Plus Jakarta Sans

- Family (pubspec): `PlusJakartaSans`
- License: SIL Open Font License 1.1 (`OFL-PlusJakartaSans.txt`)
- Source: official upstream release Tokotype PlusJakartaSans 2.7.1
  https://github.com/tokotype/PlusJakartaSans/releases/tag/2.7.1
- Also catalogued on Google Fonts (OFL)
- Form: static TTF weights (not variable)
- Weights bundled: 400 Regular, 500 Medium, 600 SemiBold, 700 Bold, and 800 ExtraBold (added 16 Oct 2026 for the Daybook stamps, from the same 2.7.1 release zip, `ttf/PlusJakartaSans-ExtraBold.ttf`)

## Almarai (Arabic)

- Family (pubspec): `Almarai`. Replaced Noto Sans Arabic on 18 Oct 2026 (founder's choice, review 50 F33, review 53 Part C); the Noto files are removed.
- Licence: SIL Open Font License 1.1 (`OFL-Almarai.txt`, copied unchanged from the source folder). Copyright 2019 The Almarai Project Authors (https://github.com/JuergenWillrodt/Almarai). Designer: Boutros Fonts, Mourad Boutros.
- Source: google/fonts, folder `ofl/almarai`, at commit `47d54ca1ebb14fd864695f1d39dc734f39017c33` (HEAD on 18 Oct 2026):
  https://raw.githubusercontent.com/google/fonts/47d54ca1ebb14fd864695f1d39dc734f39017c33/ofl/almarai/Almarai-Regular.ttf
  https://raw.githubusercontent.com/google/fonts/47d54ca1ebb14fd864695f1d39dc734f39017c33/ofl/almarai/Almarai-Bold.ttf
  https://raw.githubusercontent.com/google/fonts/47d54ca1ebb14fd864695f1d39dc734f39017c33/ofl/almarai/OFL.txt
- Font version: 1.10 (name ID 5, "Version 1.10"). SHA-256 of the downloaded files: Regular `5b5cad33c8e5922083728d271cdcda91f96ba291f1307eccc4f4ef732dc19622`, Bold `06401391b5b39fbcf2bc0c6a6e03faf992435e7b011183a1861737e913af8613`.
- Weights bundled: 400 Regular and 700 Bold only (Light and ExtraBold are not used). Arabic hierarchy is Bold against Regular.
- Subset with fontTools 4.67.0 (`pyftsubset`) to the Arabic blocks, so Latin letters, digits and Latin punctuation inside Arabic text fall back to Plus Jakarta Sans (`fontFamilyFallback` in `BvType`):

  ```
  pyftsubset Almarai-<Regular|Bold>.ttf     --unicodes="U+0020,U+00A0,U+0600-06FF,U+0750-077F,U+08A0-08FF,U+FB50-FDFF,U+FE70-FEFF,U+200C-200F"     --layout-features='*'     --output-file=Almarai-<Regular|Bold>.ttf
  ```

  - U+0600–06FF includes the Arabic comma, semicolon and question mark (، ؛ ؟), tatweel U+0640 and U+061C (Almarai has no glyph for U+061C or U+200C–200F; the range is listed so they are kept if present).
  - The space and no-break space (U+0020, U+00A0) are kept on purpose: without a space glyph in the first font, the Flutter engine crashed (native illegal instruction) laying out Arabic text with bidi isolates (U+2066–2069) around names and times. With them, the space between Arabic words is Almarai's, as in Figma.
  - Result: 256 code points, 288 glyphs each. SHA-256: Regular `c7d334428a595d2273669cbae427665b837fb4866d673d34248ed56769310324`, Bold `53669d5ab61e5a0114a336a12ff63687c821ff635d53cbe8706bdde9a9c6f852`.

## Phosphor (icons)

- Family (pubspec): `PhosphorRegular`
- License: MIT (`LICENSE-Phosphor.txt`)
- Source: `lib/fonts/Phosphor.ttf` from the pub package `phosphor_flutter` 2.1.0 (Phosphor Icons, regular weight), copied 11 Oct 2026.
- Why bundled here: `phosphor_flutter` 2.1.0 (the latest) doesn't compile on Flutter 3.44, because `IconData` is now a final class. The app uses the font through `lib/core/design/bv_icons.dart`; code points come from the package's `PhosphorIconsRegular` table.
