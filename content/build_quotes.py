"""Find quotations from public-domain literature for the catalogue words.

Usage:
    python3 content/build_quotes.py fetch
    python3 content/build_quotes.py candidates content/quote_candidates.json

"fetch" downloads the books listed in BOOKS from Project Gutenberg into
content/.cache (not committed). "candidates" reads the drafts and writes up to
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

ABBREVIATIONS = ["Mr", "Mrs", "Ms", "Dr", "St", "Mme", "Mlle", "M", "Esq", "Col", "Capt", "Rev", "Prof"]


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for number in BOOKS:
        path = os.path.join(CACHE, f"{number}.txt")
        if os.path.exists(path) and os.path.getsize(path) > 20000:
            continue
        url = f"https://www.gutenberg.org/cache/epub/{number}/pg{number}.txt"
        try:
            data = urllib.request.urlopen(url, timeout=90).read()
        except Exception as error:  # the site is sometimes down; report and carry on
            print(f"{number}: {error}")
            continue
        if b"*** START OF" not in data:
            print(f"{number}: not a book file, skipped")
            continue
        with open(path, "wb") as handle:
            handle.write(data)
        print(f"{number}: {len(data)} bytes")


def read_book(path):
    """Return (author, title, sentences) for one downloaded book."""
    text = open(path, encoding="utf-8-sig", errors="replace").read().replace("\r\n", "\n")
    title = re.search(r"^Title: (.+)$", text, re.M)
    author = re.search(r"^Author: (.+)$", text, re.M)
    start = re.search(r"\*\*\* START OF.*?\*\*\*", text)
    end = re.search(r"\*\*\* END OF", text)
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

    for path in sorted(glob.glob(os.path.join(CACHE, "*.txt"))):
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
