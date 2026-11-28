# Bovary

A vocabulary app for iOS, written in SwiftUI. One word at a time, a daily habit,
and a cream-and-serif look.

## Run it

Open `Bovary.xcodeproj` in Xcode 16 or later, pick an iPhone simulator (iOS 17
or later) and press Run. Xcode downloads the Supabase package on first open.
Every file in the `Bovary` folder is part of the app automatically; there is
nothing to add by hand when a file is created.

To install on a device, set your team under Signing & Capabilities. The bundle
identifier is `com.vikstudios.bovary`.

If the project does not open, it can be regenerated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`,
then `xcodegen generate`).

## What is in this first version

- **Onboarding**: 35 pages driven by one list in `OnboardingView.swift`, with a
  progress bar. No question can be skipped: an answer is chosen, then confirmed
  with Continue. Pages cross-fade with a slight rise; there is no swipe, and
  every page change, choice and button fires a haptic. The pages with an
  animation of their own are in `OnboardingPages.swift`: word cards dealt on
  the welcome page, a year of words that fills square by square, an iPhone
  showing the widget then the Lock Screen, a pile of word cards, a timed
  loading page, the profile built from the answers, a gift that opens
  onto the free trial, and the trial reminder written word by word.
- **Tabs**: a native tab bar with Words, Topics, Practice, Stats and Profile.
  Topics, Practice, Stats and Profile use native navigation bars with large
  Alegreya titles; Topics has native search. Alegreya (SIL Open Font License) is
  bundled in `Bovary/Fonts` and registered at launch.
- **Words**: one word per screen in a vertical paging feed. The page follows
  the finger, snaps into place and gives a soft tap on landing. Tap the
  pronunciation to hear it.
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

The app reads `Bovary/words.json`, which is built from the drafts in
`content/drafts` by a script that checks every entry and adds pronunciation.

```bash
pip install cmudict wordfreq
```

```bash
python3 content/build_catalog.py content/pilot_words.json Bovary/words.json content/drafts/*.json
```

`content/pilot_words.json` keeps every field and the result of the checks, for
review. Topics per word are in `content/topics.json`.

### Supabase

The schema in `supabase/migrations` is applied to the "Vocabulary" project and
the 404 words are loaded. At launch the app downloads the published catalogue
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
the word detail sheet. 344 of the 404 words have a quotation; the rest are
too rare or too modern to appear in these books.

When gutenberg.org is down, `fetch` takes the same files from
[GITenberg](https://github.com/GITenberg), a copy of the collection on GitHub.
Those copies are older editions of the files: a few are plain ASCII (straight
quotes, no accents) and some spell an author differently ("A. Conan Doyle"),
so tidy the source line when choosing a quotation.

```bash
python3 content/build_quotes.py fetch
```

```bash
python3 content/build_quotes.py candidates content/quote_candidates.json
```

## Not done yet

- **Nothing is locked**: every topic, game and statistic is free for now. The
  subscription is sold in the onboarding, but the limit it lifts is still to
  be built.

- **The rating page shows placeholder social proof** (a 4.8 rating, a user
  count and four reviews) in debug and TestFlight builds only. Replace it with real figures
  in `SocialProof` (`Motion.swift`) before release; an App Store build shows none.

- Sign in with Apple and Google: the account is anonymous for now.
- Subscriptions are wired to RevenueCat, but no purchase has been tested yet:
  the products still await Apple's review screenshot and the Paid Apps agreement.
- The paywall's Terms and Privacy links lead nowhere yet.
- Notifications ask for permission but schedule nothing.
- No widget target. "Topics you follow" and "Home Screen widgets" in Profile are placeholders.
- Body text uses the system font (San Francisco), not Inter as in the mock-ups.

## Widget

`BovaryWidget/` is a second target, embedded in the app: the word of the day
as a small or medium Home Screen widget and as a Lock Screen widget. It has its
own bundle identifier (`com.vikstudios.bovary.widget`) and its own copy of the
catalogue, `BovaryWidget/words.json`, written by `content/build_catalog.py`. It
shows the first word of the app's daily feed as long as both use the same
catalogue; a catalogue refreshed from Supabase can make them differ until the
next app update.

## Subscriptions

`Subscriptions.swift` talks to RevenueCat; `Paywall.swift` is the offer screen.
What is sold is set in the RevenueCat dashboard, so prices can change without
an app update:

- the paywall sells the yearly package of the **current offering** and explains
  the trial as a timeline; its close button appears after eight seconds;
- closing it shows the offering named `discount`, a single time ever;
- a trial purchase schedules a local notification for the day before it ends;
- every plan unlocks the entitlement `premium`.

RevenueCat's public iOS key is in `Subscriptions.apiKey`. The current offering
sells the yearly plan with a 3-day trial and the monthly plan; `discount` sells
the cheaper yearly plan. Five more products exist in App Store Connect and
RevenueCat, attached to `premium` but in no offering. After adding or updating a package, regenerate
`Package.resolved` with the Swift version Xcode Cloud uses.
