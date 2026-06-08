# Kupo — Low-Effort Localized Executor

A small, fast Eidolon in the [Eidolons](https://github.com/Rynaro/eidolons) hierarchy.
Heavier planners delegate quick, well-scoped micro-tasks to Kupo to keep their own
sessions efficient. Kupo patches an ephemeral scratch sandbox, proves the edit with
an external verifier, and hands the parent a verified patch to commit.

> Kupo is a worker, not a router. The parent always commits.

## Quick Start

```bash
# Install Kupo into your project
bash <(curl -fsSL https://raw.githubusercontent.com/Rynaro/Kupo/main/install.sh)
```

Default install target: `./.eidolons/kupo`. Then wire Claude Code:

```
# Add to your project's CLAUDE.md:
@.eidolons/kupo/agent.md
```

## The K→U→P→O Cycle

```
K ──▶ U ──▶ P ──▶ O ──┬──▶ PROPOSE (verified)
                      └──▶ ESCALATE / REFUSE
```

| Phase | Role |
|---|---|
| **K** Keep-or-Kick | Triage: ≤2 files, named verifier, pass-rate > 0.20 → KEEP; else REFUSE cheap |
| **U** Understand | Just-in-time atlas-aci gather at 40–60% ctx; produce `path:line` anchor |
| **P** Patch | Emit search/replace or whole-file → harness applier → scratch sandbox |
| **O** Observe | External verifiers only; success silent, failures verbose; circuit-breaker 3/20 |

## Scope Guard

Kupo KEEP iff **all** hold: ≤ 2 files · named external verifier · expected pass-rate > 0.20.

**KEEP classes:** rename/symbol-move · import/path fix · lockfile bump · config-key edit ·
lint autofix · mechanical fixture update · one-line assertion fix · template boilerplate ·
bounded grep-replace.

**REFUSE/ESCALATE:** open-ended reasoning · cross-cutting refactor (>2 files) · ambiguous spec ·
loop-native coding campaign (→ Vivi / APIVR-Δ) · no nameable verifier · pass-rate ≤ 0.20.

## Architecture

```
Kupo/
├── install.sh               # Install into any project
├── agent.md                 # Always-loaded entry point (≤1000 tokens)
├── SPEC.md                  # Full KUPO methodology specification
├── ECL_VERSION              # 2.0
├── EIIS_VERSION             # 1.4
├── skills/
│   ├── verify-incoming.md   # BLOCKING ECL gate (ECL §6.2.2)
│   ├── keep-or-kick.md      # Phase K triage procedure
│   └── patch-verify.md      # Phase P+O patch-and-verify loop
├── schemas/
│   ├── kupo-edit-proposal.v1.json   # Edit proposal output schema
│   ├── ecl-envelope.v1.json         # Vendored ECL envelope schema
│   ├── ecl-base-profile.v1.json     # Vendored ECL base profile
│   └── install.manifest.v1.json     # Vendored EIIS manifest schema
└── contracts/               # ECL per-edge contracts (6 in / 5 out)
```

## Design Principles

**Harness over model.** Kupo wins by owning a fixed, minimal-autonomy
localize→edit→validate pipeline with external-only verification. A haiku-class
agent on a 2-tool surface beats a larger model in an open loop on this task class
(Haiku 4.5 @ 73.3% SWE-bench Verified — Anthropic).

**PROPOSE-only.** Kupo never writes the real tree. It patches an ephemeral sandbox,
verifies externally, and proposes. The parent commits.

**External-only verify.** Intrinsic self-critique degrades at haiku tier (Huang ICLR'24,
2310.01798). Only tests / typecheck / lint / compile / diff count.

**Economic gate.** Kupo only attempts tasks with expected pass-rate > ~0.20 (haiku→opus
cost ratio). Misfits bounce at K for ~1 step — structurally non-negative.

**MASTER eval-gate (ship-blocker).** Kupo is deployed behind a periodic KEEP-cohort eval.
Do not rely on Kupo in production pipelines without an eval result.

## Standards

- [EIIS v1.4](https://github.com/Rynaro/eidolons-eiis) — install contract
- [ECL v2.0](https://github.com/Rynaro/eidolons-ecl) — communication contract

---

*Kupo v0.1.0 — in_construction*
