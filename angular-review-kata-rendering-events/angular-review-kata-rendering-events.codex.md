# Prompt — angular-review-kata-rendering-events (OpenAI Codex entry point)

> Install this file as `~/.codex/prompts/angular-review-kata-rendering-events.md` (user-global slash command) or `.codex/prompts/angular-review-kata-rendering-events.md` (project-local). After install, invoke with `/angular-review-kata-rendering-events [target]` in `codex` CLI.

The full orchestration lives in **`ORCHESTRATION.md`** in the skill bundle — a provider-agnostic document also used by the Claude Code and GitHub Copilot versions of this skill.

This is the **kata-specific variant** of `angular-review`: the only difference vs the general skill is that `references/PROJECT_COMPLIANCE_REVIEW.md` ships pre-filled with the 13 R-KATA rules derived from the « Rendering Events » brief. Everything else is identical.

## What to do when invoked

1. **Read** the `ORCHESTRATION.md` file from the skill bundle. The bundle is typically at `~/.codex/agent-skills/angular-review-kata-rendering-events/` (user-global) or `.codex/agent-skills/angular-review-kata-rendering-events/` (project-local). If you don't know the path, ask the user.
2. **Follow** all 6 steps exactly as written there.
3. **Use Codex-native capabilities**:
   - For Step 3 (multiple reviewers), use **Codex's native subagents feature** — `Codex can run subagent workflows by spawning specialized agents in parallel and then collecting their results in one response.` Spawn one subagent per reviewer; Codex orchestrates routing, waiting, and thread closure for you. See <https://developers.openai.com/codex/subagents>.
   - Use the shell tool for git operations and dev-server launch.
   - Use the apply-patch / write-file tool **only** for the report file under `<skill-root>/reports/` and Playwright artefacts.
   - For Step 6, use the `mcp_playwright_*` tools if the Playwright MCP server is registered in `~/.codex/config.toml`.
4. **Pass the user argument** as the target for Step 1 (`$ARGUMENTS` or `$1` depending on Codex version).

## Notes specific to OpenAI Codex CLI

- Codex's `AGENTS.md` mechanism is **complementary** to this slash command. If you want the skill rules to apply implicitly to every chat in the project, copy the `ORCHESTRATION.md` content (or summary) into the project `AGENTS.md`. Otherwise, keep it as a slash-command-only skill.
- MCP servers register in `~/.codex/config.toml` under `[mcp_servers.<name>]`.
- For Step 6, the Playwright MCP server tool names are typically `mcp_playwright_browser_navigate`, `mcp_playwright_browser_snapshot`, etc.
- The kata-compliance reviewer (prefix `R-KATA`) auto-activates because `references/PROJECT_COMPLIANCE_REVIEW.md` ships pre-filled. A single `R-KATA BLOCKER` flips the verdict to `REQUEST_CHANGES`.

## Input

The user may pass a target as the argument: `PR <num>`, `<branch>`, `staged`, `<range>` (e.g. `abc..def`), or empty (defaults to `main...HEAD`).

For installation, MCP registration, and the rationale behind each step, see the repo `README.md`.
