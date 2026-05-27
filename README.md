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

## Contribute

The registry is a content repo: a `registry.json` manifest plus one folder per skill under `skills/`. Contributions land via PR.

### Prerequisites

```bash
npm install -g forgent     # provides validate-registry, hash-files, validate-skill, verify
```

CI runs `forgent validate-registry` on every PR (see [`.github/workflows/validate-registry.yml`](./.github/workflows/validate-registry.yml)). Run the same command locally to fail-fast before pushing.

### Add a new skill

1. **Fork & clone** `PrincyExaltIT/agent-skill`, then create a branch:
   ```bash
   git checkout -b feat/<your-skill>
   ```

2. **Scaffold the skill folder** at `skills/<your-skill>/`:
   ```
   skills/<your-skill>/
   ├─ SKILL.md                       required — Claude entry point
   ├─ ORCHESTRATION.md               required — provider-agnostic logic (single source of truth)
   ├─ <your-skill>.prompt.md         optional — Copilot variant
   ├─ <your-skill>.codex.md          optional — Codex variant
   ├─ references/                    optional — rules/docs the skill reads
   ├─ templates/                     optional — output templates (e.g. REPORT.md)
   └─ examples/                      optional — sample inputs/outputs
   ```

   `SKILL.md` needs Claude-style frontmatter:
   ```yaml
   ---
   name: <your-skill>
   description: One sentence describing when to invoke this skill. Claude reads this to decide whether the skill applies.
   ---

   # Skill body — markdown
   ```

   The simplest way to start is to copy [`skills/angular-review/`](./skills/angular-review/) and edit.

3. **Register the skill** in [`registry.json`](./registry.json) by appending an entry to `items`:
   ```json
   {
     "name": "<your-skill>",
     "version": "0.1.0",
     "description": "Same trigger sentence as SKILL.md, or a richer version.",
     "tags": ["tag1", "tag2"],
     "files": [
       { "path": "SKILL.md", "type": "skill:main", "sha256": "..." },
       { "path": "ORCHESTRATION.md", "type": "skill:doc", "sha256": "..." }
     ]
   }
   ```

   Bump the top-level `version` in `registry.json` too (semver). Allowed `files[].type` values: `skill:main`, `skill:doc`, `skill:copilot`, `skill:codex`, `skill:reference`, `skill:template`, `skill:example`. Full schema: [`forgent`'s manifest shape](https://github.com/PrincyExaltIT/forgent#manifest-shape).

4. **Compute SHA256 hashes** — `forgent` reads `registry.json`, computes hashes for every declared file, and reports mismatches:
   ```bash
   forgent hash-files --registry .
   ```
   Paste the correct hashes into your `registry.json` entry.

5. **Validate locally** — same checks CI runs:
   ```bash
   forgent validate-registry --registry .
   ```
   If your skill ships JSON examples with a `$schema` field, also run:
   ```bash
   forgent validate-skill <your-skill> --registry .
   ```

6. **Smoke-test end-to-end** by installing your skill from the local registry into a throwaway location:
   ```bash
   forgent add --provider claude --registry . --dest /tmp/test-install <your-skill>
   forgent verify --provider claude --dest /tmp/test-install
   ```
   `verify` re-hashes every installed file against the lockfile — confirms your manifest hashes match the actual file content.

7. **Commit and open a PR** — [Conventional Commits](https://www.conventionalcommits.org/):
   ```bash
   git add skills/<your-skill>/ registry.json
   git commit -m "feat(skills): add <your-skill>"
   git push origin feat/<your-skill>
   ```
   Open the PR against `PrincyExaltIT/agent-skill:main`. CI must be green to merge.

### Modify an existing skill

Same flow, fewer steps:

1. Branch: `git checkout -b fix/<skill>-<what-changed>` (or `feat/...` for new behaviour).
2. Edit files under `skills/<name>/`.
3. **Bump versions** in `registry.json`:
   - the affected `items[].version` (semver — patch for fixes, minor for additive, major for breaking).
   - the top-level `version`.
4. Re-run **`forgent hash-files --registry .`** — paste the new SHA256s for every file you touched.
5. Re-run **`forgent validate-registry --registry .`**.
6. Smoke-test as in step 6 above.
7. Commit and PR.

Forgetting to bump SHA256s after editing a file is the most common review nit — `forgent hash-files` catches it.

### Tips

- The `$schema` field at the top of `registry.json` enables JSON-schema autocomplete and inline validation in VS Code / IntelliJ — keep it.
- Provider variants (`<name>.prompt.md`, `<name>.codex.md`) are optional. If absent, `forgent` installs `SKILL.md` for every provider; you adjust the frontmatter post-install (see [forgent's caveats](https://github.com/PrincyExaltIT/forgent#caveat-frontmatter)).
- `forgent doctor` diagnoses common config issues if `add`/`verify` behave unexpectedly during your smoke test.

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
