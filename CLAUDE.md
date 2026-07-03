# Claude Code — Kupo

Load order for this repository:

1. `agent.md` — entry point, always loaded (≤ 1,000 tokens)
2. `SPEC.md` — full methodology specification
3. `skills/<skill>.md` — on-demand per phase (flat layout)
4. `schemas/ecl-envelope.v2.json` — load on demand to validate an outbound PROPOSE envelope (`schemas/ecl-envelope.v1.json` is retained for the ECL §7.3 back-compat window when validating an inbound v1.x sidecar).

## Consumer Project Usage

After installing this Eidolon into a consumer project (`bash install.sh`), Claude Code will find the installed agent at `.eidolons/kupo/agent.md`.

Add to the consumer project's `CLAUDE.md`:

```
@.eidolons/kupo/agent.md
```
