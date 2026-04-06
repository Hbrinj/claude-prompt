#!/usr/bin/env bash
# update.sh — Pull latest claude-prompt submodule changes and re-run CLAUDE.md merge flow

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
# Must match the separator written by install.sh
SEPARATOR_MARKER="# --- claude-prompt start ---"

# ── Summary tracking ────────────────────────────────────────────────────────
ACTIONS=()
SKIPPED=()
DRY_RUN=false

record_action()  { ACTIONS+=("$1"); }
record_skipped() { SKIPPED+=("$1"); }

print_summary() {
  echo ""
  echo "══════════════════════════════════════"
  if $DRY_RUN; then
    echo "  Update Summary (DRY RUN — no changes made)"
  else
    echo "  Update Summary"
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

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Pull latest claude-prompt submodule changes and re-run the CLAUDE.md merge flow.

Options:
  --help, -h    Print this help message and exit
  --dry-run     Print every action that would be taken without executing any

What this script does:
  1. Detects the claude-prompt submodule path from .gitmodules
  2. Runs: git submodule update --remote --merge <submodule-path>
  3. Prints what changed (git log since last update)
  4. Verifies and repairs ~/.claude/agents and ~/.claude/skills symlinks
  5. Re-runs the CLAUDE.md merge flow with hash-based change detection

Run install.sh first if you haven't already.
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=true ;;
    -*) echo "Error: Unknown option: $arg" >&2; usage >&2; exit 1 ;;
    *)  echo "Error: Unexpected argument: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

# ── Preflight checks ──────────────────────────────────────────────────────────
check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: Required command '$1' not found. Please install it and retry." >&2
    exit 1
  fi
}

check_command git
check_command awk
check_command cp
check_command ln

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: Not inside a git repository. Run this script from your project root." >&2
  exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
if [ "$(pwd)" != "${PROJECT_ROOT}" ]; then
  echo "Error: Run this script from the project root: ${PROJECT_ROOT}" >&2
  exit 1
fi

GITMODULES="${PROJECT_ROOT}/.gitmodules"

if [ ! -f "${GITMODULES}" ]; then
  echo "Error: .gitmodules not found. Run install.sh first." >&2
  exit 1
fi

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
    echo "Error: No hash command available (sha1sum, shasum, md5sum, or md5)" >&2
    exit 1
  fi
}

# ── Step 1: Detect submodule path ─────────────────────────────────────────────
echo "→ Detecting submodule path…"

SUBMODULE_PATH=""

# Primary: find by URL containing "claude-prompt"
while IFS= read -r entry; do
  key="$(printf '%s' "$entry" | awk '{print $1}')"
  url="$(printf '%s' "$entry" | awk '{print $2}')"
  if printf '%s' "$url" | grep -qi "claude-prompt"; then
    section="${key#submodule.}"
    section="${section%.url}"
    SUBMODULE_PATH="$(git config --file "${GITMODULES}" "submodule.${section}.path" 2>/dev/null || true)"
    break
  fi
done < <(git config --file "${GITMODULES}" --get-regexp 'submodule\..*\.url' 2>/dev/null || true)

# Fallback: find by submodule that contains agents/ and skills/
if [ -z "${SUBMODULE_PATH}" ]; then
  while IFS= read -r entry; do
    candidate_path="$(printf '%s' "$entry" | awk '{print $2}')"
    candidate_abs="${PROJECT_ROOT}/${candidate_path}"
    if [ -d "${candidate_abs}/agents" ] && [ -d "${candidate_abs}/skills" ]; then
      SUBMODULE_PATH="$candidate_path"
      break
    fi
  done < <(git config --file "${GITMODULES}" --get-regexp 'submodule\..*\.path' 2>/dev/null || true)
fi

if [ -z "${SUBMODULE_PATH}" ]; then
  echo "Error: No claude-prompt submodule found in .gitmodules. Run install.sh first." >&2
  exit 1
fi

SUBMODULE_ABS="${PROJECT_ROOT}/${SUBMODULE_PATH}"
echo "  Found submodule at: ${SUBMODULE_PATH}"

# Verify the submodule directory exists on disk (install.sh has been run)
if [ ! -d "${SUBMODULE_ABS}" ]; then
  echo "Error: Submodule directory '${SUBMODULE_ABS}' does not exist. Run install.sh first." >&2
  exit 1
fi

# ── Step 2: Pull latest upstream changes ─────────────────────────────────────
echo "→ Updating submodule…"

if $DRY_RUN; then
  echo "  [dry-run] Would run: git submodule update --remote --merge ${SUBMODULE_PATH}"
  record_action "[dry-run] git submodule update --remote --merge ${SUBMODULE_PATH}"
else
  git submodule update --remote --merge "${SUBMODULE_PATH}"
  record_action "git submodule update --remote --merge ${SUBMODULE_PATH}"
fi

# ── Step 3: Show what changed ─────────────────────────────────────────────────
echo "→ Changes in submodule:"

if $DRY_RUN; then
  echo "  [dry-run] Would show: git -C ${SUBMODULE_PATH} log HEAD@{1}..HEAD --oneline"
else
  changes="$(git -C "${SUBMODULE_ABS}" log "HEAD@{1}..HEAD" --oneline 2>/dev/null || true)"
  if [ -z "${changes}" ]; then
    echo "  Already up to date."
  else
    printf '%s\n' "${changes}" | sed 's/^/  /'
  fi
fi

# ── Step 4: Verify and repair symlinks ───────────────────────────────────────
echo "→ Verifying symlinks in ${CLAUDE_DIR}…"

verify_symlink() {
  local link_path="$1"
  local target="$2"
  local label="$3"

  if [ ! -d "${target}" ]; then
    echo "  Warning: ${target} does not exist in submodule. Skipping ${label} check." >&2
    record_skipped "${label} symlink (target directory missing in submodule)"
    return
  fi

  if [ -L "${link_path}" ]; then
    current_target="$(readlink "${link_path}")"
    if [ "${current_target}" = "${target}" ]; then
      if [ -e "${link_path}" ]; then
        # Symlink exists and resolves — all good
        echo "  ✓ Symlink OK: ${link_path}"
        record_skipped "${label} symlink (OK, no action needed)"
      else
        # Broken symlink pointing to the right path — repair it
        if $DRY_RUN; then
          echo "  [dry-run] Would repair broken symlink: ${link_path} → ${target}"
          record_action "[dry-run] Repair broken symlink ${link_path} → ${target}"
        else
          ln -sf "${target}" "${link_path}"
          echo "  ✓ Repaired symlink: ${link_path}"
          record_action "Repaired symlink ${link_path} → ${target}"
        fi
      fi
    else
      # Points to a different target — do not touch it
      echo "  Warning: ${link_path} points to '${current_target}' (expected '${target}'). Skipping." >&2
      echo "  Update it manually if needed." >&2
      record_skipped "${label} symlink (points to different target: ${current_target})"
    fi
  elif [ -d "${link_path}" ]; then
    # Real directory — never delete without confirmation
    echo "  Warning: ${link_path} is a real directory (not a symlink). Skipping to avoid data loss." >&2
    echo "  Move or remove it manually if you want it replaced." >&2
    record_skipped "${label} symlink (real directory at ${link_path})"
  else
    # Missing entirely — create it
    if $DRY_RUN; then
      echo "  [dry-run] Would create missing symlink: ${link_path} → ${target}"
      record_action "[dry-run] Create missing symlink ${link_path} → ${target}"
    else
      # Ensure ~/.claude exists
      mkdir -p "${CLAUDE_DIR}"
      ln -s "${target}" "${link_path}"
      echo "  ✓ Repaired symlink: ${link_path}"
      record_action "Repaired symlink ${link_path} → ${target}"
    fi
  fi
}

verify_symlink "${CLAUDE_DIR}/agents" "${SUBMODULE_ABS}/agents" "agents"
verify_symlink "${CLAUDE_DIR}/skills" "${SUBMODULE_ABS}/skills" "skills"

# ── Step 5: CLAUDE.md merge ───────────────────────────────────────────────────
echo "→ Checking CLAUDE.md…"

SUBMODULE_CLAUDE_MD="${SUBMODULE_ABS}/CLAUDE.md"
PROJECT_CLAUDE_MD="${PROJECT_ROOT}/CLAUDE.md"

if [ ! -f "${SUBMODULE_CLAUDE_MD}" ]; then
  echo "  Warning: Submodule has no CLAUDE.md. Skipping." >&2
  record_skipped "CLAUDE.md update (submodule CLAUDE.md not found)"
  print_summary
  exit 0
fi

new_hash="$(compute_hash "${SUBMODULE_CLAUDE_MD}")"

if [ ! -f "${PROJECT_CLAUDE_MD}" ]; then
  # No project CLAUDE.md — create it fresh
  if $DRY_RUN; then
    echo "  [dry-run] Would create CLAUDE.md from submodule"
    record_action "[dry-run] Create CLAUDE.md from submodule"
  else
    cp "${SUBMODULE_CLAUDE_MD}" "${PROJECT_CLAUDE_MD}"
    echo "  ✓ CLAUDE.md created"
    record_action "Created CLAUDE.md from submodule"
  fi
  print_summary
  exit 0
fi

# Check if hash marker already exists in project CLAUDE.md — idempotency guard
if grep -qF "# claude-prompt-hash: ${new_hash}" "${PROJECT_CLAUDE_MD}" 2>/dev/null; then
  echo "  CLAUDE.md already up to date. Skipping."
  record_skipped "CLAUDE.md update (already up to date, hash matches)"
  print_summary
  exit 0
fi

# Hash differs — prompt the user
echo ""
echo "The submodule CLAUDE.md has changed. Choose an option:"
echo "  [1] Append updated submodule section (replaces previous appended section if present)"
echo "  [2] Replace entire CLAUDE.md with submodule version"
echo "  [3] Skip — leave CLAUDE.md untouched"
printf "Enter 1, 2, or 3: "

read -r claude_choice </dev/tty

case "${claude_choice}" in
  1)
    if $DRY_RUN; then
      if grep -qF "${SEPARATOR_MARKER}" "${PROJECT_CLAUDE_MD}" 2>/dev/null; then
        echo "  [dry-run] Would replace existing appended section in CLAUDE.md (hash: ${new_hash})"
        record_action "[dry-run] Replace existing claude-prompt section in CLAUDE.md"
      else
        echo "  [dry-run] Would append submodule section to CLAUDE.md (hash: ${new_hash})"
        record_action "[dry-run] Append submodule section to CLAUDE.md"
      fi
    else
      tmpfile="$(mktemp)"
      # Ensure temp file is removed on exit (including errors)
      trap 'rm -f "${tmpfile}"' EXIT

      if grep -qF "${SEPARATOR_MARKER}" "${PROJECT_CLAUDE_MD}" 2>/dev/null; then
        # Strip the old appended block (from separator through the hash marker line),
        # then append fresh content. Lines outside the block are preserved as-is.
        awk -v sep="${SEPARATOR_MARKER}" '
          $0 == sep { in_block=1; next }
          in_block && /^# claude-prompt-hash:/ { in_block=0; next }
          in_block { next }
          { print }
        ' "${PROJECT_CLAUDE_MD}" > "${tmpfile}"
        action_label="Replaced existing claude-prompt section in CLAUDE.md"
      else
        # No previous block — copy verbatim, then append below
        cp "${PROJECT_CLAUDE_MD}" "${tmpfile}"
        action_label="Appended submodule section to CLAUDE.md"
      fi

      {
        echo ""
        echo "${SEPARATOR_MARKER}"
        cat "${SUBMODULE_CLAUDE_MD}"
        echo "# claude-prompt-hash: ${new_hash}"
      } >> "${tmpfile}"

      mv "${tmpfile}" "${PROJECT_CLAUDE_MD}"
      trap - EXIT  # disarm the trap after successful mv
      echo "  ✓ ${action_label}"
      record_action "${action_label}"
    fi
    ;;

  2)
    printf "  This will overwrite your existing CLAUDE.md. Are you sure? (y/N): "
    read -r overwrite_confirm </dev/tty
    if [ "${overwrite_confirm}" = "y" ] || [ "${overwrite_confirm}" = "Y" ]; then
      if $DRY_RUN; then
        echo "  [dry-run] Would overwrite CLAUDE.md with submodule version"
        record_action "[dry-run] Overwrite CLAUDE.md with submodule version"
      else
        cp "${SUBMODULE_CLAUDE_MD}" "${PROJECT_CLAUDE_MD}"
        echo "  ✓ Replaced CLAUDE.md with submodule version"
        record_action "Replaced CLAUDE.md with submodule version"
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

# ── Final summary ─────────────────────────────────────────────────────────────
print_summary
