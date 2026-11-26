"""Download the English etymology of each catalogue word from Wiktionary.

Usage:
    python3 content/fetch_etymology.py

Writes content/.cache/etymology.json, mapping each lemma to the wikitext of its
English "Etymology" section ("" when the page has none). The file is the source
a reviewer compares our "origin" lines against. Wiktionary text is CC BY-SA:
it is used here for checking only and is not copied into the catalogue.
"""

import glob
import json
import os
import re
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, ".cache", "etymology.json")
API = ("https://en.wiktionary.org/w/api.php?action=query&prop=revisions&rvprop=content&rvslots=main"
       "&format=json&formatversion=2&titles=")
BATCH = 40  # the API accepts up to 50 titles per request


def english_etymology(wikitext):
    english = re.search(r"^==English==\s*$(.*?)(?=^==[^=]|\Z)", wikitext, re.M | re.S)
    if not english:
        return ""
    sections = re.findall(r"^===+\s*Etymology[^=]*===+\s*$(.*?)(?=^==|\Z)", english.group(1), re.M | re.S)
    return "\n---\n".join(" ".join(section.split())[:900] for section in sections[:2])


def main():
    lemmas = []
    for path in sorted(glob.glob(os.path.join(HERE, "drafts", "*.json"))):
        lemmas += [entry["lemma"] for entry in json.load(open(path, encoding="utf-8"))]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    found = json.load(open(OUT, encoding="utf-8")) if os.path.exists(OUT) else {}
    missing = [lemma for lemma in lemmas if lemma not in found]
    for start in range(0, len(missing), BATCH):
        batch = missing[start:start + BATCH]
        url = API + urllib.parse.quote("|".join(batch))
        request = urllib.request.Request(url, headers={"User-Agent": "catalogue-check/0.1"})
        for attempt in range(4):
            try:
                reply = json.load(urllib.request.urlopen(request, timeout=60))
                break
            except Exception as error:
                print(f"batch {start}: {error}; waiting")
                time.sleep(20 * (attempt + 1))
        else:
            continue
        for page in reply.get("query", {}).get("pages", []):
            revisions = page.get("revisions") or []
            text = revisions[0]["slots"]["main"]["content"] if revisions else ""
            found[page["title"]] = english_etymology(text)
        time.sleep(3)
    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(found, handle, ensure_ascii=False, indent=1)
    print(f"{sum(1 for text in found.values() if text)} of {len(lemmas)} words have an etymology section")


if __name__ == "__main__":
    main()
