# review.md sections and where each number comes from

Bundle files are under `~/.local/state/squad/debug/<run>/bundle/`. "Prev"
means the same file in the previous run's bundle.

| Section | Bundle source | Previous-run comparison |
|---|---|---|
| 1 Summary | `summary.md` headline table; `run.json` id, mode, window, versions, presence intervals | none |
| 2 What shipped since | issues labelled `debug-review:<prev run>`; CHANGELOG sections between `run.json.versions` of the two runs; Rollout lines for merged-not-live broker parts | the previous ranked list |
| 3 HITL | `items.csv`: `source`, `blocking`, `raised`, `notified` (channels), `decided_by`, `resolved`, `wait_min`, `foreseeable`; `operator.notify_skipped` rows in `events.jsonl.gz`; `invalid_input` raise refusals in `decisions.jsonl`; `timeline.md` for what Tim did | count, p50/p95 per source |
| 4 Leader interventions | `interventions.csv`: `function`, `action`, `reason`, `outcome`, `explicit|inferred`; plus `<run>/interventions.jsonl` (pre-v0.5.10 file log) | count per L-function, trend arrow |
| 5 Capture readiness | `run.json` (`mode`, `started_by`, `started_at` versus the first event); files missing or empty; `sessions.csv` `transcript_exists`; `run.json.versions.broker` versus CHANGELOG Rollout | none |
| 6 Delivery | `deliveries.csv` `wait_s`, `mid_turn`, `via`; `latency.md` p50/p95/max per kind and member; undelivered to closed sessions | p50/p95/max |
| 6 Idle | `idle.csv`: stretches > 5 min with `wait_reason` (heavy, item, watch, land, none) | member-minutes idle with no reason |
| 6 Heavy | `heavy.csv`: `waited_s`, `held_s`, `revoked_cause`, headroom columns | p50/p95 wait |
| 6 Lands | `lands.csv`: `verdict`, `review_s`, `reason_code`, `attempt`, `by` | landed / refused counts |
| 6 Quota and host | `quota.md` level changes and walls; `host.md` pressure episodes, orphan reaps, runaways; `run.json.restarts` | walls, episodes, restarts |
| 7 Round changes: efficacy | PR body or CHANGELOG bullet "Evidence:" line → the named column in the files above | the baseline value the PR cited |
| 8 What worked | any of the above where the number met its target, `watches.csv` hits, `lands.csv` refusals on substance | none |
| 9 Findings | investigator quadrants with pointers; wrong rulings cite `decisions.jsonl` ids or the ruling / `managed_repos` row | none |
| 10 K3 | `usage.csv` rows with account `openrouter`; `sessions.csv` `model` | none |
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
- zero lands against the wrong base, zero force-pushes after a refusal
  (`lands.csv`, member transcripts only if a refusal names one);
- every preflight `blocks_launch` item notified a channel within a minute
  (`items.csv` `notified`);
- every orchestrator restart has a build check before bootout and an L7
  intervention row; through the `ops.Justfile` recipe once it exists (a
  logged hand restart while the recipe is absent passes; an unlogged one,
  or one on a failed build, fails) (`run.json.restarts`,
  `interventions.csv`);
- leader interventions per function not higher than the previous run.
