cwd: ~/dev/<owner>/<repo>
context: exxo
model: opus
effort: high
needs: none
join: /squad-join --name <member> --priority 3 --needs <connectors> --branch squad/<member>
launch: claude-kickoff ~/claude/prompts/<date>/<NN>-<member>.md
base: main
depends: none
tickets: <KEY-1>, <KEY-2>
before-launch: none
---

/squad-join --name <member> --priority 3 --needs <connectors> --branch squad/<member>

<!--
Kickoff prompt template. Copy to ~/claude/prompts/<yymmdd>/<NN>-<member>.md,
fill it in and delete every comment. Launch with
`claude-kickoff <that file>` (add `--account` to override the context, and
`--dry-run` to see what it would do first); the squad herder calls the same
launcher, never a hand-built `claude` line.

FRONTMATTER (key: value lines, ended by the first line that is exactly `---`;
the body is everything after it). claude-kickoff reads the first four keys and the optional
launch keys below (harness to before-launch, add_dirs); `join`, `launch`, `base`, `depends` and
`tickets` are for the humans and the orchestrator, and are ignored by it.
Values may run long. A comment after `context` is fine: only its first word counts.

  cwd           working directory: ~/dev/..., an absolute path, or the bare name of one
                git checkout under ~/dev
  context       a context name in ~/.config/claude-kickoff/contexts.toml (personal, exxo,
                exxo-personal, exxo-openrouter): which account context runs it
                (overridable with `--account`)
  model         passed as `--model`
  effort        passed as `--effort`
  needs         optional, state it as this key (the join line is not read): each need the
                contexts file lists in `account_bound` (m365, figma, notion, agent-run,
                datadog, boards) must be provided by the context; an unmet one exits 9
  harness       optional, default claude-code; must equal the context's harness (else exit 5)
  role          optional: client (default) | herder | concierge | orchestrator | infra
  lifetime      optional: run | task; default task for a client, else run
  capabilities  optional comma list, passed to the herder via --dry-run
  env-pass      optional comma list of variable names the herder forwards from its environment
  add_dirs      optional comma or space separated paths (~ expanded), each passed as
                `--add-dir`, so the member can read and write brief and report files outside
                its cwd without prompts; each must exist (else exit 3)
  join          the /squad-join line the member runs first (repeat it as the first
                line of the body so the member sees it)
  launch        informational: how it is started; claude-kickoff is the launcher
  base          base branch the work starts from (and PRs target), if not main
  depends       other streams or PRs that must land before this one starts or merges
  tickets       the tickets in scope, in the order to take them
  before-launch the human steps that must happen first (a pull, a consent, a merge);
                `none` if there are none (`before launch` with a space reads the same)
-->

<!--
FACTS TO PRE-STATE PER STREAM. A member cannot ask mid-run, so write down what it
would otherwise have to guess. Put each as a line or short section in the body.

  [ ] Auth seam owner: who or what owns each login the stream touches (the orchestrator,
      the infra agent, a named human step), and what the member must never do itself
  [ ] Base branch: the branch to start from, where PRs go, and what must never be
      force-pushed or touched directly
  [ ] Identity list: every account, email address and user the stream acts as or touches
      (service accounts, test users, client mailboxes), so none is guessed
  [ ] Brand name: the exact spelling of the client, product and brand names to use
  [ ] Transcript location: where this session's transcript and any handoff files live,
      so the next session and the review can find them
  [ ] Merge authority, in Tim's own words: who may merge, what, and when, quoted
      as Tim said it ("I grant authority within this squad session to ..."), never
      paraphrased and never assumed from a previous batch
  [ ] Credential authority, in Tim's own words: which secrets the member may resolve
      and through what, and what is an operator item, quoted the same way
  [ ] Human steps to pre-enumerate: consents, DNS changes, device codes, admin panels
      and portals, each raised as an operator item with the exact command or URL and
      the build step it unblocks, not discovered one at a time in the pane
-->

<One paragraph: what this stream delivers, the umbrella ticket, and what "done" means.>

Base branch: `<base>`; `<how the worktree is made, e.g. wt switch --create squad/<member> --base <base>>`; <what must never be force-pushed or touched directly>.

Identities: <accounts / emails / users this stream acts as or touches>.
Brand: <exact brand and client names>.
Transcripts and handoffs: <where they live>.
Auth seam: <who owns what>.

1. <First step: usually preflight and operator pre-enumeration, then the first ticket.>
2. <Next step, with the ticket key, the acceptance check and what to report back.>
3. <Production or irreversible steps: quote Tim's words granting the authority, and the
   evidence required before using it.>
4. <Closing step: written review or report, tickets updated, `squad set --status done`.>

Authority (Tim's words): "<merge authority, verbatim>"; "<credential authority, verbatim>".

Operator items to raise up front: <consents, DNS, device codes, admin panels, each with
command or URL and the step it unblocks>.

Guardrails: <what the member must not do; evals kept minimal; heavy_slot before any
browser or Lighthouse run; anything out of bounds>. Decisions you can make, make and
record; route the rest to the orchestrator.
