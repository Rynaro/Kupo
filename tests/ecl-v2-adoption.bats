#!/usr/bin/env bats
# tests/ecl-v2-adoption.bats — Wave-3 ECL v2.0 adoption sweep (lightest of the eight)
#
# Kupo was already ECL-2.0-clean in prose (comm.envelope_version: "2.0" in
# PERSONA.md/AGENTS.md frontmatter, ECL_VERSION = 2.0) but only vendored the v1
# envelope schema on disk. This sweep: (1) vendors schemas/ecl-envelope.v2.json
# (v1 retained for the ECL §7.3 back-compat window), (2) emits the optional ISE
# (Intent, Source, Entitlement) block on the outbound edit-proposal PROPOSE
# (assertion_grade: "validated", auto_merge: false), (3) documents a pending
# ECL 2.1 verification-attestation note in skills/esl-hop/SKILL.md (doc-only, 2.1 is
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






# ─────────────────────────────────────────────────────────────────────────────
# ISE emission — outbound edit-proposal PROPOSE (skills/patch-verify/SKILL.md)
# ─────────────────────────────────────────────────────────────────────────────

@test "ise: skills/patch-verify/SKILL.md PROPOSE example declares envelope_version 2.0" {
  grep -q '"envelope_version": "2.0"' "${REPO_ROOT}/skills/patch-verify/SKILL.md"
}

@test "ise: skills/patch-verify/SKILL.md PROPOSE example sets assertion_grade to validated" {
  grep -q '"assertion_grade": "validated"' "${REPO_ROOT}/skills/patch-verify/SKILL.md"
}

@test "ise: skills/patch-verify/SKILL.md PROPOSE example sets auto_merge false (load-bearing)" {
  grep -q '"auto_merge": false' "${REPO_ROOT}/skills/patch-verify/SKILL.md"
  grep -qi 'load-bearing' "${REPO_ROOT}/skills/patch-verify/SKILL.md"
}

@test "ise: skills/patch-verify/SKILL.md PROPOSE example sets auto_route true and auto_deploy false" {
  grep -q '"auto_route": true' "${REPO_ROOT}/skills/patch-verify/SKILL.md"
  grep -q '"auto_deploy": false' "${REPO_ROOT}/skills/patch-verify/SKILL.md"
}

@test "ise: validated-grade justification cites keep-or-kick.md's named-verifier gate" {
  grep -q 'skills/keep-or-kick/SKILL.md' "${REPO_ROOT}/skills/patch-verify/SKILL.md"
  grep -qi 'green' "${REPO_ROOT}/skills/patch-verify/SKILL.md"
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
# ECL 2.1 verification-attestation note (doc-only, pending) — skills/esl-hop/SKILL.md
# ─────────────────────────────────────────────────────────────────────────────

@test "esl-hop: documents the pending ECL 2.1 ise.verification shape" {
  grep -q 'ise.verification' "${REPO_ROOT}/skills/esl-hop/SKILL.md"
  grep -q 'fresh_context' "${REPO_ROOT}/skills/esl-hop/SKILL.md"
  grep -q 'transcript_access' "${REPO_ROOT}/skills/esl-hop/SKILL.md"
  grep -q '"artifact-only"' "${REPO_ROOT}/skills/esl-hop/SKILL.md"
}

@test "esl-hop: cites ESL 1.1 C8 for the pending attestation" {
  grep -q 'C8' "${REPO_ROOT}/skills/esl-hop/SKILL.md"
}

@test "esl-hop: the note is explicit that 2.1 is Draft and NOT currently emitted" {
  grep -qi 'Draft' "${REPO_ROOT}/skills/esl-hop/SKILL.md"
  grep -qi 'not emitted\|not current\|pending' "${REPO_ROOT}/skills/esl-hop/SKILL.md"
}

@test "esl-hop: asserts ECL_VERSION stays 2.0 while 2.1 is Draft, and the repo file agrees" {
  grep -q 'ECL_VERSION` stays `2.0`' "${REPO_ROOT}/skills/esl-hop/SKILL.md"
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

@test "memory: skills/patch-verify/SKILL.md references the post-flight commit as SHOULD, additive" {
  grep -qi 'Post-flight procedural-memory commit' "${REPO_ROOT}/skills/patch-verify/SKILL.md"
  grep -q 'SPEC.md §9' "${REPO_ROOT}/skills/patch-verify/SKILL.md"
}

# ─────────────────────────────────────────────────────────────────────────────
# keep-or-kick.md / verify-incoming.md semantics UNCHANGED by this sweep
# ─────────────────────────────────────────────────────────────────────────────

@test "unchanged: skills/keep-or-kick/SKILL.md still has the 4-step decision tree headers" {
  grep -q 'Step 1 — Localization check' "${REPO_ROOT}/skills/keep-or-kick/SKILL.md"
  grep -q 'Step 2 — Named-verifier predicate' "${REPO_ROOT}/skills/keep-or-kick/SKILL.md"
  grep -q 'Step 3 — Scope-class match' "${REPO_ROOT}/skills/keep-or-kick/SKILL.md"
  grep -q 'Step 4 — Economic gate' "${REPO_ROOT}/skills/keep-or-kick/SKILL.md"
}

@test "unchanged: skills/verify-incoming/SKILL.md is still BLOCKING with all 8 failure codes" {
  run grep -qiE 'REFUSE|SHALL NOT|blocking' "${REPO_ROOT}/skills/verify-incoming/SKILL.md"
  [ "$status" -eq 0 ]
  for code in INTEGRITY_MISMATCH UNVERIFIED SCHEMA_INVALID UNDECLARED_EDGE \
              PERFORMATIVE_NOT_ALLOWED ARTIFACT_KIND_NOT_ALLOWED \
              CONTEXT_OVER_BUDGET MISSING_REQUIRED_SECTION; do
    run grep -q "$code" "${REPO_ROOT}/skills/verify-incoming/SKILL.md"
    [ "$status" -eq 0 ]
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Drift-kill: no stray "ECL v1.0" prose left in documentation
# ─────────────────────────────────────────────────────────────────────────────


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
