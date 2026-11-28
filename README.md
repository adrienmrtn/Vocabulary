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
  the word feed, settings, and the app icon picker: seven characters and eight
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
the catalogue is loaded there. At launch the app downloads the published catalogue
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

### Other languages

Each language gets its own words, chosen for that language, not a translation
of the English list. Besides English the app teaches twenty-four languages:
French, Spanish, Italian, German, Portuguese (Brazil and Portugal, as two
languages), Dutch, Swedish, Danish, Norwegian, Finnish, Polish, Czech, Slovak,
Slovenian, Croatian, Hungarian, Romanian, Greek, Russian, Turkish, Arabic,
Hebrew and Japanese. Each has 160 to 200 words in `content/<code>/drafts`,
written in that language, and whatever quotations its classics on the mirror
allowed (`content/<code>/quotes.json`): from more than a hundred for French,
Spanish, Swedish, Greek, Dutch or Finnish to none for Arabic, Croatian, Slovak
and Turkish, which have no book there.

The same scripts build a language with `--lang <code>`:

```bash
python3 content/build_quotes.py --lang fr fetch
```

```bash
python3 content/build_quotes.py --lang fr candidates content/fr/quote_candidates.json
```

```bash
python3 content/build_catalog.py --lang fr content/fr/pilot_words.json Bovary/words_fr.json content/fr/drafts/*.json
```

```bash
python3 content/push_catalog.py --lang fr
```

A language describes itself in `content/<code>/books.json`: its parts of
speech (`parts`), its showcase word (`featured`) and the Gutenberg numbers of
its books. The drafts carry the pronunciation themselves (key `ipa`). The
build writes `Bovary/words_<code>.json` and `BovaryWidget/words_<code>.json`,
and keeps `Bovary/featured.json` and `BovaryWidget/texts.json` up to date.

In the app, the second onboarding page asks which language to enrich, and
Settings can change it later. The choice sets the catalogue, the voice and the
interface together; Arabic and Hebrew are laid out from right to left. The
code is written in English; `tr("...")` looks each text up in
`Bovary/strings_<code>.json` (English text to translation), and a text with no
translation is shown in English. A new language needs a case in `AppLanguage`
(`Language.swift`), a `strings_<code>.json` and a `words_<code>.json`. The
widget cannot read the app's choice, so it follows the device language.

In Supabase a word is identified by its language and its lemma together
(`words.language`), so the same spelling can be a word in several languages.
The app reads the view `catalog_localized` filtered on its language; the older
view `catalog` stays English only for builds released before. The member's
favorites and history are plain spellings, shown in whichever catalogue has
them (`supabase/migrations`).

Most etymologies and pronunciations outside English were written from
knowledge and not checked against a dictionary, and the interface texts have
not been read by native speakers. Languages with several plural forms (the
Slavic ones, Romanian, Arabic) use a single form per sentence, which reads
wrongly for some numbers.

## Not done yet

- **The language support has not been built or run.** It was written without
  Xcode at hand: build it and walk through the onboarding in another language
  before release.

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

## App Store screenshots

Seven screenshots for each of the twenty-five languages, drawn in HTML from
the app's own screens. `marketing/screenshots/build_data.py` gathers, for each
language, the interface texts, the words shown on each screen and the headlines
(`headlines.json`); `shots.html` draws them; `render.js` saves them at
1290 × 2796 in `fastlane/screenshots`, one folder per App Store locale. That
folder is not kept in the repository.

```bash
python3 marketing/screenshots/build_data.py
```

```bash
node marketing/screenshots/render.js
```

Rendering needs Playwright and the network, for the fonts. The phone screens
are mock-ups, not simulator captures. Languages whose catalogue has few
quotations show a word's origin on the third screenshot instead of a quotation.

The "App Store screenshots" workflow, started by hand from the Actions tab,
draws them, keeps them as an artifact and sends them to App Store Connect with
fastlane. It replaces the screenshots of the version being prepared and submits
nothing for review; untick "upload" to only draw them. Uploading needs three
repository secrets from an App Store Connect API key with the App Manager
role: `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8_BASE64` (the `.p8` file,
base64-encoded).
