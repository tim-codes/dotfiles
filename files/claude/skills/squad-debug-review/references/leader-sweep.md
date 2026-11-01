# Leader-transcript sweep

Everything the leader did outside the GUI (nested merge runners, classifier
refusals, restarts, releases, issue closes, hygiene, Figma legs, its own
monitors) leaves no event unless the leader called `intervene`. On a run
where `interventions.csv` has few or no `explicit` or `leader-file` rows
(any run before v0.5.10, or a leader that did not log), the investigator
runs **one** fixed-pattern sweep of the leader transcript(s) and scratchpad
and counts the hits per L1–L13. Without it L1, L2, L7, L8, L9, L10, L12
and L13 all read zero (the 2026-10-31 dry run recalled half the hand
review's findings for exactly this reason).

## Identify the leader session(s)

In order of reliability:

1. From v0.5.10: `run.json.leader_attach` (`operator.attached {kind:
   leader}` events) and `sessions.csv` rows whose mutations carry actor
   `gui:leader` in `events.jsonl.gz`.
2. Before that: `sessions.csv` rows with `kind = operator` that are
   long-lived (hours, spanning most of the window), `cwd` `~/claude`
   (`/Users/tim/claude`), and whose kickoff brief says `role: orchestrator`
   or names the session the master operating session. There may be two or
   more in sequence (a handover), e.g. an exxo-context session until
   mid-morning, then a reserve one. Tim's own helper sessions are short and
   task-shaped; list them, do not sweep them.
3. Still unsure: name the candidates with start, end and cwd in the report
   and sweep the two longest.

The leader's scratchpad is
`/private/tmp/claude-501/<cwd slug>/<session_id>/scratchpad/` (restart and
build logs, monitor scripts, merge-runner, kickoff briefs and lane reports).
Read-only.

## Transcript locations

`sessions.csv` gives `transcript_path`, `transcript_exists` and
`transcript_found_via`. When `transcript_exists` is false (worktree
transcripts relocated after the run), search these roots and only these:

```bash
ls ~/.claude-personal/projects/*/<session_id>.jsonl ~/.claude-reserve/projects/*/<session_id>.jsonl \
   ~/.claude-exxo/projects/*/<session_id>.jsonl ~/.claude-exxo-openrouter/projects/*/<session_id>.jsonl 2>/dev/null
```

(`~/.claude-exxo-personal/projects` is a symlink to exxo's; dedupe by
`realpath`.) Subagent transcripts sit beside the parent under
`<session_id>/subagents/`. Never run `find /` or any filesystem-wide search.

## Patterns

One `grep -c` per pattern per transcript, then read only the hits (the
`uuid` and timestamp of each matching record are the evidence pointer):

| Pattern | Counts toward |
|---|---|
| `claude -p`, `merge-runner`, `--allowedTools` | L2 (a nested session re-running a refused merge; always an incident) |
| `gh pr merge` | L2 |
| `gh issue close`, `gh issue create` | L9 |
| `denied`, `classifier`, `Permission`, `refused` (in tool results) | L1 (the refusal; attribute the row to the blocked function) |
| `launchctl bootout`, `launchctl kickstart`, `bootstrap` | L7 |
| `build-0`, `pnpm install`, `just .*build`, `recipe failed`, `Rollup` | L7 (restart on a failed build when a failure line precedes the bootout) |
| `cargo install`, `tag v0.`, `chore(release)`, checkpoint PR | L8 |
| `items.decide`, `tasks.approve` | L4, L11 |
| `inbox.send` | L5 |
| `sessions.resume`, `sessions.close`, `policy.pause` | L6 |
| `wt remove`, `worktree remove`, `tmux kill-window` | L10 |
| `Figma`, `Boards`, `slack_send_message`, `notion`, Linear updates | L12 |
| `Monitor`, `no action needed`, `monitor` scripts in the scratchpad | L13 (count turns, not polls) |
| `verify.sh`, `format.sh`, `render`, `node --check` run by the leader | L3 |

## Output

A table `function, count, first, last, evidence` (one pointer per
function, more for L1 and L2) plus the refusal list: each refusal with what
was refused, how the leader handled it (`done` by another route, `parked`,
`handed_to_tim`) and the pointer. At most 30 lines of the investigator's
120. These rows are reported in the review as source `transcript-sweep`,
counted beside `explicit`/`inferred`/`leader-file`, and the review says
which functions rest on the sweep alone.
