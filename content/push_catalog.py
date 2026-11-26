"""Send the built catalogue to Supabase.

Usage:
    SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SECRET_KEY=... \\
        python3 content/push_catalog.py

Reads Flaub/words.json (run build_catalog.py first) and calls the database
function import_catalog, which upserts topics, words and their links and marks
the words as published. The function accepts only the service role, so this
needs the project's secret key: keep it out of the repository.
"""

import json
import os
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# slug, name, image asset in the app, premium
TOPICS = [
    ("emotions", "Emotions", "topic_emotions", False),
    ("character", "Character", "hero", True),
    ("persuasion", "Persuasion", "topic_persuasion", True),
    ("debate", "Debate", "topic_debate", True),
    ("business", "Business", "topic_business", True),
    ("literature", "Literature", "topic_literature", True),
    ("science", "Science", "topic_science", True),
    ("nature", "Nature", "topic_nature", True),
    ("travel", "Travel", "topic_travel", True),
    ("society", "Society", "tile_topics", True),
]


def payload():
    with open(os.path.join(ROOT, "Flaub", "words.json"), encoding="utf-8") as handle:
        words = json.load(handle)
    topics = [
        {"slug": slug, "name": name, "image": image, "premium": premium, "position": position}
        for position, (slug, name, image, premium) in enumerate(TOPICS)
    ]
    return {"topics": topics, "words": words}


def main():
    url = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/rpc/import_catalog"
    key = os.environ["SUPABASE_SECRET_KEY"]
    request = urllib.request.Request(
        url,
        data=json.dumps({"payload": payload()}).encode("utf-8"),
        headers={"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    print("words in the catalogue:", urllib.request.urlopen(request, timeout=120).read().decode())


if __name__ == "__main__":
    main()
