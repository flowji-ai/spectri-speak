---
Date Created: 2026-03-08T00:15:00Z
Date Updated: 2026-03-08T00:15:00Z
---

# Speak2 (Flowji Fork)

Local voice dictation for macOS. Fork of [zachswift615/speak2](https://github.com/zachswift615/speak2) with improved dictionary matching and programmatic dictionary access.

## Quick Start

- **Build**: `xcodebuild build -scheme Speak2 -configuration Release -destination 'platform=macOS' -derivedDataPath .derivedData`
- **Run**: `.derivedData/Build/Products/Release/Speak2`
- **Test**: `swift test`
- **Must use xcodebuild** (not `swift build`) — MLX requires Metal shader compilation via Xcode build system.

## What We're Changing

See [docs/plan.md](docs/plan.md) for full details.

1. Configurable phonetic matching threshold (currently hardcoded at 70%)
2. Per-entry phonetic toggle and alias-only mode
3. CLI/API for programmatic dictionary management
4. Short word protection against false positives

## What We're Not Changing

Speech recognition, AI refinement, UI/UX, transcription history — all upstream features stay as-is.

## Key Files

- `Sources/Models/PersonalDictionary.swift` — dictionary entry model
- `Sources/Models/DictionaryState.swift` — dictionary state/logic
- `Sources/Views/DictionaryView.swift` — dictionary settings UI
- `docs/plan.md` — development plan

## Upstream Sync

- `origin` = `flowji-ai/speak2` (our fork)
- `upstream` = `zachswift615/speak2` (original)
- Merge upstream periodically: `git fetch upstream && git merge upstream/main`

## Dictionary Location

`~/Library/Application Support/Speak2/personal_dictionary.json`

## Important Caveat

Speak2's phonetic matching (Soundex + Metaphone + fuzzy) applies to ALL dictionary words, not just aliases. Any dictionary word that phonetically resembles a common English word will cause false positive replacements. Do not add short or common-sounding words without alias-only mode enabled.
