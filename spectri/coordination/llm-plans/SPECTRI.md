# [LLM-PLANS/] LLM PLANS
<!-- target: spectri/coordination/llm-plans/ -->

When user asks to add a Claude plan to this repo:

1. **Copy** plan from `~/.claude/plans/[session-name].md` to `spectri/coordination/llm-plans/claude-plans/[new-name].md`
2. **Filename:** `YYYY-MM-DD-[slug].md` (ask user for slug if unclear)
3. **Replace frontmatter** with:
```yaml
---
Date Created: YYYY-MM-DDTHH:MM:SSZ
Date Updated: YYYY-MM-DDTHH:MM:SSZ
Title: [Plan Title]
Original: ~/.claude/plans/[session-name].md
Source: spectri/coordination/prompts/[prompt-file].md
Workstream: [N] of [Total] ([Series Name])
Reviewed By: [N] sub-agents ([review types])
---
```
**Timestamps:** Use `~/.local/bin/print-melbourne-timestamp` and convert to UTC (Z format)
4. **Body:** Exact copy of original plan (everything after original frontmatter)

Original plan in `~/.claude/plans/` stays unchanged.

## Prompts Folder

Prompts for agents live in `spectri/coordination/prompts/`. When referencing prompts in plan frontmatter, use relative path from memory root.
