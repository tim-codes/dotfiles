# Verbatim block for subagent briefs (lab host / secret access)

Paste this block, near-verbatim, into ANY subagent brief that may run
`ansible`, `ssh`, or `op` against the homelab. Do not summarize it — the
subagent has none of the orchestrator's loaded context.

---

Environment access rules (mandatory — violating them prompt-storms the
operator with Touch ID / SSH approvals):

1. Run ansible via `just` recipes or from the relevant
   `~/dev/homelab/projects/<host>/` directory. Both the root and each
   project's `ansible.cfg` set `ControlPersist=4h` SSH multiplexing, but only
   the project dir carries the host's own overrides (zima forces password
   auth there), so a root-run ad-hoc command against a project host can
   connect the wrong way.
2. Route `op` through the caching shim:
   `PATH=$HOME/dev/homelab/tools/op-shim:$PATH op ...` or a Just recipe —
   never bare `op` more than once. Run `just secret-cache-up` (idempotent)
   first if doing several reads.
3. Batch raw ssh into ONE invocation per host (a single remote script), with
   `-o ControlMaster=auto -o ControlPath=~/.ssh/cm-%r@%h -o ControlPersist=4h`
   so follow-ups reuse the socket.
4. Never retry failing auth in a loop — one retry max, then stop and report.
   The 1Password agent offers many keys per attempt; unpinned hosts can hit
   the server's MaxAuthTries, and every attempt can prompt the operator.
5. A command that appears hung is usually waiting on a Touch ID approval on
   the operator's Mac — wait, don't kill/retry.
6. Never run `op ... --reveal` or print secret values; consume secrets via
   playbooks/recipes only.
