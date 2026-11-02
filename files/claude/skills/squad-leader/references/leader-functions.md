# Leader functions L1–L13 and what retires each

Taxonomy from the 2026-10-31 debug review §3 (tim-codes/squad,
`docs/superpowers/plans/2026-10-31-squad-v05-debug-review.md`), pinned in
the orchestrator's `leader.intervention` contract. Log every instance with
`intervene` (or the file log) using the function id. Counts in brackets are
the 2026-10-31 baseline the next rounds are measured against.

| # | Function | What the leader does by hand today | Retired by | Log as |
|---|---|---|---|---|
| L1 | Unblock classifier and permission refusals [about 18] | Hands the refused action to Tim with the exact command; files the squad issue that removes the need. Not logged as its own row: a refusal is logged under the function it blocked (L2, L3, L9, …) with `outcome: handed_to_tim`, and L1 is the count of those rows | #287 (trunk service owns merges and issue close-out), #288 (host-job for sandbox-blocked commands); items carry an exact one-line command | the blocked function, `outcome: handed_to_tim`, `command` |
| L2 | Merges outside the trunk service [27] | Merges framework, release and checkpoint PRs with its own `gh pr merge` when permitted (logged, `outcome: done`); when the classifier refuses, the PR goes to Tim (`handed_to_tim`). The nested merge-runner (ruling 38, "for today") is retired | #287 | `pr`, `reason` citing `managed_repos` |
| L3 | Run sandbox-blocked work unsandboxed [75 renders, 13 items] | Runs an allow-listed render or repo gate script (`verify.sh`, `format.sh`, `node --check`) outside the member sandbox and returns the result to the member by `inbox.send` | #288 (broker host-job with a fixed allowlist); Node 24 pinned for members | `member`, `task_id`, `command` |
| L4 | Decide items [59] | `items.decide` under a ruling it can cite | #290 (rulings in the DB, routine kinds auto-decided) | `item_id`, `reason: ruling <id>` |
| L5 | Nudge and brief members [61 notes] | `inbox.send` a note: a fix landed, a new ruling, a protocol change, "your watch may not have woken you" | #290 (ruling broadcast), #289 (idle nudge), #285 (wind-down only after land) | `member`, `task_id` |
| L6 | Session control | `sessions.resume` after a restart or a refused land; `sessions.close` a revived idle session; a policy pause | #291 (resume lost and refused-land sessions after restart), #285 | `member`, `session_id` |
| L7 | Rebuild and restart [10 orchestrator, 2 broker] | `deploy/ops.Justfile restart-orchestrator` (fallback: procedures.md) | #291 (verified release and restart job); #292 keeps only the attended broker re-grant | `reason`, `command` |
| L8 | Cut releases, checkpoints and tags [6] | Release PR on the trunk, checkpoint PR trunk→main with a merge commit, tag | #293 (release task kind queued at milestone completion) | `pr` |
| L9 | File and close issues [11 filed, 20 closes] | `gh issue create/close -R tim-codes/squad`; refused closes go to Tim | #287 (closes `Closes #n` at land); members raise bugs as items the orchestrator files | `command` |
| L10 | Hygiene [35 worktrees, 20 windows] | `worktree-closedown` skill; tmux windows by name or `@id` | #239 (teardown at land; partial) plus transcript relocation in the trunk service | `task_id` |
| L11 | Plan and approve rounds [7 approvals, 3 planner lanes] | Launches a planner lane over open issues; `tasks.approve` under ruling 29 | #294 (when-idle planning under standing rulings); agentic plan review already live | `task_id`, `reason: ruling 29` |
| L12 | Operator-only legs [15 decks, 15 Slack sends] | Figma, Boards, Slack, Notion, Linear legs members cannot reach | #295 (Figma and Boards via `needs`/`provides`; concierge sends status and pairing links) | `task_id`, `item_id` |
| L13 | Watch for trouble [1,137 monitor events] | The monitors in the skill's Operating section | #289 (orchestrator watchers), #286 (CI-green watch kind), #284 (notify on `blocks_launch` preflight items) | one row per monitor-triggered action, not per poll |

Look a title up with `gh issue view <n> -R tim-codes/squad`. When an issue
closes, the function is retired only once a round's `interventions.csv`
shows zero for it; until then it stays in the table with the new count.
