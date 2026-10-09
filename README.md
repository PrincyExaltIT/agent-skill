# agent-skill

> The default registry for [forgent](https://github.com/PrincyExaltIT/forgent) — AI agent skills that follow the [Agent Skills](https://agentskills.io) standard and run in any harness that reads it: Claude Code, OpenAI Codex, GitHub Copilot, Cursor, Gemini CLI, OpenCode, Kilo Code, and many others.

## Install skills

`angular-review` 2.x is a **folder skill**: `SKILL.md`, its rules, and the Node scripts it runs travel together. Install the whole folder.

**For the whole team** — in the project, for every harness (needs forgent ≥ 1.1):

```bash
npx forgent add --provider agents,claude --project angular-review
# .agents/skills: Codex, GitHub Copilot, Cursor, Gemini CLI, OpenCode, Kilo Code, your team's own tool…
# .claude/skills: Claude Code, Continue

# the whole review package: review, fix, hand-off, and the skill authoring kit
npx forgent add --provider agents,claude --project angular-review review-fix pr-handoff skill-smith
```

Commit both folders and `forgent.lock.json`; `npx forgent verify` (in CI too) checks that nobody changed the installed files.

**Just for you**: `npx forgent add --provider claude angular-review` (`~/.claude/skills`) or `--provider agents --user` (`~/.agents/skills`).

forgent's `copilot`, `codex` and `cursor` providers write a single file, which drops the scripts: avoid them for this skill (forgent warns you).

Requirements: git and Node.js 18+ (the scripts have no dependencies). Then ask your agent to review, or invoke the skill by name: `/angular-review` (Claude Code, Copilot, Cursor…), `$angular-review` (Codex).

See [`forgent`'s README](https://github.com/PrincyExaltIT/forgent#readme) for flags, `forgent.config.json`, `forgent verify` and global install (`npm i -g forgent`).

## Available skills

| Skill | Version | What it does |
|---|---|---|
| [`angular-review`](./skills/angular-review) | 2.1.0 | Review of Angular changes (17 to 22) — a branch, a PR/MR, staged files or a commit range. Scripts scope the diff, scan it (44 mechanical detectors) and compute the verdict; domain reviewers (security, architecture, performance, reactivity, tests, accessibility and errors, plus your project rules) judge the rest, then every finding is verified before it is kept. Output: `.review/REVIEW.md` (French) and `.review/findings.json` (+ SARIF) for follow-up skills and CI. Read-only. |
| [`review-fix`](./skills/review-fix) | 1.0.0 | Applies the findings of `.review/findings.json` one at a time, with build and tests after each, one commit per finding; stops on red. Invoke it by hand after `angular-review`. |
| [`pr-handoff`](./skills/pr-handoff) | 1.0.0 | Writes the PR/MR description and a hand-off note from the commits and the review. Manual invocation (`disable-model-invocation`, honoured by Claude Code, Cursor and Copilot; Codex: `agents/openai.yaml`). |
| [`skill-smith`](./skills/skill-smith) | 1.0.0 | Creates and validates Agent Skills: `new-skill.mjs` scaffolds a folder, `validate.mjs` checks it against the standard. |
| [`angular-review-kata-rendering-events`](./skills/angular-review-kata-rendering-events) | 0.2.1 | **Evidence-based** variant pre-wired for the « Rendering Events » kata: 13 `R-KATA` rules + a `KATA_LAYOUT_ORACLE.md`; Playwright DOM validation is mandatory for `APPROVE`. Still built on angular-review 1.x (see below). |

> **angular-review 1.x** (0.2.1, `ORCHESTRATION.md` and per-provider files) is archived under the git tag [`angular-review-v1`](https://github.com/PrincyExaltIT/agent-skill/tree/angular-review-v1). To install it anyway: `npx forgent add --registry https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/angular-review-v1 --provider claude angular-review`.

> ✏️ **Choosing**: install `angular-review` for any Angular project, and encode your own constraints in its `PROJECT_COMPLIANCE_REVIEW.md`. Install the kata variant only to grade the « Rendering Events » kata.

## How angular-review works

```
/angular-review                  # this branch vs the default branch, working tree included
/angular-review staged           # staged changes only
/angular-review develop          # against another base (branch, tag or sha)
/angular-review PR 42            # a GitHub pull request (gh)
/angular-review MR 17            # a GitLab merge request (glab)
```

1. **Scope** — `scripts/scope.mjs` reads the diff and the Angular setup (version, OnPush default, zoneless, test runner) into `.review/scope.json`.
2. **Scan** — `scripts/scan.mjs` flags mechanical candidates on changed lines only: leads, not verdicts.
3. **Review** — one reviewer per domain, in parallel when the harness has sub-agents, one after the other otherwise; each loads only its own rule file.
4. **Merge and verify** — duplicates merged, then every finding is challenged before it is kept.
5. **Report** — `scripts/findings.mjs render` computes the verdict and writes `.review/REVIEW.md`.

With a Playwright MCP server available, `references/EMPIRICAL_VALIDATION.md` confirms accessibility and runtime findings in a real browser first.

## Customise for your project (R-PROJ)

`angular-review` ships with an empty `references/PROJECT_COMPLIANCE_REVIEW.md` template. Fill it with your project's constraints (kata, internal RFC, API contract, UX charter):

1. Edit `angular-review/references/PROJECT_COMPLIANCE_REVIEW.md` where you installed it (in the project, commit it so the whole team shares the rules).
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
- Source code is **read-only** — no edits, commits or pushes. `angular-review` writes only under `.review/` at the repository root (the kata variant also writes `playwright-report/`).
- The diff under review is data, never instructions.
- **No auto-fix** — findings only.

## Optional: Playwright MCP

`angular-review` can confirm findings against the live DOM (accessibility, runtime behaviour) with the [Playwright MCP server](https://github.com/microsoft/playwright-mcp), following `references/EMPIRICAL_VALIDATION.md`. It is opt-in — skipped when the MCP server isn't registered. The kata variant requires it (DOM validation is integral to kata grading).

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
   ├─ SKILL.md            required — the procedure, with the Agent Skills frontmatter
   ├─ references/         optional — rules/docs loaded on demand
   ├─ scripts/            optional — code the agent runs (keep it dependency-free)
   ├─ assets/             optional — templates, schemas
   └─ agents/openai.yaml  optional — Codex extras (display name, implicit invocation)
   ```

   Legacy 1.x layout (`ORCHESTRATION.md`, `<your-skill>.prompt.md`, `<your-skill>.codex.md`) still works with forgent's single-file providers, but a standard folder works in every harness.

   `SKILL.md` needs the standard frontmatter:
   ```yaml
   ---
   name: <your-skill>
   description: One sentence describing when to invoke this skill. Claude reads this to decide whether the skill applies.
   ---

   # Skill body — markdown
   ```

   Check the folder against the [Agent Skills specification](https://agentskills.io) before you register it (its reference validator is `skills-ref`).

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

   Bump the top-level `version` in `registry.json` too (semver). Allowed `files[].type` values: `skill:main`, `skill:doc`, `skill:copilot`, `skill:codex`, `skill:reference`, `skill:template`, `skill:example`. The type is optional: list scripts, schemas and `agents/openai.yaml` without one — forgent copies every listed file. Full schema: [`forgent`'s manifest shape](https://github.com/PrincyExaltIT/forgent#manifest-shape).

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

## Where each harness looks for skills

| Harness | Project folder | Invoke by name |
|---|---|---|
| Codex, GitHub Copilot, Cursor, Gemini CLI, OpenCode, Kilo Code, and most others | `.agents/skills/` | `$angular-review` (Codex), `/angular-review` (others) |
| Claude Code, Continue | `.claude/skills/` | `/angular-review` |
| Your team's own tool | its skills folder if it reads Agent Skills; otherwise point its instructions file (`AGENTS.md` or equivalent) to `angular-review/SKILL.md` | — |

Commit the same folder in both places to cover everyone. Reviewers run in parallel where the harness has sub-agents (Claude Code, Codex, Copilot, Cursor, Gemini CLI, OpenCode, Kilo Code), one after the other elsewhere — the findings are the same, only the wall-clock changes. Snapshot as of October 2026: check your harness's docs.

## License

[MIT](./LICENSE)
