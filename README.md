# Keyboard Insets Reproduction

Minimal Flutter/Android reproduction for an IME inset that can remain after the
app is backgrounded and resumed. The project intentionally contains no focus or
keyboard lifecycle workaround. Its Dart and Android build constraints use the
common range supported by Flutter 3.47.9 and 3.50.0.

The trigger page does not rebuild in response to lifecycle, focus, metrics, or
native diagnostic events. Diagnostics are recorded silently and displayed only
after returning to the observer page. **Request Android insets** is a manual
diagnostic action and is the only code path that calls `requestApplyInsets()`.

## Run

From this directory:

```sh
fvm flutter run --print-dtd
```

To compare another installed Flutter SDK without changing the Moody SDK pin:

```sh
fvm spawn 3.47.9 run --print-dtd
fvm spawn 3.50.0 run --print-dtd
```

Record `fvm spawn <version> --version` with each result.

## Reproduction

1. Open **2. Trigger page**.
2. Tap the text field and keep the keyboard visible.
3. Open Recent apps and switch to another app.
4. Use Recent apps to return to the reproduction app.
5. If a blank keyboard-sized area appears, press Back to return to the observer
   page and check whether the orange bottom marker remains displaced.
6. Copy the event log before changing focus or restarting the app.
7. Press **Request Android insets**. Record whether this removes the blank area.

Also test the Home button and the keyboard settings button as separate paths.

## Reading the Result

- Native `imeVisible=false`, native `imeBottom=0`, but Flutter
  `viewInsets.bottom>0`: the Flutter engine has retained or redispatched stale
  window metrics.
- Native `imeVisible=true` or native `imeBottom>0` while no keyboard is drawn:
  Android or the IME is retaining a phantom IME inset.
- Native and Flutter inset values are all zero while the blank area remains:
  the problem is in the Flutter framework/widget layout rather than window
  metrics.
- `FlutterView.viewInsets` is correct but `MediaQuery.viewInsets` is stale: the
  framework did not propagate the updated view metrics to the widget tree.
- If **Request Android insets** fixes the state, the resume path likely needs a
  new native insets dispatch.

## Logcat

The native side logs snapshots with tag `KeyboardInsetsRepro`:

```sh
adb logcat -v time KeyboardInsetsRepro:D flutter:I ImeTracker:I InsetsController:D InputMethodManager:I '*:S'
```

When filing an upstream issue, attach:

- Flutter version and engine revision.
- Device model, Android version, and keyboard version.
- Copied in-app event log and the filtered logcat output.
- A screen recording showing the Recent-apps reproduction.
- Whether **Request Android insets** clears the blank area.
