---
name: run-with-secrets
description: Use before running any command in this repo that touches 1Password — Ansible against zima/ragnar, playbooks with onepassword lookups, unifi just recipes, or ad-hoc op reads — to minimize Touch ID approval prompts via the secret cache and SSH multiplexing.
---

# Running homelab tasks that need 1Password secrets

Secret reads and SSH connections in this repo trigger Touch ID approvals on
the operator's Mac. Two mechanisms keep that to roughly one prompt per
secret/host per session — use them.

## Before secret-touching work: warm the cache

```bash
just secret-cache-up     # idempotent, allowlisted — run it freely
```

This starts `homelab-1p-cache`, a memory-only Redis container on
`127.0.0.1:6381`. The `op` shim at `tools/op-shim/op` — first on PATH for all
Just recipes — then caches read-only `op` output (`op read`, `op item get`)
for 1 hour, so each 1Password item costs **one** Touch ID per TTL window
instead of one per invocation. This covers Ansible's `onepassword` lookups
(zima's `ansible_ssh_pass`, playbook secrets) and `unifi.py`'s API key.

- Long unattended run? Extend the TTL so it can't expire mid-run and hang
  on an unapprovable prompt: `HOMELAB_1P_CACHE_TTL_SECONDS=14400 just ...`
- Bypass: `HOMELAB_1P_CACHE_DISABLE=1`. Cache down = silent fallback to
  live `op` (never blocks; the operator just gets more prompts).
- `just secret-cache-down` destroys all cached secrets (also allowlisted).
  **Don't run it to "tidy up" after a task.** The cache is shared across every
  session on this machine, so tearing it down mid-flight silently re-prompts
  another agent's run for Touch ID. Let the 1h TTL expire on its own; reserve
  `secret-cache-down` for rotating a credential.

## SSH prompts

Ansible configs set `ControlPersist=4h`: the **first** connection to each
host per window prompts Touch ID — that is expected, don't treat it as an
error — and subsequent runs reuse the socket silently. If a run seems hung,
it is usually waiting on a Touch ID approval, not stuck: tell the operator
instead of killing it. macbook-m2max is deliberately human-in-the-loop —
never try to make its auth unattended.

## Rules

- Never run `op ... --reveal` or otherwise print secret values into the
  transcript; let playbooks/scripts consume them via the shim.
- Prefer `just` recipes over raw `ansible`/`ansible-playbook` — the recipes
  carry the shim PATH and correct working directory (run from repo root or
  the project dir so the right `ansible.cfg` applies). For zima playbooks
  use `just zima-play <name>`; a bare `ansible-playbook` bypasses the shim.
- Secrets live in the 1Password **HomeLab** vault; item UUIDs are documented
  in CLAUDE.md / project CLAUDE.md files.
- Tradeoffs and design: `docs/adr/005-1password-secret-cache.md`.
