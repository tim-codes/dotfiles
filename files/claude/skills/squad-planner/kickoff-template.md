/squad-member
Invoke the squad-member skill first.

Task <task_id>: <title>
Repo: <owner/name>   Base: <base branch or trunk>   Priority (suggested): <1-5>

## Goal
<two to five sentences>

## Deliverables
<one line per deliverable: name: how "done" is checked; add "release: patch|minor|major" where it changes a tag-released package's public surface; where it shows a person or identity, how the identity resolves (source, lookup, caching) and who may see it>

## Milestones
<"none": the work lands once, at the completion land. A milestone only where Tim named one.>

## Merge authority
[trunk_service: land the completion with mcp__squad__land (and any milestone named above); never gh pr merge.]
[operator: open the PR against the base and raise a review item; Tim merges.]

## Test policy
<"squad-member, Testing and trunks" or the exception, e.g. a browser smoke needing a heavy slot>

## Operator steps you may meet
<blocks_step items by title; "none">

## Dependencies
<the plan's `prerequisites` (task ids, tickets, external steps); "none">

## Notes
<anything the member must know that the deliverables do not say; where a plan PR or OpenSpec change exists, its URL and change id, and "Run the staleness pass first (squad-member, Starting from a plan PR): rebase onto the base above before the first push only; after pushing, merge the base in.">
