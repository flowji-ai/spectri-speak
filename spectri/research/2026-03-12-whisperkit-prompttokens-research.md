---
Date Created: 2026-03-12T15:30:00+11:00
Date Updated: 2026-03-12T15:30:00+11:00
Agent: Claude Celadon Pangolin 1407
Type: tooling
Status: complete
Plan Reference: spectri/coordination/llm-plans/claude-plans/2026-03-12-doc-decomposition-pilot.md
Note: Research conducted during planning session to inform the two-layer vocabulary strategy ADR
---

# WhisperKit promptTokens Research

## Purpose

Investigate whether WhisperKit's `promptTokens` parameter can reliably bias transcription toward domain-specific vocabulary (brand names, proper nouns, technical terms), and whether it could replace or supplement the existing post-transcription dictionary replacement in Spectri Speak.

## Research Questions

1. Does WhisperKit support vocabulary priming via `promptTokens`? How does it work?
2. How effective is prompt-based vocabulary priming for domain-specific terms?
3. What are the practical limits (token budget, model size requirements)?
4. Are there known bugs or gotchas?
5. What is the current state of promptTokens wiring in the Spectri Speak codebase?

## Findings

### How promptTokens Works

WhisperKit supports vocabulary priming via `DecodingOptions.promptTokens`. This is the equivalent of OpenAI Whisper's `initial_prompt` parameter.

**Mechanism:**
1. Tokenize vocabulary/glossary text using WhisperKit's tokenizer
2. Filter out special tokens (keep only tokens below `specialTokenBegin`)
3. Pass the token array as `promptTokens` in `DecodingOptions`
4. Tokens are injected into the `<|startofprev|>` section of the decoder prompt

**Usage pattern** (from WhisperKit GitHub issue #127, confirmed by maintainer ZachNagengast):

```swift
let promptText = "Glossary: VBOUT, Claude Code, Holmgren, RetroSuburbia"
let promptTokens = tokenizer.encode(text: promptText)
    .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
let options = DecodingOptions(promptTokens: promptTokens)
let result = try await whisperKit.transcribe(audioPath: path, decodeOptions: options)
```

**Key limitation from the maintainer:** "This is not like an LLM prompt. It should purely be used as an example of the style and spelling of output you're looking for."

### Token Limit

**224 tokens maximum.** Longer prompts are silently truncated. This accommodates roughly 50-100 vocabulary terms depending on term length. For Spectri Speak's dictionary (target: 400+ entries from Wispr Flow migration), this means prioritising which terms to include — likely by category or frequency of misrecognition.

### Effectiveness: Academic Evidence

**Primary source:** arxiv 2406.05806 — "Do Prompts Really Prompt? Exploring the Prompt Understanding Capability of Whisper"

Key findings:
- Whisper has **limited understanding of textual prompts**
- Topic Following Rate: only **17.5%-38%** across datasets
- Mismatched topics sometimes **outperformed** matched ones by up to 11%
- No positive correlation found between prompt understanding and performance improvement
- English prompts outperform non-English prompts even on non-English data (training bias)

**What actually works** (OpenAI Cookbook guidance):
- Spelling of proper nouns: effective when names have ambiguous spellings (e.g., "Aimee" vs "Amy")
- Glossary format: listing target words works, but natural sentence context works better
- Style influence: punctuation style, capitalisation patterns carry through

**What does NOT work:**
- Direct instructions ("Format as markdown") — Whisper ignores these
- Overriding what the audio actually contains
- Short prompts — unreliable; longer examples establish patterns better
- Uncommon formatting — Whisper defaults to conventional transcript style

### Effectiveness: Domain-Specific Terms

**Source:** arxiv 2410.18363

- Simple prompting alone is **insufficient** for specialised vocabulary
- A Tree-Constrained Pointer Generator (TCPGen) approach achieved dramatically better results (WER from 27.82% to 11.12% on medium model)
- Fine-tuning actually performed **worse** than baseline for domain vocabulary
- Conclusion: explicit architectural biasing outperforms prompt-only approaches

### Known Bug: #372 — promptTokens + audioArray

WhisperKit issue #372 documented that `promptTokens` caused **empty transcription results** when used with `transcribe(audioArray:)`. The root cause: prompt tokens shifted the decoder KV cache state, causing the first content token's logprob to drop below `firstTokenLogProbThreshold` (-1.5), which aborted decoding.

**Status:** Fixed upstream by skipping the threshold check when `promptTokens` are set. Spectri Speak currently pins WhisperKit at `0.9.0` — needs upgrade to get this fix.

### Model Size vs Priming Effectiveness

| Model | Parameters | promptTokens Reliability |
|-------|-----------|--------------------------|
| tiny/tiny.en | 39M | Poor — inconsistent results |
| base/base.en | 74M | Poor — marginal improvement |
| small/small.en | 244M | Fair — works for some terms |
| medium/medium.en | 769M | Good — minimum for reliable priming |
| large-v3 | 1.55B | Best — most consistent recognition |
| large-v3-turbo | ~800M | Good — near-large accuracy, practical on all M-series Macs |

**Community consensus:** `medium` is the minimum for reliable proper noun recognition. `large-v3-turbo` or `large-v3` recommended for Spectri Speak since the Neural Engine handles them efficiently on Apple Silicon.

### Current State in Spectri Speak Codebase

The promptTokens plumbing is **already wired into the codebase** in `Sources/Services/WhisperTranscriber.swift`:

- **File-based transcription** (lines 179-181): `dictionaryHint` parameter is tokenized and passed as `promptTokens`. Working. Includes fallback — if promptTokens cause empty results, retries without them.
- **Streaming start** (lines 226-229): `dictionaryHint` tokenized and stored in `activeDecodeOptions`. Working for the initial streaming setup.
- **Streaming loop** (lines 325-331): **Deliberately disabled.** Comment reads: "promptTokens cause empty results with audioArray, so only set detectLanguage." This is the bug #372 workaround. The streaming loop uses a separate `streamingDecodeOptions` that omits promptTokens.
- **Final transcription on stop** (lines 453-456): Uses `activeDecodeOptions` (which includes promptTokens) via file-based transcription. Working.

**Work needed to fully enable:**
1. Upgrade WhisperKit past the #372 fix
2. Remove the streaming loop workaround — pass `activeDecodeOptions` into streaming transcription passes instead of the stripped-down `streamingDecodeOptions`
3. Test with problem terms (VBOUT, Claude Code, Holmgren, etc.)

## Analysis

### Implications for Spectri Speak

1. **promptTokens is available and partially wired** — the infrastructure exists, it just needs a WhisperKit version bump and one code change to fully enable it in streaming mode.

2. **Post-transcription dictionary replacement is fundamentally more reliable** than prompt-based priming for truly novel vocabulary. The academic evidence is clear: prompting alone cannot make Whisper reliably recognise words it hasn't been trained on.

3. **A hybrid approach is optimal:** Use `promptTokens` as "soft" hints (helps with spelling disambiguation), while keeping the phonetic dictionary replacement as the reliable fallback. This is additive, not either/or.

4. **The 224-token limit** means only ~50-100 terms can be primed per session. For large dictionaries (target: 400+), a prioritisation strategy is needed — possibly by misrecognition frequency or category weighting.

5. **Model size matters:** Priming effectiveness scales with model size. Users should be guided toward `large-v3-turbo` or `large-v3` for best results. Smaller models may see little benefit from priming.

### What This Means for the Two-Layer Strategy

The research validates the decision to use both layers:
- **Layer 1 (promptTokens)** reduces the frequency of misrecognitions, giving the model better odds of getting domain terms right on the first pass
- **Layer 2 (dictionary replacement)** catches everything the model misses, with configurable strictness to avoid the false positive problem that made the original dictionary unusable

Neither layer alone is sufficient. Together they provide reliable vocabulary recognition without cloud processing.

## Recommendations

1. **Adopt the hybrid two-layer approach** — document as an ADR
2. **Upgrade WhisperKit** to a version including the #372 fix before enabling promptTokens in streaming
3. **Build a dictionary hint builder** that selects the highest-priority terms within the 224-token budget
4. **Test empirically** with the known problem terms before relying on priming in production
5. **Default to large-v3-turbo** in user guidance for best priming results

## Sources

- WhisperKit GitHub issue #127 — promptTokens usage pattern and maintainer guidance
- WhisperKit GitHub issue #372 — empty results bug with promptTokens + audioArray
- arxiv 2406.05806 — "Do Prompts Really Prompt? Exploring the Prompt Understanding Capability of Whisper"
- arxiv 2410.18363 — Domain-specific vocabulary recognition approaches
- OpenAI Cookbook — Whisper prompting best practices
- WhisperKit GitHub Discussion #250 — WhisperKit vs whisper.cpp comparison
- Spectri Speak codebase: `Sources/Services/WhisperTranscriber.swift` — current promptTokens wiring

## Related

- ADR (pending): Two-layer vocabulary recognition strategy
- Spec (pending): Prompt token priming feature (P2 in initial plan)
- `docs/initial-plan.md`: Original monolithic plan containing the strategy section this research informs
