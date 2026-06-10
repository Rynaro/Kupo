# Wiring Kupo into Claude Code

## 1. Install

```bash
bash install.sh --target ./.eidolons/kupo --hosts claude-code
```

Or install all hosts at once:

```bash
bash install.sh --hosts all
```

## 2. Config

Add to your consumer project's `CLAUDE.md`:

```markdown
@.eidolons/kupo/agent.md
```

Claude Code loads `agent.md` into every session. Skills load on-demand when Kupo
requests them (triggered by phase entry or envelope detection).

### Frontmatter (agent.md)

```yaml
---
name: kupo
version: 1.1.0
methodology: KUPO
methodology_version: 1.0.0
role: executor — low-effort localized micro-task worker
---
```

### Subagent dispatch (`.claude/agents/kupo.md`)

When installed with `--hosts claude-code`, the installer writes a Claude Code
subagent dispatch file at `.claude/agents/kupo.md`:

```yaml
---
name: kupo
description: Low-effort localized executor. Delegates quick verifier-backed micro-tasks; patches a sandbox, proves externally, proposes a verified patch.
model: haiku
---
You are KUPO. Read these two files in order at session start:
1. `./.eidolons/kupo/agent.md` — always-loaded P0 rules.
2. `./.eidolons/kupo/SPEC.md` — deep on-demand methodology spec.
Skills live at `./.eidolons/kupo/skills/<skill>.md` (load on demand).
```

The `model: haiku` frontmatter ensures Kupo runs at the correct speed-class tier.
Kupo is NOT dispatched at sonnet or opus — that would destroy the cost-ratio premise.

## 3. Verify

Open a Claude Code session in your project and run:

```
"Using Kupo, fix the broken import path in src/api/client.ts. Use the TypeScript compiler as verifier."
```

Expected behavior:
1. Kupo loads `skills/keep-or-kick.md`, evaluates KEEP (import fix + tsc verifier → KEEP).
2. Kupo loads `skills/patch-verify.md`, locates the import via atlas-aci.
3. Kupo emits a search/replace proposal → harness applies to sandbox → tsc exits 0.
4. Kupo emits an `edit-proposal.json` + ECL PROPOSE envelope.
5. Parent applies the edit to the real tree and commits.

## 4. Troubleshooting

**Kupo not responding to `@.eidolons/kupo/agent.md`**
- Verify `.eidolons/kupo/agent.md` exists: `ls .eidolons/kupo/agent.md`
- Verify the `@` path in `CLAUDE.md` is correct relative to the project root.

**Kupo loading full SPEC.md on every invocation**
- This is intentional only if explicitly referenced. `agent.md` is the only
  always-loaded file (~600 tokens). SPEC.md loads on demand.

**Skills not found**
- Verify `.eidolons/kupo/skills/` contains `verify-incoming.md`, `keep-or-kick.md`,
  `patch-verify.md`.
- Check that paths are relative (not absolute) in the installed directory.

**Kupo refusing tasks it should accept**
- Check the Phase K triage in `skills/keep-or-kick.md`. Ensure the task is ≤2 files,
  has a named verifier, and a pass-rate clearly > 0.20.

**PROPOSE not being applied**
- Kupo never applies edits itself. The parent (orchestrator / human / Eidolon)
  must apply the `edit-proposal.json` to the real tree and commit.
