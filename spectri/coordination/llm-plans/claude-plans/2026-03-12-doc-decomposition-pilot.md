---
Date Created: 2026-03-12T04:29:00Z
Date Updated: 2026-03-12T04:50:00Z
Title: Documentation Decomposition Pilot
Original: direct
Source: conversation — Celadon Pangolin 1407
Workstream: 1 of 1 (Documentation Decomposition)
Reviewed By: 3 models (claude subagent plan-review, qwen3-coder-plus neutral, mercury devil's-advocate)
---

# Documentation Decomposition Pilot

## Context

Spectri Speak has a single planning document (`docs/initial-plan.md`) that contains architecture decisions, research findings, feature descriptions, project context, and implementation sequencing. This monolithic structure served well during early planning but now needs to decompose into Spectri artefact types so individual features can move through the spec lifecycle independently.

The decomposition was reviewed by two external models. Both endorsed the approach; the devil's-advocate review flagged discoverability cost and link-drift as the main practical risks for a project of this size.

To mitigate those risks, this plan uses a **pilot approach**: decompose the foundational artefacts first (ADR, research doc, ROADMAP), then create one feature spec and evaluate whether the structure works before scaling to all 9+ features.

### What exists now

- `docs/initial-plan.md` — monolithic plan containing everything
- `AGENTS.md` — project onboarding context (already has fork rationale and caveats)
- `spectri/` — Spectri framework installed but no specs, ADRs, or research docs yet

### What this plan produces

- `ROADMAP.md` — spec sequencing with rationale
- ADR for the two-layer vocabulary strategy
- Research doc for WhisperKit promptTokens findings
- Updated `AGENTS.md` with technical notes migrated from initial plan
- One pilot spec (alias-only mode) created via `/spec.specify`
- Evaluation of whether the decomposition works before scaling

## Scope Boundaries

This plan covers **documentation structure only** — no code changes, no feature implementation. The pilot spec will be authored but not implemented.

**Not in scope:**
- Creating all 9 feature specs (deferred pending pilot evaluation)
- Implementing any features
- Modifying Spectri framework artefact types or scripts
- Deleting `docs/initial-plan.md` (preserved as reference until decomposition is validated)

## Confirmed Decisions

1. **Pilot before scaling** — create foundational artefacts + one spec, evaluate, then decide whether to create the remaining specs in this structure
2. **initial-plan.md preserved** — not deleted until the decomposition is confirmed working. Serves as reference and rollback point.
3. **ROADMAP.md at project root** — per project conventions, not inside `spectri/` or `docs/`
4. **Quick-add dictionary feature included** — a new feature not in the original initial-plan.md. Concept: a fast UX path (hotkey, menu bar shortcut, or right-click on misrecognised text) to add a word to the dictionary during active use, without opening the full dictionary settings. Positioned in the roadmap after alias-only mode since it depends on working exact-match replacement. This is distinct from P4.2 (CLI interface) which is for programmatic/terminal access.

## Phase 1: Foundational Artefacts

### Step 1: Create ROADMAP.md

Create `ROADMAP.md` at the project root containing the spec sequence with rationale for ordering. Content sourced from the "Planned Changes" and priority ordering in `docs/initial-plan.md`.

The roadmap should include:
- Ordered list of planned specs with short descriptions
- Rationale for the sequencing (why alias-only mode first, etc.)
- The quick-add dictionary feature in its proper position
- A migration note explaining that this content was extracted from `docs/initial-plan.md`
- Links to specs as they are created (initially empty/placeholder)

**COMMIT**: Stage `ROADMAP.md` and commit.

### Step 2: Create ADR for two-layer vocabulary strategy

Use `/spec.adr` to create an ADR in `spectri/adr/` documenting the decision to use both pre-transcription priming (WhisperKit promptTokens) and post-transcription dictionary replacement.

Content sourced from the "Strategy: Two-Layer Vocabulary Recognition" section and "Considered and Rejected" section in `docs/initial-plan.md`.

The ADR should capture:
- The decision and its context
- Alternatives considered: promptText-only, dictionary-only, ground-up rewrite
- Why each alternative was rejected (with evidence — the academic research, the false positive experience)
- Consequences of the decision

**COMMIT**: Stage ADR and commit.

### Step 3: Create research doc for WhisperKit promptTokens

**PRE-COMPLETED**: This step was completed during the planning session by Claude Celadon Pangolin 1407. The research doc exists at `spectri/research/2026-03-12-whisperkit-prompttokens-research.md` and contains findings from web searches, academic papers, and WhisperKit GitHub issues gathered during the session that produced this plan.

The research doc covers:
- How promptTokens works (tokenize → filter specials → pass as DecodingOptions)
- The 224-token limit and its practical implications
- Academic findings on effectiveness (arxiv 2406.05806 — 17-38% topic following rate)
- The known bug (#372) and its fix status
- Model size vs priming effectiveness tradeoffs
- Practical recommendations for Spectri Speak's dictionary size
- Current state of promptTokens wiring in the Spectri Speak codebase

**COMMIT**: Already committed with the plan.

### Step 4: Update AGENTS.md with technical context

Migrate and reconcile content from `docs/initial-plan.md` into `AGENTS.md`. Specific actions:

- **Fix stale reference**: AGENTS.md currently references `docs/plan.md` — update to `docs/initial-plan.md`
- **Migrate key files list**: The expanded key files table from initial-plan.md (PhoneticMatcher, DictionaryProcessor, WhisperTranscriber, DictationController, etc.) should update the existing "Key Files" section in AGENTS.md
- **Migrate "Previous Dictation Setup" context**: The Wispr Flow migration details (411 entries, 71 imported, exact-match vs phonetic matching comparison) belong in AGENTS.md as onboarding context
- **Reconcile "Not Changing" section**: AGENTS.md already has "What We're Not Changing" — update it to match the revised version in initial-plan.md
- **Add links to new artefacts**: Reference the ADR and research doc by relative path (e.g., `spectri/adr/...` and `spectri/research/...`) rather than inlining their content
- **Do not duplicate**: Architecture decision rationale stays in the ADR. Research data stays in the research doc. AGENTS.md links to them.

**COMMIT**: Stage `AGENTS.md` and commit.

## Phase 2: Pilot Spec

### Step 5: Create pilot spec — alias-only mode

Use `/spec.specify` to create spec for alias-only mode (was P1.3 in the initial plan). This is the highest-value, lowest-complexity feature — a global toggle that disables phonetic matching entirely, giving Wispr Flow-style exact-match behaviour.

Starting-point feature description (to be refined through the `/spec.specify` interactive workflow, not pasted verbatim): a global toggle in dictionary settings that disables all phonetic matching, so dictionary entries only trigger on exact alias matches. Aimed at users migrating from Wispr Flow who expect exact-match behaviour. Eliminates false positives for users who prefer precision over fuzzy matching.

Follow the `/spec.specify` interactive workflow. The spec goes into `spectri/specs/` with proper numbering.

**COMMIT**: Stage spec folder and commit.

## Phase 3: Evaluate

### Step 6: Evaluate the pilot

Review the decomposed structure with the user:
- Can an agent starting fresh find what it needs from AGENTS.md alone?
- Does the ADR stand on its own without needing to read the initial plan?
- Does the research doc provide enough context for the promptTokens spec when it's created later?
- Does the pilot spec reference the ADR and research doc cleanly?
- Is the overhead acceptable or burdensome?

Based on the evaluation, decide whether to:
- Scale the approach to remaining specs
- Adjust the structure before creating more specs
- Simplify by collapsing some artefacts

## Verification

1. `ROADMAP.md` exists at project root with ordered spec list and sequencing rationale
2. ADR exists in `spectri/adr/` documenting the two-layer vocabulary strategy with alternatives considered
3. Research doc exists in `spectri/research/` with WhisperKit promptTokens findings
4. `AGENTS.md` contains updated technical context without duplicating ADR or research content
5. One spec (alias-only mode) exists in `spectri/specs/` created via `/spec.specify`
6. `docs/initial-plan.md` still exists as reference
7. User has evaluated the structure and confirmed whether to scale or adjust

## Execution Log

### Claude Celadon Pangolin 1407 — Step 3 (pre-completed) — 2026-03-12

Research doc created at `spectri/research/2026-03-12-whisperkit-prompttokens-research.md` during the planning session. Content sourced from web searches (WhisperKit GitHub issues #127, #372, argmaxinc docs), academic paper (arxiv 2406.05806), and codebase exploration of `Sources/Services/WhisperTranscriber.swift`. Plan also updated with three fixes from 3-model review: (1) quick-add feature definition added to Confirmed Decisions, (2) Step 4 expanded with specific migration actions, (3) Step 5 feature description marked as starting-point not verbatim.
