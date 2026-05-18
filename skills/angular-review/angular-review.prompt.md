---
mode: agent
description: Multi-reviewer Angular code audit (security, architecture, performance, a11y/errors, optional project-compliance) on the current branch or a specified diff, with optional empirical DOM validation via the Playwright MCP server.
tools: ['codebase', 'editFiles', 'runCommands', 'search', 'usages', 'findTestFiles', 'githubRepo']
---

# Prompt — angular-review (GitHub Copilot entry point)

The full orchestration lives in **`ORCHESTRATION.md`** alongside this file — a provider-agnostic document also used by the Claude Code and OpenAI Codex versions of this skill.

## What to do when invoked

1. **Read** the `ORCHESTRATION.md` file that ships with this prompt (same folder where this prompt is installed, or under the `.github/agent-skills/angular-review/` workspace folder if installed there).
2. **Follow** all 6 steps exactly as written there.
3. **Use Copilot-native capabilities**:
   - For Step 3 (multiple reviewers), use **parallel `runSubagent` calls** — Copilot's agent mode dispatches independent `runSubagent` tasks in parallel since the Jan 2026 update. If you're in Copilot CLI, the `/fleet` slash command does the same. Fall back to sequential only if your Copilot tier doesn't expose `runSubagent`.
   - Use the available tools (`runCommands` for git/dev-server, `editFiles` for the report file only, `search`/`codebase` for diff inspection).
   - For Step 6, use the `#playwright` MCP tools if the Playwright MCP server is registered in `.vscode/mcp.json` or VS Code settings.
4. **Pass the user's argument** (`#input:target`) as the target for Step 1. If empty, default to `git diff main...HEAD`.

## Notes specific to GitHub Copilot

- Tool whitelist in frontmatter must include shell + file-read + file-write. Adjust to your Copilot tier's available tools if some aren't surfaced.
- For agent-mode invocation, ask the user to run `/angular-review` in Copilot Chat (with this file installed under `.github/prompts/angular-review.prompt.md`).
- Project-wide always-on instructions can go in `.github/copilot-instructions.md` if you want the skill rules to apply implicitly without an explicit `/angular-review` invocation.
- Sub-agent parallelism is supported in agent mode since Jan 2026 (and via `/fleet` in Copilot CLI). If your tier doesn't expose `runSubagent`, fall back to sequential review — same findings, slower wall-clock.

For installation, MCP registration, and the rationale behind each step, see the repo `README.md`.

## Input

The user may pass a target as the argument: `PR <num>`, `<branch>`, `staged`, `<range>` (e.g. `abc..def`), or empty (defaults to `main...HEAD`).
