"""Builds data.js for shots.html: for each language the app teaches, the
interface texts, the words shown on each screen and the headlines.

Interface texts come from Bovary/strings_<code>.json, words from
Bovary/words_<code>.json, the widget's name from BovaryWidget/texts.json and
the headlines from headlines.json.

    python3 marketing/screenshots/build_data.py
"""
import json
import unicodedata
from pathlib import Path

HERE = Path(__file__).parent
APP = HERE.parent.parent / "Bovary"

# The app's language codes and their App Store Connect locales.
LOCALES = {
    "en": "en-US", "fr": "fr-FR", "es": "es-ES", "it": "it", "de": "de-DE",
    "pt-BR": "pt-BR", "pt-PT": "pt-PT", "nl": "nl-NL", "sv": "sv", "da": "da",
    "nb": "no", "fi": "fi", "pl": "pl", "cs": "cs", "sk": "sk", "sl": "sl-SI",
    "hr": "hr", "hu": "hu", "ro": "ro", "el": "el", "ru": "ru", "tr": "tr",
    "ar": "ar-SA", "he": "he", "ja": "ja",
}
RTL = {"ar", "he"}

UI = ["Words", "Topics", "Practice", "Stats", "Profile", "Example", "In literature",
      "Synonyms", "Origin", "Sprint", "Which word means this?", "Your streak", "Read",
      "Favorited", "Saved", "Take a test", "to see your current level", "Explore topics",
      "Search", "Emotions", "Character", "Persuasion", "Debate", "Business", "Literature",
      "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

# Words chosen by hand; every other language takes the first words that fit.
PICKS = {
    "en": {"feed": "ephemeral", "detail": "melancholy", "game": "tenacious",
           "others": ["wistful", "candid", "serene"], "widgets": ["solace", "reverie"]},
    "fr": {"feed": "éphémère", "detail": "épier", "game": "intrépide",
           "others": ["hautain", "frivole", "austère"], "widgets": ["aube", "lueur"]},
}

# The word on the first screen, where a pleasant one was easy to name.
PREFER = {
    "es": "sosiego", "it": "garbato", "de": "anmutig", "pt-BR": "aconchego", "pt-PT": "sereno",
    "nl": "behoedzaam", "sv": "rofylld", "da": "yndig", "nb": "varsom", "fi": "lempeä",
    "pl": "błogi", "cs": "něžný", "sk": "nežný", "sl": "spokojen", "hr": "blag", "hu": "szelíd",
    "ro": "duios", "el": "θαρραλέος", "ru": "безмятежный", "tr": "zarif", "ar": "نبيل",
    "he": "נדיב", "ja": "朗らか",
}

# A language shows the literature screen when at least this share of its words has a quotation.
QUOTE_SHARE = 0.2


def width(text):
    """Rough width in Latin letters: full-width characters count double."""
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in text)


def first(words, test, taken, what):
    for word in words:
        if word["lemma"] not in taken and test(word):
            taken.add(word["lemma"])
            return word
    raise SystemExit(f"no word fits: {what}")


def build(code):
    words = json.loads((APP / ("words.json" if code == "en" else f"words_{code}.json")).read_text())
    strings = {} if code == "en" else json.loads((APP / f"strings_{code}.json").read_text())
    by_lemma = {w["lemma"]: w for w in words}
    picks = PICKS.get(code, {})
    taken = set(picks.get("others", [])) | set(picks.get("widgets", []))
    taken |= {picks[k] for k in ("feed", "detail", "game") if k in picks}
    quoted = sum(1 for w in words if w.get("quote"))
    literature = quoted >= QUOTE_SHARE * len(words)

    def short(word, lemma, definition):
        return " " not in word["lemma"] and width(word["lemma"]) <= lemma and width(word["definition"]) <= definition

    # The first word a visitor sees: the preferred one, else a gentle one from nature.
    gentle = [w for w in words if "nature" in w.get("topics", [])] + words
    if "feed" in picks:
        feed = by_lemma[picks["feed"]]
    elif PREFER.get(code) in by_lemma:
        feed = by_lemma[PREFER[code]]
        taken.add(feed["lemma"])
    else:
        feed = first(gentle, lambda w: short(w, 10, 36) and w.get("ipa"), taken, "feed")

    def detailed(w):
        if not (short(w, 12, 42) and width(w["example"]) <= 78 and len(w.get("synonyms", [])) >= 2):
            return False
        if literature:
            return 60 <= width(w.get("quote", "")) <= 125 and w.get("quote_source")
        return 40 <= width(w.get("origin", "")) <= 150

    detail = by_lemma[picks["detail"]] if picks else first(words, detailed, taken, "detail")
    game = by_lemma[picks["game"]] if picks else first(words, lambda w: short(w, 12, 46), taken, "game")
    if picks:
        others = picks["others"]
    else:
        same = [w for w in words if w["part_of_speech"] == game["part_of_speech"]]
        others = [first(same, lambda w: short(w, 12, 999), taken, "game option")["lemma"] for _ in range(3)]
    if picks:
        widgets = [by_lemma[l] for l in picks["widgets"]]
    else:
        widgets = [first(gentle, lambda w: short(w, 9, 54), taken, "medium widget"),
                   first(gentle, lambda w: short(w, 8, 30), taken, "small widget")]

    # The field of words behind the speaker: three highlighted, the rest quiet.
    pool = [w["lemma"] for w in words if " " not in w["lemma"] and 3 <= width(w["lemma"]) <= 10]
    lit = [l for l in pool if 5 <= width(l) <= 9][:2]
    lit += [l for l in pool if 4 <= width(l) <= 6 and l not in lit][:1]
    quiet = [l for l in pool if l not in lit]
    rows, at = [], 0
    for index in range(13):
        row = quiet[at % len(quiet):][:4]
        at += 4
        if index in (0, 1, 3):
            row.insert(1 if index < 3 else 0, "*" + lit[min(index, 2)])
        rows.append(row)

    widget_name = json.loads((APP.parent / "BovaryWidget" / "texts.json").read_text()).get(code, {}).get("name", "Word of the day")
    keep = ("lemma", "ipa", "part_of_speech", "definition", "example", "quote", "quote_source", "origin")
    return {
        "locale": LOCALES[code],
        "rtl": code in RTL,
        "ui": {key: strings.get(key, key) for key in UI},
        "widgetHeading": widget_name.upper(),
        "literature": literature,
        "feed": {k: feed.get(k, "") for k in keep},
        "detail": {**{k: detail.get(k, "") for k in keep}, "synonyms": detail["synonyms"][:3]},
        "game": {"definition": game["definition"], "options": [others[0], game["lemma"], others[1], others[2]]},
        "widgets": [{k: w.get(k, "") for k in keep} for w in widgets],
        "field": rows,
    }


def wrapped(headline):
    """A two-line headline with one very long line becomes three lines."""
    lines = headline.split("|")
    longest = max(lines, key=width)
    if len(lines) != 2 or width(longest) <= 19 or " " not in longest.strip("*"):
        return headline
    emphasised = longest.startswith("*")
    text = longest.strip("*")
    spaces = [i for i, c in enumerate(text) if c == " "]
    cut = min(spaces, key=lambda i: abs(i - len(text) / 2))
    parts = [text[:cut], text[cut + 1:]]
    if emphasised:
        parts = [f"*{p}*" for p in parts]
    at = lines.index(longest)
    return "|".join(lines[:at] + parts + lines[at + 1:])


def main():
    headlines = json.loads((HERE / "headlines.json").read_text())
    data = {}
    for code in LOCALES:
        entry = build(code)
        heads = headlines[code]
        order = ["word", "vocabulary", "literature" if entry["literature"] else "detail", "games", "widget", "streak", "topics"]
        entry["headlines"] = [wrapped(heads[key]) for key in order]
        data[code] = entry
    (HERE / "data.js").write_text("// Written by build_data.py. Do not edit by hand.\nconst DATA = "
                                   + json.dumps(data, ensure_ascii=False, indent=1) + ";\n")
    for code, entry in data.items():
        print(code, entry["locale"], "literature" if entry["literature"] else "detail",
              entry["feed"]["lemma"], "|", entry["detail"]["lemma"], "|", entry["game"]["options"])


if __name__ == "__main__":
    main()
