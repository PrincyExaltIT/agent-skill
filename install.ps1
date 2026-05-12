#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Installer for agent-skill (Claude Code / GitHub Copilot / OpenAI Codex).

.DESCRIPTION
  Auto-detects the AI provider from project markers, fetches the skill bundle
  via shallow git clone, places it at the correct path, and optionally
  registers the Playwright MCP server.

.EXAMPLE
  # One-liner, auto-detect provider
  irm https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/install.ps1 | iex

.EXAMPLE
  # Explicit provider + scope (with-mcp)
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/install.ps1))) -Skill angular-review -Provider claude -Scope project -WithMcp playwright

.PARAMETER Skill        Skill to install (default: angular-review)
.PARAMETER Provider     claude | copilot | codex | auto (default: auto)
.PARAMETER Scope        project | global (default: project)
.PARAMETER WithMcp      Optional MCP server to register: playwright
.PARAMETER Ref          Git ref (branch / tag / commit) to install from (default: main)
.PARAMETER Yes          Skip overwrite prompt (force overwrite)
#>
[CmdletBinding()]
param(
  [string]$Skill = "angular-review",
  [ValidateSet("claude", "copilot", "codex", "auto")]
  [string]$Provider = "auto",
  [ValidateSet("project", "global")]
  [string]$Scope = "project",
  [ValidateSet("", "playwright")]
  [string]$WithMcp = "",
  [string]$Ref = "main",
  [switch]$Yes
)

$ErrorActionPreference = "Stop"
$repo = if ($env:AGENT_SKILL_REPO) { $env:AGENT_SKILL_REPO } else { "PrincyExaltIT/agent-skill" }

# ASCII status markers (Unicode glyphs render badly on Windows PowerShell 5.x default encoding)
function Info($msg) { Write-Host "[..] $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "[ok] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[!!] $msg" -ForegroundColor Yellow }
function Err($msg)  { Write-Host "[xx] $msg" -ForegroundColor Red }

# ── sanity ─────────────────────────────────────────────────────────────────
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Err "git is required but not found in PATH."
  exit 1
}

# Defence in depth: $Skill is interpolated into destination paths and the git-fetch
# subpath. Reject anything that could escape the install root.
if ($Skill -notmatch '^[A-Za-z0-9._-]+$' -or $Skill.StartsWith('.') -or $Skill.StartsWith('-')) {
  Err "Invalid -Skill value: '$Skill'. Allowed: [A-Za-z0-9._-]+, not starting with '.' or '-'."
  exit 2
}

# $Ref is passed to `git checkout` (and as the value of `git clone --branch`). A leading
# '-' would let `git checkout` interpret the ref as a flag, enabling option injection.
# Note: we DON'T add `--` before $Ref in `git checkout` because there `--` separates
# pathspecs; validating the ref shape is the correct fix for this surface.
if ($Ref.StartsWith('-')) {
  Err "Invalid -Ref value: '$Ref'. Refs starting with '-' are not allowed."
  exit 2
}

# ── kata variant requires Playwright MCP ───────────────────────────────────
# Step 6 (empirical DOM validation) is integral to the kata grading — the
# reviewer must verify positionnement temps→pixels, somme des largeurs au pic,
# responsivité, etc. against the real rendered DOM. Force -WithMcp playwright
# when this skill is installed, but respect an explicit user choice.
if ($Skill -eq 'angular-review-kata-rendering-events' -and [string]::IsNullOrEmpty($WithMcp)) {
  $WithMcp = 'playwright'
  Info "Skill '$Skill' auto-enables -WithMcp playwright (Step 6 empirical DOM validation is integral to kata grading)."
}

# ── auto-detect provider ───────────────────────────────────────────────────
function Detect-Provider {
  $hits = @()
  if ((Test-Path .claude) -or (Test-Path .mcp.json) -or (Test-Path CLAUDE.md)) { $hits += "claude" }
  if (Test-Path .github) { $hits += "copilot" }
  if ((Test-Path .codex) -or (Test-Path AGENTS.md))  { $hits += "codex" }
  switch ($hits.Count) {
    0 { Err "Cannot auto-detect provider. Pass -Provider claude|copilot|codex."; exit 1 }
    1 { return $hits[0] }
    default {
      Warn "Multiple providers detected: $($hits -join ', '). Defaulting to $($hits[0]). Override with -Provider."
      return $hits[0]
    }
  }
}
if ($Provider -eq "auto") { $Provider = Detect-Provider }

# ── compute destination paths ──────────────────────────────────────────────
$promptDest = $null
switch ("${Provider}:${Scope}") {
  "claude:project"  { $dest = ".claude/skills/$Skill" }
  "claude:global"   { $dest = Join-Path $HOME ".claude/skills/$Skill" }
  "copilot:project" {
    $dest       = ".github/agent-skills/$Skill"
    $promptDest = ".github/prompts/$Skill.prompt.md"
  }
  "copilot:global"  { Err "Copilot has no user-global skills path. Use -Scope project."; exit 1 }
  "codex:project"   {
    $dest       = ".codex/agent-skills/$Skill"
    $promptDest = ".codex/prompts/$Skill.md"
  }
  "codex:global"    {
    $dest       = Join-Path $HOME ".codex/agent-skills/$Skill"
    $promptDest = Join-Path $HOME ".codex/prompts/$Skill.md"
  }
  default { Err "Unsupported provider/scope: $Provider/$Scope"; exit 2 }
}

Info "Installing $Skill for $Provider ($Scope) -> $dest"

# ── confirm overwrite if needed ────────────────────────────────────────────
if (Test-Path $dest) {
  if (-not $Yes) {
    $ans = Read-Host "$dest already exists. Overwrite? [y/N]"
    if ($ans -notmatch '^(y|Y|yes|YES)$') { Err "Aborted."; exit 1 }
  }
  Warn "$dest exists; backing up to $dest.bak"
  if (Test-Path "$dest.bak") { Remove-Item -Recurse -Force "$dest.bak" }
  Move-Item $dest "$dest.bak"
}

# ── resolve clone URL (supports GitHub shortcut, full URL, or local path) ──
if ($repo -match '^(https?://|git@|file://|ssh://)') {
  $cloneUrl = $repo
} elseif ($repo -match '^(\.\.?[/\\]|[/\\]|[A-Za-z]:)') {
  $cloneUrl = $repo
} else {
  $cloneUrl = "https://github.com/$repo.git"
}

# ── fetch the skill ────────────────────────────────────────────────────────
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
try {
  Info "Fetching ${cloneUrl}@${Ref}..."
  # --quiet suppresses git's "Cloning into..." stderr, which PowerShell otherwise treats as an error.
  # Wrap in $ErrorActionPreference=Continue locally so a non-zero exit doesn't throw before we check it.
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = "Continue"

  # Fast path: shallow clone with --branch (works for branches and tags).
  # The `--` separator before $cloneUrl forces git to treat it as the repository
  # argument, not a flag (defence in depth).
  & git clone --depth 1 --quiet --branch $Ref -- $cloneUrl $tmp 2>$null
  $cloneExit = $LASTEXITCODE

  # Fallback: when $Ref is a commit SHA or any ref --branch can't resolve, do a full clone + checkout.
  if ($cloneExit -ne 0) {
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    & git clone --quiet -- $cloneUrl $tmp 2>$null
    $cloneExit = $LASTEXITCODE
    if ($cloneExit -ne 0) {
      $ErrorActionPreference = $prevEAP
      Err "git clone failed (url: $cloneUrl, exit: $cloneExit)."
      exit 1
    }
    # $Ref is already validated above to not start with '-', so `git checkout $Ref` is safe.
    & git -C $tmp checkout --quiet $Ref 2>$null
    $checkoutExit = $LASTEXITCODE
    if ($checkoutExit -ne 0) {
      $ErrorActionPreference = $prevEAP
      Err "git checkout failed (ref: $Ref). Branch/tag/commit not found in $cloneUrl."
      exit 1
    }
  }

  $ErrorActionPreference = $prevEAP
  if (-not (Test-Path (Join-Path $tmp $Skill))) {
    Err "Skill '$Skill' not found in source."
    exit 1
  }
  $parent = Split-Path $dest -Parent
  if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Copy-Item -Recurse (Join-Path $tmp $Skill) $dest
  Ok "Bundle installed at $dest"
}
finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}

# ── place the provider-specific prompt entry ───────────────────────────────
# Each skill ships its provider entries under predictable names so the installer
# is skill-agnostic: <skill>.prompt.md (Copilot) and <skill>.codex.md (Codex).
if ($promptDest) {
  $srcPrompt = switch ($Provider) {
    "copilot" { Join-Path $dest "$Skill.prompt.md" }
    "codex"   { Join-Path $dest "$Skill.codex.md" }
  }
  if (-not (Test-Path $srcPrompt)) {
    Err "Skill '$Skill' is missing the expected $Provider entry file: $srcPrompt"
    Err "Expected naming convention: <skill>.prompt.md for Copilot, <skill>.codex.md for Codex."
    exit 1
  }
  $parent = Split-Path $promptDest -Parent
  if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  # Back up any existing prompt so customisations aren't silently lost (symmetric with bundle backup).
  if (Test-Path $promptDest) {
    if (Test-Path "$promptDest.bak") { Remove-Item -Force "$promptDest.bak" }
    Move-Item $promptDest "$promptDest.bak"
    Warn "Existing prompt backed up to $promptDest.bak"
  }
  Copy-Item $srcPrompt $promptDest
  Ok "Prompt entry placed at $promptDest"
}

# ── optional: register Playwright MCP ──────────────────────────────────────
function Register-Mcp-Claude {
  if (Get-Command claude -ErrorAction SilentlyContinue) {
    try {
      & claude mcp add playwright -- npx -y "@playwright/mcp@latest" | Out-Null
      Ok "Registered playwright MCP via 'claude mcp add'"
      return
    } catch { }
  }
  $f = ".mcp.json"
  if (Test-Path $f) {
    Warn "$f exists; add the playwright server manually (see README)."
  } else {
    @'
{
  "mcpServers": {
    "playwright": { "command": "npx", "args": ["-y", "@playwright/mcp@latest"] }
  }
}
'@ | Set-Content -Encoding UTF8 $f
    Ok "Wrote $f with playwright MCP server"
  }
}
function Register-Mcp-Copilot {
  $f = ".vscode/mcp.json"
  if (-not (Test-Path .vscode)) { New-Item -ItemType Directory -Force -Path .vscode | Out-Null }
  if (Test-Path $f) {
    Warn "$f exists; add the playwright server manually (see README)."
  } else {
    @'
{
  "servers": {
    "playwright": { "command": "npx", "args": ["-y", "@playwright/mcp@latest"] }
  }
}
'@ | Set-Content -Encoding UTF8 $f
    Ok "Wrote $f with playwright MCP server"
  }
}
function Register-Mcp-Codex {
  $codexDir = Join-Path $HOME ".codex"
  if (-not (Test-Path $codexDir)) { New-Item -ItemType Directory -Force -Path $codexDir | Out-Null }
  $f = Join-Path $codexDir "config.toml"
  if ((Test-Path $f) -and (Select-String -Path $f -Pattern '^\[mcp_servers\.playwright\]' -Quiet)) {
    Warn "playwright MCP already present in $f."
  } else {
    Add-Content -Path $f -Value @'

[mcp_servers.playwright]
command = "npx"
args = ["-y", "@playwright/mcp@latest"]
'@
    Ok "Appended playwright MCP to $f"
  }
}

if ($WithMcp -eq "playwright") {
  switch ($Provider) {
    "claude"  { Register-Mcp-Claude }
    "copilot" { Register-Mcp-Copilot }
    "codex"   { Register-Mcp-Codex }
  }
}

Write-Host ""
Ok "Done. Invoke with: /$Skill [target]"
Write-Host "Optional: install Playwright test runner for repeatable e2e:  npm i -D @playwright/test && npx playwright install chromium" -ForegroundColor DarkGray
