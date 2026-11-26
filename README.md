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

- **Onboarding**: 33 pages driven by one list in `OnboardingView.swift`. Pages
  cross-fade with a slight rise; there is no swipe. Every page change, choice
  and button fires a haptic.
- **Tabs**: a native tab bar with Words, Topics, Practice, Stats and Profile.
  Topics, Practice, Stats and Profile use native navigation bars with large
  Alegreya titles; Topics has native search. Alegreya (SIL Open Font License) is
  bundled in `Flaub/Fonts` and registered at launch.
- **Words**: one word full screen. A vertical drag moves to the next or previous
  word with a soft cross-fade. Tap the pronunciation to hear it.
- **Practice**: a small quiz over the sample words.
- **Profile**: reminders (asks for notification permission), voice, and the app
  icon picker (six characters, eight backgrounds).

## The word catalogue

The app reads `Flaub/words.json`, which is built from the drafts in
`content/drafts` by a script that checks every entry and adds pronunciation.

```bash
pip install cmudict wordfreq
```

```bash
python3 content/build_catalog.py content/pilot_words.json Flaub/words.json content/drafts/*.json
```

`content/pilot_words.json` keeps every field and the result of the checks, for
review. The table definitions for moving the catalogue to Supabase later are in
`supabase/migrations`; nothing has been applied to a project yet.

## Not done yet

- Topics and stats are sample data in `Models.swift`. Words are real but not
  yet linked to topics, and their etymologies have not been checked against a
  source.
- The paywall shows `[PRICE]`; there is no StoreKit purchase.
- The icon picker saves the choice but does not change the real Home Screen
  icon. That needs each combination shipped as an alternate icon.
- Notifications ask for permission but schedule nothing.
- No widget target, no themes beyond the default.
- Body text uses the system font (San Francisco), not Inter as in the mock-ups.
