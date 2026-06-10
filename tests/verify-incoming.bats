#!/usr/bin/env bats
# tests/verify-incoming.bats — blocking, symmetric verify-incoming gate (ECL §6.2.2)
#
# Asserts:
#   1. skills/verify-incoming.md exists in the repo and declares BLOCKING posture.
#   2. It does NOT declare warn-only / "payload is always processed" / "process anyway".
#   3. install.sh (non-interactive) installs skills/verify-incoming.md into the target.
#   4. install.manifest.json records skills/verify-incoming.md (source_path).
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

@test "skills/verify-incoming.md exists in the repo" {
  [ -f "${REPO_ROOT}/skills/verify-incoming.md" ]
}

@test "skills/verify-incoming.md declares BLOCKING posture" {
  run grep -qiE 'REFUSE|SHALL NOT|blocking' "${REPO_ROOT}/skills/verify-incoming.md"
  [ "$status" -eq 0 ]
}

@test "skills/verify-incoming.md contains 'Do not process' language" {
  run grep -qiE 'Do not process' "${REPO_ROOT}/skills/verify-incoming.md"
  [ "$status" -eq 0 ]
}

@test "skills/verify-incoming.md does NOT declare warn-only posture as the current behaviour" {
  # Negative assertion: the skill must NOT instruct the receiver to PROCESS
  # a tampered or unverified payload (i.e. adopt the old warn-only posture).
  run grep -qiE 'always processes?|shall process|must process|proceed.*anyway|process.*despite' \
    "${REPO_ROOT}/skills/verify-incoming.md"
  # grep must NOT find a match (exit 1)
  [ "$status" -ne 0 ]
}

@test "skills/verify-incoming.md does NOT contain 'process the payload anyway'" {
  run grep -qi 'process the payload anyway' "${REPO_ROOT}/skills/verify-incoming.md"
  [ "$status" -ne 0 ]
}

@test "skills/verify-incoming.md contains inbound-edge table with 6 rows" {
  # All 6 senders must be listed: spectra, vigil, forge, apivr, atlas, human
  for sender in spectra vigil forge apivr atlas human; do
    run grep -qi "$sender" "${REPO_ROOT}/skills/verify-incoming.md"
    [ "$status" -eq 0 ]
  done
}

@test "skills/verify-incoming.md lists all 8 failure codes" {
  for code in INTEGRITY_MISMATCH UNVERIFIED SCHEMA_INVALID UNDECLARED_EDGE \
              PERFORMATIVE_NOT_ALLOWED ARTIFACT_KIND_NOT_ALLOWED \
              CONTEXT_OVER_BUDGET MISSING_REQUIRED_SECTION; do
    run grep -q "$code" "${REPO_ROOT}/skills/verify-incoming.md"
    [ "$status" -eq 0 ]
  done
}

@test "skills/verify-incoming.md has canonical EIIS skill frontmatter" {
  # D2: skills now carry canonical frontmatter (name, description, metadata).
  run grep -q '^name: kupo-verify-incoming' "${REPO_ROOT}/skills/verify-incoming.md"
  [ "$status" -eq 0 ]
  run grep -q '^description:' "${REPO_ROOT}/skills/verify-incoming.md"
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

@test "EIIS_VERSION file exists and contains 1.4" {
  [ -f "${REPO_ROOT}/EIIS_VERSION" ]
  local ver
  ver="$(cat "${REPO_ROOT}/EIIS_VERSION")"
  ver="$(echo "$ver" | tr -d '[:space:]')"
  [ "$ver" = "1.4" ]
}

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

@test "install.sh exits 0 with --hosts none" {
  run_install "${INSTALL_TARGET}"
  [ "$INSTALL_STATUS" -eq 0 ]
}

@test "install.sh writes skills/verify-incoming.md into target" {
  run_install "${INSTALL_TARGET}"
  [ -f "${INSTALL_TARGET}/skills/verify-incoming.md" ]
}

@test "installed skills/verify-incoming.md content matches source" {
  run_install "${INSTALL_TARGET}"
  local src="${REPO_ROOT}/skills/verify-incoming.md"
  local dst="${INSTALL_TARGET}/skills/verify-incoming.md"
  [ -f "$dst" ]
  run diff "$src" "$dst"
  [ "$status" -eq 0 ]
}

# ── Manifest assertions ───────────────────────────────────────────────────────

@test "install.manifest.json is generated" {
  run_install "${INSTALL_TARGET}"
  [ -f "${INSTALL_TARGET}/install.manifest.json" ]
}

@test "install.manifest.json records skills/verify-incoming.md in files_written" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not available"
  fi
  run_install "${INSTALL_TARGET}"
  local manifest="${INSTALL_TARGET}/install.manifest.json"
  run jq -e '[.files_written[] | select(.path == "skills/verify-incoming.md")] | length > 0' \
    "$manifest"
  [ "$status" -eq 0 ]
  [[ "$output" == "true" ]]
}

@test "install.manifest.json records skills/verify-incoming.md in skills[]" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not available"
  fi
  run_install "${INSTALL_TARGET}"
  local manifest="${INSTALL_TARGET}/install.manifest.json"
  run jq -e '[.skills[] | select(.name == "verify-incoming")] | length > 0' \
    "$manifest"
  [ "$status" -eq 0 ]
  [[ "$output" == "true" ]]
}

@test "manifest skills[verify-incoming].source_path points at kupo skills dir" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not available"
  fi
  run_install "${INSTALL_TARGET}"
  local manifest="${INSTALL_TARGET}/install.manifest.json"
  run jq -r '.skills[] | select(.name == "verify-incoming") | .source_path' "$manifest"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kupo/skills/verify-incoming.md"* ]]
}

@test "manifest files_written[verify-incoming].sha256 matches installed file" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not available"
  fi
  run_install "${INSTALL_TARGET}"
  local manifest="${INSTALL_TARGET}/install.manifest.json"
  local declared_sha
  declared_sha="$(jq -r '[.files_written[] | select(.path == "skills/verify-incoming.md")][0].sha256' "$manifest")"
  local actual_sha
  actual_sha="$(sha256_of "${INSTALL_TARGET}/skills/verify-incoming.md")"
  [[ "$declared_sha" == "$actual_sha" ]]
}

# ── Vendor copy (claude-code host) ───────────────────────────────────────────

@test "install.sh with --hosts claude-code writes vendor SKILL.md" {
  # Seed CLAUDE.md so detect_hosts would pick it up; but we pass --hosts explicitly.
  run bash "${REPO_ROOT}/install.sh" \
    --non-interactive \
    --force \
    --target "${INSTALL_TARGET}" \
    --hosts claude-code
  [ "$status" -eq 0 ]
  [ -f ".claude/skills/kupo-verify-incoming/SKILL.md" ]
  # Cleanup vendor copy
  rm -rf ".claude/skills/kupo-verify-incoming"
}

@test "vendor SKILL.md content matches source when claude-code wired" {
  run bash "${REPO_ROOT}/install.sh" \
    --non-interactive \
    --force \
    --target "${INSTALL_TARGET}" \
    --hosts claude-code
  [ "$status" -eq 0 ]
  local vendor=".claude/skills/kupo-verify-incoming/SKILL.md"
  [ -f "$vendor" ]
  run diff "${REPO_ROOT}/skills/verify-incoming.md" "$vendor"
  [ "$status" -eq 0 ]
  # Cleanup vendor copy
  rm -rf ".claude/skills/kupo-verify-incoming"
}
