<!-- SPECTRI:START -->
@./SPECTRI.md
<!-- SPECTRI:END -->

---
Date Created: 2026-03-08T00:15:00Z
Date Updated: 2026-03-08T00:30:00Z
---

# Spectri Speak

Local voice dictation for macOS. Fork of [zachswift615/speak2](https://github.com/zachswift615/speak2) with improved dictionary matching and programmatic dictionary access.

**GitHub**: [flowji-ai/spectri-speak](https://github.com/flowji-ai/spectri-speak)
**Local**: `04-REPOSITORIES/04-REPOS-Spectri/spectri-speak/`

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

## Planned: Agent Skill

Once the CLI/API for dictionary management is built, create an agent skill (`speak2-dictionary` or `spectri-speak-dictionary`) that allows adding/removing/listing dictionary entries from any Claude Code session. Skill source goes to `05-RESOURCES/05-APPLIED-RESEARCH/agentic-systems/research/skills-research/03-outputs/prototypes/`, deployed via `skill-deployment`.

## What We're Not Changing

Speech recognition, AI refinement, UI/UX, transcription history — all upstream features stay as-is.

## Key Files

- `Sources/Models/PersonalDictionary.swift` — dictionary entry model
- `Sources/Models/DictionaryState.swift` — dictionary state/logic
- `Sources/Views/DictionaryView.swift` — dictionary settings UI
- `docs/plan.md` — development plan

## Upstream Sync

- `origin` = `flowji-ai/spectri-speak` (our fork)
- `upstream` = `zachswift615/speak2` (original)
- Merge upstream periodically: `git fetch upstream && git merge upstream/main`

## Dictionary Location

`~/Library/Application Support/Speak2/personal_dictionary.json`

## Important Caveats

- Speak2's phonetic matching (Soundex + Metaphone + fuzzy) applies to ALL dictionary words, not just aliases. Any dictionary word that phonetically resembles a common English word will cause false positive replacements. Do not add short or common-sounding words without alias-only mode enabled.
- Dictionary entries that can be confused with single-syllable plain English words (e.g. VBOUT → "but", PRD → "word") will cause constant false positives. Avoid these until the threshold is configurable.
- Editing `personal_dictionary.json` directly does NOT work — the app caches the dictionary in memory and does not watch the file. Changes require restart at minimum, and may be overwritten.
