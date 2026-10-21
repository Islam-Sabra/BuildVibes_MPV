# Review 74: F60, every photo drawn again — 21 Oct 2026

Branch `f60-photo-reencode` (6951e3f). It starts from `claude/review72-app`, so it merges **after** that branch. I read `lib/core/photo_privacy.dart`, every place that picks a photo, the tests and `docs/reviews/f60-fixture-for-lead.md`.

## What held up
- **A JPEG is drawn again:** upright, at most 2560 px, quality 85, with a new EXIF block that holds only DateTimeOriginal and OffsetTimeOriginal. Nothing is copied from the old file.
- **The time is read safely.** Only digits, colons, signs and spaces are kept, and every offset is checked against the segment.
- **Every way a photo enters the app goes through it:**
  - the gallery (one photo and several);
  - the proof camera;
  - the profile photo;
  - the Files picker for the Library and Chat.
- **No HEIC from Files:** right, because its location can't be taken out on the phone.
- **The encode runs off the screen's thread** (`Isolate.run`), and the decode runs in the engine.
- **The tests** cover the thumbnail, the stale string area, sideways photos, the 2560 px limit and small photos.

## Confirmed
- **PNG and WebP keep their pixels** and lose EXIF and XMP. Approved: screenshots and drawings must stay sharp.
- **The colour profile is dropped.** Approved. The phone's decoder already gives standard colours, so the profile no longer describes the pixels anyway. The founder's phone test will show whether anything looks dull.
- **The fixture files are approved to commit,** because I checked the description:
  - grey 64×48 pixels;
  - no thumbnail, maker note or serial;
  - GPS at 0° N, 0° E;
  - the only phone strings are the ones the test hunts for.
  
  Commit them with their test.

## Fix before merging
### H1. A photo is only refused when nobody could open it (founder, 21 Oct: "ok")
Today, when a JPEG can't be decoded, or a PNG or WebP can't be read, or the file can't be written, `cleanPhoto` leaves the file as it is and the original goes up with its location. People must not be stopped from sending photos, and the location must never go up. Use three steps:
1. **Draw the photo again,** as now.
2. **If that fails but the file is still a well-formed JPEG** (its markers read up to SOS), remove every metadata segment without decoding: APP1 to APP15 and COM, which covers EXIF, XMP, maker notes, ICC and the thumbnail. Keep APP0 and the image data, and send the photo.
   - **PNG and WebP that can't be parsed** have no step 2, so they go to step 3.
   - **If writing the file fails,** use a fresh copy in the app's own folder. Never send the original.
3. **Only if the file is broken,** meaning the phone can't read it as an image at all, so nobody in the Space could see it either: drop that photo and show one line, **"This photo can't be opened. Choose another."** / **«تعذّر فتح هذه الصورة. اختر صورة أخرى.»** If several photos were picked, the others still go.

- **`cleanPhoto` returns** one of three results: cleaned, or not an image (a PDF, which goes as it is), or refused.
- **Tests:**
  - a JPEG the decoder refuses but whose markers are well-formed goes up with no APP1–APP15 or COM, and no "Xiaomi" bytes;
  - a broken JPEG, PNG and WebP are each refused;
  - a PDF passes unchanged.

**Noted for after the pilot:** clean photos on the server too. A modified app could skip the phone's cleaning, but it would only expose its own user's location.

### H2. Show that photos are being prepared
Each photo is cleaned one after another right after picking, so up to 3 photos can take several seconds with nothing on screen.
- **If it takes longer than 400 ms,** show the photo slots as **"Preparing…"** / **«جارٍ التجهيز…»** with the usual small spinner, in the place where the photos will appear.
- **The card stays usable** while this happens: the person can keep typing.
- **Clean the photos at the same time** (`Future.wait`), not one after another.

### H3. Measure the speed in the real app (option 2)
- **In the next BuildVibes test build,** log how long each photo takes to clean, in milliseconds, with the picture size before and after, using `debugPrint` only. Don't keep a log file and don't send anything off the phone.
- **The founder posts:**
  - 1 camera photo;
  - 3 gallery photos;
  - 1 full-size photo through Files.
- **Read the times** from `adb logcat` on the PC.
- **If any camera or gallery photo takes more than 2 s,** switch the encoder to the phone's own JPEG encoder, and keep the same rules and tests.

## Standing rule (from this round)
Nothing but the BuildVibes build is installed on the founder's phone without his yes in chat. This includes test apps, helpers and other packages. Write it in `docs/handoff.md`.

## Order
1. Fix H1 (the three steps) and H2, commit the fixtures and their test, and add the timing from H3. Then run analyze and test, and push `f60-photo-reencode`.
2. Merge it after `claude/review72-app` has passed the founder's test, then make one build for the phone.
3. **The founder's check:**
   - post one camera photo and 3 gallery photos;
   - look: are the photos upright and sharp, and are the colours normal?
   - Claude Code confirms that the stored file contains no "Xiaomi", no model and no location, and reports the timings.
