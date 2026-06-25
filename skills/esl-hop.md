---
name: kupo-esl-hop
description: ESL lifecycle hop — when the cortex routes a verification to Kupo in an ESL-enabled project (tonberry MCP available), Kupo is the CHECKER (maker≠checker, mechanically enforced) and owns the verified transition. Use when a change with acceptance_checks is routed for verification and a mcp__tonberry__* tool surface exists. Absent tonberry → run your normal verify (ESL opt-in); never hard-fail.
metadata:
  methodology: Kupo
  phase: cross-cutting
---

# ESL Lifecycle Hop — Kupo (the CHECKER)

## When to use

Load this skill in an **ESL-enabled project** (`mcp__tonberry__*` tools available)
when the cortex routes a **verification** to you. You are the **CHECKER**, distinct
from the maker — `maker ≠ checker` is **mechanically enforced** (tonberry `verify`
check C4). You own the **verified** transition of the Eidolons Spec Lifecycle (ESL).

For the full lifecycle, stage definitions, and role bindings, see the nexus cortex
`methodology/cortex/esl-protocol.md`.

## Your hop

You did **not** make this change — you check it. Run your normal external-verify
discipline against the change's declared `acceptance_checks`, then drive the
conformance gate and the transition:

1. **verify externally** — load `skills/keep-or-kick.md` (triage the change is in
   scope to check) and `skills/patch-verify.md` (run the NAMED external verifiers
   against the change's `acceptance_checks` in a scratch copy). One green external
   signal per check, never self-critique.
2. **conformance gate** — call
   `mcp__tonberry__verify <change-dir> --mode <enforcement from the lock>`.
   It runs the 6 mechanical checks **C1–C6** (incl. **C4** maker≠checker, which
   cross-checks `verify.envelope.json`'s `from.eidolon != change.json.maker`).
3. **compose the verify envelope** — `from.eidolon = kupo`. This **MUST differ**
   from `change.json.maker` (else C4 fails by construction). Reuse your normal ECL
   `PROPOSE` composition (see `skills/patch-verify.md` "ECL emission").
4. **on pass** → call
   `mcp__tonberry__transition --change_id <id> --to_status verified`, then PROPOSE
   `verify_pass`.
5. **on fail** → **ESCALATE** with the last failure output. Do **not** edit the
   change to make it pass — the checker cannot make (you are not the maker).

## Invariants

- **You MUST NOT have been the maker.** `change.json.maker` must differ from `kupo`;
  if Kupo authored this change, REFUSE the checker role and ESCALATE — maker≠checker
  is mechanically enforced (C4), not a courtesy.
- **Checker cannot make.** On a failing check you ESCALATE; you never patch the
  change to flip it green. Editing-to-pass is exactly the maker≠checker violation
  the gate exists to stop.
- **External-only verify.** Correctness is a NAMED external verifier against the
  declared `acceptance_checks` — never self-critique, never LLM-judge (your P0).
- **Tonberry composes state; you provide the verdict.** You supply the green
  external signals and the verify envelope (`from.eidolon = kupo`); tonberry runs
  C1–C6 and writes the `verified` status.
- **Graceful skip** — if `mcp__tonberry__*` tools are unavailable, run your normal
  verify and **never hard-fail**. ESL is opt-in; Kupo is EIIS-standalone-conformant
  and works without tonberry.

---

*ESL Lifecycle Hop — Kupo (the CHECKER, maker≠checker mechanically enforced)*
