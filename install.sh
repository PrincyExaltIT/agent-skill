#!/usr/bin/env bash
# agent-skill installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --skill angular-review --provider claude --scope project --with-mcp playwright

set -euo pipefail

REPO="${AGENT_SKILL_REPO:-PrincyExaltIT/agent-skill}"
SKILL="${SKILL:-angular-review}"
PROVIDER="${PROVIDER:-auto}"
SCOPE="${SCOPE:-project}"
WITH_MCP="${WITH_MCP:-}"
REF="${REF:-main}"
ASSUME_YES="${ASSUME_YES:-0}"

print_help() {
  cat <<'EOF'
agent-skill installer

Usage (piped):
  curl -fsSL https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/install.sh | bash
  curl -fsSL .../install.sh | bash -s -- --provider claude --with-mcp playwright

Flags (env vars in caps also work):
  --skill <name>      Skill to install                   (default: angular-review)
  --provider <name>   claude | copilot | codex | auto    (default: auto)
  --scope <name>      project | global                   (default: project)
  --with-mcp <name>   Optional MCP to register: playwright
  --ref <git-ref>     Branch / tag / commit to install   (default: main)
  --yes, -y           Skip overwrite prompt
  --help, -h          Show this help

Auto-detection (first match wins, override with --provider):
  .claude/ | .mcp.json | CLAUDE.md  → claude
  .github/                          → copilot
  .codex/ | AGENTS.md               → codex
EOF
}

# ── parse args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)    SKILL="$2"; shift 2 ;;
    --provider) PROVIDER="$2"; shift 2 ;;
    --scope)    SCOPE="$2"; shift 2 ;;
    --with-mcp) WITH_MCP="$2"; shift 2 ;;
    --ref)      REF="$2"; shift 2 ;;
    --yes|-y)   ASSUME_YES=1; shift ;;
    --help|-h)  print_help; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; echo "Run with --help for usage." >&2; exit 2 ;;
  esac
done

c_blue=$'\033[34m'; c_green=$'\033[32m'; c_yellow=$'\033[33m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_reset=$'\033[0m'
info()  { echo "${c_blue}ℹ${c_reset} $*"; }
ok()    { echo "${c_green}✓${c_reset} $*"; }
warn()  { echo "${c_yellow}⚠${c_reset} $*" >&2; }
err()   { echo "${c_red}✗${c_reset} $*" >&2; }

# ── sanity ─────────────────────────────────────────────────────────────────
command -v git >/dev/null 2>&1 || { err "git is required but not found in PATH."; exit 1; }

# ── auto-detect provider ───────────────────────────────────────────────────
detect_provider() {
  local hits=()
  if [[ -d .claude ]] || [[ -f .mcp.json ]] || [[ -f CLAUDE.md ]]; then hits+=("claude"); fi
  if [[ -d .github ]]; then hits+=("copilot"); fi
  if [[ -d .codex ]] || [[ -f AGENTS.md ]]; then hits+=("codex"); fi
  if [[ ${#hits[@]} -eq 0 ]]; then
    err "Cannot auto-detect provider from project markers."
    err "Pass --provider claude|copilot|codex (or run from inside a project with an AI agent already configured)."
    exit 1
  fi
  if [[ ${#hits[@]} -gt 1 ]]; then
    warn "Multiple provider markers detected: ${hits[*]}"
    warn "Defaulting to '${hits[0]}'. Override with --provider <name> if wrong."
  fi
  echo "${hits[0]}"
}
if [[ "$PROVIDER" == "auto" ]]; then PROVIDER=$(detect_provider); fi

# ── compute destination paths ──────────────────────────────────────────────
PROMPT_DEST=""
case "$PROVIDER:$SCOPE" in
  claude:project)  DEST=".claude/skills/$SKILL" ;;
  claude:global)   DEST="$HOME/.claude/skills/$SKILL" ;;
  copilot:project) DEST=".github/agent-skills/$SKILL"
                   PROMPT_DEST=".github/prompts/$SKILL.prompt.md" ;;
  copilot:global)  err "Copilot has no user-global skills path. Use --scope project."; exit 1 ;;
  codex:project)   DEST=".codex/agent-skills/$SKILL"
                   PROMPT_DEST=".codex/prompts/$SKILL.md" ;;
  codex:global)    DEST="$HOME/.codex/agent-skills/$SKILL"
                   PROMPT_DEST="$HOME/.codex/prompts/$SKILL.md" ;;
  *) err "Unsupported provider/scope: $PROVIDER/$SCOPE"; exit 2 ;;
esac

info "Installing ${c_blue}$SKILL${c_reset} for ${c_blue}$PROVIDER${c_reset} (${SCOPE}) → ${c_dim}$DEST${c_reset}"

# ── confirm overwrite if needed ────────────────────────────────────────────
if [[ -e "$DEST" ]]; then
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    warn "$DEST exists; backing up to $DEST.bak"
    rm -rf "$DEST.bak"
    mv "$DEST" "$DEST.bak"
  else
    # When piped (curl|bash), stdin is the script — read from the controlling TTY instead.
    if [[ -t 0 ]]; then INPUT_TTY=0; else INPUT_TTY="/dev/tty"; fi
    read -r -p "$DEST already exists. Overwrite? [y/N] " ans <"$INPUT_TTY" || ans=""
    case "$ans" in
      y|Y|yes|YES)
        rm -rf "$DEST.bak"
        mv "$DEST" "$DEST.bak"
        warn "Existing install backed up to $DEST.bak" ;;
      *) err "Aborted (use --yes to skip this prompt)."; exit 1 ;;
    esac
  fi
fi

# ── fetch the skill ────────────────────────────────────────────────────────
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
info "Fetching $REPO@$REF…"
git clone --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$TMP" >/dev/null 2>&1 \
  || { err "git clone failed (repo: $REPO, ref: $REF)."; exit 1; }
[[ -d "$TMP/$SKILL" ]] || { err "Skill '$SKILL' not found in repo."; exit 1; }

mkdir -p "$(dirname "$DEST")"
cp -r "$TMP/$SKILL" "$DEST"
ok "Bundle installed at $DEST"

# ── place the provider-specific prompt entry ───────────────────────────────
if [[ -n "$PROMPT_DEST" ]]; then
  mkdir -p "$(dirname "$PROMPT_DEST")"
  case "$PROVIDER" in
    copilot) cp "$DEST/angular-review.prompt.md" "$PROMPT_DEST" ;;
    codex)   cp "$DEST/codex-prompt.md" "$PROMPT_DEST" ;;
  esac
  ok "Prompt entry placed at $PROMPT_DEST"
fi

# ── optional: register Playwright MCP ──────────────────────────────────────
register_mcp_claude() {
  if command -v claude >/dev/null 2>&1; then
    if claude mcp add playwright -- npx -y "@playwright/mcp@latest" >/dev/null 2>&1; then
      ok "Registered playwright MCP via 'claude mcp add'"
      return
    fi
  fi
  local f=".mcp.json"
  if [[ -f $f ]]; then
    warn "$f exists; please add the playwright server manually (see repo README)."
  else
    cat > "$f" <<'EOF'
{
  "mcpServers": {
    "playwright": { "command": "npx", "args": ["-y", "@playwright/mcp@latest"] }
  }
}
EOF
    ok "Wrote $f with playwright MCP server"
  fi
}
register_mcp_copilot() {
  local f=".vscode/mcp.json"
  mkdir -p .vscode
  if [[ -f $f ]]; then
    warn "$f exists; please add the playwright server manually (see repo README)."
  else
    cat > "$f" <<'EOF'
{
  "servers": {
    "playwright": { "command": "npx", "args": ["-y", "@playwright/mcp@latest"] }
  }
}
EOF
    ok "Wrote $f with playwright MCP server"
  fi
}
register_mcp_codex() {
  local f="$HOME/.codex/config.toml"
  mkdir -p "$HOME/.codex"
  if [[ -f $f ]] && grep -q "^\[mcp_servers\.playwright\]" "$f"; then
    warn "playwright MCP already present in $f."
  else
    {
      echo ""
      echo "[mcp_servers.playwright]"
      echo 'command = "npx"'
      echo 'args = ["-y", "@playwright/mcp@latest"]'
    } >> "$f"
    ok "Appended playwright MCP to $f"
  fi
}

if [[ "$WITH_MCP" == "playwright" ]]; then
  case "$PROVIDER" in
    claude)  register_mcp_claude ;;
    copilot) register_mcp_copilot ;;
    codex)   register_mcp_codex ;;
  esac
elif [[ -n "$WITH_MCP" ]]; then
  warn "Unknown --with-mcp value '$WITH_MCP'. Supported: playwright."
fi

echo ""
ok "Done. Invoke with: ${c_green}/$SKILL [target]${c_reset}"
echo "${c_dim}Optional: install Playwright test runner for repeatable e2e:  npm i -D @playwright/test && npx playwright install chromium${c_reset}"
