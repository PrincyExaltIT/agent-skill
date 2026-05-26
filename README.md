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
| [`angular-review`](./skills/angular-review) | `/angular-review` | Multi-reviewer Angular code audit (security, architecture, performance, a11y/errors, optional project-compliance) using guidelines compiled from angular.dev. Ships with an **empty** `PROJECT_COMPLIANCE_REVIEW.md` template — fill it in to encode your R-PROJ rules. Read-only — produces a markdown report, never modifies code. |
| [`angular-review-kata-rendering-events`](./skills/angular-review-kata-rendering-events) | `/angular-review-kata-rendering-events` | Variant of `angular-review` **pre-filled** with the 13 R-KATA rules of the « Rendering Events » kata (RFC2119 constraints: time→pixel positioning, overlap, responsivity). Auto-enables Step 6 Playwright MCP validation. |

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

The next invocation auto-detects your rules and runs an extra `project-compliance-reviewer` sub-agent emitting `R-PROJ-NNN` findings. A single R-PROJ BLOCKER ⇒ `REQUEST_CHANGES`.

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

Manifest shape is documented in [`forgent`'s README](https://github.com/PrincyExaltIT/forgent#manifest-shape).

## Capability matrix per provider

| Step | Claude Code | GitHub Copilot | OpenAI Codex |
|---|---|---|---|
| 1. Read git diff | `Bash` | `runCommands` | shell |
| 2. Glob references | `Glob` | `search`/`codebase` | shell/builtin |
| 3. Run reviewers in parallel | ✅ `Agent` × N | ✅ `runSubagent` / `/fleet` | ✅ native `subagents` |
| 4. Aggregate findings | inline | inline | inline |
| 5. Write report | `Write` | `editFiles` | apply-patch |
| 6. Playwright MCP | `mcp__playwright__*` | `#playwright` | `mcp_playwright_*` |

## License

[MIT](./LICENSE)
