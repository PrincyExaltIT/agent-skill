# agent-skill

> The default registry for [forgent](https://github.com/PrincyExaltIT/forgent) — provider-agnostic AI agent skills that run on Claude Code, GitHub Copilot, OpenAI Codex CLI, and Cursor.

## Install skills

```bash
npx forgent add --provider claude angular-review
# or: --provider copilot | codex | cursor
```

Then, in your AI agent, invoke `/angular-review`. See [`forgent`'s README](https://github.com/PrincyExaltIT/forgent#readme) for flags, `forgent.config.json`, and global install (`npm i -g forgent`).

## Available skills

| Skill | Invoke with | What it does |
|---|---|---|
| [`angular-review`](./skills/angular-review) | `/angular-review` | Multi-reviewer Angular code audit (security, architecture, performance, a11y/errors, optional project-compliance) using guidelines compiled from angular.dev. Ships with an **empty** `PROJECT_COMPLIANCE_REVIEW.md` template — fill it in to encode your project rules under any `rule_prefix` (default `R-PROJ`; the orchestration reads the frontmatter dynamically). Optional Step 6 Playwright MCP DOM validation. Read-only — produces a markdown report, never modifies code. |
| [`angular-review-kata-rendering-events`](./skills/angular-review-kata-rendering-events) | `/angular-review-kata-rendering-events` | **Evidence-based** variant of `angular-review` pre-wired for the « Rendering Events » kata: 13 `R-KATA` rules (RFC2119 constraints: time→pixel positioning, overlap, responsivity) + a `KATA_LAYOUT_ORACLE.md` (formulas, tolerances, DOM measurement procedure, adversarial test patterns). Verdict driven **only** by R-KATA findings; non-R-KATA reviewers contribute to a separate « Hygiène prod » section without blocking the kata verdict. Step 6 Playwright DOM validation is mandatory for `APPROVE`. |

Each skill ships with one provider-agnostic `ORCHESTRATION.md` (single source of truth), thin per-provider entry-point files (`SKILL.md`, `<skill>.prompt.md`, `<skill>.codex.md`), and shared assets (rules, templates, examples).

> ✏️ **Choosing between the two**: install `angular-review` if you have your own constraints to encode (or none at all). Install `angular-review-kata-rendering-events` if you're submitting the « Rendering Events » kata and want the rules pre-loaded — no template editing.

## How angular-review works

Invoke from your AI agent:

```
/angular-review                  # diff main…HEAD
/angular-review staged           # staged diff only
/angular-review PR 42            # GitHub PR
/angular-review feature/foo      # a specific branch
/angular-review abc..def         # a commit range
```

The agent will:
1. Compute the diff.
2. Run reviewers in parallel — security (R-SEC), architecture (R-ARCH), performance (R-PERF), a11y/errors (R-A11Y / R-ERR), and project-compliance (R-PROJ) if you filled in the template.
3. Aggregate findings into a markdown report under `<skill>/reports/review-<timestamp>.md`.
4. *(Optional Step 6)* If the Playwright MCP server is registered, validate the rendered DOM in a real browser — positioning, accessibility, responsive behaviour.

## Customise for your project (R-PROJ)

`angular-review` ships with an empty `references/PROJECT_COMPLIANCE_REVIEW.md` template. Fill it with your project's constraints (kata, internal RFC, API contract, UX charter):

1. Edit `<install-path>/angular-review/references/PROJECT_COMPLIANCE_REVIEW.md`.
2. Add at least one rule under « Règles à vérifier ». Use the template format in the file.
3. *(Optional)* Adjust the `applies_to` glob and `rule_prefix` in the frontmatter.

The next invocation auto-detects your rules and runs an extra `project-compliance-reviewer` sub-agent emitting `<rule_prefix>-NNN` findings (default `R-PROJ`). A single BLOCKER under the configured `rule_prefix` ⇒ `REQUEST_CHANGES`.

> 💡 The [`angular-review-kata-rendering-events`](./skills/angular-review-kata-rendering-events) skill is this pattern applied: 13 R-KATA rules encoded from a kata brief's RFC2119 constraints. Read its `references/PROJECT_COMPLIANCE_REVIEW.md` for a concrete example of severity, flag patterns, and ❌/✅ examples.

## Security / privacy

**Privacy model:**
- The skill itself makes no outbound network calls beyond `gh pr diff` (GitHub API) and local MCP server calls.
- The AI runtime that executes the skill (Claude Code, GitHub Copilot, OpenAI Codex CLI, Cursor) **does** send context to its provider according to that runtime's data policy — this is outside the skill's control.
- Do not run this skill on confidential code without your organisation's AI usage policy validated for the chosen runtime.

**Guardrails the skill enforces on the AI runtime:**
- Source code is **read-only** — no edits or commits. Only allowed writes: the markdown report under `<skill-root>/reports/` and Playwright artefacts under `playwright-report/`.
- **No auto-fix** — findings only.

## Optional: Playwright MCP

Step 6 of `angular-review` validates findings against the live DOM (positioning, a11y, resize behaviour) using the [Playwright MCP server](https://github.com/microsoft/playwright-mcp). The step is opt-in — if the MCP server isn't registered, it's silently skipped. The kata variant auto-enables it (Step 6 is integral to kata grading).

Register the server once per provider:

```bash
# Claude Code
claude mcp add playwright -- npx -y @playwright/mcp@latest
```

For Copilot (`.vscode/mcp.json`), Codex (`~/.codex/config.toml`), or project-local `.mcp.json`, see the [Playwright MCP docs](https://github.com/microsoft/playwright-mcp#configuration).

## Author a new skill

1. Add `skills/<your-skill>/` containing `SKILL.md` (Claude), `<your-skill>.prompt.md` (Copilot), `<your-skill>.codex.md` (Codex), plus `ORCHESTRATION.md` and any references/templates/examples.
2. Append an entry to `registry.json` with the file manifest.
3. Open a PR.

Manifest shape is documented in [`forgent`'s README](https://github.com/PrincyExaltIT/forgent#manifest-shape). This registry follows the [forgent registry schema](https://raw.githubusercontent.com/PrincyExaltIT/forgent/main/schema/registry.schema.json). The current version of this registry is declared in [`registry.json`](./registry.json).

## Capability matrix per provider

| Step | Claude Code | GitHub Copilot | OpenAI Codex | Cursor | Status |
|---|---|---|---|---|---|
| 1. Read git diff | `Bash` | `runCommands` | shell | Composer terminal | stable ✓ |
| 2. Glob references | `Glob` | `search`/`codebase` | shell/builtin | `@` refs / grep | stable ✓ |
| 3. Run reviewers in parallel | ✅ `Agent` × N | ✅ `runSubagent`¹ / `/fleet` | ✅ native `subagents` | ⚠ sequential fallback² | partial ⊘ |
| 4. Aggregate findings | inline | inline | inline | inline | stable ✓ |
| 5. Write report | `Write` | `editFiles` | apply-patch | Composer write | stable ✓ |
| 6. Playwright MCP | `mcp__playwright__*` | `#playwright` | `mcp_playwright_*` | `.cursor/mcp.json` | optional ◌ |

¹ Available in GitHub Copilot Chat since the Jan 2026 update (`runSubagent` API / `/fleet` slash command in Copilot CLI).
² Cursor has no native parallel sub-agent dispatch — the orchestrator runs reviewers sequentially in one Composer session; wall-clock is N× longer, findings are identical.

> **Status legend** — ✓ stable: behaves consistently across all four providers · ⊘ partial: one provider needs a documented fallback · ◌ optional: silently skipped when the MCP server isn't registered. **Capability snapshot as of 2026-05** — runtime tooling evolves; verify against your provider's current docs.

**Provider tooling references:**
- Claude Code: <https://docs.claude.com/en/docs/claude-code>
- GitHub Copilot Chat (subagents): <https://docs.github.com/copilot>
- OpenAI Codex CLI: <https://github.com/openai/codex>
- Cursor (Composer / MCP): <https://docs.cursor.com>

## License

[MIT](./LICENSE)
