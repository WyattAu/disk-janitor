# disk-janitor

Autonomous disk reclamation for Linux workstations that compile all day.
Born on a 1TB btrfs CachyOS box where AI-agent build churn hit **145M free**
while swap sat 31G/31G full; this repo is the tooling that ended the
crash-clean-crash cycle without a reboot.

## What's inside

| Script | Problem it solves |
|---|---|
| [`scripts/disk-janitor.sh`](scripts/disk-janitor.sh) | Deletes build dirs (`target/`, `build/`, `.lake/`, `node_modules`) once idle, with tiered urgency: 24h idle normally, 5min when free < 25G, 1min emergency sweep below 10G. Caps a shared dedup cargo target at 100G. Also sweeps out-of-tree target roots (`~/.cache/<name>-target`, `~/dev/.targets/<name>`) — those dirs are not named `target`, so a daily loop could grow one to 183G unnoticed; they are removed when idle for the tiered window, or when >40G and cold >6h, and never while a process still references them. Guards: never touches anything inside `node_modules`, `vendor`, or `.git` — lesson learned the hard way when a naive `-name build` match deleted real source. |
| [`scripts/reclaim-snapshots.sh`](scripts/reclaim-snapshots.sh) | Prunes btrfs snapshot bloat (snapper). Key finding: `snapper cleanup` only deletes snapshots *tagged* with a cleanup algorithm — untagged ones survive forever. This script tightens retention, then force-deletes by number, keeping the newest 2, and follows with a `balance -dusage=40`. |
| [`scripts/drain-zram.sh`](scripts/drain-zram.sh) | Empties a full zram swap device **without a reboot** by migrating pages to a temporary NOCOW swapfile on btrfs, refreshing the zram device, and pulling pages back. |

All three are defensive by design: they only ever delete *regenerable
artifacts*, never source, user data, or anything modified recently.

## Requirements

- bash 4+
- Linux with btrfs (`reclaim-snapshots.sh`, `drain-zram.sh`)
- `snapper` configured on the root subvolume (for snapshot reclaim)
- zram swap device (for drain)
- Each script states its own needs at the top; everything is read-only
  until you run it with `sudo`.

## Install

```bash
git clone https://github.com/WyattAu/disk-janitor.git
cd disk-janitor
sudo cp scripts/*.sh /usr/local/bin/
```

Or symlink from wherever you keep scripts. Nothing is installed on your
system; the scripts are self-contained.

## Usage

```bash
disk-janitor.sh            # one sweep; run from cron/systemd for autonomy
reclaim-snapshots.sh --dry-run   # preview, then run without --dry-run
drain-zram.sh              # sudo only
```

`disk-janitor.sh` is configurable via environment:

| Variable | Default | Meaning |
|---|---|---|
| `JANITOR_ROOTS` | `$HOME/dev/src $HOME/dev/.targets $HOME/builds $HOME/.cargo/target` | where it hunts for build dirs |
| `JANITOR_SHARED_TARGET` | `$HOME/.cache/cargo-target` | the dedup store it caps at 100G |
| `JANITOR_LOG` | `$XDG_CACHE_HOME/janitor.log` | run log |

Recommended cadence: every 6 hours via a systemd user timer
(`OnCalendar=*-*-* 00/6:30:00`, `Persistent=true`).

## Cautions learned in production

- `find -name build` matches real source directories inside vendored
  dependency trees. The janitor checks for `CACHEDIR.TAG`/`CMakeCache.txt`
  and skips `node_modules`/`vendor`/`.git` paths outright.
- `snapper cleanup` silently skips snapshots without a cleanup tag. If your
  count never drops, that's why — hence the force-delete in
  `reclaim-snapshots.sh`.
- A swapfile on btrfs must be NOCOW and fully allocated before use;
  `truncate` creates holes the kernel rejects. `drain-zram.sh` does the
  `touch → chattr +C → dd` dance for you.
- Deleting a shared cargo target while a build writes to it can fail that
  build (cargo just rebuilds on the next run, but be aware).

## Status

In production daily on a CachyOS workstation with continuous AI-agent
builds. See each script's header for exact behavior.

## License

MIT — see [LICENSE](LICENSE).
