#!/usr/bin/env bash
set -euo pipefail

EIDOLON_NAME="kupo"
EIDOLON_SLUG="kupo"
EIDOLON_VERSION="1.1.0"
METHODOLOGY="KUPO"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- legacy cleanup arrays (v1.2/v1.3-era artefacts) ---
# Basenames removed from <TARGET>/ when found on disk.
LEGACY_SPEC_FILES=("KUPO.md")
# Subdir names removed from <TARGET>/skills/ when found as directories.
LEGACY_SKILL_DIRS=("keep-or-kick" "patch-verify" "verify-incoming")

# --- ECL version ---
ECL_VERSION_FILE="${SCRIPT_DIR}/ECL_VERSION"
if [[ -f "$ECL_VERSION_FILE" ]]; then
  ECL_VERSION="$(head -n1 "$ECL_VERSION_FILE" | tr -d '[:space:]')"
else
  ECL_VERSION="none"
fi

# --- defaults ---
TARGET="./.eidolons/${EIDOLON_NAME}"
HOSTS="auto"
FORCE=false
DRY_RUN=false
NON_INTERACTIVE=false
MANIFEST_ONLY=false
SHARED_DISPATCH=false

usage() {
  cat <<EOF
Usage: bash install.sh [OPTIONS]

Options:
  --target DIR            Target install dir (default: ${TARGET})
  --hosts LIST            claude-code,copilot,cursor,opencode,codex,all (default: auto)
  --shared-dispatch       Compose marker-bounded section in root AGENTS.md /
                          CLAUDE.md / .github/copilot-instructions.md (opt-in).
  --no-shared-dispatch    Skip root dispatch files (default). Per-vendor files
                          remain self-sufficient.
  --force                 Overwrite existing install
  --dry-run               Print actions, no writes
  --non-interactive       No prompts; fail on ambiguity (meta-installer mode)
  --manifest-only         Only emit install.manifest.json
  --version               Print Eidolon version
  -h, --help              Show help
EOF
}

# --- arg parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)               TARGET="$2"; shift 2 ;;
    --hosts)                HOSTS="$2"; shift 2 ;;
    --shared-dispatch)      SHARED_DISPATCH=true; shift ;;
    --no-shared-dispatch)   SHARED_DISPATCH=false; shift ;;
    --force)                FORCE=true; shift ;;
    --dry-run)              DRY_RUN=true; shift ;;
    --non-interactive)      NON_INTERACTIVE=true; shift ;;
    --manifest-only)        MANIFEST_ONLY=true; shift ;;
    --version)              echo "${EIDOLON_VERSION}"; exit 0 ;;
    -h|--help)              usage; exit 0 ;;
    *)                      echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# --- host detection ---
# EIIS v1.1 §4.5 — `.codex/` and root `AGENTS.md` are Codex signals; root
# `AGENTS.md` is co-owned with copilot and treated as a definitive Codex
# signal when no `.github/` is present.
detect_hosts() {
  local -a detected=()
  [[ -f "CLAUDE.md" || -d ".claude" ]]          && detected+=("claude-code")
  [[ -d ".github" ]]                             && detected+=("copilot")
  [[ -d ".cursor" || -f ".cursorrules" ]]        && detected+=("cursor")
  [[ -d ".opencode" ]]                           && detected+=("opencode")
  if [[ -d ".codex" ]]; then
    detected+=("codex")
  elif [[ -f "AGENTS.md" && ! -d ".github" ]]; then
    detected+=("codex")
  fi
  printf "%s\n" "${detected[@]+"${detected[@]}"}"
}

if [[ "$HOSTS" == "auto" ]]; then
  detected_list="$(detect_hosts | paste -sd, -)"
  HOSTS="${detected_list:-none}"
elif [[ "$HOSTS" == "all" ]]; then
  HOSTS="claude-code,copilot,cursor,opencode,codex"
fi

# Validate host list (EIIS v1.1 §2.1, §2.7).
IFS=',' read -ra _HOST_ARRAY <<< "$HOSTS"
for _h in "${_HOST_ARRAY[@]}"; do
  case "$_h" in
    claude-code|copilot|cursor|opencode|codex|raw|none|"") : ;;
    *) echo "Invalid --hosts value: $_h" >&2; exit 2 ;;
  esac
done
unset _HOST_ARRAY _h

hosts_contains() { [[ ",$HOSTS," == *",$1,"* ]]; }

# --- resolve target ---
if [[ "$DRY_RUN" != "true" ]]; then
  mkdir -p "$TARGET"
  TARGET="$(cd "$TARGET" && pwd)"
fi

# Relative form for @-pointers (strip absolute prefix or leading ./)
TARGET_REL="${TARGET#$(pwd)/}"
TARGET_REL="${TARGET_REL#./}"

# --- idempotency check ---
if [[ -f "${TARGET}/install.manifest.json" && "$FORCE" != "true" ]]; then
  EXISTING_VER="$(grep -o '"version":"[^"]*"' "${TARGET}/install.manifest.json" 2>/dev/null | cut -d'"' -f4 || echo "unknown")"
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    echo "Existing install v${EXISTING_VER} at ${TARGET}. Pass --force to overwrite." >&2
    exit 3
  fi
  read -rp "Existing install v${EXISTING_VER} at ${TARGET}. Overwrite? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

# --- portable sha256 helper ---
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    openssl dgst -sha256 -hex "$1" | awk '{print $2}'
  fi
}

# cleanup_legacy_v1_2 <target>
#
# Sweep legacy v1.2-era artefacts left behind by prior installs.
# Called exactly once, early in the install sequence, BEFORE any new content
# is written under <target>. Idempotent: no-op when no legacy file exists.
#
# Reads two top-of-file arrays:
#   LEGACY_SPEC_FILES  — basenames to rm -f at "<target>/<basename>"
#   LEGACY_SKILL_DIRS  — skill names to rm -rf at "<target>/skills/<name>"
#
# Both arrays are declared per-Eidolon and MAY be empty (in which case
# the corresponding loop is a no-op). Never reads/writes outside <target>.
cleanup_legacy_v1_2() {
  local target="$1"
  local legacy
  local legacy_skill_dir

  if [ -z "${target}" ] || [ ! -d "${target}" ]; then
    return 0
  fi

  # Sweep legacy spec filenames (e.g. IDG.md, SCRIBE.md)
  for legacy in "${LEGACY_SPEC_FILES[@]}"; do
    if [ -n "${legacy}" ] && [ -f "${target}/${legacy}" ]; then
      rm -f "${target}/${legacy}"
      echo "  swept legacy spec file: ${target}/${legacy}" >&2
    fi
  done

  # Sweep legacy subdir-style skills (e.g. skills/composition/SKILL.md)
  for legacy_skill_dir in "${LEGACY_SKILL_DIRS[@]}"; do
    if [ -n "${legacy_skill_dir}" ] && [ -d "${target}/skills/${legacy_skill_dir}" ]; then
      rm -rf "${target}/skills/${legacy_skill_dir}"
      echo "  swept legacy skill subdir: ${target}/skills/${legacy_skill_dir}" >&2
    fi
  done

  return 0
}

# canonical_inventory_sweep <target>
#
# Remove every file under <target>/ that is not present in the in-memory
# allow-set FILES_WRITTEN_PATHS. The allow-set is maintained by files_append()
# during the install; each successful write appends its target-relative path.
#
# EIIS v1.4 §6.X — manifest-driven cleanup obligation.
# Bash 3.2 compatible. Idempotent: re-running on a clean target is a no-op.
canonical_inventory_sweep() {
  local target="$1"
  local file_rel
  local found
  local known

  if [ -z "${target}" ] || [ ! -d "${target}" ]; then
    return 0
  fi

  find "${target}" -type f -print0 | while IFS= read -r -d '' file; do
    file_rel="${file#${target}/}"

    found=0
    for known in "${FILES_WRITTEN_PATHS[@]+"${FILES_WRITTEN_PATHS[@]}"}"; do
      case "${known}" in
        *"/${file_rel}"|"${file_rel}")
          found=1
          break
          ;;
      esac
    done

    if [ "${found}" -eq 0 ]; then
      rm -f "${file}"
      echo "  swept non-whitelisted file: ${file}" >&2
    fi
  done

  # Remove any empty directories left after the sweep.
  find "${target}" -mindepth 1 -type d -empty -delete 2>/dev/null || true

  return 0
}

# --- resolve spec source ---
SRC_SPEC="${SCRIPT_DIR}/SPEC.md"
if [[ ! -f "${SRC_SPEC}" ]]; then
  echo "ERROR: spec source not found: ${SRC_SPEC}" >&2
  exit 3
fi

# upsert_eidolon_block <file> <content>
#
# Owns a marker-bounded region in a composable dispatch file. Rewrites the
# body in place when markers already exist; appends a new block otherwise.
# Cleans up any pre-existing symlink at the target.
upsert_eidolon_block() {
  local dst="$1" content="$2"
  local start="<!-- eidolon:${EIDOLON_NAME} start -->"
  local end="<!-- eidolon:${EIDOLON_NAME} end -->"

  if [[ "$DRY_RUN" == "true" ]]; then
    local action="append"
    [[ -f "$dst" ]] && grep -qF "$start" "$dst" 2>/dev/null && action="rewrite"
    echo "[dry-run] ${action} eidolon:${EIDOLON_NAME} block in ${dst}"
    return
  fi

  mkdir -p "$(dirname "$dst")" 2>/dev/null || true
  [[ -L "$dst" ]] && rm -f "$dst"

  local content_file tmp
  content_file="$(mktemp)"
  printf '%s\n' "$content" > "$content_file"

  if [[ -f "$dst" ]] && grep -qF "$start" "$dst" 2>/dev/null; then
    tmp="$(mktemp)"
    awk -v start="$start" -v end="$end" -v cf="$content_file" '
      BEGIN { in_block = 0 }
      $0 == start {
        print start
        while ((getline line < cf) > 0) print line
        close(cf)
        in_block = 1
        next
      }
      $0 == end {
        print end
        in_block = 0
        next
      }
      !in_block { print }
    ' "$dst" > "$tmp"
    mv "$tmp" "$dst"
    echo "  rewrote eidolon:${EIDOLON_NAME} block in ${dst}"
  elif [[ -f "$dst" ]]; then
    { printf '\n%s\n' "$start"; cat "$content_file"; printf '%s\n' "$end"; } >> "$dst"
    echo "  appended eidolon:${EIDOLON_NAME} block to ${dst}"
  else
    { printf '%s\n' "$start"; cat "$content_file"; printf '%s\n' "$end"; } > "$dst"
    echo "  created ${dst} with eidolon:${EIDOLON_NAME} block"
  fi

  rm -f "$content_file"
}

if [[ "$MANIFEST_ONLY" != "true" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Target: ${TARGET}"
    echo "[dry-run] Hosts:  ${HOSTS}"
    echo "[dry-run] Would write:"
    echo "  ${TARGET}/agent.md"
    echo "  ${TARGET}/SPEC.md"
    echo "  ${TARGET}/ECL_VERSION"
    echo "  ${TARGET}/skills/verify-incoming.md"
    echo "  ${TARGET}/skills/keep-or-kick.md"
    echo "  ${TARGET}/skills/patch-verify.md"
    echo "  ${TARGET}/schemas/ecl-envelope.v1.json"
    echo "  ${TARGET}/schemas/ecl-base-profile.v1.json"
    echo "  ${TARGET}/schemas/install.manifest.v1.json"
    echo "  ${TARGET}/schemas/kupo-edit-proposal.v1.json"
    hosts_contains "claude-code" && echo "  CLAUDE.md (append @${TARGET_REL}/agent.md)"
    hosts_contains "claude-code" && echo "  .claude/agents/${EIDOLON_NAME}.md"
    hosts_contains "copilot"     && echo "  .github/copilot-instructions.md"
    hosts_contains "cursor"      && echo "  .cursor/rules/${EIDOLON_NAME}.mdc"
    hosts_contains "opencode"    && echo "  .opencode/agents/${EIDOLON_NAME}.md"
    hosts_contains "codex"       && echo "  AGENTS.md (eidolon:${EIDOLON_NAME} marker block)"
    hosts_contains "codex"       && echo "  .codex/agents/${EIDOLON_NAME}.md"
  else
    # Create directory structure
    mkdir -p \
      "${TARGET}/skills" \
      "${TARGET}/schemas"

    # Sweep legacy v1.2-era artefacts before writing new content.
    cleanup_legacy_v1_2 "${TARGET}"

    # Copy agent files
    cp "${SCRIPT_DIR}/agent.md"                                   "${TARGET}/agent.md"
    cp "${SRC_SPEC}"                                              "${TARGET}/SPEC.md"
    cp "${SCRIPT_DIR}/ECL_VERSION"                                "${TARGET}/ECL_VERSION"

    # Copy vendored ECL schemas + the edit-proposal profile Kupo emits
    cp "${SCRIPT_DIR}/schemas/ecl-envelope.v1.json"               "${TARGET}/schemas/ecl-envelope.v1.json"
    cp "${SCRIPT_DIR}/schemas/ecl-base-profile.v1.json"           "${TARGET}/schemas/ecl-base-profile.v1.json"
    cp "${SCRIPT_DIR}/schemas/install.manifest.v1.json"           "${TARGET}/schemas/install.manifest.v1.json"
    cp "${SCRIPT_DIR}/schemas/kupo-edit-proposal.v1.json"         "${TARGET}/schemas/kupo-edit-proposal.v1.json"

    # --- shared composable block (opt-in via --shared-dispatch) ---
    SHARED_BLOCK="## ${METHODOLOGY} — Low-effort executor (v${EIDOLON_VERSION})

Entry:     \`${TARGET_REL}/agent.md\`
Full spec: \`${TARGET_REL}/SPEC.md\`
Cycle:     K (Keep-or-Kick) → U (Understand) → P (Patch) → O (Observe)

**P0 (non-negotiable):** PROPOSE-only (the parent commits — never the real tree); external-only verify (a NAMED test/lint/typecheck/compile — never self-critique); worker-never-router (no DELEGATE/DECIDE/CRITIQUE/REQUEST); scope-guard (KEEP only localized ≤2-file verifier-backed tasks with pass-rate >0.20, else REFUSE/ESCALATE); circuit-breaker (3-consecutive or 20-total failures → ESCALATE)."

    # --- per-skill vendor wiring helpers ---
    strip_frontmatter() {
      local f="$1"
      if [[ "$(head -1 "$f")" == "---" ]]; then
        awk 'NR==1 && /^---$/ {in_fm=1; next}
             in_fm && /^---$/ {in_fm=0; next}
             !in_fm {print}' "$f"
      else
        cat "$f"
      fi
    }
    extract_fm_field() {
      awk -v field="$2" '
        NR==1 && /^---$/ { in_fm=1; next }
        in_fm && /^---$/ { exit }
        in_fm { p=index($0, field ":"); if (p==1) { sub("^" field ":[[:space:]]*", ""); print; exit } }
      ' "$1"
    }
    # wire_skill <skill_slug>
    #
    # Dual-writes a skill file per EIIS v1.3 §4.2.4:
    #   - source-of-truth: ${TARGET}/skills/<skill_slug>.md   (flat layout)
    #   - vendor copy:     .claude/skills/${EIDOLON_SLUG}-<skill_slug>/SKILL.md
    #
    # Also writes copilot/cursor vendor copies when those hosts are wired.
    wire_skill() {
      local skill="$1"
      local src="${SCRIPT_DIR}/skills/${skill}.md"
      local dst_src="${TARGET}/skills/${skill}.md"
      local dst_vendor=".claude/skills/${EIDOLON_SLUG}-${skill}/SKILL.md"

      if [[ ! -f "${src}" ]]; then
        echo "ERROR: skill source not found: ${src}" >&2
        exit 3
      fi

      mkdir -p "$(dirname "${dst_src}")"
      cp "${src}" "${dst_src}"

      local description
      description="$(extract_fm_field "${src}" "description")"
      [[ -z "$description" ]] && description="${skill}"

      if hosts_contains "claude-code"; then
        mkdir -p "$(dirname "${dst_vendor}")"
        cp "${src}" "${dst_vendor}"
      fi
      if hosts_contains "copilot"; then
        mkdir -p ".github/instructions"
        {
          echo "---"
          echo "applyTo: \"**\""
          echo "description: \"${description}\""
          echo "---"
          strip_frontmatter "${src}"
        } > ".github/instructions/${EIDOLON_SLUG}-${skill}.instructions.md"
      fi
      if hosts_contains "cursor"; then
        mkdir -p ".cursor/rules"
        {
          echo "---"
          echo "description: \"${description}\""
          echo "alwaysApply: false"
          echo "---"
          strip_frontmatter "${src}"
        } > ".cursor/rules/${EIDOLON_SLUG}-${skill}.mdc"
      fi
    }

    # Emit per-skill source-of-truth + vendor files for every skill.
    for skill in verify-incoming keep-or-kick patch-verify; do
      wire_skill "${skill}"
    done

    # --- host dispatch wiring ---
    if hosts_contains "claude-code"; then
      [[ "$SHARED_DISPATCH" == "true" ]] && upsert_eidolon_block "CLAUDE.md" "$SHARED_BLOCK"

      # Subagent dispatch — always written when claude-code wired.
      mkdir -p ".claude/agents"
      if [[ ! -f ".claude/agents/${EIDOLON_NAME}.md" || "$FORCE" == "true" ]]; then
        cat > ".claude/agents/${EIDOLON_NAME}.md" <<AGENT
---
name: ${EIDOLON_NAME}
description: "Low-effort executor — delegated localized micro-tasks, sandbox-proven, PROPOSE-only (never the real tree)."
model: haiku
---

You are ${METHODOLOGY}. Read these two files in order at session start:

1. \`./.eidolons/${EIDOLON_SLUG}/agent.md\` — always-loaded P0 rules.
2. \`./.eidolons/${EIDOLON_SLUG}/SPEC.md\` — deep on-demand methodology spec.

Skills live at \`./.eidolons/${EIDOLON_SLUG}/skills/<skill>.md\` (load on demand).
AGENT
      fi
    fi

    if hosts_contains "copilot"; then
      [[ "$SHARED_DISPATCH" == "true" ]] && upsert_eidolon_block ".github/copilot-instructions.md" "$SHARED_BLOCK"
    fi

    if hosts_contains "cursor"; then
      # Drop the legacy methodology-level rule — per-skill rules are canonical now.
      [[ -f ".cursor/rules/${EIDOLON_NAME}.mdc" && "$FORCE" == "true" ]] && rm -f ".cursor/rules/${EIDOLON_NAME}.mdc"
    fi

    if hosts_contains "opencode"; then
      mkdir -p ".opencode/agents"
      if [[ ! -f ".opencode/agents/${EIDOLON_NAME}.md" || "$FORCE" == "true" ]]; then
        printf "# %s — %s\n\nSee \`%s/agent.md\` for the %s methodology entry point.\n" \
          "${METHODOLOGY}" "${EIDOLON_NAME}" "${TARGET_REL}" "${METHODOLOGY}" \
          > ".opencode/agents/${EIDOLON_NAME}.md"
      fi
    fi

    # Codex (EIIS v1.1 §4.5). Required: `.codex/agents/<name>.md` with YAML
    # frontmatter (`name`, `description`); SHOULD point at the methodology
    # entry. Body mirrors the Claude subagent prompt for parity (§4.5.3.3
    # allows divergence; we choose to mirror).
    if hosts_contains "codex"; then
      mkdir -p ".codex/agents"
      if [[ ! -f ".codex/agents/${EIDOLON_NAME}.md" || "$FORCE" == "true" ]]; then
        cat > ".codex/agents/${EIDOLON_NAME}.md" <<CODEX_AGENT
---
name: ${EIDOLON_NAME}
description: Low-effort executor subagent — heavier agents delegate quick localized verifier-backed micro-tasks; patches an ephemeral sandbox, proves it externally, PROPOSEs a verified patch for the parent to commit.
---

# ${METHODOLOGY} — Codex subagent

${METHODOLOGY} runs the K→U→P→O cycle. Given a localized, verifier-backed
micro-task, it patches an ephemeral scratch sandbox, proves the change with a
NAMED external verifier, and proposes a verified patch — it never writes the
real tree and never routes work onward.

When Codex delegates to this subagent, treat the methodology in
\`${TARGET_REL}/agent.md\` as authoritative. The full ruleset lives in
\`${TARGET_REL}/SPEC.md\`. Skills load on demand — see
\`${TARGET_REL}/skills/\`.

## P0 (non-negotiable)

- PROPOSE-only: edits go to a throwaway sandbox; the parent commits.
- External-only verify: a NAMED test/lint/typecheck/compile — never self-critique.
- Worker, never router: no DELEGATE/DECIDE/CRITIQUE/REQUEST.
- Scope-guard: KEEP only localized (≤2 files), verifier-backed tasks with
  expected pass-rate >0.20; else REFUSE/ESCALATE cheaply.
- Circuit-breaker: 3-consecutive or 20-total failures → ESCALATE.

## When to use

When a planner/coder Eidolon (or a human) has a quick, localized, verifier-backed
change — a rename, an import fix, a lockfile bump, a lint autofix — and wants it
done cheaply without spending its own context.
CODEX_AGENT
      fi
    fi

    # Root AGENTS.md is co-owned by `copilot` and `codex` per EIIS v1.1
    # §4.1.0. Write the marker block when --shared-dispatch is set OR when
    # codex is wired (Codex's primary instruction surface).
    if [[ "$SHARED_DISPATCH" == "true" ]] || hosts_contains "codex"; then
      upsert_eidolon_block "AGENTS.md" "$SHARED_BLOCK"
    fi
  fi
fi

# --- emit manifest ---
if [[ "$DRY_RUN" != "true" ]]; then
  INSTALLED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Build hosts_wired JSON array
  hosts_json="["
  first=true
  IFS=',' read -ra host_list <<< "$HOSTS"
  for h in "${host_list[@]}"; do
    [[ "$h" == "none" ]] && continue
    [[ "$first" == "true" ]] && first=false || hosts_json+=", "
    hosts_json+="\"$h\""
  done
  hosts_json+="]"

  # Build files_written and skills JSON arrays.
  # FILES_WRITTEN_PATHS is an indexed array used by canonical_inventory_sweep.
  FILES_WRITTEN_PATHS=()
  files_json="[]"
  skills_json="[]"
  if [[ "$MANIFEST_ONLY" != "true" && -f "${TARGET}/agent.md" ]]; then
    sha_agent=$(sha256_file "${TARGET}/agent.md")
    sha_spec=$(sha256_file "${TARGET}/SPEC.md")
    sha_ecl_ver=$(sha256_file "${TARGET}/ECL_VERSION")
    sha_verinc=$(sha256_file "${TARGET}/skills/verify-incoming.md")
    sha_kok=$(sha256_file "${TARGET}/skills/keep-or-kick.md")
    sha_pv=$(sha256_file "${TARGET}/skills/patch-verify.md")
    sha_ecl_env=$(sha256_file "${TARGET}/schemas/ecl-envelope.v1.json")
    sha_ecl_base=$(sha256_file "${TARGET}/schemas/ecl-base-profile.v1.json")
    sha_manifest=$(sha256_file "${TARGET}/schemas/install.manifest.v1.json")
    sha_editprop=$(sha256_file "${TARGET}/schemas/kupo-edit-proposal.v1.json")

    # SHA of vendor copies (same content as source-of-truth)
    sha_verinc_vendor=""
    sha_kok_vendor=""
    sha_pv_vendor=""
    if hosts_contains "claude-code"; then
      sha_verinc_vendor=$(sha256_file ".claude/skills/${EIDOLON_SLUG}-verify-incoming/SKILL.md")
      sha_kok_vendor=$(sha256_file ".claude/skills/${EIDOLON_SLUG}-keep-or-kick/SKILL.md")
      sha_pv_vendor=$(sha256_file ".claude/skills/${EIDOLON_SLUG}-patch-verify/SKILL.md")
    fi

    files_entries=""
    files_append() {
      local json_entry="$1"
      local path_val="$2"
      if [[ -z "$files_entries" ]]; then
        files_entries="    ${json_entry}"
      else
        files_entries="${files_entries},
    ${json_entry}"
      fi
      # Populate the allow-set for canonical_inventory_sweep.
      if [[ -n "${path_val}" ]]; then
        FILES_WRITTEN_PATHS+=("${path_val}")
      fi
    }
    files_append \
      "{\"path\": \"agent.md\",                       \"sha256\": \"${sha_agent}\",   \"role\": \"agent-profile\", \"mode\": \"created\"}" \
      "agent.md"
    files_append \
      "{\"path\": \"SPEC.md\",                        \"sha256\": \"${sha_spec}\",    \"role\": \"spec\",          \"mode\": \"created\"}" \
      "SPEC.md"
    files_append \
      "{\"path\": \"ECL_VERSION\",                    \"sha256\": \"${sha_ecl_ver}\", \"role\": \"ecl-version\",   \"mode\": \"created\"}" \
      "ECL_VERSION"
    files_append \
      "{\"path\": \"skills/verify-incoming.md\",      \"sha256\": \"${sha_verinc}\",  \"role\": \"skill\",         \"mode\": \"created\"}" \
      "skills/verify-incoming.md"
    files_append \
      "{\"path\": \"skills/keep-or-kick.md\",         \"sha256\": \"${sha_kok}\",     \"role\": \"skill\",         \"mode\": \"created\"}" \
      "skills/keep-or-kick.md"
    files_append \
      "{\"path\": \"skills/patch-verify.md\",         \"sha256\": \"${sha_pv}\",      \"role\": \"skill\",         \"mode\": \"created\"}" \
      "skills/patch-verify.md"
    if hosts_contains "claude-code"; then
      files_append \
        "{\"path\": \".claude/skills/${EIDOLON_SLUG}-verify-incoming/SKILL.md\", \"sha256\": \"${sha_verinc_vendor}\", \"role\": \"skill\", \"mode\": \"created\"}" \
        ""
      files_append \
        "{\"path\": \".claude/skills/${EIDOLON_SLUG}-keep-or-kick/SKILL.md\", \"sha256\": \"${sha_kok_vendor}\", \"role\": \"skill\", \"mode\": \"created\"}" \
        ""
      files_append \
        "{\"path\": \".claude/skills/${EIDOLON_SLUG}-patch-verify/SKILL.md\", \"sha256\": \"${sha_pv_vendor}\", \"role\": \"skill\", \"mode\": \"created\"}" \
        ""
    fi
    files_append \
      "{\"path\": \"schemas/ecl-envelope.v1.json\",        \"sha256\": \"${sha_ecl_env}\",  \"role\": \"other\", \"mode\": \"created\"}" \
      "schemas/ecl-envelope.v1.json"
    files_append \
      "{\"path\": \"schemas/ecl-base-profile.v1.json\",    \"sha256\": \"${sha_ecl_base}\", \"role\": \"other\", \"mode\": \"created\"}" \
      "schemas/ecl-base-profile.v1.json"
    files_append \
      "{\"path\": \"schemas/install.manifest.v1.json\",    \"sha256\": \"${sha_manifest}\", \"role\": \"other\", \"mode\": \"created\"}" \
      "schemas/install.manifest.v1.json"
    files_append \
      "{\"path\": \"schemas/kupo-edit-proposal.v1.json\",  \"sha256\": \"${sha_editprop}\", \"role\": \"other\", \"mode\": \"created\"}" \
      "schemas/kupo-edit-proposal.v1.json"

    # Codex artefacts (EIIS v1.1 §4.5.5).
    if hosts_contains "codex"; then
      if [[ -f ".codex/agents/${EIDOLON_NAME}.md" ]]; then
        sha_codex=$(sha256_file ".codex/agents/${EIDOLON_NAME}.md")
        files_append \
          "{\"path\": \".codex/agents/${EIDOLON_NAME}.md\", \"sha256\": \"${sha_codex}\", \"role\": \"dispatch\", \"mode\": \"created\"}" \
          ""
      fi
      if [[ -f "AGENTS.md" ]]; then
        sha_agents=$(sha256_file "AGENTS.md")
        files_append \
          "{\"path\": \"AGENTS.md\", \"sha256\": \"${sha_agents}\", \"role\": \"dispatch\"}" \
          ""
      fi
    fi

    # EIIS v1.4 §6.X — canonical inventory sweep. Remove any non-whitelisted
    # file from <target>/ that is not in the current files_written[] set.
    # Belt-and-braces: runs AFTER all writes, BEFORE manifest finalisation.
    canonical_inventory_sweep "${TARGET}"

    files_json="[
${files_entries}
  ]"

    # Build skills[] JSON array (EIIS v1.3 §4.2.4)
    if hosts_contains "claude-code"; then
      skills_json="[
    {\"name\": \"verify-incoming\", \"source_path\": \".eidolons/${EIDOLON_SLUG}/skills/verify-incoming.md\", \"source_sha256\": \"${sha_verinc}\", \"vendor_path\": \".claude/skills/${EIDOLON_SLUG}-verify-incoming/SKILL.md\", \"vendor_sha256\": \"${sha_verinc_vendor}\"},
    {\"name\": \"keep-or-kick\",    \"source_path\": \".eidolons/${EIDOLON_SLUG}/skills/keep-or-kick.md\",    \"source_sha256\": \"${sha_kok}\",    \"vendor_path\": \".claude/skills/${EIDOLON_SLUG}-keep-or-kick/SKILL.md\",    \"vendor_sha256\": \"${sha_kok_vendor}\"},
    {\"name\": \"patch-verify\",    \"source_path\": \".eidolons/${EIDOLON_SLUG}/skills/patch-verify.md\",    \"source_sha256\": \"${sha_pv}\",     \"vendor_path\": \".claude/skills/${EIDOLON_SLUG}-patch-verify/SKILL.md\",    \"vendor_sha256\": \"${sha_pv_vendor}\"}
  ]"
    else
      skills_json="[
    {\"name\": \"verify-incoming\", \"source_path\": \".eidolons/${EIDOLON_SLUG}/skills/verify-incoming.md\", \"source_sha256\": \"${sha_verinc}\"},
    {\"name\": \"keep-or-kick\",    \"source_path\": \".eidolons/${EIDOLON_SLUG}/skills/keep-or-kick.md\",    \"source_sha256\": \"${sha_kok}\"},
    {\"name\": \"patch-verify\",    \"source_path\": \".eidolons/${EIDOLON_SLUG}/skills/patch-verify.md\",    \"source_sha256\": \"${sha_pv}\"}
  ]"
    fi
  fi

  AGENT_TOKENS=$(wc -w < "${TARGET}/agent.md" | awk '{printf "%d", $1/0.75}')

  cat > "${TARGET}/install.manifest.json" <<MANIFEST_EOF
{
  "eidolon": "${EIDOLON_NAME}",
  "version": "${EIDOLON_VERSION}",
  "methodology": "${METHODOLOGY}",
  "installed_at": "${INSTALLED_AT}",
  "target": "${TARGET}",
  "hosts_wired": ${hosts_json},
  "canonical_inventory_strict": true,
  "spec_file": ".eidolons/${EIDOLON_SLUG}/SPEC.md",
  "skills": ${skills_json},
  "files_written": ${files_json},
  "handoffs_declared": {
    "upstream": ["spectra", "vigil", "forge", "apivr", "atlas"],
    "downstream": []
  },
  "token_budget": {
    "entry": ${AGENT_TOKENS},
    "working_set_target": 1000
  },
  "security": {
    "reads_repo": true,
    "reads_network": false,
    "writes_repo": false,
    "persists": []
  },
  "comm": {
    "envelope_version": "${ECL_VERSION}",
    "emits": ["PROPOSE", "INFORM", "ESCALATE", "REFUSE", "ACKNOWLEDGE", "RESUME"],
    "verifies": ["spec", "root-cause-report", "decision-record", "change-summary", "scout-report"]
  }
}
MANIFEST_EOF

  echo ""
  echo "${METHODOLOGY} installed to: ${TARGET}"
  echo "Hosts wired: ${HOSTS}"
  echo ""
  echo "✓ agent.md: ${AGENT_TOKENS} tokens (budget: ≤1000)"

  if [[ "${AGENT_TOKENS}" -gt 1000 && "$NON_INTERACTIVE" == "true" ]]; then
    echo "ERROR: agent.md exceeds 1000-token budget." >&2
    exit 4
  fi
fi

# --- smoke test banner ---
echo ""
echo "Smoke test:"
echo "  \"${METHODOLOGY}: rename the symbol 'oldName' to 'newName' in src/util.ts — verifier: tsc --noEmit. Propose a verified patch.\""
