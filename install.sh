#!/usr/bin/env bash
# install.sh — Install claude-prompt as a git submodule into a target project
# and wire up agents/ and skills/ into the project-level .claude/

# Ensure bash-compatible array behaviour when piped to zsh (curl | zsh)
if [ -n "${ZSH_VERSION:-}" ]; then
  setopt KSH_ARRAYS NO_NOMATCH 2>/dev/null
fi

set -euo pipefail

REPO_URL="https://github.com/Hbrinj/claude-prompt.git"
DEFAULT_SUBMODULE_PATH=".claude/claude-prompt"

# ── Summary tracking ────────────────────────────────────────────────────────
ACTIONS=()
SKIPPED=()

record_action()  { ACTIONS+=("$1"); }
record_skipped() { SKIPPED+=("$1"); }

print_summary() {
  echo ""
  echo "══════════════════════════════════════"
  echo "  Install Summary"
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
Usage: $0 [OPTIONS] [SUBMODULE_PATH]

Install claude-prompt as a git submodule and wire up agents/skills into the project-level .claude/.

Arguments:
  SUBMODULE_PATH   Path relative to the target project root where the submodule
                   will be added. (default: ${DEFAULT_SUBMODULE_PATH})

Options:
  --help, -h       Print this help message and exit

What this script does:
  1. Adds ${REPO_URL} as a git submodule at SUBMODULE_PATH
  2. Runs: git submodule update --init --recursive
  3. Symlinks agents/ and skills/ from the submodule into .claude/
  4. Lets you choose a system prompt (standard or autonomous) and merges it into CLAUDE.md

EOF
}

# ── Argument parsing ─────────────────────────────────────────────────────────
SUBMODULE_PATH="${DEFAULT_SUBMODULE_PATH}"

for arg in "$@"; do
  case "$arg" in
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $arg" >&2
      usage >&2
      exit 1
      ;;
    *)
      SUBMODULE_PATH="$arg"
      ;;
  esac
done

# ── Preflight checks ─────────────────────────────────────────────────────────
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

# Must be run from the root of a git repository
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: Not inside a git repository. Run this script from your project root." >&2
  exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
if [ "$(pwd)" != "${PROJECT_ROOT}" ]; then
  echo "Error: Run this script from the project root: ${PROJECT_ROOT}" >&2
  exit 1
fi

SUBMODULE_ABS="${PROJECT_ROOT}/${SUBMODULE_PATH}"

# ── Portable hash ─────────────────────────────────────────────────────────────
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

# Separator marker — must match update.sh
SEPARATOR_MARKER="# --- claude-prompt start ---"

# ── Step 1: Add submodule ────────────────────────────────────────────────────
echo "→ Checking submodule registration…"

GITMODULES="${PROJECT_ROOT}/.gitmodules"
ALREADY_REGISTERED=false

if [ -f "${GITMODULES}" ]; then
  # Check if this submodule path is already registered (normalize trailing slash)
  normalized_path="${SUBMODULE_PATH%/}"
  if git config --file "${GITMODULES}" --get-regexp 'submodule\..*\.path' 2>/dev/null \
      | awk '{print $2}' \
      | grep -qxF "${normalized_path}"; then
    ALREADY_REGISTERED=true
  fi
fi

if $ALREADY_REGISTERED; then
  echo "  Submodule already registered at '${SUBMODULE_PATH}', skipping git submodule add."
  record_skipped "git submodule add (already registered at '${SUBMODULE_PATH}')"
else
  echo "  Running: git submodule add ${REPO_URL} ${SUBMODULE_PATH}"
  git submodule add "${REPO_URL}" "${SUBMODULE_PATH}"
  record_action "Added submodule ${REPO_URL} → ${SUBMODULE_PATH}"
fi

# ── Step 2: Init and update ──────────────────────────────────────────────────
echo "→ Running git submodule update --init --recursive…"
git submodule update --init --recursive
record_action "git submodule update --init --recursive"

# ── Step 3: Symlinks into project-level .claude/ ─────────────────────────────
CLAUDE_DIR="${PROJECT_ROOT}/.claude"

# Ensure .claude exists
if [ ! -d "${CLAUDE_DIR}" ]; then
  mkdir -p "${CLAUDE_DIR}"
  record_action "Created directory ${CLAUDE_DIR}"
fi

create_symlink() {
  local link_path="$1"    # e.g. .claude/agents
  local target="$2"       # e.g. <submodule-path>/agents
  local label="$3"        # human-readable label for summary

  if [ ! -d "${target}" ]; then
    echo "  Warning: Target directory '${target}' does not exist in submodule. Skipping ${label} symlink." >&2
    record_skipped "${label} symlink (target directory missing)"
    return
  fi

  if [ -L "${link_path}" ]; then
    current_target="$(readlink "${link_path}")"
    if [ "${current_target}" = "${target}" ]; then
      # Already correct — silent skip
      record_skipped "${label} symlink (already correct)"
      return
    else
      echo "  Warning: ${link_path} already points to '${current_target}' (expected '${target}')." >&2
      echo "  Skipping — update it manually if needed." >&2
      record_skipped "${label} symlink (points to different target: ${current_target})"
      return
    fi
  elif [ -d "${link_path}" ]; then
    # Real directory exists — do not delete it
    echo "  Warning: ${link_path} is a real directory (not a symlink). Skipping ${label} symlink to avoid data loss." >&2
    echo "  Move or remove it manually if you want it replaced." >&2
    record_skipped "${label} symlink (real directory exists at ${link_path})"
    return
  elif [ -e "${link_path}" ]; then
    # Some other file type
    echo "  Warning: ${link_path} already exists and is not a symlink or directory. Skipping." >&2
    record_skipped "${label} symlink (unexpected file at ${link_path})"
    return
  fi

  ln -s "${target}" "${link_path}"
  echo "  ✓ Linked ${link_path} → ${target}"
  record_action "Symlinked ${link_path} → ${target}"
}

echo "→ Wiring up symlinks in ${CLAUDE_DIR}…"
create_symlink "${CLAUDE_DIR}/agents" "${SUBMODULE_ABS}/agents" "agents"
create_symlink "${CLAUDE_DIR}/skills" "${SUBMODULE_ABS}/skills" "skills"

# ── Step 4: Select and merge system prompt → CLAUDE.md ───────────────────────
echo "→ Handling CLAUDE.md…"

# Discover available system prompt files in the submodule
SYSTEM_PROMPTS=()
while IFS= read -r -d '' sp_file; do
  SYSTEM_PROMPTS+=("$(basename "$sp_file")")
done < <(find "${SUBMODULE_ABS}" -maxdepth 1 -name '*SYSTEM_PROMPT*.md' -print0 | sort -z)

PROMPT_COUNT=0
if [ ${#SYSTEM_PROMPTS[@]+x} ]; then
  PROMPT_COUNT=${#SYSTEM_PROMPTS[@]}
fi
PROJECT_CLAUDE_MD="${PROJECT_ROOT}/CLAUDE.md"

# Detect previously selected system prompt from existing CLAUDE.md
PREVIOUS_SOURCE=""
if [ -f "${PROJECT_CLAUDE_MD}" ]; then
  PREVIOUS_SOURCE="$(grep -oP '(?<=^# claude-prompt-source: ).+' "${PROJECT_CLAUDE_MD}" 2>/dev/null || true)"
fi

# Helper — prompt user to pick a system prompt, sets SELECTED_PROMPT and SUBMODULE_SYSTEM_PROMPT_MD
pick_system_prompt() {
  if [ "${PROMPT_COUNT}" -eq 1 ]; then
    SELECTED_PROMPT="${SYSTEM_PROMPTS[0]}"
    echo "  Using system prompt: ${SELECTED_PROMPT}"
  else
    echo ""
    echo "  Available system prompts:"
    for ((i = 0; i < PROMPT_COUNT; i++)); do
      marker=""
      if [ -n "${PREVIOUS_SOURCE}" ] && [ "${SYSTEM_PROMPTS[$i]}" = "${PREVIOUS_SOURCE}" ]; then marker=" (current)"; fi
      echo "    [$((i + 1))] ${SYSTEM_PROMPTS[$i]}${marker}"
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
  SUBMODULE_SYSTEM_PROMPT_MD="${SUBMODULE_ABS}/${SELECTED_PROMPT}"
}

if [ "${PROMPT_COUNT}" -eq 0 ]; then
  echo "  Warning: No system prompt files found in submodule. Skipping." >&2
  record_skipped "CLAUDE.md merge (no system prompt files found)"
elif [ ! -f "${PROJECT_CLAUDE_MD}" ]; then
  # No CLAUDE.md yet — pick a prompt and create it
  pick_system_prompt
  cp "${SUBMODULE_SYSTEM_PROMPT_MD}" "${PROJECT_CLAUDE_MD}"
  echo "  ✓ CLAUDE.md created from ${SELECTED_PROMPT}"
  record_action "Created CLAUDE.md from ${SELECTED_PROMPT}"
else
  # CLAUDE.md already exists — pick a prompt, then choose how to apply it
  pick_system_prompt
  echo ""
  echo "  CLAUDE.md already exists. How should ${SELECTED_PROMPT} be applied?"
  echo "    [1] Add/replace system prompt section (keeps your custom content)"
  echo "    [2] Replace entire CLAUDE.md (overwrites everything)"
  echo "    [3] Skip — leave CLAUDE.md untouched"
  printf "  Enter 1, 2, or 3: "

  read -r claude_choice </dev/tty

  case "${claude_choice}" in
    1)
      new_hash="$(compute_hash "${SUBMODULE_SYSTEM_PROMPT_MD}")"
      tmpfile="$(mktemp)"
      trap 'rm -f "${tmpfile}"' EXIT

      if grep -qF "${SEPARATOR_MARKER}" "${PROJECT_CLAUDE_MD}" 2>/dev/null; then
        awk -v sep="${SEPARATOR_MARKER}" '
          $0 == sep { in_block=1; next }
          in_block && /^# claude-prompt-hash:/ { in_block=0; next }
          in_block { next }
          { print }
        ' "${PROJECT_CLAUDE_MD}" > "${tmpfile}"
        action_label="Replaced system prompt section with ${SELECTED_PROMPT}"
      else
        cp "${PROJECT_CLAUDE_MD}" "${tmpfile}"
        action_label="Added ${SELECTED_PROMPT} section to CLAUDE.md"
      fi

      {
        echo ""
        echo "${SEPARATOR_MARKER}"
        echo "# claude-prompt-source: ${SELECTED_PROMPT}"
        cat "${SUBMODULE_SYSTEM_PROMPT_MD}"
        echo "# claude-prompt-hash: ${new_hash}"
      } >> "${tmpfile}"

      mv "${tmpfile}" "${PROJECT_CLAUDE_MD}"
      trap - EXIT
      echo "  ✓ ${action_label}"
      record_action "${action_label}"
      ;;
    2)
      printf "  This will overwrite your existing CLAUDE.md. Are you sure? (y/N): "
      read -r overwrite_confirm </dev/tty
      if [ "${overwrite_confirm}" = "y" ] || [ "${overwrite_confirm}" = "Y" ]; then
        cp "${SUBMODULE_SYSTEM_PROMPT_MD}" "${PROJECT_CLAUDE_MD}"
        echo "  ✓ Replaced CLAUDE.md with ${SELECTED_PROMPT}"
        record_action "Replaced CLAUDE.md with ${SELECTED_PROMPT}"
      else
        echo "  Overwrite cancelled. CLAUDE.md left untouched."
        record_skipped "CLAUDE.md overwrite (cancelled by user)"
      fi
      ;;
    3)
      echo "  Skipped CLAUDE.md"
      record_skipped "CLAUDE.md merge (skipped by user)"
      ;;
    *)
      echo "  Invalid choice '${claude_choice}'. Skipping CLAUDE.md." >&2
      record_skipped "CLAUDE.md merge (invalid input: '${claude_choice}')"
      ;;
  esac
fi

# ── Final summary ────────────────────────────────────────────────────────────
print_summary
