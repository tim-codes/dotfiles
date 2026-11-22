# Push policy for the build branch (section 4, step 7)

The build branch is a local trunk. Moved verbatim from SKILL.md section 4.

**The build branch is a local trunk. Do not push it per checkpoint.**
Every push wakes remote CI, and a multi-lane build that pushes at each
merge pays for a dozen pipeline runs that are obsolete before they
finish and waits on them in between (Tim, 11 Nov 2026: "just work with a
local trunk and do light tests for gating locally, once all in then push
the batch to the remote and let github run verifications only at the
end"). Lanes integrate on the local build branch; the ledger, not the
PR, is the progress record between pushes. Push only:
- **once, at the end** (section 7), when every lane is merged and its
  light gate is green: this push is what runs the comprehensive
  verification;
- **at a pause or handover** (quota, context, a session change, going
  idle on the operator), because unpushed work must never be the only
  copy when attention moves. If the repo's CI runs on every push, push
  the branch without opening or updating a non-draft PR, or with the
  repo's CI-skip convention for that one push if it has one, and say so
  in the ledger;
- when the operator asks for a push.
Lane branches are not pushed either: lanes commit locally and the lead
merges locally. Open the draft PR at the first push (the end or a
pause), not at setup.
