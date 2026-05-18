# agent-skill

Provider-agnostic agent skills — one bundle, works on **Claude Code**, **GitHub Copilot** (VS Code or CLI), and **OpenAI Codex CLI**.

## ⚡ Install with forgent

This repo is the default registry for **[forgent](https://github.com/PrincyExaltIT/forgent)**, a shadcn-style CLI for AI agent skills. One command, any provider:

```bash
npx forgent add --provider claude angular-review
# or: --provider copilot | codex | cursor
```

That's it. In your AI agent, type `/angular-review` to use the skill.

Want the kata variant? `npx forgent add --provider claude angular-review-kata-rendering-events`.

See [`forgent`'s README](https://github.com/PrincyExaltIT/forgent#readme) for full flags, `forgent.config.json`, and global install (`npm i -g forgent`).

---

## Legacy install (deprecated)

> The `install.sh` / `install.ps1` curl one-liners below are kept for users mid-migration. They were tied to the old root-level skill layout and will not work after the move to `skills/`. New users should install via `forgent`.

From the root of your project, run the one-liner for your shell. The installer **auto-detects** your AI provider (Claude / Copilot / Codex) from project markers and drops the skill at the right path.

### Linux / macOS / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/install.sh | bash
```

### Windows (PowerShell 7+)

```powershell
irm https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/install.ps1 | iex
```

> Want the kata-specific variant? Append `--skill angular-review-kata-rendering-events` to the one-liner — see the [Available skills](#-available-skills) table below.

---

## ⚙️ Common flags

Both installers accept the same flags. Defaults: `--skill angular-review --provider auto --scope project`.

```bash
# Specify a provider explicitly
curl -fsSL .../install.sh | bash -s -- --provider claude

# Install user-globally (every project)
curl -fsSL .../install.sh | bash -s -- --scope global

# Also register the Playwright MCP server (enables Step 6: empirical DOM validation)
curl -fsSL .../install.sh | bash -s -- --with-mcp playwright

# Install the kata-specific variant (pre-filled R-KATA rules for « Rendering Events »)
# Note: this skill auto-enables --with-mcp playwright (Step 6 is integral to kata grading)
curl -fsSL .../install.sh | bash -s -- --skill angular-review-kata-rendering-events

# Combine
curl -fsSL .../install.sh | bash -s -- --provider claude --scope global --with-mcp playwright
```

PowerShell equivalent — pipe `irm` into a scriptblock to pass parameters:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/install.ps1))) -Provider claude -Scope global -WithMcp playwright
```

| Flag | Values | Default | Effect |
|---|---|---|---|
| `--skill` / `-Skill` | any skill folder in this repo | `angular-review` | Which skill to install |
| `--provider` / `-Provider` | `claude`, `copilot`, `codex`, `auto` | `auto` | AI provider to target |
| `--scope` / `-Scope` | `project`, `global` | `project` | Install to repo or to home dir |
| `--with-mcp` / `-WithMcp` | `playwright` | _(none)_ | Register an MCP server while you're at it |
| `--ref` / `-Ref` | branch/tag/commit | `main` | Install a specific version |
| `--yes` / `-Yes` | flag | off | Skip overwrite prompt |

### Auto-detection rules

The installer marks the first match in this order:

| Marker present in cwd | Provider chosen |
|---|---|
| `.claude/`, `.mcp.json`, or `CLAUDE.md` | `claude` |
| `.github/` | `copilot` |
| `.codex/` or `AGENTS.md` | `codex` |

If multiple markers exist, it picks the first and prints a warning so you can override with `--provider`.

---

## 🤖 Use the skill

Once installed, invoke from your AI agent:

```
/angular-review                  # diff main…HEAD
/angular-review staged           # staged diff only
/angular-review PR 42            # GitHub PR
/angular-review feature/foo      # a specific branch
/angular-review abc..def         # a commit range
```

The agent will:
1. Compute the diff.
2. Run the relevant reviewers in parallel (security, architecture, performance, a11y/errors, plus project-compliance if you filled in the template).
3. Aggregate findings and write a markdown report under `<skill>/reports/review-<timestamp>.md`.
4. _(Optional Step 6)_ If the Playwright MCP is registered, validate the rendered DOM in a real browser — positioning, accessibility, responsive behaviour.

---

## 🧪 Available skills

| Skill | Invoke with | What it does |
|---|---|---|
| [`angular-review`](./angular-review) | `/angular-review` | Multi-reviewer Angular code audit (security, architecture, performance, a11y/errors, optional project-compliance) using guidelines compiled from angular.dev. Ships with an **empty** `PROJECT_COMPLIANCE_REVIEW.md` template — fill it in to encode your project's R-PROJ constraints. Optionally validates the rendered DOM via the Playwright MCP server. **Read-only** — produces a markdown report, never modifies code. |
| [`angular-review-kata-rendering-events`](./angular-review-kata-rendering-events) | `/angular-review-kata-rendering-events` | Variant of `angular-review` **pre-filled** with the 13 R-KATA rules of the « Rendering Events » kata (RFC2119 constraints from the kata brief: positionnement temps→pixels, chevauchement, responsivité, libs autorisées, …). Otherwise byte-for-byte identical to `angular-review`. Install with `--skill angular-review-kata-rendering-events`. **Auto-enables `--with-mcp playwright`** (Step 6 empirical DOM validation is integral to kata grading). |

> ✏️ **Choosing between the two**: install `angular-review` if you have your own constraints to encode (or none at all). Install `angular-review-kata-rendering-events` if you're submitting the « Rendering Events » kata and want the conformity rules pre-loaded — no `PROJECT_COMPLIANCE_REVIEW.md` editing needed.

Each skill ships with:
- One **provider-agnostic** orchestration document (`ORCHESTRATION.md`) — single source of truth.
- A thin **entry-point file per provider** (`SKILL.md` / `<skill>.prompt.md` / `<skill>.codex.md`).
- **Shared assets** (rules, templates, examples) used by all three.

---

## 🧰 Customise for your project (R-PROJ)

The general `angular-review` skill ships with an **empty** `references/PROJECT_COMPLIANCE_REVIEW.md` template. Fill it with the constraints specific to your project (kata, internal RFC, API contract, UX charter):

1. Edit `<install-path>/angular-review/references/PROJECT_COMPLIANCE_REVIEW.md`.
2. Add at least one rule under « Règles à vérifier ». Use the template format provided in the file.
3. _(Optional)_ Adjust the `applies_to` glob and `rule_prefix` in the frontmatter.

The next invocation auto-detects your rules and runs an extra `project-compliance-reviewer` sub-agent emitting `R-PROJ-NNN` findings. A single R-PROJ BLOCKER ⇒ `REQUEST_CHANGES`.

> 💡 **Looking for a concrete example?** The [`angular-review-kata-rendering-events`](./angular-review-kata-rendering-events) skill is exactly that: the general `angular-review` skill with a pre-filled `PROJECT_COMPLIANCE_REVIEW.md` encoding the 13 R-KATA rules of the « Rendering Events » kata. Read its `references/PROJECT_COMPLIANCE_REVIEW.md` to see how RFC2119 brief constraints translate into actionable reviewer rules with severity, flag patterns, and ✅/❌ examples.

---

## 🔍 What the installer does

Reading the one-liner with a healthy dose of skepticism is encouraged. Here's exactly what it does:

1. **Sanity checks**: requires `git` in PATH.
2. **Auto-detects** the provider from project markers (override with `--provider`).
3. **Computes the destination path** from `provider × scope`.
4. **Backs up** any existing install to `<dest>.bak` (asks first; `--yes` to skip the prompt).
5. **Shallow-clones** `https://github.com/PrincyExaltIT/agent-skill.git@<ref>` to a temp dir. If `<ref>` is a commit SHA (or any ref that `git clone --branch` can't resolve), the installer **falls back** to a full clone followed by `git checkout <ref>` — so branch, tag, and commit refs all work.
6. **Copies** the requested skill folder to its destination.
7. **Places the provider-specific prompt** at the slash-command location (`.github/prompts/` for Copilot, `.codex/prompts/` for Codex).
8. _(If `--with-mcp playwright`)_ **Registers** the Playwright MCP server — via `claude mcp add` if available, otherwise by writing the right config file for your provider.
9. **No network beyond the GitHub clone at install time.** No telemetry. No global package installs. (Note: the registered Playwright MCP server runs `npx -y @playwright/mcp@latest` the first time your AI agent uses it — that command fetches `@playwright/mcp` from npm on first launch, not during install.)

The two scripts ([`install.sh`](./install.sh), [`install.ps1`](./install.ps1)) are short and unminified — read before running if you want.

---

## 📂 Install paths reference

Replace `<skill>` below with the skill name passed to `--skill` (`angular-review` by default, or `angular-review-kata-rendering-events` for the kata variant).

| Provider | Scope | Bundle path | Slash-command prompt |
|---|---|---|---|
| Claude Code | project | `.claude/skills/<skill>/` | _(uses `SKILL.md` frontmatter)_ |
| Claude Code | global | `~/.claude/skills/<skill>/` | _(uses `SKILL.md` frontmatter)_ |
| GitHub Copilot | project | `.github/agent-skills/<skill>/` | `.github/prompts/<skill>.prompt.md` |
| GitHub Copilot | global | _(not supported by Copilot — use project scope)_ | — |
| OpenAI Codex | project | `.codex/agent-skills/<skill>/` | `.codex/prompts/<skill>.md` |
| OpenAI Codex | global | `~/.codex/agent-skills/<skill>/` | `~/.codex/prompts/<skill>.md` |

---

## 🪛 Optional: Playwright MCP

Step 6 of `angular-review` validates findings against the live DOM (positioning, a11y, resize behaviour) using the [Playwright MCP server](https://github.com/microsoft/playwright-mcp). The step is **opt-in** — if the MCP server isn't registered, it's silently skipped.

> 🎯 **Exception**: the [`angular-review-kata-rendering-events`](./angular-review-kata-rendering-events) variant **auto-enables** `--with-mcp playwright` at install time — Step 6 is integral to kata grading (it empirically verifies the temps→pixels positioning, the somme des largeurs au pic for overlapping clusters, and the responsivité on resize). If you pass `--with-mcp` explicitly, your choice is respected; otherwise the installer fills it in for you.

The easiest path is `--with-mcp playwright` at install time. If you'd rather wire it up manually, the per-provider snippets are:

**Claude Code:**

```bash
claude mcp add playwright -- npx -y @playwright/mcp@latest
```

or project-local `.mcp.json`:

```json
{ "mcpServers": { "playwright": { "command": "npx", "args": ["-y", "@playwright/mcp@latest"] } } }
```

**GitHub Copilot (VS Code)** — `.vscode/mcp.json`:

```json
{ "servers": { "playwright": { "command": "npx", "args": ["-y", "@playwright/mcp@latest"] } } }
```

**OpenAI Codex** — `~/.codex/config.toml`:

```toml
[mcp_servers.playwright]
command = "npx"
args = ["-y", "@playwright/mcp@latest"]
```

### Versioned e2e suite (optional, independent of MCP)

```bash
npm i -D @playwright/test
npx playwright install chromium
npx playwright test --reporter=list,html
npx playwright show-report   # http://localhost:9323
```

The orchestration auto-detects `playwright.config.*` and runs the suite as part of Step 6.4.

---

## 🛠️ Manual install (fallback)

If you can't run a script or prefer to inspect everything, do it by hand:

Replace `angular-review` below with `angular-review-kata-rendering-events` if you want the kata-specific variant.

<details>
<summary><strong>Claude Code</strong></summary>

```bash
mkdir -p .claude/skills
git clone --depth 1 https://github.com/PrincyExaltIT/agent-skill.git /tmp/agent-skill
cp -r /tmp/agent-skill/angular-review .claude/skills/
```

</details>

<details>
<summary><strong>GitHub Copilot (VS Code)</strong></summary>

```bash
mkdir -p .github/prompts .github/agent-skills
git clone --depth 1 https://github.com/PrincyExaltIT/agent-skill.git /tmp/agent-skill
cp -r /tmp/agent-skill/angular-review .github/agent-skills/
cp .github/agent-skills/angular-review/angular-review.prompt.md .github/prompts/
```

</details>

<details>
<summary><strong>OpenAI Codex CLI</strong></summary>

```bash
mkdir -p .codex/prompts .codex/agent-skills
git clone --depth 1 https://github.com/PrincyExaltIT/agent-skill.git /tmp/agent-skill
cp -r /tmp/agent-skill/angular-review .codex/agent-skills/
cp .codex/agent-skills/angular-review/angular-review.codex.md .codex/prompts/angular-review.md
```

</details>

---

## 🏗️ Capability matrix per provider

| Step | Claude Code | GitHub Copilot | OpenAI Codex |
|---|---|---|---|
| 1. Read git diff | `Bash` | `runCommands` | shell |
| 2. Glob references | `Glob` | `search`/`codebase` | shell/builtin |
| 3. Run N reviewers **in parallel** | ✅ `Agent` × N in one message | ✅ `runSubagent` (Jan 2026+) / `/fleet` in CLI | ✅ native `subagents` |
| 4. Aggregate findings | inline | inline | inline |
| 5. Write report | `Write` | `editFiles` | apply-patch |
| 6. Playwright MCP | `mcp__playwright__*` | `#playwright` | `mcp_playwright_*` |

All three providers now expose parallel sub-agent dispatch — Step 3 has identical wall-clock characteristics across them.

---

## 📜 Repository layout

```
agent-skill/
├── README.md
├── LICENSE                                      ← MIT
├── install.sh                                   ← bash one-liner installer
├── install.ps1                                  ← PowerShell one-liner installer
├── angular-review/                              ← general skill (R-PROJ template empty)
│   ├── ORCHESTRATION.md                         ← single source of truth (provider-agnostic)
│   ├── SKILL.md                                 ← Claude Code entry (frontmatter)
│   ├── angular-review.prompt.md                 ← GitHub Copilot entry (frontmatter)
│   ├── angular-review.codex.md                  ← OpenAI Codex entry (plain md)
│   ├── references/
│   │   ├── SECURITY_REVIEW.md                   ← R-SEC
│   │   ├── ARCHITECTURE_CLEAN_CODE_REVIEW.md    ← R-ARCH
│   │   ├── PERFORMANCE_REVIEW.md                ← R-PERF
│   │   ├── A11Y_AND_ERROR_HANDLING_REVIEW.md    ← R-A11Y, R-ERR
│   │   └── PROJECT_COMPLIANCE_REVIEW.md         ← R-PROJ (user-filled template, empty)
│   ├── templates/
│   │   └── REPORT.md                            ← final report template
│   ├── reports/                                 ← generated reviews (gitignored)
│   └── examples/
│       ├── subagent-prompt.md
│       └── subagent-output.json
└── angular-review-kata-rendering-events/        ← kata variant (R-KATA pre-filled)
    ├── ORCHESTRATION.md                         ← (identical to angular-review's)
    ├── SKILL.md                                 ← Claude Code entry, name: angular-review-kata-rendering-events
    ├── angular-review-kata-rendering-events.prompt.md  ← Copilot entry
    ├── angular-review-kata-rendering-events.codex.md   ← Codex entry
    ├── references/
    │   ├── SECURITY_REVIEW.md                   ← (identical)
    │   ├── ARCHITECTURE_CLEAN_CODE_REVIEW.md    ← (identical)
    │   ├── PERFORMANCE_REVIEW.md                ← (identical)
    │   ├── A11Y_AND_ERROR_HANDLING_REVIEW.md    ← (identical)
    │   └── PROJECT_COMPLIANCE_REVIEW.md         ← R-KATA-001..013, pre-filled from kata README
    ├── templates/REPORT.md                      ← (identical)
    └── examples/                                ← (identical)
```

---

## License

[MIT](./LICENSE)
