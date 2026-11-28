"""Find quotations from public-domain literature for the catalogue words.

Usage:
    python3 content/build_quotes.py fetch
    python3 content/build_quotes.py candidates content/quote_candidates.json

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

CACHE = os.path.join(os.path.dirname(__file__), ".cache")
DRAFTS = os.path.join(os.path.dirname(__file__), "drafts", "*.json")

# Project Gutenberg ebook numbers. Title and author are read from each file.
BOOKS = [
    1342, 158, 161, 105, 98, 1400, 766, 730, 174, 84, 1260, 768, 145, 2701, 76, 74, 345, 11,
    1661, 2554, 28054, 2413, 1399, 2600, 215, 910, 64317, 25344, 1184, 135, 2852, 219, 35, 36,
    43, 120, 205, 144, 5670, 4517, 541, 2814, 4217, 160, 113, 514, 209, 432, 2891, 2641, 1952,
]

# Where the book itself begins and ends. Older files have no "*** START OF"
# line: their licence closes with "*END*THE SMALL PRINT!" instead.
BODY_START = re.compile(r"\*\*\* ?START OF.*?\*\*\*|^\*END[* ]THE SMALL PRINT.*$", re.M | re.S)
BODY_END = re.compile(r"\*\*\* ?END OF|^End of (The |this )?Project Gutenberg", re.M | re.I)

ABBREVIATIONS = ["Mr", "Mrs", "Ms", "Dr", "St", "Mme", "Mlle", "M", "Esq", "Col", "Capt", "Rev", "Prof"]


MIRROR = "https://raw.githubusercontent.com/GITenberg"
MIRROR_INDEX = "https://raw.githubusercontent.com/gitenberg-dev/gitberg/master/gitenberg/data/GITenberg_repo_list.tsv"


def download(url):
    return urllib.request.urlopen(url, timeout=90).read()


def mirror_names():
    """Ebook number to GITenberg repository name, from the mirror's own index."""
    path = os.path.join(CACHE, "gitenberg_index.tsv")
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
    for number in BOOKS:
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
        with open(path, "wb") as handle:
            handle.write(data)
        print(f"{number}: {len(data)} bytes ({origin})")


def read_book(path):
    """Return (author, title, sentences) for one downloaded book."""
    text = open(path, encoding="utf-8-sig", errors="replace").read().replace("\r\n", "\n")
    # One mirrored file has its title glued to the end of the line before it.
    title = re.search(r"^Title: (.+)$", text, re.M) or re.search(r"\bTitle: (.+)$", text[:3000], re.M)
    author = re.search(r"^Author: (.+)$", text, re.M)
    start = BODY_START.search(text)
    end = BODY_END.search(text)
    body = text[start.end() if start else 0: end.start() if end else len(text)]
    sentences = []
    for paragraph in re.split(r"\n\s*\n", body):
        paragraph = " ".join(paragraph.split()).replace("_", "")
        if len(paragraph) < 40 or paragraph.isupper():
            continue
        for short in ABBREVIATIONS:
            paragraph = re.sub(rf"\b{short}\.", f"{short}<dot>", paragraph)
        for sentence in re.split(r"(?<=[.!?])\s+(?=[“\"‘']?[A-Z])", paragraph):
            sentences.append(sentence.replace("<dot>", ".").strip())
    return (author.group(1).strip() if author else "", title.group(1).strip() if title else "", sentences)


def forms(lemma):
    """The word and its regular inflections, as one regular expression."""
    options = {lemma, lemma + "s", lemma + "es", lemma + "ed", lemma + "ing"}
    if lemma.endswith("e"):
        options |= {lemma + "d", lemma[:-1] + "ing"}
    if lemma.endswith("y"):
        options |= {lemma[:-1] + "ies", lemma[:-1] + "ied"}
    return re.compile(r"\b(" + "|".join(sorted(options, key=len, reverse=True)) + r")\b", re.I)


def score(sentence, match):
    """Higher is better: a self-contained sentence of a comfortable length."""
    words = sentence.split()
    count = len(words)
    if not 8 <= count <= 30:
        return None
    if sentence.count("“") != sentence.count("”") or sentence.count('"') % 2:
        return None
    if not sentence[0].isupper() and sentence[0] not in "“\"":
        return None
    points = 10 - abs(count - 16) * 0.5
    if match.start() == 0:
        points -= 2
    if words[0].strip("“\"") in {"He", "She", "It", "They", "This", "That", "But", "And", "Then", "So"}:
        points -= 2
    names = sum(1 for word in words[1:] if word[:1].isupper() and word not in {"I", "I’m", "I'm"})
    points -= names * 1.5
    points -= sentence.count(";") + sentence.count("—") + sentence.count("--")
    if "“" in sentence or '"' in sentence:
        points -= 1.5
    return points


def candidates(out_path):
    lemmas = []
    for path in sorted(glob.glob(DRAFTS)):
        lemmas += [entry["lemma"] for entry in json.load(open(path, encoding="utf-8"))]
    patterns = {lemma: forms(lemma) for lemma in dict.fromkeys(lemmas)}
    found = {lemma: [] for lemma in patterns}

    for path in sorted(glob.glob(os.path.join(CACHE, "[0-9]*.txt"))):
        author, title, sentences = read_book(path)
        if not author or not title:
            continue
        source = f"{author}, {title}"
        for sentence in sentences:
            lowered = sentence.lower()
            for lemma, pattern in patterns.items():
                if lemma[:4] not in lowered:
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
            picked.append({"quote": sentence, "source": source})
            if len(picked) == 5:
                break
        result[lemma] = picked

    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(result, handle, ensure_ascii=False, indent=2)
    covered = sum(1 for rows in result.values() if rows)
    print(f"{covered} of {len(result)} words have at least one candidate")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "fetch":
        fetch()
    elif len(sys.argv) >= 3 and sys.argv[1] == "candidates":
        candidates(sys.argv[2])
    else:
        print(__doc__)
