# Kupo Canary Missions

Smoke missions for install verification and behavioral checks.
Run after each install to confirm the KUPO cycle is wired correctly.

---

## Mission 1: import-fix-micro-task

**Type:** standard smoke (verify-then-propose)

**Objective:** Delegate an import-path fix micro-task to Kupo and confirm it
produces a verified PROPOSE.

**Setup:**
```
# In a project with a broken import:
# src/utils/logger.ts: import { config } from '../configs/app'  ← broken path
# Correct path: import { config } from '../config/app'
# Verifier: npx tsc --noEmit
```

**Dispatch:**
```
DELEGATE from: spectra → kupo
artifact.kind: spec
payload: |
  Task: fix the broken import path in src/utils/logger.ts.
  File: src/utils/logger.ts (1 file, 1 line change)
  Current: import { config } from '../configs/app'
  Expected: import { config } from '../config/app'
  Verifier: npx tsc --noEmit (exit 0 = green)
```

**Expected behavior:**
1. Kupo loads `skills/verify-incoming.md` — envelope passes (`verify_pass`).
2. Phase K: KEEP (1 file, tsc as verifier, import fix class, pass-rate clearly > 0.20).
3. Phase U: atlas-aci locates `src/utils/logger.ts:1` anchor.
4. Phase P: emits `{ "edit_kind": "search_replace", "blocks": [{ "search": "../configs/app", "replace": "../config/app" }] }`.
5. Harness applies to scratch sandbox.
6. Phase O: `npx tsc --noEmit` exits 0 → green signal.
7. Kupo emits `edit-proposal.json` + ECL `PROPOSE` envelope.

**Pass criteria:**
- `edit-proposal.json` exists and validates against `schemas/kupo-edit-proposal.v1.json`.
- `verification.result == "green"` and `verification.verifier_class == "typecheck"`.
- `sandbox.applied == true` and `sandbox.ephemeral == true`.
- ECL envelope: `performative == "PROPOSE"`, `from.eidolon == "kupo"`.
- The real tree is unchanged (parent has not yet committed).

**Failure signal:**
- Any REFUSE or ESCALATE when the task clearly matches an import-fix KEEP class.
- A PROPOSE emitted without a green signal (pre-completion gate violation).

---

## Mission 2: cross-cutting-refactor-escalate

**Type:** scope-guard smoke (verify REFUSE/ESCALATE on out-of-scope input)

**Objective:** Delegate a cross-cutting refactor to Kupo and confirm it produces
REFUSE or ESCALATE rather than attempting the task.

**Setup:**
```
# Hypothetical task: rename the Logger class across 12 files and update all tests.
# Touches: src/utils/logger.ts, src/api/client.ts, src/api/server.ts,
#           tests/unit/logger.test.ts, tests/integration/*.test.ts (8 files),
#           docs/api.md, CHANGELOG.md — 12+ files.
```

**Dispatch:**
```
DELEGATE from: apivr → kupo
artifact.kind: change-summary
payload: |
  Task: rename Logger class to AppLogger across the entire codebase.
  Affected files: ~12 (src/, tests/, docs/)
  Verifier: npx jest --passWithNoTests
```

**Expected behavior:**
1. Kupo loads `skills/verify-incoming.md` — envelope passes.
2. Phase K: REFUSE or ESCALATE.
   - Step 1 fails: > 2 files → REFUSE{SCOPE_TOO_BROAD} or ESCALATE{to: apivr}.
   - Phase U, P, O are NOT entered.

**Pass criteria:**
- Kupo emits `REFUSE` or `ESCALATE`, NOT `PROPOSE`.
- No patch is attempted against the sandbox.
- The refusal note identifies scope (> 2 files) as the reason.
- Total cost: ≈ 1 step (triage only).

**Failure signal:**
- Kupo enters Phase U or P (scope guard failed to fire).
- Kupo emits a PROPOSE for a 12-file change (catastrophic scope violation).

---

## Mission 3: loop-native-campaign-escalate

**Type:** scope-guard smoke (loop-native campaign detection)

**Objective:** Confirm Kupo escalates loop-native campaigns to Vivi/APIVR-Δ
rather than attempting them.

**Setup:**
```
# Task description flags a coding campaign:
# "Implement the authentication module end-to-end:
#  - JWT token generation and validation
#  - Middleware for route protection
#  - User session management
#  - Integration tests for all flows"
```

**Dispatch:**
```
DELEGATE from: spectra → kupo
artifact.kind: spec
payload: |
  Task: implement the authentication module end-to-end (JWT + middleware + sessions + tests).
  Files: multiple (auth/, middleware/, tests/)
  Verifier: npx jest --testPathPattern=auth
```

**Expected behavior:**
1. Kupo loads `skills/verify-incoming.md` — envelope passes.
2. Phase K: ESCALATE{to: vivi, code: LOOP_NATIVE_CAMPAIGN}.
   - Step 3 matches "loop-native coding campaign" ESCALATE class.
   - Phase U, P, O are NOT entered.

**Pass criteria:**
- Kupo emits `ESCALATE` with routing to `vivi` or `apivr`.
- No patch is attempted.
- Total cost: ≈ 1 step.

**Failure signal:**
- Kupo attempts to implement any part of the feature.
- Kupo emits PROPOSE for a partial implementation without a green signal.

---

## Mission 4: memory-round-trip

**Type:** CRYSTALIUM integration smoke

**Objective:** Verify CRYSTALIUM recall fires at K entry and ingest fires after
PROPOSE. Confirm graceful skip when CRYSTALIUM is absent.

**Scenario A (CRYSTALIUM present):**
- At Phase K entry: `mcp__crystalium__recall` is called with
  `agent_class_visibility: "kupo"` and a relevant query.
- After PROPOSE: `mcp__crystalium__ingest` is called with the outbound envelope.
- After session end: `mcp__crystalium__session_end` is called.

**Scenario B (CRYSTALIUM absent):**
- No `mcp__crystalium__*` calls produce errors.
- Kupo completes the KUPO cycle normally (EIIS-standalone-conformant).

**Pass criteria (Scenario A):**
- Recall query includes the task type and `from_eidolon`.
- Ingest envelope has `from.eidolon: kupo`.

**Pass criteria (Scenario B):**
- No hard failure, no error surface to the user.
- PROPOSE (or REFUSE) emitted normally.
