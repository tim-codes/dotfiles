# review.md sections and where each number comes from

Bundle files are under `~/.local/state/squad/debug/<run>/bundle/`. "Prev"
means the same file in the previous run's bundle.

| Section | Bundle source | Previous-run comparison |
|---|---|---|
| 1 Summary | `summary.md` headline table; `run.json` id, mode, window, versions, presence intervals | none |
| 1 Scorecard | `summary.md` "Scorecard" section; `scorecard.csv` (one row per variant plus `all`: `gaia_index`, `n_tasks`, `n_no_land`, `first_pass_rate`, `elapsed_p50_s`/`p90`, `active_p50_s`, `cost_p50_usd`/`mean`/`total`, `cost_is_proxy`, `cache_hit_rate`, `interventions_per_land`, `by_function`, `by_arbiter_class`); `task_scores.csv` (one row per task closed in the run: `score` and its terms). A closed run's rows are frozen (`source` = `frozen`); the open run's are live. Cost is notional list price and a variant marked proxy is metered. A variant under 5 tasks reads `n<5`. A round with no closed task has an empty index. Definitions: `docs/eval-scorecard.md` in the squad repo | the previous round's `all` row (Δ column in `summary.md`) |
| 2 What shipped since | issues labelled `debug-review:<prev run>`; CHANGELOG sections between `run.json.versions` of the two runs; Rollout lines for merged-not-live broker parts | the previous ranked list |
| 3 HITL | `items.csv`: `source`, `kind`, `blocking`, `preflight_class`, `raised`, `presented`, `first_notified`, `notified_n`, `notified` (channels), `notify_skipped`, `decided_by`, `decision`, `resolved`, `wait_min`, `foreseeable`; `invalid_input` raise refusals in `decisions.jsonl`; `timeline.md` for what Tim did | count, p50/p95 per source |
| 4 Leader interventions | `interventions.csv`: `ts`, `source` (`explicit`, `inferred`, `inferred-unlabelled`, `leader-file`), `function`, `action`, `reason`, `ruling`, `outcome`, `item_id`, `task_id`, `member`, `pr`, `command`, `actor`, `event_type`, `event_id`. The file log is already merged; `inferred-unlabelled` is outside the trend | count per L-function, trend arrow (`summary.md` computes it against the previous bundle) |
| 5 Capture readiness | `run.json` (`mode`, `started_by`, `started_at` versus the first event, capture facts); `logs.md` (restarts, closing sessions, tunnel loss, build failures); leader-sweep `squad debug on` hits; files missing or empty; `sessions.csv` `transcript_exists`; `run.json.versions.broker` versus CHANGELOG Rollout | none |
| Authority (sections 1, 4, 9) | `repos.csv` (`managed_repos` snapshot: repo, trunk policy, `release_needs_approval`); the rulings memory files; `gh pr view --json baseRefName,mergedBy` per landed PR | none |
| 6 Delivery | `deliveries.csv` `queue_s`, `wait_s`, `total_s`, `ack_s`, `mid_turn`, `via`, `undelivered_closed`; `latency.md` p50/p95/max per kind and member, mid-turn share, directives never acked | p50/p95/max |
| 6 Idle | `idle.csv`: stretches of 5 min or more, `idle_s`, `ended_by`, `wait_reason` (heavy, item, land, watch, none), `wait_detail` | member-minutes idle with no reason |
| 6 Heavy | `heavy.csv`: `waited_s`, `held_s`, `revoked_cause`, `headroom_at_request`, `headroom_at_grant`, `slots_at_grant`, `calm_s_at_grant`, `forced` | p50/p95 wait |
| 6 Lands | `lands.csv`: `state`, `verdict`, `review_s`, `reason_code`, `reason`, `attempt`, `by` | landed / refused counts |
| 6 Quota and host | `quota.md` level changes and walls; `host.md` pressure episodes (from the broker sinks when present); `run.json.restarts` (`component`, `build_ok`, `build_log`, `downtime_s`) | walls, episodes, restarts |
| 7 Round changes: efficacy | PR body or CHANGELOG bullet "Evidence:" line → the named column in the files above | the baseline value the PR cited |
| 8 What worked | any of the above where the number met its target, `watches.csv` hits, `lands.csv` refusals on substance | none |
| 9 Findings | investigator quadrants with pointers; wrong rulings cite `decisions.jsonl` ids or the ruling / `managed_repos` row | none |
| 10 K3 | `usage.csv` rows with `scope` = `session` and `account` = `openrouter`; `sessions.csv` `model` | none |
| 11 Ranked change list | findings 3 to 9; cost and where are judgement | rank movement of carried-over items |

Pass/fail targets that carry over from round to round (state the number
either way):

- ack-gated directive p95 delivery ≤ 5 s (`deliveries.csv`, kind directive,
  `wait_s`);
- every approval item has a decision; delivered items are closed
  (`items.csv`);
- no member idle > 10 min with `wait_reason = none` (`idle.csv` lists
  stretches from 5 min; the target counts those over 10);
- heavy wait p95 under the configured dwell plus one tick while headroom
  existed (`heavy.csv` headroom columns);
- zero lands against the wrong base (`gh pr view <n> -R <repo> --json
  baseRefName,mergedBy` for every landed PR in `lands.csv`, against the
  repo's trunk policy; `lands.csv` has no base column), zero force-pushes
  after a refusal (member transcripts only if a refusal names one);
- every preflight `blocks_launch` item notified a channel within a minute
  (`items.csv` `notified`);
- every orchestrator restart has a build check before bootout and an L7
  intervention row; through the `ops.Justfile` recipe once it exists (a
  logged hand restart while the recipe is absent passes; an unlogged one,
  or one on a failed build, fails) (`run.json.restarts`,
  `interventions.csv`);
- leader interventions per function not higher than the previous run
  (`explicit` + `inferred` + `leader-file`, plus `transcript-sweep` rows
  when the sweep ran; `inferred-unlabelled` excluded).

Bundle values to verify before citing (wrong, not merely unknown, on the
2026-10-31 bundle; drop a line here once the bundler fixes it):
`deliveries.csv`/`summary.md` undelivered-to-closed count (check inbox rows
`queued` to sessions with `ended_at`), `run.json.restarts` (check
`orchestrator.started`/`broker.connected` in `events.jsonl.gz` and
`errors.jsonl`), `mid_turn` "not recorded" (derive from `via` and the
session state), `heavy.csv` `headroom_at_*` empty (the `decisions.jsonl`
triggers hold the numbers), any wrong-base count (`gh pr view`; the
summary's expected base is wrong for repos outside the squad), `idle.csv`
`wait_reason = none` during an admission pause or a heavy wait (check
`heavy.csv` and `decisions.jsonl` for the stretch), `watches.csv` blank
`polls` for `github_run`, and `items.csv` `notified` "unknown" for raises
that `operator.notified` shows were notified.

Incident classes the bundle cannot flag at all (investigator ask 11, one
targeted transcript check each): a wind-down before the land verdict, a
decided item whose member was never told, a heavy grant followed by a Bash
gate refusal. Facts only in service logs (`logs.md`): sessions closed by a
restart, `lost` exits, live sessions at bootout, tunnel loss.
