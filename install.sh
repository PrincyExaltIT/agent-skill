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
need_val() { [[ $# -ge 2 ]] || { echo "Flag $1 requires a value." >&2; exit 2; }; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)    need_val "$@"; SKILL="$2"; shift 2 ;;
    --provider) need_val "$@"; PROVIDER="$2"; shift 2 ;;
    --scope)    need_val "$@"; SCOPE="$2"; shift 2 ;;
    --with-mcp) need_val "$@"; WITH_MCP="$2"; shift 2 ;;
    --ref)      need_val "$@"; REF="$2"; shift 2 ;;
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

# Defence in depth: $SKILL is interpolated into destination paths and the git-fetch
# subpath. Reject anything that could escape the install root or break path
# construction (path separators, '..', null bytes, leading dashes).
if [[ ! "$SKILL" =~ ^[A-Za-z0-9._-]+$ ]] || [[ "$SKILL" == .* ]] || [[ "$SKILL" == -* ]]; then
  err "Invalid --skill value: '$SKILL'. Allowed: [A-Za-z0-9._-]+, not starting with '.' or '-'."
  exit 2
fi

# $REF is passed to `git checkout` (and as the value of `git clone --branch`). A leading
# '-' would let `git checkout` interpret the ref as a flag, enabling option injection.
# Note: we DON'T add `--` before $REF in `git checkout` because there `--` separates
# pathspecs (i.e. `git checkout -- foo` restores file 'foo', NOT switch to ref 'foo');
# validating the ref shape is the correct fix for this surface.
if [[ "$REF" == -* ]]; then
  err "Invalid --ref value: '$REF'. Refs starting with '-' are not allowed."
  exit 2
fi

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
    # When piped (curl|bash) stdin is the script; read from the controlling TTY instead.
    # When stdin IS a TTY (running locally), read from the inherited stdin directly.
    if [[ -t 0 ]]; then
      read -r -p "$DEST already exists. Overwrite? [y/N] " ans || ans=""
    elif [[ -r /dev/tty ]]; then
      read -r -p "$DEST already exists. Overwrite? [y/N] " ans </dev/tty || ans=""
    else
      # Non-interactive with no TTY (CI piped) — refuse to clobber without --yes.
      err "$DEST already exists and no TTY is available for confirmation. Re-run with --yes to overwrite."
      exit 1
    fi
    case "$ans" in
      y|Y|yes|YES)
        rm -rf "$DEST.bak"
        mv "$DEST" "$DEST.bak"
        warn "Existing install backed up to $DEST.bak" ;;
      *) err "Aborted (use --yes to skip this prompt)."; exit 1 ;;
    esac
  fi
fi

# ── resolve clone URL (supports GitHub shortcut, full URL, or local path) ──
if [[ "$REPO" =~ ^(https?://|git@|file://|ssh://) ]]; then
  CLONE_URL="$REPO"
elif [[ "$REPO" =~ ^(\.\.?/|/|[A-Za-z]:) ]]; then
  CLONE_URL="$REPO"
else
  CLONE_URL="https://github.com/$REPO.git"
fi

# ── fetch the skill ────────────────────────────────────────────────────────
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
info "Fetching $CLONE_URL@$REF…"
# Fast path: shallow clone with --branch works for branches and tags.
# Fallback: when $REF is a commit SHA (or any ref --branch can't resolve), do a full
# clone + checkout. The `--` separator before $CLONE_URL forces git to treat it as
# the repository argument, not a flag (defence in depth).
if ! git clone --depth 1 --quiet --branch "$REF" -- "$CLONE_URL" "$TMP" 2>/dev/null; then
  rm -rf "$TMP"
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  if ! git clone --quiet -- "$CLONE_URL" "$TMP" 2>/dev/null; then
    err "git clone failed (url: $CLONE_URL)."
    exit 1
  fi
  # $REF is already validated above to not start with '-', so `git checkout $REF` is safe.
  if ! git -C "$TMP" checkout --quiet "$REF" 2>/dev/null; then
    err "git checkout failed (ref: $REF). Branch/tag/commit not found in $CLONE_URL."
    exit 1
  fi
fi
[[ -d "$TMP/$SKILL" ]] || { err "Skill '$SKILL' not found in source."; exit 1; }

mkdir -p "$(dirname "$DEST")"
cp -r "$TMP/$SKILL" "$DEST"
ok "Bundle installed at $DEST"

# ── place the provider-specific prompt entry ───────────────────────────────
# Each skill ships its provider entries under predictable names so the installer
# is skill-agnostic: <skill>.prompt.md (Copilot) and <skill>.codex.md (Codex).
if [[ -n "$PROMPT_DEST" ]]; then
  case "$PROVIDER" in
    copilot) SRC_PROMPT="$DEST/${SKILL}.prompt.md" ;;
    codex)   SRC_PROMPT="$DEST/${SKILL}.codex.md" ;;
  esac
  if [[ ! -f "$SRC_PROMPT" ]]; then
    err "Skill '$SKILL' is missing the expected $PROVIDER entry file: $SRC_PROMPT"
    err "Expected naming convention: \${SKILL}.prompt.md for Copilot, \${SKILL}.codex.md for Codex."
    exit 1
  fi
  mkdir -p "$(dirname "$PROMPT_DEST")"
  # Back up any existing prompt the same way we back up the bundle, so customisations aren't silently lost.
  if [[ -e "$PROMPT_DEST" ]]; then
    rm -f "$PROMPT_DEST.bak"
    mv "$PROMPT_DEST" "$PROMPT_DEST.bak"
    warn "Existing prompt backed up to $PROMPT_DEST.bak"
  fi
  cp "$SRC_PROMPT" "$PROMPT_DEST"
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
