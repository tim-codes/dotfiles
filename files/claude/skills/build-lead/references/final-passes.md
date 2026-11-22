# Final passes and fold-back (section 7, steps 1 and 6)

Moved verbatim from SKILL.md section 7.

## Propose the final passes; don't start them

When the last lane is
merged and light-gated, stop and queue the candidate passes for the
operator with a recommendation each: a whole-branch review (by the most
capable reviewer, `review-package` over merge-base..HEAD, read by
`--stat` first; a package over ~100 KB is read by file), a UX pass for
UI changes, a conformity review, a security review of new auth or
credential paths. Give each a one-line scope, a cost (time and tokens)
and what it would catch that the light gates did not. Run only what the
operator picks (Tim, 11 Nov 2026: "dont trigger any whole-branch final
review at the end just queue these up and suggest what final passes you
want to do"). Include the ledger's deferred minors and parked rulings in
the proposal, since they are what a final review would weigh.

## Fold back what was generic

wrappers, scripts and procedures go to
the libraries (dotfiles `src/bin`, skills repos, the harness kit) as
draft PRs, one per library. Procedure text goes to a skill; data goes
to a reference; code that only suited this repo stays there. Note
candidates in the ledger as they arise so the pass at the end is a
read, not a memory.
