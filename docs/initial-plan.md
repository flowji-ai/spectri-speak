---
Date Created: 2026-03-08T00:15:00Z
Date Updated: 2026-03-12T14:07:00Z
---

# Spectri Speak — Development Plan

Fork of [zachswift615/speak2](https://github.com/zachswift615/speak2) (v1.6.0, MIT license).
**GitHub**: [flowji-ai/spectri-speak](https://github.com/flowji-ai/spectri-speak)

## Why We Forked

Speak2 is an excellent local macOS dictation app (Parakeet + Whisper, on-device AI refinement, personal dictionary). However the dictionary system has issues that make it impractical for daily use:

1. **Phonetic matching is too aggressive** — Soundex + Metaphone + 70% fuzzy matching runs against ALL dictionary words, not just aliases. Adding "VBOUT" to the dictionary causes "but" to be replaced. Adding "Tyber" causes "typed" to be replaced. Any word that phonetically resembles a common English word creates false positives.

2. **No programmatic dictionary access** — the app reads the dictionary into memory on launch. Editing `personal_dictionary.json` directly has no effect until restart, and may be overwritten. No CLI, API, or IPC mechanism exists to add words on the fly.

3. **Threshold is hardcoded** — the 70% fuzzy matching threshold is not user-configurable. No way to disable phonetic matching per-entry or globally.

## Strategy: Two-Layer Vocabulary Recognition

Rather than relying on a single mechanism, Spectri Speak uses a **hybrid approach** to domain vocabulary:

1. **Layer 1 — Pre-transcription priming** via WhisperKit's `promptTokens`. Dictionary terms are injected as context hints before the model decodes audio. This biases the model toward recognising domain terms during transcription. It helps with spelling disambiguation but is not reliable as a sole mechanism — academic research shows Whisper follows prompt hints only 17–38% of the time.

2. **Layer 2 — Post-transcription dictionary replacement** with configurable matching. This is the reliable fallback. Exact alias matching (like Wispr Flow) plus optional phonetic matching with user-controlled strictness. The combination of both layers means the model gets a better chance of recognising terms natively, and anything it misses gets caught by the dictionary processor.

**Why not just promptText?** Testing and research (arxiv 2406.05806) show that prompt-based priming alone is insufficient for truly novel vocabulary (brand names, acronyms, jargon). It helps the model choose "VBOUT" over "V-bout" when the audio is ambiguous, but won't reliably prevent "about" when the acoustic signal strongly favours it. The dictionary processor handles those cases.

**Why not just dictionary replacement?** Because the current phonetic matching is too aggressive — it replaces common words that sound vaguely similar. Priming reduces how often the dictionary processor needs to intervene, which means fewer opportunities for false positives.

## Planned Changes

### Priority 1: Fix Dictionary False Positives

The core problem. Without this, the dictionary is unusable at scale (71 entries imported from Wispr Flow caused constant false positives).

- **P1.1 — Configurable phonetic matching threshold** — add a slider in Settings > Dictionary (range: 50–100%, default: 85%). Higher = stricter matching, fewer false positives. Currently hardcoded at 70% in `PhoneticMatcher.swift:7`.
- **P1.2 — Per-entry phonetic toggle** — add an `enablePhoneticMatch` boolean to `DictionaryEntry`. When false, only exact alias matching applies. Default: true for proper names, false for short/ambiguous words.
- **P1.3 — Alias-only mode** — global toggle: "Only replace text that exactly matches an alias". Disables phonetic matching entirely. Useful for users migrating from Wispr Flow who expect exact-match behaviour.
- **P1.4 — Short word protection** — automatically skip phonetic matching for dictionary words of 4 characters or fewer to prevent common word collisions (e.g., PRD → "word").

**Affected files:**
- `Sources/Services/PhoneticMatcher.swift` — threshold, short word skip
- `Sources/Models/PersonalDictionary.swift` — `enablePhoneticMatch` field
- `Sources/Services/DictionaryProcessor.swift` — respect per-entry toggle + global alias-only mode
- `Sources/Views/DictionaryView.swift` — UI for threshold slider, per-entry toggle, global alias-only toggle

### Priority 2: Vocabulary Priming via promptTokens

WhisperKit's `promptTokens` parameter is already wired into both transcription paths:
- File-based: `WhisperTranscriber.swift:179–181` — working
- Streaming start: `WhisperTranscriber.swift:226–229` — working
- Streaming loop: `WhisperTranscriber.swift:325–331` — **deliberately disabled** because promptTokens caused empty results with `audioArray` (known WhisperKit bug #372, now fixed upstream)

Work needed:

- **P2.1 — Upgrade WhisperKit** to a version that includes the #372 fix (promptTokens + audioArray)
- **P2.2 — Re-enable promptTokens in the streaming loop** — currently skipped with a comment explaining the bug. Once WhisperKit is updated, pass `activeDecodeOptions` (which already includes promptTokens) into the streaming transcription passes.
- **P2.3 — Build dictionary hint string** — load enabled dictionary entries and format as a comma-separated glossary for `promptTokens`. Respect the 224-token limit; prioritise entries by category or frequency. This logic may already exist in `DictationController` — verify.
- **P2.4 — Test with problem terms** — specifically test VBOUT, Claude Code, Holmgren, RetroSuburbia, Spectri, SPARRA with and without priming to measure the actual improvement.

### Priority 3: Live Streaming Polish

Streaming transcription and the live overlay already exist. The infrastructure works — words appear as they're decoded via `LiveTranscriptionPanelController`. Refinements:

- **P3.1 — Verify overlay behaviour** — confirm the panel sits above other windows without stealing focus. It uses `NSPanel` already; may need `.floating` or `.nonactivatingPanel` level adjustments.
- **P3.2 — Dictionary processing on streaming text** — currently dictionary replacement only runs on the final transcription. Consider running it on the live overlay text too so the user sees corrected terms in real time (even if the final pass re-processes).
- **P3.3 — Confirm promptTokens in streaming passes** — once P2.2 is done, verify that live streaming text benefits from vocabulary priming, not just the final file-based transcription.

### Priority 4: Programmatic Dictionary Access

- **P4.1 — File watcher** — watch `personal_dictionary.json` for changes and reload automatically. Simplest approach; enables any external tool to modify the dictionary.
- **P4.2 — CLI interface** — `spectri-speak dict add "word" --aliases "alias1,alias2" --category name` for adding words from terminal or agent scripts.
- **P4.3 — Agent skill** — Claude Code skill (`spectri-speak-dictionary`) that writes to the JSON + triggers reload via file watcher. Source at skills-research prototypes folder, deployed via `skill-deployment` skill. The skill should warn when entries could cause false positives (short words, common-sounding terms).

### Priority 5: Upstream Sync

- Keep `upstream` remote pointing to `zachswift615/speak2`.
- Periodically merge upstream changes.
- Consider submitting threshold configurability as a PR to upstream.

## Technical Notes

- **Language**: Swift + SwiftUI
- **Build**: Requires `xcodebuild` (not `swift build`) due to MLX Metal shader compilation
- **Key files**:
  - `Sources/Services/PhoneticMatcher.swift` — phonetic matching algorithms, hardcoded 0.7 threshold
  - `Sources/Services/DictionaryProcessor.swift` — applies dictionary entries to transcribed text
  - `Sources/Services/WhisperTranscriber.swift` — WhisperKit integration, streaming, promptTokens
  - `Sources/Services/DictationController.swift` — main orchestrator: hotkey → record → transcribe → dictionary → refine → inject
  - `Sources/Models/PersonalDictionary.swift` — dictionary entry model
  - `Sources/Models/DictionaryState.swift` — dictionary state management
  - `Sources/Views/DictionaryView.swift` — dictionary UI
- **Tests**: `swift test` works for non-Metal code
- **Dictionary storage**: `~/Library/Application Support/Speak2/personal_dictionary.json`
- **WhisperKit promptTokens limit**: 224 tokens max (~50–100 vocabulary terms)
- **promptTokens effectiveness**: scales with model size. `large-v3` or `large-v3-turbo` recommended for reliable priming. Smaller models show inconsistent results.

## Context: Previous Dictation Setup

- Was using **Wispr Flow** (commercial, cloud-based) with 411 dictionary entries.
- Wispr Flow uses exact string matching — no phonetic matching, so short words were safe.
- Migrated to Speak2 for local-only privacy, Parakeet speed, and MIT license.
- 71 entries imported (names, brands, URLs, dotfiles) but phonetic false positives made it unusable at scale.
- Currently running with minimal dictionary while we fix the matching logic.

## Not Changing

- Speech recognition engines (Parakeet + WhisperKit both stay — user selects in settings)
- AI refinement (built-in Qwen 2.5 / Ollama) — not yet tested but architecture is sound
- Core UI/UX — menu bar app, hotkey system, transcription history
- Paste-to-active-app — `TextInjector.swift` already handles this

## Considered and Rejected

- **Replacing post-transcription dictionary with promptText-only** — rejected. Research shows prompt-based priming is unreliable as a sole mechanism (17–38% topic following rate). The hybrid approach keeps both layers.
- **Switching entirely to WhisperKit from Parakeet** — rejected. Both engines are already supported; no reason to remove a working option. Users can choose.
- **Ground-up rewrite** — rejected. The existing codebase already has streaming, live overlay, promptTokens wiring, dictionary system, and text injection. The work is refinement, not rebuilding.
