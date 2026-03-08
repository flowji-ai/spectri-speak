---
Date Created: 2026-03-08T00:15:00Z
Date Updated: 2026-03-08T00:15:00Z
---

# Spectri Speak — Development Plan

Fork of [zachswift615/speak2](https://github.com/zachswift615/speak2) (v1.6.0, MIT license).
**GitHub**: [flowji-ai/spectri-speak](https://github.com/flowji-ai/spectri-speak)

## Why We Forked

Speak2 is an excellent local macOS dictation app (Parakeet + Whisper, on-device AI refinement, personal dictionary). However the dictionary system has issues that make it impractical for daily use:

1. **Phonetic matching is too aggressive** — Soundex + Metaphone + 70% fuzzy matching runs against ALL dictionary words, not just aliases. Adding "VBOUT" to the dictionary causes "but" to be replaced. Adding "Tyber" causes "typed" to be replaced. Any word that phonetically resembles a common English word creates false positives.

2. **No programmatic dictionary access** — the app reads the dictionary into memory on launch. Editing `personal_dictionary.json` directly has no effect until restart, and may be overwritten. No CLI, API, or IPC mechanism exists to add words on the fly.

3. **Threshold is hardcoded** — the 70% fuzzy matching threshold is not user-configurable. No way to disable phonetic matching per-entry or globally.

## Planned Changes

### Priority 1: Fix Dictionary False Positives

- **Configurable phonetic matching threshold** — add a slider in Settings > Dictionary (range: 50-100%, default: 85%). Higher = stricter matching, fewer false positives.
- **Per-entry phonetic toggle** — add an `enablePhoneticMatch` boolean to `DictionaryEntry`. When false, only exact alias matching applies. Default: true for names, false for short words.
- **Alias-only mode** — global toggle: "Only replace text that exactly matches an alias". Disables phonetic matching entirely. Useful for users migrating from Wispr Flow who expect exact-match behavior.
- **Short word protection** — automatically skip phonetic matching for dictionary words of 4 characters or fewer to prevent common word collisions.

### Priority 2: Programmatic Dictionary Access

- **CLI interface** — `speak2 dict add "word" --aliases "alias1,alias2" --category name` for adding words from terminal or agent scripts.
- **Unix socket / local API** — lightweight IPC so running agents (Claude Code, OpenCode) can add dictionary entries without restarting the app.
- **File watcher** — watch `personal_dictionary.json` for changes and reload automatically. Simplest approach if CLI/API is complex.
- **Agent skill** — Claude Code skill (`spectri-speak-dictionary`) that calls the CLI or writes to the JSON + triggers reload. Source at skills-research prototypes folder, deployed via `skill-deployment` skill. Important: dictionary entries that can be confused with single-syllable plain English words (e.g. VBOUT → "but", PRD → "word") will cause constant false positives — the skill should warn about this.

### Priority 3: Upstream Sync

- Keep `upstream` remote pointing to `zachswift615/speak2`.
- Periodically merge upstream changes.
- Consider submitting threshold configurability as a PR to upstream.

## Technical Notes

- **Language**: Swift + SwiftUI
- **Build**: Requires `xcodebuild` (not `swift build`) due to MLX Metal shader compilation
- **Key files**:
  - `Sources/Models/PersonalDictionary.swift` — dictionary entry model
  - `Sources/Models/DictionaryState.swift` — dictionary state management
  - `Sources/Views/DictionaryView.swift` — dictionary UI
  - Phonetic matching logic — locate in DictionaryState or a processor file
- **Tests**: `swift test` works for non-Metal code
- **Dictionary storage**: `~/Library/Application Support/Speak2/personal_dictionary.json`

## Context: Previous Dictation Setup

- Was using **Wispr Flow** (commercial, cloud-based) with 411 dictionary entries.
- Wispr Flow uses exact string matching — no phonetic matching, so short words were safe.
- Migrated to Speak2 for local-only privacy, Parakeet speed, and MIT license.
- 71 entries imported (names, brands, URLs, dotfiles) but phonetic false positives made it unusable at scale.
- Currently running with minimal dictionary while we fix the matching logic.

## Not Changing

- Speech recognition engine (Parakeet/Whisper) — working great
- AI refinement (built-in Qwen 2.5 / Ollama) — not yet tested but architecture is sound
- Core UI/UX — menu bar app, hotkey system, live overlay all work well
- Transcription history — useful as-is
