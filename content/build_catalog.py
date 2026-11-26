"""Merge drafted word entries, check them, and add pronunciation and frequency.

Usage:
    pip install cmudict wordfreq
    python3 content/build_catalog.py OUT.json DRAFT1.json [DRAFT2.json ...]

Each draft file is a JSON array of entries with the keys in REQUIRED below.
The pronunciation is not written by hand: it is converted from the CMU
Pronouncing Dictionary (American English). Frequency comes from wordfreq.
Entries that fail a check are still written, with their problems listed in
"issues", and are reported on stdout so a person can fix them.
"""

import json
import sys

import cmudict
from wordfreq import zipf_frequency

REQUIRED = ["lemma", "level", "part_of_speech", "definition", "example", "synonyms", "origin"]
PARTS = {"adj.", "n.", "v.", "adv."}

VOWELS = {
    "AA": "ɑ", "AE": "æ", "AO": "ɔ", "AW": "aʊ", "AY": "aɪ", "EH": "ɛ", "EY": "eɪ",
    "IH": "ɪ", "IY": "i", "OW": "oʊ", "OY": "ɔɪ", "UH": "ʊ", "UW": "u",
}
CONSONANTS = {
    "B": "b", "CH": "tʃ", "D": "d", "DH": "ð", "F": "f", "G": "ɡ", "HH": "h", "JH": "dʒ",
    "K": "k", "L": "l", "M": "m", "N": "n", "NG": "ŋ", "P": "p", "R": "r", "S": "s",
    "SH": "ʃ", "T": "t", "TH": "θ", "V": "v", "W": "w", "Y": "j", "Z": "z", "ZH": "ʒ",
}
# Two-consonant clusters that can start an English syllable.
ONSETS = {
    ("P", "L"), ("P", "R"), ("B", "L"), ("B", "R"), ("T", "R"), ("D", "R"), ("K", "L"), ("K", "R"),
    ("G", "L"), ("G", "R"), ("F", "L"), ("F", "R"), ("TH", "R"), ("SH", "R"), ("S", "P"), ("S", "T"),
    ("S", "K"), ("S", "L"), ("S", "M"), ("S", "N"), ("S", "W"), ("K", "W"), ("T", "W"), ("D", "W"),
    ("K", "Y"), ("P", "Y"), ("B", "Y"), ("F", "Y"), ("M", "Y"), ("V", "Y"), ("HH", "Y"),
}

PRONUNCIATIONS = cmudict.dict()


def to_ipa(phones):
    """Convert one ARPAbet pronunciation to IPA, with a primary-stress mark."""
    symbols = []
    stress_at = None
    vowel_count = 0
    for position, phone in enumerate(phones):
        base = phone.rstrip("012")
        stress = phone[-1] if phone[-1] in "012" else None
        if stress is None:
            symbols.append(CONSONANTS[base])
            continue
        vowel_count += 1
        if base == "AH":
            symbols.append("ʌ" if stress == "1" else "ə")
        elif base == "ER":
            symbols.append("ɝ" if stress == "1" else "ɚ")
        else:
            symbols.append(VOWELS[base])
        if stress == "1" and stress_at is None:
            # Put the mark before the consonants that open the stressed syllable.
            start = position
            before = [p for p in phones[:position]]
            if before and before[-1][-1] not in "012":
                start = position - 1
                if len(before) >= 2 and before[-2][-1] not in "012" and (before[-2], before[-1]) in ONSETS:
                    start = position - 2
                    # s + stop + liquid or glide, as in "obscure" or "astray".
                    if len(before) >= 3 and before[-3] == "S" and before[-2] in ("P", "T", "K"):
                        start = position - 3
            stress_at = start
    if vowel_count > 1 and stress_at is not None:
        symbols.insert(stress_at, "ˈ")
    return "".join(symbols)


def check(entry):
    issues = []
    for key in REQUIRED:
        if key not in entry:
            issues.append(f"missing {key}")
    if issues:
        return issues
    lemma = entry["lemma"]
    stem = lemma[: max(4, len(lemma) - 3)]
    if entry["part_of_speech"] not in PARTS:
        issues.append("unknown part of speech")
    words = entry["definition"].split()
    if not 3 <= len(words) <= 14:
        issues.append("definition length")
    if stem in entry["definition"].lower():
        issues.append("definition uses the word itself")
    if entry["definition"].endswith("."):
        issues.append("definition ends with a period")
    if stem not in entry["example"].lower():
        issues.append("example does not contain the word")
    if not 6 <= len(entry["example"].split()) <= 22:
        issues.append("example length")
    synonyms = entry["synonyms"]
    if len(set(synonyms)) != 3 or lemma in synonyms:
        issues.append("needs three distinct synonyms")
    if not entry["origin"]:
        issues.append("no origin")
    if entry["level"] not in (1, 2, 3):
        issues.append("level out of range")
    return issues


def main():
    out_path, draft_paths = sys.argv[1], sys.argv[2:]
    entries, seen = [], set()
    for path in draft_paths:
        with open(path, encoding="utf-8") as handle:
            for entry in json.load(handle):
                if entry.get("lemma") in seen:
                    continue
                seen.add(entry.get("lemma"))
                entries.append(entry)

    flagged = 0
    for entry in entries:
        issues = check(entry)
        lemma = entry.get("lemma", "")
        phones = PRONUNCIATIONS.get(lemma)
        entry["ipa"] = to_ipa(phones[0]) if phones else ""
        if not phones:
            issues.append("no pronunciation in CMUdict")
        entry["zipf"] = zipf_frequency(lemma, "en")
        entry["issues"] = issues
        if issues:
            flagged += 1
            print(f"{lemma}: {'; '.join(issues)}")

    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(entries, handle, ensure_ascii=False, indent=2)
    print(f"{len(entries)} entries written to {out_path}, {flagged} flagged")


if __name__ == "__main__":
    main()
