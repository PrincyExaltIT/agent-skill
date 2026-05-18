---
name: angular-review
description: Multi-reviewer Angular code audit (security, architecture, performance, a11y/errors, optional project-compliance) on the current branch or a specified diff, with optional empirical DOM validation via the Playwright MCP server. Invoke with /angular-review (optionally followed by a target: "PR <num>", "<branch>", "staged", or a commit range).
---

# Skill — angular-review (Claude Code entry point)

The full orchestration lives in **[`ORCHESTRATION.md`](./ORCHESTRATION.md)** — a provider-agnostic document also used by GitHub Copilot and OpenAI Codex versions of this skill.

## What to do when invoked

1. **Read** `.claude/skills/angular-review/ORCHESTRATION.md` (or whatever path this skill is installed under).
2. **Follow** all 6 steps exactly as written there.
3. **Use Claude-native capabilities**:
   - `Agent` tool for parallel reviewer sub-agents (Step 3) — emit one message with N parallel calls.
   - `Bash` tool for git operations and dev-server launch.
   - `Read` / `Glob` / `Grep` tools for file inspection.
   - `Write` tool only for the report file under `reports/` and Playwright artefacts.
   - `mcp__playwright__*` tools if the Playwright MCP server is registered (Step 6).
4. **Pass any user argument** ("PR 42", "staged", "feature/foo", "abc..def") as the target for Step 1.

## Notes specific to Claude Code

- This file's frontmatter (`name`, `description`) is what makes the skill discoverable via `/angular-review`.
- Parallel sub-agent calls are a Claude-native feature — use them; this is the main speed-up vs. other providers.
- `subagent_type: general-purpose` for each reviewer call.

For installation, MCP registration, and the rationale behind each step, see the repo `README.md`.
