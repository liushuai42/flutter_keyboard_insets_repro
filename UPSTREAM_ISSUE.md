# [Android] Phantom IME inset remains after returning through Recent apps

## Description

After a Flutter `TextField` opens the Android keyboard, switching to another
app through Recent apps and then returning can leave a keyboard-sized bottom
inset even though no keyboard is visible. The stale inset can survive popping
the route that contained the `TextField` and affect the previous route.

This appears related to, but is observably different from, flutter/flutter
#21193. The main symptom here is not only retained input focus: the invisible
IME inset changes layout globally and can remain after the editable route has
been disposed.

The issue has been observed in an application using both Flutter 3.47.9 and
3.50.0, so it does not appear to be introduced by the 3.50.0 upgrade.

The Android device used for the minimal reproduction is a Google Pixel 8 Pro
running Android 17 (API 37), build `CP2A.260805.005`.
With Flutter 3.50.0, the issue reproduces in both debug and profile build modes.

The issue did not reproduce on a Google Pixel 9 running Android 17 (API 37),
build `CP3A.261005.005`, with Gboard `18.5.10.993608717-release-arm64-v8a`.
It also did not reproduce on a Google Pixel 10 Pro XL running Android 16
(API 36), build `CP1A.260505.005`, with Gboard
`18.5.6.993608717-release-arm64-v8a`.

## Steps to reproduce

1. Run the attached `keyboard_insets_repro` project on Android.
2. Open **2. Trigger page**.
3. Tap the text field and leave the keyboard visible.
4. Open Recent apps and switch to another app.
5. Return to the reproduction app through Recent apps.
6. Observe whether a blank keyboard-sized area remains at the bottom.
7. Press Back and check whether the blank area remains on **1. Observer page**.

## Expected result

When the IME is no longer visible, Android and Flutter both report a zero IME
inset, and both routes use the full available height.

## Actual result

<!-- Fill after reproducing with the minimal project. Include all four values. -->

- Android `WindowInsets.isVisible(Type.ime())`:
- Android `WindowInsets.getInsets(Type.ime()).bottom`:
- Flutter `FlutterView.viewInsets.bottom`:
- Flutter `MediaQuery.viewInsets.bottom`:
- Does `requestApplyInsets()` clear the blank area?:

## Reproducibility

<!-- Fill the matrix before filing. -->

| Device | Android | Keyboard/version | Flutter | Result |
| --- | --- | --- | --- | --- |
| Pixel 8 Pro | 17 (API 37), `CP2A.260805.005` | Gboard | 3.47.9 | |
| Pixel 8 Pro | 17 (API 37), `CP2A.260805.005` | Gboard | 3.50.0 | Reproduced in debug and profile modes |
| Pixel 9 | 17 (API 37), `CP3A.261005.005` | Gboard `18.5.10.993608717-release-arm64-v8a` | 3.50.0 | Not reproduced |
| Pixel 10 Pro XL | 16 (API 36), `CP1A.260505.005` | Gboard `18.5.6.993608717-release-arm64-v8a` | 3.50.0 | Not reproduced |

## Logs and media

- Attach the copied in-app event log.
- Attach filtered `KeyboardInsetsRepro`, `ImeTracker`, `InsetsController`, and
  `InputMethodManager` logcat output.
- Attach a screen recording showing the Recent-apps transition and the blank
  area persisting after route pop.
- Attach `flutter doctor -v` for each tested Flutter version.
