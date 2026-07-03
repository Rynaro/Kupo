#!/usr/bin/env bats
# tests/ecl-v2-adoption.bats — Wave-3 ECL v2.0 adoption sweep (lightest of the eight)
#
# Kupo was already ECL-2.0-clean in prose (comm.envelope_version: "2.0" in
# agent.md/AGENTS.md frontmatter, ECL_VERSION = 2.0) but only vendored the v1
# envelope schema on disk. This sweep: (1) vendors schemas/ecl-envelope.v2.json
# (v1 retained for the ECL §7.3 back-compat window), (2) emits the optional ISE
# (Intent, Source, Entitlement) block on the outbound edit-proposal PROPOSE
# (assertion_grade: "validated", auto_merge: false), (3) documents a pending
# ECL 2.1 verification-attestation note in skills/esl-hop.md (doc-only, 2.1 is
# Draft), (4) documents an additive post-flight procedural-memory commit, and
# (5) bumps the version stamp to 1.3.0. keep-or-kick.md and verify-incoming.md
# semantics are UNCHANGED by this sweep.

load helpers.bash

INSTALL_TARGET=""

setup() {
  INSTALL_TARGET="$(mktemp -d)"
}

teardown() {
  teardown_install
}

# ─────────────────────────────────────────────────────────────────────────────
# v2 envelope schema — vendored, valid, v1 retained
# ─────────────────────────────────────────────────────────────────────────────

@test "v2: schemas/ecl-envelope.v2.json exists and is valid JSON" {
  [ -f "${REPO_ROOT}/schemas/ecl-envelope.v2.json" ]
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run jq empty "${REPO_ROOT}/schemas/ecl-envelope.v2.json"
  [ "$status" -eq 0 ]
}

@test "v2: schemas/ecl-envelope.v1.json is RETAINED (not removed by the sweep)" {
  [ -f "${REPO_ROOT}/schemas/ecl-envelope.v1.json" ]
  if command -v jq &>/dev/null; then
    run jq empty "${REPO_ROOT}/schemas/ecl-envelope.v1.json"
    [ "$status" -eq 0 ]
  fi
}

@test "v2: envelope_version pattern accepts both 1.x (compat window) and 2.0" {
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run jq -r '.properties.envelope_version.pattern' "${REPO_ROOT}/schemas/ecl-envelope.v2.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1"* ]]
  [[ "$output" == *"2"* ]]
}

@test "v2: schema declares an ise \$defs block with assertion_grade required" {
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run jq -r '.["$defs"].ise.required[0]' "${REPO_ROOT}/schemas/ecl-envelope.v2.json"
  [ "$status" -eq 0 ]
  [[ "$output" == "assertion_grade" ]]
}

@test "v2: ise.assertion_grade enum has the four ECL v2.0 §6.5.2 values" {
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run jq -r '.["$defs"].ise.properties.assertion_grade.enum[]' "${REPO_ROOT}/schemas/ecl-envelope.v2.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unverified"* ]]
  [[ "$output" == *"self-attested"* ]]
  [[ "$output" == *"validated"* ]]
  [[ "$output" == *"human-reviewed"* ]]
}

@test "v2: top-level ise property refs the \$defs/ise block" {
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run jq -r '.properties.ise["$ref"]' "${REPO_ROOT}/schemas/ecl-envelope.v2.json"
  [ "$status" -eq 0 ]
  [[ "$output" == "#/\$defs/ise" ]]
}

@test "v2: receiver_authorization defaults match ECL v2.0 §6.5.3 (auto_route true, others false)" {
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run jq -r '.["$defs"].ise.properties.receiver_authorization.properties.auto_route.default' "${REPO_ROOT}/schemas/ecl-envelope.v2.json"
  [[ "$output" == "true" ]]
  run jq -r '.["$defs"].ise.properties.receiver_authorization.properties.auto_merge.default' "${REPO_ROOT}/schemas/ecl-envelope.v2.json"
  [[ "$output" == "false" ]]
  run jq -r '.["$defs"].ise.properties.receiver_authorization.properties.auto_deploy.default' "${REPO_ROOT}/schemas/ecl-envelope.v2.json"
  [[ "$output" == "false" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# install.sh wiring — v2 schema
# ─────────────────────────────────────────────────────────────────────────────

@test "v2: install.sh copies schemas/ecl-envelope.v2.json" {
  grep -q 'cp "\${SCRIPT_DIR}/schemas/ecl-envelope.v2.json"' "${REPO_ROOT}/install.sh"
}

@test "v2: install.sh records schemas/ecl-envelope.v2.json in files_written (manifest)" {
  grep -q '"schemas/ecl-envelope.v2.json"' "${REPO_ROOT}/install.sh"
}

@test "v2: install produces schemas/ecl-envelope.v2.json in target, v1 retained" {
  run_install "${INSTALL_TARGET}"
  [ "$INSTALL_STATUS" -eq 0 ]
  [ -f "${INSTALL_TARGET}/schemas/ecl-envelope.v2.json" ]
  [ -f "${INSTALL_TARGET}/schemas/ecl-envelope.v1.json" ]
}

@test "v2: install.manifest.json records schemas/ecl-envelope.v2.json in files_written" {
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run_install "${INSTALL_TARGET}"
  local manifest="${INSTALL_TARGET}/install.manifest.json"
  run jq -e '[.files_written[] | select(.path == "schemas/ecl-envelope.v2.json")] | length > 0' "$manifest"
  [ "$status" -eq 0 ]
  [[ "$output" == "true" ]]
}

@test "v2: manifest files_written[ecl-envelope.v2.json].sha256 matches installed file" {
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run_install "${INSTALL_TARGET}"
  local manifest="${INSTALL_TARGET}/install.manifest.json"
  local declared_sha
  declared_sha="$(jq -r '[.files_written[] | select(.path == "schemas/ecl-envelope.v2.json")][0].sha256' "$manifest")"
  local actual_sha
  actual_sha="$(sha256_of "${INSTALL_TARGET}/schemas/ecl-envelope.v2.json")"
  [[ "$declared_sha" == "$actual_sha" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# ISE emission — outbound edit-proposal PROPOSE (skills/patch-verify.md)
# ─────────────────────────────────────────────────────────────────────────────

@test "ise: skills/patch-verify.md PROPOSE example declares envelope_version 2.0" {
  grep -q '"envelope_version": "2.0"' "${REPO_ROOT}/skills/patch-verify.md"
}

@test "ise: skills/patch-verify.md PROPOSE example sets assertion_grade to validated" {
  grep -q '"assertion_grade": "validated"' "${REPO_ROOT}/skills/patch-verify.md"
}

@test "ise: skills/patch-verify.md PROPOSE example sets auto_merge false (load-bearing)" {
  grep -q '"auto_merge": false' "${REPO_ROOT}/skills/patch-verify.md"
  grep -qi 'load-bearing' "${REPO_ROOT}/skills/patch-verify.md"
}

@test "ise: skills/patch-verify.md PROPOSE example sets auto_route true and auto_deploy false" {
  grep -q '"auto_route": true' "${REPO_ROOT}/skills/patch-verify.md"
  grep -q '"auto_deploy": false' "${REPO_ROOT}/skills/patch-verify.md"
}

@test "ise: validated-grade justification cites keep-or-kick.md's named-verifier gate" {
  grep -q 'skills/keep-or-kick.md' "${REPO_ROOT}/skills/patch-verify.md"
  grep -qi 'green' "${REPO_ROOT}/skills/patch-verify.md"
}

@test "ise: SPEC.md §5 documents the ISE block and points outbound validation at v2 schema" {
  grep -q 'ecl-envelope.v2.json' "${REPO_ROOT}/SPEC.md"
  grep -q 'assertion_grade: "validated"' "${REPO_ROOT}/SPEC.md"
  grep -qi 'auto_merge' "${REPO_ROOT}/SPEC.md"
}

@test "ise: SPEC.md §6 schema table lists v2 as the outbound-validation schema" {
  grep -q 'Validating an outbound PROPOSE envelope' "${REPO_ROOT}/SPEC.md"
  grep -q 'schemas/ecl-envelope.v2.json' "${REPO_ROOT}/SPEC.md"
}

# ─────────────────────────────────────────────────────────────────────────────
# ECL 2.1 verification-attestation note (doc-only, pending) — skills/esl-hop.md
# ─────────────────────────────────────────────────────────────────────────────

@test "esl-hop: documents the pending ECL 2.1 ise.verification shape" {
  grep -q 'ise.verification' "${REPO_ROOT}/skills/esl-hop.md"
  grep -q 'fresh_context' "${REPO_ROOT}/skills/esl-hop.md"
  grep -q 'transcript_access' "${REPO_ROOT}/skills/esl-hop.md"
  grep -q '"artifact-only"' "${REPO_ROOT}/skills/esl-hop.md"
}

@test "esl-hop: cites ESL 1.1 C8 for the pending attestation" {
  grep -q 'C8' "${REPO_ROOT}/skills/esl-hop.md"
}

@test "esl-hop: the note is explicit that 2.1 is Draft and NOT currently emitted" {
  grep -qi 'Draft' "${REPO_ROOT}/skills/esl-hop.md"
  grep -qi 'not emitted\|not current\|pending' "${REPO_ROOT}/skills/esl-hop.md"
}

@test "esl-hop: asserts ECL_VERSION stays 2.0 while 2.1 is Draft, and the repo file agrees" {
  grep -q 'ECL_VERSION` stays `2.0`' "${REPO_ROOT}/skills/esl-hop.md"
  local ver
  ver="$(cat "${REPO_ROOT}/ECL_VERSION" | tr -d '[:space:]')"
  [[ "$ver" == "2.0" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Memory: additive post-flight procedural commit (SPEC.md §9 + patch-verify.md)
# ─────────────────────────────────────────────────────────────────────────────

@test "memory: SPEC.md §9 documents the post-flight procedural commit" {
  grep -qi 'layer=procedural\|layer: "procedural"\|layer   = "procedural"' "${REPO_ROOT}/SPEC.md"
  grep -qi 'weak-host fix library' "${REPO_ROOT}/SPEC.md"
}

@test "memory: SPEC.md §9 keeps the graceful-skip guarantee" {
  grep -qi 'graceful skip' "${REPO_ROOT}/SPEC.md"
  grep -qi 'skipped silently' "${REPO_ROOT}/SPEC.md"
}

@test "memory: skills/patch-verify.md references the post-flight commit as SHOULD, additive" {
  grep -qi 'Post-flight procedural-memory commit' "${REPO_ROOT}/skills/patch-verify.md"
  grep -q 'SPEC.md §9' "${REPO_ROOT}/skills/patch-verify.md"
}

# ─────────────────────────────────────────────────────────────────────────────
# keep-or-kick.md / verify-incoming.md semantics UNCHANGED by this sweep
# ─────────────────────────────────────────────────────────────────────────────

@test "unchanged: skills/keep-or-kick.md still has the 4-step decision tree headers" {
  grep -q 'Step 1 — Localization check' "${REPO_ROOT}/skills/keep-or-kick.md"
  grep -q 'Step 2 — Named-verifier predicate' "${REPO_ROOT}/skills/keep-or-kick.md"
  grep -q 'Step 3 — Scope-class match' "${REPO_ROOT}/skills/keep-or-kick.md"
  grep -q 'Step 4 — Economic gate' "${REPO_ROOT}/skills/keep-or-kick.md"
}

@test "unchanged: skills/verify-incoming.md is still BLOCKING with all 8 failure codes" {
  run grep -qiE 'REFUSE|SHALL NOT|blocking' "${REPO_ROOT}/skills/verify-incoming.md"
  [ "$status" -eq 0 ]
  for code in INTEGRITY_MISMATCH UNVERIFIED SCHEMA_INVALID UNDECLARED_EDGE \
              PERFORMATIVE_NOT_ALLOWED ARTIFACT_KIND_NOT_ALLOWED \
              CONTEXT_OVER_BUDGET MISSING_REQUIRED_SECTION; do
    run grep -q "$code" "${REPO_ROOT}/skills/verify-incoming.md"
    [ "$status" -eq 0 ]
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Drift-kill: no stray "ECL v1.0" prose left in documentation
# ─────────────────────────────────────────────────────────────────────────────

@test "drift: CLAUDE.md points the load-order note at the v2 schema, not v1-only" {
  grep -q 'ecl-envelope.v2.json' "${REPO_ROOT}/CLAUDE.md"
}

@test "drift: README.md architecture tree lists both v1 (retained) and v2 schemas" {
  grep -q 'ecl-envelope.v1.json' "${REPO_ROOT}/README.md"
  grep -q 'ecl-envelope.v2.json' "${REPO_ROOT}/README.md"
}

@test "drift: no stray 'ECL v1.0' prose outside the retained v1 schemas and CHANGELOG.md" {
  local hits
  hits="$(grep -rl 'ECL v1\.0' "${REPO_ROOT}" \
    --include='*.md' --include='*.sh' --include='*.yaml' 2>/dev/null || true)"
  # Only CHANGELOG.md (historical + this sweep's own note) is allowed to match.
  local f
  for f in $hits; do
    [[ "$(basename "$f")" == "CHANGELOG.md" ]]
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Version stamp — 5 canonical homes at 1.3.0
# ─────────────────────────────────────────────────────────────────────────────

@test "stamp: install.sh, agent.md, AGENTS.md, SPEC.md, hosts/claude-code.md agree on 1.3.0" {
  grep -q 'EIDOLON_VERSION="1.3.0"' "${REPO_ROOT}/install.sh"
  grep -q '^version: 1.3.0' "${REPO_ROOT}/agent.md"
  grep -q '^version: 1.3.0' "${REPO_ROOT}/AGENTS.md"
  grep -q '^version: 1.3.0' "${REPO_ROOT}/SPEC.md"
  grep -q '^version: 1.3.0' "${REPO_ROOT}/hosts/claude-code.md"
}

@test "stamp: install.sh --version prints 1.3.0" {
  run bash "${REPO_ROOT}/install.sh" --version
  [ "$status" -eq 0 ]
  [[ "$output" == "1.3.0" ]]
}

@test "stamp: CHANGELOG.md has a [1.3.0] entry" {
  grep -q '\[1.3.0\]' "${REPO_ROOT}/CHANGELOG.md"
}

@test "stamp: no lingering 1.2.0 version stamp outside CHANGELOG.md history" {
  local hits
  hits="$(grep -rl '"1\.2\.0"\|EIDOLON_VERSION="1.2.0"\|^version: 1.2.0' "${REPO_ROOT}" \
    --include='*.md' --include='*.sh' 2>/dev/null || true)"
  local f
  for f in $hits; do
    [[ "$(basename "$f")" == "CHANGELOG.md" ]]
  done
}
