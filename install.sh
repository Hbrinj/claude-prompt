#!/usr/bin/env bash
# install.sh — Install or update claude-prompt (git clone) and wire up agents/skills
#
# Usage:
#   ./install.sh [--global|--project] [--dry-run] [--help]
#
# Auto-detects install vs update: if the clone directory already exists it pulls
# the latest changes; otherwise it performs a fresh clone.

# Ensure bash-compatible array behaviour when piped to zsh (curl | zsh)
if [ -n "${ZSH_VERSION:-}" ]; then
  setopt KSH_ARRAYS NO_NOMATCH 2>/dev/null
fi

set -euo pipefail

REPO_URL="https://github.com/Hbrinj/claude-prompt.git"
INSTALL_MODE=""   # "project" or "global"
DRY_RUN=false

# ── Summary tracking ────────────────────────────────────────────────────────
ACTIONS=()
SKIPPED=()

record_action()  { ACTIONS+=("$1"); }
record_skipped() { SKIPPED+=("$1"); }

print_summary() {
  echo ""
  echo "══════════════════════════════════════"
  if $DRY_RUN; then
    echo "  Summary (DRY RUN — no changes made)"
  else
    echo "  Summary"
  fi
  echo "══════════════════════════════════════"
  if [ ${#ACTIONS[@]} -gt 0 ]; then
    echo "Actions taken:"
    for a in "${ACTIONS[@]}"; do echo "  ✓ $a"; done
  fi
  if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo "Skipped:"
    for s in "${SKIPPED[@]}"; do echo "  – $s"; done
  fi
  if [ ${#ACTIONS[@]} -eq 0 ] && [ ${#SKIPPED[@]} -eq 0 ]; then
    echo "  Nothing to do."
  fi
  echo "══════════════════════════════════════"
}

# ── Usage ───────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Install or update claude-prompt and wire up agents/skills.

Options:
  --global         Install into ~/.claude/ (git clone)
  --project        Install into the current project's .claude/ (git clone)
  --dry-run        Print every action without executing any
  --help, -h       Print this help message and exit

What this script does:
  Project mode (default when inside a git repo):
    1. Clones (or pulls) ${REPO_URL} into .claude/claude-prompt/
    2. Symlinks agents/ and skills/ from the clone into .claude/
    3. Lets you choose a system prompt and merges it into CLAUDE.md

  Global mode:
    1. Clones (or pulls) ${REPO_URL} into ~/.claude/claude-prompt/
    2. Symlinks agents/, skills/, commands/, and hooks/ into ~/.claude/
    3. Lets you choose a system prompt and merges it into ~/.claude/CLAUDE.md
    4. Prints the settings.json hooks block to add manually
       (this script never edits settings.json)

EOF
}

# ── Argument parsing ─────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --help|-h)
      usage
      exit 0
      ;;
    --global)
      INSTALL_MODE="global"
      ;;
    --project)
      INSTALL_MODE="project"
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    -*)
      echo "Error: Unknown option: $arg" >&2
      usage >&2
      exit 1
      ;;
    *)
      echo "Error: Unexpected argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# ── Preflight checks ────────────────────────────────────────────────────────
check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: Required command '$1' not found. Please install it and retry." >&2
    exit 1
  fi
}

check_command git
check_command ln
check_command cp
check_command awk

# ── Install mode selection ──────────────────────────────────────────────────
IN_GIT_REPO=false
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  IN_GIT_REPO=true
fi

if [ -z "${INSTALL_MODE}" ]; then
  if $IN_GIT_REPO; then
    echo ""
    echo "Where would you like to install claude-prompt?"
    echo "  [1] Project — installs into this project's .claude/ (git clone)"
    echo "  [2] Global  — installs into ~/.claude/ (git clone)"
    printf "  Select (1 or 2): "
    read -r mode_choice </dev/tty
    case "${mode_choice}" in
      1) INSTALL_MODE="project" ;;
      2) INSTALL_MODE="global" ;;
      *)
        echo "  Invalid choice '${mode_choice}'. Defaulting to project install." >&2
        INSTALL_MODE="project"
        ;;
    esac
  else
    echo "Not inside a git repository. Proceeding with global install into ~/.claude/."
    INSTALL_MODE="global"
  fi
fi

# Validate mode requirements
if [ "${INSTALL_MODE}" = "project" ] && ! $IN_GIT_REPO; then
  echo "Error: --project requires being inside a git repository." >&2
  exit 1
fi

# ── Resolve paths ───────────────────────────────────────────────────────────
if [ "${INSTALL_MODE}" = "project" ]; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel)"
  if [ "$(pwd)" != "${PROJECT_ROOT}" ]; then
    echo "Error: Run this script from the project root: ${PROJECT_ROOT}" >&2
    exit 1
  fi
  CLONE_PATH="${PROJECT_ROOT}/.claude/claude-prompt"
  CLAUDE_DIR="${PROJECT_ROOT}/.claude"
  TARGET_CLAUDE_MD="${PROJECT_ROOT}/CLAUDE.md"
else
  CLONE_PATH="${HOME}/.claude/claude-prompt"
  CLAUDE_DIR="${HOME}/.claude"
  TARGET_CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
fi

# ── Portable hash ───────────────────────────────────────────────────────────
compute_hash() {
  local file="$1"
  if command -v sha1sum >/dev/null 2>&1; then
    sha1sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 1 "$file" | awk '{print $1}'
  elif command -v md5sum >/dev/null 2>&1; then
    md5sum "$file" | awk '{print $1}'
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q "$file"
  else
    echo "Error: No hash command found (sha1sum, shasum, md5sum, or md5)" >&2
    exit 1
  fi
}

# Separator marker for CLAUDE.md managed block
SEPARATOR_MARKER="# --- claude-prompt start ---"

# ── ensure_symlink ──────────────────────────────────────────────────────────
# Unified create / verify / repair symlink function
ensure_symlink() {
  local link_path="$1"
  local target="$2"
  local label="$3"

  if [ ! -d "${target}" ]; then
    echo "  Warning: Target directory '${target}' does not exist. Skipping ${label} symlink." >&2
    record_skipped "${label} symlink (target directory missing)"
    return
  fi

  if [ -L "${link_path}" ]; then
    current_target="$(readlink "${link_path}")"
    if [ "${current_target}" = "${target}" ]; then
      if [ -e "${link_path}" ]; then
        echo "  ✓ ${label} symlink OK"
        record_skipped "${label} symlink (already correct)"
      else
        # Broken symlink pointing to the right path — repair
        if $DRY_RUN; then
          echo "  [dry-run] Would repair broken ${label} symlink: ${link_path} → ${target}"
          record_action "[dry-run] Repair broken ${label} symlink"
        else
          ln -sf "${target}" "${link_path}"
          echo "  ✓ Repaired ${label} symlink: ${link_path} → ${target}"
          record_action "Repaired ${label} symlink → ${target}"
        fi
      fi
    else
      echo "  ${link_path} currently points to '${current_target}'"
      echo "  Expected target: '${target}'"
      printf '  Update %s symlink to the new target? (y/N): ' "${label}"
      read -r fix_choice </dev/tty
      if [ "${fix_choice}" = "y" ] || [ "${fix_choice}" = "Y" ]; then
        if $DRY_RUN; then
          echo "  [dry-run] Would update ${label} symlink: ${link_path} → ${target}"
          record_action "[dry-run] Update ${label} symlink"
        else
          ln -sfn "${target}" "${link_path}"
          echo "  ✓ Updated ${link_path} → ${target}"
          record_action "Updated ${label} symlink → ${target}"
        fi
      else
        echo "  Skipping ${label} symlink."
        record_skipped "${label} symlink (kept existing target: ${current_target})"
      fi
    fi
  elif [ -d "${link_path}" ]; then
    echo "  ${link_path} is a real directory (not a symlink)."
    printf "  Remove it and create %s symlink to '%s'? (y/N): " "${label}" "${target}"
    read -r fix_choice </dev/tty
    if [ "${fix_choice}" = "y" ] || [ "${fix_choice}" = "Y" ]; then
      if $DRY_RUN; then
        echo "  [dry-run] Would remove directory and create ${label} symlink: ${link_path} → ${target}"
        record_action "[dry-run] Replace ${label} directory with symlink"
      else
        rm -rf "${link_path}"
        ln -s "${target}" "${link_path}"
        echo "  ✓ Replaced directory with symlink: ${link_path} → ${target}"
        record_action "Replaced ${label} directory with symlink → ${target}"
      fi
    else
      echo "  Skipping ${label} symlink."
      record_skipped "${label} symlink (kept existing directory at ${link_path})"
    fi
  elif [ -e "${link_path}" ]; then
    echo "  ${link_path} already exists and is not a symlink or directory."
    printf "  Remove it and create %s symlink to '%s'? (y/N): " "${label}" "${target}"
    read -r fix_choice </dev/tty
    if [ "${fix_choice}" = "y" ] || [ "${fix_choice}" = "Y" ]; then
      if $DRY_RUN; then
        echo "  [dry-run] Would remove file and create ${label} symlink: ${link_path} → ${target}"
        record_action "[dry-run] Replace ${label} file with symlink"
      else
        rm -f "${link_path}"
        ln -s "${target}" "${link_path}"
        echo "  ✓ Replaced file with symlink: ${link_path} → ${target}"
        record_action "Replaced ${label} file with symlink → ${target}"
      fi
    else
      echo "  Skipping ${label} symlink."
      record_skipped "${label} symlink (kept existing file at ${link_path})"
    fi
  else
    # Missing — create
    if $DRY_RUN; then
      echo "  [dry-run] Would create ${label} symlink: ${link_path} → ${target}"
      record_action "[dry-run] Create ${label} symlink"
    else
      ln -s "${target}" "${link_path}"
      echo "  ✓ Linked ${link_path} → ${target}"
      record_action "Symlinked ${label} → ${target}"
    fi
  fi
}

# ── Step 1: Clone or pull ──────────────────────────────────────────────────
echo "→ Setting up claude-prompt in ${CLONE_PATH}…"

IS_UPDATE=false

if [ -d "${CLONE_PATH}/.git" ]; then
  IS_UPDATE=true
  echo "  Repository already cloned. Pulling latest…"

  if $DRY_RUN; then
    echo "  [dry-run] Would run: git -C ${CLONE_PATH} pull --ff-only"
    record_action "[dry-run] git pull --ff-only in ${CLONE_PATH}"
  else
    git -C "${CLONE_PATH}" pull --ff-only
    record_action "Pulled latest changes into ${CLONE_PATH}"
  fi
else
  echo "  Cloning ${REPO_URL}…"

  if $DRY_RUN; then
    echo "  [dry-run] Would run: git clone ${REPO_URL} ${CLONE_PATH}"
    record_action "[dry-run] git clone ${REPO_URL} → ${CLONE_PATH}"
  else
    mkdir -p "$(dirname "${CLONE_PATH}")"
    git clone "${REPO_URL}" "${CLONE_PATH}"
    record_action "Cloned ${REPO_URL} → ${CLONE_PATH}"
  fi
fi

# ── Step 2: Show changelog (update path only) ──────────────────────────────
if $IS_UPDATE && ! $DRY_RUN; then
  echo "→ Changes since last update:"
  changes="$(git -C "${CLONE_PATH}" log "HEAD@{1}..HEAD" --oneline 2>/dev/null || true)"
  if [ -z "${changes}" ]; then
    echo "  Already up to date."
  else
    printf '%s\n' "${changes}" | sed 's/^/  /'
  fi
fi

# ── Step 3: Symlinks ───────────────────────────────────────────────────────
# Ensure .claude dir exists
if [ ! -d "${CLAUDE_DIR}" ]; then
  if $DRY_RUN; then
    echo "  [dry-run] Would create directory ${CLAUDE_DIR}"
  else
    mkdir -p "${CLAUDE_DIR}"
    record_action "Created directory ${CLAUDE_DIR}"
  fi
fi

echo "→ Wiring up symlinks in ${CLAUDE_DIR}…"
ensure_symlink "${CLAUDE_DIR}/agents" "${CLONE_PATH}/agents" "agents"
ensure_symlink "${CLAUDE_DIR}/skills" "${CLONE_PATH}/skills" "skills"

# Global mode: also symlink skills as commands (Claude Code reads ~/.claude/commands/)
# and the guard hooks (wired into settings.json manually — see snippet below)
if [ "${INSTALL_MODE}" = "global" ]; then
  ensure_symlink "${CLAUDE_DIR}/commands" "${CLONE_PATH}/skills" "commands"
  ensure_symlink "${CLAUDE_DIR}/hooks" "${CLONE_PATH}/scripts/hooks" "hooks"
fi

# ── Step 4: Select and merge system prompt → CLAUDE.md ─────────────────────
echo "→ Handling CLAUDE.md…"

# Discover available system prompt files
SYSTEM_PROMPTS=()

# Only scan if clone path exists (skip during dry-run of fresh install)
if [ -d "${CLONE_PATH}" ]; then
  while IFS= read -r -d '' sp_file; do
    SYSTEM_PROMPTS+=("$(basename "$sp_file")")
  done < <(find "${CLONE_PATH}" -maxdepth 1 -name '*SYSTEM_PROMPT*.md' -print0 | sort -z)
fi

PROMPT_COUNT=${#SYSTEM_PROMPTS[@]}

# Detect previously selected system prompt from existing CLAUDE.md
PREVIOUS_SOURCE=""
if [ -f "${TARGET_CLAUDE_MD}" ]; then
  PREVIOUS_SOURCE="$(grep -oP '(?<=^# claude-prompt-source: ).+' "${TARGET_CLAUDE_MD}" 2>/dev/null || true)"
fi

# ── pick_system_prompt — interactive selection ─────────────────────────────
pick_system_prompt() {
  if [ "${PROMPT_COUNT}" -eq 1 ]; then
    SELECTED_PROMPT="${SYSTEM_PROMPTS[0]}"
    echo "  Using system prompt: ${SELECTED_PROMPT}"
  elif [ -n "${PREVIOUS_SOURCE}" ] && [ -f "${CLONE_PATH}/${PREVIOUS_SOURCE}" ]; then
    echo ""
    echo "  Available system prompts:"
    for ((i = 0; i < PROMPT_COUNT; i++)); do
      marker=""
      if [ "${SYSTEM_PROMPTS[$i]}" = "${PREVIOUS_SOURCE}" ]; then marker=" (current)"; fi
      echo "    [$((i + 1))] ${SYSTEM_PROMPTS[$i]}${marker}"
    done
    printf "  Keep current or pick a new one? Enter choice (1-%d) or press Enter to keep [%s]: " "${PROMPT_COUNT}" "${PREVIOUS_SOURCE}"
    read -r sp_choice </dev/tty

    if [ -z "${sp_choice}" ]; then
      SELECTED_PROMPT="${PREVIOUS_SOURCE}"
    elif [[ "${sp_choice}" =~ ^[0-9]+$ ]] && [ "${sp_choice}" -ge 1 ] && [ "${sp_choice}" -le "${PROMPT_COUNT}" ]; then
      SELECTED_PROMPT="${SYSTEM_PROMPTS[$((sp_choice - 1))]}"
    else
      echo "  Invalid choice '${sp_choice}'. Keeping ${PREVIOUS_SOURCE}." >&2
      SELECTED_PROMPT="${PREVIOUS_SOURCE}"
    fi
    echo "  Using system prompt: ${SELECTED_PROMPT}"
  else
    if [ -n "${PREVIOUS_SOURCE}" ]; then
      echo "  Warning: Previously selected '${PREVIOUS_SOURCE}' no longer exists."
    fi
    echo ""
    echo "  Available system prompts:"
    for ((i = 0; i < PROMPT_COUNT; i++)); do
      echo "    [$((i + 1))] ${SYSTEM_PROMPTS[$i]}"
    done
    printf "  Select a system prompt (1-%d): " "${PROMPT_COUNT}"
    read -r sp_choice </dev/tty

    if [[ "${sp_choice}" =~ ^[0-9]+$ ]] && [ "${sp_choice}" -ge 1 ] && [ "${sp_choice}" -le "${PROMPT_COUNT}" ]; then
      SELECTED_PROMPT="${SYSTEM_PROMPTS[$((sp_choice - 1))]}"
    else
      echo "  Invalid choice '${sp_choice}'. Defaulting to ${SYSTEM_PROMPTS[0]}." >&2
      SELECTED_PROMPT="${SYSTEM_PROMPTS[0]}"
    fi
    echo "  Using system prompt: ${SELECTED_PROMPT}"
  fi

  SYSTEM_PROMPT_FILE="${CLONE_PATH}/${SELECTED_PROMPT}"
}

# ── merge_claude_md — strip-then-replace or create fresh ───────────────────
merge_claude_md() {
  local new_hash="$1"

  # Check idempotency: if source unchanged and hash matches, skip
  if [ -f "${TARGET_CLAUDE_MD}" ]; then
    existing_source="$(grep -oP '(?<=^# claude-prompt-source: ).+' "${TARGET_CLAUDE_MD}" 2>/dev/null || true)"
    source_changed=false
    if [ -n "${existing_source}" ] && [ "${existing_source}" != "${SELECTED_PROMPT}" ]; then
      source_changed=true
    fi

    if ! $source_changed && grep -qF "# claude-prompt-hash: ${new_hash}" "${TARGET_CLAUDE_MD}" 2>/dev/null; then
      echo "  CLAUDE.md already up to date. Skipping."
      record_skipped "CLAUDE.md update (already up to date, hash matches)"
      return
    fi
  fi

  if [ ! -f "${TARGET_CLAUDE_MD}" ]; then
    # No CLAUDE.md — create it fresh
    if $DRY_RUN; then
      echo "  [dry-run] Would create CLAUDE.md from ${SELECTED_PROMPT}"
      record_action "[dry-run] Create CLAUDE.md from ${SELECTED_PROMPT}"
    else
      cp "${SYSTEM_PROMPT_FILE}" "${TARGET_CLAUDE_MD}"
      echo "  ✓ CLAUDE.md created from ${SELECTED_PROMPT}"
      record_action "Created CLAUDE.md from ${SELECTED_PROMPT}"
    fi
    return
  fi

  # CLAUDE.md exists — prompt for merge strategy
  echo ""
  echo "  CLAUDE.md already exists. How should ${SELECTED_PROMPT} be applied?"
  echo "    [1] Add/replace system prompt section (keeps your custom content)"
  echo "    [2] Replace entire CLAUDE.md (overwrites everything)"
  echo "    [3] Skip — leave CLAUDE.md untouched"
  printf "  Enter 1, 2, or 3: "
  read -r claude_choice </dev/tty

  case "${claude_choice}" in
    1)
      if $DRY_RUN; then
        if grep -qF "${SEPARATOR_MARKER}" "${TARGET_CLAUDE_MD}" 2>/dev/null; then
          echo "  [dry-run] Would replace existing system prompt section with ${SELECTED_PROMPT}"
          record_action "[dry-run] Replace system prompt section in CLAUDE.md"
        else
          echo "  [dry-run] Would append ${SELECTED_PROMPT} to CLAUDE.md"
          record_action "[dry-run] Append ${SELECTED_PROMPT} to CLAUDE.md"
        fi
      else
        tmpfile="$(mktemp)"
        trap 'rm -f "${tmpfile}"' EXIT

        if grep -qF "${SEPARATOR_MARKER}" "${TARGET_CLAUDE_MD}" 2>/dev/null; then
          awk -v sep="${SEPARATOR_MARKER}" '
            $0 == sep { in_block=1; next }
            in_block && /^# claude-prompt-hash:/ { in_block=0; next }
            in_block { next }
            { print }
          ' "${TARGET_CLAUDE_MD}" > "${tmpfile}"
          action_label="Replaced system prompt section with ${SELECTED_PROMPT}"
        else
          cp "${TARGET_CLAUDE_MD}" "${tmpfile}"
          action_label="Added ${SELECTED_PROMPT} section to CLAUDE.md"
        fi

        {
          echo ""
          echo "${SEPARATOR_MARKER}"
          echo "# claude-prompt-source: ${SELECTED_PROMPT}"
          cat "${SYSTEM_PROMPT_FILE}"
          echo "# claude-prompt-hash: ${new_hash}"
        } >> "${tmpfile}"

        mv "${tmpfile}" "${TARGET_CLAUDE_MD}"
        trap - EXIT
        echo "  ✓ ${action_label}"
        record_action "${action_label}"
      fi
      ;;
    2)
      printf "  This will overwrite your existing CLAUDE.md. Are you sure? (y/N): "
      read -r overwrite_confirm </dev/tty
      if [ "${overwrite_confirm}" = "y" ] || [ "${overwrite_confirm}" = "Y" ]; then
        if $DRY_RUN; then
          echo "  [dry-run] Would overwrite CLAUDE.md with ${SELECTED_PROMPT}"
          record_action "[dry-run] Overwrite CLAUDE.md with ${SELECTED_PROMPT}"
        else
          cp "${SYSTEM_PROMPT_FILE}" "${TARGET_CLAUDE_MD}"
          echo "  ✓ Replaced CLAUDE.md with ${SELECTED_PROMPT}"
          record_action "Replaced CLAUDE.md with ${SELECTED_PROMPT}"
        fi
      else
        echo "  Overwrite cancelled. CLAUDE.md left untouched."
        record_skipped "CLAUDE.md overwrite (cancelled by user)"
      fi
      ;;
    3)
      echo "  Skipped CLAUDE.md"
      record_skipped "CLAUDE.md update (skipped by user)"
      ;;
    *)
      echo "  Invalid choice '${claude_choice}'. Skipping CLAUDE.md." >&2
      record_skipped "CLAUDE.md update (invalid input: '${claude_choice}')"
      ;;
  esac
}

# ── Run prompt selection and merge ─────────────────────────────────────────
if [ "${PROMPT_COUNT}" -eq 0 ]; then
  echo "  Warning: No system prompt files found. Skipping." >&2
  record_skipped "CLAUDE.md merge (no system prompt files found)"
else
  pick_system_prompt
  new_hash="$(compute_hash "${SYSTEM_PROMPT_FILE}")"
  merge_claude_md "${new_hash}"
fi

# ── Final summary ──────────────────────────────────────────────────────────
print_summary

# ── Hooks wiring snippet (global mode only) ────────────────────────────────
# install.sh NEVER edits settings.json — it prints the block for the user to
# add manually. See scripts/hooks/README.md for what each guard does.
if [ "${INSTALL_MODE}" = "global" ]; then
  cat <<'EOF'

→ Guard hooks (manual step — install.sh never edits settings.json)
  To enable the main/master guard hooks, add this to ~/.claude/settings.json
  (merge into an existing "hooks" key if you already have one):

  {
    "hooks": {
      "PreToolUse": [
        {
          "matcher": "Edit|Write|NotebookEdit",
          "hooks": [
            { "type": "command", "command": "bash \"$HOME/.claude/hooks/guard-main-edit.sh\"" }
          ]
        },
        {
          "matcher": "Bash",
          "hooks": [
            { "type": "command", "command": "bash \"$HOME/.claude/hooks/guard-push-main.sh\"" }
          ]
        }
      ]
    }
  }

  Both hooks require jq (preinstalled on recent macOS; otherwise
  `brew install jq` / `apt install jq`). Details, the fail-open rules, and
  the ~/.claude/hooks-exceptions format: scripts/hooks/README.md in the clone.
EOF
fi
