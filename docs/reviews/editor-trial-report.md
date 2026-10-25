# Editor trial report (review 97) — 25 Oct 2026

**Branch:** `claude/editor-trial`, from `origin/slice2-app` (bc269ec), in a cloud session. Nothing is merged, live, deployed or installed. No database change.

**Package:** `appflowy_editor` **6.2.0** from pub.dev, the latest stable (8 Dec 2025), used under **MPL 2.0**.
- The notice and the package's own LICENSE are in `assets/licences/appflowy_editor.md`.
- None of the package's files were changed. Nothing was read or copied from the AppFlowy app (AGPL); only the package and its own docs and API were looked at.

## Result in one line
**The trial stops at check 1.** `appflowy_editor` does not compile on this app's Flutter (3.44.9), and getting past that needs a change **inside the package**. Review 97 says to stop and report in that case, so checks 2–12 and 15 could not be run.

## Why it stops

### 1. The Flutter version
`DeltaTextInputService` (`lib/src/editor/editor_component/service/ime/delta_input_service.dart`) implements Flutter's `TextInputClient` but lacks `onFocusReceived`, a member Flutter 3.44 added:

```
Error: The non-abstract class 'DeltaTextInputService' is missing implementations for these members:
 - TextInputClient.onFocusReceived
```

- Every published version has it: 5.2.0, 6.0.0, 6.1.0 and 6.2.0 (checked).
- The package's GitHub `main` has the fix (`bool onFocusReceived() => false;`), but it isn't released. `main`'s pubspec still says 6.1.0.
- It is the same kind of break as `phosphor_flutter` (CLAUDE.md, review 50). That one we got around by bundling the font. Here the code itself has to change.

### 2. Its dependencies clash with ours
- **`file_picker`:** the package asks for ^10.2.0; the app is on ^13.1.0 (Library, files on notes).
  - To resolve at all, the trial overrides it to 13 (`dependency_overrides`).
  - The package then fails on file_picker 13's changed API: `FilePicker.platform` (3 places) and `PlatformFile.bytes` (`image_upload_widget.dart`).
  - The only other way is to take the app back to file_picker 10, which is a change in our own code and a step back.
- **`device_info_plus`:** the package asks for ^11, which needs win32 5; our `share_plus` 13 needs win32 6. The trial overrides it to 13.3.0.
  - That one doesn't show a compile error, but it is untested: the package was built against 11.
  - The package's `main` asks for ^12.3.0, which still needs win32 5, so the next release would clash too.

### 3. Why no "Editor trial" screen
- Every file of the package, its document model included (`src/core/document/*`), imports the whole package. So nothing of it compiles, not even the converter's types.
- A debug-only screen would have to import it. The app's tests import the router, so **every** app test would then fail to compile.
- So no screen was added. Production navigation and the current notebook are untouched.
- `tool/editor_trial/compile_probe_test.dart` reproduces the failure on its own: `flutter test tool/editor_trial/compile_probe_test.dart`.

## The checklist

| # | Check | Result | Evidence and notes |
|---|---|---|---|
| 1 | Builds | **fail** | `flutter analyze` is clean (it doesn't analyse the package). The package doesn't compile on Flutter 3.44: the probe's output is quoted above. APK size not measured (no build). |
| 2 | Typed shortcuts | not run (blocked) | **On paper:** `characterShortcutEvents` is a list we pass in, so any shortcut can be left out or replaced by our own. It has `1.` (numbered), `-` and `*` (bullet), `[]` (to-do) and `#` (heading). **Quote is `"`, not `>`**: ours would be a custom event. |
| 3 | `/` menu | not run (blocked) | **On paper:** the `/` menu takes our own items (`SelectionMenuItem`, with our names and icons), so ARB names fit. **No Arabic strings ship** (23 languages, no `ar`). Our items carry our own words. Its built-in strings (toolbar, image and link dialogs) would need hiding or wrapping. Arabic filtering and "grouped as on phones": unknown. |
| 4 | Arabic | not run (blocked) | **On paper:** per-block text direction (`blockComponentTextDirection`: ltr, rtl, auto). The numbered list's deeper levels use Latin letters and Roman numerals, as review 93 wants, but its exact rules (restart and continue) aren't checked. Marker side and indent direction in RTL: unknown. |
| 5 | Children | not run (blocked) | **On paper:** nodes hold real children, and indent and outdent commands move them. Our `notes.blocks` is a flat list with `indent`, so the converter would nest and unnest (no data change). `folded` would be our own attribute and our own drawing. |
| 6 | Our bar | not run (blocked) | **On paper:** the mobile toolbar is a separate widget we don't have to use, so our bar (+, Indent and Outdent, the additions, Save) could drive the editor through its commands. |
| 7 | Line menu | **PC later** | Not run. Needs the device for feel. |
| 8 | `+` vs Turn into | not run (blocked) | **On paper:** possible through transactions (insert a node below; change a node's type). |
| 9 | Our blocks | not run (blocked) | **On paper:** custom block components (`blockComponentBuilders`) can draw voice, photo and file with our widgets. Location and the date or reminder are **note fields** (migration 44), not blocks, so they stay outside the editor. |
| 10 | Our data | not run (blocked) | **On paper:** possible. Its `Document` is JSON with nested nodes. Ours is flat: `text`, `heading`, `todo`, `bullet`, `numbered`, `toggle`, `table`, `callout`, `quote`, `divider`, `voice`, with `indent`, `start` and `folded`. **No round-trip test could run**, because the package's types don't compile. `table` and `toggle` would need checking against its table and toggle blocks. |
| 11 | Tokens | not run (blocked) | **On paper:** `EditorStyle` and each block's style take our `BvType` styles and `bv_tokens` colours. Its own dialogs and pickers have their own look. |
| 12 | Undo | not run (blocked) | **On paper:** the package has an undo manager over its transactions, so typing, Turn into, indent and moves undo in one place. |
| 13 | Speed | **PC later** | |
| 14 | Screen reader | **PC later** | |
| 15 | Tests | **fail** | No widget test can drive the editor under `flutter test`: it doesn't compile. The probe is the one test, and it fails. |

"On paper" means read from the package's own public API and docs, not run.

## What would have to change inside the package (MPL: a changed file must be published)
1. `delta_input_service.dart`: add `onFocusReceived`. It is upstream on `main`, not released.
2. `file_picker_impl.dart` and `image_upload_widget.dart`: move to file_picker 13's API. This is needed while the app is on file_picker 13.
3. Probably the pubspec ranges for `file_picker` and `device_info_plus`, so that it resolves without overrides.

Doing these ourselves means **forking the package**:
- publishing every changed file under MPL;
- keeping the fork in step with upstream;
- carrying the version risk ourselves, on every Flutter update.

The trial was told not to.

## Size of adopting it (if it compiled)
- **Would move out of our code** (about 1,900 lines):
  - `note_page_editor.dart` (1,040 lines): the lines' typing, Enter, Backspace, indent and outdent, fold, Turn into, `/`, and ticking;
  - `note_outline.dart` (243 lines): the numbering;
  - most of `page_block_editing.dart` (618 lines, shared with Work).
- **Would stay:**
  - the `PageBlock` model and the save path (`notebook_state.dart`);
  - our bar and the additions (`note_writing.dart`, 773 lines);
  - the voice, photo and file widgets;
  - the location and date fields;
  - the ARB strings and the block menu's rows.
- **Would be new:**
  - the converter (flat `indent` list to nested nodes and back, with `start` and `folded`);
  - our custom blocks;
  - shortcut and `/` lists from ARB;
  - wrapping or hiding the package's English-only dialogs.
- **Work's post pages** (`daybook_page_editor.dart`, 1,378 lines) would stay as they are until a second step.
- **Cost on top:**
  - about 48,000 lines of package code, with its own dependency chain: `keyboard_height_plugin`, `flutter_svg`, `markdown`, `html`, `universal_html`, `scroll_to_index` and others;
  - its pins now hold back or clash with ours (file_picker, win32).

## Recommendation
**Keep our editor and add the rules ourselves.** Don't adopt `appflowy_editor` now.
- It can't be used from pub.dev on our Flutter without forking it, which the trial's licence rule exists to avoid.
- Its pins already clash with two of our packages, and the next upstream release would still clash (win32 5).
- The parts we most need are already ours and tested, in EN and AR (about 1,950 app tests):
  - Arabic first, markers on the right;
  - review 93's numbering;
  - `notes.blocks` with nothing lost;
  - our bar, our blocks and our tokens.
- The behaviour worth copying is behaviour, not code. Each item is a small, testable addition to our editor:
  - the `>` quote shortcut and a way to turn shortcuts off;
  - `/` filtering as you type;
  - one undo history across typing, Turn into, indent and moves;
  - Move up and Move down carrying children.

**Look again only if** upstream releases a version that compiles on our Flutter and resolves next to our packages without overrides. Then this trial can be run again as it is: the branch, the probe and the checklist are ready. If the founder doesn't want that, the branch can be deleted: nothing else depends on it.
