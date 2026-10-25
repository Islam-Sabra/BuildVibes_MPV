# Review 91: the app icon (interim) and a calm splash — 24 Oct 2026

**Founder, 24 Oct:**
- the default Flutter icon has to go;
- he chose **icon 2**: a white cube with an orange **B** on its left face and an orange **V** on its right face, on terracotta;
- the long story animation is parked until a professional designer does the logo and the motion (lead's recommendation).

For the pilot: the icon, plus a short, calm open. This is **interim**: when the real logo comes, only these files change.

## The files (on `main`, in `assets/brand/`)
| File | Use |
|---|---|
| `bv_icon_1024.png` (`bv_icon_full.svg`) | the full icon on terracotta `#C24417`: iOS, Android's legacy icon, the store listing |
| `bv_icon_foreground_1024.png` (`bv_icon_foreground.svg`) | the Android adaptive icon foreground: the cube alone, transparent, inside the 66/108 safe zone |
| `bv_icon_monochrome_1024.png` | the Android 13+ themed icon: alpha only, with B and V cut out |
| `bv_splash_1152.png` (`bv_splash.svg`) | the splash image: the cube alone, transparent, for Android 12's 288 dp splash icon and older Androids |

The B and V are real outlines from Plus Jakarta Sans ExtraBold (the app's own font, OFL), so no font is needed to render them.

## Build (on a new branch `claude/app-icon` from `slice2-app`)
1. **Copy the files:** `git checkout origin/main -- assets/brand`.
2. **The icon:** with `flutter_launcher_icons` (dev dependency):
   - `image_path: assets/brand/bv_icon_1024.png`;
   - Android adaptive: `adaptive_icon_background: "#C24417"`, `adaptive_icon_foreground: assets/brand/bv_icon_foreground_1024.png`, `adaptive_icon_monochrome: assets/brand/bv_icon_monochrome_1024.png`;
   - iOS: `remove_alpha_ios: true`;
   - generate, and commit the generated `mipmap-*` and `AppIcon.appiconset` files.
3. **The splash:** with `flutter_native_splash` (dev dependency):
   - `color: "#C24417"`, `image: assets/brand/bv_splash_1152.png`;
   - `android_12: { color: "#C24417", image: assets/brand/bv_splash_1152.png }`;
   - no branding image, no dark variant (the app is light only);
   - generate and commit.
4. **The handover to the app:** keep the native splash until the app knows where to go, by calling `FlutterNativeSplash.preserve` / `remove` around the existing start-up (session restore, then the router's first screen). Then the first screen fades in over **350 ms**:
   - a plain fade from the splash colour, with no story, no text and no extra delay;
   - if start-up is already done, there's no added wait: the fade is the only extra time;
   - this runs on every start.
5. **Name and label:** the launcher label stays "BuildVibes" in both languages (the name stays Latin).
6. **Checks:**
   - analyze, then the tests;
   - a test that the first screen appears with no splash-only wait;
   - build once, and check on the emulator: the icon on the home screen, round and squircle masks, the themed icon on (Settings › Wallpaper › Themed icons), and the splash on a cold start;
   - screenshots of the home-screen icon and the splash in the report.

**Nothing goes live, and there's no migration.** Install it on the founder's phone and the emulator with his yes.

## Later (not now)
A designer delivers the real logo, the icon, and an opening animation as a Lottie or Rive file. The story:
- people from every trade;
- BuildVibes connects them;
- "Stay connected".

Timings: a first open under 4 s, a daily open under 1 s. The lead writes that brief when the founder says go.

## Addendum, 25 Oct: the cube traces itself while loading (founder: "if it fits, use it")
**The idea** is a logo trace loader, as in dqnamo's "Kitchen" (dqnamo.com/kitchen): a showcase with no code to take, so we only borrow the idea and draw it natively.

**What happens after the native splash** (same terracotta, same cube position, so the handover is seamless):
1. **The trace (≈ 600 ms):**
   - the cube's outline draws itself in white, 2.5 px, round caps, as one continuous pen line: the hexagon, then the inner "Y" where the three faces meet;
   - easing `easeInOutCubic`.
2. **The fill (≈ 200 ms):** the three faces fill (white / `#F8F1E8` / `#E6DACA`) and the outline fades into them.
3. **The letters (≈ 150 ms):** B and V fade in, orange.
4. **The hand-over:** Home fades in over 350 ms, as already built.

**Rules:**
- **It plays only while the app is really loading** (session restore and the first screen's data). If loading ends before the trace has begun (under about 300 ms), there's no trace: straight to the fade. If loading ends mid-trace, the trace finishes quickly (to 1.0 in 150 ms), and then Home comes.
- **Never longer than 1.2 s in total** after the native splash, whatever happens.
- **Reduce motion** (the phone's accessibility setting): no trace, just the fade.
- **Built with no new package:** a `CustomPainter` with `PathMetric.extractPath` for the trace, the same geometry as `assets/brand/bv_splash.svg` (the cube at 0.72 scale), and the letters as paths from the SVG.
- **Tests:**
  - the loader never runs over 1.2 s;
  - it's skipped when loading is fast and when reduce motion is on;
  - it finishes early when loading ends mid-trace.
- **Screenshots:** three frames, at the half-traced outline, the filled cube, and the letters.
