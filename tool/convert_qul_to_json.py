#!/usr/bin/env python3
"""Convert the two downloaded QUL SQLite exports into a compact JSON asset
for the Flutter web build (sqflite does not run in browsers).

Input (downloaded from QUL — https://qul.tarteel.ai — the ONLY permitted
data source; see tool/fetch_qul_assets.sh):
  assets/indopak/indopak_15_lines_layout.db  ("Indopak 15 lines" layout, `pages` table)
  assets/indopak/indopak_words.db            (IndoPak word-by-word script, `words` table)

Output:
  assets/indopak/mushaf_data.json

This script is a pure transformation: every word in the output is copied
verbatim from the QUL words database. It NEVER generates, fixes or fills in
Quranic text — any missing or empty data aborts the build with an error.
"""

import json
import os
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Env overrides exist for the script's own tests only — production builds
# always read the QUL files from assets/indopak/.
LAYOUT_DB = os.environ.get(
    "INDOPAK_LAYOUT_DB",
    os.path.join(ROOT, "assets/indopak/indopak_15_lines_layout.db"))
WORDS_DB = os.environ.get(
    "INDOPAK_WORDS_DB",
    os.path.join(ROOT, "assets/indopak/indopak_words.db"))
OUT_PATH = os.environ.get(
    "INDOPAK_OUT_JSON",
    os.path.join(ROOT, "assets/indopak/mushaf_data.json"))

# The same column-name variants the Dart sqlite repository accepts.
PAGE_COLS = ["page_number", "page"]
LINE_COLS = ["line_number", "line"]
TYPE_COLS = ["line_type", "type"]
CENTER_COLS = ["is_centered", "centered"]
SURAH_NO_COLS = ["surah_number", "surah", "chapter"]
WORD_ID_COLS = ["word_id", "word_index", "id"]
WORD_TEXT_COLS = ["text", "word_text", "word"]
WORD_SURAH_COLS = ["surah", "surah_number", "chapter"]
WORD_AYAH_COLS = ["ayah", "ayah_number", "verse"]


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    print("Aborting — the build must never ship substituted or partial "
          "Quran data.", file=sys.stderr)
    sys.exit(1)


def open_ro(path, label):
    if not os.path.isfile(path):
        fail(f"{label} not found at {path}. Run tool/fetch_qul_assets.sh first.")
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True)


def table_columns(con, table):
    try:
        return {row[1] for row in con.execute(f"PRAGMA table_info({table})")}
    except sqlite3.Error:
        return set()


def pick(cols, candidates, what):
    for candidate in candidates:
        if candidate in cols:
            return candidate
    fail(f"{what}: none of {candidates} present (found {sorted(cols)})")


def load_words(con):
    cols = table_columns(con, "words")
    if not cols:
        fail(f"{WORDS_DB} has no `words` table — wrong QUL export?")
    c_id = pick(cols, WORD_ID_COLS, "words id column")
    c_text = pick(cols, WORD_TEXT_COLS, "words text column")
    c_surah = pick(cols, WORD_SURAH_COLS, "words surah column")
    c_ayah = pick(cols, WORD_AYAH_COLS, "words ayah column")

    words = {}
    basmallah = []
    rows = con.execute(
        f"SELECT {c_id}, {c_text}, {c_surah}, {c_ayah} FROM words ORDER BY {c_id}")
    for wid, text, surah, ayah in rows:
        if not isinstance(text, str) or not text.strip():
            fail(f"QUL words database has an empty text for word id {wid}.")
        words[int(wid)] = text
        # Al-Fatiha 1:1 is the basmallah in the IndoPak script export.
        if int(surah) == 1 and int(ayah) == 1 and len(basmallah) < 4:
            basmallah.append(text)
    if not words:
        fail("QUL words database is empty.")
    if not basmallah:
        fail("QUL words database is missing surah 1 ayah 1 (basmallah).")
    return words, basmallah


def load_pages(con, words, basmallah):
    cols = table_columns(con, "pages")
    if not cols:
        fail(f"{LAYOUT_DB} has no `pages` table — wrong QUL export?")
    c_page = pick(cols, PAGE_COLS, "pages page column")
    c_line = pick(cols, LINE_COLS, "pages line column")
    c_type = pick(cols, TYPE_COLS, "pages line_type column")
    c_center = pick(cols, CENTER_COLS, "pages is_centered column")
    c_first = pick(cols, ["first_word_id"], "pages first_word_id column")
    c_last = pick(cols, ["last_word_id"], "pages last_word_id column")
    c_surah = pick(cols, SURAH_NO_COLS, "pages surah_number column")

    pages = {}
    rows = con.execute(
        f"SELECT {c_page}, {c_line}, {c_type}, {c_center}, {c_first}, "
        f"{c_last}, {c_surah} FROM pages ORDER BY {c_page}, {c_line}")
    for page, line, line_type, centered, first_id, last_id, surah in rows:
        entry = {"l": int(line), "t": line_type or "unknown",
                 "c": 1 if centered in (1, "1", True) else 0}
        if surah is not None:
            entry["s"] = int(surah)
        if first_id is not None and last_id is not None:
            # Same semantics as SQL BETWEEN in the native repository.
            texts = [words[i] for i in range(int(first_id), int(last_id) + 1)
                     if i in words]
            if not texts:
                fail(f"Page {page} line {line}: word ids {first_id}..{last_id} "
                     f"not found in the QUL words database.")
            entry["w"] = texts
        elif line_type == "basmallah":
            entry["w"] = list(basmallah)
        pages.setdefault(int(page), []).append(entry)
    if not pages:
        fail("QUL layout database has no pages.")

    page_count = max(pages)
    missing = [p for p in range(1, page_count + 1) if p not in pages]
    if missing:
        fail(f"QUL layout database is missing pages: {missing[:10]} ...")
    return [pages[p] for p in range(1, page_count + 1)]


def load_surah_names(cons):
    for con in cons:
        for table in ("chapters", "surahs"):
            cols = table_columns(con, table)
            if not cols:
                continue
            c_id = next((c for c in ("id", "surah_number", "chapter_id")
                         if c in cols), None)
            c_name = next((c for c in ("name_arabic", "arabic_name",
                                       "name_ar", "name") if c in cols), None)
            if not c_id or not c_name:
                continue
            names = {str(int(row[0])): row[1]
                     for row in con.execute(
                         f"SELECT {c_id}, {c_name} FROM {table}")
                     if row[1] and isinstance(row[1], str)}
            if names:
                return names
    return {}


def validate(pages):
    page_count = len(pages)
    if page_count < 600:
        fail(f"Unexpected page count {page_count} — the IndoPak 15-line "
             f"layout has 610 pages. Wrong layout export?")
    total_words = sum(len(e.get("w", [])) for page in pages for e in page)
    if total_words < 70000:
        fail(f"Only {total_words} words across all pages — the Quran has "
             f"~77k words. Wrong/incomplete words export?")
    page1 = pages[0]
    if not any(e["t"] == "surah_name" for e in page1):
        fail("Page 1 has no surah_name line — unexpected layout data.")
    if not any(e.get("w") for e in page1):
        fail("Page 1 has no words — unexpected layout/words data.")
    for p, page in enumerate(pages, start=1):
        for e in page:
            for w in e.get("w", []):
                if not isinstance(w, str) or not w.strip():
                    fail(f"Empty word on page {p} — refusing to build.")
    return page_count, total_words


def main():
    layout_con = open_ro(LAYOUT_DB, "QUL layout database")
    words_con = open_ro(WORDS_DB, "QUL words database")

    words, basmallah = load_words(words_con)
    pages = load_pages(layout_con, words, basmallah)
    surah_names = load_surah_names([layout_con, words_con])
    page_count, total_words = validate(pages)

    data = {
        "version": 1,
        "source": "QUL (https://qul.tarteel.ai) — Indopak 15 lines layout "
                  "+ IndoPak word-by-word script. Pure transformation; no "
                  "text generated.",
        "page_count": page_count,
        "surah_names": surah_names,
        "pages": pages,
    }
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

    size_kb = os.path.getsize(OUT_PATH) // 1024
    print(f"OK: wrote {OUT_PATH} ({size_kb} KiB) — {page_count} pages, "
          f"{total_words} words, {len(surah_names)} surah names, "
          f"page 1 lines: {len(pages[0])}.")


if __name__ == "__main__":
    main()
