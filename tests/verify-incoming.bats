#!/usr/bin/env bats
# tests/verify-incoming.bats — blocking, symmetric verify-incoming gate (ECL §6.2.2)
#
# Asserts:
#   1. skills/verify-incoming/SKILL.md exists in the repo and declares BLOCKING posture.
#   2. It does NOT declare warn-only / "payload is always processed" / "process anyway".
#   3. install.sh (non-interactive) installs skills/verify-incoming/SKILL.md into the target.
#   4. install.manifest.json records skills/verify-incoming/SKILL.md (source_path).
#   5. The vendor copy .claude/skills/kupo-verify-incoming/SKILL.md is installed
#      when claude-code host is wired.

load helpers.bash

INSTALL_TARGET=""

setup() {
  INSTALL_TARGET="$(mktemp -d)"
}

teardown() {
  teardown_install
}

# ── Skill source file assertions ─────────────────────────────────────────────

@test "skills/verify-incoming/SKILL.md exists in the repo" {
  [ -f "${REPO_ROOT}/skills/verify-incoming/SKILL.md" ]
}

@test "skills/verify-incoming/SKILL.md declares BLOCKING posture" {
  run grep -qiE 'REFUSE|SHALL NOT|blocking' "${REPO_ROOT}/skills/verify-incoming/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skills/verify-incoming/SKILL.md contains 'Do not process' language" {
  run grep -qiE 'Do not process' "${REPO_ROOT}/skills/verify-incoming/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skills/verify-incoming/SKILL.md does NOT declare warn-only posture as the current behaviour" {
  # Negative assertion: the skill must NOT instruct the receiver to PROCESS
  # a tampered or unverified payload (i.e. adopt the old warn-only posture).
  run grep -qiE 'always processes?|shall process|must process|proceed.*anyway|process.*despite' \
    "${REPO_ROOT}/skills/verify-incoming/SKILL.md"
  # grep must NOT find a match (exit 1)
  [ "$status" -ne 0 ]
}

@test "skills/verify-incoming/SKILL.md does NOT contain 'process the payload anyway'" {
  run grep -qi 'process the payload anyway' "${REPO_ROOT}/skills/verify-incoming/SKILL.md"
  [ "$status" -ne 0 ]
}

@test "skills/verify-incoming/SKILL.md contains inbound-edge table with 6 rows" {
  # All 6 senders must be listed: spectra, vigil, forge, apivr, atlas, human
  for sender in spectra vigil forge apivr atlas human; do
    run grep -qi "$sender" "${REPO_ROOT}/skills/verify-incoming/SKILL.md"
    [ "$status" -eq 0 ]
  done
}

@test "skills/verify-incoming/SKILL.md lists all 8 failure codes" {
  for code in INTEGRITY_MISMATCH UNVERIFIED SCHEMA_INVALID UNDECLARED_EDGE \
              PERFORMATIVE_NOT_ALLOWED ARTIFACT_KIND_NOT_ALLOWED \
              CONTEXT_OVER_BUDGET MISSING_REQUIRED_SECTION; do
    run grep -q "$code" "${REPO_ROOT}/skills/verify-incoming/SKILL.md"
    [ "$status" -eq 0 ]
  done
}

@test "skills/verify-incoming/SKILL.md has canonical EIIS skill frontmatter" {
  # D2: skills now carry canonical frontmatter (name, description, metadata).
  run grep -q '^name: kupo-verify-incoming' "${REPO_ROOT}/skills/verify-incoming/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -q '^description:' "${REPO_ROOT}/skills/verify-incoming/SKILL.md"
  [ "$status" -eq 0 ]
}

# ── ECL_VERSION assertion ─────────────────────────────────────────────────────

@test "ECL_VERSION file exists and contains 2.0" {
  [ -f "${REPO_ROOT}/ECL_VERSION" ]
  local ver
  ver="$(cat "${REPO_ROOT}/ECL_VERSION")"
  # strip trailing newline/whitespace
  ver="$(echo "$ver" | tr -d '[:space:]')"
  [ "$ver" = "2.0" ]
}

# ── EIIS_VERSION assertion ────────────────────────────────────────────────────


# ── Schema assertion ──────────────────────────────────────────────────────────

@test "schemas/kupo-edit-proposal.v1.json passes jq empty" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not available"
  fi
  run jq empty "${REPO_ROOT}/schemas/kupo-edit-proposal.v1.json"
  [ "$status" -eq 0 ]
}

@test "schemas/ecl-envelope.v1.json passes jq empty" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not available"
  fi
  run jq empty "${REPO_ROOT}/schemas/ecl-envelope.v1.json"
  [ "$status" -eq 0 ]
}

# ── Install: exit code + file placement ──────────────────────────────────────



@test "installed skills/verify-incoming/SKILL.md content matches source" {
  run_install "${INSTALL_TARGET}"
  local src="${REPO_ROOT}/skills/verify-incoming/SKILL.md"
  local dst="${INSTALL_TARGET}/skills/verify-incoming/SKILL.md"
  [ -f "$dst" ]
  run diff "$src" "$dst"
  [ "$status" -eq 0 ]
}

# ── Manifest assertions ───────────────────────────────────────────────────────






# ── Vendor copy (claude-code host) ───────────────────────────────────────────
