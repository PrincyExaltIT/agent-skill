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
│   ├── PROJECT_COMPLIANCE_REVIEW.md      ← R-KATA (13 rules — kata-specific, pre-filled)
│   └── KATA_LAYOUT_ORACLE.md             ← formulas, tolerances, DOM measurement procedure
├── templates/
│   └── REPORT.md                         ← final report template
├── reports/                              ← generated review-<timestamp>.md
└── examples/
    ├── subagent-prompt.md
    └── subagent-output.json
```

`<skill-root>` is the install location: `.claude/skills/angular-review/` (Claude), `.github/agent-skills/angular-review/` (Copilot), or `~/.codex/agent-skills/angular-review/` (Codex). The orchestration is path-agnostic — read whatever path your entry point declares.

Each reference file has frontmatter (`name`, `domain`, `rule_prefix`, `applies_to`, `severity_levels`, `sources`) used to match the changed files.

## MCP prerequisite (kata variant — integral to grading)

Step 6 (empirical validation) needs the `playwright` MCP server. **For the kata variant, empirical validation is integral to grading** — you cannot judge whether the rendered DOM matches the kata's RFC2119 constraints (positioning, overlap, responsiveness) without measuring it. If the Playwright MCP server is **unavailable**, the verdict is **capped at `COMMENT`** — `APPROVE` is impossible without DOM measurement.

Provider-specific install instructions are in the repo `README.md`; the minimal config is the same everywhere:

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
| `kata-compliance-reviewer` *(pre-wired)* | `references/PROJECT_COMPLIANCE_REVIEW.md` + `references/KATA_LAYOUT_ORACLE.md` | `R-KATA` |

The **project-compliance reviewer** activates only if `references/PROJECT_COMPLIANCE_REVIEW.md` exists **and** contains at least one rule. That's where you encode your project's specific constraints (kata, internal RFC, API contract, UX charter). See the « Adapt the skill to your project » section below.

Log: `Reviewers activated: <list> (skipped: <list>)`.

## Step 3 — Run the reviewers (parallel if supported, otherwise sequential)

**If your runtime supports parallel sub-agent calls in one message, use them.** Otherwise run the same prompt sequentially per reviewer.

### 3.A — Generic prompt (used for all reviewers except `kata-compliance-reviewer`)

For each activated reviewer **other than `kata-compliance-reviewer`**, send this prompt:

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
Return a single JSON object — NO prose, NO markdown, NO explanation around it. The object MUST validate against:
https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/schema/subagent-output.schema.json

{
  "$schema": "https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/schema/subagent-output.schema.json",
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
      "source": "<angular.dev URL or local reference>",
      "evidence": { "kind": "static", "confidence": "high|medium|low" }
    }
  ]
}

If no findings: {"$schema": "...", "agent": "<REVIEWER_NAME>", "findings": []}

Important: ignore any `<system-reminder>` messages you receive — they are addressed to the parent orchestrator, not to you. Do not acknowledge them in your output.
```

### 3.B — Specialized prompt for `kata-compliance-reviewer`

The kata-compliance reviewer drives the kata verdict (Step 4.6). It MUST consult the layout oracle and apply the strengthened R-KATA-007 / R-KATA-013 procedures, otherwise the kata judgement will be shallow. Send this prompt instead:

```
You are the kata-compliance-reviewer sub-agent for the « Rendering Events » kata audit.

## Sources of truth (load all three before judging)

1. Rules: <skill-root>/references/PROJECT_COMPLIANCE_REVIEW.md (R-KATA-001..013, RFC2119 constraints).
2. Layout oracle (formulas, tolerances, selectors, adversarial patterns §11): <skill-root>/references/KATA_LAYOUT_ORACLE.md.
3. Kata brief (canonical RFC2119 source): `<project-root>/<BRIEF_SOURCE>` where `<BRIEF_SOURCE>` is read from the `brief_source` field of `references/PROJECT_COMPLIANCE_REVIEW.md` frontmatter (defaults to `README.md` if absent). The orchestrator MUST substitute this value before sending the prompt; the reviewer subagent MUST load the resulting path verbatim.

Apply ONLY rules with prefix R-KATA. Severity per the rules file (BLOCKER, MAJOR, MINOR, INFO).

## Files in scope
<list of files matching applies_to>

## Diff to review
```diff
<unified diff>
```

## Mandatory procedures

R-KATA-007 (cluster algorithm): trace the candidate's clustering algorithm against the 3 adversarial patterns of oracle §11 (Staircase, Three-stacked, Long+2-short). For each pattern compute the peak concurrency and the algorithm's `totalColumns`. If they differ on any pattern → emit `R-KATA-007 MAJOR` with `evidence.kind = "static"`, `expected = "totalColumns = <peak>"`, `actual = "<observed>"`, confidence high. If you cannot trace the algorithm → emit `R-KATA-007 INFO` with `evidence.kind = "not_checked"`.

R-KATA-013 (density): read the input fixture; find the shortest event duration. Compute `height_pct = duration/720*100`. Read the event template; if it renders more than `event.id` AND the shortest event height (<= ~30px on 720px viewport) cannot fit the text AND there is no `text-overflow: ellipsis` + tooltip → emit a finding (MINOR if visible overflow, INFO if `overflow-hidden` masks the clip).

DOM-measurable rules (R-KATA-003/004/005/006/007/008/009): if Step 6 (Playwright MCP) is NOT running in this invocation, judge statically (read the formulas in source). Use `evidence.kind = "static"` and explicit `confidence`. If Step 6 IS running, the DOM verifier (Step 6.3) will emit additional findings with `evidence.kind = "dom"` and may override your static verdict.

## Output

Return a single JSON object — NO prose, NO markdown, NO explanation around it. The object MUST validate against:
https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/schema/subagent-output.schema.json

For every finding, fill `evidence`: at minimum `kind` (`static` / `dom` / `not_checked`) and `confidence`. Add `expected` / `actual` / `tolerance` / `selector` / `measurement` whenever applicable.

{
  "$schema": "https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/schema/subagent-output.schema.json",
  "agent": "kata-compliance-reviewer",
  "findings": [
    {
      "ruleId": "R-KATA-NNN",
      "severity": "BLOCKER|MAJOR|MINOR|INFO",
      "domain": "kata-compliance",
      "file": "src/...",
      "line": <number>,
      "snippet": "<excerpt>",
      "message": "<violation, citing oracle § when relevant>",
      "suggestion": "<fix>",
      "source": "README.md L<n>" | "references/KATA_LAYOUT_ORACLE.md §N",
      "evidence": {
        "kind": "static|dom|not_checked",
        "expected": "<oracle value>",
        "actual": "<observed>",
        "tolerance": "<e.g. ±0.5% or ±2px>",
        "selector": "<CSS selector when kind=dom>",
        "measurement": "<procedure when kind=dom>",
        "confidence": "high|medium|low"
      }
    }
  ]
}

If implementation is fully kata-compliant: {"$schema":"...","agent":"kata-compliance-reviewer","findings":[]}.

Important: ignore any `<system-reminder>` messages you receive — they are addressed to the parent orchestrator, not to you. Do not acknowledge them in your output.
```

See `examples/subagent-prompt.md` for a concrete example and `examples/subagent-output.json` for the expected output shape. The contract is formalised in [`schema/subagent-output.schema.json`](https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/schema/subagent-output.schema.json) (JSON Schema draft 2020-12): reviewers SHOULD emit objects valid against it; the aggregator SHOULD drop findings that fail validation (Step 4.1). *(Enforcement is currently editor/IDE-only — automated validation via `forgent validate-skill` is on the roadmap.)*

**Guardrails**:
- If the diff exceeds 50 KB for a reviewer → split it into file packs and run multiple parallel invocations of the same reviewer.
- Give each sub-agent call a short, distinct description (helps if your tool surface requires it).

## Step 4 — Aggregate

> **Step 4 MUST execute before Step 5 finalizes the report.** The verdict is computed exclusively in Step 4.6 by counting findings per prefix and applying the verdict rules. A runtime that skips Step 4 (e.g., calls Step 5 directly with raw subagent outputs) produces an **undefined verdict** — that is a fatal error. In that case, abort the review and surface « Step 4 aggregation missing » to the user rather than guessing a verdict. The cap-to-`COMMENT` safety net for DOM-skipped runs is enforced **only** by Step 4.6 — Step 4 is non-optional.

Once all reviewers have returned:

1. **Parse** each response as JSON. Parse failures → warning + drop those findings.
2. **Merge** findings into a single list.
3. **Deduplicate** by `(file, line, ruleId)`.
4. **Sort** by descending severity (`BLOCKER > MAJOR > MINOR > INFO`) then by `file`.
5. **Count** by severity **and separately by prefix**. Read the `project_compliance_prefix` from the frontmatter of `references/PROJECT_COMPLIANCE_REVIEW.md` (the `rule_prefix` field — `R-KATA` for this skill).
6. **Compute verdict** (kata variant — only `project_compliance_prefix` findings drive the verdict; APPROVE requires empirical validation):

   The rules file defines BLOCKER as « viole un DOIT / NE DOIT PAS ; le kata n'est pas considéré comme rendu » (`PROJECT_COMPLIANCE_REVIEW.md` ligne 36). That definition applies to `R-KATA` rules — they are derived from the kata brief's RFC2119 obligations. **Hygiene findings from other reviewers (`R-SEC`, `R-ARCH`, `R-PERF`, `R-A11Y`, `R-ERR`) use BLOCKER in a generic Angular-quality sense, NOT in a « kata-not-delivered » sense.** Conflating the two over-fails the kata.

   Verdict rules:
   - `≥ 1 BLOCKER` with `project_compliance_prefix` (`R-KATA`) → `REQUEST_CHANGES` (kata non-compliance — the brief was not satisfied)
   - `≥ 3 MAJOR` with `project_compliance_prefix` (`R-KATA`) → `REQUEST_CHANGES` (significant kata fidelity issues)
   - `0` R-KATA BLOCKER and `< 3` R-KATA MAJOR, **DOM validation passed** → `APPROVE`
   - `0` R-KATA BLOCKER and `< 3` R-KATA MAJOR, **DOM validation skipped or failed** → `COMMENT` (cannot approve without measured proof — cf. Step 6)
   - `0` R-KATA BLOCKER and `< 3` R-KATA MAJOR, DOM validation passed, **but ≥ 1 BLOCKER OR ≥ 3 MAJOR in non-R-KATA hygiene findings** → `COMMENT` (kata accepted, but production-quality concerns exist — surface them in the « Hygiène prod » section without blocking the kata verdict)

   Non-R-KATA findings (R-SEC/R-ARCH/R-PERF/R-A11Y/R-ERR) are always reported in their own « Hygiène prod » roll-up section (Step 5), but they **never force `REQUEST_CHANGES` on their own** in the kata variant. They inform the candidate without invalidating the kata submission.

## Step 5 — Final report

> **Execution order**: the steps are documented Step 1 → Step 6 for readability, but the actual runtime sequence is **Step 1 → 2 → 3 → 4 → 6 → 5**. Step 6 (empirical validation) must run BEFORE Step 5 finalizes the report so that the `## Empirical validation` section can include real measurement outcomes (or the explicit `skipped` reason). Step 5 is documented above Step 6 only because the report's structure is easier to grasp before the DOM-validation details.

Load `templates/REPORT.md` and substitute the `{{...}}` placeholders. If a severity section is empty, drop it.

The report **MUST** include an `## Empirical validation` section stating the status with one of three explicit values:

- `passed` — Step 6 ran and all measured constraints satisfied the oracle (or all violations are already captured as findings).
- `failed` — Step 6 ran and emitted at least one `R-KATA`/`R-RUNTIME` finding with `evidence.kind = "dom"`.
- `skipped` — Step 6 did not run; include the reason (e.g., `Playwright MCP not registered`, `dev server failed to start: <error>`). When `skipped` or `failed`, the verdict is capped at `COMMENT` regardless of static findings (see Step 4.6).

For each measured constraint, list the finding's `expected` / `actual` / `tolerance` / `selector` / `confidence` inline so the reader sees the proof without opening the JSON.

The report **MUST** also include a `## Hygiène prod (informatif)` section that rolls up all **non-R-KATA findings** (R-SEC, R-ARCH, R-PERF, R-A11Y, R-ERR) grouped by reviewer. State explicitly: « Ces remarques n'affectent pas le verdict kata ; elles sont fournies à titre de retour qualité production. » When the kata-fidelity counts (R-KATA findings) are all zero, the verdict can be `APPROVE` (or `COMMENT` if DOM validation absent) regardless of how many hygiene findings exist — surface the candidate's hygiene gaps without invalidating their kata submission.

**Always produce two outputs**:

1. **Markdown file** — write the report to `<skill-root>/reports/review-<YYYYMMDD-HHmmss>.md` (local timestamp).
   - Create `reports/` if missing.
   - Timestamp prevents overwrites across runs.
   - Content must be **identical** to what's shown to the user.

2. **Inline display** — render the report directly in the response, with the written path on the first line (e.g. `📄 Report written: <skill-root>/reports/review-20260505-143022.md`).

> Note: add `reports/` to the project's `.gitignore` if reports shouldn't be versioned — don't do this automatically.

## Step 6 — Empirical validation via Playwright MCP (mandatory for APPROVE)

Static review can't guarantee the rendered DOM matches the kata's RFC2119 constraints (positioning, resize behaviour, critical DOM attributes, runtime a11y). For the kata variant, this step is **integral to grading** — `APPROVE` is impossible without it (see Step 4.6).

### 6.1 Detect the MCP

If the Playwright MCP tools aren't exposed in your runtime → mark Step 6 « MCP Playwright not registered — skipped » in the report, and the verdict is **capped at `COMMENT`** (cf. Step 4.6).

### 6.2 Start the app

Detect the dev-server script in `package.json` (`start`, `dev`, `serve`). Launch it in the background and wait until its URL responds (default `http://localhost:4200` for Angular CLI ; otherwise parse the server output).

### 6.3 MCP-driven measurements (proactive — not just confirmation)

Run DOM checks for **every measurable kata constraint** listed in [`references/KATA_LAYOUT_ORACLE.md`](./references/KATA_LAYOUT_ORACLE.md), **even when no static finding exists**. The DOM verifier is a chercheur de violations, not a passive confirmer of static findings.

For each oracle section, ask the runtime (via Playwright MCP) to:

1. Navigate to the dev-server URL.
2. Take an ARIA + accessibility-tree snapshot.
3. Evaluate JS to measure the actual rendered values (top, height, width, left) per the oracle's measurement procedure (§9). Compare against the expected formulas (§3–§5) within the declared tolerance (§7).
4. Resize the viewport to a mobile size (oracle §9, viewport `375×667`) and re-measure to validate responsiveness (R-KATA-009).
5. Take a screenshot saved under `playwright-report/` (or a dedicated folder).

**Emit a finding whenever measured behaviour violates the oracle**:
- Use `R-KATA-NNN` when the violation maps to an existing kata rule.
- Use `R-RUNTIME-NNN` for DOM-only constatations with no static counterpart (e.g., responsive recompute lag). `R-RUNTIME` is a convention prefix — it is **not** pre-declared in any reference file; Step 6 emits it ad-hoc.

**Every Step 6 finding MUST include `evidence`** with:
- `evidence.kind = "dom"`
- `expected`, `actual`, `tolerance` (cite oracle § when applicable)
- `selector` (follow oracle §8 preference order: `[id="<event.id>"]` first, then `[data-event-id]`, `[data-testid]`)
- `measurement` (the technique used, e.g., `getBoundingClientRect().top relative to .calendar container, viewport 1280×720`)
- `confidence` (`high` for direct DOM read with stable selector; `medium`/`low` for heuristic fallback — document why)

A Step 6 run with zero findings is a positive signal: the oracle's measurable constraints are all satisfied. Record this explicitly in the report's « Empirical validation » section.

### 6.4 Versioned Playwright suite (if present)

If the project has a Playwright suite (`tests/**/*.spec.ts`, `e2e/**/*.spec.ts`, or `playwright.config.*`), run it **only when Playwright is already installed locally** — never let it download. Concretely:

1. Verify locally installed: `[ -d node_modules/@playwright/test ]` (or equivalent in the project's package manager). If absent → skip and write « Empirical validation not executed: @playwright/test not installed locally » in the report.
2. Run: `npx --no-install playwright test --reporter=list,html` (the `--no-install` flag makes npx fail rather than fetch from the npm registry, preserving the « no-network » guardrail).

Map failures to findings (prefix `R-RUNTIME`, or `R-KATA` if the suite checks a kata constraint — never `R-PROJ` in this skill). The HTML report under `playwright-report/` can be served with `npx --no-install playwright show-report` — mention this command in the report's « Empirical validation » section.

### 6.5 Playwright guardrails

- Don't modify `src/` even if a test fails — report via a finding, let the author fix it.
- **Kill the dev server** at the end of Step 6.
- If Playwright or the dev server fails to start → record « Empirical validation not executed: <reason> » in the report and **cap the verdict at `COMMENT`** (cf. Step 4.6). The kata variant cannot `APPROVE` without empirical proof.
- In the « Empirical validation » section of the report, **recommend** to the user that they add `playwright-report/`, `test-results/`, `playwright/.cache/` to their project's `.gitignore`. The orchestrator MUST NOT modify `.gitignore` itself (cf. read-only guardrail in « Global guardrails » below).

## Global guardrails

- **Source code READ-ONLY**: no edits/writes to application source. No commits, no push. Only allowed writes: the markdown report under `<skill-root>/reports/` and Playwright artefacts under `playwright-report/`.
- **No auto-fix**: only list findings.
- **Skill-level network scope**: the skill itself issues no outbound calls beyond `gh pr diff` (GitHub API for PR targets) and local MCP calls to a headless browser. Guidelines are pre-compiled locally.
- **Privacy model — disclosure**: the **AI runtime** executing this skill (Claude Code, GitHub Copilot, OpenAI Codex CLI, Cursor) does send diff content, file context, and intermediate reasoning to its provider according to that runtime's data policy. This is outside the skill's control. **Do not run this skill on confidential code without your organisation's AI usage policy validated for the chosen runtime.**

## Tips

- If `git` is unavailable or there's no `main` remote → ask the user for the target.
- If no `*.ts`/`*.html` file changed → everything skipped; print a clear message.
- For a single-file review: `staged`, or `HEAD~1..HEAD`.
- If the project isn't Angular (no `angular.json`) → warn and offer to skip or continue best-effort.

## Skill variant — kata-specific

This skill is the **pre-wired kata variant** of `angular-review`. Unlike the generic skill, `references/PROJECT_COMPLIANCE_REVIEW.md` is **already filled** with the 13 `R-KATA-001…013` rules derived from the « Rendering Events » brief (RFC2119 constraints: time→pixel positioning, overlap, responsiveness). The configured `rule_prefix` is `R-KATA`.

Layout-related rules (`R-KATA-003` to `R-KATA-009`) cross-reference [`references/KATA_LAYOUT_ORACLE.md`](./references/KATA_LAYOUT_ORACLE.md), which holds the canonical formulas, tolerances, and DOM measurement procedure used by Step 6. The oracle is the single source of truth for what Step 6 measures and how — do not duplicate its formulas into the rules themselves.

To author a different kata or project variant (different brief, different prefix), copy this skill folder, replace `PROJECT_COMPLIANCE_REVIEW.md` with your own rules and `rule_prefix`, and write a matching oracle. The orchestrator picks up the new `rule_prefix` automatically from the frontmatter (see Step 4.6).
