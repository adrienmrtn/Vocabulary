# Flaub

A vocabulary app for iOS, written in SwiftUI. One word at a time, a daily habit,
and a cream-and-serif look.

## Run it

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

```bash
open Flaub.xcodeproj
```

Pick an iPhone simulator (iOS 17 or later) and press Run. To install on a device,
set your team under Signing & Capabilities and change the bundle identifier
(`com.example.flaub`) in `project.yml`.

## What is in this first version

- **Onboarding**: 34 pages driven by one list in `OnboardingView.swift`. Pages
  cross-fade with a slight rise; there is no swipe. Every page change, choice
  and button fires a haptic.
- **Tabs**: a native tab bar with Words, Topics, Practice, Stats and Profile.
  Topics, Practice, Stats and Profile use native navigation bars with large
  serif titles; Topics has native search.
- **Words**: one word full screen. A vertical drag moves to the next or previous
  word with a soft cross-fade. Tap the pronunciation to hear it.
- **Practice**: a small quiz over the sample words.
- **Profile**: reminders (asks for notification permission), voice, and the app
  icon picker (six characters, eight backgrounds).

## Not done yet

- Words, topics and stats are sample data in `Models.swift`.
- The paywall shows `[PRICE]`; there is no StoreKit purchase.
- The icon picker saves the choice but does not change the real Home Screen
  icon. That needs each combination shipped as an alternate icon.
- Notifications ask for permission but schedule nothing.
- No widget target, no themes beyond the default.
- Titles use the system serif (New York), not Alegreya.
