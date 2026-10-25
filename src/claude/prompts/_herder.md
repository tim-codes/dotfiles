cwd: ~/claude
context: exxo
model: sonnet
effort: medium
role: herder
lifetime: run
needs: none
env-pass: SQUAD_MERGE_AUTHORITY
launch: claude-kickoff ~/claude/prompts/<date>/00-herder.md
before-launch: none
---

/squad-herder

<!--
Kickoff template for the squad herder itself. Copy to
~/claude/prompts/<yymmdd>/00-herder.md, fill in the placeholder below and
delete every comment. The herder is launched by Tim (or the concierge on his
word) with `claude-kickoff <that file>`; it launches everything else.
-->

Bootstrap the managers from the kickoff directory `~/claude/prompts/<yymmdd>/`:
the concierge, orchestrator and infra, the liaison, then persistent clients
such as `dashboard`. Skip and report any file whose `before_launch` is not
`none`. Take directives from the orchestrator only; make no decisions of your
own.
