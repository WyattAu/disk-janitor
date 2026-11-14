# AGENTS.md — contract for AI agents working in this repo

These scripts run with root and delete things. The rules below exist
because breaking them deleted real files once (2026-11-09: a `-name build`
sweep erased vendored crate sources and 354 `node_modules` subtrees).

## Hard rules

1. **Never add a deletion path that matches directories by bare name
   alone.** Every removal must be evidence-backed: `CACHEDIR.TAG`,
   `CMakeCache.txt`, or an explicit allowlist path. Paths under
   `node_modules/`, `vendor/`, or `.git/` are always protected — `build`
   directories there contain real source.
2. **Deletions require an idle check.** No target is removed while it has
   files modified inside the idle window. The idle window shrinks only
   when free space is low (tiered: 24h → 5min → 1min).
3. **`~/data` (datasets, training shards, models) and Windows partitions
   are off-limits.** No rule, flag, or emergency mode may ever touch them.
4. **Test flags against the real binary, not the docs.** e.g. `swapon
   --show DEVICE=…` is not a real flag; parse `/proc/swaps` instead.
5. **Every script change runs `bash -n` and shellcheck before push**
   (CI enforces; run `make lint` locally).

## Layout

- `scripts/` — the three tools, self-contained, no shared code.
- Parameterize with env vars (`JANITOR_*`), never hardcode user paths.

## Workflow

```bash
make lint        # shellcheck + bash -n on every script
bash scripts/<tool>.sh --help   # read-only paths where offered
```

Commit style: conventional commits, subject ≤ 50 chars. Push to `master`
directly; CI must be green.
