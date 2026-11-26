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

- **Onboarding**: 35 pages driven by one list in `OnboardingView.swift`. Pages
  cross-fade with a slight rise; there is no swipe. Every page change, choice
  and button fires a haptic.
- **Tabs**: a native tab bar with Words, Topics, Practice, Stats and Profile.
  Topics, Practice, Stats and Profile use native navigation bars with large
  Alegreya titles; Topics has native search. Alegreya (SIL Open Font License) is
  bundled in `Flaub/Fonts` and registered at launch.
- **Words**: one word full screen. A vertical drag moves to the next or previous
  word with a soft cross-fade. Tap the pronunciation to hear it.
- **Practice**: mini-games built from the catalogue. Five kinds of question
  (meaning, fill the gap, synonym, true or false, listening) and four modes:
  Sprint (ten questions against the clock), Rush (60 seconds), Perfection
  (until the first mistake) and Game shuffle. Missed words come back first.
- **Profile**: reminders (asks for notification permission), voice, themes for
  the word feed, settings, and the app icon picker: six characters and eight
  backgrounds, each pair a real alternate Home Screen icon.
- **Library**: Favorites, Collections, Your own words and History, and a word
  list with practice for each of the ten topics.

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
review. Topics per word are in `content/topics.json`.

### Supabase

The schema in `supabase/migrations` is applied to the "Vocabulary" project and
the 250 words are loaded. At launch the app downloads the published catalogue
and uses it from the next launch on; the bundled file is the offline fallback.
To publish a new build of the catalogue (needs the project's secret key, which
must stay out of the repository):

```bash
SUPABASE_URL=https://ybufanypeamzxnsqsvzf.supabase.co SUPABASE_SECRET_KEY=... python3 content/push_catalog.py
```

Member data (favorites, collections, own words, history, review boxes, active
days, onboarding answers) lives on the device first and is backed up through
two database functions, `sync_user_state` and `get_user_state`, under an
anonymous account. **Anonymous sign-ins must be enabled** in the project
(Authentication, Sign In / Providers) for the backup to work; without it the
app simply stays local.

`content/fetch_etymology.py` downloads Wiktionary's etymology sections into
`content/.cache`, as the reference for checking the "origin" lines.

### Quotations from literature

`content/build_quotes.py` downloads public-domain classics from Project
Gutenberg and proposes up to five sentences per word. The ones chosen go in
`content/quotes.json` and are merged by the build above; the app shows them in
the word detail sheet. No quotations have been chosen yet.

```bash
python3 content/build_quotes.py fetch
```

```bash
python3 content/build_quotes.py candidates content/quote_candidates.json
```

## Not done yet

- Sign in with Apple and Google: the account is anonymous for now.
- The bundle identifier is still the placeholder `com.example.flaub`.
- The paywall shows `[PRICE]`; there is no StoreKit purchase.
- Notifications ask for permission but schedule nothing.
- No widget target. "Topics you follow" and "Home Screen widgets" in Profile are placeholders.
- Body text uses the system font (San Francisco), not Inter as in the mock-ups.
