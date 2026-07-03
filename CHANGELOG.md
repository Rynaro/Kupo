# Changelog

All notable changes to Kupo are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning: [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

---

## [1.3.0] - 2026-07-03

### Added

- **ECL v2.0 vendoring.** `schemas/ecl-envelope.v2.json` — self-contained
  vendored copy of `eidolons-ecl@v2.0.0`'s `schemas/envelope.v2.json`
  (`spec/ecl-2.0.md` §6.5), following the same inlined-enum, self-contained
  convention as the existing `schemas/ecl-envelope.v1.json`. The v1 file is
  **retained**, not replaced — Kupo can still validate a v1.x sidecar
  received during the ECL §7.3 compatibility window (through 2027-05-13).
  Kupo was already ECL-2.0-clean in prose (`comm.envelope_version: "2.0"` in
  `agent.md`/`AGENTS.md` frontmatter, `ECL_VERSION` = `2.0`) but only vendored
  the v1 schema on disk — this closes that gap. Wired into `install.sh`
  (unconditional `cp`, role `other`, manifest `files_written[]`).
- **ISE (Intent, Source, Entitlement) emission on the outbound `edit-proposal`
  PROPOSE** (ECL v2.0 §6.5). `skills/patch-verify.md`'s "ECL emission" step
  gains `ise.assertion_grade: "validated"` — the only grade Kupo ever emits,
  because Kupo cannot reach PROPOSE without first passing the
  pre-completion green-signal gate: a NAMED external verifier (the one
  `skills/keep-or-kick.md`'s structural KEEP predicate required to exist
  before the task was even accepted) exited green in the sandbox. "Emitter
  ran spec-mandated gates" is true by construction, never a self-report.
  Plus `ise.receiver_authorization: {auto_route: true, auto_merge: false,
  auto_deploy: false}` — `auto_merge: false` is load-bearing, not
  boilerplate: the parent applies and commits (PROPOSE-only P0); Kupo's own
  verified signal never authorizes a receiver to merge on its say-so. Plus
  `ise.provenance.methodology_version: "kupo-1.3.0"` (`lateral_consults`
  always empty — worker-never-router). `SPEC.md §5` documents the full
  rationale; `SPEC.md §6`'s schema table now points outbound validation at
  the v2 schema.
- **ECL 2.1 verification-attestation note (doc-only, pending).**
  `skills/esl-hop.md` gains a "Looking ahead" section documenting that once
  ECL 2.1 (currently Draft — adoption-gated, `spec/ecl-2.1.md`) is cut to
  Published, the verify envelope Kupo composes as CHECKER for Vivi/APIVR-Δ
  makers will carry `ise.verification: {fresh_context: true, checker:
  "kupo", transcript_access: "artifact-only"}` per ESL 1.1's C8 check
  (§5.4/§8.2). This is **documentation of a pending shape — not current
  emission**; `ECL_VERSION` stays `2.0` and this skill does not emit
  `ise.verification` today.
- **Memory: post-flight procedural commit (SHOULD, additive).** `SPEC.md §9`
  and `skills/patch-verify.md` step 5 now document that after a KEEP task's
  Phase O produces its green external signal, Kupo SHOULD commit the
  verified edit pattern (`task_class`, `verifier`, `pattern_summary`) to
  CRYSTALIUM `layer=procedural` with `quality: "verified"` as part of the
  standard post-flight, building a reusable weak-host fix library across
  delegations. Additive prose only — no new tooling, never blocks or delays
  PROPOSE, graceful-skip when CRYSTALIUM is absent (unchanged posture).

### Changed

- **ECL prose drift kill.** `CLAUDE.md`'s load-order note and `README.md`'s
  architecture tree updated to list both the retained v1 schema and the new
  v2 schema, instead of only v1.
- **Version stamp bumped to 1.3.0** across the 5 canonical homes:
  `install.sh` (`EIDOLON_VERSION`), `agent.md`, `AGENTS.md`, `SPEC.md`,
  `hosts/claude-code.md`.

### Tests

- New `tests/ecl-v2-adoption.bats`: v2 schema vendored + valid + v1 retained,
  `$defs.ise` shape (`assertion_grade` required, four-value enum), install.sh
  wiring (source cp, manifest `files_written[]`, installed-target presence),
  ISE emission asserted on the `skills/patch-verify.md` PROPOSE example
  (`assertion_grade: "validated"`, `auto_merge: false`), the ECL 2.1
  pending-note in `skills/esl-hop.md`, the memory post-flight-commit prose in
  `SPEC.md`/`skills/patch-verify.md`, drift-kill greps (no stray "ECL v1.0"
  prose outside the retained v1 schema's own self-description and
  CHANGELOG.md), and the 5-canonical-homes version-stamp check.

---

## [1.2.0] - 2026-06-25

### Added

- `skills/esl-hop.md` (`kupo-esl-hop`) — ESL (Eidolons Spec Lifecycle) adoption.
  In an ESL-enabled project (`mcp__tonberry__*` available), when the cortex routes
  a verification to Kupo, Kupo is the **CHECKER** and owns the **verified**
  transition: run the external verifiers against the change's `acceptance_checks`,
  call `mcp__tonberry__verify <change-dir> --mode <enforcement>` (the 6 conformance
  checks C1–C6, incl. C4 maker≠checker), compose the verify envelope with
  `from.eidolon = kupo` (MUST differ from `change.json.maker`), and on pass call
  `mcp__tonberry__transition --to_status verified` + PROPOSE `verify_pass`; on fail
  ESCALATE (the checker cannot make). **Graceful skip:** tonberry absent → run the
  normal verify, never hard-fail (ESL is opt-in). References the nexus cortex
  `methodology/cortex/esl-protocol.md`. Replicates the proven SPECTRA esl-hop
  pattern (the checker half of the maker≠checker pair).
- Skill wired through `install.sh` for all hosts: source-of-truth
  `skills/esl-hop.md` + `.claude/skills/kupo-esl-hop/SKILL.md` (manifest-listed) +
  `.github/instructions/kupo-esl-hop.instructions.md` +
  `.cursor/rules/kupo-esl-hop.mdc`. New `skills[]` + `files_written[]` manifest
  entries; `LEGACY_SKILL_DIRS` gains `esl-hop`.
- Skill-loading row added in `agent.md`, `SPEC.md §6`, and `AGENTS.md`.

### Changed

- Version stamp bumped to 1.2.0 across all canonical homes: `install.sh`
  (`EIDOLON_VERSION`), `agent.md`, `AGENTS.md`, `SPEC.md`, `hosts/claude-code.md`.

---

## [1.1.1] - 2026-06-10

### Added

- `.claude/agents/kupo.md` subagent dispatch file now includes an explicit
  `tools:` allowlist in frontmatter: `Read, Grep, Glob,
  Bash(eidolons sandbox:*), Bash(make:*), Bash(bats:*), Bash(rspec:*),
  Bash(jest:*), Bash(pytest:*), Bash(go test:*), Bash(shellcheck:*),
  Bash(shasum:*), Bash(wc:*)`. Previously the heredoc emitted no `tools:`
  line, leaving Kupo crystalium-only and unable to Read files in the
  Understand phase, invoke the sandbox applier, or run its mandatory external
  verifier. PROPOSE-only boundary preserved: no Write/Edit tools granted.
  `mcp__crystalium__*` is omitted — nexus wiring appends it separately.

### Changed

- Version stamp bumped to 1.1.1 across all canonical homes: `install.sh`,
  `agent.md`, `AGENTS.md`, `SPEC.md`.
- `hosts/claude-code.md`: subagent dispatch example updated with `tools:`
  line; `agent.md` frontmatter example version bumped to 1.1.1.

---

## [1.1.0] - 2026-06-10

### Changed

- Version-stamp sweep: all canonical homes bumped to 1.1.0 (install.sh, agent.md,
  AGENTS.md, SPEC.md frontmatter headers). Doc/template footers stripped of inline
  version strings per D1 policy.
- README footer: stripped stale `v0.1.0 — in_construction` tag.
- Skills: added canonical EIIS skill frontmatter (`name`, `description`, `metadata:`)
  to all three skills (kupo-verify-incoming, kupo-keep-or-kick, kupo-patch-verify).
  Descriptions are host-visible; bodies preserved verbatim.
- ECL trace placeholders: `"to":"kupo@1.0"` → `"to":"kupo@<version>"`;
  `"version":"1.0.0"` envelope template → `"<version>"` in patch-verify.md.
- schemas/install.manifest.v1.json `$id`: EIIS URL bumped from v1.0.0 → v1.4.0.
- hosts/claude-code.md example frontmatter: version bumped to 1.1.0.
- CHANGELOG: backfilled [1.0.0] entry (promotion from in_construction 0.1.0).

---

## [1.0.0] - 2026-06-08

### Changed

- Promoted from `in_construction` (0.1.0) to shipped stable release.
- Roster status flipped to active; MASTER eval-gate passed (KEEP-cohort 36/36).
- All 0.1.0 content retained; version stamps updated to 1.0.0.

---

## [0.1.0] - 2026-06-08

### Added

- Initial in_construction release of Kupo, the low-effort executor Eidolon.
- `agent.md` — always-loaded entry point (≤1000 tokens). K→U→P→O cycle
  summary, scope-guard table, skill loading table, PROPOSE-only P0 rules.
- `SPEC.md` — full KUPO methodology: §1 Identity, §2 KUPO Cycle (K/U/P/O
  entry+exit gates), §3 Scope-Guard Taxonomy (9 KEEP + 6 REFUSE/ESCALATE
  classes + additive-proof clause + MASTER eval-gate), §4 Sandbox+Harness-Applier
  Contract, §5 ECL Composition v2.0, §6 Skill/Schema loading tables, §7 Guardrails,
  §8 Invocation Protocol, §9 Memory Protocol (CRYSTALIUM).
- `ECL_VERSION` — `2.0`.
- `EIIS_VERSION` — `1.4`.
- `skills/verify-incoming.md` — blocking ECL §6.2.2 receiver gate; 6-row
  inbound-edge table; 8 failure codes; trace event schema.
- `skills/keep-or-kick.md` — Phase K triage: localization check, named-verifier
  predicate, scope-class match, economic gate; KEEP/REFUSE/ESCALATE output format.
- `skills/patch-verify.md` — Phase P+O loop: edit emission (search/replace +
  whole-file), harness applier, per-file loop detector, circuit-breaker 3/20,
  pre-completion green-signal gate, edit-proposal + ECL PROPOSE construction.
- `schemas/kupo-edit-proposal.v1.json` — JSON Schema for the edit-proposal
  artefact Kupo emits via ECL PROPOSE.
- `schemas/ecl-envelope.v1.json` — vendored ECL envelope schema.
- `schemas/ecl-base-profile.v1.json` — vendored ECL base profile.
- `schemas/install.manifest.v1.json` — vendored EIIS manifest schema.
- `contracts/` — 11 ECL per-edge contracts: 6 inbound
  (spectra/vigil/forge/apivr/atlas/human → kupo) + 5 outbound
  (kupo → spectra/vigil/forge/apivr/atlas).
- `AGENTS.md`, `CLAUDE.md`, `README.md`, `INSTALL.md` — repository documentation.
- `hosts/claude-code.md` — Claude Code host wiring guide.
- `tests/verify-incoming.bats` — bats test suite for the blocking gate.
- `evals/canary-missions.md` — smoke missions for install verification.

### Notes

- Status: `in_construction`. Roster debut pins `0.1.0`. Deployment-grade reliance
  is GATED on a Kupo KEEP-cohort eval (the MASTER eval-gate).
- ECL_VERSION = 2.0, EIIS_VERSION = 1.4.
- Methodology version = 1.0.0 (shipped alongside the 0.1.0 repo debut).
