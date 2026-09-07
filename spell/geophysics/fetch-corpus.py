#!/usr/bin/env python3
"""Download text to mine for geophysics vocabulary into spell/geophysics/corpus/.

Sources (all free to use for deriving a word list):
  wikipedia.txt   plain-text extracts of every article in Wikipedia's
                  geophysics category tree plus a few neighbouring categories
  arxiv.txt       titles and abstracts of recent physics.geo-ph submissions

Run it from anywhere:  python spell/geophysics/fetch-corpus.py
Then in Vim:           :GeoSpellHarvest   (reviews the candidates)
The corpus directory is not tracked; re-run this to refresh it.
Only the standard library is used.
"""
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CORPUS = os.path.join(HERE, "corpus")
UA = "vimfiles-geospell/1.0 (personal spelling dictionary; contact via github.com/RobertCrummett)"

# Category tree roots and how deep to follow subcategories.
WIKI_ROOTS = [
    ("Category:Geophysics", 2),
    ("Category:Exploration geophysics", 2),
    ("Category:Seismology", 2),
    ("Category:Geodesy", 1),
    ("Category:Geomagnetism", 2),
    ("Category:Gravimetry", 1),
    ("Category:Geophysical imaging", 1),
    ("Category:Petroleum geology", 1),
    ("Category:Mineral exploration", 1),
    ("Category:Geostatistics", 1),
    ("Category:Inverse problems", 1),
    ("Category:Radiometric dating", 1),
    ("Category:Remote sensing", 1),
    ("Category:Structural geology", 1),
    ("Category:Igneous petrology", 1),
    ("Category:Sedimentology", 1),
    # Exploration and economic geology run close to geophysics.
    ("Category:Economic geology", 2),
    ("Category:Ore deposits", 2),
    ("Category:Mining", 1),
    ("Category:Mineralogy", 1),
    ("Category:Geochemistry", 1),
    ("Category:Hydrogeology", 1),
    ("Category:Well logging", 1),
]
# Subcategories that only hold people, prizes, journals or list pages.
WIKI_SKIP = re.compile(r"(awards|journals|organizations|organisations|stubs|lists|by country|by year|people|scientists|ists$|births|deaths|templates)", re.I)
WIKI_MAX_PAGES = 4000

ARXIV_TOTAL = 6000
ARXIV_BATCH = 1000


def get(url, retries=5):
    """GET with a polite user agent; on 429 wait for Retry-After (or a minute)."""
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < retries - 1:
                wait = int(e.headers.get("Retry-After", "0") or 0) or 60
                print(f"  rate limited, waiting {wait}s", file=sys.stderr)
                time.sleep(wait)
                continue
            if attempt == retries - 1:
                raise
            time.sleep(5 * (attempt + 1))
        except Exception:  # noqa: BLE001
            if attempt == retries - 1:
                raise
            time.sleep(5 * (attempt + 1))


def wiki_api(**params):
    params.update(format="json", formatversion="2")
    url = "https://en.wikipedia.org/w/api.php?" + urllib.parse.urlencode(params)
    return json.loads(get(url))


def wiki_members(cat, cmtype):
    out, cont = [], {}
    while True:
        data = wiki_api(action="query", list="categorymembers", cmtitle=cat, cmtype=cmtype, cmlimit="500", **cont)
        out += [m["title"] for m in data["query"]["categorymembers"]]
        if "continue" not in data:
            return out
        cont = {"cmcontinue": data["continue"]["cmcontinue"]}
        time.sleep(1.0)


def wiki_pages():
    seen_cats, pages = set(), []
    stack = [(c, d) for c, d in WIKI_ROOTS]
    while stack and len(pages) < WIKI_MAX_PAGES:
        cat, depth = stack.pop()
        if cat in seen_cats:
            continue
        seen_cats.add(cat)
        try:
            pages += wiki_members(cat, "page")
            if depth > 0:
                for sub in wiki_members(cat, "subcat"):
                    if not WIKI_SKIP.search(sub):
                        stack.append((sub, depth - 1))
        except Exception as e:  # noqa: BLE001
            print(f"  skip {cat}: {e}", file=sys.stderr)
        time.sleep(1.0)
    # dedupe, keep order, drop list/outline pages
    out, seen = [], set()
    for p in pages:
        if p not in seen and not p.startswith(("List of", "Outline of", "Timeline of", "Glossary of")):
            seen.add(p)
            out.append(p)
    return out[:WIKI_MAX_PAGES]


def fetch_wikipedia():
    pages = wiki_pages()
    print(f"wikipedia: {len(pages)} pages")
    path = os.path.join(CORPUS, "wikipedia.txt")
    with open(path, "w", encoding="utf-8") as f:
        for i in range(0, len(pages), 20):
            batch = pages[i:i + 20]
            try:
                data = wiki_api(action="query", prop="extracts", explaintext="1", exlimit="max", titles="|".join(batch))
            except Exception as e:  # noqa: BLE001
                print(f"  skip batch at {i}: {e}", file=sys.stderr)
                continue
            for page in data["query"].get("pages", []):
                text = page.get("extract", "")
                if text:
                    f.write(f"= {page['title']} =\n{text}\n\n")
            if i % 400 == 0:
                print(f"  {i}/{len(pages)}")
            time.sleep(3.0)
    print(f"wikipedia: wrote {path}")


TAG = re.compile(r"<[^>]+>")


def fetch_arxiv():
    path = os.path.join(CORPUS, "arxiv.txt")
    n = 0
    with open(path, "w", encoding="utf-8") as f:
        for start in range(0, ARXIV_TOTAL, ARXIV_BATCH):
            url = ("https://export.arxiv.org/api/query?search_query=cat:physics.geo-ph"
                   f"&start={start}&max_results={ARXIV_BATCH}&sortBy=submittedDate&sortOrder=descending")
            try:
                xml = get(url)
            except Exception as e:  # noqa: BLE001
                print(f"  skip arxiv batch {start}: {e}", file=sys.stderr)
                continue
            entries = re.findall(r"<entry>(.*?)</entry>", xml, re.S)
            for e in entries:
                title = re.search(r"<title>(.*?)</title>", e, re.S)
                summary = re.search(r"<summary>(.*?)</summary>", e, re.S)
                text = " ".join(TAG.sub(" ", m.group(1)) for m in (title, summary) if m)
                text = text.replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")
                f.write(re.sub(r"\s+", " ", text).strip() + "\n")
            n += len(entries)
            print(f"  arxiv {n}")
            if not entries:
                break
            time.sleep(3)
    print(f"arxiv: wrote {n} abstracts to {path}")


def main():
    os.makedirs(CORPUS, exist_ok=True)
    which = sys.argv[1:] or ["wikipedia", "arxiv"]
    if "wikipedia" in which:
        fetch_wikipedia()
    if "arxiv" in which:
        fetch_arxiv()


if __name__ == "__main__":
    main()
