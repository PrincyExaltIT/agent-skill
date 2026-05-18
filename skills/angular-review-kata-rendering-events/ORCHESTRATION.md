# Angular Review — Orchestration (provider-agnostic)

This document is the **single source of truth** for the `angular-review` skill. Provider-specific entry points (Claude Code, GitHub Copilot, OpenAI Codex) all delegate to this file.

You are the **orchestrator** of a multi-reviewer Angular code audit. Your job is to coordinate four (or five) specialised reviewers, aggregate their findings, write a report, and optionally validate the result empirically with a browser. This audit is **READ-ONLY on application source**: never modify, commit, or push application code. The only writes allowed are:

- the markdown report under `<skill-root>/reports/` ;
- Playwright artefacts (`playwright-report/`, traces, screenshots) if the empirical-validation step runs.

## Capability assumptions per provider

This document is written for any agent runtime. Translate the generic steps to your provider's tooling:

| Capability needed | Claude Code | GitHub Copilot | OpenAI Codex |
|---|---|---|---|
| Read files | `Read` tool | builtin | builtin |
| Run shell command | `Bash` tool | `runCommands` | builtin shell |
| Spawn parallel sub-agents | `Agent` tool, N calls in one message | `runSubagent` (parallel since Jan 2026), or `/fleet` in Copilot CLI | native subagent (parallel) |
| Write report file | `Write` tool | `editFiles` | apply-patch / write-file |
| MCP browser (optional) | `mcp__playwright__*` tools | `#playwright` tools | `mcp_playwright_*` tools |

**All three providers now support parallel sub-agent dispatch** (Claude has had it; Copilot since the Jan 2026 update; Codex via its native `subagents` feature). Always use parallelism for Step 3. If a runtime version doesn't support it, fall back to sequential — the rules and outputs are identical, only wall-clock differs.

## Skill bundle layout

```
<skill-root>/
├── SKILL.md                              ← Claude Code entry (frontmatter)
├── angular-review.prompt.md              ← GitHub Copilot prompt entry
├── angular-review.codex.md               ← OpenAI Codex prompt entry
├── ORCHESTRATION.md                      ← this file (the actual logic)
├── references/
│   ├── SECURITY_REVIEW.md                ← R-SEC (23 rules)
│   ├── ARCHITECTURE_CLEAN_CODE_REVIEW.md ← R-ARCH (26 rules)
│   ├── PERFORMANCE_REVIEW.md             ← R-PERF (33 rules)
│   ├── A11Y_AND_ERROR_HANDLING_REVIEW.md ← R-A11Y + R-ERR (24 rules)
│   └── PROJECT_COMPLIANCE_REVIEW.md      ← R-PROJ (optional, user-filled)
├── templates/
│   └── REPORT.md                         ← final report template
├── reports/                              ← generated review-<timestamp>.md
└── examples/
    ├── subagent-prompt.md
    └── subagent-output.json
```

`<skill-root>` is the install location: `.claude/skills/angular-review/` (Claude), `.github/agent-skills/angular-review/` (Copilot), or `~/.codex/agent-skills/angular-review/` (Codex). The orchestration is path-agnostic — read whatever path your entry point declares.

Each reference file has frontmatter (`name`, `domain`, `rule_prefix`, `applies_to`, `severity_levels`, `sources`) used to match the changed files.

## MCP prerequisite (optional)

Step 6 (empirical validation) needs the `playwright` MCP server. If it's not registered, Step 6 is **silently skipped**. Provider-specific install instructions are in the repo `README.md`; the minimal config is the same everywhere:

```
command: npx
args: ["-y", "@playwright/mcp@latest"]
```

## Step 1 — Determine the review target

Based on the argument passed to the skill invocation:

| Argument | Diff target |
|---|---|
| (empty) | `git diff main...HEAD` |
| `staged` | `git diff --cached` |
| `PR <num>` | `gh pr diff <num>` |
| `<branch>` | `git diff main...<branch>` |
| `<range>` (e.g. `abc..def`) | `git diff <range>` |

Also compute the changed-file list (`--name-only`) and filter out `node_modules/`, `dist/`, `*.lock`, binary files.

If the diff is **empty** → print « Aucun changement à reviewer » and stop.

## Step 2 — Select eligible reviewers

Read the frontmatter of each file in `<skill-root>/references/`. Activate a reviewer **if at least one changed file matches a `applies_to` glob**.

Available reviewers:

| Reviewer name | Reference file | Rule prefix |
|---|---|---|
| `angular-security-reviewer` | `references/SECURITY_REVIEW.md` | `R-SEC` |
| `angular-architecture-reviewer` | `references/ARCHITECTURE_CLEAN_CODE_REVIEW.md` | `R-ARCH` |
| `angular-performance-reviewer` | `references/PERFORMANCE_REVIEW.md` | `R-PERF` |
| `angular-a11y-error-reviewer` | `references/A11Y_AND_ERROR_HANDLING_REVIEW.md` | `R-A11Y`, `R-ERR` |
| `project-compliance-reviewer` *(optional)* | `references/PROJECT_COMPLIANCE_REVIEW.md` | `R-PROJ` |

The **project-compliance reviewer** activates only if `references/PROJECT_COMPLIANCE_REVIEW.md` exists **and** contains at least one rule. That's where you encode your project's specific constraints (kata, internal RFC, API contract, UX charter). See the « Adapt the skill to your project » section below.

Log: `Reviewers activated: <list> (skipped: <list>)`.

## Step 3 — Run the reviewers (parallel if supported, otherwise sequential)

**If your runtime supports parallel sub-agent calls in one message, use them.** Otherwise run the same prompt sequentially per reviewer.

For each activated reviewer, send this prompt:

```
You are the <REVIEWER_NAME> sub-agent for an Angular code review.

Load your rules from: <skill-root>/references/<REFERENCE_FILE>

Apply ONLY rules with prefix <RULE_PREFIX>. Severity levels: BLOCKER, MAJOR, MINOR, INFO.

## Files in scope
<list of files matching applies_to>

## Diff to review
```diff
<unified diff, ≤ 50 KB ; split into chunks if larger>
```

## Output
Return a single JSON object — NO prose, NO markdown:

{
  "agent": "<REVIEWER_NAME>",
  "findings": [
    {
      "ruleId": "<PREFIX>-NNN",
      "severity": "BLOCKER|MAJOR|MINOR|INFO",
      "domain": "<domain>",
      "file": "path/to/file.ts",
      "line": <number>,
      "snippet": "<line excerpt>",
      "message": "<what's wrong>",
      "suggestion": "<how to fix>",
      "source": "<angular.dev URL or local reference>"
    }
  ]
}

If no findings: {"agent": "<REVIEWER_NAME>", "findings": []}
```

See `examples/subagent-prompt.md` for a concrete example and `examples/subagent-output.json` for the expected output shape.

**Guardrails**:
- If the diff exceeds 50 KB for a reviewer → split it into file packs and run multiple parallel invocations of the same reviewer.
- Give each sub-agent call a short, distinct description (helps if your tool surface requires it).

## Step 4 — Aggregate

Once all reviewers have returned:

1. **Parse** each response as JSON. Parse failures → warning + drop those findings.
2. **Merge** findings into a single list.
3. **Deduplicate** by `(file, line, ruleId)`.
4. **Sort** by descending severity (`BLOCKER > MAJOR > MINOR > INFO`) then by `file`.
5. **Count** by severity **and separately by prefix** (especially `R-PROJ`).
6. **Compute verdict**:
   - `≥ 1 BLOCKER R-PROJ` → `REQUEST_CHANGES` (project non-compliance)
   - `≥ 1 BLOCKER` (any prefix) → `REQUEST_CHANGES`
   - `≥ 3 MAJOR` → `REQUEST_CHANGES`
   - `0 findings & 0 INFO` → `APPROVE`
   - otherwise → `COMMENT`

## Step 5 — Final report

Load `templates/REPORT.md` and substitute the `{{...}}` placeholders. If a severity section is empty, drop it.

**Always produce two outputs**:

1. **Markdown file** — write the report to `<skill-root>/reports/review-<YYYYMMDD-HHmmss>.md` (local timestamp).
   - Create `reports/` if missing.
   - Timestamp prevents overwrites across runs.
   - Content must be **identical** to what's shown to the user.

2. **Inline display** — render the report directly in the response, with the written path on the first line (e.g. `📄 Report written: <skill-root>/reports/review-20260505-143022.md`).

> Note: add `reports/` to the project's `.gitignore` if reports shouldn't be versioned — don't do this automatically.

## Step 6 — Empirical validation via Playwright MCP (optional)

Static review can't guarantee the rendered DOM matches expected constraints (positioning, resize behaviour, critical DOM attributes, runtime a11y). When the `playwright` MCP server is available, run this step to confirm empirically.

### 6.1 Detect the MCP

If the Playwright MCP tools aren't exposed in your runtime → mark Step 6 « MCP Playwright not registered — skipped » in the report and move on.

### 6.2 Start the app

Detect the dev-server script in `package.json` (`start`, `dev`, `serve`). Launch it in the background and wait until its URL responds (default `http://localhost:4200` for Angular CLI ; otherwise parse the server output).

### 6.3 MCP-driven smoke tests

For **each static finding in a11y, runtime perf, or compliance** that can be visually confirmed, ask the runtime (via Playwright MCP) to:

1. Navigate to the dev-server URL.
2. Take an ARIA + accessibility-tree snapshot.
3. Evaluate JS to assert a specific property (attribute, class, position, `getComputedStyle`).
4. Resize the viewport and re-snapshot to validate responsiveness.
5. Take a screenshot saved under `playwright-report/` (or a dedicated folder).

List the checks performed and their result (✅ / ❌). A failure → **escalate** an existing finding's severity or create a new `R-RUNTIME-NNN` finding (prefix reserved for DOM/runtime constatations).

### 6.4 Versioned Playwright suite (if present)

If the project has a Playwright suite (`tests/**/*.spec.ts`, `e2e/**/*.spec.ts`, or `playwright.config.*`), run it **only when Playwright is already installed locally** — never let it download. Concretely:

1. Verify locally installed: `[ -d node_modules/@playwright/test ]` (or equivalent in the project's package manager). If absent → skip and write « Empirical validation not executed: @playwright/test not installed locally » in the report.
2. Run: `npx --no-install playwright test --reporter=list,html` (the `--no-install` flag makes npx fail rather than fetch from the npm registry, preserving the « no-network » guardrail).

Map failures to findings (prefix `R-RUNTIME`, or `R-PROJ` if the suite checks a project constraint). The HTML report under `playwright-report/` can be served with `npx --no-install playwright show-report` — mention this command in the report's « Empirical validation » section.

### 6.5 Playwright guardrails

- Don't modify `src/` even if a test fails — report via a finding, let the author fix it.
- **Kill the dev server** at the end of Step 6.
- If Playwright or the dev server fails to start → **don't block the verdict**; record « Empirical validation not executed: <reason> » in the report.
- In the « Empirical validation » section of the report, **recommend** to the user that they add `playwright-report/`, `test-results/`, `playwright/.cache/` to their project's `.gitignore`. The orchestrator MUST NOT modify `.gitignore` itself (cf. read-only guardrail in « Global guardrails » below).

## Global guardrails

- **Source code READ-ONLY**: no edits/writes to application source. No commits, no push. Only allowed writes: the markdown report under `<skill-root>/reports/` and Playwright artefacts under `playwright-report/`.
- **No auto-fix**: only list findings.
- **No network** beyond `gh pr diff` for PR targets and local MCP calls to a headless browser. Guidelines are pre-compiled locally.
- **Confidentiality**: never send the diff or DOM snapshots to an external service.

## Tips

- If `git` is unavailable or there's no `main` remote → ask the user for the target.
- If no `*.ts`/`*.html` file changed → everything skipped; print a clear message.
- For a single-file review: `staged`, or `HEAD~1..HEAD`.
- If the project isn't Angular (no `angular.json`) → warn and offer to skip or continue best-effort.

## Adapt the skill to your project

The `references/PROJECT_COMPLIANCE_REVIEW.md` file is an **empty template** you fill in to encode your project's specific constraints (kata, internal RFC, API contract, UX charter). Procedure:

1. Copy the frontmatter + structure from any existing reference (e.g. `SECURITY_REVIEW.md`).
2. Set `rule_prefix` (`R-PROJ` default, or a custom prefix like `R-KATA` / `R-API`).
3. List your constraints as `R-PROJ-NNN — <title>` with severity, flag pattern, ❌/✅ examples, and a pointer to the canonical source (project README, ticket, RFC).
4. Adjust `applies_to` to match only the files you care about.

The orchestrator activates it automatically on the next invocation. `R-PROJ` is prioritised in the verdict (see Step 4.6).

Concrete example: for a kata « display events on a calendar », encode the RFC2119 constraints from the brief (time→pixel positioning, overlap handling, responsivity) as `R-PROJ-001…013`. The author's own setup in `web-front-rendering-event` is an instance of this pattern.
