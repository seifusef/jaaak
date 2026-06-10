#!/usr/bin/env bash
#
# Downloads the three QUL (Quranic Universal Library, https://qul.tarteel.ai)
# resources required by the IndoPak Mushaf prototype and places them where
# the app expects them:
#
#   assets/indopak/indopak_15_lines_layout.db   "Indopak 15 lines" mushaf layout (SQLite)
#   assets/indopak/indopak_words.db             IndoPak word-by-word script (SQLite)
#   assets/indopak/fonts/indopak_nastaleeq.ttf  IndoPak Nastaleeq font (Hanafi)
#
# QUL is the ONLY permitted data source for this feature. Never substitute
# Quran text or layout data from anywhere else.
#
# QUL serves the SQLite exports from the resource pages below; the exact
# signed download URLs can change, so this script accepts overrides:
#
#   LAYOUT_URL=<direct sqlite url> WORDS_URL=<direct sqlite url> \
#   FONT_URL=<direct ttf url> tool/fetch_qul_assets.sh
#
# Where to find them in a browser:
#   Layout : https://qul.tarteel.ai/resources/mushaf-layout  -> "Indopak 15 lines" -> Export/Download SQLite
#   Words  : https://qul.tarteel.ai/resources/quran-script   -> IndoPak (word by word) -> Download SQLite
#            (e.g. https://qul.tarteel.ai/resources/quran-script/59)
#   Font   : https://qul.tarteel.ai/resources/font           -> IndoPak Nastaleeq (Hanafi)

set -euo pipefail
cd "$(dirname "$0")/.."

ASSET_DIR="assets/indopak"
FONT_DIR="$ASSET_DIR/fonts"
mkdir -p "$FONT_DIR"

LAYOUT_DEST="$ASSET_DIR/indopak_15_lines_layout.db"
WORDS_DEST="$ASSET_DIR/indopak_words.db"
FONT_DEST="$FONT_DIR/indopak_nastaleeq.ttf"

# Default font URL on the official QUL CDN (Hanafi Nastaleeq).
FONT_URL="${FONT_URL:-https://static-cdn.tarteel.ai/qul/fonts/nastaleeq/Hanafi/normal-v4.2.2/with-waqf-lazmi/font.ttf}"
LAYOUT_URL="${LAYOUT_URL:-}"
WORDS_URL="${WORDS_URL:-}"

download() { # url dest
  echo "Downloading $1"
  if ! curl -fL --retry 3 -o "$2" "$1"; then
    rm -f "$2"
    echo "DOWNLOAD FAILED: $1" >&2
    echo "Refusing to continue — Quran data must come from QUL and is never substituted." >&2
    exit 1
  fi
}

check_sqlite_table() { # file table
  if command -v sqlite3 >/dev/null; then
    if ! sqlite3 "file:$1?mode=ro" \
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='$2';" \
        | grep -q '^[1-9]'; then
      echo "ERROR: $1 does not contain a '$2' table — wrong QUL export?" >&2
      exit 1
    fi
    rows=$(sqlite3 "file:$1?mode=ro" "SELECT count(*) FROM $2;")
    echo "  ok: $1 ($2 table, $rows rows)"
  else
    echo "  note: sqlite3 CLI not found, skipping validation of $1"
  fi
}

# --- Font ------------------------------------------------------------------
if [[ -s "$FONT_DEST" ]]; then
  echo "Font already present: $FONT_DEST"
else
  download "$FONT_URL" "$FONT_DEST"
fi

# --- Layout DB ---------------------------------------------------------------
if [[ -s "$LAYOUT_DEST" ]]; then
  echo "Layout DB already present: $LAYOUT_DEST"
elif [[ -n "$LAYOUT_URL" ]]; then
  download "$LAYOUT_URL" "$LAYOUT_DEST"
else
  cat >&2 <<'EOF'
MISSING: Indopak 15 lines layout database.
  NOTE: QUL serves SQLite exports to signed-in users (free account).
  1. Sign in at https://qul.tarteel.ai, open
     https://qul.tarteel.ai/resources/mushaf-layout
  2. Pick "Indopak 15 lines" and download the SQLite export
  3. Then EITHER commit the file as
       assets/indopak/indopak_15_lines_layout.db
     (e.g. upload via the GitHub web UI), OR set a direct file URL in the
     repo Actions variable QUL_LAYOUT_URL / env LAYOUT_URL and re-run.
EOF
  MISSING=1
fi

# --- Words DB ----------------------------------------------------------------
if [[ -s "$WORDS_DEST" ]]; then
  echo "Words DB already present: $WORDS_DEST"
elif [[ -n "$WORDS_URL" ]]; then
  download "$WORDS_URL" "$WORDS_DEST"
else
  cat >&2 <<'EOF'
MISSING: IndoPak word-by-word script database.
  NOTE: QUL serves SQLite exports to signed-in users (free account).
  1. Sign in at https://qul.tarteel.ai, open
     https://qul.tarteel.ai/resources/quran-script (IndoPak, word by word)
  2. Download the SQLite export
  3. Then EITHER commit the file as
       assets/indopak/indopak_words.db
     (e.g. upload via the GitHub web UI), OR set a direct file URL in the
     repo Actions variable QUL_WORDS_URL / env WORDS_URL and re-run.
EOF
  MISSING=1
fi

if [[ "${MISSING:-0}" == 1 ]]; then
  echo >&2
  echo "Some QUL assets are still missing — see instructions above." >&2
  exit 1
fi

# Some QUL exports ship zipped; unpack transparently if needed.
for f in "$LAYOUT_DEST" "$WORDS_DEST"; do
  if file "$f" | grep -qi 'zip archive'; then
    echo "Unzipping $f"
    tmp=$(mktemp -d)
    unzip -o -d "$tmp" "$f" >/dev/null
    inner=$(find "$tmp" \( -name '*.db' -o -name '*.sqlite' \) | head -1)
    [[ -n "$inner" ]] || { echo "ERROR: no .db inside $f" >&2; exit 1; }
    mv "$inner" "$f"
    rm -rf "$tmp"
  fi
done

check_sqlite_table "$LAYOUT_DEST" pages
check_sqlite_table "$WORDS_DEST" words

echo
echo "All QUL assets in place. Run: flutter pub get && flutter run"
