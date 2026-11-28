"""Find quotations from public-domain literature for the catalogue words.

Usage:
    python3 content/build_quotes.py fetch
    python3 content/build_quotes.py candidates content/quote_candidates.json
    python3 content/build_quotes.py --lang fr fetch
    python3 content/build_quotes.py --lang fr candidates content/fr/quote_candidates.json

"fetch" downloads the books listed in BOOKS from Project Gutenberg into
content/.cache (not committed). When gutenberg.org does not answer, the same
files are taken from GITenberg, a copy of the collection kept on GitHub. "candidates" reads the drafts and writes up to
five candidate sentences per word, best first. Choosing the one to publish is a
review step: the chosen quotations live in content/quotes.json, which
build_catalog.py merges into the catalogue.

Everything on Project Gutenberg is in the public domain in the United States.
Other countries have other rules, so check before shipping there. Modern
translations are deliberately left out of BOOKS.
"""

import glob
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(__file__)
# English is the default. "--lang fr" switches the books, the cache folder
# (content/.cache/fr) and the drafts (content/fr/drafts).
LANG = "en"
CACHE = os.path.join(HERE, ".cache")
DRAFTS = os.path.join(HERE, "drafts", "*.json")

# Project Gutenberg ebook numbers. Title and author are read from each file.
BOOKS = [
    1342, 158, 161, 105, 98, 1400, 766, 730, 174, 84, 1260, 768, 145, 2701, 76, 74, 345, 11,
    1661, 2554, 28054, 2413, 1399, 2600, 215, 910, 64317, 25344, 1184, 135, 2852, 219, 35, 36,
    43, 120, 205, 144, 5670, 4517, 541, 2814, 4217, 160, 113, 514, 209, 432, 2891, 2641, 1952,
]

# Where the book itself begins and ends. Older files have no "*** START OF"
# line: their licence closes with "*END*THE SMALL PRINT!" instead.
BODY_START = re.compile(r"\*\*\* ?START OF[^\n]*?\*\*\*|^\*END[* ]THE SMALL PRINT[^\n]*$", re.M)
BODY_END = re.compile(r"\*\*\* ?END OF|^End of (The |this )?Project Gutenberg", re.M | re.I)

# The mirrored files are older editions: tidy the names they give.
AUTHORS = {
    "A. Conan Doyle": "Arthur Conan Doyle", "Alexandre Dumas, père": "Alexandre Dumas",
    "Charlotte Bronte": "Charlotte Brontë", "Emily Bronte": "Emily Brontë",
    "Fyodor Dostoyevsky": "Fyodor Dostoevsky", "Mark Twain (Samuel Clemens)": "Mark Twain",
    "Mary Wollstonecraft (Godwin) Shelley": "Mary Shelley",
}
TITLES = {
    "A Room With A View": "A Room with a View", "Howard's End": "Howards End",
    "Walden, and On The Duty Of Civil Disobedience": "Walden", "Moby Dick; or The Whale": "Moby-Dick",
    "Moby Dick; Or, The Whale": "Moby-Dick", "Adventures of Huckleberry Finn, Complete": "Adventures of Huckleberry Finn",
    "The Adventures of Tom Sawyer, Complete": "The Adventures of Tom Sawyer",
    "The Strange Case Of Dr. Jekyll And Mr. Hyde": "The Strange Case of Dr. Jekyll and Mr. Hyde",
    "The Awakening and Selected Short Stories": "The Awakening",
}


AUTHORS.update({
    "Honore de Balzac": "Honoré de Balzac", "Emile Zola": "Émile Zola",
    "Alexandre Dumas, Fils": "Alexandre Dumas fils",
    "Marie-Madeleine Pioche de La Vergne, comtesse de La Fayette": "Madame de La Fayette",
})
TITLES.update({
    "Eugenie Grandet": "Eugénie Grandet", "Le Horla and Others": "Le Horla",
    "La dame aux camelias": "La Dame aux camélias", "Du Côté de Chez Swann": "Du côté de chez Swann",
    "Voyage au Centre de la Terre": "Voyage au centre de la Terre",
    "20000 Lieues sous les mers (complète)": "Vingt mille lieues sous les mers",
    "La Bete Humaine": "La Bête humaine", "Therese Raquin": "Thérèse Raquin",
    "Le Tour du Monde en 80 Jours": "Le Tour du monde en quatre-vingts jours",
    "Les misérables": "Les Misérables", "Le comte de Monte-Cristo": "Le Comte de Monte-Cristo",
    "Les trois mousquetaires": "Les Trois Mousquetaires", "Au bonheur des dames": "Au Bonheur des Dames",
    "Le rêve": "Le Rêve", "La curée": "La Curée", "La princesse de Clèves": "La Princesse de Clèves",
    "L'île mystérieuse": "L’Île mystérieuse", "L'homme qui rit": "L’Homme qui rit",
    "Quatrevingt-Treize": "Quatrevingt-treize", "Le Rouge et le noir": "Le Rouge et le Noir",
    "Les Fleurs du Mal": "Les Fleurs du mal",
})


def typeset(sentence):
    """Curly quotes and real dashes, for the files that are plain ASCII."""
    sentence = re.sub(r"\s*--\s*", "—", sentence)
    sentence = re.sub(r"(?<=\w)'(?=\w)", "’", sentence)
    if LANG not in ("en", "fr"):
        return sentence.replace("'", "’")
    if LANG == "fr":
        # Older files write "coeur" and "oeil" without the ligature.
        for plain, joined in (("oeu", "œu"), ("Oeu", "Œu"), ("oeil", "œil"), ("Oeil", "Œil")):
            sentence = sentence.replace(plain, joined)
        return sentence.replace("'", "’")
    sentence = re.sub(r'"(?=\w)', "“", sentence).replace('"', "”")
    sentence = re.sub(r"(?<!\w)'(?=\w)", "‘", sentence).replace("'", "’")
    return sentence


# French classics, in French. Files in another language are skipped by fetch.
BOOKS_FR = [
    796, 798, 800, 2419, 2650, 4650, 4791, 5097, 5154, 5250, 5423, 5711, 6099, 6470, 8600,
    9645, 10746, 10775, 11049, 11131, 11450, 11770, 12065, 13861, 13951, 14155, 14287, 14288,
    16852, 17457, 17489, 17493, 17494, 17518, 17519, 17533, 17553, 17983, 17989, 17990, 17991,
    17992, 18797, 19657, 7461, 8560, 2708,
]
LANGUAGE_NAMES = {
    "en": "English", "fr": "French", "es": "Spanish", "de": "German", "it": "Italian", "ar": "Arabic",
    "hr": "Croatian", "cs": "Czech", "da": "Danish", "nl": "Dutch", "fi": "Finnish", "el": "Greek",
    "he": "Hebrew", "hu": "Hungarian", "ja": "Japanese", "nb": "Norwegian", "pl": "Polish",
    "pt-BR": "Portuguese", "pt-PT": "Portuguese", "ro": "Romanian", "ru": "Russian", "sk": "Slovak",
    "sl": "Slovenian", "sv": "Swedish", "tr": "Turkish",
}
# The other languages describe themselves in content/<code>/books.json:
# {"books": [ebook numbers], "abbreviations": [...], "openers": [...],
#  "authors": {name in the file: name to show}, "titles": {...}}.
CONFIG = {}
ABBREVIATIONS_FR = ["M", "MM", "Mme", "Mlle", "Dr", "St", "Ste", "Mgr"]
OPENERS = {
    "en": {"He", "She", "It", "They", "This", "That", "But", "And", "Then", "So"},
    "fr": {"Il", "Elle", "Ils", "Elles", "Ce", "Cela", "Mais", "Et", "Puis", "Alors", "On", "Car", "Or"},
}

ABBREVIATIONS = ["Mr", "Mrs", "Ms", "Dr", "St", "Mme", "Mlle", "M", "Esq", "Col", "Capt", "Rev", "Prof"]


MIRROR = "https://raw.githubusercontent.com/GITenberg"
MIRROR_INDEX = "https://raw.githubusercontent.com/gitenberg-dev/gitberg/master/gitenberg/data/GITenberg_repo_list.tsv"


def download(url):
    return urllib.request.urlopen(url, timeout=90).read()


def mirror_names():
    """Ebook number to GITenberg repository name, from the mirror's own index."""
    path = os.path.join(HERE, ".cache", "gitenberg_index.tsv")
    if not os.path.exists(path):
        with open(path, "wb") as handle:
            handle.write(download(MIRROR_INDEX))
    names = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        number, _, name = line.strip().partition("\t")
        names[number] = name
    return names


def from_mirror(number, names):
    """The book as UTF-8 bytes from GITenberg, a copy of Gutenberg kept on GitHub."""
    name = names.get(str(number))
    if not name:
        raise LookupError("not in the mirror's index")
    error = None
    # "-0" is UTF-8, "-8" is Latin-1 and the bare number is plain ASCII.
    for suffix, encoding in (("-0", "utf-8"), ("-8", "latin-1"), ("", "ascii")):
        try:
            data = download(f"{MIRROR}/{name}/master/{number}{suffix}.txt")
        except Exception as caught:
            error = caught
            continue
        return data.decode(encoding, errors="replace").encode("utf-8")
    raise error


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    names = None
    site_down = False
    for number in (BOOKS_FR if LANG == "fr" else CONFIG.get("books", BOOKS)):
        path = os.path.join(CACHE, f"{number}.txt")
        if os.path.exists(path) and os.path.getsize(path) > 20000:
            continue
        data, origin = None, "gutenberg.org"
        if not site_down:
            try:
                data = download(f"https://www.gutenberg.org/cache/epub/{number}/pg{number}.txt")
            except Exception as error:  # the site can be down for long stretches
                print(f"gutenberg.org is not answering ({error}); using the GitHub mirror")
                site_down = True
        if data is None:
            origin = "mirror"
            try:
                names = names or mirror_names()
                data = from_mirror(number, names)
            except Exception as error:
                print(f"{number}: {error}")
                continue
        if not BODY_START.search(data.decode("utf-8", errors="replace")):
            print(f"{number}: not a book file, skipped")
            continue
        language = re.search(rb"^Language: *(\w+)", data, re.M)
        wanted = CONFIG.get("language_name") or LANGUAGE_NAMES[LANG]
        if not language or language.group(1).decode() != wanted:
            print(f"{number}: not in {wanted}, skipped")
            continue
        with open(path, "wb") as handle:
            handle.write(data)
        print(f"{number}: {len(data)} bytes ({origin})")


def read_book(path):
    """Return (author, title, sentences) for one downloaded book."""
    text = open(path, encoding="utf-8-sig", errors="replace").read().replace("\r\n", "\n")
    # One mirrored file has its title glued to the end of the line before it.
    title = re.search(r"^Title: (.+)$", text, re.M) or re.search(r"Title: (.+)$", text[:3000], re.M)
    author = re.search(r"^Author: (.+)$", text, re.M)
    start = BODY_START.search(text)
    end = BODY_END.search(text)
    body = text[start.end() if start else 0: end.start() if end else len(text)]
    sentences = []
    for paragraph in re.split(r"\n\s*\n", body):
        paragraph = " ".join(paragraph.split()).replace("_", "")
        if len(paragraph) < 40 or paragraph.isupper():
            continue
        for short in (ABBREVIATIONS_FR if LANG == "fr" else CONFIG.get("abbreviations", ABBREVIATIONS)):
            paragraph = re.sub(rf"\b{short}\.", f"{short}<dot>", paragraph)
        if LANG in ("en", "fr"):
            pieces = re.split(r"(?<=[.!?])\s+(?=[“\"‘'«„»¿¡]?\s?[A-ZÀ-Ý])", paragraph)
        else:
            # Other alphabets: split after the mark, and let score() judge the opening.
            pieces = re.split(r"(?<=[.!?…؟])\s+(?=\S)", paragraph)
        for sentence in pieces:
            sentences.append(sentence.replace("<dot>", ".").strip())
    author = author.group(1).strip() if author else ""
    title = title.group(1).strip() if title else ""
    if LANG == "fr":
        title = re.sub(r",? *-* *Tome .*$", "", title, flags=re.I)
    return (AUTHORS.get(author, author), TITLES.get(title, title), sentences)


def forms(lemma):
    """The word and its regular inflections, as one regular expression."""
    options = {lemma, lemma + "s", lemma + "es", lemma + "ed", lemma + "ing"}
    if lemma.endswith("e"):
        options |= {lemma + "d", lemma[:-1] + "ing"}
    if lemma.endswith("y"):
        options |= {lemma[:-1] + "ies", lemma[:-1] + "ied"}
    return re.compile(r"\b(" + "|".join(sorted(options, key=len, reverse=True)) + r")\b", re.I)


def forms_fr(lemma, part):
    """A French word and its usual inflections, as one regular expression."""
    if part == "v.":
        stem = lemma[:-2]
        stems = {stem}
        if stem.endswith("c"):
            stems.add(stem[:-1] + "ç")          # exauça
        if stem.endswith("g"):
            stems.add(stem + "e")               # songeait
        if stem.endswith(("el", "et")):
            stems.add(stem + stem[-1])          # grommelle
        if stem.endswith("oy"):
            stems.add(stem[:-2] + "oi")         # atermoie
        if "é" in stem[-3:]:
            cut = stem.rindex("é")
            stems.add(stem[:cut] + "è" + stem[cut + 1:])  # vénère
        if lemma.endswith("er"):
            endings = ("e es ent é ée és ées er a ai as ait ais aient ant èrent ât era erai erait "
                       "eraient ons ez").split()
        else:
            endings = ("ir is it i ie ies irent issait issaient issant issent isse ira irait ît "
                       "e es ent ait aient ant").split()
        options = {s + e for s in stems for e in endings}
    else:
        options = {lemma, lemma + "s"}
        if lemma.endswith("eux"):
            options |= {lemma[:-1] + "se", lemma[:-1] + "ses"}
        elif lemma.endswith("if"):
            options |= {lemma[:-1] + "ve", lemma[:-1] + "ves"}
        elif lemma.endswith("et"):
            options |= {lemma + "te", lemma + "tes"}
        elif not lemma.endswith("e"):
            options |= {lemma + "e", lemma + "es"}
    return re.compile(r"\b(" + "|".join(sorted(options, key=len, reverse=True)) + r")\b", re.I)


def forms_generic(lemma):
    """Any word that starts like the lemma: loose, since a person reviews the result."""
    stem = lemma[:-2] if len(lemma) > 5 else lemma[:-1] if len(lemma) > 4 else lemma
    return re.compile(r"\b(" + re.escape(stem) + r"\w{0,6})\b", re.I)


def score(sentence, match):
    """Higher is better: a self-contained sentence of a comfortable length."""
    words = sentence.split()
    count = len(words)
    if not 8 <= count <= 30:
        return None
    if sentence.count("“") != sentence.count("”") or sentence.count('"') % 2:
        return None
    if sentence.count("«") != sentence.count("»"):
        return None
    if LANG not in ("en", "fr") and not sentence[0].islower():
        pass  # a capital, an opening mark, or a script without capitals
    elif not sentence[0].isupper() and sentence[0] not in "“\"¿¡«„»":
        return None
    points = 10 - abs(count - 16) * 0.5
    if match.start() == 0:
        points -= 2
    if words[0].strip("“\"«„»¿¡") in OPENERS.get(LANG, set(CONFIG.get("openers", []))):
        points -= 2
    names = sum(1 for word in words[1:] if word[:1].isupper() and word not in {"I", "I’m", "I'm"})
    points -= names * 1.5
    points -= sentence.count(";") + sentence.count("—") + sentence.count("--")
    if "“" in sentence or '"' in sentence or "«" in sentence:
        points -= 1.5
    return points


def candidates(out_path):
    patterns = {}
    for path in sorted(glob.glob(DRAFTS)):
        for entry in json.load(open(path, encoding="utf-8")):
            lemma = entry["lemma"]
            if lemma not in patterns:
                if LANG == "en":
                    patterns[lemma] = forms(lemma)
                elif LANG == "fr":
                    patterns[lemma] = forms_fr(lemma, entry["part_of_speech"])
                else:
                    patterns[lemma] = forms_generic(lemma)
    found = {lemma: [] for lemma in patterns}

    for path in sorted(glob.glob(os.path.join(CACHE, "[0-9]*.txt"))):
        author, title, sentences = read_book(path)
        if not author or not title:
            continue
        source = f"{author}, {title}"
        for sentence in sentences:
            lowered = sentence.lower()
            for lemma, pattern in patterns.items():
                if lemma[:4 if LANG == "en" else 3].lower() not in lowered:
                    continue
                match = pattern.search(sentence)
                if not match:
                    continue
                points = score(sentence, match)
                if points is not None:
                    found[lemma].append((points, sentence, source))

    result = {}
    for lemma, rows in found.items():
        rows.sort(key=lambda row: -row[0])
        picked, per_source = [], {}
        for points, sentence, source in rows:
            if per_source.get(source, 0) >= 2 or any(sentence == p["quote"] for p in picked):
                continue
            per_source[source] = per_source.get(source, 0) + 1
            picked.append({"quote": typeset(sentence), "source": source})
            if len(picked) == 5:
                break
        result[lemma] = picked

    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(result, handle, ensure_ascii=False, indent=2)
    covered = sum(1 for rows in result.values() if rows)
    print(f"{covered} of {len(result)} words have at least one candidate")


if __name__ == "__main__":
    if "--lang" in sys.argv:
        position = sys.argv.index("--lang")
        LANG = sys.argv[position + 1]
        del sys.argv[position:position + 2]
        if LANG != "en":
            CACHE = os.path.join(HERE, ".cache", LANG)
            DRAFTS = os.path.join(HERE, LANG, "drafts", "*.json")
            config_path = os.path.join(HERE, LANG, "books.json")
            if os.path.exists(config_path):
                CONFIG = json.load(open(config_path, encoding="utf-8"))
                AUTHORS.update(CONFIG.get("authors", {}))
                TITLES.update(CONFIG.get("titles", {}))
    if len(sys.argv) >= 2 and sys.argv[1] == "fetch":
        fetch()
    elif len(sys.argv) >= 3 and sys.argv[1] == "candidates":
        candidates(sys.argv[2])
    else:
        print(__doc__)
