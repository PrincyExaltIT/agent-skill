---
name: angular-review-kata-rendering-events
description: Variante de l'audit `angular-review` pré-câblée pour le kata « Rendering Events » — embarque les règles R-KATA-001..013 (RFC2119 du brief : positionnement temps→pixels, chevauchement, responsivité). Sinon, identique à `angular-review` (security, architecture, performance, a11y/errors + validation DOM via Playwright MCP). Invoke with /angular-review-kata-rendering-events (optionally followed by a target: "PR <num>", "<branch>", "staged", or a commit range).
---

# Skill — angular-review-kata-rendering-events (Claude Code entry point)

The full orchestration lives in **[`ORCHESTRATION.md`](./ORCHESTRATION.md)** — a provider-agnostic document also used by GitHub Copilot and OpenAI Codex versions of this skill.

This is the **kata-specific variant** of `angular-review`: the only difference vs the general skill is that `references/PROJECT_COMPLIANCE_REVIEW.md` is pre-filled with the 13 R-KATA rules derived from the « Rendering Events » brief (`README.md` du kata). Everything else (security, architecture, performance, a11y/errors reviewers, report template, Playwright validation step) is identical.

## What to do when invoked

1. **Read** `.claude/skills/angular-review-kata-rendering-events/ORCHESTRATION.md` (or whatever path this skill is installed under).
2. **Follow** all 6 steps exactly as written there.
3. **Use Claude-native capabilities**:
   - `Agent` tool for parallel reviewer sub-agents (Step 3) — emit one message with N parallel calls.
   - `Bash` tool for git operations and dev-server launch.
   - `Read` / `Glob` / `Grep` tools for file inspection.
   - `Write` tool only for the report file under `reports/` and Playwright artefacts.
   - `mcp__playwright__*` tools if the Playwright MCP server is registered (Step 6).
4. **Pass any user argument** ("PR 42", "staged", "feature/foo", "abc..def") as the target for Step 1.

## Notes specific to Claude Code

- This file's frontmatter (`name`, `description`) is what makes the skill discoverable via `/angular-review-kata-rendering-events`.
- Parallel sub-agent calls are a Claude-native feature — use them; this is the main speed-up vs. other providers.
- `subagent_type: general-purpose` for each reviewer call.
- The kata-compliance reviewer (prefix `R-KATA`) auto-activates because `references/PROJECT_COMPLIANCE_REVIEW.md` ships pre-filled. A single `R-KATA BLOCKER` flips the verdict to `REQUEST_CHANGES`.

For installation, MCP registration, and the rationale behind each step, see the repo `README.md`.
