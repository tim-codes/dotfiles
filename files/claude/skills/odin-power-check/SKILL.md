---
name: odin-power-check
description: Verify the odin power-lifecycle stack (sleep inhibitor, heartbeat link, wake controller) is healthy — use after an odin cold boot or reboot, after changing any power-lifecycle component, or before sleep/wake testing. Runs read-only check scripts; changes nothing.
---

# Odin power-lifecycle verification

The scale-to-zero stack (ADR-009) spans the Windows host, the odin-k3s
guest, and two cluster workloads. Verify it with the two committed
procedural checks below — do not improvise ad-hoc probes; extend the
scripts instead if a check is missing.

## 1. Windows half (run on odin, no elevation)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File projects\odin\scripts\check-power-lifecycle.ps1
```

Asserts: heartbeat vNIC `172.31.99.1` assigned, firewall rule enabled, a
`listener up` log line newer than the last boot, and the powercfg snapshot
file refreshed within 180s (proves the SYSTEM listener loop is alive right
now). Prints the current hold state + power requests. Exits non-zero on any
failure.

## 2. Cluster half (from `projects/k8s`; on odin run inside WSL Debian)

```bash
just play power-lifecycle-check
```

Asserts: guest `eth1` has `172.31.99.2/30`, node `odin` Ready (implies the
VM auto-restarted), beacon pod Running on odin and logging counts, wake
controller Running on bifrost and polling.

## Interpreting results

- **odin asleep on purpose?** The guest/node/beacon checks fail by design —
  that is the lifecycle working. Only the wake-controller checks and the
  Windows half (once awake) are meaningful then.
- The Windows script deliberately never queries the scheduled task object
  (unelevated access-denied) or Get-VM (needs Hyper-V admin) — log/snapshot
  freshness and node Ready cover both without a UAC prompt.
- Healthy idle state: listener `RELEASED`, snapshot `SYSTEM:` section shows
  no `powershell.exe` entry, beacon `non-DaemonSet pods on odin: 0`,
  wake-controller `node=True amd64-runners=0`.
- Runbook background: ADR-009 (+ 2026-08-14 amendment), issue #57.
