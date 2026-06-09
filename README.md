# Arkani — IndoPak Mushaf Viewer (Prototype)

A fully separate, read-only **IndoPak 15-line Mushaf viewer** feature module
for the Arkani app, isolated under `lib/features/indopak_mushaf/`.

> **Note for reviewers:** this repository was empty when the feature was
> developed, so a minimal host shell (`lib/main.dart`) stands in for the
> Arkani app. The existing Madinah/QCF Mushaf is **not** present in this
> repository and therefore untouched. To merge into Arkani, carry over only:
> `lib/features/indopak_mushaf/`, `lib/core/feature_flags.dart`, the
> `assets/indopak/` entries in `pubspec.yaml`, the dependencies
> (`flutter_riverpod`, `sqflite`, `path`, `path_provider`), and the
> feature-flagged tile from `lib/main.dart`.

## Data source — QUL only (mandatory)

All Quran text, layout data, and fonts come **exclusively** from
[QUL (Quranic Universal Library)](https://qul.tarteel.ai), the official
project by Quran.com/Tarteel:

| Resource | QUL page | Bundled as |
|---|---|---|
| "Indopak 15 lines" mushaf layout (SQLite, `pages` table) | [resources/mushaf-layout](https://qul.tarteel.ai/resources/mushaf-layout) | `assets/indopak/indopak_15_lines_layout.db` |
| IndoPak word-by-word script (SQLite, `words` table) | [resources/quran-script](https://qul.tarteel.ai/resources/quran-script) | `assets/indopak/indopak_words.db` |
| IndoPak Nastaleeq font (Hanafi) | [resources/font](https://qul.tarteel.ai/resources/font) | `assets/indopak/fonts/indopak_nastaleeq.ttf` |

**The app never generates, types, or "fills in" Quranic text.** Every word
rendered is read from the QUL words database; if an asset or row is missing
the viewer shows an error state instead of substituting text. The three
asset files are intentionally **not committed** — fetch them with:

```bash
tool/fetch_qul_assets.sh
# or, with direct download links copied from the QUL pages:
LAYOUT_URL=... WORDS_URL=... tool/fetch_qul_assets.sh
```

The script validates that the downloads contain the expected `pages` /
`words` tables before accepting them.

## Running

```bash
flutter create . --platforms=android,ios   # one-time: generate platform runners
tool/fetch_qul_assets.sh                   # download QUL data + font
flutter pub get
flutter run
```

The home screen shows a **«مصحف إندوباك (تجريبي)»** tile, gated behind
`kEnableIndoPakMushaf` in `lib/core/feature_flags.dart` — set it to `false`
to hide the entry point.

## Architecture

```
lib/features/indopak_mushaf/
├── application/providers.dart        Riverpod providers (init, page count, page, surah names)
├── data/
│   ├── indopak_assets.dart           Asset paths + missing-assets exception
│   ├── indopak_font.dart             Runtime FontLoader for the QUL Nastaleeq font
│   ├── indopak_database.dart         Copies asset DBs to app storage, opens read-only
│   └── indopak_mushaf_repository.dart  Queries pages/words; resolves QUL column-name variants
├── domain/models.dart                MushafPage / MushafLine / MushafWord / line types
└── presentation/
    ├── indopak_mushaf_screen.dart    RTL PageView over all pages (per layout DB count)
    └── widgets/
        ├── mushaf_page_widget.dart   15 equal line slots per page
        ├── mushaf_line_widget.dart   One Text per line, FittedBox scaling, is_centered honored
        └── surah_header_widget.dart  Decorative surah_name line
```

Rendering follows the QUL layout exactly: for each page, the `pages` table
gives the lines; each `ayah` line fetches words `first_word_id..last_word_id`
from the `words` table and renders them as a single `Text` in the Nastaleeq
font. `basmallah` lines reuse the basmallah words (1:1) from the same QUL
database, and `is_centered` selects natural-width centering vs. full-width
justification. Per-line `FittedBox` scaling keeps 15 lines on screen with no
overflow on small devices.

State management is **Riverpod** (no GetX in this module). The viewer is
read-only: no bookmarks, audio, or sync integration yet.
