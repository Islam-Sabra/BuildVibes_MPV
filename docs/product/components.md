# BV components — spec from Figma (11 Oct 2026)

Source: Figma `IcoK4u8JFO6K8l4YYiHNkm`. The pages are "DS · Button", "DS · Chip & Tab", "DS · Inputs", "DS · Controls", "DS · Rows", "DS · Avatar & Badge" and "DS · Sheet", plus the Spaces screens W3a, W3e, S10k-C and S20 v3.

Build each one once in `lib/shared/widgets/`, using `bv_tokens.dart` only. Use directional padding and alignment (start/end, never left/right). Each component gets a widget test in English and Arabic.

**Token names:** some Figma layers use old names. Map them like this:
| Old name | Token |
|---|---|
| surface/default | `surfaceElevated` |
| bg/default | `surfaceApp` |
| bg/subtle | `surfaceSubtle` |
| text/tertiary | `textSecondary` |
| border/strong (old) | `borderDefault` |
| surface/inverse | `brandInk` |

**Overline text** (for example "NEEDS YOU" or "SIGN-OFF") uses the `overline` style. Write the string in capitals in the English ARB file. Arabic has no capitals, so the Arabic string is written normally.

## 1. BvButton
Radius 10 (`BvRadius.control`), gap 8, optional leading icon 20, text style `button`.

| Size | Height | Side padding |
|---|---|---|
| Large | 52 | 20 |
| Medium | 44 | 16 |

| Style | Default | Pressed | Disabled |
|---|---|---|---|
| Primary | fill `actionPrimary`, text `actionPrimaryForeground` | fill `actionPrimaryPressed` | fill `actionDisabled`, text `actionDisabledForeground` |
| Secondary | fill `actionSecondary`, border `borderInput` 1, text `textPrimary` | fill `surfaceSubtle` | fill `actionDisabled`, no border |
| Tertiary | no fill, text `textAction` | fill `surfaceSubtle` | text `actionDisabledForeground` |
| Destructive | fill `actionSecondary`, border `borderDestructive` 1, text `textDestructive` | fill `surfaceSubtle` | as disabled |

Focused (keyboard or accessibility focus): border `borderFocus` 2. Full-width buttons in footers use Large.

## 2. BvChip
- **Shape:** 36 high, padding 6 vertical and 12 horizontal, radius 10, gap 6.
- **Content:** optional icon 16, label `labelMd`.
- **Default:** fill `surfaceElevated`, border `borderDefault` 1, text `textPrimary`.
- **Selected:** fill `surfaceBrandSoft`, border `borderSelected` 1, text `textPrimary`.
- **Ink** (for example the "All" filter, when it's selected): fill `brandInk`, text `textInverse`.
- **Rows of chips** scroll horizontally, with a gap of 8.

## 3. BvTabs (top tabs, for example Home's Feed / Spaces)
- **Size:** each tab is 48 high, with 16 padding on each side.
- **Active:** label `labelLg`, `textPrimary`, with a 2 px indicator in `surfaceSelected` (radius 1) along the bottom edge.
- **Inactive:** label `labelMd`, `textSecondary`, no indicator.

## 4. BvTextField
Parts, top to bottom, with a gap of 6:
1. Label: `labelMd`, `textPrimary`.
2. Field:
   - 48 high, 12 padding on each side, radius 10;
   - fill `surfaceElevated`, border `borderInput` 1;
   - value text `bodyLg`, `textPrimary`; placeholder `textSecondary`.
3. Helper (optional): `metadata`, `textSecondary`.

States:
- **Focused:** border `borderFocus` 2.
- **Error:** border `borderDestructive` 2. The helper turns `textDestructive`, with a warning-circle icon (14) before it.

**Variants built on the same field:**
- **BvSelect:** a caret-down icon (20) at the end. Tapping it opens a bottom sheet with a single-choice list.
- **Phone field:** the country code comes from the market pack.
- **Code input:** 6 digits.
- **Multi-line:** shows a character counter when it's near the limit.

## 5. BvSearchField
- **Shape:** 48 high, 12 padding on each side, radius 10.
- **Default:** fill `surfaceSubtle`, no border.
- **Content:** magnifying-glass icon 20, text `bodyMd` (placeholder `textSecondary`).
- **Focused:** fill `surfaceElevated`, border `borderFocus` 2.

## 6. Controls (each has a 48 × 48 tap area)
- **Switch:**
  - track 48 × 28, radius 14, padding 2; thumb 24, `surfaceElevated`;
  - track colour: on `actionPrimary`, off `borderInput`, disabled `actionDisabled`;
  - the thumb sits at the end when on, so it mirrors in right-to-left.
- **Checkbox:**
  - box 22, radius 6;
  - checked: `actionPrimary` with a check icon 16, `iconInverse`;
  - unchecked: `surfaceElevated` with a `borderInput` 1.5 border.
- **Radio:**
  - ring 22;
  - selected: `actionPrimary` border 2, with a dot 10 in `actionPrimary`;
  - unselected: `borderInput` 1.5 border.

## 7. BvListRow
- **Layout:** padding 12 vertical and 16 horizontal, gap 12, fill `surfaceElevated`, minimum height 64.
- **Leading (optional):** icon tile 40, radius 10, fill `brandEnergySoft`, with an icon 24 in `iconAction`. An avatar can take its place.
- **Text:**
  - title `titleMd`, `textPrimary`;
  - subtitle (optional) `bodySm`, `textSecondary`;
  - gap 2.
- **Trailing (one of):**
  - **chevron:** caret-right 20, `iconSecondary`, mirrored in right-to-left;
  - **switch;**
  - **value:** `bodyMd`, `textSecondary`, followed by a chevron;
  - **none.**
- **Dividers:** 1 px `borderDefault` between rows, inset to start after the leading tile.

## 8. BvChoiceCard (single choice, for example "Visibility option" and the Access, Who can invite and Notifications sheets)
- **Layout:** padding 12 vertical and 16 horizontal, gap 12, radius 14.
- **Content:** optional icon 24; title `titleMd`; description `bodySm`, `textSecondary`; Radio at the end.
- **Selected:** fill `surfaceBrandSoft`, border `borderSelected` 2.
- **Unselected:** fill `surfaceElevated`, border `borderDefault` 1.
- **Rule:** use this for **every** set of mutually exclusive choices, never switches.

## 9. BvAvatar
| Size | Dimension | Initials style | Company radius |
|---|---|---|---|
| sm | 32 | `labelSm` | 8 |
| md | 40 | `labelMd` | 8 |
| lg | 56 | `titleLg` | 14 |
| xl | 88 | `headingXl` | 14 |

- **Shape:** a person is a circle; a company is a rounded square.
- **Without a photo:** fill `surfaceSubtle`, border `borderDefault` 1, initials in `textPrimary`. Arabic names use Arabic initials.
- **With a photo:** the photo fills the shape.
- **Project and Space avatars:** use `BvProjectColors.forId(id)` as the tile colour, with a white icon.

## 10. BvBadge
- **Shape:** 20 high, padding 2 vertical and 8 horizontal, radius 6, text `labelSm`.

| Tone | Fill | Text |
|---|---|---|
| Neutral | `surfaceSubtle` | `textSecondary` |
| Brand | `surfaceBrandSoft` | `textAction` |
| Positive | `surfaceSubtle` | `textPositive` |
| Warning | `surfaceSubtle` | `textWarning` |

## 11. BvBottomSheet
- **Scrim:** `overlayScrim`. Tapping it closes the sheet.
- **Sheet:**
  - fill `surfaceApp`, top radius 20 (`BvRadius.sheetTop`), shadow `BvShadow.sheet`;
  - padding 10 at the top and 16 on the sides; bottom padding is the safe area plus 16;
  - gap 12;
  - a handle at the top centre: 36 × 4, radius 2, `borderDefault`.
- **Header:** title `titleLg`, with an optional subtitle in `bodySm`, `textSecondary`.
- **Footer (optional):** two Large buttons sharing the width equally: Secondary (Cancel) and Primary (Confirm).
- **Motion:** `BvMotion.sheet`, `BvMotion.enter`.

## 12. BvStamp (the "site paperwork" signature element)
- **Shape:** outlined label, border 2, radius 6, padding 3 vertical and 8 horizontal.
- **Text:** `labelMd`, the same colour as the border.

| Tone | Colour | Used for |
|---|---|---|
| Action | `textAction` | IDs such as KCT-021, SELECTED |
| Positive | `textPositive` | CHECKED |
| Muted | `textSecondary` | — |

- **Rotation:** optional, −3°. Use it for status stamps (CHECKED, SELECTED), not for IDs. In right-to-left, rotate +3°.

## 13. BvSiteTag (the work item detail header, W3a)
**Outer card:** radius 16, fill `surfaceElevated`, border `borderDefault` 1.5.

**Punched hole:** a 12 circle at the top centre, 8 from the top. Fill `surfaceApp`, same border.

**Head:** padding 14 top, 16 sides, 10 bottom.
- start: Stamp (Action tone) with the item ID;
- end: team name in `overline`, `textSecondary`.

**Body:** padding 0 top, 16 sides, 14 bottom; gap 8.
- title: `titleLg`;
- place row: map-pin icon 16 + `bodyMd`, `textSecondary`.

**Title-block cells:** a row of 3 equal cells — FROM, OWNER, DUE.
- top border and dividers: `borderDefault` 1;
- each cell: padding 10 vertical and 12 horizontal, gap 4; label in `overline`, `textSecondary`; value in `labelMd`, `textPrimary`;
- the DUE value is `textAction`, or `textDestructive` when overdue.

## 14. BvSignOffStrip (RAISED · DONE · CHECKED)
- **Section label:** "SIGN-OFF" in `overline`, `textSecondary`, with a gap of 8 above the strip.
- **Strip:** radius 12, border `borderDefault` 1, fill `surfaceElevated`, 3 equal cells with 1 px dividers.
- **Each cell:** padding 10 top, 10 sides, 12 bottom; gap 6.
  - step name in `overline`;
  - person in `labelMd`;
  - signature line 1 px;
  - date and time in `metadata`.
- **Signed cell:** step `textAction`, person `textPrimary`, signature line `borderInput`, date `textSecondary`.
- **Waiting cell:** fill `surfaceSubtle`; step, "—" and "Waiting" all in `textSecondary`; signature line `borderDefault`.

## 15. BvWorkItemCard (lists: Work tab, Needs you)
- **Card:** radius 14, fill `surfaceElevated`, border `borderDefault` 1. The whole card is tappable.
- **Header strip:** fill `surfaceSubtle`, padding 12 vertical and 16 horizontal.
  - start: "KCT-021 · STRUCTURE" in `overline`, `textSecondary`;
  - end: status line in `overline`.

  | Status | Example | Colour |
  |---|---|---|
  | Open | OPEN · DUE SUN 12 OCT | `textAction` |
  | Done | DONE · YOU CHECK IT | `textAction` |
  | Checked | CHECKED · THU 9 OCT | `textPositive` |
  | Overdue | — | `textDestructive` |

- **Body:** padding 14 vertical and 16 horizontal, gap 4.
  - title `titleMd`;
  - place `metadata`, `textSecondary`;
  - people line `bodySm`, `textSecondary`, for example "Owner: you · from Sara Al-Mutairi".
- **Evidence row** (Done and Checked only): photo thumbnail 40, radius 8, then a line in `labelSm`.
  - Done: `textSecondary`, with the quoted note.
  - Checked: `textPositive`, for example "Checked by Sara · 1 photo".
- **Action row (optional):** padding 0 top, 16 sides, 14 bottom. Label in `labelMd`, `textAction`, for example "Sign as done" or "Check it". It's shown only when the viewer can act.

## 16. BvPassCard (Lead / Crew / Viewer)
**Card:** radius 12; a colour band 8 wide at the start edge.

| Pass | Band colour |
|---|---|
| Lead | `brandInk` |
| Crew | `actionPrimary` |
| Viewer | `borderInput` |

**Content:** padding 10 vertical and 12 horizontal, gap 3.
- header row: pass name in `overline` (for example "CREW PASS"), with a Stamp "SELECTED" (Action tone, −3°) when selected;
- "Opens: …" line in `bodySm`, `textPrimary`;
- "who it's for" line in `metadata`, `textSecondary`.

**States:**
- Selected: fill `brandEnergySoft`, border `actionPrimary` 2.
- Unselected: fill `surfaceElevated`, border `borderDefault` 1.

## 17. BvSitePhoto with stamp
- **Photo:** radius 14, cover-fit.
- **Stamp overlay:** at the bottom start, 12 from the edges.
  - fill `brandInk`, radius 8, padding 6 vertical and 10 horizontal, gap 6;
  - map-pin icon 14 in `iconInverse`;
  - text `labelSm`, `textInverse`, for example "Level 2 · Grid C7 · 09:40 · Omar Haddad".
- **Loading or missing:** placeholder fill `surfaceSubtle`.

## Bottom bar
Already built. See review 01.
