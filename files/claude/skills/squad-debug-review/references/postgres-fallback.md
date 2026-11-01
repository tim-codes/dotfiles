# Postgres fallback for a squad debug review

Used only when no review bundle can be produced (section 2 of the skill).
Every query runs read-only through the deploy recipe, which keeps the
password inside the container:

```bash
just -f /Users/tim/dev/squad/deploy/Justfile psql -c "<sql>"
just -f /Users/tim/dev/squad/deploy/Justfile psql -At -F $'\t' -c "<sql>" > /path/in/scratchpad/items.tsv
```

Columns below are the live v0.5.9 schema (`orchestrator/migrations`):
`heavy_requests` has no grant time (join `grants` on `grant_id`),
`trunk_lands` has `created_at` and a prose `reason` (`reason_code` is a
v0.5.10 event field), `operator_items` has `raised_at`, `session_usage` has
`bucket` and no model (join `sessions`). Every query was dry-run against
the 2026-10-31 database.

Set the window first. With a `runs` row (v0.5.10 and later; the table does
not exist before):

```sql
select id, mode, started_at, ended_at, orchestrator_version, broker_version from runs order by started_at desc limit 5;
```

Without one, take the first and last `events.ts` of the day and say so.
Replace `:from` and `:to` below with literal timestamps
(`'2026-10-31 05:00Z'`).

## Headline numbers (review §1 table)

```sql
-- deliveries and latency
select count(*) enqueued, count(consumed_at) consumed, count(acked_at) acked,
       percentile_cont(0.5) within group (order by extract(epoch from consumed_at - written_at)) p50_s,
       percentile_cont(0.95) within group (order by extract(epoch from consumed_at - written_at)) p95_s,
       max(extract(epoch from consumed_at - written_at)) max_s
from inbox where created_at between :from and :to;

-- heavy grants and waits
select count(*) requests, count(g.granted_at) granted,
       percentile_cont(0.5) within group (order by extract(epoch from g.granted_at - h.requested_at)) p50_wait_s,
       percentile_cont(0.95) within group (order by extract(epoch from g.granted_at - h.requested_at)) p95_wait_s,
       max(extract(epoch from g.granted_at - h.requested_at)) max_wait_s
from heavy_requests h left join grants g on g.id = h.grant_id
where h.requested_at between :from and :to;

-- lands: state is landed | refused; reason is prose
select state, left(reason, 40) reason, count(*)
from trunk_lands where created_at between :from and :to group by 1, 2 order by 3 desc;

-- HITL items by source (raise | preflight | policy), wait = resolved - raised
select source, count(*) n, count(resolved_at) done,
       percentile_cont(0.5) within group (order by extract(epoch from resolved_at - raised_at) / 60) p50_min,
       percentile_cont(0.95) within group (order by extract(epoch from resolved_at - raised_at) / 60) p95_min
from operator_items where raised_at between :from and :to group by 1;

-- who decided (actor label; 'gui' alone means leader and Tim are indistinguishable, say so)
select actor, count(*) from events
where type = 'operator.item.decided' and ts between :from and :to group by 1;

-- cost of headless sessions (model comes from sessions)
select s.kind, s.model, count(distinct u.session_id) sessions, round(sum(u.cost_usd)::numeric, 2) usd
from session_usage u join sessions s on s.id = u.session_id
where u.bucket between :from and :to group by 1, 2 order by 4 desc;
```

## Leader interventions (review §4)

```sql
-- explicit (v0.5.10 and later; zero rows before)
select data->>'function' f, data->>'outcome' outcome, count(*)
from events where type = 'leader.intervention' and ts between :from and :to group by 1, 2 order by 1;

-- implicit: GUI mutations by the leader (actor 'gui:leader' after v0.5.10; before it, 'gui' is both)
select type, count(*) from events
where actor like 'gui%' and ts between :from and :to group by 1 order by 2 desc;

-- notes sent to members by the operator
select count(*) from inbox where sender = 'operator' and created_at between :from and :to;
```

Merge in the leader's file log
`~/.local/state/squad/debug/<run>/interventions.jsonl` when it exists.

## Idle stretches and wait reasons (review §6)

```sql
-- idle > 10 min per member session: broker.idle to the next tool_use or consumed
with e as (
  select session_id, ts, type,
         lead(ts) over (partition by session_id order by ts) next_ts
  from events
  where type in ('broker.idle', 'broker.tool_use', 'inbox.consumed') and ts between :from and :to)
select s.member, e.session_id, e.ts idle_from, e.next_ts idle_to,
       round(extract(epoch from e.next_ts - e.ts) / 60) idle_min
from e join sessions s on s.id = e.session_id
where e.type = 'broker.idle' and e.next_ts - e.ts > interval '10 min'
order by idle_min desc limit 30;
```

For each stretch, look for a concurrent wait reason: an open
`heavy_requests` row (`requested_at <= idle_from` and the joined
`grants.granted_at` is null or `>= idle_to`), an open `operator_items` row
for the task (`raised_at <= idle_from and coalesce(resolved_at, now()) >= idle_to`),
a pending `watches` row (`created_at <= idle_from and last_hit_at is null`),
or a `trunk_lands` row in review. No reason found means the member idled
for nothing, which is the finding.

## Decisions and restarts

```sql
select id, ts, rule, member, left(action::text, 80) action from decisions
where ts between :from and :to order by ts limit 200;

-- restarts (v0.5.10 and later; zero rows before). Before it, grep
-- "orchestrator listening" in ~/.local/state/squad/orchestrator.log and
-- the build logs the leader kept
select ts, type, data from events
where type in ('orchestrator.started', 'orchestrator.stopping', 'broker.connected', 'broker.disconnected', 'run.annotated')
  and ts between :from and :to order by ts;
```

## Transcripts

```sql
select id, kind, member, account, model, config_dir, cwd, transcript_path, exit_reason
from sessions where started_at between :from and :to order by started_at;
```

`transcript_path` is derived for headless sessions from v0.5.10 and null
before. When null, the path is
`<config_dir>/projects/<cwd with every / and . replaced by ->/<id>.jsonl`.
Resolve each with `ls` and keep a table `session_id, kind, member, path,
exists`; flag missing files rather than dropping the row.
