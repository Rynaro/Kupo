# Installing Kupo

Kupo installs into any project as a self-contained agent directory.

## Prerequisites

- `bash` 3.2+ (macOS ships with bash 3.2; no upgrade required)
- `git` (for clone method)
- `jq` (for manifest validation; auto-installed by the nexus CLI if absent)

## Quick Install

```bash
git clone https://github.com/Rynaro/Kupo
cd your-project
bash ../Kupo/install.sh
```

Default target: `./.eidolons/kupo`. Then wire your AI tooling (see host sections below).

## Options

```
bash install.sh [OPTIONS]

  --target DIR          Target install dir (default: ./.eidolons/kupo)
  --hosts LIST          claude-code,copilot,cursor,opencode,codex,all,auto,none (default: auto)
  --force               Overwrite existing install
  --dry-run             Print actions, no writes
  --non-interactive     No prompts; fail on ambiguity (meta-installer mode)
  --manifest-only       Only emit install.manifest.json
  --version             Print Kupo version
  -h, --help            Show help
```

Exit codes: `0` ok · `2` bad args · `3` already-installed (no --force) · `4` token budget exceeded.

---

## Claude Code

**Install:**
```bash
bash install.sh --target ./.eidolons/kupo --hosts claude-code
```

**Wire:**
Add to your project's `CLAUDE.md`:
```
@.eidolons/kupo/agent.md
```

**Verify:**
Open a session and run:
```
"Using Kupo, fix the broken import in src/utils.ts. The TypeScript compiler is the verifier."
```

Expected: Kupo runs phase K (KEEP — import fix, tsc as verifier), phase U (locates the import),
phase P (emits search/replace), phase O (tsc exits 0), emits PROPOSE.

---

## GitHub Copilot

**Install:**
```bash
bash install.sh --target ./.eidolons/kupo --hosts copilot
```

**Wire:**
The installer appends to or creates `.github/copilot-instructions.md`. Verify it contains:
```markdown
See `.eidolons/kupo/agent.md` for the KUPO methodology entry point.
```

---

## Cursor

**Install:**
```bash
bash install.sh --target ./.eidolons/kupo --hosts cursor
```

**Wire:**
The installer creates `.cursor/rules/kupo.mdc`. Activate in Cursor's rules panel.

---

## OpenCode

**Install:**
```bash
bash install.sh --target ./.eidolons/kupo --hosts opencode
```

**Wire:**
The installer creates `.opencode/agents/kupo.md`. OpenCode picks this up automatically.

---

## All Hosts at Once

```bash
bash install.sh --hosts all
```

---

## Raw API / Any LLM

Copy `.eidolons/kupo/agent.md` (compact, ≤ 1,000 tokens) as the system prompt.
Load `.eidolons/kupo/SPEC.md` for the full methodology. Load skills on-demand.

---

## Uninstall

```bash
rm -rf .eidolons/kupo
```

Then remove the dispatch lines added to `CLAUDE.md`, `.github/copilot-instructions.md`, etc.
