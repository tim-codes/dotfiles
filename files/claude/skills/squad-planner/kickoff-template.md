/squad-member
Invoke the squad-member skill first.

Task <task_id>: <title>
Repo: <owner/name>   Base: <base branch or trunk>   Priority (suggested): <1-5>

## Goal
<two to five sentences>

## Deliverables
<one line per deliverable: name: how "done" is checked>

## Milestones
<one line per milestone where the lane lands with land kind milestone; "none" if the work lands once>

## Merge authority
[trunk_service: land each milestone and the completion with mcp__squad__land; never gh pr merge.]
[operator: open the PR against the base and raise a review item; Tim merges.]

## Test policy
<"squad-member, Testing and trunks" or the exception, e.g. a browser smoke needing a heavy slot>

## Operator steps you may meet
<blocks_step items by title; "none">

## Dependencies
<task ids this waits on, and infra tasks; "none">

## Notes
<anything the member must know that the deliverables do not say>
