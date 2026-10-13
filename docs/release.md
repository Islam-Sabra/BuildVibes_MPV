# Release builds (review 30 §2)

**For:** whoever makes a build for testers, and the lead reviewing it.
Nothing here goes to testers until the lead has reviewed the `release` branch.

## The app

| | Value |
|---|---|
| App id (Android and iOS) | `com.buildvibes.buildvibes` |
| Name | BuildVibes |
| Icon | the current icon in the repo (the new logo comes later) |
| Version | `0.9.0+1` in `pubspec.yaml`: 0.9.0 is the version name, 1 the build number |

**Every build for testers raises the build number by one:** `0.9.0+2`, `0.9.0+3`, and so on. The stores refuse a build number they have already seen.

## Release settings

- **Live project only:** `env/prod.json` holds the live project's URL and its public anon key. It is git-ignored, like every file in `env/` except `example.json`.
- **No Components screen and no debug banner:** the Components row and its route exist only in debug builds (`kDebugMode`), and `debugShowCheckedModeBanner` is off.
- **Off in the pilot:** phone sign-in, Google and Apple sign-in, and Translate. They stay off unless a define turns them on, and the release build passes none.

## Building (Android)

```
flutter build apk --release --dart-define-from-file=env/prod.json
```

The APK is at `build/app/outputs/flutter-apk/app-release.apk`. For Google Play, build an app bundle (`flutter build appbundle …`) instead.

## The upload key

- **Where it is:** `D:\Projects\00 AECOX Technology\BuildVibes keys\`, next to the project folder and outside the repo. The folder holds:
  - `buildvibes-upload.jks`, the key;
  - `key.properties`, its passwords;
  - `README.txt`.
- **How the build finds it:** the release build reads `key.properties` from that folder. Set `BV_KEY_PROPERTIES` to use another path.
- **Without it:** a release build stops with a message. It never falls back to the debug key. Debug builds don't need the key.
- **Never** put the key or its passwords in git, chat or email.
- **The founder keeps two copies of the whole folder:** this PC, and a USB drive or a password manager.
- **Losing it** means the app can't be updated in Google Play. If that happens, Play can reset the upload key once the app is enrolled in Play App Signing, but it takes days.
- **The key's certificate:** "CN=BuildVibes, O=AECOX Technology", RSA 2048, valid for about 27 years. The 13 Oct release APK was checked: it is signed with this key, not the debug key.

## Crash reports (Firebase Crashlytics)

- **Release builds only.** Collection is off in the manifest, and the app turns it on only when `kReleaseMode` (`lib/core/crash/crash_reports.dart`).
- **No personal text.** A report carries the error's type (for example "StateError") and its stack trace, which is file and function names. Error messages are never sent, because a message can contain what someone typed. No user id, no custom keys and no logs are set. A test checks this (`test/core/crash_reports_test.dart`).
- **Native crashes:** Android crashes outside Dart are reported by Crashlytics itself, with no app text.
- **Where to read them:** the Firebase console → Crashlytics, project BuildVibes.

## Getting the build to testers: Firebase App Distribution (free, no Play account)

After the lead's review, with the founder's yes:
1. **The founder** opens the Firebase console → App Distribution, picks the Android app `com.buildvibes.buildvibes` and clicks "Get started".
2. **The founder** adds the testers' emails under "Testers and groups", in a group called "week 9". The emails stay in Firebase, never in the repo.
3. **Claude Code** uploads the APK:
   - with the Firebase CLI (`firebase appdistribution:distribute … --groups "week 9"`), after the founder signs in to it once;
   - or the founder drags the APK into the console.
4. **The testers** get an email with an install link. They allow "install from this source" once on their phone.

## iPhone (waits for Apple's approval; nothing is built yet)

- **Bundle id:** `com.buildvibes.buildvibes`, registered in the Apple Developer account once it is approved.
- **Push:**
  - turn on the Push Notifications capability and the background mode "Remote notifications";
  - create an APNs key (.p8) in the developer account and upload it to Firebase → Project settings → Cloud Messaging;
  - the key file stays out of git, like the Android key.
- **Firebase:** add an iOS app with the bundle id, and download `GoogleService-Info.plist` into `ios/Runner/` (git-ignored, like `google-services.json`).
- **Signing:** automatic signing with the founder's team in Xcode. It needs a Mac, or a cloud Mac build (Codemagic's free tier), to be chosen when Apple approves.
- **Delivery:** TestFlight (review 30 §0b).
